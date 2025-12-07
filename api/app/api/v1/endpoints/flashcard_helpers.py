"""
Helper functions for flashcard operations.
"""
from sqlmodel import Session, select
from app.models.models import Card
from app.services.translation_service import translation_service
from app.services.description_service import description_service
from typing import Dict, Optional, List
import logging

logger = logging.getLogger(__name__)


def ensure_capitalized(text: str) -> str:
    """
    Ensure the first letter is capitalized while preserving the rest of the case.
    If text is empty, return as is.
    """
    if not text:
        return text
    return text[0].upper() + text[1:] if len(text) > 0 else text


def generate_descriptions_for_cards(
    cards: List[Card],
    concept_text: str,
    source_lang_code: str,
    session: Session,
    task_id: Optional[str] = None,
    cancellation_flag: Optional[Dict] = None
) -> Dict:
    """
    Reusable function to generate descriptions for a list of cards.
    
    Strategy:
    1. Check if English description exists, if not generate with Gemini
    2. Translate English description to other languages
    
    Args:
        cards: List of Card objects that need descriptions
        concept_text: The original phrase/text to generate description for
        source_lang_code: Source language code
        session: Database session
        task_id: Optional task ID for progress tracking
        cancellation_flag: Optional dict with 'cancelled' key to check for cancellation
    
    Returns:
        Dict with 'cards_updated', 'failed_languages', etc.
    """
    if not cards:
        return {'cards_updated': 0, 'failed_languages': []}
    
    # Check for cancellation
    if cancellation_flag and cancellation_flag.get('cancelled', False):
        logger.info(f"Task {task_id}: Cancellation requested, stopping description generation")
        return {'cards_updated': 0, 'failed_languages': [], 'cancelled': True}
    
    languages_needing_descriptions = {card.language_code for card in cards}
    logger.info(f"Generating descriptions for {len(cards)} card(s) in {len(languages_needing_descriptions)} language(s)")
    
    # Step 1: Check if English description exists, if not generate with Gemini
    english_description = None
    english_card = next((card for card in cards if card.language_code == 'en'), None)
    
    if english_card and english_card.description and english_card.description.strip():
        # English description already exists, use it
        english_description = english_card.description.strip()
        logger.info(f"Using existing English description for concept: '{concept_text}'")
    else:
        # Generate English description using Gemini
        logger.info(f"Generating English description using Gemini for concept: '{concept_text}'")
        try:
            english_description = description_service.generate_description(
                text=concept_text,
                target_language='en',
                source_language=source_lang_code
            )
            if english_description:
                english_description = english_description.strip()
                if english_card:
                    english_card.description = english_description
                    session.add(english_card)
                    logger.info(f"Generated and saved English description: '{english_description[:100]}...'")
                else:
                    logger.info(f"Generated English description for translation: '{english_description[:100]}...'")
            else:
                logger.warning("English description generation returned empty")
        except Exception as e:
            logger.error(f"Failed to generate English description: {str(e)}")
            english_description = None
    
    # Check for cancellation again
    if cancellation_flag and cancellation_flag.get('cancelled', False):
        logger.info(f"Task {task_id}: Cancellation requested after English generation")
        return {'cards_updated': 0, 'failed_languages': [], 'cancelled': True}
    
    # Step 2: Translate English description to other languages
    if not english_description:
        logger.error("Could not generate English description, skipping translation step")
        return {'cards_updated': 0, 'failed_languages': list(languages_needing_descriptions)}
    
    # Get languages that need descriptions (excluding English, which we already have)
    languages_to_translate = languages_needing_descriptions - {'en'}
    
    translated_descriptions = {}
    failed_translations = []
    
    if languages_to_translate:
        logger.info(f"Translating English description to {len(languages_to_translate)} language(s): {sorted(languages_to_translate)}")
        
        try:
            # Use translation service to translate the English description
            translation_result = translation_service.translate_to_multiple_languages(
                text=english_description,
                source_language='en',
                target_languages=list(languages_to_translate),
                skip_source_language=True
            )
            
            translated_descriptions = translation_result['translations']
            failed_translations = translation_result['failed_languages']
            
            logger.info(f"Translated {len(translated_descriptions)} descriptions, failed: {len(failed_translations)}")
        except Exception as e:
            logger.error(f"Translation failed: {str(e)}")
            failed_translations = list(languages_to_translate)
    
    # Check for cancellation before updating cards
    if cancellation_flag and cancellation_flag.get('cancelled', False):
        logger.info(f"Task {task_id}: Cancellation requested before updating cards")
        return {'cards_updated': 0, 'failed_languages': [], 'cancelled': True}
    
    # Update cards with descriptions
    cards_updated = 0
    for card in cards:
        lang_code = card.language_code
        if lang_code == 'en' and english_card and english_card.description:
            # English card already updated above
            cards_updated += 1
        elif lang_code in translated_descriptions:
            description_text = translated_descriptions[lang_code].strip()
            if description_text:
                card.description = description_text
                session.add(card)
                cards_updated += 1
                logger.info(f"Updated description for card {card.id} (language: {lang_code})")
    
    return {
        'cards_updated': cards_updated,
        'failed_languages': failed_translations,
        'english_description': english_description
    }

