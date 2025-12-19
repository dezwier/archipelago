"""
Concept service for business logic related to concept operations.
"""
import logging
from sqlmodel import Session, select
from typing import Optional

from app.models.models import Concept, Lemma, Card
from app.utils.assets_utils import get_assets_directory
from app.services.image_service import delete_concept_image_file

logger = logging.getLogger(__name__)


def delete_concept_and_associated_resources(
    session: Session,
    concept_id: int
) -> None:
    """
    Delete a concept and all its associated resources.
    
    This function deletes:
    - All Cards that reference lemmas for this concept
    - All Lemmas for this concept
    - The concept's image file (if it exists)
    - The Concept itself
    
    Args:
        session: Database session
        concept_id: The concept ID to delete
        
    Raises:
        ValueError: If concept not found
    """
    concept = session.get(Concept, concept_id)
    if not concept:
        raise ValueError(f"Concept with id {concept_id} not found")
    
    # Delete concept's image file if it exists
    if concept.image_url:
        delete_concept_image_file(concept.image_url)
    
    # Get all lemmas for this concept
    lemmas = session.exec(
        select(Lemma).where(Lemma.concept_id == concept_id)
    ).all()
    
    # Delete all Cards that reference these lemmas
    lemma_ids = [lemma.id for lemma in lemmas]
    if lemma_ids:
        cards = session.exec(
            select(Card).where(Card.lemma_id.in_(lemma_ids))  # type: ignore
        ).all()
        for card in cards:
            session.delete(card)
    
    # Delete all lemmas
    for lemma in lemmas:
        session.delete(lemma)
    
    # Delete the concept
    session.delete(concept)
    
    session.commit()
    logger.info(f"Deleted concept {concept_id} and all associated resources")

