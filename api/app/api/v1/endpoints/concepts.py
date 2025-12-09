"""
Concept generation endpoint.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Concept, Card, Language, Topic
from app.schemas.flashcard import (
    CreateConceptRequest,
    CreateConceptResponse,
    ConceptResponse,
    CardResponse,
    LLMResponse,
    CreateConceptOnlyRequest,
    ConceptWithMissingLanguages,
    ConceptsWithMissingLanguagesResponse,
    GetConceptsWithMissingLanguagesRequest,
    GenerateCardsForConceptsRequest,
    GenerateCardsForConceptsResponse,
)
import json
import logging
from typing import List
from datetime import datetime, timezone

from app.api.v1.endpoints.llm_helpers import call_gemini_api
from app.api.v1.endpoints.prompt_helpers import (
    generate_concept_prompt,
    generate_card_translation_system_instruction,
    generate_card_translation_user_prompt,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concepts", tags=["concepts"])


@router.post("/create", response_model=CreateConceptResponse, status_code=status.HTTP_201_CREATED)
async def create_concept(
    request: CreateConceptRequest,
    session: Session = Depends(get_session)
):
    """
    Create a concept with cards for multiple languages using LLM generation.
    
    Execution flow:
    1. Validate topic_id (if provided) and language codes exist
    2. Generate prompt and call Gemini API once
    3. Validate LLM output using Pydantic
    4. Create concept row in database
    5. Create card rows for each language in database
    6. All database operations in a single transaction
    7. Return created concept and cards
    """
    # Validate topic exists if topic_id is provided
    if request.topic_id is not None:
        topic = session.get(Topic, request.topic_id)
        if not topic:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Topic with id {request.topic_id} not found"
            )
    
    # Validate all language codes exist
    language_codes = [lang.lower() for lang in request.languages]
    languages = session.exec(
        select(Language).where(Language.code.in_(language_codes))
    ).all()
    
    found_language_codes = {lang.code.lower() for lang in languages}
    missing_languages = set(language_codes) - found_language_codes
    
    if missing_languages:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(sorted(missing_languages))}"
        )
    
    # Generate prompt
    prompt = generate_concept_prompt(
        term=request.term,
        part_of_speech=request.part_of_speech,
        core_meaning_en=request.core_meaning_en,
        excluded_senses=request.excluded_senses or [],
        languages=language_codes
    )
    
    logger.info(f"Calling Gemini API for concept creation: term='{request.term}', languages={language_codes}")
    
    # Call Gemini API
    try:
        llm_data, token_usage = call_gemini_api(prompt)
        logger.info(f"Gemini API call completed. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
    except Exception as e:
        logger.error(f"Gemini API call failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate concept data: {str(e)}"
        )
    
    # Validate LLM output using Pydantic
    try:
        validated_data = LLMResponse.model_validate(llm_data)
    except Exception as e:
        logger.error(f"LLM output validation failed: {str(e)}")
        logger.error(f"LLM response: {json.dumps(llm_data, indent=2)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Invalid LLM output format: {str(e)}"
        )
    
    # Verify we have cards for all requested languages
    card_language_codes = {card.language_code.lower() for card in validated_data.cards}
    missing_card_languages = set(language_codes) - card_language_codes
    
    if missing_card_languages:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"LLM did not generate cards for all languages. Missing: {', '.join(sorted(missing_card_languages))}"
        )
    
    # Verify no duplicate language codes in cards
    if len(validated_data.cards) != len(card_language_codes):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="LLM generated duplicate language codes in cards"
        )
    
    # Create concept and cards in a single transaction
    try:
        # Create concept record with the given term, description, and topic (if given)
        concept = Concept(
            topic_id=request.topic_id,  # Topic ID if provided
            term=request.term,  # Term from user input
            description=validated_data.concept.description,  # Description from LLM response
            part_of_speech=request.part_of_speech,
            frequency_bucket=validated_data.concept.frequency_bucket,
            status="active"
        )
        session.add(concept)
        session.flush()  # Flush to get concept.id without committing
        
        # Create cards
        created_cards = []
        for card_data in validated_data.cards:
            card = Card(
                concept_id=concept.id,
                language_code=card_data.language_code.lower(),
                term=card_data.term,
                ipa=card_data.ipa,
                description=card_data.description,
                gender=card_data.gender,
                article=card_data.article,
                plural_form=card_data.plural_form,
                verb_type=card_data.verb_type,
                auxiliary_verb=card_data.auxiliary_verb,
                formality_register=card_data.formality_register,
                status="active",
                source="llm"
            )
            session.add(card)
            created_cards.append(card)
        
        # Commit transaction
        session.commit()
        
        # Refresh objects to get IDs and timestamps
        session.refresh(concept)
        for card in created_cards:
            session.refresh(card)
        
        logger.info(f"Successfully created concept {concept.id} with {len(created_cards)} cards")
        
    except Exception as e:
        session.rollback()
        logger.error(f"Database transaction failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create concept and cards: {str(e)}"
        )
    
    # Build response
    return CreateConceptResponse(
        concept=ConceptResponse.model_validate(concept),
        cards=[CardResponse(
            id=card.id,
            concept_id=card.concept_id,
            language_code=card.language_code,
            translation=card.term,
            description=card.description or "",
            ipa=card.ipa,
            audio_path=card.audio_url,
            gender=card.gender,
            article=card.article,
            plural_form=card.plural_form,
            verb_type=card.verb_type,
            auxiliary_verb=card.auxiliary_verb,
            formality_register=card.formality_register,
            notes=None  # Card model doesn't have notes field
        ) for card in created_cards]
    )


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
            Concept.term.isnot(None),
            Concept.term.ilike(f"%{search_term}%")
        ).order_by(Concept.created_at.desc())
    ).all()
    
    return [ConceptResponse.model_validate(concept) for concept in concepts]


@router.post("/create-only", response_model=ConceptResponse, status_code=status.HTTP_201_CREATED)
async def create_concept_only(
    request: CreateConceptOnlyRequest,
    session: Session = Depends(get_session)
):
    """
    Create a concept record with term, description, and topic (if given).
    This does NOT create any cards - use generate-cards endpoint to create cards.
    
    Execution flow:
    1. Validate topic_id (if provided) exists
    2. Create concept row in database
    3. Return created concept
    """
    # Validate topic exists if topic_id is provided
    if request.topic_id is not None:
        topic = session.get(Topic, request.topic_id)
        if not topic:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Topic with id {request.topic_id} not found"
            )
    
    # Validate term is not empty
    if not request.term or not request.term.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term cannot be empty"
        )
    
    # Create concept record
    try:
        concept = Concept(
            topic_id=request.topic_id,
            term=request.term.strip(),
            description=request.description.strip() if request.description else None,
            status="active"
        )
        session.add(concept)
        session.commit()
        session.refresh(concept)
        
        logger.info(f"Successfully created concept {concept.id} (term: {concept.term})")
        
    except Exception as e:
        session.rollback()
        logger.error(f"Database transaction failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create concept: {str(e)}"
        )
    
    return ConceptResponse.model_validate(concept)


@router.post("/missing-languages", response_model=ConceptsWithMissingLanguagesResponse)
async def get_concepts_with_missing_languages(
    request: GetConceptsWithMissingLanguagesRequest,
    session: Session = Depends(get_session)
):
    """
    Get concepts that are missing cards for the given list of languages.
    
    Only includes concepts with term, description, and part_of_speech present.
    For each concept, includes languages that either:
    1. Don't have a card in Card table, OR
    2. Have a card but the card is missing term, description, or ipa
    
    Results are sorted by max(created_at, updated_at) descending (recent first).
    
    Args:
        request: Request containing languages list
    
    Returns:
        List of concepts with their missing languages
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
    
    # Get concepts with term, description, and part_of_speech present
    all_concepts = session.exec(
        select(Concept).where(
            Concept.term.isnot(None),
            Concept.term != "",
            Concept.description.isnot(None),
            Concept.description != "",
            Concept.part_of_speech.isnot(None),
            Concept.part_of_speech != ""
        )
    ).all()
    
    # For each concept, find which languages need cards (missing or incomplete)
    concepts_with_missing = []
    for concept in all_concepts:
        # Get existing cards for this concept
        existing_cards = session.exec(
            select(Card).where(Card.concept_id == concept.id)
        ).all()
        
        # Create a map of existing cards by language code
        existing_cards_by_lang = {card.language_code.lower(): card for card in existing_cards}
        
        # Find languages that need cards
        missing_for_concept = []
        for lang in language_codes:
            card = existing_cards_by_lang.get(lang)
            
            # Language needs a card if:
            # 1. No card exists, OR
            # 2. Card exists but is missing term, description, or ipa
            if not card:
                missing_for_concept.append(lang)
            elif not card.term or not card.term.strip() or \
                 not card.description or not card.description.strip() or \
                 not card.ipa or not card.ipa.strip():
                missing_for_concept.append(lang)
        
        if missing_for_concept:
            # Calculate max timestamp for sorting (concept created_at, updated_at, and max card timestamp)
            concept_timestamps = []
            if concept.created_at:
                concept_timestamps.append(concept.created_at)
            if concept.updated_at:
                concept_timestamps.append(concept.updated_at)
            
            # Get max timestamp from cards for this concept
            for card in existing_cards:
                if card.created_at:
                    concept_timestamps.append(card.created_at)
                if card.updated_at:
                    concept_timestamps.append(card.updated_at)
            
            max_timestamp = max(concept_timestamps) if concept_timestamps else None
            
            concepts_with_missing.append(
                (max_timestamp, concept, missing_for_concept)
            )
    
    # Sort by max timestamp descending (recent first), then by concept term alphabetical (ascending A to Z)
    # Use negative timestamp for descending order, then term for ascending alphabetical
    concepts_with_missing.sort(
        key=lambda x: (
            -(x[0].timestamp() if x[0] else datetime.min.replace(tzinfo=timezone.utc).timestamp()),
            (x[1].term or "").lower() if x[1].term else ""
        ),
        reverse=False  # Explicitly set to False to ensure ascending order for terms
    )
    
    # Build response (limit to 100 concepts max)
    result = []
    for max_timestamp, concept, missing_langs in concepts_with_missing[:100]:
        result.append(
            ConceptWithMissingLanguages(
                concept=ConceptResponse.model_validate(concept),
                missing_languages=missing_langs
            )
        )
    
    return ConceptsWithMissingLanguagesResponse(concepts=result)


