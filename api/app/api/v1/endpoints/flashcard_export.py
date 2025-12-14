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
from PIL import Image
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
    
    # First, check for bundled fonts in the api/fonts directory
    api_root = Path(__file__).parent.parent.parent.parent.parent
    bundled_fonts_dir = api_root / "fonts"
    
    # Search paths for fonts (bundled fonts first, then system fonts)
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
            continue
        try:
            pdfmetrics.registerFont(TTFont("UnicodeFont", font_path))
            _unicode_font_name = "UnicodeFont"
            _unicode_font_registered = True
            logger.info("Successfully registered Unicode font: %s", font_path)
            break
        except Exception as e:
            logger.warning("Failed to register font %s: %s", font_path, str(e))
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
        logger.error("Download from: https://fonts.google.com/noto/specimen/Noto+Sans")
        logger.error("Or run: python3 -c \"import urllib.request; urllib.request.urlretrieve('https://github.com/google/fonts/raw/main/ofl/notosans/NotoSans-Regular.ttf', 'api/fonts/NotoSans-Regular.ttf')\"")
        _unicode_font_registered = True
    
    return _unicode_font_name, _emoji_font_name


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
    
    # Log registered fonts for debugging
    registered_fonts = pdfmetrics.getRegisteredFontNames()
    logger.debug("Available fonts: %s", registered_fonts)
    logger.info("Using Unicode font: %s, Emoji font: %s", unicode_font, emoji_font)
    
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
    x = margin
    
    # Image at the top (centered) - with more spacing
    image_height = 60 * mm
    image_margin_top = 10 * mm  # Increased spacing above image
    image_margin_bottom = 10 * mm  # Increased spacing below image
    
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
                
                # Resize image
                pil_image = pil_image.resize((int(new_width), int(new_height)), Image.Resampling.LANCZOS)
                
                # Convert to RGB if necessary
                if pil_image.mode != "RGB":
                    pil_image = pil_image.convert("RGB")
                
                # Save to BytesIO
                img_buffer = BytesIO()
                pil_image.save(img_buffer, format="JPEG", quality=85)
                img_buffer.seek(0)
                
                # Draw image centered
                img_x = (width - new_width) / 2
                img_y = y - new_height
                c.drawImage(ImageReader(img_buffer), img_x, img_y, width=new_width, height=new_height)
                y = img_y - image_margin_bottom  # More spacing below image
            except Exception as e:
                logger.warning("Failed to draw image for concept %d: %s", concept.id, str(e))
                y -= image_height + image_margin_bottom  # Reserve space even if image fails
    
    # Language lemmas below
    # Calculate font sizes
    title_font_size = 16  # Reduced from 20
    body_font_size = 11
    small_font_size = 9
    desc_font_size = 8  # Smaller font for description
    
    # Draw lemmas for each language
    for lang_code in languages:
        # Find lemma for this language
        lemma = next((l for l in lemmas if l.language_code.lower() == lang_code.lower()), None)
        if not lemma:
            continue
        
        if y < margin + 30 * mm:  # Not enough space
            break
        
        # Language flag emoji - use emoji font if available, then unicode font
        lang_emoji = get_language_emoji(lang_code)
        emoji_drawn = False
        if emoji_font and emoji_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(emoji_font, small_font_size)
                c.setFillColor(HexColor("#666666"))
                emoji_width = c.stringWidth(lang_emoji, emoji_font, small_font_size)
                emoji_x = (width - emoji_width) / 2
                c.drawString(emoji_x, y, lang_emoji)
                emoji_drawn = True
            except Exception as e:
                logger.debug("Failed to draw emoji with emoji font: %s", str(e))
        
        if not emoji_drawn and unicode_font and unicode_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(unicode_font, small_font_size)
                c.setFillColor(HexColor("#666666"))
                emoji_width = c.stringWidth(lang_emoji, unicode_font, small_font_size)
                emoji_x = (width - emoji_width) / 2
                c.drawString(emoji_x, y, lang_emoji)
                emoji_drawn = True
            except Exception as e:
                logger.debug("Failed to draw emoji with unicode font: %s", str(e))
        
        if not emoji_drawn:
            # Fallback to text if emoji fails
            c.setFont("Helvetica", small_font_size)
            c.setFillColor(HexColor("#666666"))
            lang_text = f"[{lang_code.upper()}]"
            text_width = c.stringWidth(lang_text, "Helvetica", small_font_size)
            text_x = (width - text_width) / 2
            c.drawString(text_x, y, lang_text)
        y -= small_font_size + 4
        
        # Translation (main term) - centered
        translation = decode_html_entities(lemma.term)
        c.setFont("Helvetica-Bold", title_font_size)
        c.setFillColor(HexColor("#000000"))
        
        # Word wrap for long translations
        words = translation.split()
        lines = []
        current_line = ""
        max_width_text = width - 2 * margin
        
        for word in words:
            test_line = f"{current_line} {word}".strip()
            if c.stringWidth(test_line, "Helvetica-Bold", title_font_size) <= max_width_text:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
        
        if current_line:
            lines.append(current_line)
        
        # Draw translation lines (centered)
        for line in lines:
            if y < margin + 20 * mm:
                break
            line_width = c.stringWidth(line, "Helvetica-Bold", title_font_size)
            line_x = (width - line_width) / 2
            c.drawString(line_x, y, line)
            y -= title_font_size + 3
        
        y -= 3  # Extra spacing
        
        # IPA - centered, using Unicode font
        if lemma.ipa and y > margin + 15 * mm:
            ipa_text = f"/{decode_html_entities(lemma.ipa)}/"
            ipa_drawn = False
            if unicode_font and unicode_font in pdfmetrics.getRegisteredFontNames():
                try:
                    c.setFont(unicode_font, body_font_size)
                    c.setFillColor(HexColor("#666666"))
                    ipa_width = c.stringWidth(ipa_text, unicode_font, body_font_size)
                    ipa_x = (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                    ipa_drawn = True
                except Exception as e:
                    logger.debug("Failed to draw IPA with unicode font: %s", str(e))
            
            if not ipa_drawn:
                # Fallback if Unicode font doesn't support the IPA characters
                try:
                    c.setFont("Helvetica", body_font_size)
                    c.setFillColor(HexColor("#666666"))
                    ipa_width = c.stringWidth(ipa_text, "Helvetica", body_font_size)
                    ipa_x = (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                except Exception as e:
                    logger.debug("Failed to draw IPA with Helvetica: %s", str(e))
            y -= body_font_size + 4
        
        # Tags (part of speech, article, plural, formality)
        tags = []
        if concept.part_of_speech:
            tags.append(concept.part_of_speech)
        if lemma.article:
            tags.append(lemma.article)
        if lemma.plural_form:
            tags.append(f"pl. {lemma.plural_form}")
        if lemma.formality_register and lemma.formality_register.lower() != "neutral":
            tags.append(lemma.formality_register)
        
        if tags and y > margin + 10 * mm:
            c.setFont("Helvetica", small_font_size)
            c.setFillColor(HexColor("#666666"))
            tags_text = " • ".join(tags)
            # Word wrap tags if needed
            if c.stringWidth(tags_text, "Helvetica", small_font_size) > max_width_text:
                # Split tags across lines
                tag_lines = []
                current_tag_line = ""
                for tag in tags:
                    test_tag_line = f"{current_tag_line} • {tag}".strip()
                    if test_tag_line.startswith(" • "):
                        test_tag_line = test_tag_line[3:]
                    if c.stringWidth(test_tag_line, "Helvetica", small_font_size) <= max_width_text:
                        current_tag_line = test_tag_line
                    else:
                        if current_tag_line:
                            tag_lines.append(current_tag_line)
                        current_tag_line = tag
                if current_tag_line:
                    tag_lines.append(current_tag_line)
                
                for tag_line in tag_lines:
                    if y < margin + 10 * mm:
                        break
                    c.drawString(x, y, tag_line)
                    y -= small_font_size + 1
            else:
                c.drawString(x, y, tags_text)
                y -= small_font_size + 2
        
        # Description - centered, smaller and grey
        if lemma.description and y > margin + 10 * mm:
            desc = decode_html_entities(lemma.description)
            c.setFont("Helvetica", desc_font_size)
            c.setFillColor(HexColor("#666666"))  # Grey color
            
            # Word wrap description
            words = desc.split()
            desc_lines = []
            current_line = ""
            
            for word in words:
                test_line = f"{current_line} {word}".strip()
                if c.stringWidth(test_line, "Helvetica", desc_font_size) <= max_width_text:
                    current_line = test_line
                else:
                    if current_line:
                        desc_lines.append(current_line)
                    current_line = word
            
            if current_line:
                desc_lines.append(current_line)
            
            # Draw description lines (centered, limit to available space)
            max_desc_lines = int((y - margin) / (desc_font_size + 2))
            for line in desc_lines[:max_desc_lines]:
                if y < margin + 5 * mm:
                    break
                line_width = c.stringWidth(line, "Helvetica", desc_font_size)
                line_x = (width - line_width) / 2
                c.drawString(line_x, y, line)
                y -= desc_font_size + 2
        
        # Notes
        if lemma.notes and y > margin + 5 * mm:
            notes = decode_html_entities(lemma.notes)
            c.setFont("Helvetica-Oblique", small_font_size)
            c.setFillColor(HexColor("#666666"))
            
            # Word wrap notes
            words = notes.split()
            notes_lines = []
            current_line = ""
            
            for word in words:
                test_line = f"{current_line} {word}".strip()
                if c.stringWidth(test_line, "Helvetica-Oblique", small_font_size) <= max_width_text:
                    current_line = test_line
                else:
                    if current_line:
                        notes_lines.append(current_line)
                    current_line = word
            
            if current_line:
                notes_lines.append(current_line)
            
            # Draw notes (limit to 2-3 lines)
            for line in notes_lines[:3]:
                if y < margin:
                    break
                c.drawString(x, y, line)
                y -= small_font_size + 1
        
        y -= 12  # More spacing between languages


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

