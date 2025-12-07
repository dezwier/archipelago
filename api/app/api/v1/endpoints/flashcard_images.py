"""
Endpoints for generating images for existing flashcards.
"""
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Concept, Card
from app.schemas.flashcard import (
    GenerateDescriptionsResponse,
    TaskStatusResponse,
)
from app.api.v1.endpoints.flashcard_background_tasks import generate_images_for_existing_concepts_task
from app.api.v1.endpoints.flashcard_helpers import retrieve_images_for_concept
import logging
import uuid
from typing import Dict, Optional
from threading import Lock

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
        has_images = any([
            concept.image_path_1,
            concept.image_path_2,
            concept.image_path_3,
            concept.image_path_4
        ])
        if not has_images:
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
    Refresh/regenerate images for a specific concept.
    This will retrieve new images even if the concept already has images.
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
            concept_text = card.translation
            break
    
    if not concept_text and cards:
        concept_text = cards[0].translation
    
    if not concept_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Concept {concept_id} has no cards with translation text"
        )
    
    # Retrieve new images (force refresh even if images exist)
    result = retrieve_images_for_concept(
        concept=concept,
        concept_text=concept_text,
        session=session,
        force_refresh=True
    )
    
    if result['success']:
        return {
            'success': True,
            'images_retrieved': result['images_retrieved'],
            'message': f"Retrieved {result['images_retrieved']} new image(s) for concept {concept_id}"
        }
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=result.get('error', 'Failed to retrieve images')
        )

