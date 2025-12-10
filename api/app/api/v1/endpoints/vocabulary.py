"""
Vocabulary endpoints for retrieving paired vocabulary items.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, func, or_
from sqlalchemy.orm import aliased
from typing import Optional
from app.core.database import get_session
from app.models.models import Concept, Card, Image
from app.schemas.flashcard import (
    CardResponse,
    PairedVocabularyItem,
    VocabularyResponse,
    ImageResponse,
)
from app.api.v1.endpoints.flashcard_helpers import ensure_capitalized
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vocabulary", tags=["vocabulary"])


@router.get("", response_model=VocabularyResponse)
async def get_vocabulary(
    user_id: Optional[int] = None,
    page: int = 1,
    page_size: int = 20,
    sort_by: str = "alphabetical",  # Options: "alphabetical", "recent"
    search: Optional[str] = None,  # Optional search query for concept.term and card.term
    visible_languages: Optional[str] = None,  # Comma-separated list of visible language codes - cards are filtered to these languages
    session: Session = Depends(get_session)
):
    """
    Get all concepts with cards for visible languages, with search and pagination.
    Optimized to do filtering, sorting, and pagination at the database level.
    
    Args:
        user_id: The user ID (optional - for future use)
        page: Page number (1-indexed, default: 1)
        page_size: Number of items per page (default: 20)
        sort_by: Sort order - "alphabetical" (default) or "recent" (by created_at, newest first)
        search: Optional search query to filter by concept.term and card.term (for visible languages)
        visible_languages: Comma-separated list of visible language codes - only cards for these languages are returned
    """
    # Validate parameters
    if sort_by not in ["alphabetical", "recent"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="sort_by must be 'alphabetical' or 'recent'"
        )
    
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
    
    # Parse visible_languages parameter
    visible_language_codes = None
    if visible_languages:
        visible_language_codes = [lang.strip().lower() for lang in visible_languages.split(',') if lang.strip()]
    
    # Build base query for concepts - start with all concepts
    concept_query = select(Concept)
    
    # Apply search filter at database level if provided
    if search and search.strip():
        search_term = f"%{search.strip().lower()}%"
        
        # Search in concept.term or card.term for visible languages
        if visible_language_codes:
            # Subquery to find concept_ids that match search in cards for visible languages
            card_search_subquery = (
                select(Card.concept_id)
                .where(
                    Card.language_code.in_(visible_language_codes),
                    func.lower(Card.term).like(search_term)
                )
                .distinct()
            )
            
            # Filter concepts where term matches OR has matching cards
            concept_query = concept_query.where(
                or_(
                    func.lower(Concept.term).like(search_term),
                    Concept.id.in_(card_search_subquery)
                )
            )
        else:
            # Search in concept.term or any card.term
            card_search_subquery = (
                select(Card.concept_id)
                .where(func.lower(Card.term).like(search_term))
                .distinct()
            )
            concept_query = concept_query.where(
                or_(
                    func.lower(Concept.term).like(search_term),
                    Concept.id.in_(card_search_subquery)
                )
            )
    
    # Get total count before pagination (for concepts matching search)
    total_count_query = select(func.count(Concept.id)).select_from(concept_query.subquery())
    total = session.exec(total_count_query).one()
    
    # Apply sorting at database level
    if sort_by == "recent":
        # Sort by concept.created_at descending, or most recent card.created_at
        if visible_language_codes:
            # Subquery to get max created_at from visible language cards
            card_time_subquery = (
                select(
                    Card.concept_id,
                    func.max(Card.created_at).label('max_card_time')
                )
                .where(
                    Card.language_code.in_(visible_language_codes),
                    Card.term.isnot(None),
                    Card.term != ""
                )
                .group_by(Card.concept_id)
                .subquery()
            )
            # Join and sort by max card time or concept time
            concept_query = (
                concept_query
                .outerjoin(card_time_subquery, Concept.id == card_time_subquery.c.concept_id)
                .order_by(
                    func.coalesce(
                        card_time_subquery.c.max_card_time,
                        Concept.created_at
                    ).desc()
                )
            )
        else:
            concept_query = concept_query.order_by(Concept.created_at.desc())
    else:
        # Alphabetical sorting - use first visible language card term, fallback to concept.term
        if visible_language_codes and len(visible_language_codes) > 0:
            # Create aliases for cards to get the first visible language card
            first_lang = visible_language_codes[0]
            card_alias = aliased(Card)
            
            # Join with first visible language card for sorting
            concept_query = (
                concept_query
                .outerjoin(
                    card_alias,
                    (card_alias.concept_id == Concept.id) & 
                    (card_alias.language_code == first_lang) &
                    (card_alias.term.isnot(None)) &
                    (card_alias.term != "")
                )
                .order_by(
                    func.coalesce(
                        func.lower(card_alias.term),
                        func.lower(Concept.term)
                    ).asc()
                )
            )
        else:
            # Sort by concept.term
            concept_query = concept_query.order_by(func.lower(Concept.term).asc())
    
    # Apply pagination at database level
    offset = (page - 1) * page_size
    concept_query = concept_query.offset(offset).limit(page_size)
    
    # Execute query to get paginated concepts
    concepts = session.exec(concept_query).all()
    concept_ids = [c.id for c in concepts]
    
    # Calculate total_concepts_with_term (concepts with term or at least one card with term)
    # This is independent of search/pagination
    total_concepts_with_term_query = select(func.count(Concept.id)).where(
        or_(
            Concept.term.isnot(None),
            Concept.id.in_(
                select(Card.concept_id)
                .where(Card.term.isnot(None) & (Card.term != ""))
                .distinct()
            )
        )
    )
    total_concepts_with_term = session.exec(total_concepts_with_term_query).one()
    
    if not concept_ids:
        # Calculate concepts_with_all_visible_languages if needed
        concepts_with_all_visible_languages = None
        if visible_language_codes and len(visible_language_codes) > 0:
            # Count concepts that have cards with terms for all visible languages
            # Count distinct concept_ids that have cards for all languages
            count_subquery = (
                select(Card.concept_id)
                .where(
                    Card.language_code.in_(visible_language_codes),
                    Card.term.isnot(None),
                    Card.term != ""
                )
                .group_by(Card.concept_id)
                .having(func.count(func.distinct(Card.language_code)) == len(visible_language_codes))
                .subquery()
            )
            concepts_with_all_visible_languages = session.exec(
                select(func.count()).select_from(count_subquery)
            ).one()
        
        return VocabularyResponse(
            items=[],
            total=total,
            page=page,
            page_size=page_size,
            has_next=False,
            has_previous=page > 1,
            total_concepts_with_term=total_concepts_with_term,
            concepts_with_all_visible_languages=concepts_with_all_visible_languages
        )
    
    # Fetch cards for these concepts (only visible languages)
    if visible_language_codes:
        cards_query = (
            select(Card)
            .where(
                Card.concept_id.in_(concept_ids),
                Card.language_code.in_(visible_language_codes),
                Card.term.isnot(None),
                Card.term != ""
            )
        )
    else:
        cards_query = (
            select(Card)
            .where(
                Card.concept_id.in_(concept_ids),
                Card.term.isnot(None),
                Card.term != ""
            )
        )
    
    cards = session.exec(cards_query).all()
    
    # Group cards by concept_id and language_code
    concept_cards_map = {}
    for card in cards:
        if card.concept_id not in concept_cards_map:
            concept_cards_map[card.concept_id] = {}
        concept_cards_map[card.concept_id][card.language_code] = card
    
    # Fetch images for these concepts
    images_query = (
        select(Image)
        .where(Image.concept_id.in_(concept_ids))
        .order_by(Image.created_at)
    )
    images = session.exec(images_query).all()
    
    # Group images by concept_id
    concept_images_map = {}
    for img in images:
        if img.concept_id not in concept_images_map:
            concept_images_map[img.concept_id] = []
        concept_images_map[img.concept_id].append(ImageResponse.model_validate(img))
    
    # Build response items
    paired_items = []
    for concept in concepts:
        lang_cards = concept_cards_map.get(concept.id, {})
        concept_images = concept_images_map.get(concept.id, [])
        
        # Build list of cards for visible languages only (in order)
        visible_cards_list = []
        if visible_language_codes:
            for lang_code in visible_language_codes:
                card = lang_cards.get(lang_code)
                if card and card.term and card.term.strip():
                    visible_cards_list.append(
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
        else:
            for card in lang_cards.values():
                if card.term and card.term.strip():
                    visible_cards_list.append(
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
        
        source_card_response = visible_cards_list[0] if len(visible_cards_list) > 0 else None
        target_card_response = visible_cards_list[1] if len(visible_cards_list) > 1 else None
        
        paired_items.append(
            PairedVocabularyItem(
                concept_id=concept.id,
                cards=visible_cards_list,
                source_card=source_card_response,
                target_card=target_card_response,
                images=concept_images,
                part_of_speech=concept.part_of_speech,
                concept_term=concept.term,
                concept_description=concept.description,
                concept_level=concept.level.value if concept.level else None,
            )
        )
    
    # Calculate pagination metadata
    has_next = offset + page_size < total
    has_previous = page > 1
    
    # Calculate concepts with all visible languages (only if visible_languages specified)
    concepts_with_all_visible_languages = None
    if visible_language_codes and len(visible_language_codes) > 0:
        # Count concepts that have cards with terms for all visible languages
        count_subquery = (
            select(Card.concept_id)
            .where(
                Card.language_code.in_(visible_language_codes),
                Card.term.isnot(None),
                Card.term != ""
            )
            .group_by(Card.concept_id)
            .having(func.count(func.distinct(Card.language_code)) == len(visible_language_codes))
            .subquery()
        )
        concepts_with_all_visible_languages = session.exec(
            select(func.count()).select_from(count_subquery)
        ).one()
    
    return VocabularyResponse(
        items=paired_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=has_next,
        has_previous=has_previous,
        concepts_with_all_visible_languages=concepts_with_all_visible_languages,
        total_concepts_with_term=total_concepts_with_term
    )

