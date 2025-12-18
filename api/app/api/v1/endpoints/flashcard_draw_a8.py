"""
PDF drawing utilities for A8 landscape flashcard export.
A8 cards use a landscape layout with image on the left and content on the right.
"""
import logging
from io import BytesIO
from typing import List, Optional, Tuple
from PIL import Image
from reportlab.lib.pagesizes import A8
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor
from reportlab.pdfbase import pdfmetrics

from app.models.models import Concept, Lemma, Topic
from app.services.flashcard_service import (
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


def draw_card_side_a8_landscape(
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
    """Draw one side of an A8 flashcard in landscape layout.
    
    Landscape layout:
    - Image on the left, taking 1/3 of screen width with margin from border
    - Languages, title, IPA, description on the right 2/3rds
    
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
                   will be determined from canvas pagesize. For A8 landscape, width > height.
    """
    # Get canvas pagesize to determine card dimensions
    # Use provided page_size or try to get from canvas, fallback to A8
    if page_size is not None:
        width, height = page_size
    else:
        try:
            pagesize = c._pagesize  # pyright: ignore[reportAttributeAccessIssue, reportPrivateUsage]
            width, height = pagesize
        except (AttributeError, TypeError):
            # Fallback to A8 if pagesize cannot be determined
            # A8 landscape: swap dimensions (width > height)
            a8_portrait = A8
            width, height = a8_portrait[1], a8_portrait[0]  # Swap for landscape
    
    # Use A8 portrait as reference size for scaling calculations
    # A8 portrait dimensions: 52mm x 74mm = 147.40 x 209.76 points (at 72 DPI)
    # A8 landscape: 74mm x 52mm = 209.76 x 147.40 points
    ref_width_landscape = A8[1]  # Height becomes width in landscape
    
    # Calculate scale factor based on width ratio
    scale_factor = width / ref_width_landscape
    
    # Scale all dimensions proportionally
    # Base values (for A8 landscape reference size)
    base_margin = 7 * mm  # Smaller margin for A8
    base_title_font_size = 12  # Increased from 10
    base_icon_size = 12
    base_flag_spacing = 4
    base_line_spacing = 3  # Increased from 1.5 (more vertical spacing for title & description)
    base_language_spacing = 32
    base_corner_radius = 3 * mm
    
    # Scaled values
    margin = base_margin * scale_factor
    title_font_size = base_title_font_size * scale_factor
    # IPA font size is 50% of title font size
    ipa_font_size = title_font_size * 0.7
    # Description font size: 50% of title if title is present, 80% if not
    desc_font_size = title_font_size * (0.7 if include_title else 0.9)
    icon_size = base_icon_size * scale_factor
    flag_spacing = base_flag_spacing * scale_factor
    line_spacing = base_line_spacing * scale_factor
    language_spacing = base_language_spacing * scale_factor
    
    # Layout: Image at top (60% width, centered), content below
    image_width_percent = 0.80  # 70% of page width (increased from 50% to reduce side whitespace)
    image_margin_top = margin * 2  # Reduced from 2.5 (less whitespace above)
    image_margin_bottom = margin * 2  # Increased from 1.5 (more space between image and text)
    content_margin = margin * 0.95
    
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
    
    # ============================================================================
    # TOP SECTION: Image (50% width, centered)
    # ============================================================================
    y = offset_y + height - image_margin_top
    
    if include_image and concept.image_url:
        image_data = download_image(concept.image_url)
        if image_data:
            try:
                # Open with PIL to resize
                pil_image = Image.open(image_data)
                
                # Image width is 50% of page width
                max_width = width * image_width_percent
                max_image_height = height * 0.4  # Max 40% of page height
                
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
                
                # Calculate target display size in pixels
                target_width_px = int(new_width)
                target_height_px = int(new_height)
                
                # Supersample for sharper output
                supersample_factor = 3
                render_width_px = max(int(target_width_px * supersample_factor), 1)
                render_height_px = max(int(target_height_px * supersample_factor), 1)
                
                # Resize with high-quality resampling
                if pil_image.size != (render_width_px, render_height_px):
                    pil_image = pil_image.resize((render_width_px, render_height_px), Image.Resampling.LANCZOS)
                
                # Add rounded corners
                corner_radius_scaled = base_corner_radius * scale_factor
                corner_radius_px = int((corner_radius_scaled / width) * new_width * supersample_factor)
                min_radius = 4 * supersample_factor
                max_radius = 20 * supersample_factor * scale_factor
                corner_radius_px = max(min_radius, min(corner_radius_px, max_radius))
                
                pil_image = apply_rounded_corners(pil_image, corner_radius_px)
                
                # Save to BytesIO
                img_buffer = BytesIO()
                pil_image.save(img_buffer, format="PNG", compress_level=0, optimize=False)
                img_buffer.seek(0)
                
                # Center image horizontally
                image_x = offset_x + (width - new_width) / 2
                image_y = y - new_height
                c.drawImage(ImageReader(img_buffer), image_x, image_y, width=new_width, height=new_height, mask='auto')
                y = image_y - image_margin_bottom  # Move y below image
            except Exception as e:
                logger.warning("Failed to draw image for concept %d: %s", concept.id, str(e))
                # Reserve space even if image fails
                estimated_image_height = max_width / 1.5  # Assume 1.5:1 aspect ratio
                y -= estimated_image_height + image_margin_bottom
    
    # ============================================================================
    # CONTENT SECTION: Languages, Title, IPA, Description (centered)
    # ============================================================================
    content_available_width = width - 2 * content_margin

    if not include_image:
        y -= image_margin_bottom * 0.25

    # Draw lemmas for each language
    for lang_code in languages:
        # Find lemma for this language
        lemma = next((l for l in lemmas if l.language_code.lower() == lang_code.lower()), None)
        if not lemma:
            continue
        
        # Translation (main term) - left-aligned in right section
        if include_title:
            translation_text = decode_html_entities(lemma.term)
            
            # Process Arabic text for proper rendering
            if should_use_unicode_font(lang_code, translation_text):
                translation_text = process_arabic_text(translation_text)
            
            # Get language flag image
            flag_image_path = get_language_flag_image_path(lang_code)
            flag_image_data = None
            flag_width = 0
            flag_height = title_font_size * 0.85
            
            if flag_image_path and flag_image_path.exists():
                try:
                    pil_flag = Image.open(flag_image_path)
                    flag_aspect = pil_flag.width / pil_flag.height
                    flag_width = flag_height * flag_aspect
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
                except Exception as e:
                    logger.warning("Failed to load language flag image for %s: %s", lang_code, str(e))
                    flag_image_data = None
            
            # Determine which font to use
            use_unicode_for_title = should_use_unicode_font(lang_code, translation_text)
            if use_unicode_for_title:
                registered_fonts = pdfmetrics.getRegisteredFontNames()
                if "ArabicFont" in registered_fonts:
                    title_font_to_use = "ArabicFont"
                elif unicode_font and unicode_font in registered_fonts:
                    title_font_to_use = unicode_font
                else:
                    unicode_candidates = [f for f in registered_fonts if 'Unicode' in f or 'Noto' in f or 'Arial' in f or 'Arabic' in f]
                    title_font_to_use = unicode_candidates[0] if unicode_candidates else title_font
            else:
                title_font_to_use = title_font
            
            # Word wrap for translation text
            c.setFont(title_font_to_use, title_font_size)
            words = translation_text.split()
            lines = []
            current_line = ""
            current_flag_spacing = flag_spacing if flag_image_data else 0
            max_width_text = content_available_width - flag_width - current_flag_spacing
            
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
            
            # Draw translation lines with flag image prefix (centered)
            min_y_threshold = offset_y + margin + (10 * mm * scale_factor)
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
                        ascent = pdfmetrics.getAscent(title_font_to_use) * title_font_size / 1000.0
                        offset = title_font_size * 0.22
                        flag_y = y + ascent - flag_height - offset
                        c.drawImage(ImageReader(flag_image_data), line_x, flag_y, width=flag_width, height=flag_height, mask='auto')
                    except Exception as e:
                        logger.warning("Failed to draw language flag image: %s", str(e))
                
                # Draw text (centered with flag)
                c.setFont(title_font_to_use, title_font_size)
                c.setFillColor(HexColor("#000000"))
                text_x = line_x + flag_width + current_flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                
                if use_unicode_for_title and contains_arabic_characters(line):
                    try:
                        c.setFont(title_font_to_use, title_font_size)
                        c.setFillColor(HexColor("#000000"))
                        c.drawString(text_x, y, line)
                    except Exception as e:
                        logger.error("Failed to draw Arabic text: %s", str(e))
                        try:
                            c.setFont("Helvetica", title_font_size)
                            c.drawString(text_x, y, line)
                        except:
                            pass
                else:
                    c.drawString(text_x, y, line)
                y -= title_font_size + line_spacing
            
            y -= line_spacing
        elif not include_title and (include_ipa or include_description):
            y -= 3 * scale_factor
        
        # IPA - left-aligned, using Unicode font, with word wrapping
        min_y_for_ipa = offset_y + margin + (8 * mm * scale_factor)
        if include_ipa and lemma.ipa and y > min_y_for_ipa:
            ipa_text = f"/{decode_html_entities(lemma.ipa)}/"
            ipa_drawn = False
            
            builtin_fonts = ["Helvetica", "Helvetica-Bold", "Helvetica-Oblique", "Helvetica-BoldOblique",
                            "Times-Roman", "Times-Bold", "Times-Italic", "Times-BoldItalic",
                            "Courier", "Courier-Bold", "Courier-Oblique", "Courier-BoldOblique"]
            
            ipa_font_to_use = ipa_font or unicode_font
            
            # Determine which font to use
            if ipa_font_to_use:
                is_registered = ipa_font_to_use in pdfmetrics.getRegisteredFontNames()
                is_builtin = ipa_font_to_use in builtin_fonts
                
                if not (is_registered or is_builtin):
                    ipa_font_to_use = "Helvetica"  # Fallback
            
            # Use Helvetica as fallback if font not available
            if not ipa_font_to_use:
                ipa_font_to_use = "Helvetica"
            
            try:
                c.setFont(ipa_font_to_use, ipa_font_size)
                c.setFillColor(HexColor("#aaaaaa"))
                
                # Improved word wrap for IPA text - ensure it uses full available width
                # Split by spaces and wrap properly
                words = ipa_text.split()
                ipa_lines = []
                current_line = ""
                
                for word in words:
                    test_line = f"{current_line} {word}".strip() if current_line else word
                    if c.stringWidth(test_line, ipa_font_to_use, ipa_font_size) <= content_available_width:
                        current_line = test_line
                    else:
                        if current_line:
                            ipa_lines.append(current_line)
                        # If single word is too long, add it anyway (will overflow slightly but better than breaking IPA)
                        if c.stringWidth(word, ipa_font_to_use, ipa_font_size) > content_available_width:
                            ipa_lines.append(word)
                            current_line = ""
                        else:
                            current_line = word
                
                if current_line:
                    ipa_lines.append(current_line)
                
                # Draw IPA lines (centered) - ensure proper wrapping
                min_y_for_ipa_lines = offset_y + margin + (5 * mm * scale_factor)
                for line in ipa_lines:
                    if y < min_y_for_ipa_lines:
                        break
                    c.setFont(ipa_font_to_use, ipa_font_size)
                    c.setFillColor(HexColor("#aaaaaa"))
                    ipa_line_width = c.stringWidth(line, ipa_font_to_use, ipa_font_size)
                    ipa_x = offset_x + (width - ipa_line_width) / 2
                    c.drawString(ipa_x, y, line)
                    y -= ipa_font_size + line_spacing
                
                ipa_drawn = True
            except Exception as e:
                logger.warning("Failed to draw IPA: %s", str(e))
            
            if ipa_drawn:
                y -= (4 * scale_factor)  # Space before description
        
        # Description - left-aligned, wrapped
        if include_description and lemma.description:
            desc = decode_html_entities(lemma.description)
            
            # Process Arabic text for proper rendering
            if should_use_unicode_font(lang_code, desc):
                desc = process_arabic_text(desc)
            
            # Determine which font to use
            use_unicode_for_desc = should_use_unicode_font(lang_code, desc)
            if use_unicode_for_desc:
                registered_fonts = pdfmetrics.getRegisteredFontNames()
                if "ArabicFont" in registered_fonts:
                    desc_font_to_use = "ArabicFont"
                elif unicode_font and unicode_font in registered_fonts:
                    desc_font_to_use = unicode_font
                else:
                    unicode_candidates = [f for f in registered_fonts if 'Unicode' in f or 'Noto' in f or 'Arial' in f or 'Arabic' in f]
                    desc_font_to_use = unicode_candidates[0] if unicode_candidates else desc_font
            else:
                desc_font_to_use = desc_font
            
            # If title is not included, show flag and use black color
            if not include_title:
                flag_image_path = get_language_flag_image_path(lang_code)
                flag_image_data = None
                flag_width = 0
                flag_height = desc_font_size * 1.5
                
                if flag_image_path and flag_image_path.exists():
                    try:
                        pil_flag = Image.open(flag_image_path)
                        flag_aspect = pil_flag.width / pil_flag.height
                        flag_width = flag_height * flag_aspect
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
                    except Exception as e:
                        logger.warning("Failed to load language flag image for %s: %s", lang_code, str(e))
                        flag_image_data = None
                
                desc_flag_spacing = flag_spacing if flag_image_data else 0
                c.setFont(desc_font_to_use, desc_font_size)
                c.setFillColor(HexColor("#000000"))
                
                max_width_text = content_available_width - flag_width - desc_flag_spacing
                
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
                
                # Draw description lines with flag image prefix (centered)
                for line_idx, line in enumerate(desc_lines):
                    # Calculate total width (flag + space + text)
                    text_width = c.stringWidth(line, desc_font_to_use, desc_font_size)
                    total_width = flag_width + desc_flag_spacing + text_width if flag_image_data else text_width
                    
                    # Center the entire line (flag + text)
                    line_x = offset_x + (width - total_width) / 2
                    
                    # Draw flag image (only on first line)
                    if line_idx == 0 and flag_image_data:
                        try:
                            ascent = pdfmetrics.getAscent(desc_font_to_use) * desc_font_size / 1000.0
                            offset = desc_font_size * 0.22
                            flag_y = y + ascent - flag_height - offset
                            c.drawImage(ImageReader(flag_image_data), line_x, flag_y, width=flag_width, height=flag_height, mask='auto')
                        except Exception as e:
                            logger.warning("Failed to draw language flag image: %s", str(e))
                    
                    # Draw text (centered with flag)
                    c.setFont(desc_font_to_use, desc_font_size)
                    c.setFillColor(HexColor("#000000"))
                    text_x = line_x + flag_width + desc_flag_spacing if (line_idx == 0 and flag_image_data) else line_x
                    
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
                c.setFillColor(HexColor("#666666"))  # Darker grey color (was #999999)
                
                # Word wrap description
                words = desc.split()
                desc_lines = []
                current_line = ""
                
                for word in words:
                    test_line = f"{current_line} {word}".strip()
                    if c.stringWidth(test_line, desc_font_to_use, desc_font_size) <= content_available_width:
                        current_line = test_line
                    else:
                        if current_line:
                            desc_lines.append(current_line)
                        current_line = word
                
                if current_line:
                    desc_lines.append(current_line)
                
                # Draw description lines (centered)
                for line in desc_lines:
                    line_width = c.stringWidth(line, desc_font_to_use, desc_font_size)
                    line_x = offset_x + (width - line_width) / 2
                    
                    if use_unicode_for_desc and contains_arabic_characters(line):
                        try:
                            textobj = c.beginText()
                            textobj.setFont(desc_font_to_use, desc_font_size)
                            textobj.setFillColor(HexColor("#666666"))  # Darker grey color (was #999999)
                            textobj.setTextOrigin(line_x, y)
                            textobj.textLine(line)
                            c.drawText(textobj)
                        except Exception as e:
                            logger.warning("Failed to draw Arabic description with text object, falling back: %s", str(e))
                            c.drawString(line_x, y, line)
                    else:
                        c.drawString(line_x, y, line)
                    y -= desc_font_size + line_spacing
        
        y -= language_spacing  # Spacing between languages

