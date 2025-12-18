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
from reportlab.lib.pagesizes import A4, A5, A6, A8
from reportlab.pdfgen import canvas

from app.core.database import get_session
from app.models.models import Concept, Lemma, Topic
from app.schemas.flashcard import FlashcardExportRequest
import logging

from .flashcard_layouts import generate_pdf, generate_pdf_a4_layout

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcard-export", tags=["flashcard-export"])


def get_page_format(format_str: str):
    """Map format string to reportlab page size tuple.
    
    Args:
        format_str: Format string ('a4', 'a5', 'a6', etc.)
    
    Returns:
        Tuple of (width, height) in points
    """
    format_lower = format_str.lower()
    format_map = {
        'a4': A4,
        'a5': A5,
        'a6': A6,
        'a8': A8,
    }
    return format_map.get(format_lower, A6)  # Default to A6 if unknown


@router.post("/pdf")
async def export_flashcards_pdf(
    request: FlashcardExportRequest,
    session: Session = Depends(get_session)
):
    """
    Export flashcards as PDF.
    Each concept gets front and back sides on separate pages.
    Page format is determined by the 'layout' parameter ('a4', 'a5', or 'a6').
    """
    if not request.concept_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="concept_ids cannot be empty"
        )
    
    # Validate languages are provided if any text-related fields are enabled
    if (request.include_text_front or request.include_ipa_front or request.include_description_front) and not request.languages_front:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="languages_front cannot be empty when text, IPA, or description is enabled on front side"
        )
    
    if (request.include_text_back or request.include_ipa_back or request.include_description_back) and not request.languages_back:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="languages_back cannot be empty when text, IPA, or description is enabled on back side"
        )
    
    
    # Fetch all concepts with their lemmas and topics
    concepts = []
    for concept_id in request.concept_ids:
        concept = session.get(Concept, concept_id)
        if not concept:
            logger.warning("Concept %d not found, skipping", concept_id)
            continue
        
        # Get ALL lemmas for this concept (no limit, no pagination - we need every single one)
        # Explicitly avoid any limits by using .all() which returns all results
        statement = select(Lemma).where(Lemma.concept_id == concept_id)
        # Execute without any offset/limit to ensure we get all results
        lemmas = list(session.exec(statement).all())
        logger.info("Loaded %d lemmas for concept %d (IDs: %s)", 
                   len(lemmas), concept_id, 
                   [l.id for l in lemmas[:10]] + (["..."] if len(lemmas) > 10 else []))
        
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
    
    logger.info("Exporting %d concepts to PDF with format: %s (fit_to_a4: %s)", 
                len(concepts), request.layout, request.fit_to_a4)
    
    # Get page format from layout string
    pagesize = get_page_format(request.layout)
    
    # Create PDF buffer - always use A4 pagesize when fit_to_a4 is enabled
    buffer = BytesIO()
    if request.fit_to_a4 and request.layout.lower() in ['a6', 'a8']:
        # Use A4 pagesize when fitting cards to A4
        c = canvas.Canvas(buffer, pagesize=A4)
        
        # Get card format (A6 or A8)
        card_format = get_page_format(request.layout)
        
        # Use generate_pdf_a4_layout to fit multiple cards on A4 pages
        total_cards_drawn = generate_pdf_a4_layout(
            c=c,
            concepts=concepts,
            languages_front=request.languages_front,
            languages_back=request.languages_back,
            include_image_front=request.include_image_front,
            include_text_front=request.include_text_front,
            include_ipa_front=request.include_ipa_front,
            include_description_front=request.include_description_front,
            include_image_back=request.include_image_back,
            include_text_back=request.include_text_back,
            include_ipa_back=request.include_ipa_back,
            include_description_back=request.include_description_back,
            card_format=card_format,
        )
    else:
        # Use normal generate_pdf with the specified page format
        c = canvas.Canvas(buffer, pagesize=pagesize)
        
        total_cards_drawn = generate_pdf(
            c=c,
            concepts=concepts,
            languages_front=request.languages_front,
            languages_back=request.languages_back,
            include_image_front=request.include_image_front,
            include_text_front=request.include_text_front,
            include_ipa_front=request.include_ipa_front,
            include_description_front=request.include_description_front,
            include_image_back=request.include_image_back,
            include_text_back=request.include_text_back,
            include_ipa_back=request.include_ipa_back,
            include_description_back=request.include_description_back,
            page_format=pagesize,
        )
    logger.info("Total cards drawn: %d", total_cards_drawn)
    
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
