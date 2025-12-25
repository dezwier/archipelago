"""
SRS (Spaced Repetition System) service implementing the Leitner system.

This service handles updating user lemma progress based on exercise results.
"""
import logging
from datetime import datetime, timedelta
from typing import List, Optional, Dict
from sqlmodel import Session, select
from app.models.user_lemma import UserLemma
from app.models.exercise import Exercise
from app.models.lesson import Lesson

logger = logging.getLogger(__name__)


# Leitner bin review intervals in days
# Bin 0 = 1 day, Bin 1 = 2 days, Bin 2 = 4 days, Bin 3 = 8 days, Bin 4 = 16 days, Bin 5 = 32 days
LEITNER_INTERVALS = [1, 2, 4, 8, 16, 32]
MAX_BIN = 5
MIN_BIN = 0


def calculate_fibonacci_interval(bin_number: int, interval_start_hours: int) -> int:
    """
    Calculate review interval in hours using Fibonacci sequence.
    
    Fibonacci intervals starting from interval_start_hours:
    Bin 1 = interval_start_hours, Bin 2 = interval_start_hours, 
    Bin 3 = 2*interval_start_hours, Bin 4 = 3*interval_start_hours, etc.
    
    Example with interval_start_hours=23: Bin 1=23h, Bin 2=23h, Bin 3=46h, Bin 4=69h, Bin 5=115h, etc.
    
    Args:
        bin_number: Current bin number (1-based, minimum 1)
        interval_start_hours: Starting interval in hours (e.g., 23)
    
    Returns:
        Interval in hours
    """
    # Ensure bin_number is at least 1
    bin_number = max(1, bin_number)
    
    # Fibonacci sequence starting from [interval_start_hours, interval_start_hours]
    # For bins 1-7 with start=23: [23, 23, 46, 69, 115, 184, 299]
    if bin_number == 1:
        return interval_start_hours
    elif bin_number == 2:
        return interval_start_hours
    
    # Generate Fibonacci sequence starting from [interval_start_hours, interval_start_hours]
    fib_prev = interval_start_hours  # F(1) = interval_start_hours
    fib_curr = interval_start_hours  # F(2) = interval_start_hours
    
    # Calculate up to the requested bin
    for _ in range(3, bin_number + 1):
        fib_next = fib_prev + fib_curr
        fib_prev = fib_curr
        fib_curr = fib_next
    
    return fib_curr


def calculate_next_review_at(leitner_bin: int, base_time: datetime = None) -> datetime:
    """
    Calculate the next review time based on the Leitner bin.
    
    Args:
        leitner_bin: Current Leitner bin (0-5)
        base_time: Base time to calculate from (defaults to now)
    
    Returns:
        Datetime for next review
    """
    if base_time is None:
        base_time = datetime.utcnow()
    
    # Clamp bin to valid range
    bin_index = max(MIN_BIN, min(MAX_BIN, leitner_bin))
    
    # Get interval in days
    interval_days = LEITNER_INTERVALS[bin_index]
    
    return base_time + timedelta(days=interval_days)


def update_leitner_bin(current_bin: int, exercise_result: str) -> int:
    """
    Update Leitner bin based on exercise result.
    
    Args:
        current_bin: Current Leitner bin (0-5)
        exercise_result: Exercise result ('success', 'hint', or 'fail')
    
    Returns:
        New Leitner bin
    """
    # Clamp current bin to valid range
    current_bin = max(MIN_BIN, min(MAX_BIN, current_bin))
    
    if exercise_result == 'success':
        # Success: move up one bin (max bin 5)
        return min(MAX_BIN, current_bin + 1)
    elif exercise_result == 'hint':
        # Hint: stay in same bin (no change)
        return current_bin
    elif exercise_result == 'fail':
        # Failure: move down one bin (min bin 0)
        return max(MIN_BIN, current_bin - 1)
    else:
        # Unknown result: no change
        return current_bin


