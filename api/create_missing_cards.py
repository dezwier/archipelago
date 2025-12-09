"""
Script to create Card records for concepts that don't have an English card.
For each concept with both term and description, creates a card with:
- language_code = 'en'
- term = concept.term
- description = concept.description

Only creates cards if a card with the same term and description doesn't already exist for language 'en'.
"""
import sys
import logging
from sqlmodel import Session, select
from app.core.database import engine
from app.models.models import Concept, Card, Language

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def get_concepts_with_term_and_description() -> list[Concept]:
    """
    Retrieve all concepts that have both term and description.
    
    Returns:
        List of Concept objects that have both term and description
    """
    with Session(engine) as session:
        # Get all concepts with both term and description
        concepts = session.exec(
            select(Concept).where(
                Concept.term.isnot(None),
                Concept.description.isnot(None),
                Concept.term != "",
                Concept.description != ""
            )
        ).all()
        
        logger.info("Found %d concepts with both term and description", len(concepts))
        return list(concepts)


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


def create_english_cards_for_concepts(concepts: list[Concept]) -> tuple[int, int]:
    """
    Create English cards for the given concepts.
    Skips if a card with the same term and description already exists for language 'en'.
    
    Args:
        concepts: List of Concept objects to create cards for
        
    Returns:
        Tuple of (cards_created, cards_skipped)
    """
    cards_created = 0
    cards_skipped = 0
    
    with Session(engine) as session:
        # Verify English language exists
        if not verify_english_language_exists(session):
            raise Exception("Language code 'en' does not exist in the languages table")
        
        for concept in concepts:
            # Double-check that both term and description exist
            if not concept.term or not concept.description:
                logger.warning("Skipping concept %d: missing term or description", concept.id)
                cards_skipped += 1
                continue
            
            # Check if a card with the same term and description already exists for language 'en'
            existing_card = session.exec(
                select(Card).where(
                    Card.language_code == 'en',
                    Card.term == concept.term,
                    Card.description == concept.description
                )
            ).first()
            
            if existing_card:
                logger.debug("Card with term '%s' and description already exists for language 'en', skipping concept %d", 
                           concept.term, concept.id)
                cards_skipped += 1
                continue
            
            # Create the card
            try:
                card = Card(
                    concept_id=concept.id,
                    language_code='en',
                    term=concept.term,
                    description=concept.description,
                    status='active',
                    source='script'
                )
                session.add(card)
                session.commit()
                cards_created += 1
                
                if cards_created % 100 == 0:
                    logger.info("Created %d cards so far...", cards_created)
                    
            except Exception as e:
                session.rollback()
                logger.error("Error creating card for concept %d (%s): %s", concept.id, concept.term, e)
                cards_skipped += 1
                continue
    
    return cards_created, cards_skipped


def main():
    """Main function to create English cards for concepts that don't have them."""
    logger.info("Starting card creation for concepts with term and description...")
    
    try:
        # Get concepts with both term and description
        concepts = get_concepts_with_term_and_description()
        
        if not concepts:
            logger.info("No concepts with both term and description found. Exiting.")
            return
        
        logger.info("Creating English cards for %d concepts...", len(concepts))
        
        # Create cards
        cards_created, cards_skipped = create_english_cards_for_concepts(concepts)
        
        logger.info("Successfully completed!")
        logger.info("Cards created: %d", cards_created)
        logger.info("Cards skipped: %d", cards_skipped)
        
    except Exception as e:
        logger.error("Error during card creation: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()

