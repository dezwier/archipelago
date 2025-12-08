"""
Concept generation endpoint.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy import text
from app.core.database import get_session
from app.core.config import settings
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
import requests
import json
import logging
from typing import List, Optional

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concepts", tags=["concepts"])


def calculate_gemini_cost(prompt_tokens: int, output_tokens: int, model_name: str = "gemini-2.5-flash") -> float:
    """
    Calculate cost for Gemini API call based on token usage.
    
    Pricing (as of 2024):
    - gemini-2.5-flash: $0.075 per 1M input tokens, $0.30 per 1M output tokens
    - gemini-2.5-pro: $0.125 per 1M input tokens, $0.50 per 1M output tokens
    
    Args:
        prompt_tokens: Number of input tokens
        output_tokens: Number of output tokens
        model_name: Name of the model used
        
    Returns:
        Cost in USD
    """
    # Pricing per million tokens
    if "flash" in model_name.lower():
        input_price_per_million = 0.075
        output_price_per_million = 0.30
    elif "pro" in model_name.lower():
        input_price_per_million = 0.125
        output_price_per_million = 0.50
    else:
        # Default to flash pricing
        input_price_per_million = 0.075
        output_price_per_million = 0.30
    
    input_cost = (prompt_tokens / 1_000_000) * input_price_per_million
    output_cost = (output_tokens / 1_000_000) * output_price_per_million
    
    return input_cost + output_cost


def call_gemini_api(prompt: str) -> tuple[dict, dict]:
    """
    Call Gemini API to generate concept and card data.
    
    Args:
        prompt: The prompt to send to the LLM
        
    Returns:
        Tuple of (parsed JSON response from the LLM, token usage dict with keys:
                  'prompt_tokens', 'output_tokens', 'total_tokens', 'cost_usd', 'model_name')
        
    Raises:
        Exception: If API call fails or response is invalid
    """
    api_key = settings.google_gemini_api_key
    if not api_key:
        raise Exception("Google Gemini API key not configured")
    
    model_name = "gemini-2.5-flash"
    base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
    
    payload = {
        "contents": [{
            "parts": [{
                "text": prompt
            }]
        }],
        "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 4096,
        }
    }
    
    try:
        response = requests.post(
            f"{base_url}?key={api_key}",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=60
        )
        response.raise_for_status()
        data = response.json()
        
        # Extract token usage from usageMetadata
        usage_metadata = data.get('usageMetadata', {})
        prompt_tokens = usage_metadata.get('promptTokenCount', 0)
        output_tokens = usage_metadata.get('candidatesTokenCount', 0)
        total_tokens = usage_metadata.get('totalTokenCount', prompt_tokens + output_tokens)
        
        # Calculate cost
        cost_usd = calculate_gemini_cost(prompt_tokens, output_tokens, model_name)
        
        token_usage = {
            'prompt_tokens': prompt_tokens,
            'output_tokens': output_tokens,
            'total_tokens': total_tokens,
            'cost_usd': cost_usd,
            'model_name': model_name
        }
        
        # Extract generated text
        if 'candidates' in data and len(data['candidates']) > 0:
            candidate = data['candidates'][0]
            if 'content' in candidate and 'parts' in candidate['content']:
                text = candidate['content']['parts'][0].get('text', '').strip()
                if not text:
                    raise Exception("LLM returned empty response")
                
                # Try to extract JSON from the response
                # The LLM might return markdown code blocks or plain JSON
                text = text.strip()
                if text.startswith('```'):
                    # Remove markdown code blocks
                    lines = text.split('\n')
                    text = '\n'.join(lines[1:-1]) if lines[0].startswith('```') else text
                    if text.endswith('```'):
                        text = text[:-3]
                
                # Parse JSON
                try:
                    llm_data = json.loads(text)
                    return llm_data, token_usage
                except json.JSONDecodeError as e:
                    logger.error(f"Failed to parse LLM JSON response: {e}")
                    logger.error(f"Response text: {text[:500]}")
                    raise Exception(f"LLM returned invalid JSON: {str(e)}")
            else:
                raise Exception("LLM response missing content or parts")
        else:
            raise Exception("LLM response missing candidates")
            
    except requests.exceptions.RequestException as e:
        error_msg = f"Gemini API request failed: {str(e)}"
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                error_msg += f" - {error_data}"
            except:
                error_msg += f" - Status: {e.response.status_code}"
        logger.error(error_msg)
        raise Exception(error_msg)


def generate_concept_prompt(
    term: str,
    part_of_speech: Optional[str],
    core_meaning_en: Optional[str],
    excluded_senses: List[str],
    languages: List[str]
) -> str:
    """
    Generate the prompt for the LLM.
    
    Args:
        term: The term to generate concept for
        part_of_speech: Part of speech (optional - will be inferred if not provided)
        core_meaning_en: Core meaning in English (optional)
        excluded_senses: List of excluded senses
        languages: List of language codes
        
    Returns:
        The prompt string
    """
    excluded_text = ""
    if excluded_senses:
        excluded_text = f"\nExcluded senses (do not include these meanings): {', '.join(excluded_senses)}"
    
    core_meaning_instruction = ""
    if core_meaning_en:
        core_meaning_instruction = f"\nCore meaning in English: {core_meaning_en}\nUse this exact meaning for all language cards."
    else:
        core_meaning_instruction = "\nIMPORTANT: No core meaning was provided. You must infer ONE specific semantic meaning for this term based on its part of speech and common usage. Choose the most common or primary meaning. All cards across all languages MUST represent this exact same semantic concept."
    
    # Handle part of speech - if not provided, instruct LLM to infer it
    part_of_speech_instruction = ""
    if part_of_speech:
        part_of_speech_instruction = f"\nPart of speech: {part_of_speech}"
    else:
        part_of_speech_instruction = "\nPart of speech: NOT PROVIDED - You must infer the part of speech from the term itself. Analyze the term to determine if it's a noun, verb, adjective, adverb, etc."
    
    prompt = f"""You are a language learning assistant. Generate concept and card data for the term "{term}".{part_of_speech_instruction}{core_meaning_instruction}{excluded_text}