def update_srs_for_lesson(
    session: Session,
    user_lemma: UserLemma,
    lesson_id: int,
    interval_style: str = 'fibonacci',
    max_bins: int = 7,
    interval_start_hours: int = 23
) -> None:
    """
    Update UserLemma SRS fields based on exercises in a specific lesson.
    
    This function:
    - Only updates if last_exercise_end_time >= next_review_at (or next_review_at is None)
    - Queries exercises for the user_lemma in the specific lesson
    - Determines if user_lemma is new (no previous exercises before this lesson)
    - Applies bin logic:
      - New user_lemma: set bins to 1
      - Existing + any exercise failed: decrement bins -2 (min 1)
      - Existing + any hint (no fail): no change (+0)
      - Existing + all success: increment bins +1 (max max_bins)
    - Updates last_review_time to last exercise end_time (regardless of result)
    - Updates next_review_at using Fibonacci intervals based on last_exercise_end_time
    
    Args:
        session: Database session
        user_lemma: UserLemma instance to update
        lesson_id: ID of the lesson to process
        interval_style: Interval style ('fibonacci' or other, default 'fibonacci')
        max_bins: Maximum bin number (default 7)
        interval_start_hours: Starting interval in hours for bin 1 (default 23)
    """
    # Get all exercises for this user_lemma in the specific lesson
    lesson_exercises = session.exec(
        select(Exercise)
        .where(
            Exercise.user_lemma_id == user_lemma.id,
            Exercise.lesson_id == lesson_id
        )
        .order_by(Exercise.end_time)  # type: ignore
    ).all()
    
    if not lesson_exercises:
        # No exercises in this lesson, no update needed
        return
    
    # Get last exercise end_time (regardless of result)
    last_exercise_end_time = max(ex.end_time for ex in lesson_exercises)
    
    # Determine if user_lemma is new (no exercises before this lesson)
    # Check if there are any exercises with lesson_id < current lesson_id
    # or if leitner_bin is 0 and no previous exercises exist
    previous_exercises = session.exec(
        select(Exercise)
        .where(
            Exercise.user_lemma_id == user_lemma.id,
            Exercise.lesson_id < lesson_id  # type: ignore
        )
    ).first()
    
    is_new = previous_exercises is None and user_lemma.leitner_bin == 0
    
    if is_new:
        # First occurrence: hardcode with bin=1, last_review_time, next_review_at = last_review_time + interval_start_hours
        user_lemma.leitner_bin = 1
        user_lemma.last_review_time = last_exercise_end_time
        user_lemma.next_review_at = last_exercise_end_time + timedelta(hours=interval_start_hours)
        return
    
    # Lemma already exists: check if we should update
    current_bin = user_lemma.leitner_bin if user_lemma.leitner_bin is not None else 0
    current_next_review_at = user_lemma.next_review_at
    
    if current_next_review_at is None:
        # No next_review_at set, update it
        should_update = True
    else:
        # Only update if last_exercise_end_time >= next_review_at
        should_update = last_exercise_end_time >= current_next_review_at
    
    if not should_update:
        # Skip this lemma (last_exercise_end_time < next_review_at)
        return
    
    # Update UserLemma
    # Set last_review_time to last exercise end_time (regardless of result)
    user_lemma.last_review_time = last_exercise_end_time
    
    # Determine bin update based on exercise results
    has_fail = any(ex.result == 'fail' for ex in lesson_exercises)
    has_hint = any(ex.result == 'hint' for ex in lesson_exercises)
    all_success = all(ex.result == 'success' for ex in lesson_exercises)
    
    if has_fail:
        # Any exercise failed: decrement bin by 2 (min 1)
        new_bin = max(1, current_bin - 2)
    elif has_hint:
        # Any hint used (but no failures): no change (+0)
        new_bin = current_bin
    elif all_success:
        # All exercises succeeded: increment bin by 1 (max max_bins)
        new_bin = min(max_bins, current_bin + 1)
    else:
        # Fallback (shouldn't happen)
        new_bin = current_bin
    
    user_lemma.leitner_bin = new_bin
    
    # Calculate next_review_at based on bin and fibonacci
    if interval_style == 'fibonacci':
        interval_hours = calculate_fibonacci_interval(new_bin, interval_start_hours)
    else:
        # Fallback to old Leitner intervals if needed (convert days to hours)
        bin_index = max(0, min(5, new_bin))
        interval_days = LEITNER_INTERVALS[bin_index]
        interval_hours = interval_days * 24  # Convert days to hours
    
    # Use fibonacci interval directly in hours
    user_lemma.next_review_at = last_exercise_end_time + timedelta(hours=interval_hours)


