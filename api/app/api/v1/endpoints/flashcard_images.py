"""
Endpoints for generating images for existing flashcards.
"""
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Concept, Card, Image
from app.schemas.flashcard import (
    GenerateDescriptionsResponse,
    TaskStatusResponse,
    UpdateConceptImageRequest,
)
from app.api.v1.endpoints.flashcard_background_tasks import generate_images_for_existing_concepts_task
from app.api.v1.endpoints.flashcard_helpers import retrieve_images_for_concept
import logging
import uuid
from typing import Dict, Optional
from threading import Lock
from datetime import datetime

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcards", tags=["flashcards"])

# Task tracking for image generation
image_tasks: Dict[str, Dict] = {}
task_lock = Lock()


@router.post("/generate-images", response_model=GenerateDescriptionsResponse, status_code=status.HTTP_202_ACCEPTED)
async def generate_images_for_existing(
    background_tasks: BackgroundTasks,
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Generate images for existing concepts that don't have images.
    
    Returns a task ID that can be used to check status and cancel the operation.
    """
    # Generate unique task ID
    task_id = str(uuid.uuid4())
    
    # Start background task
    background_tasks.add_task(
        generate_images_for_existing_concepts_task,
        task_id=task_id,
        user_id=user_id,
        image_tasks=image_tasks,
        task_lock=task_lock
    )
    
    # Count total concepts that need images (quick check)
    all_concepts = session.exec(select(Concept)).all()
    total_concepts = 0
    for concept in all_concepts:
        # Check if concept has any images
        image_count = session.exec(
            select(Image).where(Image.concept_id == concept.id)
        ).first()
        if not image_count:
            total_concepts += 1
    
    logger.info(f"Started image generation task {task_id} for {total_concepts} concepts")
    
    return GenerateDescriptionsResponse(
        task_id=task_id,
        message="Image generation started. Use the task_id to check status or cancel.",
        total_concepts=total_concepts,
        status="running"
    )


@router.get("/generate-images/{task_id}/status", response_model=TaskStatusResponse)
async def get_image_generation_status(
    task_id: str
):
    """
    Get the status of an image generation task.
    """
    with task_lock:
        task = image_tasks.get(task_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found"
        )
    
    return TaskStatusResponse(
        task_id=task_id,
        status=task['status'],
        progress=task['progress'],
        message=task.get('message')
    )


@router.post("/generate-images/{task_id}/cancel", response_model=TaskStatusResponse)
async def cancel_image_generation(
    task_id: str
):
    """
    Cancel a running image generation task.
    """
    with task_lock:
        task = image_tasks.get(task_id)
    
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task {task_id} not found"
        )
    
    if task['status'] not in ['running']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Task {task_id} is not running (current status: {task['status']})"
        )
    
    # Set cancellation flag
    task['cancelled'] = True
    task['status'] = 'cancelling'
    task['message'] = 'Cancellation requested'
    
    logger.info(f"Cancellation requested for task {task_id}")
    
    return TaskStatusResponse(
        task_id=task_id,
        status='cancelling',
        progress=task['progress'],
        message='Cancellation requested'
    )


@router.post("/concepts/{concept_id}/refresh-images")
async def refresh_images_for_concept(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Add new images to a specific concept, filling empty slots.
    This will only add images to empty slots, not replace existing ones.
    """
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept {concept_id} not found"
        )
    
    # Get concept text from English card if available, otherwise use first card
    concept_text = None
    cards = session.exec(select(Card).where(Card.concept_id == concept_id)).all()
    for card in cards:
        if card.language_code == 'en':
            concept_text = card.term
            break
    
    if not concept_text and cards:
        concept_text = cards[0].term
    
    if not concept_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Concept {concept_id} has no cards with term text"
        )
    
    # Add new images to empty slots (don't force refresh, just fill empty slots)
    result = retrieve_images_for_concept(
        concept=concept,
        concept_text=concept_text,
        session=session,
        force_refresh=False
    )
    
    if result['success']:
        if result.get('skipped'):
            message = result.get('message', 'No empty slots available')
            return {
                'success': True,
                'images_retrieved': 0,
                'message': message
            }
        return {
            'success': True,
            'images_retrieved': result['images_retrieved'],
            'message': f"Added {result['images_retrieved']} new image(s) to concept {concept_id}"
        }
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get('error', 'Failed to retrieve images')
        )


