"""
Helper functions for dictionary endpoint.
These functions extract complex logic from the main dictionary endpoint for better maintainability.
"""
from fastapi import HTTPException, status
from sqlmodel import select, func, or_
from sqlalchemy import and_
from sqlalchemy.orm import aliased
from typing import Optional, List
from app.models.models import Concept, Lemma, CEFRLevel
from app.schemas.lemma import LemmaResponse
from app.schemas.concept import PairedDictionaryItem
from app.schemas.utils import normalize_part_of_speech
from app.api.v1.endpoints.utils import ensure_capitalized


# ============================================================================
# Parameter Parsing and Validation Helpers
# ============================================================================

def validate_request_parameters(sort_by: str, page: int, page_size: int) -> None:
    """Validate request parameters."""
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


def parse_visible_languages(visible_languages: Optional[str]) -> Optional[List[str]]:
    """Parse visible_languages parameter into a list of language codes."""
    if not visible_languages:
        return None
    return [lang.strip().lower() for lang in visible_languages.split(',') if lang.strip()]


def parse_topic_ids(topic_ids: Optional[str]) -> Optional[List[int]]:
    """Parse topic_ids parameter into a list of topic IDs."""
    if not topic_ids:
        return None
    try:
        return [int(tid.strip()) for tid in topic_ids.split(',') if tid.strip()]
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="topic_ids must be comma-separated integers"
        ) from exc


def parse_levels(levels: Optional[str]) -> Optional[List[CEFRLevel]]:
    """Parse levels parameter into a list of CEFRLevel enums."""
    if not levels:
        return None
    level_strs = [level.strip().upper() for level in levels.split(',') if level.strip()]
    level_list = []
    for level_str in level_strs:
        try:
            level_list.append(CEFRLevel(level_str))
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid CEFR level: {level_str}. Must be one of: A1, A2, B1, B2, C1, C2"
            ) from exc
    return level_list


def parse_part_of_speech(part_of_speech: Optional[str]) -> Optional[List[str]]:
    """Parse part_of_speech parameter into a list of normalized POS values."""
    if not part_of_speech:
        return None
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
    return pos_list


# ============================================================================
# Query Filter Building Helpers
# ============================================================================

def apply_user_id_filter(query, user_id: Optional[int]):
    """Apply user_id filter to concept query."""
    if user_id is not None:
        # Show public concepts (user_id IS NULL) OR concepts belonging to this user
        return query.where(
            or_(
                Concept.user_id.is_(None),
                Concept.user_id == user_id
            )
        )
    else:
        # When logged out, show only public concepts (user_id IS NULL)
        return query.where(Concept.user_id.is_(None))


def apply_lemmas_phrases_filter(query, include_lemmas: bool, include_phrases: bool):
    """Apply lemmas/phrases filter using is_phrase field."""
    if not include_lemmas and not include_phrases:
        # Both filters are False - return empty result
        return query.where(False)  # This will return no results
    elif include_lemmas and include_phrases:
        # Both filters are True - show all concepts (no is_phrase filter)
        return query
    elif include_lemmas and not include_phrases:
        # Only lemmas - concepts where is_phrase is False
        return query.where(Concept.is_phrase == False)
    elif not include_lemmas and include_phrases:
        # Only phrases - concepts where is_phrase is True
        return query.where(Concept.is_phrase == True)
    return query


def apply_topic_filter(query, topic_id_list: Optional[List[int]], include_without_topic: bool):
    """Apply topic_ids filter to concept query."""
    if topic_id_list is not None and len(topic_id_list) > 0:
        # When filtering by topic(s), only show concepts with those topic IDs
        # Always exclude concepts without a topic when topic_ids are provided
        return query.where(Concept.topic_id.in_(topic_id_list))
    else:
        # topic_id_list is None/empty (all topics selected in frontend)
        if not include_without_topic:
            # Exclude concepts without a topic (only show concepts with a topic)
            return query.where(Concept.topic_id.isnot(None))
        # If include_without_topic is True, show ALL concepts (no topic filter)
        return query


def apply_levels_filter(query, level_list: Optional[List[CEFRLevel]]):
    """Apply levels filter to concept query."""
    if level_list is not None and len(level_list) > 0:
        return query.where(Concept.level.in_(level_list))
    return query


