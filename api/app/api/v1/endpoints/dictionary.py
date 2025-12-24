"""
Dictionary endpoints for retrieving paired dictionary items.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends
from sqlmodel import Session, select, func, or_
from app.core.database import get_session
from app.models.models import Concept, Lemma
from app.schemas.concept import DictionaryResponse
from app.schemas.filter import DictionaryFilterRequest
from app.services.dictionary_service import (
    validate_request_parameters,
    apply_sorting,
    build_paired_dictionary_items,
    calculate_concepts_with_all_visible_languages,
)
from app.services.filter_service import (
    build_filtered_query,
    get_visible_language_codes,
)
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dictionary", tags=["dictionary"])


@router.post("", response_model=DictionaryResponse)
async def get_dictionary(
    request: DictionaryFilterRequest,
    session: Session = Depends(get_session)
):
    """
    Get all concepts with lemmas for visible languages, with search and pagination.
    Optimized to do filtering, sorting, and pagination at the database level.
    
    Args:
        request: DictionaryFilterRequest containing filter_config, page, page_size, and sort_by
    """
    # Validate and parse parameters
    validate_request_parameters(request.sort_by, request.page, request.page_size)
    
    # Get visible language codes for later use
    visible_language_codes = get_visible_language_codes(request.filter_config)
    
    # Build filtered query using FilterConfig
    concept_query = build_filtered_query(request.filter_config)

    # Get total count before pagination (for concepts matching search)
    # Count distinct concepts to avoid any potential duplicates
    # At this point, concept_query has all filters applied but no joins yet
    # So we can safely count distinct concept IDs
    concept_subquery = concept_query.subquery()
    total_count_query = select(func.count(func.distinct(concept_subquery.c.id)))
    total = session.exec(total_count_query).one()
    
    # Apply sorting
    concept_query = apply_sorting(concept_query, request.sort_by, visible_language_codes)

    # Apply pagination at database level
    offset = (request.page - 1) * request.page_size
    concept_query = concept_query.offset(offset).limit(request.page_size)
    
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
    has_next = offset + request.page_size < total
    has_previous = request.page > 1
    
    # Calculate concepts with all visible languages (only if visible_languages specified)
    concepts_with_all_visible_languages = None
    if visible_language_codes and len(visible_language_codes) > 0:
        concepts_with_all_visible_languages = calculate_concepts_with_all_visible_languages(
            session=session,
            filter_config=request.filter_config,
            visible_language_codes=visible_language_codes
        )

    
    return DictionaryResponse(
        items=paired_items,
        total=total,
        page=request.page,
        page_size=request.page_size,
        has_next=has_next,
        has_previous=has_previous,
        concepts_with_all_visible_languages=concepts_with_all_visible_languages,
        total_concepts_with_term=total_concepts_with_term
    )
