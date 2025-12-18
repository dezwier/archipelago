"""
Flashcard service for PDF export utilities.
"""
import logging
import os
import html
from io import BytesIO
from pathlib import Path
from typing import Optional
import requests
from PIL import Image, ImageDraw
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

from app.core.config import settings

logger = logging.getLogger(__name__)


# Font registration state
_unicode_font_registered = False
_unicode_font_name = "Helvetica"  # Fallback
_arabic_font_registered = False
_arabic_font_name = None  # Separate font for Arabic text
_emoji_font_registered = False
_emoji_font_name = None
_custom_fonts_registered = False
_title_font_name = "Helvetica-Bold"
_description_font_name = "Helvetica"
_ipa_font_name = None


# ============================================================================
# Font Utilities
# ============================================================================

def _build_font_search_paths():
    """Common font search paths (bundled first, then system)."""
    api_root = Path(__file__).parent.parent.parent
    bundled_fonts_dir = api_root / "fonts"
    assets_fonts_dir = api_root / "assets" / "fonts"
    
    alternative_paths = [
        assets_fonts_dir,  # Check assets/fonts directory
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
                            # Also try pattern without extension (since font_name includes extension)
                            font_name_no_ext = font_name.rsplit('.', 1)[0] if '.' in font_name else font_name
                            if (fnmatch.fnmatch(font_name, pattern + ext) or 
                                fnmatch.fnmatch(font_name, pattern + '*' + ext) or 
                                fnmatch.fnmatch(font_name, pattern + ext.replace('.', '')) or
                                fnmatch.fnmatch(font_name, pattern) or
                                fnmatch.fnmatch(font_name_no_ext, pattern.rstrip('*'))):
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
    global _unicode_font_registered, _unicode_font_name, _arabic_font_registered, _arabic_font_name, _emoji_font_registered, _emoji_font_name
    
    # Always try to register Arabic font if not already registered
    if not _arabic_font_registered:
        search_paths = _build_font_search_paths()
        logger.debug("Searching for Arabic font in paths: %s", search_paths)
        
        # Search specifically for Arabic fonts first
        arabic_patterns = [
            "NotoSansArabic*",
            "NotoSans*Arabic*",
            "*Arabic*",
        ]
        
        arabic_fonts = find_font_files(search_paths, arabic_patterns)
        logger.info("Found Arabic font candidates: %s", arabic_fonts)
        
        # Also check for exact filename match in common locations
        api_root = Path(__file__).parent.parent.parent
        exact_paths = [
            api_root / "assets" / "fonts" / "NotoSansArabic-Regular.ttf",
            api_root / "fonts" / "NotoSansArabic-Regular.ttf",
            Path("/app/assets/fonts/NotoSansArabic-Regular.ttf"),
            Path("/app/fonts/NotoSansArabic-Regular.ttf"),
        ]
        
        for exact_path in exact_paths:
            if exact_path.exists() and str(exact_path) not in arabic_fonts:
                arabic_fonts.insert(0, str(exact_path))
                logger.info("Found Arabic font at exact path: %s", exact_path)
        
        # Register Arabic font if found
        for font_path in arabic_fonts:
            if not os.path.exists(font_path):
                logger.debug("Arabic font path does not exist: %s", font_path)
                continue
            try:
                font_size = os.path.getsize(font_path)
                if font_size < 10000:
                    logger.warning("Arabic font file too small (%d bytes), skipping: %s", font_size, font_path)
                    continue
                # Check if font is already registered with this name
                if "ArabicFont" in pdfmetrics.getRegisteredFontNames():
                    logger.info("ArabicFont already registered, skipping")
                    _arabic_font_name = "ArabicFont"
                    _arabic_font_registered = True
                    break
                pdfmetrics.registerFont(TTFont("ArabicFont", font_path))
                _arabic_font_name = "ArabicFont"
                _arabic_font_registered = True
                logger.info("Successfully registered Arabic font: %s (size: %d KB)", font_path, font_size // 1024)
                break
            except Exception as e:
                logger.warning("Failed to register Arabic font %s: %s", font_path, str(e))
                import traceback
                logger.debug("Traceback: %s", traceback.format_exc())
                continue
    
    if _unicode_font_registered:
        return _unicode_font_name, _emoji_font_name
    
    search_paths = _build_font_search_paths()
    
    # Try to find Unicode-supporting fonts (prioritize Arabic-supporting fonts)
    unicode_patterns = [
        "NotoSansArabic*",  # Prioritize Arabic-specific fonts
        "NotoSans*Arabic*",
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
    logger.debug("Found Unicode font candidates: %s", unicode_fonts)
    
    # Separate Arabic fonts from general Unicode fonts
    arabic_fonts = [f for f in unicode_fonts if 'Arabic' in f and 'Noto' in f]
    general_unicode_fonts = [f for f in unicode_fonts if 'Arabic' not in f]
    
    # Prioritize general Unicode fonts: Arial Unicode first, then Noto, then DejaVu
    general_unicode_fonts.sort(key=lambda x: (
        0 if 'Arial Unicode' in x or 'ArialUni' in x else
        1 if 'Noto' in x else
        2 if 'DejaVu' in x else 3
    ))
    
    # Register Arabic font separately if available (if not already registered above)
    if not _arabic_font_registered and arabic_fonts:
        for font_path in arabic_fonts:
            if not os.path.exists(font_path):
                continue
            try:
                font_size = os.path.getsize(font_path)
                if font_size < 10000:
                    logger.warning("Arabic font file too small (%d bytes), skipping: %s", font_size, font_path)
                    continue
                pdfmetrics.registerFont(TTFont("ArabicFont", font_path))
                _arabic_font_name = "ArabicFont"
                _arabic_font_registered = True
                logger.info("Successfully registered Arabic font: %s (size: %d KB)", font_path, font_size // 1024)
                break
            except Exception as e:
                logger.warning("Failed to register Arabic font %s: %s", font_path, str(e))
                continue
    
    # Register general Unicode font for IPA and other Unicode text
    for font_path in general_unicode_fonts:
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
    
    # If no general Unicode font found but we have Arabic font, use it as fallback
    if not _unicode_font_registered and _arabic_font_registered:
        _unicode_font_name = _arabic_font_name
        _unicode_font_registered = True
        logger.info("Using Arabic font as Unicode font fallback")
    
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


# ============================================================================
# Text Utilities
# ============================================================================

def decode_html_entities(text: str) -> str:
    """Decode HTML entities in text."""
    if not text:
        return ""
    return html.unescape(text)


def contains_arabic_characters(text: str) -> bool:
    """Check if text contains Arabic characters."""
    if not text:
        return False
    # Arabic Unicode range: U+0600 to U+06FF
    return any('\u0600' <= char <= '\u06FF' for char in text)


def is_arabic_language(lang_code: str) -> bool:
    """Check if language code is Arabic."""
    return lang_code.lower() == 'ar'


def should_use_unicode_font(lang_code: str, text: str) -> bool:
    """Determine if Unicode font should be used for this text."""
    return is_arabic_language(lang_code) or contains_arabic_characters(text)


def process_arabic_text(text: str) -> str:
    """
    Process Arabic text for proper rendering in PDF.
    Reshapes Arabic characters and applies bidirectional text algorithm.
    
    Args:
        text: Arabic text to process
    
    Returns:
        Processed text ready for PDF rendering
    """
    if not text:
        return text
    
    # Only process if text contains Arabic characters
    if not contains_arabic_characters(text):
        return text
    
    try:
        import arabic_reshaper
        from bidi.algorithm import get_display
        
        # Reshape Arabic text (handles character forms based on position)
        reshaped_text = arabic_reshaper.reshape(text)
        # Apply bidirectional algorithm for RTL display
        bidi_text = get_display(reshaped_text)
        logger.debug("Processed Arabic text: '%s' -> '%s'", text[:50], bidi_text[:50])
        return bidi_text
    except ImportError:
        logger.warning("arabic-reshaper or python-bidi not installed. Arabic text may not render correctly.")
        logger.warning("Install with: pip install arabic-reshaper python-bidi")
        return text
    except Exception as e:
        logger.warning("Failed to process Arabic text: %s", str(e))
        return text


# ============================================================================
# Image Utilities
# ============================================================================

def get_image_path(image_url: Optional[str]) -> Optional[Path]:
    """Get local file path for an image URL."""
    if not image_url:
        return None
    
    # If it's a relative path starting with /assets/, get the local file
    if image_url.startswith("/assets/"):
        if settings.assets_path:
            assets_dir = Path(settings.assets_path)
        else:
            api_root = Path(__file__).parent.parent.parent
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
    api_root = Path(__file__).parent.parent.parent
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


def apply_rounded_corners(image: Image.Image, corner_radius_px: int) -> Image.Image:
    """
    Apply rounded corners to a PIL Image using a mask.
    
    Args:
        image: PIL Image to apply rounded corners to
        corner_radius_px: Corner radius in pixels
    
    Returns:
        PIL Image with rounded corners applied (RGBA mode)
    """
    # Convert to RGBA to support transparency for rounded corners
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    
    # Ensure reasonable radius
    corner_radius_px = max(1, min(corner_radius_px, min(image.size) // 2))
    
    # Create mask for rounded corners
    width, height = image.size
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # Draw rounded rectangle - try the modern method first
    try:
        # PIL 9.0.0+ has rounded_rectangle
        if hasattr(draw, 'rounded_rectangle'):
            draw.rounded_rectangle(
                [(0, 0), (width - 1, height - 1)],
                radius=corner_radius_px,
                fill=255
            )
        else:
            raise AttributeError("rounded_rectangle not available")
    except (AttributeError, TypeError):
        # Fallback: create rounded rectangle manually
        # Fill main rectangle (excluding corners)
        draw.rectangle(
            [corner_radius_px, 0, width - corner_radius_px, height],
            fill=255
        )
        draw.rectangle(
            [0, corner_radius_px, width, height - corner_radius_px],
            fill=255
        )
        # Draw corner circles
        for x, y in [
            (corner_radius_px, corner_radius_px),  # top-left
            (width - corner_radius_px, corner_radius_px),  # top-right
            (corner_radius_px, height - corner_radius_px),  # bottom-left
            (width - corner_radius_px, height - corner_radius_px)  # bottom-right
        ]:
            draw.ellipse(
                [x - corner_radius_px, y - corner_radius_px,
                 x + corner_radius_px, y + corner_radius_px],
                fill=255
            )
    
    # Apply mask to image alpha channel
    image.putalpha(mask)
    
    return image

