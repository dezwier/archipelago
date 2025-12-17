"""
PDF layout functions for flashcard export.
Provides different layout strategies that can be swapped.
"""
import logging
from typing import List, Tuple
from reportlab.lib.pagesizes import A4, A6, A8
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas

from app.models.models import Concept, Lemma, Topic
from .flashcard_draw import draw_card_side
from .flashcard_draw_a8 import draw_card_side_a8_landscape

logger = logging.getLogger(__name__)


def generate_pdf_a4_layout(
    c: canvas.Canvas,
    concepts: List[Tuple[Concept, List[Lemma], Topic]],
    languages_front: List[str],
    languages_back: List[str],
    include_image_front: bool,
    include_text_front: bool,
    include_ipa_front: bool,
    include_description_front: bool,
    include_image_back: bool,
    include_text_back: bool,
    include_ipa_back: bool,
    include_description_back: bool,
    card_format: Tuple[float, float] = A6,
) -> int:
    """
    Generate PDF with multiple cards per A4 page.
    - A6 cards: 2x2 grid (4 cards per page)
    - A8 cards: 4x4 grid (16 cards per page)
    Each group gets a front page and a back page.
    
    Args:
        c: Canvas to draw on (should be initialized with A4 pagesize)
        concepts: List of tuples (concept, lemmas, topic)
        languages_front: Language codes for front side
        languages_back: Language codes for back side
        include_image_front: Whether to include image on front side
        include_text_front: Whether to include text (title/term) on front side
        include_ipa_front: Whether to include IPA on front side
        include_description_front: Whether to include description on front side
        include_image_back: Whether to include image on back side
        include_text_back: Whether to include text (title/term) on back side
        include_ipa_back: Whether to include IPA on back side
        include_description_back: Whether to include description on back side
        card_format: Card format tuple (width, height) - A6 or A8 (default: A6)
    
    Returns:
        Total number of cards drawn
    """
    # A4 dimensions
    a4_width, a4_height = A4
    card_width, card_height = card_format
    
    # Determine grid size based on card format
    if card_format == A6:
        grid_cols = 2
        grid_rows = 2
        cards_per_page = 4
    elif card_format == A8:
        grid_cols = 4
        grid_rows = 4
        cards_per_page = 16
    else:
        # Default to A6 if unknown format
        grid_cols = 2
        grid_rows = 2
        cards_per_page = 4
        logger.warning("Unknown card format, defaulting to A6 (2x2 grid)")
    
    # Calculate scale factor to fit cards on A4 page
    # Leave small margins (2mm total)
    scale_x = (a4_width - 2 * mm) / (card_width * grid_cols)
    scale_y = (a4_height - 2 * mm) / (card_height * grid_rows)
    scale = min(scale_x, scale_y)  # Use smaller scale to maintain aspect ratio
    
    # Scaled card dimensions
    scaled_card_width = card_width * scale
    scaled_card_height = card_height * scale
    
    # Calculate spacing
    total_card_width = scaled_card_width * grid_cols
    total_card_height = scaled_card_height * grid_rows
    margin_x = (a4_width - total_card_width) / 2
    margin_y = (a4_height - total_card_height) / 2
    
    # Generate positions for front side (left-to-right, top-to-bottom)
    positions_front = []
    for row in range(grid_rows):
        for col in range(grid_cols):
            x = margin_x + col * scaled_card_width
            y = a4_height - margin_y - (row + 1) * scaled_card_height
            positions_front.append((x, y))
    
    # Generate mirrored positions for back sides (for double-sided printing alignment)
    # Mirror horizontally: flip columns
    positions_back = []
    for row in range(grid_rows):
        for col in range(grid_cols):
            # Mirror column: grid_cols - 1 - col
            mirrored_col = grid_cols - 1 - col
            x = margin_x + mirrored_col * scaled_card_width
            y = a4_height - margin_y - (row + 1) * scaled_card_height
            positions_back.append((x, y))
    
    def draw_cutting_lines(canvas_obj, page_width, page_height, card_width, card_height, margin_x, margin_y, cols, rows):
        """Draw very subtle cutting lines to separate cards on A4 page."""
        # Use a very light gray color for subtle cutting lines
        canvas_obj.setStrokeColor(HexColor("#F3F3F3"))
        canvas_obj.setLineWidth(0.5)  # Very thin line
        
        # Vertical lines (separate columns)
        for col in range(1, cols):
            vertical_x = margin_x + card_width * col
            canvas_obj.line(vertical_x, margin_y, vertical_x, page_height - margin_y)
        
        # Horizontal lines (separate rows)
        for row in range(1, rows):
            horizontal_y = page_height - margin_y - card_height * row
            canvas_obj.line(margin_x, horizontal_y, page_width - margin_x, horizontal_y)
    
    # Process concepts in groups
    total_cards_drawn = 0
    for group_start in range(0, len(concepts), cards_per_page):
        # Get the concepts for this group (or fewer if it's the last group)
        group_concepts = concepts[group_start:group_start + cards_per_page]
        group_num = (group_start // cards_per_page) + 1
        
        logger.info("Processing group %d: %d concepts (indices %d-%d)", 
                   group_num, len(group_concepts), group_start, group_start + len(group_concepts) - 1)
        
        # Initialize front page with white background
        if group_start > 0:
            c.showPage()
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, a4_width, a4_height, fill=1, stroke=0)
        
        # Draw front sides for this group
        for card_in_group, (concept, lemmas, topic) in enumerate(group_concepts):
            # Get position for this card (front side)
            offset_x, offset_y = positions_front[card_in_group]
            
            logger.debug("Drawing front of concept %d at position %d in group", concept.id, card_in_group)
            
            # Save state, translate and scale, draw card, restore
            c.saveState()
            c.translate(offset_x, offset_y)
            c.scale(scale, scale)
            # Use A8 landscape drawing function for A8 cards, regular drawing for A6
            if card_format == A8:
                draw_card_side_a8_landscape(
                    c, concept, lemmas, languages_front, topic,
                    offset_x=0, offset_y=0,
                    include_image=include_image_front,
                    include_title=include_text_front,
                    include_ipa=include_ipa_front,
                    include_description=include_description_front,
                    page_size=card_format,
                )
            else:
                draw_card_side(
                    c, concept, lemmas, languages_front, topic,
                    offset_x=0, offset_y=0,
                    include_image=include_image_front,
                    include_title=include_text_front,
                    include_ipa=include_ipa_front,
                    include_description=include_description_front,
                    page_size=card_format,
                )
            c.restoreState()
            total_cards_drawn += 1
        
        # Draw cutting lines on front page
        draw_cutting_lines(c, a4_width, a4_height, scaled_card_width, scaled_card_height, margin_x, margin_y, grid_cols, grid_rows)
        
        # Create back page for this group
        c.showPage()
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, a4_width, a4_height, fill=1, stroke=0)
        
        # Draw back sides for this group (mirrored positions)
        for card_in_group, (concept, lemmas, topic) in enumerate(group_concepts):
            # Get position for this card (back side - mirrored for double-sided printing)
            offset_x, offset_y = positions_back[card_in_group]
            
            logger.debug("Drawing back of concept %d at position %d in group", concept.id, card_in_group)
            
            # Save state, translate and scale, draw card, restore
            c.saveState()
            c.translate(offset_x, offset_y)
            c.scale(scale, scale)
            # Use A8 landscape drawing function for A8 cards, regular drawing for A6
            if card_format == A8:
                draw_card_side_a8_landscape(
                    c, concept, lemmas, languages_back, topic,
                    offset_x=0, offset_y=0,
                    include_image=include_image_back,
                    include_title=include_text_back,
                    include_ipa=include_ipa_back,
                    include_description=include_description_back,
                    page_size=card_format,
                )
            else:
                draw_card_side(
                    c, concept, lemmas, languages_back, topic,
                    offset_x=0, offset_y=0,
                    include_image=include_image_back,
                    include_title=include_text_back,
                    include_ipa=include_ipa_back,
                    include_description=include_description_back,
                    page_size=card_format,
                )
            c.restoreState()
        
        # Draw cutting lines on back page
        draw_cutting_lines(c, a4_width, a4_height, scaled_card_width, scaled_card_height, margin_x, margin_y, grid_cols, grid_rows)
    
    logger.info("Finished exporting: %d cards drawn from %d concepts", total_cards_drawn, len(concepts))
    return total_cards_drawn


