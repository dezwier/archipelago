"""
Flashcard PDF export endpoint.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlmodel import Session, select
from typing import List
from pydantic import BaseModel, Field
from io import BytesIO
from reportlab.lib.pagesizes import A4, A5
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.pdfgen import canvas

from app.core.database import get_session
from app.models.models import Concept, Lemma, Topic
import logging

from .flashcard_export_helpers import draw_card_side

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcard-export", tags=["flashcard-export"])


class FlashcardExportRequest(BaseModel):
    """Request schema for flashcard PDF export."""
    concept_ids: List[int] = Field(..., description="List of concept IDs to export")
    languages_front: List[str] = Field(..., description="Language codes for front side")
    languages_back: List[str] = Field(..., description="Language codes for back side")


@router.post("/pdf")
async def export_flashcards_pdf(
    request: FlashcardExportRequest,
    session: Session = Depends(get_session)
):
    """
    Export flashcards as PDF with A5 cards arranged 4 per A4 page.
    Each concept gets front and back sides, arranged in a 2x2 grid on A4 pages.
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
    
    # Create PDF buffer with A4 pages
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=A4)
    
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
    
    def draw_cutting_lines(canvas, page_width, page_height, card_width, card_height, margin_x, margin_y):
        """Draw very subtle cutting lines to separate A5 cards on A4 page."""
        # Use a very light gray color for subtle cutting lines
        canvas.setStrokeColor(HexColor("#E9E9E9"))
        canvas.setLineWidth(0.5)  # Very thin line
        
        # Vertical line down the middle (separates left and right cards)
        vertical_x = margin_x + card_width
        canvas.line(vertical_x, margin_y, vertical_x, page_height - margin_y)
        
        # Horizontal line across the middle (separates top and bottom cards)
        horizontal_y = page_height - margin_y - card_height
        canvas.line(margin_x, horizontal_y, page_width - margin_x, horizontal_y)
    
    # Generate pages in pairs: front page, then back page for each group of 4 cards
    # This creates the correct order for double-sided printing: front, back, front, back, etc.
    
    # Process concepts in groups of 4
    for group_start in range(0, len(concepts), 4):
        # Get the 4 concepts for this group (or fewer if it's the last group)
        group_concepts = concepts[group_start:group_start + 4]
        
        # Initialize front page with white background
        if group_start > 0:
            c.showPage()
        c.setFillColor(HexColor("#FFFFFF"))
        c.rect(0, 0, a4_width, a4_height, fill=1, stroke=0)
        
        # Draw front sides for this group
        for card_in_group, (concept, lemmas, topic) in enumerate(group_concepts):
            # Get position for this card (front side)
            offset_x, offset_y = positions_front[card_in_group]
            
            # Save state, translate and scale, draw card, restore
            c.saveState()
            c.translate(offset_x, offset_y)
            c.scale(scale, scale)
            draw_card_side(c, concept, lemmas, request.languages_front, topic, offset_x=0, offset_y=0)
            c.restoreState()
        
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
            
            # Save state, translate and scale, draw card, restore
            c.saveState()
            c.translate(offset_x, offset_y)
            c.scale(scale, scale)
            draw_card_side(c, concept, lemmas, request.languages_back, topic, offset_x=0, offset_y=0)
            c.restoreState()
        
        # Draw cutting lines on back page
        draw_cutting_lines(c, a4_width, a4_height, card_width, card_height, margin_x, margin_y)
    
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
