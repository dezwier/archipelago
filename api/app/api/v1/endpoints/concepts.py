"""
Concept CRUD endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, or_
from datetime import datetime, timezone
import logging
from app.core.database import get_session
from app.models.models import Concept, Lemma
from app.schemas.concept import (
    ConceptResponse, ConceptCountResponse, CreateConceptOnlyRequest,
    GetConceptsWithMissingLanguagesRequest, ConceptsWithMissingLanguagesResponse,
    ConceptWithMissingLanguages, UpdateConceptRequest
)
from app.schemas.utils import normalize_part_of_speech
from app.services.dictionary_service import (
    parse_topic_ids,
    parse_levels,
    parse_part_of_speech,
    build_base_filtered_query,
)
from typing import List, Optional

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concepts", tags=["concepts"])


@router.get("", response_model=List[ConceptResponse])
async def get_concepts(
    skip: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session)
):
    """
    Get all concepts with pagination.
    
    Args:
        skip: Number of concepts to skip
        limit: Maximum number of concepts to return
    
    Returns:
        List of concepts
    """
    concepts = session.exec(
        select(Concept).offset(skip).limit(limit).order_by(Concept.created_at.desc())  # type: ignore[attr-defined]
    ).all()
    
    return [ConceptResponse.model_validate(concept) for concept in concepts]


@router.post("/generate-only", response_model=ConceptResponse, status_code=status.HTTP_201_CREATED)
async def create_concept_only(
    request: CreateConceptOnlyRequest,
    session: Session = Depends(get_session)
):
    """
    Create a concept without generating lemmas.
    
    This endpoint creates a concept with just the term, description, topic_id, and user_id.
    No lemmas are generated - this is useful for creating concepts that will have lemmas
    generated later.
    
    Args:
        request: CreateConceptOnlyRequest with term, description, topic_id, and user_id
    
    Returns:
        The created concept
    """
    # Validate term is not empty
    term_stripped = request.term.strip()
    if not term_stripped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term cannot be empty"
        )
    
    # Create the concept
    # Require user_id for concepts created from the app (create page)
    # If coming from the app (user_id is present), is_phrase is always True
    if request.user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User must be logged in to create concepts"
        )
    
    is_phrase = True  # Always True when created from app (user_id is required)
    concept = Concept(
        term=term_stripped,
        description=request.description.strip() if request.description else None,
        topic_id=request.topic_id,
        user_id=request.user_id,
        is_phrase=is_phrase,
        created_at=datetime.now(timezone.utc)
    )
    
    try:
        session.add(concept)
        session.commit()
        session.refresh(concept)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to create concept: constraint violation"
        ) from e
    
    return ConceptResponse.model_validate(concept)


@router.get("/by-term", response_model=List[ConceptResponse])
async def get_concepts_by_term(
    term: str,
    session: Session = Depends(get_session)
):
    """
    Get all concepts that match the given term.
    
    Searches for concepts where the term field matches (case-insensitive).
    Uses partial matching - will find concepts where the term contains the search term.
    
    Args:
        term: The term to search for
    
    Returns:
        List of concepts matching the term
    """
    if not term or not term.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term parameter cannot be empty"
        )
    
    # Use case-insensitive partial matching
    # Filter out concepts where term is None and use case-insensitive matching
    search_term = term.strip()
    # Use ilike for PostgreSQL case-insensitive pattern matching with wildcards
    concepts = session.exec(
        select(Concept).where(
            Concept.term.isnot(None),  # type: ignore[attr-defined]
            Concept.term.ilike(f"%{search_term}%")  # type: ignore[attr-defined]
        ).order_by(Concept.created_at.desc())  # type: ignore[attr-defined]
    ).all()
    
    return [ConceptResponse.model_validate(concept) for concept in concepts]

@router.get("/{concept_id}", response_model=ConceptResponse)
async def get_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Get a concept by ID.
    
    Args:
        concept_id: The concept ID
    
    Returns:
        The concept
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    return ConceptResponse.model_validate(concept)


@router.put("/{concept_id}", response_model=ConceptResponse)
async def update_concept(
    concept_id: int,
    request: UpdateConceptRequest,
    session: Session = Depends(get_session)
):
    """
    Update a concept.
    
    Args:
        concept_id: The concept ID
        request: Update request with fields to update
    
    Returns:
        The updated concept
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Update fields if provided
    if request.term is not None:
        term_stripped = request.term.strip()
        if not term_stripped:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Term cannot be empty"
            )
        concept.term = term_stripped
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.description is not None:
        concept.description = request.description.strip() if request.description else None
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.part_of_speech is not None:
        # Normalize part_of_speech (converts deprecated 'Saying'/'Sentence' to None)
        concept.part_of_speech = normalize_part_of_speech(request.part_of_speech)
        concept.updated_at = datetime.now(timezone.utc)
    
    if request.topic_id is not None:
        concept.topic_id = request.topic_id
        concept.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(concept)
        session.commit()
        session.refresh(concept)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to update concept: constraint violation"
        ) from e
    
    return ConceptResponse.model_validate(concept)


