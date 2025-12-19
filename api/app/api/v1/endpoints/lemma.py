"""
Lemma CRUD endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status, Request, Query
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, and_, or_
from datetime import datetime, timezone
from typing import List, Optional
import logging
import random
from app.core.database import get_session
from app.models.models import Lemma, Concept, Card, User
from app.schemas.lemma import LemmaResponse, UpdateLemmaRequest, NewCardsResponse, ConceptWithLemmas
from app.schemas.concept import (
    CreateConceptRequest,
    CreateConceptResponse,
    ConceptResponse,
    GenerateLemmasForConceptsRequest,
    GenerateLemmasForConceptsResponse
)
from app.utils.text_utils import ensure_capitalized, normalize_lemma_term
from app.services.llm_service import call_gemini_api
from app.services.prompt_service import (
    generate_lemma_system_instruction,
    generate_lemma_user_prompt
)
from app.services.lemma_service import (
    validate_llm_lemma_data,
    create_or_update_lemma_from_llm_data,
    validate_language_codes,
    find_concept_by_term,
)
from app.services.dictionary_service import (
    parse_topic_ids,
    parse_levels,
    parse_part_of_speech,
    build_base_filtered_query,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lemmas", tags=["lemmas"])


@router.get("", response_model=List[LemmaResponse])
async def get_lemmas(
    skip: int = 0,
    limit: int = 100,
    concept_id: Optional[int] = None,
    language_code: Optional[str] = None,
    session: Session = Depends(get_session)
):
    """
    Get lemmas with optional filtering.
    
    Args:
        skip: Number of lemmas to skip
        limit: Maximum number of lemmas to return
        concept_id: Optional filter by concept ID
        language_code: Optional filter by language code
    
    Returns:
        List of lemmas
    """
    query = select(Lemma)
    
    if concept_id is not None:
        query = query.where(Lemma.concept_id == concept_id)
    
    if language_code is not None:
        query = query.where(Lemma.language_code == language_code.lower())
    
    lemmas = session.exec(
        query.offset(skip).limit(limit).order_by(Lemma.created_at.desc())
    ).all()
    
    return [
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
        for lemma in lemmas
    ]


@router.get("/concept/{concept_id}", response_model=List[LemmaResponse])
async def get_lemmas_by_concept_id(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Get all lemmas for a given concept ID.
    
    Args:
        concept_id: The concept ID
    
    Returns:
        List of lemmas associated with the concept
    """
    # Verify that the concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all lemmas for this concept
    lemmas = session.exec(
        select(Lemma).where(Lemma.concept_id == concept_id).order_by(Lemma.created_at.desc())
    ).all()
    
    return [
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
        for lemma in lemmas
    ]