def recompute_user_lemma_srs(
    session: Session,
    user_id: int,
    lemma_id: Optional[int] = None,
    interval_style: str = 'fibonacci',
    max_bins: int = 7,
    interval_start_hours: int = 23
) -> int:
    """
    Recompute UserLemma SRS fields (last_review_time, leitner_bin, next_review_at)
    based on all Exercise records for the user, processing lesson-by-lesson.
    
    This function:
    - Loops through all lessons for the user in chronological order
    - For each lesson, retrieves unique lemmas and their exercises
    - For each lemma in the lesson:
      - If it's the first occurrence of the lemma: creates/updates with bin=1, 
        last_review_time=last exercise end_time, next_review_at=last_review_time+interval_start_hours
      - If lemma already exists: only updates if last_exercise_end_time >= next_review_at
        - Updates last_review_time to last exercise end_time (regardless of result)
        - Updates bin: -2 if any fail, +0 if any hint (no fail), +1 if all success
        - Updates next_review_at based on bin and fibonacci intervals
    
    Args:
        session: Database session
        user_id: User ID to recompute SRS for
        lemma_id: Optional lemma ID to filter by. If provided, only processes exercises for that lemma.
        interval_style: Interval style ('fibonacci' or other, default 'fibonacci')
        max_bins: Maximum bin number (default 7)
        interval_start_hours: Starting interval in hours for bin 1 (default 23)
    
    Returns:
        Number of UserLemma records processed/updated
    """
    # Get all lessons for this user, ordered chronologically
    query = select(Lesson).where(Lesson.user_id == user_id).order_by(Lesson.end_time)  # type: ignore
    lessons = session.exec(query).all()
    
    if not lessons:
        logger.info(f"Recompute SRS for user {user_id}: No lessons found")
        return 0
    
    logger.info(f"Recompute SRS for user {user_id}: Processing {len(lessons)} lesson(s)")
    
    processed_count = 0
    # Track which lemmas we've seen (first occurrence)
    seen_lemma_ids: set[int] = set()
    # Map lemma_id to UserLemma for quick lookup
    user_lemma_map: Dict[int, UserLemma] = {}
    
    # Process each lesson chronologically
    for lesson_index, lesson in enumerate(lessons, 1):
        logger.info(
            f"Processing lesson {lesson_index}/{len(lessons)} (lesson_id={lesson.id}, "
            f"end_time={lesson.end_time})"
        )
        
        # Get all exercises for this lesson
        lesson_exercises = session.exec(
            select(Exercise).where(Exercise.lesson_id == lesson.id)  # type: ignore
        ).all()
        
        if not lesson_exercises:
            logger.info(f"  Lesson {lesson.id}: No exercises found, skipping")
            continue
        
        logger.info(f"  Lesson {lesson.id}: Found {len(lesson_exercises)} exercise(s)")
        
        # Group exercises by lemma_id
        # First, we need to get lemma_id from each exercise via user_lemma_id
        exercises_by_lemma: Dict[int, List[Exercise]] = {}
        
        for exercise in lesson_exercises:
            # Get UserLemma to find lemma_id
            user_lemma = session.get(UserLemma, exercise.user_lemma_id)
            if not user_lemma:
                logger.warning(f"  Lesson {lesson.id}: Exercise {exercise.id} has invalid user_lemma_id {exercise.user_lemma_id}, skipping")
                continue
            
            # Filter by lemma_id if provided
            if lemma_id is not None and user_lemma.lemma_id != lemma_id:
                continue
            
            lemma_id_for_exercise = user_lemma.lemma_id
            if lemma_id_for_exercise not in exercises_by_lemma:
                exercises_by_lemma[lemma_id_for_exercise] = []
            exercises_by_lemma[lemma_id_for_exercise].append(exercise)
        
        logger.info(f"  Lesson {lesson.id}: Found {len(exercises_by_lemma)} unique lemma(s)")
        
        # Process each unique lemma in this lesson
        for lemma_id_in_lesson, lemma_exercises in exercises_by_lemma.items():
            # Get last exercise end_time for this lemma in this lesson (regardless of result)
            last_exercise_end_time = max(ex.end_time for ex in lemma_exercises)
            
            # Get or create UserLemma
            if lemma_id_in_lesson not in user_lemma_map:
                # Try to get existing UserLemma
                user_lemma = session.exec(
                    select(UserLemma).where(
                        UserLemma.user_id == user_id,
                        UserLemma.lemma_id == lemma_id_in_lesson
                    )
                ).first()
                
                if not user_lemma:
                    # Create new UserLemma
                    user_lemma = UserLemma(
                        user_id=user_id,
                        lemma_id=lemma_id_in_lesson,
                        leitner_bin=0,
                        next_review_at=None
                    )
                    session.add(user_lemma)
                    session.flush()  # Flush to get the ID
                
                user_lemma_map[lemma_id_in_lesson] = user_lemma
            
            user_lemma = user_lemma_map[lemma_id_in_lesson]
            
            # Check if this is the first occurrence of this lemma
            is_first_occurrence = lemma_id_in_lesson not in seen_lemma_ids
            
            if is_first_occurrence:
                # First occurrence: hardcode with bin=1, last_review_time, next_review_at = last_review_time + interval_start_hours
                next_review = last_exercise_end_time + timedelta(hours=interval_start_hours)
                logger.info(
                    f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: First occurrence - "
                    f"initializing with bin=1, last_review_time={last_exercise_end_time}, "
                    f"next_review_at={next_review}"
                )
                user_lemma.leitner_bin = 1
                user_lemma.last_review_time = last_exercise_end_time
                user_lemma.next_review_at = next_review
                seen_lemma_ids.add(lemma_id_in_lesson)
                processed_count += 1
            else:
                # Lemma already exists: check if we should update
                current_bin = user_lemma.leitner_bin if user_lemma.leitner_bin is not None else 0
                current_next_review_at = user_lemma.next_review_at
                
                if current_next_review_at is None:
                    # No next_review_at set, update it
                    should_update = True
                    logger.info(
                        f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: Existing lemma "
                        f"(bin={current_bin}) - no next_review_at set, will update"
                    )
                else:
                    # Only update if last_exercise_end_time >= next_review_at
                    should_update = last_exercise_end_time >= current_next_review_at
                    if should_update:
                        logger.info(
                            f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: Existing lemma "
                            f"(bin={current_bin}) - last_exercise_end_time ({last_exercise_end_time}) >= "
                            f"next_review_at ({current_next_review_at}), will update"
                        )
                    else:
                        logger.info(
                            f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: Existing lemma "
                            f"(bin={current_bin}) - last_exercise_end_time ({last_exercise_end_time}) < "
                            f"next_review_at ({current_next_review_at}), skipping"
                        )
                
                if not should_update:
                    # Skip this lemma (last_review_time < next_review_at)
                    continue
                
                # Update UserLemma
                # Set last_review_time to last exercise end_time (regardless of result)
                user_lemma.last_review_time = last_exercise_end_time
                
                # Determine bin update based on exercise results
                exercise_results = [ex.result for ex in lemma_exercises]
                has_fail = any(ex.result == 'fail' for ex in lemma_exercises)
                has_hint = any(ex.result == 'hint' for ex in lemma_exercises)
                all_success = all(ex.result == 'success' for ex in lemma_exercises)
                
                logger.info(
                    f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: Exercise results - "
                    f"{exercise_results} (has_fail={has_fail}, has_hint={has_hint}, all_success={all_success})"
                )
                
                if has_fail:
                    # Any exercise failed: decrement bin by 2 (min 1)
                    new_bin = max(1, current_bin - 2)
                    bin_change = f"{current_bin} -> {new_bin} (-2)"
                elif has_hint:
                    # Any hint used (but no failures): no change (+0)
                    new_bin = current_bin
                    bin_change = f"{current_bin} -> {new_bin} (+0)"
                elif all_success:
                    # All exercises succeeded: increment bin by 1 (max max_bins)
                    new_bin = min(max_bins, current_bin + 1)
                    bin_change = f"{current_bin} -> {new_bin} (+1)"
                else:
                    # Fallback (shouldn't happen)
                    new_bin = current_bin
                    bin_change = f"{current_bin} -> {new_bin} (no change)"
                
                user_lemma.leitner_bin = new_bin
                
                # Calculate next_review_at based on bin and fibonacci
                if interval_style == 'fibonacci':
                    interval_hours = calculate_fibonacci_interval(new_bin, interval_start_hours)
                else:
                    # Fallback to old Leitner intervals if needed (convert days to hours)
                    bin_index = max(0, min(5, new_bin))
                    interval_days = LEITNER_INTERVALS[bin_index]
                    interval_hours = interval_days * 24  # Convert days to hours
                
                # Use fibonacci interval directly in hours
                new_next_review_at = last_exercise_end_time + timedelta(hours=interval_hours)
                user_lemma.next_review_at = new_next_review_at
                
                logger.info(
                    f"  Lesson {lesson.id}, Lemma {lemma_id_in_lesson}: Updated - bin={bin_change}, "
                    f"last_review_time={last_exercise_end_time}, "
                    f"next_review_at={new_next_review_at} (interval={interval_hours} hours)"
                )
                processed_count += 1
    
    logger.info(
        f"Recompute SRS for user {user_id}: Completed - processed {processed_count} lemma(s) "
        f"across {len(lessons)} lesson(s)"
    )
    return processed_count




