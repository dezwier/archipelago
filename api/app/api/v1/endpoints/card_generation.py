"""
Card generation endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Concept, Card, Language
from app.schemas.flashcard import (
    GenerateCardsForConceptsRequest,
    GenerateCardsForConceptsResponse,
)
import json
import logging
from datetime import datetime, timezone

from app.api.v1.endpoints.llm_helpers import call_gemini_api
from app.api.v1.endpoints.prompt_helpers import (
    generate_card_translation_system_instruction,
    generate_card_translation_user_prompt,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/cards", tags=["card-generation"])


@router.post("/generate", response_model=GenerateCardsForConceptsResponse)
async def generate_cards_for_concepts(
    request: GenerateCardsForConceptsRequest,
    session: Session = Depends(get_session)
):
    """
    Generate cards for concepts using LLM.
    Retrieves LLM output, validates it, and writes cards directly to the database.
    No preview step - cards are created immediately.
    
    Execution flow:
    1. Validate concept IDs and language codes exist
    2. For each concept, generate prompt and call LLM
    3. Validate LLM output
    4. Create cards in database
    5. Return summary of results
    """
    # Validate all language codes exist
    language_codes = [lang.lower() for lang in request.languages]
    valid_languages = session.exec(
        select(Language).where(Language.code.in_(language_codes))
    ).all()
    
    found_language_codes = {lang.code.lower() for lang in valid_languages}
    missing_languages = set(language_codes) - found_language_codes
    
    if missing_languages:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(sorted(missing_languages))}"
        )
    
    # Validate all concept IDs exist
    concepts = []
    for concept_id in request.concept_ids:
        concept = session.get(Concept, concept_id)
        if not concept:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Concept with id {concept_id} not found"
            )
        concepts.append(concept)
    
    # Log request input
    logger.info(f"=== GENERATE CARDS REQUEST ===")
    logger.info(f"Request JSON Input: concept_ids={request.concept_ids}, languages={request.languages}, user_id={request.user_id}")
    logger.info(f"Concepts to process: {[{'id': c.id, 'term': c.term, 'description': c.description, 'user_id': c.user_id} for c in concepts]}")
    
    # Sort concepts: prioritize user's concepts, then alphabetically by term
    # Sort key: (is_user_concept, term)
    # is_user_concept: 0 for user's concepts (to prioritize them), 1 for others
    def get_concept_sort_key(concept):
        is_user_concept = 0 if (request.user_id is not None and concept.user_id == request.user_id) else 1
        term = (concept.term or "").lower() if concept.term else ""
        return (is_user_concept, term)
    
    concepts.sort(key=get_concept_sort_key, reverse=False)
    
    concepts_processed = 0
    cards_created = 0
    cards_updated = 0
    errors = []
    total_cost_usd = 0.0
    total_tokens = 0
    
    # Process each concept
    for concept in concepts:
        try:
            # Filter: Only process concepts with filled term, description, and part_of_speech
            if not concept.term or not concept.term.strip():
                logger.info(f"Skipping concept {concept.id}: term is missing or empty")
                continue
            
            if not concept.description or not concept.description.strip():
                logger.info(f"Skipping concept {concept.id} ({concept.term}): description is missing or empty")
                continue
            
            if not concept.part_of_speech or not concept.part_of_speech.strip():
                logger.info(f"Skipping concept {concept.id} ({concept.term}): part_of_speech is missing or empty")
                continue
            
            # Get existing cards for this concept
            existing_cards = session.exec(
                select(Card).where(Card.concept_id == concept.id)
            ).all()
            
            # Create a map of existing cards by language code for easy lookup
            existing_cards_by_lang = {card.language_code.lower(): card for card in existing_cards}
            
            # Filter languages that need cards: either missing or incomplete (missing term, description, or ipa)
            languages_to_process = []
            for target_lang in language_codes:
                card = existing_cards_by_lang.get(target_lang.lower())
                
                # Language needs a card if:
                # 1. No card exists, OR
                # 2. Card exists but is missing term, description, or ipa
                if not card:
                    languages_to_process.append(target_lang)
                elif not card.term or not card.term.strip() or \
                     not card.description or not card.description.strip() or \
                     not card.ipa or not card.ipa.strip():
                    languages_to_process.append(target_lang)
            
            # Skip concept if no languages need processing
            if not languages_to_process:
                logger.info(f"Skipping concept {concept.id} ({concept.term}): all requested languages already have complete cards")
                continue
            
            # Process languages that need cards
            created_cards = []
            updated_cards = []
            
            # Generate system instruction once per concept (provides context once)
            system_instruction = generate_card_translation_system_instruction(
                term=concept.term or "",
                description=concept.description,
                part_of_speech=concept.part_of_speech
            )
            
            for target_lang in languages_to_process:
                try:
                    # Generate simple user prompt for this specific language (reuses system instruction)
                    user_prompt = generate_card_translation_user_prompt(target_language=target_lang)
                    
                    logger.info(f"Calling Gemini API for concept {concept.id}: term='{concept.term}', language={target_lang}")
                    
                    # Call Gemini API with system instruction (context provided once, reused for all languages)
                    try:
                        llm_data, token_usage = call_gemini_api(
                            prompt=user_prompt,
                            system_instruction=system_instruction
                        )
                        total_cost_usd += token_usage['cost_usd']
                        total_tokens += token_usage['total_tokens']
                        logger.info(f"Gemini API call completed for concept {concept.id}, language {target_lang}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
                        
                        # Log raw LLM output
                        logger.info(f"=== LLM RAW OUTPUT for concept {concept.id} ({concept.term}), language {target_lang} ===")
                        logger.info(f"LLM Output JSON: {json.dumps(llm_data, indent=2, ensure_ascii=False)}")
                    except Exception as e:
                        logger.error(f"Gemini API call failed for concept {concept.id}, language {target_lang}: {str(e)}")
                        errors.append(f"Concept {concept.id} ({concept.term}), language {target_lang}: Failed to generate card - {str(e)}")
                        continue
                    
                    # Validate LLM output - expect a single card object, not the full LLMResponse format
                    try:
                        # The new prompt returns a single card object, not the full concept+cards structure
                        # Validate required fields
                        if not isinstance(llm_data, dict):
                            raise ValueError("LLM output must be a JSON object")
                        
                        required_fields = ['term', 'description']
                        for field in required_fields:
                            if field not in llm_data or not llm_data[field]:
                                raise ValueError(f"Missing or empty required field: {field}")
                        
                        # Log validated data
                        logger.info(f"=== VALIDATED DATA for concept {concept.id} ({concept.term}), language {target_lang} ===")
                        logger.info(f"Term: '{llm_data.get('term')}', Description: '{llm_data.get('description')}'")
                        
                    except Exception as e:
                        logger.error(f"=== VALIDATION ERROR for concept {concept.id} ({concept.term}), language {target_lang} ===")
                        logger.error(f"LLM Output that failed validation: {json.dumps(llm_data, indent=2, ensure_ascii=False)}")
                        logger.error(f"Validation error: {str(e)}")
                        errors.append(f"Concept {concept.id} ({concept.term}), language {target_lang}: Invalid LLM output format - {str(e)}")
                        continue
                    
                    # Check if card already exists
                    existing_card = existing_cards_by_lang.get(target_lang.lower())
                    is_update = existing_card is not None
                    
                    if existing_card:
                        # Delete existing card to avoid unique constraint issues when term changes
                        session.delete(existing_card)
                        # Flush to ensure deletion is processed before insert
                        session.flush()
                    
                    # Create new card (or recreate if we just deleted one)
                    card = Card(
                        concept_id=concept.id,
                        language_code=target_lang.lower(),
                        term=llm_data.get('term'),
                        ipa=llm_data.get('ipa'),
                        description=llm_data.get('description'),
                        gender=llm_data.get('gender'),
                        article=llm_data.get('article'),
                        plural_form=llm_data.get('plural_form'),
                        verb_type=llm_data.get('verb_type'),
                        auxiliary_verb=llm_data.get('auxiliary_verb'),
                        formality_register=llm_data.get('register'),
                        status="active",
                        source="llm"
                    )
                    session.add(card)
                    if is_update:
                        updated_cards.append(card)
                    else:
                        created_cards.append(card)
                    
                except Exception as e:
                    logger.error(f"Unexpected error processing concept {concept.id}, language {target_lang}: {str(e)}")
                    errors.append(f"Concept {concept.id} ({concept.term}), language {target_lang}: Unexpected error - {str(e)}")
                    continue
            
            # Commit transaction for this concept
            if created_cards or updated_cards:
                try:
                    session.commit()
                    
                    # Refresh cards to get IDs
                    for card in created_cards:
                        session.refresh(card)
                    for card in updated_cards:
                        session.refresh(card)
                    
                    cards_created += len(created_cards)
                    cards_updated += len(updated_cards)
                    concepts_processed += 1
                    
                    logger.info(f"Successfully processed concept {concept.id}: created {len(created_cards)} cards, updated {len(updated_cards)} cards")
                    
                except Exception as e:
                    session.rollback()
                    logger.error(f"Database transaction failed for concept {concept.id}: {str(e)}")
                    errors.append(f"Concept {concept.id} ({concept.term}): Failed to create cards - {str(e)}")
                    continue
                
        except Exception as e:
            logger.error(f"Unexpected error processing concept {concept.id}: {str(e)}")
            errors.append(f"Concept {concept.id} ({concept.term}): Unexpected error - {str(e)}")
            continue
    
    # Log final response
    response = GenerateCardsForConceptsResponse(
        concepts_processed=concepts_processed,
        cards_created=cards_created,
        errors=errors,
        total_concepts=len(concepts),
        session_cost_usd=round(total_cost_usd, 6),
        total_tokens=total_tokens
    )
    
    logger.info(f"=== GENERATE CARDS RESPONSE ===")
    logger.info(f"Response JSON: {json.dumps(response.model_dump(), indent=2, ensure_ascii=False)}")
    logger.info(f"Concepts processed: {concepts_processed}, Cards created: {cards_created}, Cards updated: {cards_updated}, Errors: {len(errors)}")
    if errors:
        logger.error(f"Errors: {errors}")
    
    return response

