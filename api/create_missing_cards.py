"""
Script to create/update English Card records using LLM-generated lemmas.

Handles two cases:
1. Concepts with no English card - generates English lemma using LLM
2. English cards with missing term, description, or IPA - regenerates using LLM

For each case, uses the LLM to generate proper English lemma with IPA pronunciation
and description.
"""
import sys
import logging
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from app.core.database import engine
from app.models.models import Concept, Card, Language
from app.api.v1.endpoints.llm_helpers import call_gemini_api
from app.api.v1.endpoints.prompt_helpers import (
    generate_lemma_system_instruction,
    generate_lemma_user_prompt
)

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def get_concepts_needing_english_cards() -> tuple[list[Concept], list[Card]]:
    """
    Retrieve concepts and cards that need English lemma generation.
    
    Returns:
        Tuple of (concepts_without_cards, cards_with_missing_fields)
        - concepts_without_cards: Concepts that have a term but no English card
        - cards_with_missing_fields: English cards missing term, description, or IPA
    """
    with Session(engine) as session:
        # Get all concepts with a term (description is optional)
        all_concepts = session.exec(
            select(Concept).where(
                Concept.term.isnot(None),
                Concept.term != ""
            )
        ).all()
        
        concepts_without_cards = []
        cards_with_missing_fields = []
        
        # Get all English cards
        english_cards = session.exec(
            select(Card).where(Card.language_code == 'en')
        ).all()
        
        # Create a map of concept_id -> English card
        concept_to_card = {card.concept_id: card for card in english_cards}
        
        for concept in all_concepts:
            english_card = concept_to_card.get(concept.id)
            
            if not english_card:
                # Concept has no English card
                concepts_without_cards.append(concept)
            else:
                # Check if card is missing term, description, or IPA
                if (not english_card.term or english_card.term.strip() == "" or
                    not english_card.description or english_card.description.strip() == "" or
                    not english_card.ipa or english_card.ipa.strip() == ""):
                    cards_with_missing_fields.append(english_card)
        
        logger.info("Found %d concepts without English cards", len(concepts_without_cards))
        logger.info("Found %d English cards with missing term/description/IPA", len(cards_with_missing_fields))
        
        return list(concepts_without_cards), list(cards_with_missing_fields)


def verify_english_language_exists(session: Session) -> bool:
    """
    Verify that the 'en' language code exists in the languages table.
    
    Args:
        session: Database session
        
    Returns:
        True if 'en' language exists, False otherwise
    """
    english_lang = session.get(Language, 'en')
    if not english_lang:
        logger.error("Language code 'en' does not exist in the languages table!")
        logger.error("Please ensure the 'en' language is inserted into the languages table.")
        return False
    logger.info("Verified that language code 'en' exists")
    return True


def generate_english_lemma_for_concept(concept: Concept) -> dict:
    """
    Generate English lemma for a concept using LLM.
    
    Args:
        concept: Concept to generate lemma for
        
    Returns:
        Dictionary with LLM-generated lemma data
    """
    # Generate system instruction and user prompt for English
    system_instruction = generate_lemma_system_instruction(
        term=concept.term,
        description=concept.description,
        part_of_speech=concept.part_of_speech
    )
    
    user_prompt = generate_lemma_user_prompt(target_language='en')
    
    logger.info("Generating English lemma for concept %d: term='%s'", concept.id, concept.term)
    
    try:
        llm_data, token_usage = call_gemini_api(
            prompt=user_prompt,
            system_instruction=system_instruction
        )
        
        logger.info("Generated lemma for concept %d. Tokens: %d, Cost: $%.6f", 
                   concept.id, token_usage.get('total_tokens', 0), token_usage.get('cost_usd', 0.0))
        
        # Validate required fields
        if not isinstance(llm_data, dict):
            raise ValueError("LLM output must be a JSON object")
        
        required_fields = ['term', 'description']
        for field in required_fields:
            if field not in llm_data or not llm_data[field]:
                raise ValueError(f"Missing or empty required field: {field}")
        
        return llm_data
        
    except Exception as e:
        logger.error("Failed to generate lemma for concept %d (%s): %s", concept.id, concept.term, e)
        raise


