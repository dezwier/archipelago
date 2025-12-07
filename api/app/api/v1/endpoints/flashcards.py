from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from sqlalchemy import func
from app.core.database import get_session
from app.models.models import Topic, Concept, Card, Language, User, UserCard
from app.schemas.flashcard import (
    GenerateFlashcardRequest,
    GenerateFlashcardResponse,
    ConceptResponse,
    TopicResponse,
    CardResponse,
    PairedVocabularyItem,
    VocabularyResponse,
    UpdateCardRequest,
)
from app.services.translation_service import translation_service
from app.services.description_service import description_service
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcards", tags=["flashcards"])


def ensure_capitalized(text: str) -> str:
    """
    Ensure the first letter is capitalized while preserving the rest of the case.
    If text is empty, return as is.
    """
    if not text:
        return text
    return text[0].upper() + text[1:] if len(text) > 0 else text


@router.post("/generate", response_model=GenerateFlashcardResponse, status_code=status.HTTP_201_CREATED)
async def generate_flashcard(
    request: GenerateFlashcardRequest,
    session: Session = Depends(get_session)
):
    """
    Generate a flashcard by creating concept and cards for source and target languages.
    
    Logic:
    1. Retrieve all cards with same text (translation) in all languages
    2. If none present, write a new Concept record
    3. Retrieve API call for languages that weren't in Card, if any
    4. Write the translations that didn't exist in Card, using the correct concept_id
    """
    # Normalize language codes to lowercase for validation
    source_lang_code = request.source_language.lower()
    target_lang_code = request.target_language.lower()
    
    # Validate languages exist
    source_lang = session.exec(select(Language).where(Language.code == source_lang_code)).first()
    if not source_lang:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid source language code: {request.source_language}"
        )
    
    target_lang = session.exec(select(Language).where(Language.code == target_lang_code)).first()
    if not target_lang:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid target language code: {request.target_language}"
        )
    
    if source_lang_code == target_lang_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Source and target languages must be different"
        )
    
    # Preserve original case but ensure first letter is capitalized
    concept_text = request.concept.strip()
    concept_text_capitalized = ensure_capitalized(concept_text)
    
    # For database lookup, use case-insensitive comparison
    concept_text_lower = concept_text.lower().strip()
    
    # Step 1: Retrieve all cards with same text (translation) in all languages (case-insensitive)
    existing_cards = session.exec(
        select(Card).where(func.lower(Card.translation) == concept_text_lower)
    ).all()
    
    logger.info(f"Step 1: Found {len(existing_cards)} existing cards with translation: '{concept_text_lower}'")
    
    # Get all languages from Language table
    all_languages = session.exec(select(Language)).all()
    all_language_codes = {lang.code for lang in all_languages}
    logger.info(f"Total languages in system: {len(all_language_codes)} - {sorted(all_language_codes)}")
    
    # Determine which languages we already have cards for
    existing_language_codes = {card.language_code for card in existing_cards}
    if existing_language_codes:
        logger.info(f"Languages with existing cards: {sorted(existing_language_codes)}")
    else:
        logger.info("No existing cards found for this translation")
    
    # Step 2: If no cards present, write a new Concept record
    if not existing_cards:
        logger.info("Step 2: No existing cards found, creating new Concept")
        
        # Create or get Topic if provided
        topic = None
        topic_id = None
        if request.topic:
            topic_name_lower = request.topic.lower().strip()
            existing_topic = session.exec(
                select(Topic).where(Topic.name.ilike(topic_name_lower))
            ).first()
            
            if existing_topic:
                topic = existing_topic
                topic_id = existing_topic.id
                logger.info(f"Using existing topic: '{topic.name}' (id: {topic_id})")
            else:
                topic = Topic(name=topic_name_lower)
                session.add(topic)
                session.commit()
                session.refresh(topic)
                topic_id = topic.id
                logger.info(f"Created new topic: '{topic.name}' (id: {topic_id})")
        
        # Create new Concept
        concept = Concept(topic_id=topic_id)
        session.add(concept)
        session.commit()
        session.refresh(concept)
        concept_id = concept.id
        logger.info(f"Created new Concept (id: {concept_id})")
    else:
        # Use concept_id from existing cards (they should all have the same concept_id)
        concept_id = existing_cards[0].concept_id
        concept = session.get(Concept, concept_id)
        topic = concept.topic if concept and concept.topic_id else None
        logger.info(f"Step 2: Reusing existing Concept (id: {concept_id})")
    
    # Step 3: Retrieve API call for languages that weren't in Card, if any
    # Missing languages are any languages in Language table that are not represented for the card translation
    missing_language_codes = all_language_codes - existing_language_codes
    
    logger.info(f"Step 3: Missing languages that need translation: {len(missing_language_codes)} - {sorted(missing_language_codes)}")
    
    translations = {}
    failed_translations = []
    
    if missing_language_codes:
        logger.info(f"Step 3: Calling translation API for {len(missing_language_codes)} language(s)")
        
        # Use the reusable translation function (pass original text to preserve case)
        translation_result = translation_service.translate_to_multiple_languages(
            text=concept_text,
            source_language=source_lang_code,
            target_languages=list(missing_language_codes),
            skip_source_language=True
        )
        
        translations = translation_result['translations']
        failed_translations = translation_result['failed_languages']
        
        logger.info(f"Step 3 summary: successful: {len(translations)}, failed: {len(failed_translations)}")
    else:
        logger.info("Step 3: No missing languages - all translations already exist in database")
    
    # Step 4: Write the translations that didn't exist in Card, using the correct concept_id
    logger.info(f"Step 4: Creating cards for missing languages using concept_id: {concept_id}")
    
    new_cards = []
    # Only create cards for languages we successfully translated (or source language)
    languages_to_create = missing_language_codes - set(failed_translations)
    
    logger.info(f"Languages to create cards for: {len(languages_to_create)} - {sorted(languages_to_create)}")
    
    for lang_code in languages_to_create:
        if lang_code == source_lang_code:
            # For source language, use the original concept text (capitalized)
            translation_text = concept_text_capitalized
            logger.info(f"Creating card for source language '{lang_code}' with original text: '{translation_text}'")
        else:
            # For other languages, use the translated text (already capitalized by translation service)
            translation_text = translations.get(lang_code)
            if not translation_text:
                # Skip if translation is missing (shouldn't happen, but safe guard)
                logger.warning(f"No translation available for '{lang_code}', skipping card creation")
                continue
            logger.info(f"Creating card for language '{lang_code}' with translation: '{translation_text}'")
        
        new_card = Card(
            concept_id=concept_id,
            language_code=lang_code,
            translation=translation_text,
            description=""
        )
        session.add(new_card)
        new_cards.append(new_card)
    
    if new_cards:
        session.commit()
        for card in new_cards:
            session.refresh(card)
        logger.info(f"Step 4: Successfully created {len(new_cards)} new card(s) for languages: {sorted([c.language_code for c in new_cards])}")
    else:
        logger.info("Step 4: No new cards to create")
    
    # Log summary of failed translations
    if failed_translations:
        logger.warning(f"Summary: Failed to translate for {len(failed_translations)} language(s): {sorted(failed_translations)}")
    
    # Step 5: Generate descriptions ONLY for new cards that were just created
    logger.info("Step 5: Generating descriptions for new cards only")
    all_cards_list = existing_cards + new_cards
    
    # Only generate descriptions for new cards (not existing ones)
    if new_cards:
        languages_needing_descriptions = {card.language_code for card in new_cards}
        logger.info(f"Step 5: Generating descriptions for {len(new_cards)} new card(s) in {len(languages_needing_descriptions)} language(s)")
        
        try:
            # Use the user's input phrase (concept_text) for description generation
            # This is the original phrase in whatever language the user entered
            description_result = description_service.generate_descriptions_for_multiple_languages(
                text=concept_text,  # Use user's input phrase
                target_languages=list(languages_needing_descriptions),
                source_language=source_lang_code,
                prefer_english=False  # During generation, use the input phrase directly
            )
            
            generated_descriptions = description_result['descriptions']
            failed_descriptions = description_result['failed_languages']
            
            logger.info(f"Step 5 summary: successful: {len(generated_descriptions)}, failed: {len(failed_descriptions)}")
            
            # Update new cards with generated descriptions
            cards_updated = 0
            for card in new_cards:
                lang_code = card.language_code
                if lang_code in generated_descriptions:
                    description_text = generated_descriptions[lang_code].strip()
                    if description_text:  # Only update if description is not empty
                        card.description = description_text
                        session.add(card)
                        cards_updated += 1
                        logger.info(f"Updated description for new card {card.id} (language: {lang_code}): '{card.description[:50]}...'")
                    else:
                        logger.warning(f"Generated description is empty for new card {card.id} (language: {lang_code})")
                else:
                    logger.warning(f"No description generated for new card {card.id} (language: {lang_code})")
            
            # Commit description updates
            if cards_updated > 0:
                session.commit()
                # Refresh all new cards to get updated descriptions
                for card in new_cards:
                    session.refresh(card)
                logger.info(f"Step 5: Successfully updated {cards_updated} new card(s) with descriptions")
            else:
                logger.warning("Step 5: No descriptions were generated for any new cards")
            
            if failed_descriptions:
                logger.warning(f"Step 5: Failed to generate descriptions for {len(failed_descriptions)} language(s): {sorted(failed_descriptions)}")
        except Exception as e:
            # Don't fail the entire flashcard creation if description generation fails
            logger.error(f"Step 5: Description generation failed completely: {str(e)}. Continuing without descriptions.")
            import traceback
            logger.error(traceback.format_exc())
    else:
        logger.info("Step 5: No new cards to generate descriptions for")
    source_card = next((card for card in all_cards_list if card.language_code == source_lang_code), None)
    target_card = next((card for card in all_cards_list if card.language_code == target_lang_code), None)
    
    if not source_card or not target_card:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve or create source/target cards"
        )
    
    # Determine message
    if not existing_cards:
        if failed_translations:
            message = f"Flashcard generated successfully (failed to translate for {len(failed_translations)} language(s))"
        else:
            message = "Flashcard generated successfully"
    elif new_cards:
        if failed_translations:
            message = f"Flashcard generated successfully (reused existing concept, added {len(new_cards)} new card(s), failed {len(failed_translations)} translation(s))"
        else:
            message = f"Flashcard generated successfully (reused existing concept, added {len(new_cards)} new card(s))"
    else:
        message = "Flashcards already exist"
    
    # Build response with all cards (ensure first letter is capitalized for display)
    all_cards_response = [
        CardResponse(
            id=card.id,
            concept_id=card.concept_id,
            language_code=card.language_code,
            translation=ensure_capitalized(card.translation),
            description=card.description,
            ipa=card.ipa,
            audio_path=card.audio_path,
            gender=card.gender,
            notes=card.notes
        )
        for card in all_cards_list
    ]
    
    # Build response
    response = GenerateFlashcardResponse(
        concept=ConceptResponse(
            id=concept.id,
            image_path_1=concept.image_path_1,
            image_path_2=concept.image_path_2,
            image_path_3=concept.image_path_3,
            image_path_4=concept.image_path_4,
            topic_id=concept.topic_id
        ),
        topic=TopicResponse(
            id=topic.id,
            name=topic.name,
            created_at=topic.created_at.isoformat()
        ) if topic else None,
        source_card=CardResponse(
            id=source_card.id,
            concept_id=source_card.concept_id,
            language_code=source_card.language_code,
            translation=ensure_capitalized(source_card.translation),
            description=source_card.description,
            ipa=source_card.ipa,
            audio_path=source_card.audio_path,
            gender=source_card.gender,
            notes=source_card.notes
        ),
        target_card=CardResponse(
            id=target_card.id,
            concept_id=target_card.concept_id,
            language_code=target_card.language_code,
            translation=ensure_capitalized(target_card.translation),
            description=target_card.description,
            ipa=target_card.ipa,
            audio_path=target_card.audio_path,
            gender=target_card.gender,
            notes=target_card.notes
        ),
        all_cards=all_cards_response,
        message=message
    )
    
    return response


