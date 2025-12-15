"""
Flashcard PDF export endpoint.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlmodel import Session, select
from typing import List, Optional
from pydantic import BaseModel, Field
from app.core.database import get_session
from app.core.config import settings
from app.models.models import Concept, Lemma, Topic
import logging
from io import BytesIO
from reportlab.lib.pagesizes import A5
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image, ImageDraw
import requests
from pathlib import Path
import html
import os

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcard-export", tags=["flashcard-export"])

# Language emoji mapping (matching the Dart implementation)
LANGUAGE_EMOJI_MAP = {
    'en': '🇬🇧',  # English - UK flag
    'es': '🇪🇸',  # Spanish
    'it': '🇮🇹',  # Italian
    'fr': '🇫🇷',  # French
    'de': '🇩🇪',  # German
    'jp': '🇯🇵',  # Japanese
    'nl': '🇳🇱',  # Dutch
    'lt': '🇱🇹',  # Lithuanian
    'pt': '🇵🇹',  # Portuguese
    'ar': '🇸🇦',  # Arabic - Saudi Arabian flag
}


def get_language_emoji(language_code: str) -> str:
    """Get emoji for a language code."""
    return LANGUAGE_EMOJI_MAP.get(language_code.lower(), '🌐')


# Try to register Unicode-supporting fonts for IPA symbols and emojis
_unicode_font_registered = False
_unicode_font_name = "Helvetica"  # Fallback
_emoji_font_registered = False
_emoji_font_name = None

# Custom display fonts for flashcard PDF export
_custom_fonts_registered = False
_title_font_name = "Helvetica-Bold"
_description_font_name = "Helvetica"
_ipa_font_name = None

def _build_font_search_paths():
    """Common font search paths (bundled first, then system)."""
    api_root = Path(__file__).parent.parent.parent.parent.parent
    bundled_fonts_dir = api_root / "fonts"
    
    alternative_paths = [
        Path("/app/assets/fonts"),  # Common Docker path
        Path("/app/fonts"),  # Common Docker path
        Path("./fonts"),  # Current directory
        Path("fonts"),  # Relative to current working directory
    ]
    
    search_paths = [
        str(bundled_fonts_dir),  # Check bundled fonts first
        "/System/Library/Fonts/Supplemental",
        "/Library/Fonts",
        "/usr/share/fonts/truetype/dejavu",
        "/usr/share/fonts/TTF",
        "/usr/share/fonts/truetype/noto",
        "/usr/share/fonts/opentype/noto",
        "/usr/share/fonts/truetype/liberation",
        "C:/Windows/Fonts",
    ]
    
    for alt_path in alternative_paths:
        if alt_path.exists() and str(alt_path) not in search_paths:
            search_paths.insert(1, str(alt_path))  # Insert after bundled_fonts_dir
    
    return search_paths

def find_font_files(search_paths, patterns):
    """Find font files matching patterns in search paths."""
    import fnmatch
    found_fonts = []
    for search_path in search_paths:
        if not os.path.exists(search_path):
            continue
        path_obj = Path(search_path)
        # Search for .ttf and .otf files (NOT .ttc - TTFont doesn't support TrueType Collections)
        for ext in ['.ttf', '.otf']:
            for font_file in path_obj.rglob(f'*{ext}'):
                if font_file.is_file():
                    font_name = font_file.name
                    # Check if font name matches any pattern
                    for pattern in patterns:
                        # Handle wildcard patterns
                        if '*' in pattern:
                            # Use fnmatch for wildcard matching (font_name already has extension)
                            # Try pattern with extension, pattern with wildcard+extension, or just pattern
                            if (fnmatch.fnmatch(font_name, pattern + ext) or 
                                fnmatch.fnmatch(font_name, pattern + '*' + ext) or 
                                fnmatch.fnmatch(font_name, pattern + ext.replace('.', '')) or
                                fnmatch.fnmatch(font_name, pattern)):
                                found_fonts.append(str(font_file))
                                break
                        else:
                            # Simple substring match (case-insensitive)
                            if pattern.lower() in font_name.lower():
                                found_fonts.append(str(font_file))
                                break
    return found_fonts

def register_unicode_fonts():
    """Register Unicode-supporting fonts if available."""
    global _unicode_font_registered, _unicode_font_name, _emoji_font_registered, _emoji_font_name
    
    if _unicode_font_registered:
        return _unicode_font_name, _emoji_font_name
    
    search_paths = _build_font_search_paths()
    
    # Try to find Unicode-supporting fonts
    unicode_patterns = [
        "Arial Unicode",
        "ArialUni",
        "NotoSans*",
        "DejaVuSans",
        "LiberationSans",
    ]
    
    # Try to find emoji fonts
    emoji_patterns = [
        "Symbola",
        "NotoColorEmoji",
        "NotoEmoji",
    ]
    
    # Find and try Unicode fonts
    unicode_fonts = find_font_files(search_paths, unicode_patterns)
    # Prioritize: Arial Unicode first (most common), then Noto, then DejaVu
    unicode_fonts.sort(key=lambda x: (
        0 if 'Arial Unicode' in x or 'ArialUni' in x else
        1 if 'Noto' in x else
        2 if 'DejaVu' in x else 3
    ))
    
    for font_path in unicode_fonts:
        if not os.path.exists(font_path):
            logger.debug("Font file does not exist: %s", font_path)
            continue
        try:
            # Verify it's actually a font file by checking file size (should be > 10KB)
            font_size = os.path.getsize(font_path)
            if font_size < 10000:
                logger.warning("Font file too small (%d bytes), may be corrupted: %s", font_size, font_path)
                continue
            
            pdfmetrics.registerFont(TTFont("UnicodeFont", font_path))
            _unicode_font_name = "UnicodeFont"
            _unicode_font_registered = True
            logger.info("Successfully registered Unicode font: %s (size: %d KB)", font_path, font_size // 1024)
            break
        except Exception as e:
            logger.warning("Failed to register font %s: %s", font_path, str(e))
            # Log more details for debugging
            if hasattr(e, 'args') and e.args:
                logger.debug("Font registration error details: %s", e.args)
            continue
    
    # Find and try emoji fonts
    emoji_fonts = find_font_files(search_paths, emoji_patterns)
    for font_path in emoji_fonts:
        if not os.path.exists(font_path):
            continue
        try:
            pdfmetrics.registerFont(TTFont("EmojiFont", font_path))
            _emoji_font_name = "EmojiFont"
            _emoji_font_registered = True
            logger.info("Successfully registered emoji font: %s", font_path)
            break
        except Exception as e:
            logger.warning("Failed to register emoji font %s: %s", font_path, str(e))
            continue
    
    if not _unicode_font_registered:
        logger.error("CRITICAL: No working Unicode font found! IPA symbols and emojis will not render correctly.")
        logger.error("Please download Noto Sans font and place it in api/fonts/ directory.")
        logger.error("Run: python3 api/fonts/download_font.py")
        logger.error("Or: ./api/fonts/download_font.sh")
        _unicode_font_registered = True
    
    return _unicode_font_name, _emoji_font_name


def register_flashcard_fonts():
    """
    Register display fonts for title/description (Ramillas) and IPA (Monoscript).
    Falls back to Helvetica/Unicode font if custom fonts are unavailable.
    """
    global _custom_fonts_registered, _title_font_name, _description_font_name, _ipa_font_name
    
    if _custom_fonts_registered:
        return _title_font_name, _description_font_name, _ipa_font_name
    
    search_paths = _build_font_search_paths()
    
    # Target fonts: Ramillas for display, Monoscript for IPA
    ramillas_candidates = find_font_files(
        search_paths,
        [
            "TT Ramillas*",  # bundled trial fonts inside fonts/tt_ramillas
            "Ramillas*", 
            "Ramillas"
        ]
    )
    monoscript_candidates = find_font_files(search_paths, ["Monoscript*", "Monoscript"])
    
    def _register_first_available(candidates, registered_name):
        for font_path in candidates:
            if not os.path.exists(font_path):
                continue
            try:
                font_size = os.path.getsize(font_path)
                if font_size < 10000:
                    logger.warning("Font file too small (%d bytes), may be corrupted: %s", font_size, font_path)
                    continue
                pdfmetrics.registerFont(TTFont(registered_name, font_path))
                logger.info("Registered custom font %s from %s", registered_name, font_path)
                return registered_name
            except Exception as e:
                logger.warning("Failed to register font %s: %s", font_path, str(e))
        return None
    
    def _prioritize_ramillas(candidates, weight_keywords, exact_match=None):
        # First, check for exact match if specified (check filename, not full path)
        if exact_match:
            exact_match_lower = exact_match.lower()
            for path in candidates:
                path_filename = Path(path).name.lower()
                if path_filename == exact_match_lower:
                    return [path]  # Return exact match first
        
        # Keep files that contain any desired keyword, prefer non-outline/initial/decor variants
        filtered = []
        for path in candidates:
            lower_path = path.lower()
            if "outline" in lower_path or "decor" in lower_path or "initials" in lower_path:
                continue
            for weight in weight_keywords:
                if weight in lower_path:
                    filtered.append((weight_keywords.index(weight), path))
                    break
        # If nothing matched keywords, keep all as fallback
        if not filtered:
            filtered = [(len(weight_keywords), p) for p in candidates]
        # Sort by priority then path length (shorter often Regular vs Variable)
        filtered.sort(key=lambda x: (x[0], len(x[1])))
        return [p for _, p in filtered]
    
    # Choose best Ramillas files for title (Medium) and description (Light)
    # Prioritize exact font files: "TT Ramillas Trial Medium.ttf" for title, "TT Ramillas Trial Light.ttf" for description
    ramillas_title_candidates = _prioritize_ramillas(
        ramillas_candidates,
        ["medium", "bold", "black", "extrabold", "regular"],
        exact_match="TT Ramillas Trial Medium.ttf"
    )
    ramillas_body_candidates = _prioritize_ramillas(
        ramillas_candidates,
        ["light", "regular", "medium"],
        exact_match="TT Ramillas Trial Light.ttf"
    )
    
    ramillas_title_font = _register_first_available(ramillas_title_candidates, "RamillasTitleFont")
    ramillas_body_font = _register_first_available(ramillas_body_candidates, "RamillasBodyFont")
    monoscript_font = _register_first_available(monoscript_candidates, "MonoscriptFont")
    
    if ramillas_title_font:
        _title_font_name = ramillas_title_font
    if ramillas_body_font:
        _description_font_name = ramillas_body_font
    if not ramillas_title_font and not ramillas_body_font:
        logger.info("Ramillas font not found; falling back to Helvetica/Helvetica-Bold.")
    
    if monoscript_font:
        _ipa_font_name = monoscript_font
    else:
        logger.info("Monoscript font not found; IPA will use Unicode/Helvetica fallback.")
    
    _custom_fonts_registered = True
    return _title_font_name, _description_font_name, _ipa_font_name


class FlashcardExportRequest(BaseModel):
    """Request schema for flashcard PDF export."""
    concept_ids: List[int] = Field(..., description="List of concept IDs to export")
    languages_front: List[str] = Field(..., description="Language codes for front side")
    languages_back: List[str] = Field(..., description="Language codes for back side")


def decode_html_entities(text: str) -> str:
    """Decode HTML entities in text."""
    if not text:
        return ""
    return html.unescape(text)


def get_image_path(image_url: Optional[str]) -> Optional[Path]:
    """Get local file path for an image URL."""
    if not image_url:
        return None
    
    # If it's a relative path starting with /assets/, get the local file
    if image_url.startswith("/assets/"):
        if settings.assets_path:
            assets_dir = Path(settings.assets_path)
        else:
            api_root = Path(__file__).parent.parent.parent.parent.parent
            assets_dir = api_root / "assets"
        
        image_filename = image_url.replace("/assets/", "")
        image_path = assets_dir / image_filename
        if image_path.exists():
            return image_path
    
    return None


def get_language_flag_image_path(language_code: str) -> Optional[Path]:
    """Get local file path for a language flag image."""
    # Try multiple possible locations
    possible_paths = []
    
    # 1. Check configured assets_path (for production/Docker)
    if settings.assets_path:
        possible_paths.append(Path(settings.assets_path) / "images" / "languages" / f"{language_code.lower()}.png")
    
    # 2. Check local development path (relative to this file)
    api_root = Path(__file__).parent.parent.parent.parent.parent
    possible_paths.append(api_root / "assets" / "images" / "languages" / f"{language_code.lower()}.png")
    
    # 3. Check alternative local paths
    possible_paths.append(Path("./assets") / "images" / "languages" / f"{language_code.lower()}.png")
    possible_paths.append(Path("../assets") / "images" / "languages" / f"{language_code.lower()}.png")
    
    # Try each path until we find one that exists
    for flag_path in possible_paths:
        logger.debug("Checking flag image at: %s (exists: %s)", flag_path, flag_path.exists())
        if flag_path.exists():
            logger.info("Found flag image for %s at: %s", language_code, flag_path)
            return flag_path
    
    logger.warning("Flag image not found for %s in any of the checked paths", language_code)
    return None


def download_image(url: str) -> Optional[BytesIO]:
    """Download an image from a URL."""
    try:
        # Handle relative URLs
        if url.startswith("/assets/"):
            image_path = get_image_path(url)
            if image_path and image_path.exists():
                with open(image_path, "rb") as f:
                    return BytesIO(f.read())
            return None
        
        # Handle absolute URLs
        if url.startswith("http://") or url.startswith("https://"):
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                return BytesIO(response.content)
        
        return None
    except Exception as e:
        logger.warning("Failed to download image from %s: %s", url, str(e))
        return None


def draw_card_side(
    c: canvas.Canvas,
    concept: Concept,
    lemmas: List[Lemma],
    languages: List[str],
    topic: Optional[Topic] = None,
):
    """Draw one side of a flashcard (A5 size: 148 x 210 mm)."""
    width, height = A5
    margin = 10 * mm
    
    # Register Unicode fonts for IPA symbols and emojis
    unicode_font, emoji_font = register_unicode_fonts()
    title_font, desc_font, ipa_font = register_flashcard_fonts()
    
    # Log registered fonts for debugging
    registered_fonts = pdfmetrics.getRegisteredFontNames()
    logger.debug("Available fonts: %s", registered_fonts)
    logger.info(
        "Using fonts - Title: %s, Description: %s, IPA: %s, Unicode: %s, Emoji: %s",
        title_font, desc_font, ipa_font, unicode_font, emoji_font
    )
    
    # Clear background
    c.setFillColor(HexColor("#FFFFFF"))
    c.rect(0, 0, width, height, fill=1, stroke=0)
    
    # Topic icon at top right (subtle) - use emoji font if available
    if topic and topic.icon:
        icon_size = 16
        icon_drawn = False
        if emoji_font and emoji_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(emoji_font, icon_size)
                c.setFillColor(HexColor("#CCCCCC"))  # Subtle gray
                icon_width = c.stringWidth(topic.icon, emoji_font, icon_size)
                icon_x = width - margin - icon_width
                icon_y = height - margin - icon_size
                c.drawString(icon_x, icon_y, topic.icon)
                icon_drawn = True
            except Exception as e:
                logger.debug("Failed to draw topic icon with emoji font: %s", str(e))
        
        if not icon_drawn and unicode_font and unicode_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(unicode_font, icon_size)
                c.setFillColor(HexColor("#CCCCCC"))  # Subtle gray
                icon_width = c.stringWidth(topic.icon, unicode_font, icon_size)
                icon_x = width - margin - icon_width
                icon_y = height - margin - icon_size
                c.drawString(icon_x, icon_y, topic.icon)
            except Exception as e:
                logger.debug("Failed to draw topic icon with unicode font: %s", str(e))
    
    y = height - margin
    
    # Image at the top (centered) - with more spacing
    image_height = 60 * mm
    image_margin_top = 10 * mm  # Increased spacing above image
    image_margin_bottom = 20 * mm  # Increased spacing below image
    
    # Add space above image
    y -= image_margin_top
    
    if concept.image_url:
        image_data = download_image(concept.image_url)
        if image_data:
            try:
                # Open with PIL to resize
                pil_image = Image.open(image_data)
                # Calculate size to fit
                max_width = width - 2 * margin
                max_height = image_height
                
                # Maintain aspect ratio
                img_width, img_height = pil_image.size
                aspect_ratio = img_width / img_height
                
                if aspect_ratio > (max_width / max_height):
                    # Width is limiting
                    new_width = max_width
                    new_height = max_width / aspect_ratio
                else:
                    # Height is limiting
                    new_height = max_height
                    new_width = max_height * aspect_ratio
                
                # Only resize if necessary to maintain quality
                # Calculate target size in pixels (ReportLab uses points, 1 point = 1/72 inch)
                target_width_px = int(new_width)
                target_height_px = int(new_height)
                
                # Resize with high-quality resampling only if needed
                if pil_image.size != (target_width_px, target_height_px):
                    pil_image = pil_image.resize((target_width_px, target_height_px), Image.Resampling.LANCZOS)
                
                # Convert to RGBA to support transparency for rounded corners
                if pil_image.mode != "RGBA":
                    pil_image = pil_image.convert("RGBA")
                
                # Add rounded corners using a mask
                # Convert 8mm to pixels: 8mm as a proportion of the page width, then scale to image pixels
                corner_radius_px = int((8 * mm / width) * new_width)
                # Ensure reasonable radius (8-30 pixels typically)
                min_dimension = min(target_width_px, target_height_px)
                corner_radius_px = max(8, min(corner_radius_px, 30))
                
                # Create mask for rounded corners using a simple, reliable method
                mask = Image.new("L", (target_width_px, target_height_px), 0)
                draw = ImageDraw.Draw(mask)
                
                # Draw rounded rectangle - try the modern method first
                try:
                    # PIL 9.0.0+ has rounded_rectangle
                    if hasattr(draw, 'rounded_rectangle'):
                        draw.rounded_rectangle(
                            [(0, 0), (target_width_px - 1, target_height_px - 1)],
                            radius=corner_radius_px,
                            fill=255
                        )
                    else:
                        raise AttributeError("rounded_rectangle not available")
                except (AttributeError, TypeError):
                    # Fallback: create rounded rectangle manually
                    # Fill main rectangle (excluding corners)
                    draw.rectangle(
                        [corner_radius_px, 0, target_width_px - corner_radius_px, target_height_px],
                        fill=255
                    )
                    draw.rectangle(
                        [0, corner_radius_px, target_width_px, target_height_px - corner_radius_px],
                        fill=255
                    )
                    # Draw corner circles
                    for x, y in [
                        (corner_radius_px, corner_radius_px),  # top-left
                        (target_width_px - corner_radius_px, corner_radius_px),  # top-right
                        (corner_radius_px, target_height_px - corner_radius_px),  # bottom-left
                        (target_width_px - corner_radius_px, target_height_px - corner_radius_px)  # bottom-right
                    ]:
                        draw.ellipse(
                            [x - corner_radius_px, y - corner_radius_px,
                             x + corner_radius_px, y + corner_radius_px],
                            fill=255
                        )
                
                # Apply mask to image alpha channel
                pil_image.putalpha(mask)
                
                # Save to BytesIO with full quality (PNG for transparency support)
                img_buffer = BytesIO()
                # Save with no compression for maximum quality
                pil_image.save(img_buffer, format="PNG", compress_level=0, optimize=False)
                img_buffer.seek(0)
                
                # Draw image centered (rounded corners are already applied via mask)
                img_x = (width - new_width) / 2
                img_y = y - new_height
                c.drawImage(ImageReader(img_buffer), img_x, img_y, width=new_width, height=new_height)
                y = img_y - image_margin_bottom  # More spacing below image
            except Exception as e:
                logger.warning("Failed to draw image for concept %d: %s", concept.id, str(e))
                y -= image_height + image_margin_bottom  # Reserve space even if image fails
    
    # Language lemmas below
    # Calculate font sizes
    title_font_size = 14  # Reduced from 20
    desc_font_size = 8  # Smaller font for description and IPA
    
    # Draw lemmas for each language
    for lang_code in languages:
        # Find lemma for this language
        lemma = next((l for l in lemmas if l.language_code.lower() == lang_code.lower()), None)
        if not lemma:
            continue
        
        if y < margin + 30 * mm:  # Not enough space
            break
        
        # Translation (main term) - centered
        # Load language flag image and draw it before title text
        translation_text = decode_html_entities(lemma.term)
        
        # Get language flag image
        flag_image_path = get_language_flag_image_path(lang_code)
        flag_image_data = None
        flag_width = 0
        # Make flag larger for better quality - use 1.5x font size instead of 1.1x
        flag_height = title_font_size * 1
        
        if flag_image_path and flag_image_path.exists():
            try:
                logger.debug("Loading flag image for %s from %s", lang_code, flag_image_path)
                # Open image directly from path with PIL
                pil_flag = Image.open(flag_image_path)
                logger.debug("Flag image loaded: %dx%d pixels", pil_flag.width, pil_flag.height)
                # Maintain aspect ratio, scale to match desired height
                flag_aspect = pil_flag.width / pil_flag.height
                flag_width = flag_height * flag_aspect
                logger.debug("Flag image will be rendered at %fx%f points", flag_width, flag_height)
                # Resize with high-quality resampling for better quality
                # Convert points to pixels (1 point = 1/72 inch, assume 72 DPI for PDF)
                target_width_px = int(flag_width)
                target_height_px = int(flag_height)
                # Resize with LANCZOS resampling for best quality
                if pil_flag.size != (target_width_px, target_height_px):
                    pil_flag = pil_flag.resize((target_width_px, target_height_px), Image.Resampling.LANCZOS)
                # Convert to RGBA if needed
                if pil_flag.mode != "RGBA":
                    pil_flag = pil_flag.convert("RGBA")
                # Save to buffer with high quality (no compression)
                flag_buffer = BytesIO()
                pil_flag.save(flag_buffer, format="PNG", compress_level=0, optimize=False)
                flag_buffer.seek(0)
                flag_image_data = flag_buffer
                logger.debug("Flag image processed and ready for rendering")
            except Exception as e:
                logger.warning("Failed to load language flag image for %s from %s: %s", lang_code, flag_image_path, str(e))
                import traceback
                logger.debug("Traceback: %s", traceback.format_exc())
                flag_image_data = None
        else:
            logger.warning("Language flag image not found for %s (checked path: %s)", lang_code, flag_image_path)
        
        # Word wrap for translation text (accounting for flag image)
        c.setFont(title_font, title_font_size)
        words = translation_text.split()
        lines = []
        current_line = ""
        flag_spacing = 8 if flag_image_data else 0  # Extra spacing for clarity
        max_width_text = width - 2 * margin - flag_width - flag_spacing
        
        for word in words:
            test_line = f"{current_line} {word}".strip()
            if c.stringWidth(test_line, title_font, title_font_size) <= max_width_text:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
        
        if current_line:
            lines.append(current_line)
        
        # Draw translation lines with flag image prefix
        for line_idx, line in enumerate(lines):
            if y < margin + 20 * mm:
                break
            
            # Calculate total width (flag + space + text)
            text_width = c.stringWidth(line, title_font, title_font_size)
            total_width = flag_width + flag_spacing + text_width if flag_image_data else text_width
            
            # Center the entire line (flag + text)
            line_x = (width - total_width) / 2
            
            # Draw flag image (only on first line)
            if line_idx == 0 and flag_image_data:
                try:
                    # Align flag to the top of the text (cap height) instead of centering
                    # This makes the flag appear higher and aligned with the top of the title text
                    ascent = pdfmetrics.getAscent(title_font) * title_font_size / 1000.0
                    # Position flag so its top aligns with the cap height of the text
                    flag_y = y + ascent - flag_height
                    c.drawImage(ImageReader(flag_image_data), line_x, flag_y, width=flag_width, height=flag_height, mask='auto')
                    logger.debug(
                        "Drew flag image for %s at (%.2f, %.2f) with size (%.2f, %.2f) | ascent=%.2f",
                        lang_code, line_x, flag_y, flag_width, flag_height, ascent
                    )
                except Exception as e:
                    logger.warning("Failed to draw language flag image: %s", str(e))
            
            # Draw text
            c.setFont(title_font, title_font_size)
            c.setFillColor(HexColor("#000000"))
            text_x = line_x + flag_width + flag_spacing if (line_idx == 0 and flag_image_data) else line_x
            c.drawString(text_x, y, line)
            y -= title_font_size + 2  # Slightly tighter spacing under each line

        y -= 1  # Less extra spacing before IPA
        
        # IPA - centered, using Unicode font, same size as description
        if lemma.ipa and y > margin + 15 * mm:
            ipa_text = f"/{decode_html_entities(lemma.ipa)}/"
            ipa_drawn = False
            ipa_font_to_use = ipa_font or unicode_font
            if ipa_font_to_use and ipa_font_to_use in pdfmetrics.getRegisteredFontNames():
                try:
                    c.setFont(ipa_font_to_use, desc_font_size)
                    c.setFillColor(HexColor("#aaaaaa"))
                    ipa_width = c.stringWidth(ipa_text, ipa_font_to_use, desc_font_size)
                    ipa_x = (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                    ipa_drawn = True
                except Exception as e:
                    logger.debug("Failed to draw IPA with custom/unicode font: %s", str(e))
            
            if not ipa_drawn:
                # Fallback if Unicode font doesn't support the IPA characters
                try:
                    c.setFont("Helvetica", desc_font_size)
                    c.setFillColor(HexColor("#aaaaaa"))
                    ipa_width = c.stringWidth(ipa_text, "Helvetica", desc_font_size)
                    ipa_x = (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                except Exception as e:
                    logger.debug("Failed to draw IPA with Helvetica: %s", str(e))
            y -= desc_font_size + 10  # More space before description
        
        # Description - wrapped in container for better text wrapping
        if lemma.description and y > margin + 10 * mm:
            desc = decode_html_entities(lemma.description)
            c.setFont(desc_font, desc_font_size)
            c.setFillColor(HexColor("#999999"))  # Grey color
            
            # Use narrower width for description container (80% of available width)
            desc_container_width = (width - 2 * margin) * 0.6
            
            # Word wrap description within container
            words = desc.split()
            desc_lines = []
            current_line = ""
            
            for word in words:
                test_line = f"{current_line} {word}".strip()
                if c.stringWidth(test_line, desc_font, desc_font_size) <= desc_container_width:
                    current_line = test_line
                else:
                    if current_line:
                        desc_lines.append(current_line)
                    current_line = word
            
            if current_line:
                desc_lines.append(current_line)
            
            # Draw description lines (centered within container, limit to available space)
            max_desc_lines = int((y - margin) / (desc_font_size + 2))
            for line in desc_lines[:max_desc_lines]:
                if y < margin + 5 * mm:
                    break
                line_width = c.stringWidth(line, desc_font, desc_font_size)
                line_x = (width - line_width) / 2
                c.drawString(line_x, y, line)
                y -= desc_font_size + 2
        
        y -= 24  # More spacing between languages


@router.post("/pdf")
async def export_flashcards_pdf(
    request: FlashcardExportRequest,
    session: Session = Depends(get_session)
):
    """
    Export flashcards as PDF with A5 cards.
    Each concept gets two pages: front (languages_front) and back (languages_back).
    """
    if not request.concept_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="concept_ids cannot be empty"
        )
    
    if not request.languages_front or not request.languages_back:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="languages_front and languages_back cannot be empty"
        )
    
    # Create PDF buffer
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=A5)
    
    # Fetch all concepts with their lemmas and topics
    concepts = []
    for concept_id in request.concept_ids:
        concept = session.get(Concept, concept_id)
        if not concept:
            logger.warning("Concept %d not found, skipping", concept_id)
            continue
        
        # Get lemmas for this concept
        statement = select(Lemma).where(Lemma.concept_id == concept_id)
        lemmas = list(session.exec(statement).all())
        
        # Get topic if available
        topic = None
        if concept.topic_id:
            topic = session.get(Topic, concept.topic_id)
        
        concepts.append((concept, lemmas, topic))
    
    if not concepts:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No valid concepts found"
        )
    
    # Generate cards: front and back for each concept
    for concept, lemmas, topic in concepts:
        # Front side
        c.showPage()
        draw_card_side(c, concept, lemmas, request.languages_front, topic)
        
        # Back side
        c.showPage()
        draw_card_side(c, concept, lemmas, request.languages_back, topic)
    
    # Save PDF
    c.save()
    buffer.seek(0)
    
    # Return PDF as response
    return Response(
        content=buffer.getvalue(),
        media_type="application/pdf",
        headers={
            "Content-Disposition": "attachment; filename=flashcards.pdf"
        }
    )

