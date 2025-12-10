"""
Concept CRUD endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, exists
from datetime import datetime, timezone
from app.core.database import get_session
from app.models.models import Concept, Image, Card
from app.schemas.flashcard import ConceptResponse, ImageResponse, ConceptCountResponse
from typing import List, Optional
from pydantic import BaseModel, Field

router = APIRouter(prefix="/concepts", tags=["concepts"])


class UpdateConceptRequest(BaseModel):
    """Request schema for updating a concept."""
    term: Optional[str] = Field(None, min_length=1, description="The term (cannot be empty if provided)")
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


@router.get("/without-cards", response_model=List[ConceptResponse])
async def get_concepts_without_cards(
    skip: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session)
):
    """
    Get all concepts that don't have any cards in the card table.
    
    This endpoint returns concepts that have no associated cards, which can be useful
    for identifying concepts that need card generation.
    
    Args:
        skip: Number of concepts to skip
        limit: Maximum number of concepts to return
    
    Returns:
        List of concepts without any cards
    """
    # Use NOT EXISTS subquery to find concepts without any cards
    subquery = select(Card.id).where(Card.concept_id == Concept.id)
    query = (
        select(Concept)
        .where(~exists(subquery))
        .order_by(Concept.created_at.desc())
        .offset(skip)
        .limit(limit)
    )
    
    concepts = session.exec(query).all()
    
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
        term_stripped = request.term.strip()
        if not term_stripped:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Term cannot be empty"
            )
        concept.term = term_stripped
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


@router.get("/count/total", response_model=ConceptCountResponse)
async def get_total_concept_count(
    session: Session = Depends(get_session)
):
    """
    Get the total count of all concepts.
    
    Returns:
        Total count of concepts
    """
    count = session.exec(select(func.count(Concept.id))).one()
    return ConceptCountResponse(count=count)


@router.get("/count/with-term", response_model=ConceptCountResponse)
async def get_concept_count_with_term(
    session: Session = Depends(get_session)
):
    """
    Get the count of concepts that have a term present.
    
    A concept is considered to have a term if:
    - The concept.term field is not None and not empty, OR
    - At least one card associated with the concept has a non-empty term
    
    Returns:
        Count of concepts with at least one term
    """
    # Get all concepts
    all_concepts = session.exec(select(Concept)).all()
    
    # Get all cards with terms
    all_cards = session.exec(
        select(Card).where(
            Card.term.isnot(None),
            Card.term != ""
        )
    ).all()
    
    # Group cards by concept_id
    concept_cards_map = {}
    for card in all_cards:
        if card.concept_id not in concept_cards_map:
            concept_cards_map[card.concept_id] = []
        concept_cards_map[card.concept_id].append(card)
    
    # Count concepts with terms
    count = 0
    for concept in all_concepts:
        has_term = False
        if concept.term and concept.term.strip():
            has_term = True
        else:
            # Check if concept has at least one card with a term
            concept_cards = concept_cards_map.get(concept.id, [])
            for card in concept_cards:
                if card.term and card.term.strip():
                    has_term = True
                    break
        if has_term:
            count += 1
    
    return ConceptCountResponse(count=count)


@router.get("/count/with-cards-for-languages", response_model=ConceptCountResponse)
async def get_concept_count_with_cards_for_languages(
    languages: str,
    session: Session = Depends(get_session)
):
    """
    Get the count of concepts that have cards with terms for all of the given languages.
    
    Args:
        languages: Comma-separated list of language codes (e.g., "en,fr,es")
    
    Returns:
        Count of concepts that have cards with terms for all specified languages
    """
    if not languages or not languages.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="languages parameter is required and cannot be empty"
        )
    
    # Parse language codes
    language_codes = [lang.strip().lower() for lang in languages.split(',') if lang.strip()]
    
    if not language_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one valid language code must be provided"
        )
    
    # Get all cards with terms, filtered by the specified languages
    all_cards = session.exec(
        select(Card).where(
            Card.language_code.in_(language_codes),
            Card.term.isnot(None),
            Card.term != ""
        )
    ).all()
    
    # Group cards by concept_id and language_code
    concept_cards_map = {}
    for card in all_cards:
        if card.concept_id not in concept_cards_map:
            concept_cards_map[card.concept_id] = {}
        concept_cards_map[card.concept_id][card.language_code] = card
    
    # Count concepts that have cards for all specified languages
    count = 0
    for concept_id, lang_cards in concept_cards_map.items():
        # Check if this concept has cards for all specified languages
        has_all_cards = True
        for lang_code in language_codes:
            if lang_code not in lang_cards:
                has_all_cards = False
                break
            card = lang_cards[lang_code]
            if not card.term or not card.term.strip():
                has_all_cards = False
                break
        if has_all_cards:
            count += 1
    
    return ConceptCountResponse(count=count)

