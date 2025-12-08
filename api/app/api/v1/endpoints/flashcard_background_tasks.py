"""
Background tasks for flashcard operations.
"""
from sqlmodel import Session, select
from app.core.database import engine
from app.models.models import Concept, Card, Image
from app.api.v1.endpoints.flashcard_helpers import retrieve_images_for_concept
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def generate_images_for_existing_concepts_task(
    task_id: str,
    user_id: Optional[int] = None,
    image_tasks: dict = None,
    task_lock = None
):
    """
    Background task to generate images for existing concepts without images.
    Processes concepts one by one, checking for cancellation between each.
    
    Args:
        task_id: Unique task identifier
        user_id: Optional user ID (for future use)
        image_tasks: Dictionary to track task status
        task_lock: Thread lock for task dictionary access
    """
    with Session(engine) as bg_session:
        try:
            with task_lock:
                image_tasks[task_id] = {
                    'status': 'running',
                    'progress': {
                        'total_concepts': 0,
                        'processed': 0,
                        'images_retrieved': 0,
                        'concepts_processed': 0,
                        'concepts_failed': 0
                    },
                    'cancelled': False
                }
            
            # Step 1: Find concept IDs without images
            logger.info(f"Task {task_id}: Finding concepts without images")
            
            # Get all concepts
            all_concepts = bg_session.exec(select(Concept)).all()
            concept_ids_needing_images = []
            
            for concept in all_concepts:
                # Check if concept has no images in Image table
                image_count = bg_session.exec(
                    select(Image).where(Image.concept_id == concept.id)
                ).first()
                
                if not image_count:
                    concept_ids_needing_images.append(concept.id)
            
            total_concepts = len(concept_ids_needing_images)
            logger.info(f"Task {task_id}: Found {total_concepts} concepts needing images")
            
            with task_lock:
                image_tasks[task_id]['progress']['total_concepts'] = total_concepts
            
            if total_concepts == 0:
                with task_lock:
                    image_tasks[task_id]['status'] = 'completed'
                    image_tasks[task_id]['message'] = 'No concepts need images'
                return
            
            # Process each concept
            images_retrieved_total = 0
            concepts_processed = 0
            concepts_failed = 0
            
            for idx, concept_id in enumerate(concept_ids_needing_images):
                # Check for cancellation
                with task_lock:
                    if image_tasks[task_id].get('cancelled', False):
                        logger.info(f"Task {task_id}: Cancellation requested at concept {idx + 1}/{total_concepts}")
                        image_tasks[task_id]['status'] = 'cancelled'
                        image_tasks[task_id]['message'] = f'Cancelled after processing {concepts_processed} concepts'
                        return
                
                try:
                    # Get concept and its cards
                    concept = bg_session.get(Concept, concept_id)
                    if not concept:
                        continue
                    
                    cards = bg_session.exec(
                        select(Card).where(Card.concept_id == concept_id)
                    ).all()
                    
                    if not cards:
                        logger.warning(f"Task {task_id}: No cards found for concept {concept_id}")
                        concepts_failed += 1
                        continue
                    
                    # Get the term text from any card (prefer English, then first card)
                    concept_text = None
                    
                    # Try to get English card first
                    english_card = next((card for card in cards if card.language_code == 'en'), None)
                    if english_card:
                        concept_text = english_card.term
                    else:
                        # Use first card's term
                        if cards:
                            concept_text = cards[0].term
                    
                    if not concept_text:
                        logger.warning(f"Task {task_id}: No term text found for concept {concept_id}")
                        concepts_failed += 1
                        continue
                    
                    # Retrieve images using reusable function
                    cancellation_flag = image_tasks[task_id]
                    if cancellation_flag.get('cancelled', False):
                        logger.info(f"Task {task_id}: Cancellation requested before image retrieval")
                        image_tasks[task_id]['status'] = 'cancelled'
                        image_tasks[task_id]['message'] = f'Cancelled after processing {concepts_processed} concepts'
                        return
                    
                    image_result = retrieve_images_for_concept(
                        concept=concept,
                        concept_text=concept_text,
                        session=bg_session
                    )
                    
                    # Check if cancelled
                    if cancellation_flag.get('cancelled', False):
                        with task_lock:
                            image_tasks[task_id]['status'] = 'cancelled'
                            image_tasks[task_id]['message'] = f'Cancelled after processing {concepts_processed} concepts'
                        return
                    
                    # Commit updates for this concept
                    if image_result.get('success') and image_result.get('images_retrieved', 0) > 0:
                        bg_session.commit()
                        images_retrieved_total += image_result['images_retrieved']
                        concepts_processed += 1
                        logger.info(f"Task {task_id}: Processed concept {concept_id} - retrieved {image_result['images_retrieved']} images")
                    elif image_result.get('skipped'):
                        concepts_processed += 1
                        logger.info(f"Task {task_id}: Concept {concept_id} already has images, skipped")
                    else:
                        concepts_failed += 1
                        logger.warning(f"Task {task_id}: Failed to retrieve images for concept {concept_id}: {image_result.get('error', 'Unknown error')}")
                    
                    # Update progress
                    with task_lock:
                        image_tasks[task_id]['progress']['processed'] = idx + 1
                        image_tasks[task_id]['progress']['images_retrieved'] = images_retrieved_total
                        image_tasks[task_id]['progress']['concepts_processed'] = concepts_processed
                        image_tasks[task_id]['progress']['concepts_failed'] = concepts_failed
                
                except Exception as e:
                    logger.error(f"Task {task_id}: Error processing concept {concept_id}: {str(e)}")
                    concepts_failed += 1
                    with task_lock:
                        image_tasks[task_id]['progress']['concepts_failed'] = concepts_failed
            
            # Mark as completed
            with task_lock:
                image_tasks[task_id]['status'] = 'completed'
                image_tasks[task_id]['message'] = f'Completed: {concepts_processed} concepts processed, {images_retrieved_total} images retrieved'
            
            logger.info(f"Task {task_id}: Completed - {concepts_processed} concepts processed, {images_retrieved_total} images retrieved")
            
        except Exception as e:
            logger.error(f"Task {task_id}: Image generation failed: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
            with task_lock:
                image_tasks[task_id]['status'] = 'failed'
                image_tasks[task_id]['message'] = f'Failed: {str(e)}'

