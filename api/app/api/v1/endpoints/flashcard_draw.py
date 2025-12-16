"""
PDF drawing utilities for flashcard export.
"""
import logging
from io import BytesIO
from typing import List, Optional, Tuple
from PIL import Image
from reportlab.lib.pagesizes import A5
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen.textobject import PDFTextObject

from app.models.models import Concept, Lemma, Topic
from .flashcard_export_helpers import (
    register_unicode_fonts,
    register_flashcard_fonts,
    download_image,
    get_language_flag_image_path,
    decode_html_entities,
    apply_rounded_corners,
    should_use_unicode_font,
    process_arabic_text,
    contains_arabic_characters,
)

logger = logging.getLogger(__name__)


# ============================================================================
# PDF Drawing Utilities
# ============================================================================

def draw_card_side(
    c: canvas.Canvas,
    concept: Concept,
    lemmas: List[Lemma],
    languages: List[str],
    topic: Optional[Topic] = None,
    offset_x: float = 0,
    offset_y: float = 0,
    include_image: bool = True,
    include_title: bool = True,
    include_ipa: bool = True,
    include_description: bool = True,
    page_size: Optional[Tuple[float, float]] = None,
):
    """Draw one side of a flashcard (supports A5 or A6 size).
    
    Args:
        c: Canvas to draw on
        concept: Concept to draw
        lemmas: List of lemmas for the concept
        languages: List of language codes to display
        topic: Optional topic
        offset_x: X offset from top-left corner (for positioning on A4 page)
        offset_y: Y offset from top-left corner (for positioning on A4 page)
        include_image: Whether to include the concept image
        include_title: Whether to include the lemma title (term) for each language
        include_ipa: Whether to include IPA pronunciation for each lemma
        include_description: Whether to include description for each lemma
        page_size: Optional page size tuple (width, height) in points. If not provided, 
                   will be determined from canvas pagesize.
    """
    # Get canvas pagesize to determine card dimensions
    # Use provided page_size or try to get from canvas, fallback to A5
    if page_size is not None:
        width, height = page_size
    else:
        try:
            # Canvas has pagesize as a property (protected member, but necessary to get page dimensions)
            pagesize = c._pagesize  # pyright: ignore[reportAttributeAccessIssue, reportPrivateUsage]
            width, height = pagesize
        except (AttributeError, TypeError):
            # Fallback to A5 if pagesize cannot be determined
            width, height = A5
    
    # Use A5 as reference size for scaling calculations
    # A5 dimensions: 148mm x 210mm = 419.53 x 595.28 points (at 72 DPI)
    ref_width, _ = A5
    
    # Calculate scale factor based on width ratio (width is primary dimension for scaling)
    scale_factor = width / ref_width
    
    # Scale all dimensions proportionally
    # Base values (for A5 reference size)
    base_margin = 10 * mm
    base_title_font_size = 14
    base_desc_font_size = 8
    base_icon_size = 16
    base_image_margin_top = 10 * mm
    base_image_margin_bottom = 20 * mm
    base_flag_spacing = 8
    base_line_spacing = 2
    base_language_spacing = 28
    base_corner_radius = 6 * mm
    
    # Scaled values
    margin = base_margin * scale_factor
    title_font_size = base_title_font_size * scale_factor
    desc_font_size = base_desc_font_size * scale_factor
    icon_size = base_icon_size * scale_factor
    image_margin_top = base_image_margin_top * scale_factor
    image_margin_bottom = base_image_margin_bottom * scale_factor
    flag_spacing = base_flag_spacing * scale_factor
    line_spacing = base_line_spacing * scale_factor
    language_spacing = base_language_spacing * scale_factor
    
    # Image width is 40% of page width
    image_width = width * 0.4
    
    # Register Unicode fonts for IPA symbols and emojis
    unicode_font, emoji_font = register_unicode_fonts()
    title_font, desc_font, ipa_font = register_flashcard_fonts()
    
    # Log registered fonts for debugging
    registered_fonts = pdfmetrics.getRegisteredFontNames()
    logger.info("All registered fonts: %s", registered_fonts)
    logger.info(
        "Using fonts - Title: %s, Description: %s, IPA: %s, Unicode: %s, Emoji: %s",
        title_font, desc_font, ipa_font, unicode_font, emoji_font
    )
    if "ArabicFont" in registered_fonts:
        logger.info("ArabicFont is available for Arabic text rendering")
    else:
        logger.warning("ArabicFont is NOT registered - Arabic text may not render correctly!")
    
    # Clear background (at offset position)
    c.setFillColor(HexColor("#FFFFFF"))
    c.rect(offset_x, offset_y, width, height, fill=1, stroke=0)
    
    # Topic icon at top right (subtle) - use emoji font if available
    if topic and topic.icon:
        icon_drawn = False
        if emoji_font and emoji_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(emoji_font, icon_size)
                c.setFillColor(HexColor("#CCCCCC"))  # Subtle gray
                icon_width = c.stringWidth(topic.icon, emoji_font, icon_size)
                icon_x = offset_x + width - margin - icon_width
                icon_y = offset_y + height - margin - icon_size
                c.drawString(icon_x, icon_y, topic.icon)
                icon_drawn = True
            except Exception as e:
                logger.debug("Failed to draw topic icon with emoji font: %s", str(e))
        
        if not icon_drawn and unicode_font and unicode_font in pdfmetrics.getRegisteredFontNames():
            try:
                c.setFont(unicode_font, icon_size)
                c.setFillColor(HexColor("#CCCCCC"))  # Subtle gray
                icon_width = c.stringWidth(topic.icon, unicode_font, icon_size)
                icon_x = offset_x + width - margin - icon_width
                icon_y = offset_y + height - margin - icon_size
                c.drawString(icon_x, icon_y, topic.icon)
            except Exception as e:
                logger.debug("Failed to draw topic icon with unicode font: %s", str(e))
    
    y = offset_y + height - margin
    
    # Image at the top (centered) - width is 50% of page width
    # Calculate height based on aspect ratio, but limit to reasonable maximum
    max_image_height = height * 0.4  # Max 40% of page height
    
    # Add space above image (only if image will be drawn)
    if include_image:
        y -= image_margin_top
    
    if include_image and concept.image_url:
        image_data = download_image(concept.image_url)
        if image_data:
            try:
                # Open with PIL to resize
                pil_image = Image.open(image_data)
                # Image width is 50% of page width (as requested)
                max_width = image_width
                
                # Maintain aspect ratio
                img_width, img_height = pil_image.size
                aspect_ratio = img_width / img_height
                
                # Calculate dimensions: width is fixed at 50% of page, height scales
                new_width = max_width
                new_height = max_width / aspect_ratio
                
                # Limit height if too tall
                if new_height > max_image_height:
                    new_height = max_image_height
                    new_width = max_image_height * aspect_ratio
                
                # Calculate target display size in pixels (ReportLab uses points, 1 point = 1/72 inch)
                target_width_px = int(new_width)
                target_height_px = int(new_height)
                
                # Supersample for sharper output: render at 3x resolution and let PDF scale down
                # This improves quality without making the image bigger visually
                supersample_factor = 3
                render_width_px = max(int(target_width_px * supersample_factor), 1)
                render_height_px = max(int(target_height_px * supersample_factor), 1)
                
                # Resize with high-quality resampling to supersampled size
                if pil_image.size != (render_width_px, render_height_px):
                    pil_image = pil_image.resize((render_width_px, render_height_px), Image.Resampling.LANCZOS)
                
                # Add rounded corners using a mask
                # Scale corner radius proportionally with page size
                corner_radius_scaled = base_corner_radius * scale_factor
                # Convert to pixels for the supersampled image
                corner_radius_px = int((corner_radius_scaled / width) * new_width * supersample_factor)
                # Ensure reasonable radius (scaled appropriately for supersampled image)
                min_radius = 6 * supersample_factor
                max_radius = 30 * supersample_factor * scale_factor
                corner_radius_px = max(min_radius, min(corner_radius_px, max_radius))
                
                # Apply rounded corners using the helper function
                pil_image = apply_rounded_corners(pil_image, corner_radius_px)
                
                # Save to BytesIO with full quality (PNG for transparency support)
                img_buffer = BytesIO()
                # Save with no compression for maximum quality
                pil_image.save(img_buffer, format="PNG", compress_level=0, optimize=False)
                img_buffer.seek(0)
                
                # Draw image centered (rounded corners are already applied via mask)
                img_x = offset_x + (width - new_width) / 2
                img_y = y - new_height
                # mask='auto' ensures the PNG alpha (rounded corners) is respected by reportlab
                c.drawImage(ImageReader(img_buffer), img_x, img_y, width=new_width, height=new_height, mask='auto')
                y = img_y - image_margin_bottom  # More spacing below image
            except Exception as e:
                logger.warning("Failed to draw image for concept %d: %s", concept.id, str(e))
                # Reserve space even if image fails (use estimated height)
                estimated_image_height = image_width / 1.5  # Assume 1.5:1 aspect ratio
                y -= estimated_image_height + image_margin_bottom
    
    # Draw lemmas for each language
    for lang_code in languages:
        # Find lemma for this language
        lemma = next((l for l in lemmas if l.language_code.lower() == lang_code.lower()), None)
        if not lemma:
            continue
        
        #if y < offset_y + margin + 30 * mm:  # Not enough space
        #    break
        
        # Translation (main term) - centered
        if include_title:
            # Load language flag image and draw it before title text
            translation_text = decode_html_entities(lemma.term)
            
            # Process Arabic text for proper rendering
            if should_use_unicode_font(lang_code, translation_text):
                translation_text = process_arabic_text(translation_text)
            
            # Get language flag image
            flag_image_path = get_language_flag_image_path(lang_code)
            flag_image_data = None
            flag_width = 0
            # Keep flag height proportional to title font size
            flag_height = title_font_size * 0.85
            
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
                    # Supersample for sharper output: render at 3x target and let PDF scale down
                    target_width_px = max(int(flag_width * 3), 1)
                    target_height_px = max(int(flag_height * 3), 1)
                    if pil_flag.size != (target_width_px, target_height_px):
                        pil_flag = pil_flag.resize((target_width_px, target_height_px), Image.Resampling.LANCZOS)
                    
                    # Apply rounded corners to flag image
                    # Use a smaller corner radius for flags (scaled by supersample factor)
                    flag_corner_radius_px = max(2 * 3, min(int(flag_height * 0.15 * 3), 4 * 3))  # 15% of height, max 8px, scaled by 3x
                    logger.info(flag_corner_radius_px)
                    pil_flag = apply_rounded_corners(pil_flag, flag_corner_radius_px)
                    
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
            
            # Determine which font to use for this text (use Arabic font for Arabic, Unicode for others)
            use_unicode_for_title = should_use_unicode_font(lang_code, translation_text)
            if use_unicode_for_title:
                # For Arabic, prefer Arabic font, then Unicode font, then fallback
                registered_fonts = pdfmetrics.getRegisteredFontNames()
                logger.debug("Registered fonts for Arabic text: %s", registered_fonts)
                if "ArabicFont" in registered_fonts:
                    title_font_to_use = "ArabicFont"
                    logger.info("Using ArabicFont for Arabic text (lang: %s): %s", lang_code, translation_text[:50])
                elif unicode_font and unicode_font in registered_fonts:
                    title_font_to_use = unicode_font
                    logger.warning("ArabicFont not found, using Unicode font '%s' for Arabic text (lang: %s): %s", 
                                 unicode_font, lang_code, translation_text[:50])
                else:
                    # Fallback: try to use any registered Unicode-supporting font
                    unicode_candidates = [f for f in registered_fonts if 'Unicode' in f or 'Noto' in f or 'Arial' in f or 'Arabic' in f]
                    if unicode_candidates:
                        title_font_to_use = unicode_candidates[0]
                        logger.warning("Arabic font not found, using fallback: %s for Arabic text (lang: %s)", title_font_to_use, lang_code)
                    else:
                        title_font_to_use = title_font
                        logger.error("No Unicode font available for Arabic text (lang: %s), using default font (may not render correctly): %s", 
                                   lang_code, title_font_to_use)
            else:
                title_font_to_use = title_font
            
            # Word wrap for translation text (accounting for flag image)
            c.setFont(title_font_to_use, title_font_size)
            words = translation_text.split()
            lines = []
            current_line = ""
            current_flag_spacing = flag_spacing if flag_image_data else 0
            max_width_text = width - 2 * margin - flag_width - current_flag_spacing
            
            for word in words:
                test_line = f"{current_line} {word}".strip()
                if c.stringWidth(test_line, title_font_to_use, title_font_size) <= max_width_text:
                    current_line = test_line
                else:
                    if current_line:
                        lines.append(current_line)
                    current_line = word
            
            if current_line:
                lines.append(current_line)
            
            # Draw translation lines with flag image prefix
            min_y_threshold = offset_y + margin + (20 * mm * scale_factor)
            for line_idx, line in enumerate(lines):
                if y < min_y_threshold:
                    break
                
                # Calculate total width (flag + space + text)
                text_width = c.stringWidth(line, title_font_to_use, title_font_size)
                total_width = flag_width + current_flag_spacing + text_width if flag_image_data else text_width
                
                # Center the entire line (flag + text)
                line_x = offset_x + (width - total_width) / 2
                
                # Draw flag image (only on first line)
                if line_idx == 0 and flag_image_data:
                    try:
                        # Align flag slightly below the top of the text (cap height) for better visual alignment
                        ascent = pdfmetrics.getAscent(title_font_to_use) * title_font_size / 1000.0
                        # Position flag slightly lower - offset by a small amount (scaled with font size)
                        offset = title_font_size * 0.22
                        flag_y = y + ascent - flag_height - offset
                        c.drawImage(ImageReader(flag_image_data), line_x, flag_y, width=flag_width, height=flag_height, mask='auto')
                        logger.debug(
                            "Drew flag image for %s at (%.2f, %.2f) with size (%.2f, %.2f) | ascent=%.2f",
                            lang_code, line_x, flag_y, flag_width, flag_height, ascent
                        )
                    except Exception as e:
                        logger.warning("Failed to draw language flag image: %s", str(e))
                
                # Draw text
                c.setFont(title_font_to_use, title_font_size)
                c.setFillColor(HexColor("#000000"))
                text_x = line_x + flag_width + current_flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                
                # For Arabic/RTL text, ensure font is set and use appropriate rendering method
                if use_unicode_for_title and contains_arabic_characters(line):
                    # Verify font is available
                    if title_font_to_use not in pdfmetrics.getRegisteredFontNames() and title_font_to_use not in ["Helvetica", "Helvetica-Bold", "Times-Roman", "Courier"]:
                        logger.error("Font '%s' not available for Arabic text! Available: %s", 
                                   title_font_to_use, pdfmetrics.getRegisteredFontNames())
                        # Fallback to Unicode font if available
                        if unicode_font and unicode_font in pdfmetrics.getRegisteredFontNames():
                            title_font_to_use = unicode_font
                            logger.warning("Falling back to Unicode font: %s", unicode_font)
                        else:
                            logger.error("No suitable font found for Arabic text!")
                    
                    try:
                        # Use drawString for Arabic - ReportLab handles it correctly with proper font
                        c.setFont(title_font_to_use, title_font_size)
                        c.setFillColor(HexColor("#000000"))
                        c.drawString(text_x, y, line)
                        logger.debug("Drew Arabic text with font '%s': %s", title_font_to_use, line[:30])
                    except Exception as e:
                        logger.error("Failed to draw Arabic text: %s", str(e))
                        import traceback
                        logger.debug("Traceback: %s", traceback.format_exc())
                        # Last resort fallback
                        try:
                            c.setFont("Helvetica", title_font_size)
                            c.drawString(text_x, y, line)
                        except:
                            pass
                else:
                    c.drawString(text_x, y, line)
                y -= title_font_size + line_spacing  # Scaled spacing under each line

            y -= line_spacing  # Scaled spacing before IPA
        elif not include_title and (include_ipa or include_description):
            # Add some spacing if title is not included but other elements will be
            y -= 5 * scale_factor
        
        # IPA - centered, using Unicode font, same size as description
        min_y_for_ipa = offset_y + margin + (15 * mm * scale_factor)
        if include_ipa and lemma.ipa and y > min_y_for_ipa:
            ipa_text = f"/{decode_html_entities(lemma.ipa)}/"
            ipa_drawn = False
            
            # Built-in fonts that are always available in ReportLab
            builtin_fonts = ["Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
                            "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic",
                            "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"]
            
            ipa_font_to_use = ipa_font or unicode_font
            
            # Try to use the selected font (either registered TTF or built-in)
            if ipa_font_to_use:
                # Check if it's a registered font or a built-in font
                is_registered = ipa_font_to_use in pdfmetrics.getRegisteredFontNames()
                is_builtin = ipa_font_to_use in builtin_fonts
                
                if is_registered or is_builtin:
                    try:
                        c.setFont(ipa_font_to_use, desc_font_size)
                        c.setFillColor(HexColor("#aaaaaa"))
                        ipa_width = c.stringWidth(ipa_text, ipa_font_to_use, desc_font_size)
                        ipa_x = offset_x + (width - ipa_width) / 2
                        c.drawString(ipa_x, y, ipa_text)
                        ipa_drawn = True
                        logger.debug("Drew IPA with font: %s", ipa_font_to_use)
                    except Exception as e:
                        logger.debug("Failed to draw IPA with font %s: %s", ipa_font_to_use, str(e))
            
            # Fallback to Helvetica if the preferred font didn't work
            if not ipa_drawn:
                try:
                    c.setFont("Helvetica", desc_font_size)
                    c.setFillColor(HexColor("#aaaaaa"))
                    ipa_width = c.stringWidth(ipa_text, "Helvetica", desc_font_size)
                    ipa_x = offset_x + (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                    ipa_drawn = True
                    logger.debug("Drew IPA with Helvetica fallback")
                except Exception as e:
                    logger.warning("Failed to draw IPA with Helvetica: %s", str(e))
            
            if ipa_drawn:
                y -= desc_font_size + (10 * scale_factor)  # Scaled space before description
        
        # Description - wrapped in container for better text wrapping
        min_y_for_desc = offset_y + margin + (10 * mm * scale_factor)
        if include_description and lemma.description and y > min_y_for_desc:
            desc = decode_html_entities(lemma.description)
            
            # Process Arabic text for proper rendering
            if should_use_unicode_font(lang_code, desc):
                desc = process_arabic_text(desc)
            
            # Determine which font to use for description (use Arabic font for Arabic, Unicode for others)
            use_unicode_for_desc = should_use_unicode_font(lang_code, desc)
            if use_unicode_for_desc:
                # For Arabic, prefer Arabic font, then Unicode font, then fallback
                registered_fonts = pdfmetrics.getRegisteredFontNames()
                logger.debug("Registered fonts for Arabic description: %s", registered_fonts)
                if "ArabicFont" in registered_fonts:
                    desc_font_to_use = "ArabicFont"
                    logger.info("Using ArabicFont for Arabic description (lang: %s): %s", lang_code, desc[:50])
                elif unicode_font and unicode_font in registered_fonts:
                    desc_font_to_use = unicode_font
                    logger.warning("ArabicFont not found, using Unicode font '%s' for Arabic description (lang: %s): %s", 
                                 unicode_font, lang_code, desc[:50])
                else:
                    # Fallback: try to use any registered Unicode-supporting font
                    unicode_candidates = [f for f in registered_fonts if 'Unicode' in f or 'Noto' in f or 'Arial' in f or 'Arabic' in f]
                    if unicode_candidates:
                        desc_font_to_use = unicode_candidates[0]
                        logger.warning("Arabic font not found for description, using fallback: %s for Arabic text (lang: %s)", desc_font_to_use, lang_code)
                    else:
                        desc_font_to_use = desc_font
                        logger.error("No Unicode font available for Arabic description (lang: %s), using default font (may not render correctly): %s", 
                                   lang_code, desc_font_to_use)
            else:
                desc_font_to_use = desc_font
            
            # If title is not included, show flag and use black color but keep smaller font
            if not include_title:
                # Load language flag image (same logic as for title, but sized for desc font)
                flag_image_path = get_language_flag_image_path(lang_code)
                flag_image_data = None
                flag_width = 0
                flag_height = desc_font_size * 1.5
                
                if flag_image_path and flag_image_path.exists():
                    try:
                        logger.debug("Loading flag image for %s from %s", lang_code, flag_image_path)
                        pil_flag = Image.open(flag_image_path)
                        logger.debug("Flag image loaded: %dx%d pixels", pil_flag.width, pil_flag.height)
                        flag_aspect = pil_flag.width / pil_flag.height
                        flag_width = flag_height * flag_aspect
                        logger.debug("Flag image will be rendered at %fx%f points", flag_width, flag_height)
                        target_width_px = max(int(flag_width * 3), 1)
                        target_height_px = max(int(flag_height * 3), 1)
                        if pil_flag.size != (target_width_px, target_height_px):
                            pil_flag = pil_flag.resize((target_width_px, target_height_px), Image.Resampling.LANCZOS)
                        
                        flag_corner_radius_px = max(2 * 3, min(int(flag_height * 0.15 * 3), 4 * 3))
                        pil_flag = apply_rounded_corners(pil_flag, flag_corner_radius_px)
                        
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
                
                # Set flag spacing after flag image is loaded
                desc_flag_spacing = flag_spacing if flag_image_data else 0
                
                # Use description font size but black color when title is not included
                c.setFont(desc_font_to_use, desc_font_size)
                c.setFillColor(HexColor("#000000"))  # Black color, same as title
                
                # Use 80% width container (same as normal description)
                desc_container_width = (width - 2 * margin) * 0.8
                # Account for flag in the 80% width
                max_width_text = desc_container_width - flag_width - desc_flag_spacing
                
                words = desc.split()
                desc_lines = []
                current_line = ""
                
                for word in words:
                    test_line = f"{current_line} {word}".strip()
                    if c.stringWidth(test_line, desc_font_to_use, desc_font_size) <= max_width_text:
                        current_line = test_line
                    else:
                        if current_line:
                            desc_lines.append(current_line)
                        current_line = word
                
                if current_line:
                    desc_lines.append(current_line)
                
                # Draw description lines with flag image prefix
                max_desc_lines = int((y - offset_y - margin) / (desc_font_size + line_spacing))
                min_y_for_desc_lines = offset_y + margin + (5 * mm * scale_factor)
                for line_idx, line in enumerate(desc_lines[:max_desc_lines]):
                    if y < min_y_for_desc_lines:
                        break
                    
                    # Calculate total width (flag + space + text) within 80% container
                    text_width = c.stringWidth(line, desc_font_to_use, desc_font_size)
                    total_width = flag_width + desc_flag_spacing + text_width if flag_image_data else text_width
                    
                    # Center the entire line (flag + text) within the 80% container
                    container_x = offset_x + (width - desc_container_width) / 2
                    line_x = container_x + (desc_container_width - total_width) / 2 if flag_image_data else container_x + (desc_container_width - text_width) / 2
                    
                    # Draw flag image (only on first line)
                    if line_idx == 0 and flag_image_data:
                        try:
                            ascent = pdfmetrics.getAscent(desc_font_to_use) * desc_font_size / 1000.0
                            offset = desc_font_size * 0.22
                            flag_y = y + ascent - flag_height - offset
                            c.drawImage(ImageReader(flag_image_data), line_x, flag_y, width=flag_width, height=flag_height, mask='auto')
                            logger.debug(
                                "Drew flag image for description %s at (%.2f, %.2f) with size (%.2f, %.2f)",
                                lang_code, line_x, flag_y, flag_width, flag_height
                            )
                        except Exception as e:
                            logger.warning("Failed to draw language flag image: %s", str(e))
                    
                    # Draw text
                    c.setFont(desc_font_to_use, desc_font_size)
                    c.setFillColor(HexColor("#000000"))
                    text_x = line_x + flag_width + desc_flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                    
                    # For Arabic/RTL text, use text object for better rendering
                    if use_unicode_for_desc and contains_arabic_characters(line):
                        try:
                            textobj = c.beginText()
                            textobj.setFont(desc_font_to_use, desc_font_size)
                            textobj.setFillColor(HexColor("#000000"))
                            textobj.setTextOrigin(text_x, y)
                            textobj.textLine(line)
                            c.drawText(textobj)
                        except Exception as e:
                            logger.warning("Failed to draw Arabic description with text object, falling back: %s", str(e))
                            c.drawString(text_x, y, line)
                    else:
                        c.drawString(text_x, y, line)
                    y -= desc_font_size + line_spacing
            else:
                # Title is included, use normal description styling
                c.setFont(desc_font_to_use, desc_font_size)
                c.setFillColor(HexColor("#999999"))  # Grey color
                
                # Use narrower width for description container (80% of available width)
                desc_container_width = (width - 2 * margin) * 0.7
                
                # Word wrap description within container
                words = desc.split()
                desc_lines = []
                current_line = ""
                
                for word in words:
                    test_line = f"{current_line} {word}".strip()
                    if c.stringWidth(test_line, desc_font_to_use, desc_font_size) <= desc_container_width:
                        current_line = test_line
                    else:
                        if current_line:
                            desc_lines.append(current_line)
                        current_line = word
                
                if current_line:
                    desc_lines.append(current_line)
                
                # Draw description lines (centered within container, limit to available space)
                max_desc_lines = int((y - offset_y - margin) / (desc_font_size + line_spacing))
                min_y_for_desc_lines = offset_y + margin + (5 * mm * scale_factor)
                for line in desc_lines[:max_desc_lines]:
                    if y < min_y_for_desc_lines:
                        break
                    line_width = c.stringWidth(line, desc_font_to_use, desc_font_size)
                    line_x = offset_x + (width - line_width) / 2
                    
                    # For Arabic/RTL text, use text object for better rendering
                    if use_unicode_for_desc and contains_arabic_characters(line):
                        try:
                            textobj = c.beginText()
                            textobj.setFont(desc_font_to_use, desc_font_size)
                            textobj.setFillColor(HexColor("#999999"))
                            textobj.setTextOrigin(line_x, y)
                            textobj.textLine(line)
                            c.drawText(textobj)
                        except Exception as e:
                            logger.warning("Failed to draw Arabic description with text object, falling back: %s", str(e))
                            c.drawString(line_x, y, line)
                    else:
                        c.drawString(line_x, y, line)
                    y -= desc_font_size + line_spacing
        
        y -= language_spacing  # Scaled spacing between languages