def apply_part_of_speech_filter(query, pos_list: Optional[List[str]]):
    """Apply part_of_speech filter to concept query."""
    if pos_list is not None and len(pos_list) > 0:
        # Convert all POS values to lowercase for case-insensitive comparison
        # Database stores lowercase ('noun', 'verb') but API receives proper case ('Noun', 'Verb')
        pos_list_lower = [pos.lower() for pos in pos_list]
        return query.where(func.lower(Concept.part_of_speech).in_(pos_list_lower))
    return query


def apply_has_images_filter(query, has_images: Optional[int]):
    """Apply has_images filter to concept query."""
    if has_images == 1:
        # Include only concepts with images (image_url is not None and not empty)
        return query.where(
            and_(
                Concept.image_url.isnot(None),
                Concept.image_url != ""
            )
        )
    elif has_images == 0:
        # Include only concepts without images (image_url is None or empty)
        return query.where(
            or_(
                Concept.image_url.is_(None),
                Concept.image_url == ""
            )
        )
    # If has_images is None, include all (no filter)
    return query


def build_incomplete_lemma_subquery(visible_language_codes: Optional[List[str]]):
    """Build subquery to find concepts with incomplete lemmas."""
    base_query = select(Lemma.concept_id).where(
        or_(
            Lemma.term.is_(None),
            Lemma.term == "",
            Lemma.ipa.is_(None),
            Lemma.ipa == "",
            Lemma.description.is_(None),
            Lemma.description == ""
        )
    )
    
    if visible_language_codes:
        base_query = base_query.where(Lemma.language_code.in_(visible_language_codes))
    
    return base_query.distinct()


def build_complete_lemma_subquery(visible_language_codes: List[str]):
    """Build subquery to find concepts with complete lemmas for all visible languages."""
    return (
        select(Lemma.concept_id)
        .where(
            Lemma.language_code.in_(visible_language_codes),
            Lemma.term.isnot(None),
            Lemma.term != "",
            Lemma.ipa.isnot(None),
            Lemma.ipa != "",
            Lemma.description.isnot(None),
            Lemma.description != ""
        )
        .group_by(Lemma.concept_id)
        .having(func.count(func.distinct(Lemma.language_code)) == len(visible_language_codes))
        .subquery()
    )


def apply_is_complete_filter(query, is_complete: Optional[int], visible_language_codes: Optional[List[str]]):
    """Apply is_complete filter to concept query."""
    if is_complete is None:
        return query
    
    if visible_language_codes:
        complete_lemma_subquery = build_complete_lemma_subquery(visible_language_codes)
        
        if is_complete == 1:
            # Include only complete concepts (have complete lemmas for all visible languages)
            return query.where(Concept.id.in_(select(complete_lemma_subquery.c.concept_id)))
        elif is_complete == 0:
            # Include only incomplete concepts (do NOT have complete lemmas for all visible languages)
            return query.where(~Concept.id.in_(select(complete_lemma_subquery.c.concept_id)))
    else:
        # If no visible languages specified, check all lemmas for completeness
        incomplete_lemma_subquery = build_incomplete_lemma_subquery(None)
        if is_complete == 1:
            # Include only complete concepts (exclude incomplete)
            return query.where(~Concept.id.in_(incomplete_lemma_subquery))
        elif is_complete == 0:
            # Include only incomplete concepts
            return query.where(Concept.id.in_(incomplete_lemma_subquery))
    
    return query


def build_lemma_search_subquery(search_term: str, visible_language_codes: Optional[List[str]]):
    """Build subquery to find concept_ids that match search in lemmas."""
    query = select(Lemma.concept_id).where(func.lower(Lemma.term).like(search_term))
    
    if visible_language_codes:
        query = query.where(Lemma.language_code.in_(visible_language_codes))
    
    return query.distinct()


def apply_search_filter(query, search: Optional[str], visible_language_codes: Optional[List[str]]):
    """Apply search filter to concept query."""
    if not search or not search.strip():
        return query
    
    search_term = f"%{search.strip().lower()}%"
    lemma_search_subquery = build_lemma_search_subquery(search_term, visible_language_codes)
    
    # Filter concepts where term matches OR has matching lemmas
    return query.where(
        or_(
            func.lower(Concept.term).like(search_term),
            Concept.id.in_(lemma_search_subquery)
        )
    )


