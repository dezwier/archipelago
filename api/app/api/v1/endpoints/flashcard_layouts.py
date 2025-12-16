"""
PDF layout functions for flashcard export.
Provides different layout strategies that can be swapped.
"""
import logging
from typing import List, Tuple
from reportlab.lib.pagesizes import A4, A5, A6
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas

from app.models.models import Concept, Lemma, Topic
from .flashcard_draw import draw_card_side

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
) -> int:
    """
    Generate PDF with 4 cards per A4 page (2x2 grid).
    Each card is A6 size (1/4 of A4: 105mm × 148mm).
    Each group of 4 concepts gets a front page and a back page.
    
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
    
    Returns:
        Total number of cards drawn
    """
    # A4 dimensions
    a4_width, a4_height = A4
    # A5 dimensions
    a5_width, a5_height = A5
    
    # Calculate positions for 2x2 grid on A4
    # A5 cards: 148mm x 210mm
    # A4 page: 210mm x 297mm
    # We'll arrange 2 cards side-by-side (148mm x 2 = 296mm, fits in 297mm width)
    # And 2 rows (210mm x 2 = 420mm doesn't fit, so we need to scale or use landscape)
    # Actually, let's use landscape A5: 210mm x 148mm
    # 2 landscape A5 side-by-side: 210mm x 2 = 420mm (doesn't fit in 210mm width)
    # 2 landscape A5 stacked: 148mm x 2 = 296mm (fits in 297mm height)
    
    # Since exact fit is challenging, we'll scale the cards slightly to fit
    # Calculate scale factor to fit 2x2 grid
    scale_x = (a4_width - 2 * mm) / (a5_width * 2)  # 2 cards side-by-side with 1mm margin
    scale_y = (a4_height - 2 * mm) / (a5_height * 2)  # 2 cards stacked with 1mm margin
    scale = min(scale_x, scale_y)  # Use smaller scale to maintain aspect ratio
    
    # Scaled card dimensions
    card_width = a5_width * scale
    card_height = a5_height * scale
    
    # Calculate spacing
    total_card_width = card_width * 2
    total_card_height = card_height * 2
    margin_x = (a4_width - total_card_width) / 2
    margin_y = (a4_height - total_card_height) / 2
    
    # Positions for 2x2 grid (top-left, top-right, bottom-left, bottom-right)
    positions_front = [
        (margin_x, a4_height - margin_y - card_height),  # Top-left (Card 1)
        (margin_x + card_width, a4_height - margin_y - card_height),  # Top-right (Card 2)
        (margin_x, a4_height - margin_y - card_height * 2),  # Bottom-left (Card 3)
        (margin_x + card_width, a4_height - margin_y - card_height * 2),  # Bottom-right (Card 4)
    ]
    
    # Mirrored positions for back sides (for double-sided printing alignment)
    # Front: TL=1, TR=2, BL=3, BR=4
    # Back:  TR=1, TL=2, BR=3, BL=4 (mirrored horizontally)
    positions_back = [
        (margin_x + card_width, a4_height - margin_y - card_height),  # Top-right (Card 1 back)
        (margin_x, a4_height - margin_y - card_height),  # Top-left (Card 2 back)
        (margin_x + card_width, a4_height - margin_y - card_height * 2),  # Bottom-right (Card 3 back)
        (margin_x, a4_height - margin_y - card_height * 2),  # Bottom-left (Card 4 back)
    ]
    
    def draw_cutting_lines(canvas_obj, page_width, page_height, card_width, card_height, margin_x, margin_y):
        """Draw very subtle cutting lines to separate A6 cards on A4 page."""
        # Use a very light gray color for subtle cutting lines
        canvas_obj.setStrokeColor(HexColor("#F3F3F3"))
        canvas_obj.setLineWidth(0.5)  # Very thin line
        
        # Vertical line down the middle (separates left and right cards)
        vertical_x = margin_x + card_width
        canvas_obj.line(vertical_x, margin_y, vertical_x, page_height - margin_y)
        
        # Horizontal line across the middle (separates top and bottom cards)
        horizontal_y = page_height - margin_y - card_height
        canvas_obj.line(margin_x, horizontal_y, page_width - margin_x, horizontal_y)
    
    # Generate pages in pairs: front page, then back page for each group of 4 cards
    # This creates the correct order for double-sided printing: front, back, front, back, etc.
    
    # Process concepts in groups of 4
    total_cards_drawn = 0
    for group_start in range(0, len(concepts), 4):
        # Get the 4 concepts for this group (or fewer if it's the last group)
        group_concepts = concepts[group_start:group_start + 4]
        group_num = (group_start // 4) + 1
        
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
            draw_card_side(
                c, concept, lemmas, languages_front, topic,
                offset_x=0, offset_y=0,
                include_image=include_image_front,
                include_title=include_text_front,
                include_ipa=include_ipa_front,
                include_description=include_description_front
            )
            c.restoreState()
            total_cards_drawn += 1
        
        # Draw cutting lines on front page
        draw_cutting_lines(c, a4_width, a4_height, card_width, card_height, margin_x, margin_y)
        
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
            draw_card_side(
                c, concept, lemmas, languages_back, topic,
                offset_x=0, offset_y=0,
                include_image=include_image_back,
                include_title=include_text_back,
                include_ipa=include_ipa_back,
                include_description=include_description_back
            )
            c.restoreState()
        
        # Draw cutting lines on back page
        draw_cutting_lines(c, a4_width, a4_height, card_width, card_height, margin_x, margin_y)
    
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

