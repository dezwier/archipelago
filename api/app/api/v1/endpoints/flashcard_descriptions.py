"""
Endpoints for generating descriptions for existing flashcards.
"""
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Concept, Card
from app.schemas.flashcard import (
    GenerateDescriptionsResponse,
    TaskStatusResponse,
)
from app.api.v1.endpoints.flashcard_background_tasks import generate_descriptions_for_existing_cards_task
import logging
import uuid
from typing import Dict, Optional
from threading import Lock

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/flashcards", tags=["flashcards"])

# Task tracking for description generation
description_tasks: Dict[str, Dict] = {}
task_lock = Lock()


@router.post("/generate-descriptions", response_model=GenerateDescriptionsResponse, status_code=status.HTTP_202_ACCEPTED)
async def generate_descriptions_for_existing(
    background_tasks: BackgroundTasks,
    user_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Generate descriptions for existing cards that don't have descriptions.
    
    Step 1: Find concept IDs with at least one language without description
    Step 2: For each concept, check if English description exists, if not call Gemini API
    Step 3: Use English description to translate to other languages
    
    Returns a task ID that can be used to check status and cancel the operation.
    """
    # Generate unique task ID
    task_id = str(uuid.uuid4())
    
    # Start background task
    background_tasks.add_task(
        generate_descriptions_for_existing_cards_task,
        task_id=task_id,
        user_id=user_id,
        description_tasks=description_tasks,
        task_lock=task_lock
    )
    
    # Count total concepts that need descriptions (quick check)
    all_concepts = session.exec(select(Concept)).all()
    total_concepts = 0
    for concept in all_concepts:
        cards = session.exec(
            select(Card).where(Card.concept_id == concept.id)
        ).all()
        has_missing = any(not card.description or not card.description.strip() for card in cards)
        if has_missing:
            total_concepts += 1
    
    logger.info(f"Started description generation task {task_id} for {total_concepts} concepts")
    
    return GenerateDescriptionsResponse(
        task_id=task_id,
        message="Description generation started. Use the task_id to check status or cancel.",
        total_concepts=total_concepts,
        status="running"
    )


@router.get("/generate-descriptions/{task_id}/status", response_model=TaskStatusResponse)
async def get_description_generation_status(
    task_id: str
):
    """
    Get the status of a description generation task.
    """
    with task_lock:
        task = description_tasks.get(task_id)
    
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


@router.post("/generate-descriptions/{task_id}/cancel", response_model=TaskStatusResponse)
async def cancel_description_generation(
    task_id: str
):
    """
    Cancel a running description generation task.
    """
    with task_lock:
        task = description_tasks.get(task_id)
    
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

