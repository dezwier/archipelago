"""
Lesson completion endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import Dict, List, Optional
from datetime import datetime
import logging

from app.core.database import get_session
from app.models.models import User, UserLemma, Lemma, Exercise
from app.schemas.lesson import (
    CompleteLessonRequest,
    CompleteLessonResponse
)
from app.services.srs_service import update_leitner_bin, calculate_next_review_at

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lessons", tags=["lessons"])


def recompute_user_lemma_srs(
    session: Session,
    user_lemma: UserLemma
) -> None:
    """
    Recompute UserLemma SRS fields (last_success_time, leitner_bin, next_review_at)
    based on all Exercise records for this user_lemma.
    
    Args:
        session: Database session
        user_lemma: UserLemma instance to update
    """
    # Get all exercises for this user_lemma, ordered by end_time
    exercises = session.exec(
        select(Exercise)
        .where(Exercise.user_lemma_id == user_lemma.id)
        .order_by(Exercise.end_time)  # type: ignore
    ).all()
    
    if not exercises:
        # No exercises, reset to initial state
        user_lemma.leitner_bin = 0
        user_lemma.last_success_time = None
        user_lemma.next_review_at = calculate_next_review_at(0)
        return
    
    # Collect exercise results and find last success time
    exercise_results: List[str] = []
    last_success_time: Optional[datetime] = None
    
    for exercise in exercises:
        exercise_results.append(exercise.result)
        
        # Track last success time
        if exercise.result == 'success':
            if last_success_time is None or exercise.end_time > last_success_time:
                last_success_time = exercise.end_time
    
    # Update bin based on all exercise results
    # Process results sequentially to update bin progressively
    current_bin = 0  # Start from bin 0 for new user_lemmas, or use existing bin
    if user_lemma.leitner_bin is not None:
        current_bin = user_lemma.leitner_bin
    
    # Process each exercise result to update bin
    for result in exercise_results:
        current_bin = update_leitner_bin(current_bin, result)
    
    user_lemma.leitner_bin = current_bin
    
    # Update last_success_time
    user_lemma.last_success_time = last_success_time
    
    # Calculate next review time based on final bin
    # Use the most recent exercise end_time as base, or current time
    base_time = exercises[-1].end_time if exercises else datetime.utcnow()
    user_lemma.next_review_at = calculate_next_review_at(current_bin, base_time)


@router.post("/recompute-srs", status_code=status.HTTP_200_OK)
async def recompute_srs(
    user_id: int,
    lemma_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Recompute UserLemma SRS fields based on Exercise records.
    
    This endpoint recomputes last_success_time, leitner_bin, and next_review_at
    for UserLemma records based on all Exercise records in the database.
    
    Args:
        user_id: User ID (required)
        lemma_id: Optional lemma ID. If provided, only recomputes for that lemma.
                  If not provided, recomputes for all user lemmas.
        
    Returns:
        Dict with message and counts of updated records
    """
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Get user lemmas to update
    if lemma_id:
        # Recompute for specific lemma
        user_lemma = session.exec(
            select(UserLemma).where(
                UserLemma.user_id == user_id,
                UserLemma.lemma_id == lemma_id
            )
        ).first()
        
        if not user_lemma:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"UserLemma not found for user {user_id} and lemma {lemma_id}"
            )
        
        recompute_user_lemma_srs(session, user_lemma)
        updated_count = 1
    else:
        # Recompute for all user lemmas
        user_lemmas = session.exec(
            select(UserLemma).where(UserLemma.user_id == user_id)
        ).all()
        
        updated_count = 0
        for user_lemma in user_lemmas:
            recompute_user_lemma_srs(session, user_lemma)
            updated_count += 1
    
    # Commit changes
    try:
        session.commit()
        logger.info(
            f"Recomputed SRS for user {user_id}: {updated_count} user lemmas updated"
        )
    except Exception as e:
        session.rollback()
        logger.error(f"Error recomputing SRS for user {user_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to recompute SRS: {str(e)}"
        )
    
    return {
        "message": f"Successfully recomputed SRS for {updated_count} user lemma(s)",
        "updated_count": updated_count
    }


