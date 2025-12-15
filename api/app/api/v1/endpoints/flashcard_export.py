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
from reportlab.lib.pagesizes import A5
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
