"""
Card CRUD endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func
from datetime import datetime, timezone
from typing import List, Optional
import logging
from app.core.database import get_session
from app.models.models import Card, Concept, Language, Image
from app.schemas.flashcard import (
    CardResponse, UpdateCardRequest, CreateConceptRequest, 
    CreateConceptResponse, ConceptResponse, ImageResponse,
    GenerateCardsForConceptsRequest, GenerateCardsForConceptsResponse
)
from app.api.v1.endpoints.flashcard_helpers import ensure_capitalized
from app.api.v1.endpoints.llm_helpers import call_gemini_api
from app.api.v1.endpoints.prompt_helpers import (
    generate_lemma_system_instruction,
    generate_lemma_user_prompt
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/cards", tags=["cards"])


@router.get("", response_model=List[CardResponse])
async def get_cards(
    skip: int = 0,
    limit: int = 100,
    concept_id: Optional[int] = None,
    language_code: Optional[str] = None,
    session: Session = Depends(get_session)
):
    """
    Get cards with optional filtering.
    
    Args:
        skip: Number of cards to skip
        limit: Maximum number of cards to return
        concept_id: Optional filter by concept ID
        language_code: Optional filter by language code
    
    Returns:
        List of cards
    """
    query = select(Card)
    
    if concept_id is not None:
        query = query.where(Card.concept_id == concept_id)
    
    if language_code is not None:
        query = query.where(Card.language_code == language_code.lower())
    
    cards = session.exec(
        query.offset(skip).limit(limit).order_by(Card.created_at.desc())
    ).all()
    
    return [
        CardResponse(
            id=card.id,
            concept_id=card.concept_id,
            language_code=card.language_code,
            translation=ensure_capitalized(card.term),
            description=card.description,
            ipa=card.ipa,
            audio_path=card.audio_url,
            gender=card.gender,
            article=card.article,
            plural_form=card.plural_form,
            verb_type=card.verb_type,
            auxiliary_verb=card.auxiliary_verb,
            formality_register=card.formality_register,
            notes=card.notes
        )
        for card in cards
    ]


@router.get("/concept/{concept_id}", response_model=List[CardResponse])
async def get_cards_by_concept_id(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Get all cards for a given concept ID.
    
    Args:
        concept_id: The concept ID
    
    Returns:
        List of cards associated with the concept
    """
    # Verify that the concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all cards for this concept
    cards = session.exec(
        select(Card).where(Card.concept_id == concept_id).order_by(Card.created_at.desc())
    ).all()
    
    return [
        CardResponse(
            id=card.id,
            concept_id=card.concept_id,
            language_code=card.language_code,
            translation=ensure_capitalized(card.term),
            description=card.description,
            ipa=card.ipa,
            audio_path=card.audio_url,
            gender=card.gender,
            article=card.article,
            plural_form=card.plural_form,
            verb_type=card.verb_type,
            auxiliary_verb=card.auxiliary_verb,
            formality_register=card.formality_register,
            notes=card.notes
        )
        for card in cards
    ]


