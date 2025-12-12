"""
Script to find and fix duplicate cards.
Handles case sensitivity and whitespace issues.
"""
import sys
import logging
from sqlmodel import Session, select, func
from sqlalchemy import text
from app.core.database import engine
from app.models.models import Card

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def find_duplicates(session: Session, concept_id: int = None) -> list:
    """
    Find duplicate cards based on concept_id, language_code, and term (case-insensitive, trimmed).
    
    Args:
        session: Database session
        concept_id: Optional concept ID to filter by
    
    Returns:
        List of tuples (concept_id, language_code, term, count, card_ids)
    """
    if concept_id:
        query = text("""
            SELECT concept_id, language_code, LOWER(TRIM(term)) as normalized_term, 
                   COUNT(*) as count, array_agg(id ORDER BY id) as card_ids
            FROM card
            WHERE concept_id = :concept_id
            GROUP BY concept_id, language_code, LOWER(TRIM(term))
            HAVING COUNT(*) > 1
            ORDER BY concept_id, language_code, normalized_term
        """)
        result = session.execute(query, {"concept_id": concept_id})
    else:
        query = text("""
            SELECT concept_id, language_code, LOWER(TRIM(term)) as normalized_term, 
                   COUNT(*) as count, array_agg(id ORDER BY id) as card_ids
            FROM card
            GROUP BY concept_id, language_code, LOWER(TRIM(term))
            HAVING COUNT(*) > 1
            ORDER BY concept_id, language_code, normalized_term
        """)
        result = session.execute(query)
    
    duplicates = []
    for row in result:
        duplicates.append({
            'concept_id': row[0],
            'language_code': row[1],
            'normalized_term': row[2],
            'count': row[3],
            'card_ids': row[4]
        })
    
    return duplicates


def fix_duplicates(session: Session, concept_id: int = None) -> tuple[int, int]:
    """
    Fix duplicate cards by:
    1. Normalizing terms (trim whitespace, lowercase for comparison)
    2. Keeping the card with the lowest ID
    3. Deleting the rest
    
    Args:
        session: Database session
        concept_id: Optional concept ID to filter by
    
    Returns:
        Tuple of (duplicates_found, duplicates_removed)
    """
    duplicates = find_duplicates(session, concept_id)
    
    if not duplicates:
        logger.info("No duplicates found")
        return 0, 0
    
    logger.info(f"Found {len(duplicates)} duplicate groups")
    
    total_removed = 0
    
    for dup in duplicates:
        card_ids = dup['card_ids']
        keep_id = card_ids[0]  # Keep the one with the lowest ID
        remove_ids = card_ids[1:]  # Remove the rest
        
        logger.info(f"Concept {dup['concept_id']}, language {dup['language_code']}, term '{dup['normalized_term']}': "
                   f"Keeping card {keep_id}, removing {len(remove_ids)} duplicates (IDs: {remove_ids})")
        
        # Delete the duplicate cards
        for card_id in remove_ids:
            card = session.get(Card, card_id)
            if card:
                session.delete(card)
                total_removed += 1
    
    session.commit()
    logger.info(f"Removed {total_removed} duplicate cards")
    
    return len(duplicates), total_removed


def normalize_terms(session: Session) -> int:
    """
    Normalize all card terms by trimming whitespace.
    This ensures consistency for the unique constraint.
    
    Args:
        session: Database session
    
    Returns:
        Number of cards updated
    """
    # Update all cards to have trimmed terms
    result = session.execute(text("""
        UPDATE card
        SET term = TRIM(term)
        WHERE term != TRIM(term)
    """))
    
    updated = result.rowcount
    session.commit()
    
    if updated > 0:
        logger.info(f"Normalized {updated} card terms (trimmed whitespace)")
    
    return updated


def main():
    """Main function to fix duplicate cards."""
    logger.info("Starting duplicate card fix...")
    
    with Session(engine) as session:
        # First, normalize all terms (trim whitespace)
        normalize_terms(session)
        
        # Check for specific concept if provided
        concept_id = 44205
        
        # Find duplicates for this concept
        logger.info(f"Checking for duplicates for concept {concept_id}...")
        duplicates = find_duplicates(session, concept_id)
        
        if duplicates:
            logger.info(f"Found {len(duplicates)} duplicate groups for concept {concept_id}:")
            for dup in duplicates:
                logger.info(f"  - Concept {dup['concept_id']}, language {dup['language_code']}, "
                           f"term '{dup['normalized_term']}': {dup['count']} cards (IDs: {dup['card_ids']})")
        
        # Fix all duplicates
        logger.info("Fixing all duplicates...")
        groups_found, cards_removed = fix_duplicates(session)
        
        logger.info(f"Successfully completed!")
        logger.info(f"Duplicate groups found: {groups_found}")
        logger.info(f"Duplicate cards removed: {cards_removed}")
        
        # Verify no duplicates remain
        remaining = find_duplicates(session)
        if remaining:
            logger.warning(f"WARNING: {len(remaining)} duplicate groups still remain!")
            for dup in remaining:
                logger.warning(f"  - Concept {dup['concept_id']}, language {dup['language_code']}, "
                             f"term '{dup['normalized_term']}': {dup['count']} cards")
        else:
            logger.info("No duplicates remain - all fixed!")


if __name__ == "__main__":
    main()



