"""
Concept CRUD endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone
from app.core.database import get_session
from app.models.models import Concept, Image
from app.schemas.flashcard import ConceptResponse, ImageResponse
from typing import List, Optional
from pydantic import BaseModel

router = APIRouter(prefix="/concepts", tags=["concepts"])


class UpdateConceptRequest(BaseModel):
    """Request schema for updating a concept."""
    term: Optional[str] = None
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    topic_id: Optional[int] = None


@router.get("", response_model=List[ConceptResponse])
async def get_concepts(
    skip: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session)
):
    """
    Get all concepts with pagination.
    
    Args:
        skip: Number of concepts to skip
        limit: Maximum number of concepts to return
    
    Returns:
        List of concepts
    """
    concepts = session.exec(
        select(Concept).offset(skip).limit(limit).order_by(Concept.created_at.desc())
    ).all()
    
    # Load images for each concept
    concept_ids = [c.id for c in concepts]
    images = session.exec(
        select(Image).where(Image.concept_id.in_(concept_ids))
    ).all()
    
    image_map = {}
    for img in images:
        if img.concept_id not in image_map:
            image_map[img.concept_id] = []
        image_map[img.concept_id].append(img)
    
    result = []
    for concept in concepts:
        concept_dict = ConceptResponse.model_validate(concept).model_dump()
        concept_dict['images'] = [ImageResponse.model_validate(img) for img in image_map.get(concept.id, [])]
        result.append(ConceptResponse(**concept_dict))
    
    return result


@router.get("/{concept_id}", response_model=ConceptResponse)
async def get_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Get a concept by ID.
    
    Args:
        concept_id: The concept ID
    
    Returns:
        The concept
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Load images for the concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    return ConceptResponse(**concept_dict)


@router.put("/{concept_id}", response_model=ConceptResponse)
async def update_concept(
    concept_id: int,
    request: UpdateConceptRequest,
    session: Session = Depends(get_session)
):
    """
    Update a concept.
    
    Args:
        concept_id: The concept ID
        request: Update request with fields to update
    
    Returns:
        The updated concept
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Update fields if provided
    if request.term is not None:
        concept.term = request.term.strip()
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.description is not None:
        concept.description = request.description.strip() if request.description else None
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.part_of_speech is not None:
        concept.part_of_speech = request.part_of_speech.strip() if request.part_of_speech else None
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.topic_id is not None:
        concept.topic_id = request.topic_id
        concept.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(concept)
        session.commit()
        session.refresh(concept)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to update concept: constraint violation"
        ) from e
    
    # Load images for the concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    return ConceptResponse(**concept_dict)


@router.delete("/{concept_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a concept and all its associated cards and user_cards.
    This will cascade delete:
    - All UserCards that reference cards for this concept
    - All Cards for this concept
    - The Concept itself
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all cards for this concept
    from app.models.models import Card, UserCard
    cards = session.exec(
        select(Card).where(Card.concept_id == concept_id)
    ).all()
    
    # Delete all UserCards that reference these cards
    card_ids = [card.id for card in cards]
    if card_ids:
        user_cards = session.exec(
            select(UserCard).where(UserCard.card_id.in_(card_ids))
        ).all()
        for user_card in user_cards:
            session.delete(user_card)
    
    # Delete all cards
    for card in cards:
        session.delete(card)
    
    # Delete the concept
    session.delete(concept)
    
    session.commit()
    
    return None


@router.get("/by-term", response_model=List[ConceptResponse])
async def get_concepts_by_term(
    term: str,
    session: Session = Depends(get_session)
):
    """
    Get all concepts that match the given term.
    
    Searches for concepts where the term field matches (case-insensitive).
    Uses partial matching - will find concepts where the term contains the search term.
    
    Args:
        term: The term to search for
    
    Returns:
        List of concepts matching the term
    """
    if not term or not term.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term parameter cannot be empty"
        )
    
    # Use case-insensitive partial matching
    # Filter out concepts where term is None and use case-insensitive matching
    search_term = term.strip()
    # Use ilike for PostgreSQL case-insensitive pattern matching with wildcards
    concepts = session.exec(
        select(Concept).where(
            Concept.term.isnot(None),
            Concept.term.ilike(f"%{search_term}%")
        ).order_by(Concept.created_at.desc())
    ).all()
    
    # Load images for each concept
    concept_ids = [c.id for c in concepts]
    images = session.exec(
        select(Image).where(Image.concept_id.in_(concept_ids))
    ).all()
    
    image_map = {}
    for img in images:
        if img.concept_id not in image_map:
            image_map[img.concept_id] = []
        image_map[img.concept_id].append(img)
    
    result = []
    for concept in concepts:
        concept_dict = ConceptResponse.model_validate(concept).model_dump()
        concept_dict['images'] = [ImageResponse.model_validate(img) for img in image_map.get(concept.id, [])]
        result.append(ConceptResponse(**concept_dict))
    
    return result

