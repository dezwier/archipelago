"""
PDF drawing utilities for flashcard export.
"""
import logging
from io import BytesIO
from typing import List, Optional
from PIL import Image
from reportlab.lib.pagesizes import A5
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics

from app.models.models import Concept, Lemma, Topic
from .flashcard_export_helpers import (
    register_unicode_fonts,
    register_flashcard_fonts,
    download_image,
    get_language_flag_image_path,
    decode_html_entities,
    apply_rounded_corners,
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
):
    """Draw one side of a flashcard (A5 size: 148 x 210 mm).
    
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
    """
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
    
    # Clear background (at offset position)
    c.setFillColor(HexColor("#FFFFFF"))
    c.rect(offset_x, offset_y, width, height, fill=1, stroke=0)
    
    # Topic icon at top right (subtle) - use emoji font if available
    if topic and topic.icon:
        icon_size = 16
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
    
    # Image at the top (centered) - with more spacing
    image_height = 60 * mm
    image_margin_top = 10 * mm  # Increased spacing above image
    image_margin_bottom = 20 * mm  # Increased spacing below image
    
    # Add space above image (only if image will be drawn)
    if include_image:
        y -= image_margin_top
    
    if include_image and concept.image_url:
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
                # Convert 8mm to pixels: 8mm as a proportion of the page width, then scale to image pixels
                # Scale corner radius by supersample factor to match the supersampled image
                corner_radius_px = int((6 * mm / width) * new_width * supersample_factor)
                # Ensure reasonable radius (scaled appropriately for supersampled image)
                corner_radius_px = max(6 * supersample_factor, min(corner_radius_px, 30 * supersample_factor))
                
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
        
        #if y < offset_y + margin + 30 * mm:  # Not enough space
        #    break
        
        # Translation (main term) - centered
        if include_title:
            # Load language flag image and draw it before title text
            translation_text = decode_html_entities(lemma.term)
            
            # Get language flag image
            flag_image_path = get_language_flag_image_path(lang_code)
            flag_image_data = None
            flag_width = 0
            # Keep flag height close to text; improve quality via supersampling
            flag_height = title_font_size * .85
            
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
                if y < offset_y + margin + 20 * mm:
                    break
                
                # Calculate total width (flag + space + text)
                text_width = c.stringWidth(line, title_font, title_font_size)
                total_width = flag_width + flag_spacing + text_width if flag_image_data else text_width
                
                # Center the entire line (flag + text)
                line_x = offset_x + (width - total_width) / 2
                
                # Draw flag image (only on first line)
                if line_idx == 0 and flag_image_data:
                    try:
                        # Align flag slightly below the top of the text (cap height) for better visual alignment
                        ascent = pdfmetrics.getAscent(title_font) * title_font_size / 1000.0
                        # Position flag slightly lower - offset by a small amount (about 10% of font size)
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
                c.setFont(title_font, title_font_size)
                c.setFillColor(HexColor("#000000"))
                text_x = line_x + flag_width + flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                c.drawString(text_x, y, line)
                y -= title_font_size + 2  # Slightly tighter spacing under each line

            y -= 1  # Less extra spacing before IPA
        elif not include_title and (include_ipa or include_description):
            # Add some spacing if title is not included but other elements will be
            y -= 5
        
        # IPA - centered, using Unicode font, same size as description
        if include_ipa and lemma.ipa and y > offset_y + margin + 15 * mm:
            ipa_text = f"/{decode_html_entities(lemma.ipa)}/"
            ipa_drawn = False
            ipa_font_to_use = ipa_font or unicode_font
            if ipa_font_to_use and ipa_font_to_use in pdfmetrics.getRegisteredFontNames():
                try:
                    c.setFont(ipa_font_to_use, desc_font_size)
                    c.setFillColor(HexColor("#aaaaaa"))
                    ipa_width = c.stringWidth(ipa_text, ipa_font_to_use, desc_font_size)
                    ipa_x = offset_x + (width - ipa_width) / 2
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
                    ipa_x = offset_x + (width - ipa_width) / 2
                    c.drawString(ipa_x, y, ipa_text)
                except Exception as e:
                    logger.debug("Failed to draw IPA with Helvetica: %s", str(e))
            y -= desc_font_size + 10  # More space before description
        
        # Description - wrapped in container for better text wrapping
        if include_description and lemma.description and y > offset_y + margin + 10 * mm:
            desc = decode_html_entities(lemma.description)
            
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
                
                # Use description font size but black color when title is not included
                c.setFont(desc_font, desc_font_size)
                c.setFillColor(HexColor("#000000"))  # Black color, same as title
                
                # Use 80% width container (same as normal description)
                desc_container_width = (width - 2 * margin) * 0.8
                flag_spacing = 8 if flag_image_data else 0
                # Account for flag in the 80% width
                max_width_text = desc_container_width - flag_width - flag_spacing
                
                words = desc.split()
                desc_lines = []
                current_line = ""
                
                for word in words:
                    test_line = f"{current_line} {word}".strip()
                    if c.stringWidth(test_line, desc_font, desc_font_size) <= max_width_text:
                        current_line = test_line
                    else:
                        if current_line:
                            desc_lines.append(current_line)
                        current_line = word
                
                if current_line:
                    desc_lines.append(current_line)
                
                # Draw description lines with flag image prefix
                max_desc_lines = int((y - offset_y - margin) / (desc_font_size + 2))
                for line_idx, line in enumerate(desc_lines[:max_desc_lines]):
                    if y < offset_y + margin + 5 * mm:
                        break
                    
                    # Calculate total width (flag + space + text) within 80% container
                    text_width = c.stringWidth(line, desc_font, desc_font_size)
                    total_width = flag_width + flag_spacing + text_width if flag_image_data else text_width
                    
                    # Center the entire line (flag + text) within the 80% container
                    container_x = offset_x + (width - desc_container_width) / 2
                    line_x = container_x + (desc_container_width - total_width) / 2 if flag_image_data else container_x + (desc_container_width - text_width) / 2
                    
                    # Draw flag image (only on first line)
                    if line_idx == 0 and flag_image_data:
                        try:
                            ascent = pdfmetrics.getAscent(desc_font) * desc_font_size / 1000.0
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
                    c.setFont(desc_font, desc_font_size)
                    c.setFillColor(HexColor("#000000"))
                    text_x = line_x + flag_width + flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                    c.drawString(text_x, y, line)
                    y -= desc_font_size + 2
            else:
                # Title is included, use normal description styling
                c.setFont(desc_font, desc_font_size)
                c.setFillColor(HexColor("#999999"))  # Grey color
                
                # Use narrower width for description container (80% of available width)
                desc_container_width = (width - 2 * margin) * 0.7
                
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
                max_desc_lines = int((y - offset_y - margin) / (desc_font_size + 2))
                for line in desc_lines[:max_desc_lines]:
                    if y < offset_y + margin + 5 * mm:
                        break
                    line_width = c.stringWidth(line, desc_font, desc_font_size)
                    line_x = offset_x + (width - line_width) / 2
                    c.drawString(line_x, y, line)
                    y -= desc_font_size + 2
        
        y -= 28  # More spacing between languages