Generate data for the following languages: {', '.join(languages)}

Return ONLY valid JSON in this exact format (no markdown, no explanations):
{{
  "concept": {{
    "description": "string describing the concept in English (the core semantic meaning)",
    "frequency_bucket": "very high | high | medium | low | very low"
  }},
  "cards": [
    {{
      "language_code": "en",
      "term": "string (use infinitive for verbs)",
      "ipa": "string or null (use standard IPA symbols)",
      "description": "string or null (in the target language, do NOT translate from English)",
      "gender": "masculine | feminine | neuter | null (for languages with gender)",
      "article": "string or null (for languages with articles)",
      "plural_form": "string or null (for nouns)",
      "verb_type": "string or null (for verbs)",
      "auxiliary_verb": "string or null (for verbs in languages like French)",
      "register": "neutral | formal | informal | slang | null"
    }}
  ]
}}

IMPORTANT - Valid values:
- part_of_speech (if inferring): Must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence
- frequency_bucket: Must be one of: very high, high, medium, low, very low
- gender: Must be one of: masculine, feminine, neuter, or null

Rules:
1. Generate exactly one card per requested language
2. CRITICAL: All cards must express the EXACT SAME core semantic meaning across all languages
3. If no core meaning was provided, infer ONE specific meaning and ensure ALL language cards represent that same meaning consistently
4. If part of speech was not provided, you must infer it from the term - analyze the term's form, context, and common usage patterns. The part of speech must be one of: Noun, Verb, Adjective, Adverb, Pronoun, Preposition, Conjunction, Determiner / Article, Interjection, Saying, Sentence
5. Use infinitive form for verbs
6. Use null for non-applicable fields
7. IPA must use standard IPA symbols
8. Descriptions should be in the target language, not translated from English
9. All cards must represent the same semantic concept - consistency across languages is essential
10. The concept description should clearly define the single semantic meaning that all cards share
11. frequency_bucket must be exactly one of: "very high", "high", "medium", "low", or "very low"
12. gender must be exactly one of: "masculine", "feminine", "neuter", or null"""
    
    return prompt


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
            notes=None  # Card model doesn't have notes field
        ) for card in created_cards]
    )


@router.get("", response_model=List[ConceptResponse])
async def list_concepts(
    skip: int = 0,
    limit: int = 100,
    session: Session = Depends(get_session)
):
    """
    List all concepts in the database.
    
    Args:
        skip: Number of concepts to skip (for pagination)
        limit: Maximum number of concepts to return (default: 100, max: 1000)
    
    Returns:
        List of concepts
    """
    if limit > 1000:
        limit = 1000
    
    concepts = session.exec(
        select(Concept).offset(skip).limit(limit).order_by(Concept.created_at.desc())
    ).all()
    
    return [ConceptResponse.model_validate(concept) for concept in concepts]


@router.get("/count")
async def get_concept_count(
    session: Session = Depends(get_session)
):
    """
    Get the total count of concepts in the database.
    
    Returns:
        Dictionary with concept count
    """
    # Count concepts by querying all and getting length
    # This is simple but not optimal for large datasets
    all_concepts = session.exec(select(Concept)).all()
    count = len(all_concepts)
    
    return {"count": count}


@router.get("/integrity-check")
async def check_data_integrity(
    session: Session = Depends(get_session)
):
    """
    Check data integrity between concepts and cards.
    Verifies that all cards have valid concept_id references.
    
    Returns:
        Dictionary with integrity check results
    """
    # Check for orphaned cards (cards with concept_id that doesn't exist)
    orphaned_cards_query = text("""
        SELECT COUNT(*) as count
        FROM card
        WHERE concept_id NOT IN (SELECT id FROM concept)
    """)
    
    orphaned_result = session.exec(orphaned_cards_query).first()
    orphaned_count = orphaned_result[0] if orphaned_result else 0
    
    # Get total counts
    total_concepts = len(session.exec(select(Concept)).all())
    total_cards = len(session.exec(select(Card)).all())
    
    # Get cards grouped by concept
    cards_by_concept_query = text("""
        SELECT concept_id, COUNT(*) as card_count
        FROM card
        GROUP BY concept_id
    """)
    
    cards_by_concept = session.exec(cards_by_concept_query).all()
    concepts_with_cards = len(cards_by_concept)
    
    return {
        "total_concepts": total_concepts,
        "total_cards": total_cards,
        "concepts_with_cards": concepts_with_cards,
        "orphaned_cards": orphaned_count,
        "integrity_ok": orphaned_count == 0,
        "message": "Data integrity check passed" if orphaned_count == 0 else f"Found {orphaned_count} orphaned card(s) - these should be deleted"
    }


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
    
    # Get all concepts
    all_concepts = session.exec(select(Concept)).all()
    
    # For each concept, find which languages are missing
    concepts_with_missing = []
    for concept in all_concepts:
        # Get existing cards for this concept
        existing_cards = session.exec(
            select(Card).where(Card.concept_id == concept.id)
        ).all()
        
        existing_language_codes = {card.language_code.lower() for card in existing_cards}
        missing_for_concept = [lang for lang in language_codes if lang not in existing_language_codes]
        
        if missing_for_concept:
            concepts_with_missing.append(
                ConceptWithMissingLanguages(
                    concept=ConceptResponse.model_validate(concept),
                    missing_languages=missing_for_concept
                )
            )
    
    return ConceptsWithMissingLanguagesResponse(concepts=concepts_with_missing)


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
    
    concepts_processed = 0
    cards_created = 0
    errors = []
    total_cost_usd = 0.0
    total_tokens = 0
    
    # Process each concept
    for concept in concepts:
        try:
            # Get existing cards for this concept to determine which languages we need
            existing_cards = session.exec(
                select(Card).where(Card.concept_id == concept.id)
            ).all()
            
            existing_language_codes = {card.language_code.lower() for card in existing_cards}
            languages_to_generate = [lang for lang in language_codes if lang not in existing_language_codes]
            
            if not languages_to_generate:
                # All languages already have cards, skip
                continue
            
            # Generate prompt for this concept
            prompt = generate_concept_prompt(
                term=concept.term or "",
                part_of_speech=concept.part_of_speech,
                core_meaning_en=concept.description,
                excluded_senses=[],
                languages=languages_to_generate
            )
            
            logger.info(f"Calling Gemini API for concept {concept.id}: term='{concept.term}', languages={languages_to_generate}")
            
            # Call Gemini API
            try:
                llm_data, token_usage = call_gemini_api(prompt)
                total_cost_usd += token_usage['cost_usd']
                total_tokens += token_usage['total_tokens']
                logger.info(f"Gemini API call completed for concept {concept.id}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
            except Exception as e:
                logger.error(f"Gemini API call failed for concept {concept.id}: {str(e)}")
                errors.append(f"Concept {concept.id} ({concept.term}): Failed to generate cards - {str(e)}")
                continue
            
            # Validate LLM output using Pydantic
            try:
                validated_data = LLMResponse.model_validate(llm_data)
            except Exception as e:
                logger.error(f"LLM output validation failed for concept {concept.id}: {str(e)}")
                errors.append(f"Concept {concept.id} ({concept.term}): Invalid LLM output format - {str(e)}")
                continue
            
            # Verify we have cards for all requested languages
            card_language_codes = {card.language_code.lower() for card in validated_data.cards}
            missing_card_languages = set(languages_to_generate) - card_language_codes
            
            if missing_card_languages:
                errors.append(f"Concept {concept.id} ({concept.term}): LLM did not generate cards for all languages. Missing: {', '.join(sorted(missing_card_languages))}")
                continue
            
            # Verify no duplicate language codes in cards
            if len(validated_data.cards) != len(card_language_codes):
                errors.append(f"Concept {concept.id} ({concept.term}): LLM generated duplicate language codes in cards")
                continue
            
            # Create cards in database
            try:
                created_cards = []
                for card_data in validated_data.cards:
                    # Skip if card already exists for this language
                    if card_data.language_code.lower() in existing_language_codes:
                        continue
                    
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
                
                # Commit transaction for this concept
                session.commit()
                
                # Refresh cards to get IDs
                for card in created_cards:
                    session.refresh(card)
                
                cards_created += len(created_cards)
                concepts_processed += 1
                
                logger.info(f"Successfully created {len(created_cards)} cards for concept {concept.id}")
                
            except Exception as e:
                session.rollback()
                logger.error(f"Database transaction failed for concept {concept.id}: {str(e)}")
                errors.append(f"Concept {concept.id} ({concept.term}): Failed to create cards - {str(e)}")
                continue
                
        except Exception as e:
            logger.error(f"Unexpected error processing concept {concept.id}: {str(e)}")
            errors.append(f"Concept {concept.id} ({concept.term}): Unexpected error - {str(e)}")
            continue
    
    return GenerateCardsForConceptsResponse(
        concepts_processed=concepts_processed,
        cards_created=cards_created,
        errors=errors,
        total_concepts=len(concepts),
        session_cost_usd=round(total_cost_usd, 6),
        total_tokens=total_tokens
    )

