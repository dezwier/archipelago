"""
Script to create English lemmas for public concepts that don't have one yet.

Only considers public concepts (concepts without user_id) that don't have an English lemma.
Creates a lemma with the same term, language 'en', and description from the concept.
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
from app.models.models import Concept, Lemma, Language
from app.api.v1.endpoints.utils import normalize_lemma_term

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
    Retrieve public concepts (user_id is None) that don't have an English lemma yet.
    
    Returns:
        List of concepts that need English lemmas
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
        
        # Get all English lemmas
        english_lemmas = session.exec(
            select(Lemma).where(Lemma.language_code == 'en')
        ).all()
        
        # Create a map of concept_id -> English lemma
        concept_to_lemma = {lemma.concept_id: lemma for lemma in english_lemmas}
        
        # Find concepts without English lemmas
        concepts_needing_lemmas = [
            concept for concept in public_concepts
            if concept.id not in concept_to_lemma
        ]
        
        logger.info("Found %d public concepts without English lemmas", len(concepts_needing_lemmas))
        
        return concepts_needing_lemmas


def create_english_cards(concepts: list[Concept]) -> tuple[int, int]:
    """
    Create English lemmas for the given concepts.
    
    Args:
        concepts: List of concepts that need English lemmas
    
    Returns:
        Tuple of (lemmas_created, lemmas_failed)
    """
    lemmas_created = 0
    lemmas_failed = 0
    
    with Session(engine) as session:
        # Verify English language exists
        if not verify_english_language_exists(session):
            raise Exception("Language code 'en' does not exist in the languages table")
        
        for concept in concepts:
            if not concept.term or concept.term.strip() == "":
                logger.warning("Skipping concept %d: missing term", concept.id)
                lemmas_failed += 1
                continue
            
            try:
                # Check if lemma already exists (might have been created concurrently)
                existing_lemma = session.exec(
                    select(Lemma).where(
                        Lemma.concept_id == concept.id,
                        Lemma.language_code == 'en'
                    )
                ).first()
                
                if existing_lemma:
                    logger.info("Lemma already exists for concept %d, skipping", concept.id)
                    continue
                
                # Create new lemma with same term, description, and part_of_speech info
                # Normalize the term (trim dots and whitespace)
                normalized_term = normalize_lemma_term(concept.term) if concept.term else None
                lemma = Lemma(
                    concept_id=concept.id,
                    language_code='en',
                    term=normalized_term,
                    description=concept.description,
                    # Note: Lemma model doesn't have part_of_speech field, it's on Concept
                )
                session.add(lemma)
                session.commit()
                lemmas_created += 1
                logger.info("Created English lemma for concept %d (term: '%s')", concept.id, concept.term)
                
                if lemmas_created % 100 == 0:
                    logger.info("Created %d lemmas so far...", lemmas_created)
                    
            except IntegrityError as e:
                session.rollback()
                logger.error("Database integrity error for concept %d (%s): %s", 
                           concept.id, concept.term, e)
                lemmas_failed += 1
                continue
            except Exception as e:
                session.rollback()
                logger.error("Error processing concept %d (%s): %s", concept.id, concept.term, e)
                lemmas_failed += 1
                continue
    
    return lemmas_created, lemmas_failed


def main():
    """Main function to create English lemmas for public concepts."""
    logger.info("Starting English lemma creation for public concepts...")
    
    try:
        # Get public concepts without English lemmas
        concepts_needing_lemmas = get_public_concepts_without_english_cards()
        
        if len(concepts_needing_lemmas) == 0:
            logger.info("No public concepts need English lemmas. Exiting.")
            return
        
        logger.info("Processing %d public concepts without English lemmas...", 
                   len(concepts_needing_lemmas))
        
        # Create lemmas
        lemmas_created, lemmas_failed = create_english_cards(concepts_needing_lemmas)
        
        logger.info("Successfully completed!")
        logger.info("Lemmas created: %d", lemmas_created)
        logger.info("Lemmas failed: %d", lemmas_failed)
        
    except Exception as e:
        logger.error("Error during lemma creation: %s", e, exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