@router.delete("/{concept_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a concept and all its associated lemmas, user_cards, images, and image files.
    This will delete:
    - All UserCards that reference lemmas for this concept
    - All Lemmas for this concept
    - All Images for this concept (database records and files)
    - The Concept itself
    """
    try:
        delete_concept_and_associated_resources(session, concept_id)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        )
    
    return None


@router.get("/count/total", response_model=ConceptCountResponse)
async def get_total_concept_count(
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Get the total count of concepts visible to the user.
    - If user_id is provided: counts public concepts (user_id IS NULL) AND user's concepts
    - If user_id is None (logged out): counts only public concepts (user_id IS NULL)
    
    Args:
        user_id: Optional user ID to filter concepts
    
    Returns:
        Total count of concepts visible to the user
    """
    query = select(func.count(Concept.id))
    
    # Filter by user_id: if provided, show public concepts (user_id IS NULL) AND that user's concepts; if None, show only public concepts
    if user_id is not None:
        # Count public concepts (user_id IS NULL) OR concepts belonging to this user
        query = query.where(
            or_(
                Concept.user_id.is_(None),
                Concept.user_id == user_id
            )
        )
    else:
        # When logged out, count only public concepts (user_id IS NULL)
        query = query.where(Concept.user_id.is_(None))
    
    count = session.exec(query).one()
    return ConceptCountResponse(count=count)


@router.get("/count/with-lemmas-for-languages", response_model=ConceptCountResponse)
async def get_concept_count_with_lemmas_for_languages(
    languages: str,
    session: Session = Depends(get_session)
):
    """
    Get the count of concepts that have lemmas with terms for all of the given languages.
    
    Args:
        languages: Comma-separated list of language codes (e.g., "en,fr,es")
    
    Returns:
        Count of concepts that have lemmas with terms for all specified languages
    """
    if not languages or not languages.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="languages parameter is required and cannot be empty"
        )
    
    # Parse language codes
    language_codes = [lang.strip().lower() for lang in languages.split(',') if lang.strip()]
    
    if not language_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one valid language code must be provided"
        )
    
    # Get all lemmas with terms, filtered by the specified languages
    all_lemmas = session.exec(
        select(Lemma).where(
            Lemma.language_code.in_(language_codes),
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
    ).all()
    
    # Group lemmas by concept_id and language_code
    concept_lemmas_map = {}
    for lemma in all_lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = {}
        concept_lemmas_map[lemma.concept_id][lemma.language_code] = lemma
    
    # Count concepts that have lemmas for all specified languages
    count = 0
    for concept_id, lang_lemmas in concept_lemmas_map.items():
        # Check if this concept has lemmas for all specified languages
        has_all_lemmas = True
        for lang_code in language_codes:
            if lang_code not in lang_lemmas:
                has_all_lemmas = False
                break
            lemma = lang_lemmas[lang_code]
            if not lemma.term or not lemma.term.strip():
                has_all_lemmas = False
                break
        if has_all_lemmas:
            count += 1
    
    return ConceptCountResponse(count=count)


@router.post("/missing-languages", response_model=ConceptsWithMissingLanguagesResponse)
async def get_concepts_with_missing_languages(
    request: GetConceptsWithMissingLanguagesRequest,
    session: Session = Depends(get_session)
):
    """
    Get concepts that are missing lemmas or have incomplete lemmas (missing term/ipa/description) 
    for the specified languages.
    
    This endpoint returns concepts that don't have complete lemmas for one or more of the
    specified languages. It uses the exact same filters as the dictionary endpoint.
    It's useful for identifying concepts that need lemma generation for specific languages.
    
    Args:
        request: GetConceptsWithMissingLanguagesRequest with languages and filters
    
    Returns:
        ConceptsWithMissingLanguagesResponse with list of concepts and their missing languages
    """
    # Validate languages
    if not request.languages or len(request.languages) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one language must be specified"
        )
    
    # Validate all language codes exist
    from app.services.lemma_service import validate_language_codes
    language_codes = [lang.lower() for lang in request.languages]
    validate_language_codes(session, language_codes)
    
    # Parse filters using the same helper functions as dictionary endpoint
    topic_id_list = parse_topic_ids(','.join(map(str, request.topic_ids)) if request.topic_ids else None)
    level_list = parse_levels(','.join(request.levels) if request.levels else None)
    pos_list = parse_part_of_speech(','.join(request.part_of_speech) if request.part_of_speech else None)
    
    # Build base filtered query using the exact same function as dictionary endpoint
    concept_query = build_base_filtered_query(
        user_id=request.user_id,
        include_lemmas=request.include_lemmas,
        include_phrases=request.include_phrases,
        topic_id_list=topic_id_list,
        include_without_topic=request.include_without_topic,
        level_list=level_list,
        pos_list=pos_list,
        has_images=request.has_images,
        is_complete=request.is_complete,
        visible_language_codes=language_codes,
        search=request.search
    )
    
    # Get all concepts with filters applied (no pagination)
    all_concepts = session.exec(
        concept_query.order_by(func.lower(Concept.term).asc())
    ).all()
    
    # Get all lemmas for the specified languages
    lemmas = session.exec(
        select(Lemma).where(Lemma.language_code.in_(language_codes))
    ).all()
    
    # Group lemmas by concept_id and language_code, storing the full lemma object
    concept_lemmas_map = {}
    for lemma in lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = {}
        concept_lemmas_map[lemma.concept_id][lemma.language_code.lower()] = lemma
    
    # Find concepts with missing or incomplete lemmas
    result_concepts = []
    for concept in all_concepts:
        # Get lemmas for this concept (if any)
        concept_lemmas = concept_lemmas_map.get(concept.id, {})
        
        # Find which languages are missing or have incomplete data
        missing_languages = []
        for lang_code in language_codes:
            lemma = concept_lemmas.get(lang_code)
            
            if lemma is None:
                # Lemma doesn't exist at all
                missing_languages.append(lang_code)
            else:
                # Helper function to check if a field is missing (None, empty, or whitespace only)
                def is_missing(field_value):
                    return field_value is None or (isinstance(field_value, str) and not field_value.strip())
                
                # Check if lemma is missing term, ipa, or description
                has_missing_data = (
                    is_missing(lemma.term) or
                    is_missing(lemma.ipa) or
                    is_missing(lemma.description)
                )
                if has_missing_data:
                    missing_languages.append(lang_code)
        
        # Only include concepts that are missing at least one language or have incomplete lemmas
        if missing_languages:
            # Convert concept to dict and ensure level is serialized as string
            concept_dict = ConceptResponse.model_validate(concept).model_dump()
            # Ensure level is a string value (CEFRLevel enum value)
            if concept.level is not None:
                concept_dict['level'] = concept.level.value
            concept_response = ConceptResponse(**concept_dict)
            
            result_concepts.append(ConceptWithMissingLanguages(
                concept=concept_response,
                missing_languages=missing_languages
            ))
    
    return ConceptsWithMissingLanguagesResponse(concepts=result_concepts)
