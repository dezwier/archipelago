"""
Dictionary endpoints for retrieving paired dictionary items.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends
from sqlmodel import Session, select, func, or_
from typing import Optional
from app.core.database import get_session
from app.models.models import Concept, Lemma
from app.schemas.concept import DictionaryResponse
from app.api.v1.endpoints.dictionary_helpers import (
    validate_request_parameters,
    parse_visible_languages,
    parse_topic_ids,
    parse_levels,
    parse_part_of_speech,
    build_base_filtered_query,
    apply_sorting,
    build_paired_dictionary_items,
    calculate_concepts_with_all_visible_languages,
)
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dictionary", tags=["dictionary"])


@router.get("", response_model=DictionaryResponse)
async def get_dictionary(
    user_id: Optional[int] = None,
    page: int = 1,
    page_size: int = 20,
    sort_by: str = "alphabetical",  # Options: "alphabetical", "recent", "random"
    search: Optional[str] = None,  # Optional search query for concept.term and lemma.term
    visible_languages: Optional[str] = None,  # Comma-separated list of visible language codes - lemmas are filtered to these languages
    include_lemmas: bool = True,  # Include lemmas (concept.is_phrase is False)
    include_phrases: bool = True,  # Include phrases (concept.is_phrase is True)
    topic_ids: Optional[str] = None,  # Comma-separated list of topic IDs to filter by
    include_without_topic: bool = True,  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None,  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None,  # Comma-separated list of part of speech values to filter by
    has_images: Optional[int] = None,  # 1 = include only concepts with images, 0 = include only concepts without images, null = include all
    is_complete: Optional[int] = None,  # 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    session: Session = Depends(get_session)
):
    """
    Get all concepts with lemmas for visible languages, with search and pagination.
    Optimized to do filtering, sorting, and pagination at the database level.
    
    Args:
        user_id: The user ID (optional - for future use)
        page: Page number (1-indexed, default: 1)
        page_size: Number of items per page (default: 20)
        sort_by: Sort order - "alphabetical" (default), "recent" (by created_at, newest first), or "random"
        search: Optional search query to filter by concept.term and lemma.term (for visible languages)
        visible_languages: Comma-separated list of visible language codes - only lemmas for these languages are returned
        include_lemmas: Include lemmas (concept.is_phrase is False)
        include_phrases: Include phrases (concept.is_phrase is True)
        topic_ids: Comma-separated list of topic IDs to filter by
        include_without_topic: Include concepts without a topic (topic_id is null)
        levels: Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
        part_of_speech: Comma-separated list of part of speech values to filter by
        has_images: 1 = include only concepts with images, 0 = include only concepts without images, null = include all
        is_complete: 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    """
    # Validate and parse parameters
    validate_request_parameters(sort_by, page, page_size)
    
    visible_language_codes = parse_visible_languages(visible_languages)
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    # Build base filtered query
    concept_query = build_base_filtered_query(
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

    # Get total count before pagination (for concepts matching search)
    # Count distinct concepts to avoid any potential duplicates
    # At this point, concept_query has all filters applied but no joins yet
    # So we can safely count distinct concept IDs
    concept_subquery = concept_query.subquery()
    total_count_query = select(func.count(func.distinct(concept_subquery.c.id)))
    total = session.exec(total_count_query).one()
    
    # Apply sorting
    concept_query = apply_sorting(concept_query, sort_by, visible_language_codes)

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
    
    # Calculate total_concepts_with_term (concepts with term or at least one lemma with term)
    # This is independent of search/pagination
    total_concepts_with_term_query = select(func.count(Concept.id)).where(
        or_(
            Concept.term.isnot(None),
            Concept.id.in_(
                select(Lemma.concept_id)
                .where(Lemma.term.isnot(None) & (Lemma.term != ""))
                .distinct()
            )
        )
    )
    total_concepts_with_term = session.exec(total_concepts_with_term_query).one()
    
    # Fetch lemmas for these concepts (only visible languages)
    if visible_language_codes:
        lemmas_query = (
            select(Lemma)
            .where(
                Lemma.concept_id.in_(concept_ids),
                Lemma.language_code.in_(visible_language_codes),
                Lemma.term.isnot(None),
                Lemma.term != ""
            )
        )
    else:
        lemmas_query = (
            select(Lemma)
            .where(
                Lemma.concept_id.in_(concept_ids),
                Lemma.term.isnot(None),
                Lemma.term != ""
            )
        )
    
    lemmas = session.exec(lemmas_query).all()
    
    # Group lemmas by concept_id and language_code
    concept_lemmas_map = {}
    for lemma in lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = {}
        concept_lemmas_map[lemma.concept_id][lemma.language_code] = lemma
    
    # Build response items
    paired_items = build_paired_dictionary_items(
        concepts,
        concept_lemmas_map,
        visible_language_codes
    )

    # Calculate pagination metadata
    has_next = offset + page_size < total
    has_previous = page > 1
    
    # Calculate concepts with all visible languages (only if visible_languages specified)
    concepts_with_all_visible_languages = None
    if visible_language_codes and len(visible_language_codes) > 0:
        concepts_with_all_visible_languages = calculate_concepts_with_all_visible_languages(
            session=session,
            visible_language_codes=visible_language_codes,
            user_id=user_id,
            include_lemmas=include_lemmas,
            include_phrases=include_phrases,
            topic_id_list=topic_id_list,
            include_without_topic=include_without_topic,
            level_list=level_list,
            pos_list=pos_list,
            has_images=has_images,
            is_complete=is_complete,
            search=search
        )

    
    return DictionaryResponse(
        items=paired_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=has_next,
        has_previous=has_previous,
        concepts_with_all_visible_languages=concepts_with_all_visible_languages,
        total_concepts_with_term=total_concepts_with_term
    )
