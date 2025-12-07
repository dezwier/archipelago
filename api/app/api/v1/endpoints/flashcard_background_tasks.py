"""
Background tasks for flashcard operations.
"""
from sqlmodel import Session, select
from app.core.database import engine
from app.models.models import Concept, Card
from app.api.v1.endpoints.flashcard_helpers import generate_descriptions_for_cards
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def generate_descriptions_background(
    concept_text: str,
    source_lang_code: str,
    new_card_ids: list[int],
    concept_id: int
):
    """
    Background task to generate descriptions for new cards.
    Uses the reusable generate_descriptions_for_cards function.
    """
    # Create a new database session for the background task
    with Session(engine) as bg_session:
        try:
            logger.info(f"Background task: Generating descriptions for {len(new_card_ids)} cards (concept_id: {concept_id})")
            
            # Get the cards that need descriptions
            cards = bg_session.exec(
                select(Card).where(Card.id.in_(new_card_ids))
            ).all()
            
            if not cards:
                logger.warning(f"Background task: No cards found for IDs: {new_card_ids}")
                return
            
            # Use reusable function
            result = generate_descriptions_for_cards(
                cards=cards,
                concept_text=concept_text,
                source_lang_code=source_lang_code,
                session=bg_session
            )
            
            # Commit updates
            if result.get('cards_updated', 0) > 0:
                bg_session.commit()
                logger.info(f"Background task: Successfully updated {result['cards_updated']} card(s) with descriptions")
            else:
                logger.warning("Background task: No descriptions were updated")
                
        except Exception as e:
            logger.error(f"Background task: Description generation failed: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())


def generate_descriptions_for_existing_cards_task(
    task_id: str,
    user_id: Optional[int] = None,
    description_tasks: dict = None,
    task_lock = None
):
    """
    Background task to generate descriptions for existing cards without descriptions.
    Processes concepts one by one, checking for cancellation between each.
    
    Args:
        task_id: Unique task identifier
        user_id: Optional user ID (for future use)
        description_tasks: Dictionary to track task status
        task_lock: Thread lock for task dictionary access
    """
    with Session(engine) as bg_session:
        try:
            with task_lock:
                description_tasks[task_id] = {
                    'status': 'running',
                    'progress': {
                        'total_concepts': 0,
                        'processed': 0,
                        'cards_updated': 0,
                        'concepts_processed': 0,
                        'concepts_failed': 0
                    },
                    'cancelled': False
                }
            
            # Step 1: Find concept IDs with at least one language without description
            logger.info(f"Task {task_id}: Finding concepts with missing descriptions")
            
            # Get all concepts
            all_concepts = bg_session.exec(select(Concept)).all()
            concept_ids_needing_descriptions = []
            
            for concept in all_concepts:
                # Get all cards for this concept
                cards = bg_session.exec(
                    select(Card).where(Card.concept_id == concept.id)
                ).all()
                
                # Check if at least one card is missing a description
                has_missing_description = any(
                    not card.description or not card.description.strip() 
                    for card in cards
                )
                
                if has_missing_description:
                    concept_ids_needing_descriptions.append(concept.id)
            
            total_concepts = len(concept_ids_needing_descriptions)
            logger.info(f"Task {task_id}: Found {total_concepts} concepts needing descriptions")
            
            with task_lock:
                description_tasks[task_id]['progress']['total_concepts'] = total_concepts
            
            if total_concepts == 0:
                with task_lock:
                    description_tasks[task_id]['status'] = 'completed'
                    description_tasks[task_id]['message'] = 'No concepts need descriptions'
                return
            
            # Process each concept
            cards_updated_total = 0
            concepts_processed = 0
            concepts_failed = 0
            
            for idx, concept_id in enumerate(concept_ids_needing_descriptions):
                # Check for cancellation
                with task_lock:
                    if description_tasks[task_id].get('cancelled', False):
                        logger.info(f"Task {task_id}: Cancellation requested at concept {idx + 1}/{total_concepts}")
                        description_tasks[task_id]['status'] = 'cancelled'
                        description_tasks[task_id]['message'] = f'Cancelled after processing {concepts_processed} concepts'
                        return
                
                try:
                    # Get concept and its cards
                    concept = bg_session.get(Concept, concept_id)
                    if not concept:
                        continue
                    
                    cards = bg_session.exec(
                        select(Card).where(Card.concept_id == concept_id)
                    ).all()
                    
                    # Filter cards that need descriptions
                    cards_needing_descriptions = [
                        card for card in cards 
                        if not card.description or not card.description.strip()
                    ]
                    
                    if not cards_needing_descriptions:
                        continue
                    
                    # Get the translation text from any card (prefer English, then source)
                    concept_text = None
                    source_lang_code = None
                    
                    # Try to get English card first
                    english_card = next((card for card in cards if card.language_code == 'en'), None)
                    if english_card:
                        concept_text = english_card.translation
                        source_lang_code = 'en'
                    else:
                        # Use first card's translation
                        if cards:
                            concept_text = cards[0].translation
                            source_lang_code = cards[0].language_code
                    
                    if not concept_text:
                        logger.warning(f"Task {task_id}: No translation text found for concept {concept_id}")
                        concepts_failed += 1
                        continue
                    
                    # Generate descriptions using reusable function
                    cancellation_flag = description_tasks[task_id]
                    result = generate_descriptions_for_cards(
                        cards=cards_needing_descriptions,
                        concept_text=concept_text,
                        source_lang_code=source_lang_code,
                        session=bg_session,
                        task_id=task_id,
                        cancellation_flag=cancellation_flag
                    )
                    
                    # Check if cancelled
                    if result.get('cancelled', False):
                        with task_lock:
                            description_tasks[task_id]['status'] = 'cancelled'
                            description_tasks[task_id]['message'] = f'Cancelled after processing {concepts_processed} concepts'
                        return
                    
                    # Commit updates for this concept
                    if result.get('cards_updated', 0) > 0:
                        bg_session.commit()
                        cards_updated_total += result['cards_updated']
                        concepts_processed += 1
                        logger.info(f"Task {task_id}: Processed concept {concept_id} - updated {result['cards_updated']} cards")
                    else:
                        concepts_failed += 1
                        logger.warning(f"Task {task_id}: Failed to update cards for concept {concept_id}")
                    
                    # Update progress
                    with task_lock:
                        description_tasks[task_id]['progress']['processed'] = idx + 1
                        description_tasks[task_id]['progress']['cards_updated'] = cards_updated_total
                        description_tasks[task_id]['progress']['concepts_processed'] = concepts_processed
                        description_tasks[task_id]['progress']['concepts_failed'] = concepts_failed
                
                except Exception as e:
                    logger.error(f"Task {task_id}: Error processing concept {concept_id}: {str(e)}")
                    concepts_failed += 1
                    with task_lock:
                        description_tasks[task_id]['progress']['concepts_failed'] = concepts_failed
            
            # Mark as completed
            with task_lock:
                description_tasks[task_id]['status'] = 'completed'
                description_tasks[task_id]['message'] = f'Completed: {concepts_processed} concepts processed, {cards_updated_total} cards updated'
            
            logger.info(f"Task {task_id}: Completed - {concepts_processed} concepts processed, {cards_updated_total} cards updated")
            
        except Exception as e:
            logger.error(f"Task {task_id}: Description generation failed: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
            with task_lock:
                description_tasks[task_id]['status'] = 'failed'
                description_tasks[task_id]['message'] = f'Failed: {str(e)}'