@router.post("/complete", response_model=CompleteLessonResponse, status_code=status.HTTP_200_OK)
async def complete_lesson(
    request: CompleteLessonRequest,
    session: Session = Depends(get_session)
):
    """
    Complete a lesson by syncing exercises and updating user lemma progress.
    
    This endpoint:
    1. Validates the user exists
    2. Creates Exercise records for all exercises (excluding discovery/summary)
    3. Gets or creates UserLemma records for each lemma
    4. Updates UserLemma SRS fields based on exercise results
    5. Commits all changes in a transaction
    
    Args:
        request: CompleteLessonRequest with exercises and user_lemmas
        
    Returns:
        CompleteLessonResponse with counts of created/updated records
    """
    # Validate user exists
    user = session.get(User, request.user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {request.user_id} not found"
        )
    
    # Validate that user has a learning language
    if not user.lang_learning:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="User must have a learning language set"
        )
    
    learning_language = user.lang_learning.lower()
    
    # Get or create UserLemma records for each lemma_id
    user_lemma_map: Dict[int, UserLemma] = {}
    lemma_ids = set()
    
    # Collect all lemma_ids from exercises and user_lemmas
    for exercise in request.exercises:
        lemma_ids.add(exercise.lemma_id)
    for user_lemma_update in request.user_lemmas:
        lemma_ids.add(user_lemma_update.lemma_id)
    
    # Get or create UserLemma for each lemma_id
    for lemma_id in lemma_ids:
        # Verify lemma exists
        lemma = session.get(Lemma, lemma_id)
        if not lemma:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Lemma with id {lemma_id} not found"
            )
        
        # Verify lemma is in user's learning language
        if lemma.language_code.lower() != learning_language:
            logger.warning(
                f"Lemma {lemma_id} language {lemma.language_code} doesn't match "
                f"user {request.user_id} learning language {learning_language}"
            )
            # Continue anyway - the frontend should handle this, but we'll log it
        
        # Get or create UserLemma
        user_lemma = session.exec(
            select(UserLemma).where(
                UserLemma.user_id == request.user_id,
                UserLemma.lemma_id == lemma_id
            )
        ).first()
        
        if not user_lemma:
            # Create new UserLemma
            user_lemma = UserLemma(
                user_id=request.user_id,
                lemma_id=lemma_id,
                leitner_bin=0,
                next_review_at=None
            )
            session.add(user_lemma)
            session.flush()  # Flush to get the ID
        
        user_lemma_map[lemma_id] = user_lemma
    
    # Create Exercise records
    created_exercises_count = 0
    
    for exercise_data in request.exercises:
        # Skip discovery and summary exercises
        if exercise_data.exercise_type in ['discovery', 'summary']:
            continue
        
        user_lemma = user_lemma_map.get(exercise_data.lemma_id)
        if not user_lemma:
            logger.error(f"UserLemma not found for lemma_id {exercise_data.lemma_id}")
            continue
        
        # Create Exercise record
        exercise = Exercise(
            user_lemma_id=user_lemma.id,
            exercise_type=exercise_data.exercise_type,
            result=exercise_data.result,
            start_time=exercise_data.start_time,
            end_time=exercise_data.end_time
        )
        session.add(exercise)
        created_exercises_count += 1
    
    # Commit exercise records first
    try:
        session.commit()
        logger.info(
            f"Created {created_exercises_count} exercises for user {request.user_id}"
        )
    except Exception as e:
        session.rollback()
        logger.error(f"Error creating exercises for user {request.user_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create exercises: {str(e)}"
        )
    
    # Recompute SRS for all affected user lemmas based on Exercise records
    updated_user_lemmas_count = 0
    lemma_ids_to_update = set()
    
    # Collect all lemma_ids that had exercises created
    for exercise_data in request.exercises:
        if exercise_data.exercise_type not in ['discovery', 'summary']:
            lemma_ids_to_update.add(exercise_data.lemma_id)
    
    # Recompute SRS for each user lemma
    for lemma_id in lemma_ids_to_update:
        user_lemma = user_lemma_map.get(lemma_id)
        if user_lemma:
            recompute_user_lemma_srs(session, user_lemma)
            updated_user_lemmas_count += 1
    
    # Commit SRS updates
    try:
        session.commit()
        logger.info(
            f"Lesson completed for user {request.user_id}: "
            f"{created_exercises_count} exercises created, "
            f"{updated_user_lemmas_count} user lemmas updated"
        )
    except Exception as e:
        session.rollback()
        logger.error(f"Error updating SRS for user {request.user_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update SRS: {str(e)}"
        )
    
    return CompleteLessonResponse(
        message="Lesson completed successfully",
        created_exercises_count=created_exercises_count,
        updated_user_lemmas_count=updated_user_lemmas_count
    )


