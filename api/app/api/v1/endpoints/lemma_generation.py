"""
Lemma generation endpoint - unified endpoint for generating translations.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.database import get_session
from app.models.models import Concept
from app.schemas.lemma import (
    GenerateLemmaRequest,
    GenerateLemmaResponse,
    GenerateLemmasBatchRequest,
    GenerateLemmasBatchResponse
)
import json
import logging

from app.services.llm_service import call_gemini_api
from app.services.prompt_service import (
    generate_lemma_system_instruction,
    generate_lemma_user_prompt
)
from app.services.lemma_service import (
    validate_llm_lemma_data,
    create_or_update_lemma_from_llm_data,
    validate_language_codes,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lemma", tags=["lemma-generation"])


@router.post("/generate", response_model=GenerateLemmaResponse)
async def generate_lemma(
    request: GenerateLemmaRequest,
    session: Session = Depends(get_session)
):
    """
    Generate a lemma (translation) for a term in a target language.
    
    This is a unified endpoint that merges functionality from concept generation
    and lemma translation endpoints. It generates a single lemma/translation for
    a given term, handling both single words and phrases.
    
    Args:
        request: Request containing term, target_language, optional description, and optional part_of_speech
    
    Returns:
        Generated lemma with translation, description, IPA, and language-specific fields
    """
    # Validate target language exists
    target_language_code = request.target_language.lower()
    validate_language_codes(session, [target_language_code])
    
    # Generate system instruction and user prompt separately
    system_instruction = generate_lemma_system_instruction(
        term=request.term,
        description=request.description,
        part_of_speech=request.part_of_speech
    )
    
    user_prompt = generate_lemma_user_prompt(target_language=target_language_code)
    
    logger.info(f"Calling Gemini API for lemma generation: term='{request.term}', target_language={target_language_code}, has_description={request.description is not None}, has_pos={request.part_of_speech is not None}")
    
    # Call Gemini API with system instruction and user prompt
    try:
        llm_data, token_usage = call_gemini_api(
            prompt=user_prompt,
            system_instruction=system_instruction
        )
        logger.info(f"Gemini API call completed. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
    except Exception as e:
        logger.error(f"Gemini API call failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate lemma: {str(e)}"
        )
    
    # Validate LLM output
    try:
        validate_llm_lemma_data(llm_data, target_language_code)
        logger.info(f"=== VALIDATED LEMMA DATA ===")
        logger.info(f"Term: '{llm_data.get('term')}', Description: '{llm_data.get('description')}'")
        logger.info(f"LLM Output JSON: {json.dumps(llm_data, indent=2, ensure_ascii=False)}")
    except ValueError as e:
        logger.error(f"=== VALIDATION ERROR ===")
        logger.error(f"LLM Output that failed validation: {json.dumps(llm_data, indent=2, ensure_ascii=False)}")
        logger.error(f"Validation error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Invalid LLM output format: {str(e)}"
        )
    
    # If concept_id is provided, create/update the lemma in the database
    if request.concept_id is not None:
        create_or_update_lemma_from_llm_data(
            session=session,
            concept_id=request.concept_id,
            language_code=target_language_code,
            llm_data=llm_data,
            replace_existing=True
        )
    
    # Build response
    return GenerateLemmaResponse(
        term=llm_data.get('term'),
        ipa=llm_data.get('ipa'),
        description=llm_data.get('description'),
        gender=llm_data.get('gender'),
        article=llm_data.get('article'),
        plural_form=llm_data.get('plural_form'),
        verb_type=llm_data.get('verb_type'),
        auxiliary_verb=llm_data.get('auxiliary_verb'),
        register=llm_data.get('register'),
        token_usage={
            'prompt_tokens': token_usage.get('prompt_tokens', 0),
            'output_tokens': token_usage.get('output_tokens', 0),
            'total_tokens': token_usage.get('total_tokens', 0),
            'cost_usd': token_usage.get('cost_usd', 0.0),
            'model_name': token_usage.get('model_name', 'unknown')
        }
    )


@router.post("/generate-batch", response_model=GenerateLemmasBatchResponse)
async def generate_lemmas_batch(
    request: GenerateLemmasBatchRequest,
    session: Session = Depends(get_session)
):
    """
    Generate lemmas for a term in multiple languages.
    This endpoint optimizes for batch generation by:
    1. Generating the system instruction once (with term, description, part_of_speech)
    2. Looping through languages with just the language-specific user prompt
    
    This is more efficient than calling /generate multiple times because the system
    instruction (which contains the term context) is only sent once.
    
    Args:
        request: Request containing term, target_languages list, optional description, optional part_of_speech, and optional concept_id
    
    Returns:
        List of generated lemmas, one per target language
    """
    # Validate all target languages exist
    target_language_codes = [lang.lower() for lang in request.target_languages]
    validate_language_codes(session, target_language_codes)
    
    # Generate system instruction once (reusable for all languages)
    system_instruction = generate_lemma_system_instruction(
        term=request.term,
        description=request.description,
        part_of_speech=request.part_of_speech
    )
    
    logger.info(f"Calling Gemini API for batch lemma generation: term='{request.term}', languages={target_language_codes}, has_description={request.description is not None}, has_pos={request.part_of_speech is not None}")
    
    # Verify concept exists if concept_id is provided
    concept = None
    if request.concept_id is not None:
        concept = session.get(Concept, request.concept_id)
        if not concept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Concept with id {request.concept_id} not found"
            )
    
    # Generate lemma for each language
    generated_lemmas = []
    total_prompt_tokens = 0
    total_output_tokens = 0
    total_cost_usd = 0.0
    model_name = None  # Will be set from first successful API call
    
    for target_language_code in target_language_codes:
        try:
            # Generate user prompt for this specific language
            user_prompt = generate_lemma_user_prompt(target_language=target_language_code)
            
            # Call Gemini API with system instruction (reused) and language-specific user prompt
            llm_data, token_usage = call_gemini_api(
                prompt=user_prompt,
                system_instruction=system_instruction
            )
            
            # Accumulate token usage
            total_prompt_tokens += token_usage.get('prompt_tokens', 0)
            total_output_tokens += token_usage.get('output_tokens', 0)
            total_cost_usd += token_usage.get('cost_usd', 0.0)
            
            # Set model_name from first successful call
            if model_name is None:
                model_name = token_usage.get('model_name', 'gemini-2.5-pro')
            
            # Validate LLM output
            try:
                validate_llm_lemma_data(llm_data, target_language_code)
            except ValueError as e:
                logger.error(f"Validation error for {target_language_code}: {str(e)}")
                # Continue with other languages even if one fails
                continue
            
            # If concept_id is provided, create/update the lemma in the database
            if request.concept_id is not None:
                try:
                    create_or_update_lemma_from_llm_data(
                        session=session,
                        concept_id=request.concept_id,
                        language_code=target_language_code,
                        llm_data=llm_data,
                        replace_existing=True
                    )
                except HTTPException:
                    # Re-raise HTTP exceptions (like 404, 409)
                    raise
                except Exception as e:
                    logger.error(f"Failed to save lemma for language {target_language_code}: {str(e)}")
                    # Continue with other languages even if one fails
            
            # Build lemma response
            generated_lemmas.append(GenerateLemmaResponse(
                term=llm_data.get('term'),
                ipa=llm_data.get('ipa'),
                description=llm_data.get('description'),
                gender=llm_data.get('gender'),
                article=llm_data.get('article'),
                plural_form=llm_data.get('plural_form'),
                verb_type=llm_data.get('verb_type'),
                auxiliary_verb=llm_data.get('auxiliary_verb'),
                register=llm_data.get('register'),
                token_usage=token_usage
            ))
            
        except Exception as e:
            logger.error(f"Failed to generate lemma for language {target_language_code}: {str(e)}")
            # Continue with other languages even if one fails
            # Could optionally include error info in response
    
    logger.info(f"Batch lemma generation completed. Generated {len(generated_lemmas)}/{len(target_language_codes)} lemmas. Total tokens: {total_prompt_tokens + total_output_tokens}, Cost: ${total_cost_usd:.6f}")
    
    return GenerateLemmasBatchResponse(
        lemmas=generated_lemmas,
        total_token_usage={
            'prompt_tokens': total_prompt_tokens,
            'output_tokens': total_output_tokens,
            'total_tokens': total_prompt_tokens + total_output_tokens,
            'cost_usd': total_cost_usd,
            'model_name': model_name or 'gemini-2.5-pro'
        }
    )