@router.get("/vocabulary", response_model=VocabularyResponse)
async def get_vocabulary(
    user_id: int,
    page: int = 1,
    page_size: int = 20,
    session: Session = Depends(get_session)
):
    """
    Get cards for a user's source and target languages, paired by concept_id.
    Returns paginated vocabulary items that match the user's native and learning languages.
    
    Args:
        user_id: The user ID
        page: Page number (1-indexed, default: 1)
        page_size: Number of items per page (default: 20)
    """
    # Validate pagination parameters
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
    
    # Get user
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Get all cards for user's native and learning languages
    language_codes = [user.lang_native]
    if user.lang_learning:
        language_codes.append(user.lang_learning)
    
    # Get all cards for these languages
    all_cards = session.exec(
        select(Card).where(Card.language_code.in_(language_codes))
    ).all()
    
    # Group cards by concept_id
    concept_cards_map = {}
    for card in all_cards:
        if card.concept_id not in concept_cards_map:
            concept_cards_map[card.concept_id] = {}
        concept_cards_map[card.concept_id][card.language_code] = card
    
    # Get all concept_ids and sort by target language translation (alphabetically)
    concept_sort_keys = []
    for concept_id, lang_cards in concept_cards_map.items():
        # Get target card for sorting (prefer target language, fallback to source)
        target_card = lang_cards.get(user.lang_learning) if user.lang_learning else None
        source_card = lang_cards.get(user.lang_native)
        
        # Use target language translation for sorting, fallback to source if no target
        sort_text = ""
        if target_card:
            sort_text = target_card.translation.lower().strip()
        elif source_card:
            sort_text = source_card.translation.lower().strip()
        
        # Only include concepts that have at least one card
        if sort_text:
            concept_sort_keys.append((sort_text, concept_id))
    
    # Sort alphabetically by target language translation (case-insensitive)
    concept_sort_keys.sort(key=lambda x: x[0])
    all_concept_ids = [concept_id for _, concept_id in concept_sort_keys]
    total = len(all_concept_ids)
    
    # Calculate pagination
    offset = (page - 1) * page_size
    paginated_concept_ids = all_concept_ids[offset:offset + page_size]
    
    # If no concept_ids in this page, return empty result
    if not paginated_concept_ids:
        return VocabularyResponse(
            items=[],
            total=total,
            page=page,
            page_size=page_size,
            has_next=False,
            has_previous=page > 1
        )
    
    # Build paired vocabulary items (maintain alphabetical order)
    paired_items = []
    for concept_id in paginated_concept_ids:
        lang_cards = concept_cards_map.get(concept_id, {})
        source_card = lang_cards.get(user.lang_native)
        target_card = lang_cards.get(user.lang_learning) if user.lang_learning else None
        
        # Only include items that have at least one card
        if source_card or target_card:
            paired_items.append(
                PairedVocabularyItem(
                    concept_id=concept_id,
                    source_card=CardResponse(
                        id=source_card.id,
                        concept_id=source_card.concept_id,
                        language_code=source_card.language_code,
                        translation=ensure_capitalized(source_card.translation),
                        description=source_card.description,
                        ipa=source_card.ipa,
                        audio_path=source_card.audio_path,
                        gender=source_card.gender,
                        notes=source_card.notes
                    ) if source_card else None,
                    target_card=CardResponse(
                        id=target_card.id,
                        concept_id=target_card.concept_id,
                        language_code=target_card.language_code,
                        translation=ensure_capitalized(target_card.translation),
                        description=target_card.description,
                        ipa=target_card.ipa,
                        audio_path=target_card.audio_path,
                        gender=target_card.gender,
                        notes=target_card.notes
                    ) if target_card else None,
                )
            )
    
    # Calculate pagination metadata
    has_next = offset + page_size < total
    has_previous = page > 1
    
    return VocabularyResponse(
        items=paired_items,
        total=total,
        page=page,
        page_size=page_size,
        has_next=has_next,
        has_previous=has_previous
    )


