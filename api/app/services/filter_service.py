"""
Filter service for parsing and applying concept filters.
"""
from fastapi import HTTPException, status
from sqlmodel import select, func, or_
from sqlalchemy import and_
from typing import Optional, List
from app.models.models import Concept, Lemma, CEFRLevel
from app.schemas.filter import FilterConfig
from app.schemas.utils import normalize_part_of_speech


# ============================================================================
# Parameter Parsing Helpers
# ============================================================================

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


def parse_filter_config(filter_config: FilterConfig) -> dict:
    """Parse FilterConfig into internal representation with parsed values.
    
    Returns a dictionary with parsed filter values:
    - visible_language_codes: Optional[List[str]]
    - topic_id_list: Optional[List[int]]
    - level_list: Optional[List[CEFRLevel]]
    - pos_list: Optional[List[str]]
    """
    return {
        "user_id": filter_config.user_id,
        "visible_language_codes": parse_visible_languages(filter_config.visible_languages),
        "include_lemmas": filter_config.include_lemmas,
        "include_phrases": filter_config.include_phrases,
        "topic_id_list": parse_topic_ids(filter_config.topic_ids),
        "include_without_topic": filter_config.include_without_topic,
        "level_list": parse_levels(filter_config.levels),
        "pos_list": parse_part_of_speech(filter_config.part_of_speech),
        "has_images": filter_config.has_images,
        "has_audio": filter_config.has_audio,
        "is_complete": filter_config.is_complete,
        "search": filter_config.search,
    }


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


def build_audio_lemma_subquery(visible_language_codes: List[str]):
    """Build subquery to find concepts with audio for all visible languages."""
    return (
        select(Lemma.concept_id)
        .where(
            Lemma.language_code.in_(visible_language_codes),
            Lemma.audio_url.isnot(None),
            Lemma.audio_url != ""
        )
        .group_by(Lemma.concept_id)
        .having(func.count(func.distinct(Lemma.language_code)) == len(visible_language_codes))
        .subquery()
    )


def apply_has_audio_filter(query, has_audio: Optional[int], visible_language_codes: Optional[List[str]]):
    """Apply has_audio filter to concept query.
    
    Audio is stored in lemmas (audio_url field). If visible_language_codes is provided,
    checks that ALL visible languages have audio. Otherwise checks if any lemma has audio.
    """
    if has_audio is None:
        # If has_audio is None, include all (no filter)
        return query
    
    if visible_language_codes and len(visible_language_codes) > 0:
        # Check that all visible languages have audio
        audio_lemma_subquery = build_audio_lemma_subquery(visible_language_codes)
        
        if has_audio == 1:
            # Include only concepts with audio for ALL visible languages
            return query.where(Concept.id.in_(select(audio_lemma_subquery.c.concept_id)))
        elif has_audio == 0:
            # Include only concepts without audio for at least one visible language
            # (i.e., concepts NOT in the "all audio" subquery)
            return query.where(~Concept.id.in_(select(audio_lemma_subquery.c.concept_id)))
    else:
        # No visible languages specified - check if any lemma has audio
        audio_lemma_subquery = select(Lemma.concept_id).where(
            and_(
                Lemma.audio_url.isnot(None),
                Lemma.audio_url != ""
            )
        ).distinct().subquery()
        
        if has_audio == 1:
            # Include only concepts with audio (have at least one lemma with audio_url)
            return query.where(Concept.id.in_(select(audio_lemma_subquery.c.concept_id)))
        elif has_audio == 0:
            # Include only concepts without audio (do NOT have any lemma with audio_url)
            return query.where(~Concept.id.in_(select(audio_lemma_subquery.c.concept_id)))
    
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


def build_filtered_query(filter_config: FilterConfig):
    """Build base filtered concept query with all filters applied from FilterConfig.
    
    Args:
        filter_config: FilterConfig object with filter parameters
        
    Returns:
        SQLModel query with all filters applied
    """
    parsed = parse_filter_config(filter_config)
    
    query = select(Concept)
    query = apply_user_id_filter(query, parsed["user_id"])
    query = apply_lemmas_phrases_filter(query, parsed["include_lemmas"], parsed["include_phrases"])
    query = apply_topic_filter(query, parsed["topic_id_list"], parsed["include_without_topic"])
    query = apply_levels_filter(query, parsed["level_list"])
    query = apply_part_of_speech_filter(query, parsed["pos_list"])
    query = apply_has_images_filter(query, parsed["has_images"])
    query = apply_has_audio_filter(query, parsed["has_audio"], parsed["visible_language_codes"])
    query = apply_is_complete_filter(query, parsed["is_complete"], parsed["visible_language_codes"])
    query = apply_search_filter(query, parsed["search"], parsed["visible_language_codes"])
    return query


def get_visible_language_codes(filter_config: FilterConfig) -> Optional[List[str]]:
    """Get parsed visible language codes from FilterConfig.
    
    Args:
        filter_config: FilterConfig object with filter parameters
        
    Returns:
        Optional list of visible language codes, or None if not specified
    """
    parsed = parse_filter_config(filter_config)
    return parsed["visible_language_codes"]


# Backward compatibility: keep the old function name that takes individual parameters
def build_base_filtered_query(
    user_id: Optional[int],
    include_lemmas: bool,
    include_phrases: bool,
    topic_id_list: Optional[List[int]],
    include_without_topic: bool,
    level_list: Optional[List[CEFRLevel]],
    pos_list: Optional[List[str]],
    has_images: Optional[int],
    has_audio: Optional[int],
    is_complete: Optional[int],
    visible_language_codes: Optional[List[str]],
    search: Optional[str]
):
    """Build base filtered concept query with all filters applied.
    
    This function is kept for backward compatibility. New code should use build_filtered_query() with FilterConfig.
    """
    query = select(Concept)
    query = apply_user_id_filter(query, user_id)
    query = apply_lemmas_phrases_filter(query, include_lemmas, include_phrases)
    query = apply_topic_filter(query, topic_id_list, include_without_topic)
    query = apply_levels_filter(query, level_list)
    query = apply_part_of_speech_filter(query, pos_list)
    query = apply_has_images_filter(query, has_images)
    query = apply_has_audio_filter(query, has_audio, visible_language_codes)
    query = apply_is_complete_filter(query, is_complete, visible_language_codes)
    query = apply_search_filter(query, search, visible_language_codes)
    return query