@router.post("/generate-cards", response_model=GenerateCardsForConceptsResponse)
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
    logger.info(f"Request JSON Input: concept_ids={request.concept_ids}, languages={request.languages}")
    logger.info(f"Concepts to process: {[{'id': c.id, 'term': c.term, 'description': c.description} for c in concepts]}")
    
    # Sort concepts by max(created_at, updated_at) descending (recent first)
    # If timestamps are the same, sort alphabetically by concept term
    # This ensures we process the most recently created/updated concepts first
    def get_concept_sort_key(concept):
        timestamps = []
        if concept.created_at:
            timestamps.append(concept.created_at)
        if concept.updated_at:
            timestamps.append(concept.updated_at)
        # Also check cards for this concept
        concept_cards = session.exec(
            select(Card).where(Card.concept_id == concept.id)
        ).all()
        for card in concept_cards:
            if card.created_at:
                timestamps.append(card.created_at)
            if card.updated_at:
                timestamps.append(card.updated_at)
        max_timestamp = max(timestamps) if timestamps else datetime.min.replace(tzinfo=timezone.utc)
        # Use negative timestamp for descending order (most recent first), then term for ascending alphabetical (A to Z)
        return (-max_timestamp.timestamp(), (concept.term or "").lower() if concept.term else "")
    
    concepts.sort(key=get_concept_sort_key, reverse=False)  # Explicitly set to False to ensure ascending order for terms
    
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

