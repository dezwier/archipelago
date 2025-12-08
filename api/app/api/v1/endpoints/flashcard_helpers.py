"""
Helper functions for flashcard operations.
"""
from sqlmodel import Session, select
from app.models.models import Concept, Image
from app.services.image_service import image_service
from typing import Dict
from datetime import datetime
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


def retrieve_images_for_concept(
    concept: Concept,
    concept_text: str,
    session: Session,
    force_refresh: bool = False
) -> Dict:
    """
    Retrieve images for a concept and store them in the images table.
    
    Args:
        concept: Concept object to update with images
        concept_text: The concept text to search for (typically English translation)
        session: Database session
        force_refresh: If True, delete existing images and retrieve new ones
    
    Returns:
        Dict with 'images_retrieved' (int) and 'success' (bool)
    """
    if not concept_text or not concept_text.strip():
        logger.warning(f"No concept text provided for image retrieval for concept {concept.id}")
        return {'images_retrieved': 0, 'success': False, 'error': 'No concept text'}
    
    try:
        logger.info(f"Retrieving images for concept {concept.id} with query: '{concept_text}'")
        
        # Get current images count
        existing_images = session.exec(
            select(Image).where(Image.concept_id == concept.id)
        ).all()
        current_count = len(existing_images)
        
        # Clear existing images if forcing refresh
        if force_refresh:
            for img in existing_images:
                session.delete(img)
            session.commit()
            current_count = 0
        
        # Determine how many images we need (max 4 total)
        max_images = 4
        images_needed = max_images - current_count
        
        if images_needed <= 0:
            logger.info(f"Concept {concept.id} already has {current_count} images, no slots available")
            return {'images_retrieved': 0, 'success': True, 'skipped': True, 'message': 'All image slots are full'}
        
        # Get images from image service (only as many as we need)
        image_urls = image_service.get_images_for_concept(
            concept_text=concept_text.strip(),
            num_images=images_needed
        )
        
        if not image_urls:
            logger.warning(f"No images found for concept {concept.id} with query: '{concept_text}'")
            return {'images_retrieved': 0, 'success': False, 'error': 'No images found'}
        
        # Check if we need to set a primary image
        has_primary = any(img.is_primary for img in existing_images)
        is_first_new = not has_primary and current_count == 0
        
        # Create Image records for new URLs
        for idx, url in enumerate(image_urls):
            image = Image(
                concept_id=concept.id,
                url=url,
                image_type='illustration',
                is_primary=is_first_new and idx == 0,  # First image is primary if no primary exists
                source='google',
                created_at=datetime.utcnow()
            )
            session.add(image)
        
        session.commit()
        
        logger.info(f"Retrieved and stored {len(image_urls)} image(s) for concept {concept.id}")
        
        return {
            'images_retrieved': len(image_urls),
            'success': True
        }
        
    except Exception as e:
        logger.error(f"Failed to retrieve images for concept {concept.id}: {str(e)}")
        return {
            'images_retrieved': 0,
            'success': False,
            'error': str(e)
        }

