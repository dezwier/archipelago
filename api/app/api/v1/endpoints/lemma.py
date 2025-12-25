"""
Lemma CRUD endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func
from datetime import datetime, timezone
from typing import List, Optional
import logging
from app.core.database import get_session
from app.models.models import Lemma, Concept, UserLemma
from app.schemas.lemma import LemmaResponse, LemmaWithUserDataResponse, UpdateLemmaRequest
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


@router.get("/concept/{concept_id}", response_model=List[LemmaWithUserDataResponse])
async def get_lemmas_by_concept_id(
    concept_id: int,
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Get all lemmas for a given concept ID, optionally with user lemma data.
    
    Args:
        concept_id: The concept ID
        user_id: Optional user ID to include user lemma data (leitner_bin, last_review_time, next_review_at)
    
    Returns:
        List of lemmas associated with the concept, with optional user lemma data
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
    
    # If user_id is provided, fetch user lemma data for each lemma
    user_lemma_map = {}
    if user_id is not None:
        lemma_ids = [lemma.id for lemma in lemmas]
        if lemma_ids:
            user_lemmas = session.exec(
                select(UserLemma).where(
                    UserLemma.lemma_id.in_(lemma_ids),  # type: ignore
                    UserLemma.user_id == user_id
                )
            ).all()
            user_lemma_map = {ul.lemma_id: ul for ul in user_lemmas}
    
    # Build response with optional user lemma data
    result = []
    for lemma in lemmas:
        user_lemma = user_lemma_map.get(lemma.id)
        
        lemma_data = {
            'id': lemma.id,
            'concept_id': lemma.concept_id,
            'language_code': lemma.language_code,
            'translation': ensure_capitalized(lemma.term),
            'description': lemma.description,
            'ipa': lemma.ipa,
            'audio_path': lemma.audio_url,
            'gender': lemma.gender,
            'article': lemma.article,
            'plural_form': lemma.plural_form,
            'verb_type': lemma.verb_type,
            'auxiliary_verb': lemma.auxiliary_verb,
            'formality_register': lemma.formality_register,
            'notes': lemma.notes,
        }
        
        # Add user lemma data if available
        if user_lemma:
            lemma_data['user_lemma_id'] = user_lemma.id
            lemma_data['leitner_bin'] = user_lemma.leitner_bin
            lemma_data['last_review_time'] = user_lemma.last_review_time
            lemma_data['next_review_at'] = user_lemma.next_review_at
        
        result.append(LemmaWithUserDataResponse(**lemma_data))
    
    return result


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
    Delete a lemma and all its associated user lemmas.
    
    Args:
        lemma_id: The lemma ID
    """
    lemma = session.get(Lemma, lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lemma not found"
        )
    
    # Delete all UserLemmas that reference this lemma
    from app.models.models import UserLemma
    user_lemmas = session.exec(
        select(UserLemma).where(UserLemma.lemma_id == lemma_id)
    ).all()
    
    for user_lemma in user_lemmas:
        session.delete(user_lemma)
    
    # Delete the lemma
    session.delete(lemma)
    
    session.commit()
    
    return None