@router.post("/generate")
async def generate_lemmas_for_concept(
    http_request: Request,
    session: Session = Depends(get_session)
):
    """
    Generate lemmas for concepts in multiple languages.
    
    This endpoint can handle two types of requests:
    1. CreateConceptRequest: Finds an existing concept by term and generates lemmas
    2. GenerateLemmasForConceptsRequest: Generates lemmas for specified concept IDs
    
    Args:
        http_request: FastAPI Request object to inspect the body
        session: Database session
    
    Returns:
        CreateConceptResponse or GenerateLemmasForConceptsResponse
    """
    # Parse the request body
    body = await http_request.json()
    
    # Check if this is a GenerateLemmasForConceptsRequest (has concept_ids)
    if 'concept_ids' in body:
        # Handle GenerateLemmasForConceptsRequest
        request = GenerateLemmasForConceptsRequest(**body)
        return await _generate_lemmas_for_concepts_list(request, session)
    
    # Handle CreateConceptRequest (original behavior)
    request = CreateConceptRequest(**body)
    # Validate term is not empty
    term_stripped = request.term.strip()
    if not term_stripped:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term cannot be empty"
        )
    
    # Validate languages
    if not request.languages or len(request.languages) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one language must be specified"
        )
    
    # Validate all language codes exist
    language_codes = [lang.lower() for lang in request.languages]
    validate_language_codes(session, language_codes)
    
    # Find existing concept matching the term
    concept = find_concept_by_term(session, term_stripped, request.user_id)
    
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No concept found with term '{term_stripped}'. Please create the concept first."
        )
    
    logger.info(f"Found concept {concept.id} for term '{term_stripped}' (user_id={concept.user_id}, has_description={concept.description is not None})")
    
    # Use concept's description if available, otherwise use core_meaning_en from request
    description_for_llm = concept.description if concept.description and concept.description.strip() else request.core_meaning_en
    
    # Use concept's part_of_speech if available, otherwise use from request
    part_of_speech_for_llm = concept.part_of_speech if concept.part_of_speech else request.part_of_speech
    
    # Generate system instruction once (reusable for all languages)
    system_instruction = generate_lemma_system_instruction(
        term=term_stripped,
        description=description_for_llm,
        part_of_speech=part_of_speech_for_llm
    )
    
    # Generate lemmas for each language
    created_lemmas = []
    errors = []
    
    for lang_code in language_codes:
        try:
            # Generate user prompt for this language
            user_prompt = generate_lemma_user_prompt(target_language=lang_code)
            
            logger.info(f"Generating lemma for concept {concept.id}, language {lang_code}")
            
            # Call LLM to generate lemma data
            try:
                llm_data, token_usage = call_gemini_api(
                    prompt=user_prompt,
                    system_instruction=system_instruction
                )
                logger.info(f"Generated lemma for {lang_code}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
            except Exception as e:
                logger.error(f"LLM API call failed for language {lang_code}: {str(e)}")
                errors.append(f"Failed to generate lemma for {lang_code}: {str(e)}")
                continue
            
            # Validate LLM output
            try:
                validate_llm_lemma_data(llm_data, lang_code)
            except ValueError as e:
                errors.append(str(e))
                continue
            
            # Create or update lemma
            try:
                lemma = create_or_update_lemma_from_llm_data(
                    session=session,
                    concept_id=concept.id,
                    language_code=lang_code,
                    llm_data=llm_data,
                    replace_existing=True
                )
            except HTTPException:
                # Re-raise HTTP exceptions (like 404, 409)
                raise
            except Exception as e:
                logger.error(f"Failed to save lemma for language {lang_code}: {str(e)}")
                errors.append(f"Failed to save lemma for {lang_code}: {str(e)}")
                continue
            
            # Convert to LemmaResponse
            lemma_response = LemmaResponse(
                id=lemma.id,
                concept_id=lemma.concept_id,
                language_code=lemma.language_code,
                translation=ensure_capitalized(lemma.term) if lemma.term else "",
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
            created_lemmas.append(lemma_response)
            
        except Exception as e:
            logger.error(f"Error generating lemma for language {lang_code}: {str(e)}")
            errors.append(f"Error generating lemma for {lang_code}: {str(e)}")
            continue
    
    # If no lemmas were created, return error
    if not created_lemmas:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate any lemmas. Errors: {'; '.join(errors)}"
        )
    
    concept_response = ConceptResponse.model_validate(concept)
    
    return CreateConceptResponse(
        concept=concept_response,
        lemmas=created_lemmas
    )


async def _generate_lemmas_for_concepts_list(
    request: GenerateLemmasForConceptsRequest,
    session: Session
):
    """
    Internal function to generate lemmas for multiple concepts.
    
    Args:
        request: GenerateLemmasForConceptsRequest with concept_ids and languages
        session: Database session
    
    Returns:
        GenerateLemmasForConceptsResponse with statistics about the generation
    """
    # Validate concept_ids
    if not request.concept_ids or len(request.concept_ids) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one concept ID must be specified"
        )
    
    # Validate languages
    if not request.languages or len(request.languages) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one language must be specified"
        )
    
    # Validate all language codes exist
    language_codes = [lang.lower() for lang in request.languages]
    validate_language_codes(session, language_codes)
    
    # Verify all concepts exist
    concepts = []
    for concept_id in request.concept_ids:
        concept = session.get(Concept, concept_id)
        if not concept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Concept with id {concept_id} not found"
            )
        concepts.append(concept)
    
    # Process each concept
    total_lemmas_created = 0
    total_tokens = 0
    total_cost_usd = 0.0
    errors = []
    
    for concept in concepts:
        try:
            # Get concept data
            term = concept.term
            description = concept.description
            part_of_speech = concept.part_of_speech
            
            if not term or not term.strip():
                errors.append(f"Concept {concept.id} has no term")
                continue
            
            # Generate system instruction once (reusable for all languages)
            system_instruction = generate_lemma_system_instruction(
                term=term.strip(),
                description=description,
                part_of_speech=part_of_speech
            )
            
            # Generate lemmas for each language
            for lang_code in language_codes:
                try:
                    # Check if lemma already exists for this concept and language (case-insensitive)
                    # Query all lemmas for this concept and language to see what we have
                    all_lemmas_for_concept_lang = session.exec(
                        select(Lemma).where(
                            Lemma.concept_id == concept.id,
                            func.lower(Lemma.language_code) == lang_code.lower()
                        )
                    ).all()
                    
                    existing_lemma = all_lemmas_for_concept_lang[0] if all_lemmas_for_concept_lang else None
                    
                    if len(all_lemmas_for_concept_lang) > 1:
                        logger.warning("Found %d lemmas for concept %s, language %s. Using first one.", 
                                     len(all_lemmas_for_concept_lang), concept.id, lang_code)
                    
                    # Check if existing lemma is missing term, ipa, or description
                    needs_generation = False
                    if existing_lemma:
                        # Helper function to check if a field is missing (None, empty, or whitespace only)
                        def is_missing(field_value):
                            return field_value is None or (isinstance(field_value, str) and not field_value.strip())
                        
                        term_missing = is_missing(existing_lemma.term)
                        ipa_missing = is_missing(existing_lemma.ipa)
                        description_missing = is_missing(existing_lemma.description)
                        
                        # Debug logging to see actual values
                        logger.debug("Checking lemma for concept %s, language %s: term=%s, ipa=%s, description=%s", 
                                   concept.id, lang_code, 
                                   repr(existing_lemma.term), repr(existing_lemma.ipa), repr(existing_lemma.description))
                        
                        has_missing_data = term_missing or ipa_missing or description_missing
                        
                        if has_missing_data:
                            needs_generation = True
                            missing_fields = []
                            if term_missing:
                                missing_fields.append("term")
                            if ipa_missing:
                                missing_fields.append("ipa")
                            if description_missing:
                                missing_fields.append("description")
                            logger.info("Lemma exists but is incomplete for concept %s, language %s (found as %s). Missing: %s. Regenerating.", 
                                      concept.id, lang_code, existing_lemma.language_code, ', '.join(missing_fields))
                        else:
                            # Skip if lemma already exists and is complete
                            logger.info("Lemma already exists and is complete for concept %s, language %s (found as %s)", 
                                      concept.id, lang_code, existing_lemma.language_code)
                            continue
                    else:
                        needs_generation = True
                        logger.info("No existing lemma found for concept %s, language %s. Will create new one.", concept.id, lang_code)
                    
                    # Generate user prompt for this language
                    user_prompt = generate_lemma_user_prompt(target_language=lang_code)
                    
                    logger.info(f"Generating lemma for concept {concept.id}, language {lang_code}")
                    
                    # Call LLM to generate lemma data
                    try:
                        llm_data, token_usage = call_gemini_api(
                            prompt=user_prompt,
                            system_instruction=system_instruction
                        )
                        logger.info(f"Generated lemma for concept {concept.id}, {lang_code}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
                        
                        total_tokens += token_usage.get('total_tokens', 0)
                        total_cost_usd += token_usage.get('cost_usd', 0.0)
                    except Exception as e:
                        logger.error(f"LLM API call failed for concept {concept.id}, language {lang_code}: {str(e)}")
                        errors.append(f"Concept {concept.id}, {lang_code}: {str(e)}")
                        continue
                    
                    # Validate LLM output
                    try:
                        validate_llm_lemma_data(llm_data, lang_code)
                    except ValueError as e:
                        errors.append(f"Concept {concept.id}, {lang_code}: {str(e)}")
                        continue
                    
                    # Create or update lemma (will replace existing if needed)
                    try:
                        lemma = create_or_update_lemma_from_llm_data(
                            session=session,
                            concept_id=concept.id,
                            language_code=lang_code,
                            llm_data=llm_data,
                            replace_existing=True
                        )
                    except HTTPException:
                        # Re-raise HTTP exceptions (like 404, 409)
                        raise
                    except Exception as e:
                        logger.error(f"Failed to save lemma for concept {concept.id}, language {lang_code}: {str(e)}")
                        errors.append(f"Concept {concept.id}, {lang_code}: Failed to save lemma: {str(e)}")
                        continue
                    
                    total_lemmas_created += 1
                    logger.info(f"Created/regenerated lemma {lemma.id} for concept {concept.id}, language {lang_code}")
                    
                except Exception as e:
                    logger.error(f"Error generating lemma for concept {concept.id}, language {lang_code}: {str(e)}")
                    errors.append(f"Concept {concept.id}, {lang_code}: {str(e)}")
                    session.rollback()
                    continue
                    
        except Exception as e:
            logger.error(f"Error processing concept {concept.id}: {str(e)}")
            errors.append(f"Concept {concept.id}: {str(e)}")
            continue
    
    logger.info(f"Batch generation completed. Created {total_lemmas_created} lemmas, {len(errors)} errors")
    
    return GenerateLemmasForConceptsResponse(
        concepts_processed=len(concepts),
        lemmas_created=total_lemmas_created,
        errors=errors,
        total_concepts=len(concepts),
        session_cost_usd=total_cost_usd,
        total_tokens=total_tokens
    )


@router.get("/new-cards", response_model=NewCardsResponse)
async def get_new_cards(
    user_id: int,
    language: str,  # Learning language
    native_language: Optional[str] = None,  # Native language (optional, will use user's if not provided)
    max_n: Optional[int] = None,  # Randomly select n concepts to return
    search: Optional[str] = None,  # Optional search query for concept.term and lemma.term
    include_lemmas: bool = Query(True, description="Include lemmas (concept.is_phrase is False)"),
    include_phrases: bool = Query(True, description="Include phrases (concept.is_phrase is True)"),
    topic_ids: Optional[str] = None,  # Comma-separated list of topic IDs to filter by
    include_without_topic: bool = True,  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None,  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None,  # Comma-separated list of part of speech values to filter by
    has_images: Optional[int] = None,  # 1 = include only concepts with images, 0 = include only concepts without images, null = include all
    has_audio: Optional[int] = None,  # 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
    is_complete: Optional[int] = None,  # 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    session: Session = Depends(get_session)
):
    """
    Get concepts that don't have a card for the user in the learning language.
    Filters concepts using the same parameters as the dictionary endpoint.
    Only returns concepts that have lemmas in both native and learning languages.
    Returns concepts with both learning and native language lemmas coupled together.
    
    Args:
        user_id: The user ID (required)
        language: Learning language code (required)
        native_language: Native language code (optional, will use user's native language if not provided)
        max_n: Optional maximum number of concepts to randomly return. If not provided, returns all matching concepts.
        search: Optional search query to filter by concept.term and lemma.term
        include_lemmas: Include lemmas (concept.is_phrase is False)
        include_phrases: Include phrases (concept.is_phrase is True)
        topic_ids: Comma-separated list of topic IDs to filter by
        include_without_topic: Include concepts without a topic (topic_id is null)
        levels: Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
        part_of_speech: Comma-separated list of part of speech values to filter by
        has_images: 1 = include only concepts with images, 0 = include only concepts without images, null = include all
        has_audio: 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
        is_complete: 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    
    Returns:
        NewCardsResponse containing concepts with both native and learning language lemmas that don't have cards for the user
    """
    learning_language_code = language.lower()
    
    # Validate learning language code exists
    validate_language_codes(session, [learning_language_code])
    
    # Get user to retrieve native language if not provided
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Use provided native_language or fall back to user's native language
    native_language_code = (native_language or user.lang_native).lower()
    
    # Validate native language code exists
    validate_language_codes(session, [native_language_code])
    
    # Validate max_n if provided
    if max_n is not None and max_n < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="max_n must be >= 1"
        )
    
    # Count 0: Total concepts visible to user (before any filtering)
    # Count public concepts (user_id IS NULL) OR concepts belonging to this user
    total_concepts_query = select(func.count(Concept.id)).where(
        or_(
            Concept.user_id.is_(None),
            Concept.user_id == user_id
        )
    )
    total_concepts_count = session.exec(total_concepts_query).one()
    
    # Parse filter parameters (same as dictionary endpoint)
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    # Set visible_languages to [native_language, learning_language] for filtering
    visible_language_codes = [native_language_code, learning_language_code]
    
    # Log filter parameters for debugging
    logger.info(
        "get_new_cards: user_id=%s, language=%s, include_lemmas=%s, include_phrases=%s, topic_ids=%s, include_without_topic=%s",
        user_id, learning_language_code, include_lemmas, include_phrases, topic_ids, include_without_topic
    )
    
    # Build base filtered query using dictionary logic
    concept_query = build_base_filtered_query(
        user_id=user_id,
        include_lemmas=include_lemmas,
        include_phrases=include_phrases,
        topic_id_list=topic_id_list,
        include_without_topic=include_without_topic,
        level_list=level_list,
        pos_list=pos_list,
        has_images=has_images,
        has_audio=has_audio,
        is_complete=is_complete,
        visible_language_codes=visible_language_codes,
        search=search
    )
    
    # Execute query to get filtered concepts
    filtered_concepts = session.exec(concept_query).all()
    
    # Deduplicate concepts by ID (in case join created duplicates)
    seen_concept_ids = set()
    unique_concepts = []
    for concept in filtered_concepts:
        if concept.id not in seen_concept_ids:
            seen_concept_ids.add(concept.id)
            unique_concepts.append(concept)
    filtered_concepts = unique_concepts
    
    concept_ids = [c.id for c in filtered_concepts]
    
    # Count 1: Concepts after dictionary filtering
    filtered_concepts_count = len(filtered_concepts)
    logger.info("After dictionary filtering: %s concepts found", filtered_concepts_count)
    
    if not concept_ids:
        return NewCardsResponse(
            concepts=[],
            native_language=user.lang_native,
            total_concepts_count=total_concepts_count,
            filtered_concepts_count=filtered_concepts_count,
            concepts_with_both_languages_count=0,
            concepts_without_cards_count=0
        )
    
    # Get lemmas for these concepts in both native and learning languages
    lemmas_query = (
        select(Lemma)
        .where(
            Lemma.concept_id.in_(concept_ids),  # type: ignore[attr-defined]
            Lemma.language_code.in_([native_language_code, learning_language_code]),
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
    )
    all_lemmas = session.exec(lemmas_query).all()
    
    # Group lemmas by concept_id and language_code
    concept_lemmas_map = {}
    for lemma in all_lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = {}
        concept_lemmas_map[lemma.concept_id][lemma.language_code] = lemma
    
    # Filter to concepts that have lemmas in both languages
    concepts_with_both_languages = []
    for concept in filtered_concepts:
        lemmas = concept_lemmas_map.get(concept.id, {})
        if native_language_code in lemmas and learning_language_code in lemmas:
            concepts_with_both_languages.append(concept)
    
    # Count 2: Concepts with lemmas in both languages
    concepts_with_both_languages_count = len(concepts_with_both_languages)
    logger.info("Concepts with lemmas in both languages: %s", concepts_with_both_languages_count)
    
    if not concepts_with_both_languages:
        return NewCardsResponse(
            concepts=[],
            native_language=user.lang_native,
            total_concepts_count=total_concepts_count,
            filtered_concepts_count=filtered_concepts_count,
            concepts_with_both_languages_count=concepts_with_both_languages_count,
            concepts_without_cards_count=0
        )
    
    # Get learning language lemmas for concepts with both languages
    learning_concept_ids = [c.id for c in concepts_with_both_languages]
    learning_lemmas_query = (
        select(Lemma)
        .outerjoin(
            Card,
            and_(
                Card.lemma_id == Lemma.id,
                Card.user_id == user_id
            )
        )
        .where(
            Lemma.concept_id.in_(learning_concept_ids),  # type: ignore[attr-defined]
            Lemma.language_code == learning_language_code,
            Lemma.term.isnot(None),
            Lemma.term != "",
            Card.id.is_(None)  # type: ignore[attr-defined] # No card exists for this user
        )
    )
    learning_lemmas = session.exec(learning_lemmas_query).all()
    
    # Get unique concept IDs from learning lemmas that don't have cards
    eligible_concept_ids = list({lemma.concept_id for lemma in learning_lemmas})
    
    # Count 3: Concepts without cards for user in learning language
    concepts_without_cards_count = len(eligible_concept_ids)
    logger.info("Concepts without cards for user: %s", concepts_without_cards_count)
    
    # Randomly select n concepts if max_n is provided
    if max_n is not None and len(eligible_concept_ids) > max_n:
        eligible_concept_ids = random.sample(eligible_concept_ids, max_n)
    
    # Filter learning lemmas to only those from selected concepts
    selected_concept_ids = set(eligible_concept_ids)
    learning_lemmas = [lemma for lemma in learning_lemmas if lemma.concept_id in selected_concept_ids]
    
    # Get native language lemmas for the selected concepts
    native_lemmas_query = (
        select(Lemma)
        .where(
            Lemma.concept_id.in_(eligible_concept_ids),  # type: ignore[attr-defined]
            Lemma.language_code == native_language_code,
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
    )
    native_lemmas = session.exec(native_lemmas_query).all()
    
    # Create maps for quick lookup
    native_lemma_map = {lemma.concept_id: lemma for lemma in native_lemmas}
    concept_map = {concept.id: concept for concept in concepts_with_both_languages if concept.id in selected_concept_ids}
    
    # Build response - each item is a concept with both lemmas
    concept_responses = []
    for learning_lemma in learning_lemmas:
        # Create learning language lemma response
        learning_lemma_response = LemmaResponse(
            id=learning_lemma.id,
            concept_id=learning_lemma.concept_id,
            language_code=learning_lemma.language_code,
            translation=ensure_capitalized(learning_lemma.term),
            description=learning_lemma.description,
            ipa=learning_lemma.ipa,
            audio_path=learning_lemma.audio_url,
            gender=learning_lemma.gender,
            article=learning_lemma.article,
            plural_form=learning_lemma.plural_form,
            verb_type=learning_lemma.verb_type,
            auxiliary_verb=learning_lemma.auxiliary_verb,
            formality_register=learning_lemma.formality_register,
            notes=learning_lemma.notes
        )
        
        # Get native language lemma (should always exist since we filtered for both languages)
        native_lemma = native_lemma_map.get(learning_lemma.concept_id)
        native_lemma_response = None
        if native_lemma:
            native_lemma_response = LemmaResponse(
                id=native_lemma.id,
                concept_id=native_lemma.concept_id,
                language_code=native_lemma.language_code,
                translation=ensure_capitalized(native_lemma.term),
                description=native_lemma.description,
                ipa=native_lemma.ipa,
                audio_path=native_lemma.audio_url,
                gender=native_lemma.gender,
                article=native_lemma.article,
                plural_form=native_lemma.plural_form,
                verb_type=native_lemma.verb_type,
                auxiliary_verb=native_lemma.auxiliary_verb,
                formality_register=native_lemma.formality_register,
                notes=native_lemma.notes
            )
        
        # Get concept to retrieve image_url
        concept = concept_map.get(learning_lemma.concept_id)
        image_url = concept.image_url if concept else None
        
        # Create concept with both lemmas
        concept_responses.append(
            ConceptWithLemmas(
                concept_id=learning_lemma.concept_id,
                learning_lemma=learning_lemma_response,
                native_lemma=native_lemma_response,
                image_url=image_url
            )
        )
    
    return NewCardsResponse(
        concepts=concept_responses,
        native_language=user.lang_native,
        total_concepts_count=total_concepts_count,
        filtered_concepts_count=filtered_concepts_count,
        concepts_with_both_languages_count=concepts_with_both_languages_count,
        concepts_without_cards_count=concepts_without_cards_count
    )


@router.get("/{lemma_id}", response_model=LemmaResponse)
async def get_lemma(
    lemma_id: int,
    session: Session = Depends(get_session)
):
    """
    Get a lemma by ID.
    
    Args:
        lemma_id: The lemma ID
    
    Returns:
        The lemma
    """
    lemma = session.get(Lemma, lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lemma not found"
        )
    
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


@router.put("/{lemma_id}", response_model=LemmaResponse)
async def update_lemma(
    lemma_id: int,
    request: UpdateLemmaRequest,
    session: Session = Depends(get_session)
):
    """
    Update a lemma's translation and description.
    
    Args:
        lemma_id: The lemma ID
        request: Update request with fields to update
    
    Returns:
        The updated lemma
    """
    # Get the lemma
    lemma = session.get(Lemma, lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lemma not found"
        )
    
    # Check if translation update would create a duplicate
    if request.translation is not None:
        new_term = normalize_lemma_term(request.translation)
        new_term = ensure_capitalized(new_term)
        
        # Check if another lemma with same concept_id, language_code, and term already exists
        existing_lemma = session.exec(
            select(Lemma).where(
                Lemma.concept_id == lemma.concept_id,
                Lemma.language_code == lemma.language_code,
                Lemma.term == new_term,
                Lemma.id != lemma_id  # Exclude the current lemma
            )
        ).first()
        
        if existing_lemma:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A lemma with the same concept_id, language_code, and term already exists (lemma_id: {existing_lemma.id})"
            )
        
        lemma.term = new_term
        lemma.updated_at = datetime.now(timezone.utc)
    
    if request.description is not None:
        lemma.description = request.description.strip()
        lemma.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(lemma)
        session.commit()
        session.refresh(lemma)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to update lemma: duplicate constraint violation"
        ) from e
    
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


@router.delete("/{lemma_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_lemma(
    lemma_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a lemma and all its associated cards.
    
    Args:
        lemma_id: The lemma ID
    """
    lemma = session.get(Lemma, lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lemma not found"
        )
    
    # Delete all Cards that reference this lemma
    from app.models.models import Card
    cards = session.exec(
        select(Card).where(Card.lemma_id == lemma_id)
    ).all()
    
    for card in cards:
        session.delete(card)
    
    # Delete the lemma
    session.delete(lemma)
    
    session.commit()
    
    return None