@router.put("/concepts/{concept_id}/images/1")
async def update_concept_image_1(
    concept_id: int,
    request: UpdateConceptImageRequest,
    session: Session = Depends(get_session)
):
    """
    Update the primary image for a concept.
    
    Args:
        concept_id: The concept ID
        request: Request body with 'image_url' field (can be empty string to clear)
    """
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept {concept_id} not found"
        )
    
    image_url = request.image_url.strip() if request.image_url.strip() else None
    
    # Get primary image if it exists
    primary_image = session.exec(
        select(Image).where(Image.concept_id == concept_id, Image.is_primary == True)
    ).first()
    
    if image_url:
        if primary_image:
            # Update existing primary image
            primary_image.url = image_url
            session.add(primary_image)
        else:
            # Create new primary image
            primary_image = Image(
                concept_id=concept_id,
                url=image_url,
                image_type='illustration',
                is_primary=True,
                source='manual',
                created_at=datetime.utcnow()
            )
            session.add(primary_image)
    else:
        # Delete primary image if URL is empty
        if primary_image:
            session.delete(primary_image)
    
    session.commit()
    
    logger.info(f"Updated primary image for concept {concept_id}")
    
    return {
        'success': True,
        'message': f"Updated primary image for concept {concept_id}",
        'image_path_1': image_url
    }


@router.put("/concepts/{concept_id}/images/{image_index}")
async def update_concept_image(
    concept_id: int,
    image_index: int,
    request: UpdateConceptImageRequest,
    session: Session = Depends(get_session)
):
    """
    Update a specific image for a concept by index.
    
    Args:
        concept_id: The concept ID
        image_index: Image index (1-4) to update (1 = primary, 2-4 = non-primary)
        request: Request body with 'image_url' field (can be empty string to clear)
    """
    if image_index < 1 or image_index > 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image index must be between 1 and 4"
        )
    
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept {concept_id} not found"
        )
    
    image_url = request.image_url.strip() if request.image_url.strip() else None
    
    # Get all images for this concept, ordered by created_at
    all_images = session.exec(
        select(Image).where(Image.concept_id == concept_id).order_by(Image.created_at)
    ).all()
    
    # Separate primary and non-primary images
    primary_images = [img for img in all_images if img.is_primary]
    non_primary_images = [img for img in all_images if not img.is_primary]
    
    if image_index == 1:
        # Update primary image
        if primary_images:
            primary_image = primary_images[0]
            if image_url:
                primary_image.url = image_url
                session.add(primary_image)
            else:
                session.delete(primary_image)
        elif image_url:
            # Create new primary image
            primary_image = Image(
                concept_id=concept_id,
                url=image_url,
                image_type='illustration',
                is_primary=True,
                source='manual',
                created_at=datetime.utcnow()
            )
            session.add(primary_image)
    else:
        # Update non-primary image (index 2-4 maps to non-primary 0-2)
        non_primary_idx = image_index - 2
        if non_primary_idx < len(non_primary_images):
            # Update existing non-primary image
            img = non_primary_images[non_primary_idx]
            if image_url:
                img.url = image_url
                session.add(img)
            else:
                session.delete(img)
        elif image_url:
            # Create new non-primary image
            new_image = Image(
                concept_id=concept_id,
                url=image_url,
                image_type='illustration',
                is_primary=False,
                source='manual',
                created_at=datetime.utcnow()
            )
            session.add(new_image)
    
    session.commit()
    
    logger.info(f"Updated image {image_index} for concept {concept_id}")
    
    # Get updated image list to return the correct URL
    updated_images = session.exec(
        select(Image).where(Image.concept_id == concept_id).order_by(Image.created_at)
    ).all()
    updated_primary = [img for img in updated_images if img.is_primary]
    updated_non_primary = [img for img in updated_images if not img.is_primary]
    
    updated_path = None
    if image_index == 1:
        updated_path = updated_primary[0].url if updated_primary else None
    else:
        idx = image_index - 2
        updated_path = updated_non_primary[idx].url if idx < len(updated_non_primary) else None
    
    return {
        'success': True,
        'message': f"Updated image {image_index} for concept {concept_id}",
        f'image_path_{image_index}': updated_path
    }


@router.delete("/concepts/{concept_id}/images/{image_index}")
async def delete_concept_image(
    concept_id: int,
    image_index: int,
    session: Session = Depends(get_session)
):
    """
    Delete a specific image from a concept.
    
    Args:
        concept_id: The concept ID
        image_index: Image index (1-4) to delete (1 = primary, 2-4 = non-primary)
    """
    if image_index < 1 or image_index > 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Image index must be between 1 and 4"
        )
    
    # Get the concept
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept {concept_id} not found"
        )
    
    # Get all images for this concept, ordered by created_at
    all_images = session.exec(
        select(Image).where(Image.concept_id == concept_id).order_by(Image.created_at)
    ).all()
    
    # Separate primary and non-primary images
    primary_images = [img for img in all_images if img.is_primary]
    non_primary_images = [img for img in all_images if not img.is_primary]
    
    # Delete the specified image
    if image_index == 1:
        if primary_images:
            session.delete(primary_images[0])
    else:
        idx = image_index - 2
        if idx < len(non_primary_images):
            session.delete(non_primary_images[idx])
    
    session.commit()
    
    logger.info(f"Deleted image {image_index} from concept {concept_id}")
    
    return {
        'success': True,
        'message': f"Deleted image {image_index} from concept {concept_id}"
    }

