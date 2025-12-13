"""
Script to create English cards for public concepts that don't have one yet.

Only considers public concepts (concepts without user_id) that don't have an English card.
Creates a card with the same term, language 'en', and description from the concept.
"""
import sys
import logging
from pathlib import Path
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError

# Add the api directory to Python path so we can import from app
script_dir = Path(__file__).parent
api_dir = script_dir.parent
sys.path.insert(0, str(api_dir))

from app.core.database import engine
from app.models.models import Concept, Card, Language

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


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


def get_public_concepts_without_english_cards() -> list[Concept]:
    """
    Retrieve public concepts (user_id is None) that don't have an English card yet.
    
    Returns:
        List of concepts that need English cards
    """
    with Session(engine) as session:
        # Get all public concepts (user_id is None)
        public_concepts = session.exec(
            select(Concept).where(
                Concept.user_id.is_(None),
                Concept.term.isnot(None),
                Concept.term != ""
            )
        ).all()
        
        # Get all English cards
        english_cards = session.exec(
            select(Card).where(Card.language_code == 'en')
        ).all()
        
        # Create a map of concept_id -> English card
        concept_to_card = {card.concept_id: card for card in english_cards}
        
        # Find concepts without English cards
        concepts_needing_cards = [
            concept for concept in public_concepts
            if concept.id not in concept_to_card
        ]
        
        logger.info("Found %d public concepts without English cards", len(concepts_needing_cards))
        
        return concepts_needing_cards


def create_english_cards(concepts: list[Concept]) -> tuple[int, int]:
    """
    Create English cards for the given concepts.
    
    Args:
        concepts: List of concepts that need English cards
        
    Returns:
        Tuple of (cards_created, cards_failed)
    """
    cards_created = 0
    cards_failed = 0
    
    with Session(engine) as session:
        # Verify English language exists
        if not verify_english_language_exists(session):
            raise Exception("Language code 'en' does not exist in the languages table")
        
        for concept in concepts:
            if not concept.term or concept.term.strip() == "":
                logger.warning("Skipping concept %d: missing term", concept.id)
                cards_failed += 1
                continue
            
            try:
                # Check if card already exists (might have been created concurrently)
                existing_card = session.exec(
                    select(Card).where(
                        Card.concept_id == concept.id,
                        Card.language_code == 'en'
                    )
                ).first()
                
                if existing_card:
                    logger.info("Card already exists for concept %d, skipping", concept.id)
                    continue
                
                # Create new card with same term, description, and part_of_speech info
                card = Card(
                    concept_id=concept.id,
                    language_code='en',
                    term=concept.term,
                    description=concept.description,
                    # Note: Card model doesn't have part_of_speech field, it's on Concept
                )
                session.add(card)
                session.commit()
                cards_created += 1
                logger.info("Created English card for concept %d (term: '%s')", concept.id, concept.term)
                
                if cards_created % 100 == 0:
                    logger.info("Created %d cards so far...", cards_created)
                    
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
    
    return cards_created, cards_failed


def main():
    """Main function to create English cards for public concepts."""
    logger.info("Starting English card creation for public concepts...")
    
    try:
        # Get public concepts without English cards
        concepts_needing_cards = get_public_concepts_without_english_cards()
        
        if len(concepts_needing_cards) == 0:
            logger.info("No public concepts need English cards. Exiting.")
            return
        
        logger.info("Processing %d public concepts without English cards...", 
                   len(concepts_needing_cards))
        
        # Create cards
        cards_created, cards_failed = create_english_cards(concepts_needing_cards)
        
        logger.info("Successfully completed!")
        logger.info("Cards created: %d", cards_created)
        logger.info("Cards failed: %d", cards_failed)
        
    except Exception as e:
        logger.error("Error during card creation: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
