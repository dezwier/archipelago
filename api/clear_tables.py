"""
Script to clear contents from card and concept tables.
"""
import sys
from sqlmodel import Session, text
from app.core.database import engine
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


def clear_tables():
    """Clear all data from card and concept tables."""
    with Session(engine) as session:
        try:
            # Delete all cards first (due to foreign key constraint)
            logger.info("Deleting all cards...")
            result = session.exec(text("DELETE FROM card"))
            cards_deleted = result.rowcount if hasattr(result, 'rowcount') else 0
            logger.info(f"Deleted cards (approximate count)")
            
            # Delete all concepts
            logger.info("Deleting all concepts...")
            result = session.exec(text("DELETE FROM concept"))
            concepts_deleted = result.rowcount if hasattr(result, 'rowcount') else 0
            logger.info(f"Deleted concepts (approximate count)")
            
            session.commit()
            logger.info("Successfully cleared card and concept tables")
            
        except Exception as e:
            session.rollback()
            logger.error("Error clearing tables: %s", e, exc_info=True)
            raise


if __name__ == "__main__":
    logger.info("Starting table clearing...")
    try:
        clear_tables()
        logger.info("Successfully completed!")
    except Exception as e:
        logger.error("Error during table clearing: %s", e, exc_info=True)
        sys.exit(1)

