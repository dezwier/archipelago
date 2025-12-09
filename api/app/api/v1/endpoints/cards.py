"""
Card CRUD endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone
from typing import List, Optional
from app.core.database import get_session
from app.models.models import Card
from app.schemas.flashcard import CardResponse, UpdateCardRequest
from app.api.v1.endpoints.flashcard_helpers import ensure_capitalized

router = APIRouter(prefix="/cards", tags=["cards"])


@router.get("", response_model=List[CardResponse])
async def get_cards(
    skip: int = 0,
    limit: int = 100,
    concept_id: Optional[int] = None,
    language_code: Optional[str] = None,
    session: Session = Depends(get_session)
):
    """
    Get cards with optional filtering.
    
    Args:
        skip: Number of cards to skip
        limit: Maximum number of cards to return
        concept_id: Optional filter by concept ID
        language_code: Optional filter by language code
    
    Returns:
        List of cards
    """
    query = select(Card)
    
    if concept_id is not None:
        query = query.where(Card.concept_id == concept_id)
    
    if language_code is not None:
        query = query.where(Card.language_code == language_code.lower())
    
    cards = session.exec(
        query.offset(skip).limit(limit).order_by(Card.created_at.desc())
    ).all()
    
    return [
        CardResponse(
            id=card.id,
            concept_id=card.concept_id,
            language_code=card.language_code,
            translation=ensure_capitalized(card.term),
            description=card.description,
            ipa=card.ipa,
            audio_path=card.audio_url,
            gender=card.gender,
            article=card.article,
            plural_form=card.plural_form,
            verb_type=card.verb_type,
            auxiliary_verb=card.auxiliary_verb,
            formality_register=card.formality_register,
            notes=card.notes
        )
        for card in cards
    ]


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: int,
    session: Session = Depends(get_session)
):
    """
    Get a card by ID.
    
    Args:
        card_id: The card ID
    
    Returns:
        The card
    """
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    return CardResponse(
        id=card.id,
        concept_id=card.concept_id,
        language_code=card.language_code,
        translation=ensure_capitalized(card.term),
        description=card.description,
        ipa=card.ipa,
        audio_path=card.audio_url,
        gender=card.gender,
        article=card.article,
        plural_form=card.plural_form,
        verb_type=card.verb_type,
        auxiliary_verb=card.auxiliary_verb,
        formality_register=card.formality_register,
        notes=card.notes
    )


@router.put("/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: int,
    request: UpdateCardRequest,
    session: Session = Depends(get_session)
):
    """
    Update a card's translation and description.
    
    Args:
        card_id: The card ID
        request: Update request with fields to update
    
    Returns:
        The updated card
    """
    # Get the card
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Check if translation update would create a duplicate
    if request.translation is not None:
        new_term = ensure_capitalized(request.translation.strip())
        
        # Check if another card with same concept_id, language_code, and term already exists
        existing_card = session.exec(
            select(Card).where(
                Card.concept_id == card.concept_id,
                Card.language_code == card.language_code,
                Card.term == new_term,
                Card.id != card_id  # Exclude the current card
            )
        ).first()
        
        if existing_card:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A card with the same concept_id, language_code, and term already exists (card_id: {existing_card.id})"
            )
        
        card.term = new_term
        card.updated_at = datetime.now(timezone.utc)
    
    if request.description is not None:
        card.description = request.description.strip()
        card.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(card)
        session.commit()
        session.refresh(card)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to update card: duplicate constraint violation"
        ) from e
    
    return CardResponse(
        id=card.id,
        concept_id=card.concept_id,
        language_code=card.language_code,
        translation=ensure_capitalized(card.term),
        description=card.description,
        ipa=card.ipa,
        audio_path=card.audio_url,
        gender=card.gender,
        article=card.article,
        plural_form=card.plural_form,
        verb_type=card.verb_type,
        auxiliary_verb=card.auxiliary_verb,
        formality_register=card.formality_register,
        notes=card.notes
    )


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_card(
    card_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a card and all its associated user_cards.
    
    Args:
        card_id: The card ID
    """
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Delete all UserCards that reference this card
    from app.models.models import UserCard
    user_cards = session.exec(
        select(UserCard).where(UserCard.card_id == card_id)
    ).all()
    
    for user_card in user_cards:
        session.delete(user_card)
    
    # Delete the card
    session.delete(card)
    
    session.commit()
    
    return None