def build_base_filtered_query(
    user_id: Optional[int],
    include_lemmas: bool,
    include_phrases: bool,
    topic_id_list: Optional[List[int]],
    include_without_topic: bool,
    level_list: Optional[List[CEFRLevel]],
    pos_list: Optional[List[str]],
    has_images: Optional[int],
    is_complete: Optional[int],
    visible_language_codes: Optional[List[str]],
    search: Optional[str]
):
    """Build base filtered concept query with all filters applied."""
    query = select(Concept)
    query = apply_user_id_filter(query, user_id)
    query = apply_lemmas_phrases_filter(query, include_lemmas, include_phrases)
    query = apply_topic_filter(query, topic_id_list, include_without_topic)
    query = apply_levels_filter(query, level_list)
    query = apply_part_of_speech_filter(query, pos_list)
    query = apply_has_images_filter(query, has_images)
    query = apply_is_complete_filter(query, is_complete, visible_language_codes)
    query = apply_search_filter(query, search, visible_language_codes)
    return query


# ============================================================================
# Sorting Helpers
# ============================================================================

def apply_recent_sorting(query, visible_language_codes: Optional[List[str]]):
    """Apply recent sorting (by created_at descending)."""
    if visible_language_codes:
        # Subquery to get max created_at from visible language lemmas
        lemma_time_subquery = (
            select(
                Lemma.concept_id,
                func.max(Lemma.created_at).label('max_lemma_time')
            )
            .where(
                Lemma.language_code.in_(visible_language_codes),
                Lemma.term.isnot(None),
                Lemma.term != ""
            )
            .group_by(Lemma.concept_id)
            .subquery()
        )
        # Join and sort by max lemma time or concept time
        return (
            query
            .outerjoin(lemma_time_subquery, Concept.id == lemma_time_subquery.c.concept_id)
            .order_by(
                func.coalesce(
                    lemma_time_subquery.c.max_lemma_time,
                    Concept.created_at
                ).desc()
            )
        )
    else:
        return query.order_by(Concept.created_at.desc())


def apply_alphabetical_sorting(query, visible_language_codes: Optional[List[str]]):
    """Apply alphabetical sorting."""
    if visible_language_codes and len(visible_language_codes) > 0:
        # Use a subquery to get one lemma per concept for the first visible language
        # This prevents duplicates when a concept has multiple lemmas for the same language
        first_lang = visible_language_codes[0]
        lemma_sort_subquery = (
            select(
                Lemma.concept_id,
                func.min(Lemma.id).label('min_lemma_id')
            )
            .where(
                Lemma.language_code == first_lang,
                Lemma.term.isnot(None),
                Lemma.term != ""
            )
            .group_by(Lemma.concept_id)
            .subquery()
        )
        
        # Join with the subquery to get the lemma ID, then join with Lemma to get the term
        lemma_alias = aliased(Lemma)
        return (
            query
            .outerjoin(lemma_sort_subquery, Concept.id == lemma_sort_subquery.c.concept_id)
            .outerjoin(
                lemma_alias,
                (lemma_alias.id == lemma_sort_subquery.c.min_lemma_id)
            )
            .order_by(
                func.coalesce(
                    func.lower(lemma_alias.term),
                    func.lower(Concept.term)
                ).asc()
            )
        )
    else:
        # Sort by concept.term
        return query.order_by(func.lower(Concept.term).asc())


def apply_sorting(query, sort_by: str, visible_language_codes: Optional[List[str]]):
    """Apply sorting to concept query."""
    if sort_by == "recent":
        return apply_recent_sorting(query, visible_language_codes)
    elif sort_by == "random":
        # Random sorting - use database random function
        return query.order_by(func.random())
    else:
        # Alphabetical sorting
        return apply_alphabetical_sorting(query, visible_language_codes)


# ============================================================================
# Response Building Helpers
# ============================================================================

def build_lemma_response(lemma: Lemma) -> LemmaResponse:
    """Build a LemmaResponse from a Lemma model."""
    return LemmaResponse(
        id=lemma.id,
        concept_id=lemma.concept_id,
        language_code=lemma.language_code,
        translation=ensure_capitalized(lemma.term),
        description=lemma.description,
        ipa=lemma.ipa,
        audio_path=lemma.audio_url,
        gender=lemma.gender,
        article=lemma.article,
        plural_form=lemma.plural_form,
        verb_type=lemma.verb_type,
        auxiliary_verb=lemma.auxiliary_verb,
        formality_register=lemma.formality_register,
        notes=lemma.notes
    )


