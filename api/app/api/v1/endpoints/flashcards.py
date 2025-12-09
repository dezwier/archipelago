"""
Main flashcard CRUD endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from datetime import datetime, timezone
from app.core.database import get_session
from app.models.models import Concept, Card, User, UserCard, Image
from app.schemas.flashcard import (
    CardResponse,
    PairedVocabularyItem,
    VocabularyResponse,
    UpdateCardRequest,
    ImageResponse,
)
from app.api.v1.endpoints.flashcard_helpers import ensure_capitalized
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcards", tags=["flashcards"])


@router.get("/vocabulary", response_model=VocabularyResponse)
async def get_vocabulary(
    user_id: int,
    page: int = 1,
    page_size: int = 20,
    sort_by: str = "alphabetical",  # Options: "alphabetical", "recent"
    search: str = None,  # Optional search query
    search_languages: str = None,  # Comma-separated list of language codes to search in
    session: Session = Depends(get_session)
):
    """
    Get cards for a user's source and target languages, paired by concept_id.
    Returns paginated vocabulary items that match the user's native and learning languages.
    
    Args:
        user_id: The user ID
        page: Page number (1-indexed, default: 1)
        page_size: Number of items per page (default: 20)
        sort_by: Sort order - "alphabetical" (default) or "recent" (by created_at, newest first)
        search: Optional search query to filter cards by term
        search_languages: Comma-separated list of language codes to search in (if not provided, searches in all languages)
    """
    # Validate sort_by parameter
    if sort_by not in ["alphabetical", "recent"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="sort_by must be 'alphabetical' or 'recent'"
        )
    
    # Validate pagination parameters
    if page < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Page must be >= 1"
        )
    if page_size < 1 or page_size > 100:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Page size must be between 1 and 100"
        )
    
    # Get user
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get all cards for user's native and learning languages (for filtering/searching)
    language_codes = [user.lang_native]
    if user.lang_learning:
        language_codes.append(user.lang_learning)
    
    # Apply search filter if provided
    matching_concept_ids = None
    if search and search.strip():
        search_term = search.strip().lower()
        
        # Parse search languages if provided
        search_language_codes = None
        if search_languages:
            search_language_codes = [lang.strip().lower() for lang in search_languages.split(',') if lang.strip()]
        
        # Build search query
        if search_language_codes:
            # Search in specified languages
            matching_cards = session.exec(
                select(Card).where(
                    Card.language_code.in_(search_language_codes),
                    func.lower(Card.term).contains(search_term)
                )
            ).all()
        else:
            # Search in all languages
            matching_cards = session.exec(
                select(Card).where(
                    func.lower(Card.term).contains(search_term)
                )
            ).all()
        
        # Get all concept_ids that match
        matching_concept_ids = {card.concept_id for card in matching_cards}
    
    # Get ALL cards for matching concepts (all languages, not just source/target)
    if matching_concept_ids is not None:
        # If searching, get all cards for matching concepts
        all_cards = session.exec(
            select(Card).where(Card.concept_id.in_(list(matching_concept_ids)))
        ).all()
    else:
        # No search - get all cards (we'll filter by source/target later for sorting)
        all_cards = session.exec(select(Card)).all()
    
    # Group cards by concept_id (all languages)
    concept_cards_map = {}
    for card in all_cards:
        if card.concept_id not in concept_cards_map:
            concept_cards_map[card.concept_id] = {}
        concept_cards_map[card.concept_id][card.language_code] = card
    
    # Get all concept_ids and sort based on sort_by parameter
    concept_sort_keys = []
    for concept_id, lang_cards in concept_cards_map.items():
        target_card = lang_cards.get(user.lang_learning) if user.lang_learning else None
        source_card = lang_cards.get(user.lang_native)
        
        if sort_by == "recent":
            # For recent sort, use the most recent created_at among all cards for this concept
            # Prefer target card's created_at, fallback to source card's, or any card's
            created_at = None
            if target_card and target_card.created_at:
                created_at = target_card.created_at
            elif source_card and source_card.created_at:
                created_at = source_card.created_at
            else:
                # Get the most recent created_at from any card in this concept
                all_cards_for_concept = list(lang_cards.values())
                if all_cards_for_concept:
                    cards_with_time = [c for c in all_cards_for_concept if c.created_at]
                    if cards_with_time:
                        created_at = max(c.created_at for c in cards_with_time)
            
            # Include concept even if no created_at (fallback to concept_id for sorting)
            if created_at:
                concept_sort_keys.append((created_at, concept_id))
            else:
                # Fallback: use concept_id (higher IDs = more recent) with a very old timestamp
                fallback_time = datetime.min.replace(tzinfo=timezone.utc)
                concept_sort_keys.append((fallback_time, concept_id))
        else:
            # Default: alphabetical sorting by target language term
            # Use target language term for sorting, fallback to source if no target
            sort_text = ""
            if target_card:
                sort_text = target_card.term.lower().strip()
            elif source_card:
                sort_text = source_card.term.lower().strip()
            
            # Only include concepts that have at least one card
            if sort_text:
                concept_sort_keys.append((sort_text, concept_id))
    
    # Sort based on sort_by parameter
    if sort_by == "recent":
        # Sort by created_at descending (newest first)
        concept_sort_keys.sort(key=lambda x: x[0], reverse=True)
    else:
        # Sort alphabetically by target language term (case-insensitive)
        concept_sort_keys.sort(key=lambda x: x[0])
    
    all_concept_ids = [concept_id for _, concept_id in concept_sort_keys]
    total = len(all_concept_ids)
    
    # Calculate pagination
    offset = (page - 1) * page_size
    paginated_concept_ids = all_concept_ids[offset:offset + page_size]
    
    # If no concept_ids in this page, return empty result
    if not paginated_concept_ids:
        return VocabularyResponse(
            items=[],
            total=total,
            page=page,
            page_size=page_size,
            has_next=False,
            has_previous=page > 1
        )
    
    # Fetch images and concepts for all concepts in this page
    concept_images_map = {}
    concept_data_map = {}
    if paginated_concept_ids:
        images = session.exec(
            select(Image).where(Image.concept_id.in_(paginated_concept_ids)).order_by(Image.created_at)
        ).all()
        for img in images:
            if img.concept_id not in concept_images_map:
                concept_images_map[img.concept_id] = []
            concept_images_map[img.concept_id].append(ImageResponse.model_validate(img))
        
        # Fetch concepts to get part_of_speech
        concepts = session.exec(
            select(Concept).where(Concept.id.in_(paginated_concept_ids))
        ).all()
        for concept in concepts:
            concept_data_map[concept.id] = concept
    
    # Build paired vocabulary items (maintain alphabetical order)
    paired_items = []
    for concept_id in paginated_concept_ids:
        lang_cards = concept_cards_map.get(concept_id, {})
        source_card = lang_cards.get(user.lang_native)
        target_card = lang_cards.get(user.lang_learning) if user.lang_learning else None
        
        # Get images and concept data for this concept
        concept_images = concept_images_map.get(concept_id, [])
        concept = concept_data_map.get(concept_id)
        part_of_speech = concept.part_of_speech if concept else None
        concept_term = concept.term if concept else None
        concept_description = concept.description if concept else None
        concept_level = concept.level.value if concept and concept.level else None
        
        # Only include items that have at least one card (source or target)
        if source_card or target_card:
            # Build list of all cards for this concept
            all_cards_list = []
            for card in lang_cards.values():
                all_cards_list.append(
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
                )
            
            paired_items.append(
                PairedVocabularyItem(
                    concept_id=concept_id,
                    cards=all_cards_list,
                    source_card=CardResponse(
                        id=source_card.id,
                        concept_id=source_card.concept_id,
                        language_code=source_card.language_code,
                        translation=ensure_capitalized(source_card.term),
                        description=source_card.description,
                        ipa=source_card.ipa,
                        audio_path=source_card.audio_url,
                        gender=source_card.gender,
                        article=source_card.article,
                        plural_form=source_card.plural_form,
                        verb_type=source_card.verb_type,
                        auxiliary_verb=source_card.auxiliary_verb,
                        formality_register=source_card.formality_register,
                        notes=source_card.notes
                    ) if source_card else None,
                    target_card=CardResponse(
                        id=target_card.id,
                        concept_id=target_card.concept_id,
                        language_code=target_card.language_code,
                        translation=ensure_capitalized(target_card.term),
                        description=target_card.description,
                        ipa=target_card.ipa,
                        audio_path=target_card.audio_url,
                        gender=target_card.gender,
                        article=target_card.article,
                        plural_form=target_card.plural_form,
                        verb_type=target_card.verb_type,
                        auxiliary_verb=target_card.auxiliary_verb,
                        formality_register=target_card.formality_register,
                        notes=target_card.notes
                    ) if target_card else None,
                    images=concept_images,
                    part_of_speech=part_of_speech,
                    concept_term=concept_term,
                    concept_description=concept_description,
                    concept_level=concept_level,
                )
            )
    
    # Calculate pagination metadata
    has_next = offset + page_size < total
    has_previous = page > 1
    
    return VocabularyResponse(
        items=paired_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=has_next,
        has_previous=has_previous
    )


@router.put("/cards/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: int,
    request: UpdateCardRequest,
    session: Session = Depends(get_session)
):
    """
    Update a card's translation and description.
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


@router.delete("/concepts/{concept_id}", status_code=status.HTTP_204_NO_CONTENT)
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
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all cards for this concept
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