def create_or_update_english_cards(
    concepts_without_cards: list[Concept],
    cards_with_missing_fields: list[Card]
) -> tuple[int, int, int]:
    """
    Create or update English cards using LLM-generated lemmas.
    
    Args:
        concepts_without_cards: Concepts that need English cards created
        cards_with_missing_fields: English cards that need to be updated
        
    Returns:
        Tuple of (cards_created, cards_updated, cards_failed)
    """
    cards_created = 0
    cards_updated = 0
    cards_failed = 0
    
    with Session(engine) as session:
        # Verify English language exists
        if not verify_english_language_exists(session):
            raise Exception("Language code 'en' does not exist in the languages table")
        
        # Process concepts without cards
        for concept in concepts_without_cards:
            if not concept.term or concept.term.strip() == "":
                logger.warning("Skipping concept %d: missing term", concept.id)
                cards_failed += 1
                continue
            
            try:
                # Generate English lemma using LLM
                llm_data = generate_english_lemma_for_concept(concept)
                
                # Check if card already exists (might have been created concurrently)
                existing_card = session.exec(
                    select(Card).where(
                        Card.concept_id == concept.id,
                        Card.language_code == 'en'
                    )
                ).first()
                
                if existing_card:
                    # Update existing card
                    existing_card.term = llm_data.get('term')
                    existing_card.ipa = llm_data.get('ipa')
                    existing_card.description = llm_data.get('description')
                    existing_card.gender = llm_data.get('gender')
                    existing_card.article = llm_data.get('article')
                    existing_card.plural_form = llm_data.get('plural_form')
                    existing_card.verb_type = llm_data.get('verb_type')
                    existing_card.auxiliary_verb = llm_data.get('auxiliary_verb')
                    existing_card.formality_register = llm_data.get('register')
                    existing_card.status = 'active'
                    existing_card.source = 'llm'
                    session.add(existing_card)
                    session.commit()
                    cards_updated += 1
                    logger.info("Updated card for concept %d", concept.id)
                else:
                    # Create new card
                    card = Card(
                        concept_id=concept.id,
                        language_code='en',
                        term=llm_data.get('term'),
                        ipa=llm_data.get('ipa'),
                        description=llm_data.get('description'),
                        gender=llm_data.get('gender'),
                        article=llm_data.get('article'),
                        plural_form=llm_data.get('plural_form'),
                        verb_type=llm_data.get('verb_type'),
                        auxiliary_verb=llm_data.get('auxiliary_verb'),
                        formality_register=llm_data.get('register'),
                        status='active',
                        source='llm'
                    )
                    session.add(card)
                    session.commit()
                    cards_created += 1
                    logger.info("Created card for concept %d", concept.id)
                
                if (cards_created + cards_updated) % 10 == 0:
                    logger.info("Processed %d cards so far...", cards_created + cards_updated)
                    
            except IntegrityError as e:
                session.rollback()
                logger.error("Database integrity error for concept %d (%s): %s", 
                           concept.id, concept.term, e)
                cards_failed += 1
                continue
            except Exception as e:
                session.rollback()
                logger.error("Error processing concept %d (%s): %s", concept.id, concept.term, e)
                cards_failed += 1
                continue
        
        # Process cards with missing fields
        for card in cards_with_missing_fields:
            # Get the concept for this card
            concept = session.get(Concept, card.concept_id)
            if not concept:
                logger.warning("Skipping card %d: concept %d not found", card.id, card.concept_id)
                cards_failed += 1
                continue
            
            if not concept.term or concept.term.strip() == "":
                logger.warning("Skipping card %d: concept %d has no term", card.id, card.concept_id)
                cards_failed += 1
                continue
            
            try:
                # Generate English lemma using LLM
                llm_data = generate_english_lemma_for_concept(concept)
                
                # Update the card with LLM-generated data
                card.term = llm_data.get('term')
                card.ipa = llm_data.get('ipa')
                card.description = llm_data.get('description')
                card.gender = llm_data.get('gender')
                card.article = llm_data.get('article')
                card.plural_form = llm_data.get('plural_form')
                card.verb_type = llm_data.get('verb_type')
                card.auxiliary_verb = llm_data.get('auxiliary_verb')
                card.formality_register = llm_data.get('register')
                card.status = 'active'
                card.source = 'llm'
                session.add(card)
                session.commit()
                cards_updated += 1
                logger.info("Updated card %d for concept %d", card.id, concept.id)
                
                if (cards_created + cards_updated) % 10 == 0:
                    logger.info("Processed %d cards so far...", cards_created + cards_updated)
                    
            except IntegrityError as e:
                session.rollback()
                logger.error("Database integrity error for card %d (concept %d): %s", 
                           card.id, card.concept_id, e)
                cards_failed += 1
                continue
            except Exception as e:
                session.rollback()
                logger.error("Error processing card %d (concept %d): %s", 
                           card.id, card.concept_id, e)
                cards_failed += 1
                continue
    
    return cards_created, cards_updated, cards_failed


def main():
    """Main function to create/update English cards using LLM-generated lemmas."""
    logger.info("Starting English lemma generation for concepts and cards...")
    
    try:
        # Get concepts and cards that need English lemmas
        concepts_without_cards, cards_with_missing_fields = get_concepts_needing_english_cards()
        
        total_to_process = len(concepts_without_cards) + len(cards_with_missing_fields)
        
        if total_to_process == 0:
            logger.info("No concepts or cards need English lemma generation. Exiting.")
            return
        
        logger.info("Processing %d concepts without cards and %d cards with missing fields...", 
                   len(concepts_without_cards), len(cards_with_missing_fields))
        
        # Create/update cards using LLM
        cards_created, cards_updated, cards_failed = create_or_update_english_cards(
            concepts_without_cards,
            cards_with_missing_fields
        )
        
        logger.info("Successfully completed!")
        logger.info("Cards created: %d", cards_created)
        logger.info("Cards updated: %d", cards_updated)
        logger.info("Cards failed: %d", cards_failed)
        
    except Exception as e:
        logger.error("Error during card creation/update: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