@router.post("/generate")
async def generate_cards_for_concept(
    http_request: Request,
    session: Session = Depends(get_session)
):
    """
    Generate cards for concepts in multiple languages.
    
    This endpoint can handle two types of requests:
    1. CreateConceptRequest: Finds an existing concept by term and generates cards
    2. GenerateCardsForConceptsRequest: Generates cards for specified concept IDs
    
    Args:
        http_request: FastAPI Request object to inspect the body
        session: Database session
    
    Returns:
        CreateConceptResponse or GenerateCardsForConceptsResponse
    """
    # Parse the request body
    body = await http_request.json()
    
    # Check if this is a GenerateCardsForConceptsRequest (has concept_ids)
    if 'concept_ids' in body:
        # Handle GenerateCardsForConceptsRequest
        request = GenerateCardsForConceptsRequest(**body)
        return await _generate_cards_for_concepts_list(request, session)
    
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
    languages = session.exec(
        select(Language).where(Language.code.in_(language_codes))
    ).all()
    
    found_codes = {lang.code for lang in languages}
    missing_codes = set(language_codes) - found_codes
    if missing_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(missing_codes)}"
        )
    
    # Find existing concept matching the term (case-insensitive exact match)
    # Priority: 1) user_id match, 2) has description, 3) any match
    all_matching_concepts = session.exec(
        select(Concept).where(
            func.lower(Concept.term) == term_stripped.lower()
        ).order_by(Concept.created_at.desc())
    ).all()
    
    if not all_matching_concepts:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No concept found with term '{term_stripped}'. Please create the concept first."
        )
    
    # Prioritize concepts: user_id match first, then concepts with description
    concept = None
    
    # First priority: concepts with matching user_id
    if request.user_id is not None:
        user_matched = [c for c in all_matching_concepts if c.user_id == request.user_id]
        if user_matched:
            # Among user-matched concepts, prefer those with description
            with_description = [c for c in user_matched if c.description and c.description.strip()]
            concept = with_description[0] if with_description else user_matched[0]
    
    # Second priority: concepts with description (if no user_id match or user_id not provided)
    if concept is None:
        with_description = [c for c in all_matching_concepts if c.description and c.description.strip()]
        if with_description:
            concept = with_description[0]
    
    # Third priority: any matching concept
    if concept is None:
        concept = all_matching_concepts[0]
    
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
    
    # Generate cards for each language
    created_cards = []
    errors = []
    
    for lang_code in language_codes:
        try:
            # Generate user prompt for this language
            user_prompt = generate_lemma_user_prompt(target_language=lang_code)
            
            logger.info(f"Generating card for concept {concept.id}, language {lang_code}")
            
            # Call LLM to generate card data
            try:
                llm_data, token_usage = call_gemini_api(
                    prompt=user_prompt,
                    system_instruction=system_instruction
                )
                logger.info(f"Generated card for {lang_code}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
            except Exception as e:
                logger.error(f"LLM API call failed for language {lang_code}: {str(e)}")
                errors.append(f"Failed to generate card for {lang_code}: {str(e)}")
                continue
            
            # Validate LLM output
            if not isinstance(llm_data, dict):
                errors.append(f"Invalid LLM output format for {lang_code}")
                continue
            
            required_fields = ['term', 'description']
            for field in required_fields:
                if field not in llm_data or not llm_data[field]:
                    errors.append(f"Missing required field '{field}' for {lang_code}")
                    continue
            
            # Validate optional fields
            if 'gender' in llm_data and llm_data['gender'] is not None:
                valid_genders = ['masculine', 'feminine', 'neuter']
                if llm_data['gender'] not in valid_genders:
                    errors.append(f"Invalid gender value for {lang_code}: {llm_data['gender']}")
                    continue
            
            if 'register' in llm_data and llm_data['register'] is not None:
                valid_registers = ['neutral', 'formal', 'informal', 'slang']
                if llm_data['register'] not in valid_registers:
                    errors.append(f"Invalid register value for {lang_code}: {llm_data['register']}")
                    continue
            
            # Normalize term (trim whitespace)
            term = llm_data.get('term')
            if term:
                term = term.strip()
            
            # Check for existing cards with same concept_id, language_code, and term (case-insensitive)
            # This prevents duplicates and ensures the unique constraint is respected
            if term:
                existing_cards = session.exec(
                    select(Card).where(
                        Card.concept_id == concept.id,
                        Card.language_code == lang_code,
                        func.lower(func.trim(Card.term)) == term.lower()
                    )
                ).all()
                
                # Delete all matching cards to avoid unique constraint issues
                for existing_card in existing_cards:
                    session.delete(existing_card)
                if existing_cards:
                    session.flush()
            else:
                # If no term, check by concept_id and language_code only
                existing_card = session.exec(
                    select(Card).where(
                        Card.concept_id == concept.id,
                        Card.language_code == lang_code
                    )
                ).first()
                
                if existing_card:
                    session.delete(existing_card)
                    session.flush()
            
            # Create new card
            card = Card(
                concept_id=concept.id,
                language_code=lang_code,
                term=term,
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
            session.commit()
            session.refresh(card)
            
            # Convert to CardResponse
            card_response = CardResponse(
                id=card.id,
                concept_id=card.concept_id,
                language_code=card.language_code,
                translation=ensure_capitalized(card.term) if card.term else "",
                description=card.description,
                ipa=card.ipa,
                audio_path=card.audio_url,
                gender=card.gender,
                article=card.article,
                plural_form=card.plural_form,
                verb_type=card.verb_type,
                auxiliary_verb=card.auxiliary_verb,
                formality_register=card.formality_register,
                notes=card.notes
            )
            created_cards.append(card_response)
            
        except Exception as e:
            logger.error(f"Error generating card for language {lang_code}: {str(e)}")
            errors.append(f"Error generating card for {lang_code}: {str(e)}")
            continue
    
    # If no cards were created, return error
    if not created_cards:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate any cards. Errors: {'; '.join(errors)}"
        )
    
    # Load images for the concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept.id)
    ).all()
    
    concept_dict = ConceptResponse.model_validate(concept).model_dump()
    concept_dict['images'] = [ImageResponse.model_validate(img) for img in images]
    concept_response = ConceptResponse(**concept_dict)
    
    return CreateConceptResponse(
        concept=concept_response,
        cards=created_cards
    )


