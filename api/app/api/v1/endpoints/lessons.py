"""
Lesson completion endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from typing import Dict, List, Optional
from datetime import datetime, timedelta
import logging

from app.core.database import get_session
from app.models.models import User, UserLemma, Lemma, Exercise, Lesson
from app.schemas.filter import LessonGenerateRequest
from app.schemas.lesson import (
    CompleteLessonRequest,
    CompleteLessonResponse
)
from app.schemas.lemma import NewCardsResponse
from app.services.srs_service import calculate_next_review_at, update_srs_for_lesson
from app.services.lesson_service import generate_lesson_concepts

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lessons", tags=["lessons"])


def recompute_user_lemma_srs(
    session: Session,
    user_lemma: UserLemma,
    first_day_interval: int = 1,
    interval_style: str = 'fibonacci',
    max_bins: int = 7
) -> None:
    """
    Recompute UserLemma SRS fields (last_success_time, leitner_bin, next_review_at)
    based on all Exercise records for this user_lemma, processing lesson-by-lesson.
    
    This function processes exercises grouped by lesson, applying the same logic
    as update_srs_for_lesson() for each lesson in chronological order.
    
    Args:
        session: Database session
        user_lemma: UserLemma instance to update
        first_day_interval: First day interval (default 1)
        interval_style: Interval style ('fibonacci' or other, default 'fibonacci')
        max_bins: Maximum bin number (default 7)
    """
    from app.services.srs_service import calculate_fibonacci_interval, LEITNER_INTERVALS
    
    # Get all exercises for this user_lemma
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
    
    # Group exercises by lesson_id
    exercises_by_lesson: Dict[int, List[Exercise]] = {}
    lesson_ids = set()
    
    for exercise in exercises:
        lesson_ids.add(exercise.lesson_id)
        if exercise.lesson_id not in exercises_by_lesson:
            exercises_by_lesson[exercise.lesson_id] = []
        exercises_by_lesson[exercise.lesson_id].append(exercise)
    
    # Get lessons and order by end_time
    # Convert set to list for the query
    lesson_ids_list = list(lesson_ids)
    if not lesson_ids_list:
        # No lessons, reset to initial state
        user_lemma.leitner_bin = 0
        user_lemma.last_success_time = None
        user_lemma.next_review_at = calculate_next_review_at(0)
        return
    
    # Query lessons - using type ignore for SQLModel's in_ method
    lesson_query = select(Lesson).where(Lesson.id.in_(lesson_ids_list))  # type: ignore[attr-defined]
    lesson_query = lesson_query.order_by(Lesson.end_time)  # type: ignore
    lessons = session.exec(lesson_query).all()
    
    # Create lesson lookup by id
    lesson_map = {lesson.id: lesson for lesson in lessons}
    
    # Sort lesson_ids by lesson end_time
    sorted_lesson_ids = sorted(
        lesson_ids,
        key=lambda lid: lesson_map[lid].end_time if lid in lesson_map else datetime.min
    )
    
    # Process lessons in chronological order
    current_bin = 0  # Start from bin 0
    last_success_time: Optional[datetime] = None
    last_lesson_end_time: Optional[datetime] = None
    
    for lesson_id in sorted_lesson_ids:
        lesson_exercises = exercises_by_lesson[lesson_id]
        lesson = lesson_map.get(lesson_id)
        
        if not lesson_exercises:
            continue
        
        # Determine if this is the first lesson (user_lemma is new)
        is_new = current_bin == 0 and lesson_id == sorted_lesson_ids[0]
        
        # Collect exercise results from this lesson
        exercise_results = [ex.result for ex in lesson_exercises]
        has_any_fail = 'fail' in exercise_results
        all_correct = not has_any_fail  # All are either 'success' or 'hint'
        
        # Find last success time from lesson exercises
        lesson_last_success: Optional[datetime] = None
        for exercise in lesson_exercises:
            if exercise.result == 'success':
                if lesson_last_success is None or exercise.end_time > lesson_last_success:
                    lesson_last_success = exercise.end_time
        
        # Apply bin logic (same as update_srs_for_lesson)
        if is_new:
            # New user_lemma: set bins to 1
            current_bin = 1
        elif all_correct:
            # Existing + all exercises correct: increment bins +1 (max max_bins)
            current_bin = min(max_bins, current_bin + 1)
        else:
            # Existing + any exercise failed: decrement bins -2 (min 1)
            current_bin = max(1, current_bin - 2)
        
        # Update last_success_time if there was any success in this lesson
        if lesson_last_success:
            if last_success_time is None or lesson_last_success > last_success_time:
                last_success_time = lesson_last_success
        
        # Track the most recent lesson end_time for next_review_at calculation
        if lesson:
            if last_lesson_end_time is None or lesson.end_time > last_lesson_end_time:
                last_lesson_end_time = lesson.end_time
        else:
            # Fallback to most recent exercise end_time if lesson not found
            exercise_end_time = max(ex.end_time for ex in lesson_exercises)
            if last_lesson_end_time is None or exercise_end_time > last_lesson_end_time:
                last_lesson_end_time = exercise_end_time
    
    # Update user_lemma fields
    user_lemma.leitner_bin = current_bin
    user_lemma.last_success_time = last_success_time
    
    # Calculate next review time based on final bin using Fibonacci intervals
    # Use last_success_time as base if available, otherwise use the most recent lesson end_time
    if last_success_time:
        base_time = last_success_time
    elif last_lesson_end_time:
        base_time = last_lesson_end_time
    else:
        base_time = datetime.utcnow()
    
    if interval_style == 'fibonacci':
        interval_days = calculate_fibonacci_interval(current_bin, first_day_interval)
    else:
        # Fallback to old Leitner intervals if needed
        bin_index = max(0, min(5, current_bin))
        interval_days = LEITNER_INTERVALS[bin_index]
    
    # Use 23 hours per day to account for users doing exercises around the same time each day
    user_lemma.next_review_at = base_time + timedelta(hours=interval_days * 23)


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
    Processes exercises lesson-by-lesson in chronological order.
    
    Args:
        user_id: User ID (required)
        lemma_id: Optional lemma ID. If provided, only recomputes for that lemma.
                  If not provided, recomputes for all user lemmas.
        
    Returns:
        Dict with message and counts of updated records
    """
    # SRS parameters (same as complete_lesson)
    FIRST_DAY_INTERVAL = 1
    INTERVAL_STYLE = 'fibonacci'
    MAX_BINS = 7
    
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
        
        recompute_user_lemma_srs(
            session,
            user_lemma,
            first_day_interval=FIRST_DAY_INTERVAL,
            interval_style=INTERVAL_STYLE,
            max_bins=MAX_BINS
        )
        updated_count = 1
    else:
        # Recompute for all user lemmas
        user_lemmas = session.exec(
            select(UserLemma).where(UserLemma.user_id == user_id)
        ).all()
        
        updated_count = 0
        for user_lemma in user_lemmas:
            recompute_user_lemma_srs(
                session,
                user_lemma,
                first_day_interval=FIRST_DAY_INTERVAL,
                interval_style=INTERVAL_STYLE,
                max_bins=MAX_BINS
            )
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
    # SRS parameters
    FIRST_DAY_INTERVAL = 1
    INTERVAL_STYLE = 'fibonacci'
    MAX_BINS = 7
    
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
    for lemma_id in lemma_ids_to_update:
        user_lemma = user_lemma_map.get(lemma_id)
        if user_lemma:
            update_srs_for_lesson(
                session=session,
                user_lemma=user_lemma,
                lesson_id=lesson.id,
                first_day_interval=FIRST_DAY_INTERVAL,
                interval_style=INTERVAL_STYLE,
                max_bins=MAX_BINS
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
