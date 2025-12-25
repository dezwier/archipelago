"""
Lesson completion endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import Dict, Optional
import logging

from app.core.database import get_session
from app.models.models import User, UserLemma, Lemma, Exercise, Lesson
from app.schemas.filter import LessonGenerateRequest
from app.schemas.lesson import (
    CompleteLessonRequest,
    CompleteLessonResponse
)
from app.schemas.lemma import NewCardsResponse
from app.services.srs_service import update_srs_for_lesson, recompute_user_lemma_srs
from app.services.lesson_service import generate_lesson_concepts

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lessons", tags=["lessons"])


@router.post("/recompute-srs", status_code=status.HTTP_200_OK)
async def recompute_srs(
    user_id: int,
    lemma_id: Optional[int] = None,
    session: Session = Depends(get_session)
):
    """
    Recompute UserLemma SRS fields based on Exercise records.
    
    This endpoint recomputes last_review_time, leitner_bin, and next_review_at
    for UserLemma records based on all Exercise records in the database.
    Processes exercises lesson-by-lesson in chronological order.
    
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
    
    # Use user's Leitner configuration
    interval_style = user.leitner_algorithm
    max_bins = user.leitner_max_bins
    interval_start_hours = user.leitner_interval_start
    
    # Recompute SRS for all exercises (or filtered by lemma_id)
    updated_count = recompute_user_lemma_srs(
        session,
        user_id,
        lemma_id=lemma_id,
        interval_style=interval_style,
        max_bins=max_bins,
        interval_start_hours=interval_start_hours
    )
    
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
    2. Creates a Lesson record with metadata (start/end time, kind, learning language)
    3. Creates Exercise records for all exercises (excluding discovery/summary) linked to the lesson
    4. Gets or creates UserLemma records for each lemma
    5. Updates UserLemma SRS fields based on exercise results
    6. Commits all changes in a transaction
    
    Args:
        request: CompleteLessonRequest with kind, exercises and user_lemmas
        
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
    
    # Calculate lesson start_time and end_time from exercises
    # Filter out discovery and summary exercises for timing calculation
    valid_exercises = [
        ex for ex in request.exercises 
        if ex.exercise_type not in ['discovery', 'summary']
    ]
    
    if not valid_exercises:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No valid exercises provided (only discovery/summary exercises)"
        )
    
    lesson_start_time = min(ex.start_time for ex in valid_exercises)
    lesson_end_time = max(ex.end_time for ex in valid_exercises)
    
    # Validate learning language exists in languages table
    from app.models.models import Language
    language = session.exec(
        select(Language).where(Language.code == learning_language)
    ).first()
    if not language:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid learning language code: {learning_language}"
        )
    
    # Create Lesson record
    lesson = Lesson(
        user_id=request.user_id,
        learning_language=learning_language,
        kind=request.kind,
        start_time=lesson_start_time,
        end_time=lesson_end_time
    )
    session.add(lesson)
    session.flush()  # Flush to get the lesson ID
    
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
        
        # Create Exercise record with lesson_id
        exercise = Exercise(
            user_lemma_id=user_lemma.id,
            lesson_id=lesson.id,
            exercise_type=exercise_data.exercise_type,
            result=exercise_data.result,
            start_time=exercise_data.start_time,
            end_time=exercise_data.end_time
        )
        session.add(exercise)
        created_exercises_count += 1
    
    # Commit lesson and exercise records together
    try:
        session.commit()
        logger.info(
            f"Created lesson {lesson.id} with {created_exercises_count} exercises for user {request.user_id}"
        )
    except Exception as e:
        session.rollback()
        logger.error(f"Error creating lesson and exercises for user {request.user_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create lesson and exercises: {str(e)}"
        )
    
    # Update SRS for all affected user lemmas based on exercises in this lesson
    updated_user_lemmas_count = 0
    lemma_ids_to_update = set()
    
    # Collect all lemma_ids that had exercises created
    for exercise_data in request.exercises:
        if exercise_data.exercise_type not in ['discovery', 'summary']:
            lemma_ids_to_update.add(exercise_data.lemma_id)
    
    # Update SRS for each user lemma using lesson-based logic
    # Use user's Leitner configuration
    interval_style = user.leitner_algorithm
    max_bins = user.leitner_max_bins
    interval_start_hours = user.leitner_interval_start
    
    for lemma_id in lemma_ids_to_update:
        user_lemma = user_lemma_map.get(lemma_id)
        if user_lemma:
            update_srs_for_lesson(
                session=session,
                user_lemma=user_lemma,
                lesson_id=lesson.id,
                interval_style=interval_style,
                max_bins=max_bins,
                interval_start_hours=interval_start_hours
            )
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


@router.post("/generate", response_model=NewCardsResponse)
async def generate_lesson(
    request: LessonGenerateRequest,
    session: Session = Depends(get_session)
):
    """
    Generate a lesson by retrieving concepts based on filters and user_lemma inclusion criteria.
    
    Filters concepts using the same parameters as the dictionary endpoint.
    Only returns concepts that have lemmas in both native and learning languages.
    Returns concepts with both learning and native language lemmas coupled together.
    
    Args:
        request: LessonGenerateRequest containing filter_config, language, and other lesson parameters
    
    Returns:
        NewCardsResponse containing concepts with both native and learning language lemmas
    """
    # Extract user_id from filter_config
    user_id = request.filter_config.user_id
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="user_id is required in filter_config"
        )
    
    return generate_lesson_concepts(
        session=session,
        user_id=user_id,
        language=request.language,
        native_language=request.native_language,
        max_n=request.max_n,
        filter_config=request.filter_config,
        include_with_user_lemma=request.include_with_user_lemma,
        include_without_user_lemma=request.include_without_user_lemma,
    )
