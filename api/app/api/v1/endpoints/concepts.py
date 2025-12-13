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
from pathlib import Path
import logging
from app.core.database import get_session
from app.core.config import settings
from app.models.models import Concept, Image, Lemma, Language, CEFRLevel
from app.schemas.concept import (
    ConceptResponse, ImageResponse, ConceptCountResponse, CreateConceptOnlyRequest,
    GetConceptsWithMissingLanguagesRequest, ConceptsWithMissingLanguagesResponse,
    ConceptWithMissingLanguages
)
from app.schemas.utils import normalize_part_of_speech
from typing import List, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concepts", tags=["concepts"])


class UpdateConceptRequest(BaseModel):
    """Request schema for updating a concept."""
    term: Optional[str] = Field(None, min_length=1, description="The term (cannot be empty if provided)")
    description: Optional[str] = None
    part_of_speech: Optional[str] = None
    topic_id: Optional[int] = None


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
    
    # Load images for each concept
    concept_ids = [c.id for c in concepts]
    images = session.exec(
        select(Image).where(Image.concept_id.in_(concept_ids))
    ).all()
    
    image_map = {}
    for img in images:
        if img.concept_id not in image_map:
            image_map[img.concept_id] = []
        image_map[img.concept_id].append(img)
    
    result = []
    for concept in concepts:
        concept_dict = ConceptResponse.model_validate(concept).model_dump()
        concept_dict['images'] = [ImageResponse.model_validate(img) for img in image_map.get(concept.id, [])]
        result.append(ConceptResponse(**concept_dict))
    
    return result


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
    concept = Concept(
        term=term_stripped,
        description=request.description.strip() if request.description else None,
        topic_id=request.topic_id,
        user_id=request.user_id,
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
    
    # Load images for the concept (will be empty for new concept)
    images = session.exec(
        select(Image).where(Image.concept_id == concept.id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    return ConceptResponse(**concept_dict)


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
    
    # Load images for each concept
    concept_ids = [c.id for c in concepts]
    images = session.exec(
        select(Image).where(Image.concept_id.in_(concept_ids))
    ).all()
    
    image_map = {}
    for img in images:
        if img.concept_id not in image_map:
            image_map[img.concept_id] = []
        image_map[img.concept_id].append(img)
    
    result = []
    for concept in concepts:
        concept_dict = ConceptResponse.model_validate(concept).model_dump()
        concept_dict['images'] = [ImageResponse.model_validate(img) for img in image_map.get(concept.id, [])]
        result.append(ConceptResponse(**concept_dict))
    
    return result

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
    
    # Load images for the concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    return ConceptResponse(**concept_dict)


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
        concept.part_of_speech = request.part_of_speech.strip() if request.part_of_speech else None
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
    
    # Load images for the concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    return ConceptResponse(**concept_dict)


def _get_assets_directory() -> Path:
    """
    Get the assets directory path.
    
    Uses ASSETS_PATH environment variable if set (for Railway volumes),
    otherwise falls back to api/assets directory.
    
    Returns:
        Path to the assets directory
    """
    # Check if ASSETS_PATH is configured (for Railway volumes)
    if settings.assets_path:
        assets_dir = Path(settings.assets_path)
    else:
        # Fallback to API root/assets for local development
        api_root = Path(__file__).parent.parent.parent.parent.parent
        assets_dir = api_root / "assets"
    
    return assets_dir


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
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all images for this concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    # Delete image files from assets directory
    if images:
        assets_dir = _get_assets_directory()
        for image in images:
            # Extract filename from URL (e.g., "/assets/47099.jpg" -> "47099.jpg")
            if image.url and image.url.startswith("/assets/"):
                image_filename = image.url.replace("/assets/", "")
                image_path = assets_dir / image_filename
                
                # Delete the image file if it exists
                if image_path.exists():
                    try:
                        image_path.unlink()
                        logger.info(f"Deleted image file: {image_path}")
                    except Exception as e:
                        logger.warning(f"Failed to delete image file {image_path}: {str(e)}")
                else:
                    logger.warning(f"Image file not found: {image_path}")
    
    # Delete all image records
    for image in images:
        session.delete(image)
    
    # Get all lemmas for this concept
    from app.models.models import Lemma, UserCard
    lemmas = session.exec(
        select(Lemma).where(Lemma.concept_id == concept_id)
    ).all()
    
    # Delete all UserCards that reference these lemmas
    lemma_ids = [lemma.id for lemma in lemmas]
    if lemma_ids:
        user_cards = session.exec(
            select(UserCard).where(UserCard.lemma_id.in_(lemma_ids))
        ).all()
        for user_card in user_cards:
            session.delete(user_card)
    
    # Delete all lemmas
    for lemma in lemmas:
        session.delete(lemma)
    
    # Delete the concept
    session.delete(concept)
    
    session.commit()
    
    return None


@router.get("/count/total", response_model=ConceptCountResponse)
async def get_total_concept_count(
    session: Session = Depends(get_session)
):
    """
    Get the total count of all concepts.
    
    Returns:
        Total count of concepts
    """
    count = session.exec(select(func.count(Concept.id))).one()
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
    Get concepts that are missing lemmas for the specified languages.
    
    This endpoint returns concepts that don't have lemmas for one or more of the
    specified languages. It's useful for identifying concepts that need lemma
    generation for specific languages.
    
    Args:
        request: GetConceptsWithMissingLanguagesRequest with languages and optional user_id
    
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
    language_codes = [lang.lower() for lang in request.languages]
    languages = session.exec(
        select(Language).where(Language.code.in_(language_codes))
    ).all()
    
    found_codes = {lang.code.lower() for lang in languages}
    missing_codes = set(language_codes) - found_codes
    if missing_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(sorted(missing_codes))}"
        )
    
    # Parse and validate levels filter if provided
    level_list = None
    if request.levels is not None and len(request.levels) > 0:
        level_strs = [level.strip().upper() for level in request.levels if level.strip()]
        level_list = []
        for level_str in level_strs:
            try:
                level_list.append(CEFRLevel(level_str))
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid CEFR level: {level_str}. Must be one of: A1, A2, B1, B2, C1, C2"
                )
    
    # Parse and validate part of speech filter if provided
    pos_list = None
    if request.part_of_speech is not None and len(request.part_of_speech) > 0:
        pos_list = []
        for pos in request.part_of_speech:
            pos_stripped = pos.strip()
            if pos_stripped:
                # Normalize POS value to proper case for comparison
                try:
                    normalized_pos = normalize_part_of_speech(pos_stripped)
                    pos_list.append(normalized_pos)
                except ValueError:
                    # If normalization fails, try lowercase comparison as fallback
                    pos_list.append(pos_stripped)
    
    # Build base query for concepts with filters
    # Start with all concepts
    base_query_with_user_id = select(Concept).where(Concept.user_id.isnot(None))
    base_query_without_user_id = select(Concept).where(Concept.user_id.is_(None))
    
    # Apply public/private filters (same logic as vocabulary endpoint)
    if not request.include_public and not request.include_private:
        # Both filters are False - return empty result
        base_query_with_user_id = base_query_with_user_id.where(False)
        base_query_without_user_id = base_query_without_user_id.where(False)
    elif request.include_public and not request.include_private:
        # Only public - concepts where user_id is null
        base_query_with_user_id = base_query_with_user_id.where(False)  # No concepts with user_id
        # base_query_without_user_id already filters for user_id is None
    elif not request.include_public and request.include_private:
        # Only private - concepts where user_id matches logged in user
        if request.own_user_id is not None:
            base_query_with_user_id = base_query_with_user_id.where(Concept.user_id == request.own_user_id)
        else:
            base_query_with_user_id = base_query_with_user_id.where(False)
        base_query_without_user_id = base_query_without_user_id.where(False)  # No concepts without user_id
    
    # Apply topic_ids filter if provided (same logic as vocabulary endpoint)
    if request.topic_ids is not None and len(request.topic_ids) > 0:
        if request.include_without_topic:
            # Include concepts with these topic IDs OR concepts without a topic
            base_query_with_user_id = base_query_with_user_id.where(
                or_(
                    Concept.topic_id.in_(request.topic_ids),
                    Concept.topic_id.is_(None)
                )
            )
            base_query_without_user_id = base_query_without_user_id.where(
                or_(
                    Concept.topic_id.in_(request.topic_ids),
                    Concept.topic_id.is_(None)
                )
            )
        else:
            # Only include concepts with these topic IDs
            base_query_with_user_id = base_query_with_user_id.where(Concept.topic_id.in_(request.topic_ids))
            base_query_without_user_id = base_query_without_user_id.where(Concept.topic_id.in_(request.topic_ids))
    else:
        # topic_ids is None/empty (all topics selected in frontend)
        if not request.include_without_topic:
            # Exclude concepts without a topic (only show concepts with a topic)
            base_query_with_user_id = base_query_with_user_id.where(Concept.topic_id.isnot(None))
            base_query_without_user_id = base_query_without_user_id.where(Concept.topic_id.isnot(None))
        # If include_without_topic is True, show ALL concepts (no topic filter)
    
    # Apply levels filter if provided
    if level_list is not None and len(level_list) > 0:
        base_query_with_user_id = base_query_with_user_id.where(Concept.level.in_(level_list))
        base_query_without_user_id = base_query_without_user_id.where(Concept.level.in_(level_list))
    
    # Apply part_of_speech filter if provided
    if pos_list is not None and len(pos_list) > 0:
        # Convert all POS values to lowercase for case-insensitive comparison
        pos_list_lower = [pos.lower() for pos in pos_list]
        base_query_with_user_id = base_query_with_user_id.where(
            func.lower(Concept.part_of_speech).in_(pos_list_lower)
        )
        base_query_without_user_id = base_query_without_user_id.where(
            func.lower(Concept.part_of_speech).in_(pos_list_lower)
        )
    
    # Apply search filter if provided (same logic as vocabulary endpoint)
    if request.search and request.search.strip():
        search_term = f"%{request.search.strip().lower()}%"
        
        # Search in concept.term or lemma.term for visible languages
        lemma_search_subquery = (
            select(Lemma.concept_id)
            .where(
                Lemma.language_code.in_(language_codes),
                func.lower(Lemma.term).like(search_term)
            )
            .distinct()
        )
        
        # Filter concepts where term matches OR has matching lemmas
        base_query_with_user_id = base_query_with_user_id.where(
            or_(
                func.lower(Concept.term).like(search_term),
                Concept.id.in_(lemma_search_subquery)
            )
        )
        base_query_without_user_id = base_query_without_user_id.where(
            or_(
                func.lower(Concept.term).like(search_term),
                Concept.id.in_(lemma_search_subquery)
            )
        )
    
    # Get all concepts with filters applied
    # Prioritize concepts with filled user_id, then sort alphabetically (case-insensitive)
    concepts_with_user_id = session.exec(
        base_query_with_user_id.order_by(func.lower(Concept.term).asc())
    ).all()
    
    concepts_without_user_id = session.exec(
        base_query_without_user_id.order_by(func.lower(Concept.term).asc())
    ).all()
    
    # Combine: concepts with user_id first, then those without, both alphabetically sorted
    all_concepts = list(concepts_with_user_id) + list(concepts_without_user_id)
    
    # Get all lemmas for the specified languages
    lemmas = session.exec(
        select(Lemma).where(Lemma.language_code.in_(language_codes))
    ).all()
    
    # Group lemmas by concept_id and language_code
    concept_lemmas_map = {}
    for lemma in lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = set()
        concept_lemmas_map[lemma.concept_id].add(lemma.language_code.lower())
    
    # Find concepts with missing languages
    result_concepts = []
    for concept in all_concepts:
        # Get lemmas for this concept (if any)
        concept_lemma_languages = concept_lemmas_map.get(concept.id, set())
        
        # Find which languages are missing
        missing_languages = []
        for lang_code in language_codes:
            if lang_code not in concept_lemma_languages:
                missing_languages.append(lang_code)
        
        # Only include concepts that are missing at least one language
        if missing_languages:
            # Load images for the concept
            images = session.exec(
                select(Image).where(Image.concept_id == concept.id)
            ).all()
            
            # Convert concept to dict and ensure level is serialized as string
            concept_dict = ConceptResponse.model_validate(concept).model_dump()
            # Ensure level is a string value (CEFRLevel enum value)
            if concept.level is not None:
                concept_dict['level'] = concept.level.value
            concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
            concept_response = ConceptResponse(**concept_dict)
            
            result_concepts.append(ConceptWithMissingLanguages(
                concept=concept_response,
                missing_languages=missing_languages
            ))
    
    return ConceptsWithMissingLanguagesResponse(concepts=result_concepts)
