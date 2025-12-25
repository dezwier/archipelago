"""
Dictionary service for querying and filtering concepts and lemmas.
"""
from fastapi import HTTPException, status
from sqlmodel import select, func
from sqlalchemy.orm import aliased
from typing import Optional, List
from app.models.models import Concept, Lemma, Topic
from app.models.concept_topic import ConceptTopic
from app.schemas.lemma import LemmaResponse
from app.schemas.concept import PairedDictionaryItem
from app.utils.text_utils import ensure_capitalized
from app.services.filter_service import (
    build_base_filtered_query,
    build_filtered_query,
)
from app.schemas.filter import FilterConfig


# ============================================================================
# Request Validation Helpers
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
    """Apply alphabetical sorting.
    
    Always uses the first visible language for sorting when available.
    If no visible languages are specified, falls back to Concept.term.
    """
    if visible_language_codes and len(visible_language_codes) > 0:
        # Always use the first visible language for alphabetical sorting
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
        # No visible languages specified - fallback to concept.term
        # This should rarely happen as visible languages should always be set
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


def get_topic_info(concept: Concept, session) -> tuple[Optional[str], List[int], Optional[str], Optional[str], List[dict]]:
    """Get topic information from concept safely.
    
    Returns:
        tuple: (topic_name, topic_ids, topic_description, topic_icon, topics_list)
        - topic_name: First topic name (for backward compatibility)
        - topic_ids: List of all topic IDs
        - topic_description: First topic description (for backward compatibility)
        - topic_icon: First topic icon (for backward compatibility)
        - topics_list: List of dicts with id, name, icon for all topics
    """
    topic_name = None
    topic_ids = []
    topic_description = None
    topic_icon = None
    topics_list = []
    
    # Get topics from ConceptTopic junction table
    concept_topics = session.exec(
        select(ConceptTopic).where(ConceptTopic.concept_id == concept.id)
    ).all()
    
    if concept_topics:
        topic_ids = [ct.topic_id for ct in concept_topics]
        
        # Load all topics
        for ct in concept_topics:
            topic = session.get(Topic, ct.topic_id)
            if topic:
                topics_list.append({
                    'id': topic.id,
                    'name': topic.name,
                    'icon': topic.icon,
                })
        
        # Get first topic for backward compatibility (topic_id, topic_name, etc.)
        if topics_list:
            first_topic = topics_list[0]
            topic_name = first_topic['name']
            topic_description = None  # Not used in first topic, but kept for compatibility
            topic_icon = first_topic['icon']
    
    return topic_name, topic_ids, topic_description, topic_icon, topics_list


def build_paired_dictionary_items(
    concepts: List[Concept],
    concept_lemmas_map: dict,
    visible_language_codes: Optional[List[str]],
    session
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
        
        topic_name, topic_ids, topic_description, topic_icon, topics_list = get_topic_info(concept, session)
        # Get first topic_id for backward compatibility
        topic_id = topic_ids[0] if topic_ids else None
        
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
                topic_ids=topic_ids,
                topic_description=topic_description,
                topic_icon=topic_icon,
                topics=topics_list,
            )
        )
    
    return paired_items


def calculate_concepts_with_all_visible_languages(
    session,
    filter_config: FilterConfig,
    visible_language_codes: List[str]
) -> int:
    """Calculate count of concepts that have lemmas for all visible languages.
    
    Args:
        session: Database session
        filter_config: FilterConfig object with filter parameters
        visible_language_codes: List of visible language codes
        
    Returns:
        Count of concepts that have lemmas for all visible languages
    """
    # Build the same filtered concept query as the main query (without pagination/sorting)
    filtered_concept_query = build_filtered_query(filter_config)
    
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

