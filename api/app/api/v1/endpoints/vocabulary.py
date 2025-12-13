"""
Vocabulary endpoints for retrieving paired vocabulary items.
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func, or_
from sqlalchemy.orm import aliased
from typing import Optional, List
from app.core.database import get_session
from app.models.models import Concept, Card, Image, CEFRLevel
from app.schemas.flashcard import (
    CardResponse,
    PairedVocabularyItem,
    VocabularyResponse,
    ImageResponse,
    normalize_part_of_speech,
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
    sort_by: str = "alphabetical",  # Options: "alphabetical", "recent", "random"
    search: Optional[str] = None,  # Optional search query for concept.term and card.term
    visible_languages: Optional[str] = None,  # Comma-separated list of visible language codes - cards are filtered to these languages
    own_user_id: Optional[int] = None,  # Filter for concepts created by this user (concept.user_id == own_user_id)
    include_public: bool = True,  # Include public concepts (concept.user_id is null)
    include_private: bool = True,  # Include private concepts (concept.user_id == logged in user)
    topic_ids: Optional[str] = None,  # Comma-separated list of topic IDs to filter by
    include_without_topic: bool = False,  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None,  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None,  # Comma-separated list of part of speech values to filter by
    session: Session = Depends(get_session)
):
    """
    Get all concepts with cards for visible languages, with search and pagination.
    Optimized to do filtering, sorting, and pagination at the database level.
    
    Args:
        user_id: The user ID (optional - for future use)
        page: Page number (1-indexed, default: 1)
        page_size: Number of items per page (default: 20)
        sort_by: Sort order - "alphabetical" (default), "recent" (by created_at, newest first), or "random"
        search: Optional search query to filter by concept.term and card.term (for visible languages)
        visible_languages: Comma-separated list of visible language codes - only cards for these languages are returned
        own_user_id: Filter for concepts created by this user (concept.user_id == own_user_id) - deprecated, use include_public/include_private instead
        include_public: Include public concepts (concept.user_id is null) - default: True
        include_private: Include private concepts (concept.user_id == logged in user) - default: True
        topic_ids: Comma-separated list of topic IDs to filter by
        include_without_topic: Include concepts without a topic (topic_id is null)
        levels: Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
        part_of_speech: Comma-separated list of part of speech values to filter by
    """
    # Validate parameters
    if sort_by not in ["alphabetical", "recent", "random"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="sort_by must be 'alphabetical', 'recent', or 'random'"
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
    
    # Parse topic_ids parameter
    topic_id_list = None
    if topic_ids:
        try:
            topic_id_list = [int(tid.strip()) for tid in topic_ids.split(',') if tid.strip()]
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="topic_ids must be comma-separated integers"
            )
    
    # Parse levels parameter
    level_list = None
    if levels:
        level_strs = [level.strip().upper() for level in levels.split(',') if level.strip()]
        level_list = []
        for level_str in level_strs:
            try:
                level_list.append(CEFRLevel(level_str))
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid CEFR level: {level_str}. Must be one of: A1, A2, B1, B2, C1, C2"
                )
    
    # Parse part_of_speech parameter
    pos_list = None
    if part_of_speech:
        pos_list = []
        for pos in part_of_speech.split(','):
            pos_stripped = pos.strip()
            if pos_stripped:
                # Normalize POS value to proper case for comparison
                try:
                    normalized_pos = normalize_part_of_speech(pos_stripped)
                    pos_list.append(normalized_pos)
                except ValueError:
                    # If normalization fails, try lowercase comparison as fallback
                    # Database might have lowercase values
                    pos_list.append(pos_stripped)
    
    # Build base query for concepts - start with all concepts
    concept_query = select(Concept)
    
    # Apply public/private filters
    # If both are False, show nothing (empty result)
    # If both are True, show all (no filter)
    # Otherwise, filter by user_id
    if not include_public and not include_private:
        # Both filters are False - return empty result
        concept_query = concept_query.where(False)  # This will return no results
    elif include_public and include_private:
        # Both filters are True - show all concepts (no user_id filter)
        pass
    elif include_public and not include_private:
        # Only public - concepts where user_id is null
        concept_query = concept_query.where(Concept.user_id.is_(None))
    elif not include_public and include_private:
        # Only private - concepts where user_id matches logged in user
        if own_user_id is not None:
            concept_query = concept_query.where(Concept.user_id == own_user_id)
        else:
            # No logged in user, but only private requested - return empty result
            concept_query = concept_query.where(False)  # This will return no results
    
    # Apply topic_ids filter if provided
    if topic_id_list is not None and len(topic_id_list) > 0:
        if include_without_topic:
            # Include concepts with these topic IDs OR concepts without a topic
            concept_query = concept_query.where(
                or_(
                    Concept.topic_id.in_(topic_id_list),
                    Concept.topic_id.is_(None)
                )
            )
        else:
            # Only include concepts with these topic IDs
            concept_query = concept_query.where(Concept.topic_id.in_(topic_id_list))
    else:
        # topic_id_list is None/empty (all topics selected in frontend)
        if not include_without_topic:
            # Exclude concepts without a topic (only show concepts with a topic)
            concept_query = concept_query.where(Concept.topic_id.isnot(None))
        # If include_without_topic is True, show ALL concepts (no topic filter)
    
    # Apply levels filter if provided
    if level_list is not None and len(level_list) > 0:
        concept_query = concept_query.where(Concept.level.in_(level_list))
    
    # Apply part_of_speech filter if provided
    # Use case-insensitive comparison since database might have lowercase values
    if pos_list is not None and len(pos_list) > 0:
        # Convert all POS values to lowercase for case-insensitive comparison
        # Database stores lowercase ('noun', 'verb') but API receives proper case ('Noun', 'Verb')
        pos_list_lower = [pos.lower() for pos in pos_list]
        concept_query = concept_query.where(
            func.lower(Concept.part_of_speech).in_(pos_list_lower)
        )
    
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
    # Count distinct concepts to avoid any potential duplicates
    # At this point, concept_query has all filters applied but no joins yet
    # So we can safely count distinct concept IDs
    concept_subquery = concept_query.subquery()
    total_count_query = select(func.count(func.distinct(concept_subquery.c.id)))
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
    elif sort_by == "random":
        # Random sorting - use database random function
        # PostgreSQL uses random(), SQLite uses random(), MySQL uses RAND()
        # SQLAlchemy's func.random() should work for most databases
        concept_query = concept_query.order_by(func.random())
    else:
        # Alphabetical sorting - use first visible language card term, fallback to concept.term
        if visible_language_codes and len(visible_language_codes) > 0:
            # Use a subquery to get one card per concept for the first visible language
            # This prevents duplicates when a concept has multiple cards for the same language
            first_lang = visible_language_codes[0]
            card_sort_subquery = (
                select(
                    Card.concept_id,
                    func.min(Card.id).label('min_card_id')
                )
                .where(
                    Card.language_code == first_lang,
                    Card.term.isnot(None),
                    Card.term != ""
                )
                .group_by(Card.concept_id)
                .subquery()
            )
            
            # Join with the subquery to get the card ID, then join with Card to get the term
            card_alias = aliased(Card)
            concept_query = (
                concept_query
                .outerjoin(card_sort_subquery, Concept.id == card_sort_subquery.c.concept_id)
                .outerjoin(
                    card_alias,
                    (card_alias.id == card_sort_subquery.c.min_card_id)
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
    
    # Deduplicate concepts by ID (in case join created duplicates)
    seen_concept_ids = set()
    unique_concepts = []
    for concept in concepts:
        if concept.id not in seen_concept_ids:
            seen_concept_ids.add(concept.id)
            unique_concepts.append(concept)
    concepts = unique_concepts
    
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
        
        # Get topic information safely
        topic_name = None
        topic_id = None
        topic_description = None
        if concept.topic_id:
            topic_id = concept.topic_id
            # Access topic relationship - SQLModel will lazy load if needed
            try:
                if concept.topic:
                    topic_name = concept.topic.name
                    topic_description = concept.topic.description
            except Exception:
                # If topic relationship is not loaded or doesn't exist, topic_name stays None
                pass
        
        paired_items.append(
            PairedVocabularyItem(
                concept_id=concept.id,
                cards=visible_cards_list,
                source_card=source_card_response,
                target_card=target_card_response,
                images=concept_images,
                part_of_speech=concept.part_of_speech,
                concept_term=concept.term if concept.term and concept.term.strip() else None,
                concept_description=concept.description if concept.description and concept.description.strip() else None,
                concept_level=concept.level.value if concept.level else None,
                topic_name=topic_name,
                topic_id=topic_id,
                topic_description=topic_description,
            )
        )
    
    # Calculate pagination metadata
    has_next = offset + page_size < total
    has_previous = page > 1
    
    # Calculate concepts with all visible languages (only if visible_languages specified)
    # This count should include all filters (topic, level, POS, public/private, search)
    concepts_with_all_visible_languages = None
    if visible_language_codes and len(visible_language_codes) > 0:
        # Build the same filtered concept query as the main query (without pagination/sorting)
        # Start with all concepts
        filtered_concept_query = select(Concept)
        
        # Apply public/private filters (same as main query)
        if not include_public and not include_private:
            filtered_concept_query = filtered_concept_query.where(False)
        elif include_public and not include_private:
            filtered_concept_query = filtered_concept_query.where(Concept.user_id.is_(None))
        elif not include_public and include_private:
            if own_user_id is not None:
                filtered_concept_query = filtered_concept_query.where(Concept.user_id == own_user_id)
            else:
                filtered_concept_query = filtered_concept_query.where(False)
        
        # Apply topic_ids filter (same as main query)
        if topic_id_list is not None and len(topic_id_list) > 0:
            if include_without_topic:
                filtered_concept_query = filtered_concept_query.where(
                    or_(
                        Concept.topic_id.in_(topic_id_list),
                        Concept.topic_id.is_(None)
                    )
                )
            else:
                filtered_concept_query = filtered_concept_query.where(Concept.topic_id.in_(topic_id_list))
        else:
            if not include_without_topic:
                filtered_concept_query = filtered_concept_query.where(Concept.topic_id.isnot(None))
        
        # Apply levels filter (same as main query)
        if level_list is not None and len(level_list) > 0:
            filtered_concept_query = filtered_concept_query.where(Concept.level.in_(level_list))
        
        # Apply part_of_speech filter (same as main query)
        if pos_list is not None and len(pos_list) > 0:
            pos_list_lower = [pos.lower() for pos in pos_list]
            filtered_concept_query = filtered_concept_query.where(
                func.lower(Concept.part_of_speech).in_(pos_list_lower)
            )
        
        # Apply search filter (same as main query)
        if search and search.strip():
            search_term = f"%{search.strip().lower()}%"
            if visible_language_codes:
                card_search_subquery = (
                    select(Card.concept_id)
                    .where(
                        Card.language_code.in_(visible_language_codes),
                        func.lower(Card.term).like(search_term)
                    )
                    .distinct()
                )
                filtered_concept_query = filtered_concept_query.where(
                    or_(
                        func.lower(Concept.term).like(search_term),
                        Concept.id.in_(card_search_subquery)
                    )
                )
            else:
                card_search_subquery = (
                    select(Card.concept_id)
                    .where(func.lower(Card.term).like(search_term))
                    .distinct()
                )
                filtered_concept_query = filtered_concept_query.where(
                    or_(
                        func.lower(Concept.term).like(search_term),
                        Concept.id.in_(card_search_subquery)
                    )
                )
        
        # Now filter to concepts that have cards for all visible languages
        # Get concept IDs from the filtered query
        filtered_concept_ids_subquery = filtered_concept_query.subquery()
        
        # Find concepts that have cards for all visible languages
        card_count_subquery = (
            select(Card.concept_id)
            .where(
                Card.concept_id.in_(select(filtered_concept_ids_subquery.c.id)),
                Card.language_code.in_(visible_language_codes),
                Card.term.isnot(None),
                Card.term != ""
            )
            .group_by(Card.concept_id)
            .having(func.count(func.distinct(Card.language_code)) == len(visible_language_codes))
            .subquery()
        )
        
        concepts_with_all_visible_languages = session.exec(
            select(func.count()).select_from(card_count_subquery)
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