def build_visible_lemmas_list(
    concept_id: int,
    concept_lemmas_map: dict,
    visible_language_codes: Optional[List[str]]
) -> List[LemmaResponse]:
    """Build list of lemmas for visible languages only (in order)."""
    lang_lemmas = concept_lemmas_map.get(concept_id, {})
    visible_lemmas_list = []
    
    if visible_language_codes:
        for lang_code in visible_language_codes:
            lemma = lang_lemmas.get(lang_code)
            if lemma and lemma.term and lemma.term.strip():
                visible_lemmas_list.append(build_lemma_response(lemma))
    else:
        for lemma in lang_lemmas.values():
            if lemma.term and lemma.term.strip():
                visible_lemmas_list.append(build_lemma_response(lemma))
    
    return visible_lemmas_list


def get_topic_info(concept: Concept) -> tuple[Optional[str], Optional[int], Optional[str], Optional[str]]:
    """Get topic information from concept safely."""
    topic_name = None
    topic_id = None
    topic_description = None
    topic_icon = None
    
    if concept.topic_id:
        topic_id = concept.topic_id
        # Access topic relationship - SQLModel will lazy load if needed
        try:
            if concept.topic:
                topic_name = concept.topic.name
                topic_description = concept.topic.description
                topic_icon = concept.topic.icon
        except Exception:  # noqa: BLE001
            # If topic relationship is not loaded or doesn't exist, topic_name stays None
            pass
    
    return topic_name, topic_id, topic_description, topic_icon


def build_paired_dictionary_items(
    concepts: List[Concept],
    concept_lemmas_map: dict,
    visible_language_codes: Optional[List[str]]
) -> List[PairedDictionaryItem]:
    """Build list of PairedDictionaryItem from concepts and lemmas."""
    paired_items = []
    for concept in concepts:
        visible_lemmas_list = build_visible_lemmas_list(
            concept.id,
            concept_lemmas_map,
            visible_language_codes
        )
        
        source_lemma_response = visible_lemmas_list[0] if len(visible_lemmas_list) > 0 else None
        target_lemma_response = visible_lemmas_list[1] if len(visible_lemmas_list) > 1 else None
        
        topic_name, topic_id, topic_description, topic_icon = get_topic_info(concept)
        
        paired_items.append(
            PairedDictionaryItem(
                concept_id=concept.id,
                lemmas=visible_lemmas_list,
                source_lemma=source_lemma_response,
                target_lemma=target_lemma_response,
                image_url=concept.image_url,
                part_of_speech=concept.part_of_speech,
                concept_term=concept.term if concept.term and concept.term.strip() else None,
                concept_description=concept.description if concept.description and concept.description.strip() else None,
                concept_level=concept.level.value if concept.level else None,
                topic_name=topic_name,
                topic_id=topic_id,
                topic_description=topic_description,
                topic_icon=topic_icon,
            )
        )
    
    return paired_items


def calculate_concepts_with_all_visible_languages(
    session,
    visible_language_codes: List[str],
    user_id: Optional[int],
    include_lemmas: bool,
    include_phrases: bool,
    topic_id_list: Optional[List[int]],
    include_without_topic: bool,
    level_list: Optional[List[CEFRLevel]],
    pos_list: Optional[List[str]],
    has_images: Optional[int],
    is_complete: Optional[int],
    search: Optional[str]
) -> int:
    """Calculate count of concepts that have lemmas for all visible languages."""
    # Build the same filtered concept query as the main query (without pagination/sorting)
    filtered_concept_query = build_base_filtered_query(
        user_id=user_id,
        include_lemmas=include_lemmas,
        include_phrases=include_phrases,
        topic_id_list=topic_id_list,
        include_without_topic=include_without_topic,
        level_list=level_list,
        pos_list=pos_list,
        has_images=has_images,
        is_complete=is_complete,
        visible_language_codes=visible_language_codes,
        search=search
    )
    
    # Now filter to concepts that have lemmas for all visible languages
    # Get concept IDs from the filtered query
    filtered_concept_ids_subquery = filtered_concept_query.subquery()
    
    # Find concepts that have lemmas for all visible languages
    lemma_count_subquery = (
        select(Lemma.concept_id)
        .where(
            Lemma.concept_id.in_(select(filtered_concept_ids_subquery.c.id)),
            Lemma.language_code.in_(visible_language_codes),
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
        .group_by(Lemma.concept_id)
        .having(func.count(func.distinct(Lemma.language_code)) == len(visible_language_codes))
        .subquery()
    )
    
    return session.exec(
        select(func.count()).select_from(lemma_count_subquery)
    ).one()