@router.put("/cards/{card_id}", response_model=CardResponse)
async def update_card(
    card_id: int,
    request: UpdateCardRequest,
    session: Session = Depends(get_session)
):
    """
    Update a card's translation and description.
    """
    # Get the card
    card = session.get(Card, card_id)
    if not card:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Card not found"
        )
    
    # Update the card
    if request.translation is not None:
        card.translation = ensure_capitalized(request.translation.strip())
    if request.description is not None:
        card.description = request.description.strip()
    
    session.add(card)
    session.commit()
    session.refresh(card)
    
    return CardResponse(
        id=card.id,
        concept_id=card.concept_id,
        language_code=card.language_code,
        translation=ensure_capitalized(card.translation),
        description=card.description,
        ipa=card.ipa,
        audio_path=card.audio_path,
        gender=card.gender,
        notes=card.notes
    )


@router.delete("/concepts/{concept_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete a concept and all its associated cards and user_cards.
    This will cascade delete:
    - All UserCards that reference cards for this concept
    - All Cards for this concept
    - The Concept itself
    """
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Concept not found"
        )
    
    # Get all cards for this concept
    cards = session.exec(
        select(Card).where(Card.concept_id == concept_id)
    ).all()
    
    # Delete all UserCards that reference these cards
    card_ids = [card.id for card in cards]
    if card_ids:
        user_cards = session.exec(
            select(UserCard).where(UserCard.card_id.in_(card_ids))
        ).all()
        for user_card in user_cards:
            session.delete(user_card)
    
    # Delete all cards
    for card in cards:
        session.delete(card)
    
    # Delete the concept
    session.delete(concept)
    
    session.commit()
    
    return None

