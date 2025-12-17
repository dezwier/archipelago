"""
Dictionary endpoints for retrieving paired dictionary items.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func, or_
from sqlalchemy.orm import aliased
from typing import Optional, List
from app.core.database import get_session
from app.models.models import Concept, Lemma, CEFRLevel
from app.schemas.lemma import LemmaResponse
from app.schemas.concept import (
    PairedDictionaryItem,
    DictionaryResponse,
)
from app.schemas.utils import normalize_part_of_speech
from app.api.v1.endpoints.utils import ensure_capitalized
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
    include_without_topic: bool = False,  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None,  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None,  # Comma-separated list of part of speech values to filter by
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
    
    # Apply lemmas/phrases filters using is_phrase field
    use_lemmas = include_lemmas
    use_phrases = include_phrases
    
    # If both are False, show nothing (empty result)
    # If both are True, show all (no filter)
    # Otherwise, filter by is_phrase
    if not use_lemmas and not use_phrases:
        # Both filters are False - return empty result
        concept_query = concept_query.where(False)  # This will return no results
    elif use_lemmas and use_phrases:
        # Both filters are True - show all concepts (no is_phrase filter)
        pass
    elif use_lemmas and not use_phrases:
        # Only lemmas - concepts where is_phrase is False
        concept_query = concept_query.where(Concept.is_phrase == False)
    elif not use_lemmas and use_phrases:
        # Only phrases - concepts where is_phrase is True
        concept_query = concept_query.where(Concept.is_phrase == True)
    
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
        
        # Search in concept.term or lemma.term for visible languages
        if visible_language_codes:
            # Subquery to find concept_ids that match search in lemmas for visible languages
            lemma_search_subquery = (
                select(Lemma.concept_id)
                .where(
                    Lemma.language_code.in_(visible_language_codes),
                    func.lower(Lemma.term).like(search_term)
                )
                .distinct()
            )
            
            # Filter concepts where term matches OR has matching lemmas
            concept_query = concept_query.where(
                or_(
                    func.lower(Concept.term).like(search_term),
                    Concept.id.in_(lemma_search_subquery)
                )
            )
        else:
            # Search in concept.term or any lemma.term
            lemma_search_subquery = (
                select(Lemma.concept_id)
                .where(func.lower(Lemma.term).like(search_term))
                .distinct()
            )
            concept_query = concept_query.where(
                or_(
                    func.lower(Concept.term).like(search_term),
                    Concept.id.in_(lemma_search_subquery)
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
        # Sort by concept.created_at descending, or most recent lemma.created_at
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
            concept_query = (
                concept_query
                .outerjoin(lemma_time_subquery, Concept.id == lemma_time_subquery.c.concept_id)
                .order_by(
                    func.coalesce(
                        lemma_time_subquery.c.max_lemma_time,
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
        # Alphabetical sorting - use first visible language lemma term, fallback to concept.term
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
            concept_query = (
                concept_query
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
    paired_items = []
    for concept in concepts:
        lang_lemmas = concept_lemmas_map.get(concept.id, {})
        
        # Build list of lemmas for visible languages only (in order)
        visible_lemmas_list = []
        if visible_language_codes:
            for lang_code in visible_language_codes:
                lemma = lang_lemmas.get(lang_code)
                if lemma and lemma.term and lemma.term.strip():
                    visible_lemmas_list.append(
                        LemmaResponse(
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
                    )
        else:
            for lemma in lang_lemmas.values():
                if lemma.term and lemma.term.strip():
                    visible_lemmas_list.append(
                        LemmaResponse(
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
                    )
        
        source_lemma_response = visible_lemmas_list[0] if len(visible_lemmas_list) > 0 else None
        target_lemma_response = visible_lemmas_list[1] if len(visible_lemmas_list) > 1 else None
        
        # Get topic information safely
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
            except Exception:
                # If topic relationship is not loaded or doesn't exist, topic_name stays None
                pass
        
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
        
        # Apply lemmas/phrases filters (same as main query)
        use_lemmas = include_lemmas
        use_phrases = include_phrases
        
        if not use_lemmas and not use_phrases:
            filtered_concept_query = filtered_concept_query.where(False)
        elif use_lemmas and not use_phrases:
            filtered_concept_query = filtered_concept_query.where(Concept.is_phrase == False)
        elif not use_lemmas and use_phrases:
            filtered_concept_query = filtered_concept_query.where(Concept.is_phrase == True)
        
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
                lemma_search_subquery = (
                    select(Lemma.concept_id)
                    .where(
                        Lemma.language_code.in_(visible_language_codes),
                        func.lower(Lemma.term).like(search_term)
                    )
                    .distinct()
                )
                filtered_concept_query = filtered_concept_query.where(
                    or_(
                        func.lower(Concept.term).like(search_term),
                        Concept.id.in_(lemma_search_subquery)
                    )
                )
            else:
                lemma_search_subquery = (
                    select(Lemma.concept_id)
                    .where(func.lower(Lemma.term).like(search_term))
                    .distinct()
                )
                filtered_concept_query = filtered_concept_query.where(
                    or_(
                        func.lower(Concept.term).like(search_term),
                        Concept.id.in_(lemma_search_subquery)
                    )
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
        
        concepts_with_all_visible_languages = session.exec(
            select(func.count()).select_from(lemma_count_subquery)
        ).one()
    
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