async def _generate_cards_for_concepts_list(
    request: GenerateCardsForConceptsRequest,
    session: Session
):
    """
    Internal function to generate cards for multiple concepts.
    
    Args:
        request: GenerateCardsForConceptsRequest with concept_ids and languages
        session: Database session
    
    Returns:
        GenerateCardsForConceptsResponse with statistics about the generation
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
    languages = session.exec(
        select(Language).where(Language.code.in_(language_codes))
    ).all()
    
    found_codes = {lang.code for lang in languages}
    missing_codes = set(language_codes) - found_codes
    if missing_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(missing_codes)}"
        )
    
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
    total_cards_created = 0
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
            
            # Generate cards for each language
            for lang_code in language_codes:
                try:
                    # Check if card already exists for this concept and language
                    existing_card = session.exec(
                        select(Card).where(
                            Card.concept_id == concept.id,
                            Card.language_code == lang_code
                        )
                    ).first()
                    
                    if existing_card:
                        # Skip if card already exists
                        logger.info(f"Card already exists for concept {concept.id}, language {lang_code}")
                        continue
                    
                    # Generate user prompt for this language
                    user_prompt = generate_lemma_user_prompt(target_language=lang_code)
                    
                    logger.info(f"Generating card for concept {concept.id}, language {lang_code}")
                    
                    # Call LLM to generate card data
                    try:
                        llm_data, token_usage = call_gemini_api(
                            prompt=user_prompt,
                            system_instruction=system_instruction
                        )
                        logger.info(f"Generated card for concept {concept.id}, {lang_code}. Tokens: {token_usage['total_tokens']}, Cost: ${token_usage['cost_usd']:.6f}")
                        
                        total_tokens += token_usage.get('total_tokens', 0)
                        total_cost_usd += token_usage.get('cost_usd', 0.0)
                    except Exception as e:
                        logger.error(f"LLM API call failed for concept {concept.id}, language {lang_code}: {str(e)}")
                        errors.append(f"Concept {concept.id}, {lang_code}: {str(e)}")
                        continue
                    
                    # Validate LLM output
                    if not isinstance(llm_data, dict):
                        errors.append(f"Concept {concept.id}, {lang_code}: Invalid LLM output format")
                        continue
                    
                    required_fields = ['term', 'description']
                    for field in required_fields:
                        if field not in llm_data or not llm_data[field]:
                            errors.append(f"Concept {concept.id}, {lang_code}: Missing required field '{field}'")
                            continue
                    
                    # Validate optional fields
                    if 'gender' in llm_data and llm_data['gender'] is not None:
                        valid_genders = ['masculine', 'feminine', 'neuter']
                        if llm_data['gender'] not in valid_genders:
                            errors.append(f"Concept {concept.id}, {lang_code}: Invalid gender value")
                            continue
                    
                    if 'register' in llm_data and llm_data['register'] is not None:
                        valid_registers = ['neutral', 'formal', 'informal', 'slang']
                        if llm_data['register'] not in valid_registers:
                            errors.append(f"Concept {concept.id}, {lang_code}: Invalid register value")
                            continue
                    
                    # Normalize term (trim whitespace)
                    term = llm_data.get('term')
                    if term:
                        term = term.strip()
                    
                    # Check for existing cards with same concept_id, language_code, and term (case-insensitive)
                    # This prevents duplicates and ensures the unique constraint is respected
                    if term:
                        existing_cards = session.exec(
                            select(Card).where(
                                Card.concept_id == concept.id,
                                Card.language_code == lang_code,
                                func.lower(func.trim(Card.term)) == term.lower()
                            )
                        ).all()
                        
                        # Delete all matching cards to avoid unique constraint issues
                        for existing_card in existing_cards:
                            session.delete(existing_card)
                        if existing_cards:
                            session.flush()
                    else:
                        # If no term, check by concept_id and language_code only
                        existing_card = session.exec(
                            select(Card).where(
                                Card.concept_id == concept.id,
                                Card.language_code == lang_code
                            )
                        ).first()
                        
                        if existing_card:
                            session.delete(existing_card)
                            session.flush()
                    
                    # Create new card
                    card = Card(
                        concept_id=concept.id,
                        language_code=lang_code,
                        term=term,
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
                    session.commit()
                    session.refresh(card)
                    
                    total_cards_created += 1
                    logger.info(f"Created card {card.id} for concept {concept.id}, language {lang_code}")
                    
                except Exception as e:
                    logger.error(f"Error generating card for concept {concept.id}, language {lang_code}: {str(e)}")
                    errors.append(f"Concept {concept.id}, {lang_code}: {str(e)}")
                    session.rollback()
                    continue
                    
        except Exception as e:
            logger.error(f"Error processing concept {concept.id}: {str(e)}")
            errors.append(f"Concept {concept.id}: {str(e)}")
            continue
    
    logger.info(f"Batch generation completed. Created {total_cards_created} cards, {len(errors)} errors")
    
    return GenerateCardsForConceptsResponse(
        concepts_processed=len(concepts),
        cards_created=total_cards_created,
        errors=errors,
        total_concepts=len(concepts),
        session_cost_usd=total_cost_usd,
        total_tokens=total_tokens
    )


@router.get("/{card_id}", response_model=CardResponse)
async def get_card(
    card_id: int,
    session: Session = Depends(get_session)
):
    """
    Get a card by ID.
    
    Args:
        card_id: The card ID
    
    Returns:
        The card
    """
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    return CardResponse(
        id=card.id,
        concept_id=card.concept_id,
        language_code=card.language_code,
        translation=ensure_capitalized(card.term),
        description=card.description,
        ipa=card.ipa,
        audio_path=card.audio_url,
        gender=card.gender,
        article=card.article,
        plural_form=card.plural_form,
        verb_type=card.verb_type,
        auxiliary_verb=card.auxiliary_verb,
        formality_register=card.formality_register,
        notes=card.notes
    )


@router.put("/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: int,
    request: UpdateCardRequest,
    session: Session = Depends(get_session)
):
    """
    Update a card's translation and description.
    
    Args:
        card_id: The card ID
        request: Update request with fields to update
    
    Returns:
        The updated card
    """
    # Get the card
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Check if translation update would create a duplicate
    if request.translation is not None:
        new_term = ensure_capitalized(request.translation.strip())
        
        # Check if another card with same concept_id, language_code, and term already exists
        existing_card = session.exec(
            select(Card).where(
                Card.concept_id == card.concept_id,
                Card.language_code == card.language_code,
                Card.term == new_term,
                Card.id != card_id  # Exclude the current card
            )
        ).first()
        
        if existing_card:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"A card with the same concept_id, language_code, and term already exists (card_id: {existing_card.id})"
            )
        
        card.term = new_term
        card.updated_at = datetime.now(timezone.utc)
    
    if request.description is not None:
        card.description = request.description.strip()
        card.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(card)
        session.commit()
        session.refresh(card)
    except IntegrityError as e:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Failed to update card: duplicate constraint violation"
        ) from e
    
    return CardResponse(
        id=card.id,
        concept_id=card.concept_id,
        language_code=card.language_code,
        translation=ensure_capitalized(card.term),
        description=card.description,
        ipa=card.ipa,
        audio_path=card.audio_url,
        gender=card.gender,
        article=card.article,
        plural_form=card.plural_form,
        verb_type=card.verb_type,
        auxiliary_verb=card.auxiliary_verb,
        formality_register=card.formality_register,
        notes=card.notes
    )


@router.delete("/{card_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_card(
    card_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a card and all its associated user_cards.
    
    Args:
        card_id: The card ID
    """
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Delete all UserCards that reference this card
    from app.models.models import UserCard
    user_cards = session.exec(
        select(UserCard).where(UserCard.card_id == card_id)
    ).all()
    
    for user_card in user_cards:
        session.delete(user_card)
    
    # Delete the card
    session.delete(card)
    
    session.commit()
    
    return None