def generate_pdf(
    c: canvas.Canvas,
    concepts: List[Tuple[Concept, List[Lemma], Topic]],
    languages_front: List[str],
    languages_back: List[str],
    include_image_front: bool,
    include_text_front: bool,
    include_ipa_front: bool,
    include_description_front: bool,
    include_image_back: bool,
    include_text_back: bool,
    include_ipa_back: bool,
    include_description_back: bool,
    page_format: Tuple[float, float] = A6,
) -> int:
    """
    Generate PDF with one card per page, alternating front and back.
    Each concept gets a front page followed by a back page.
    Creates 1 PDF page for the given format.
    
    Args:
        c: Canvas to draw on (should be initialized with the specified pagesize)
        concepts: List of tuples (concept, lemmas, topic)
        languages_front: Language codes for front side
        languages_back: Language codes for back side
        include_image_front: Whether to include image on front side
        include_text_front: Whether to include text (title/term) on front side
        include_ipa_front: Whether to include IPA on front side
        include_description_front: Whether to include description on front side
        include_image_back: Whether to include image on back side
        include_text_back: Whether to include text (title/term) on back side
        include_ipa_back: Whether to include IPA on back side
        include_description_back: Whether to include description on back side
        page_format: Page format tuple (width, height) from reportlab.lib.pagesizes (default: A6)
    
    Returns:
        Total number of cards drawn
    """
    # Page dimensions from format parameter
    page_width, page_height = page_format
    
    total_cards_drawn = 0
    
    # Process each concept: front page, then back page
    for concept_idx, (concept, lemmas, topic) in enumerate(concepts):
        # Front page
        if concept_idx > 0:
            c.showPage()
        
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, page_width, page_height, fill=1, stroke=0)
        
        logger.debug("Drawing front of concept %d", concept.id)
        
        draw_card_side(
            c, concept, lemmas, languages_front, topic,
            offset_x=0, offset_y=0,
            include_image=include_image_front,
            include_title=include_text_front,
            include_ipa=include_ipa_front,
            include_description=include_description_front,
            page_size=page_format,
        )
        total_cards_drawn += 1
        
        # Back page
        c.showPage()
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, page_width, page_height, fill=1, stroke=0)
        
        logger.debug("Drawing back of concept %d", concept.id)
        
        draw_card_side(
            c, concept, lemmas, languages_back, topic,
            offset_x=0, offset_y=0,
            include_image=include_image_back,
            include_title=include_text_back,
            include_ipa=include_ipa_back,
            include_description=include_description_back,
            page_size=page_format,
        )
    
    logger.info("Finished exporting: %d cards drawn from %d concepts", total_cards_drawn, len(concepts))
    return total_cards_drawn

