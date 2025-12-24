"""
SRS (Spaced Repetition System) service implementing the Leitner system.

This service handles updating user lemma progress based on exercise results.
"""
from datetime import datetime, timedelta
from typing import List, Optional
from sqlmodel import Session, select
from app.models.user_lemma import UserLemma
from app.models.exercise import Exercise


# Leitner bin review intervals in days
# Bin 0 = 1 day, Bin 1 = 2 days, Bin 2 = 4 days, Bin 3 = 8 days, Bin 4 = 16 days, Bin 5 = 32 days
LEITNER_INTERVALS = [1, 2, 4, 8, 16, 32]
MAX_BIN = 5
MIN_BIN = 0


def calculate_fibonacci_interval(bin_number: int, first_day_interval: int = 1) -> int:
    """
    Calculate review interval in days using Fibonacci sequence.
    
    Fibonacci intervals: Bin 1 = 1 day, Bin 2 = 1 day, Bin 3 = 2 days, 
    Bin 4 = 3 days, Bin 5 = 5 days, Bin 6 = 8 days, Bin 7 = 13 days
    
    Args:
        bin_number: Current bin number (1-based, minimum 1)
        first_day_interval: First day interval (default 1)
    
    Returns:
        Interval in days
    """
    # Ensure bin_number is at least 1
    bin_number = max(1, bin_number)
    
    # Fibonacci sequence: [1, 1, 2, 3, 5, 8, 13, ...]
    # For bins 1-7: [1, 1, 2, 3, 5, 8, 13]
    if bin_number == 1:
        return first_day_interval
    elif bin_number == 2:
        return first_day_interval
    
    # Generate Fibonacci sequence starting from [1, 1]
    fib_prev = first_day_interval  # F(1) = 1
    fib_curr = first_day_interval  # F(2) = 1
    
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
    first_day_interval: int = 1,
    interval_style: str = 'fibonacci',
    max_bins: int = 7
) -> None:
    """
    Update UserLemma SRS fields based on exercises in a specific lesson.
    
    This function:
    - Queries exercises for the user_lemma in the specific lesson
    - Determines if user_lemma is new (no previous exercises before this lesson)
    - Applies bin logic:
      - New user_lemma: set bins to 1
      - Existing + all exercises correct: increment bins +1 (max max_bins)
      - Existing + any exercise failed: decrement bins -2 (min 1)
    - Updates next_review_at using Fibonacci intervals
    - Updates last_success_time if any exercise was successful
    
    Args:
        session: Database session
        user_lemma: UserLemma instance to update
        lesson_id: ID of the lesson to process
        first_day_interval: First day interval (default 1)
        interval_style: Interval style ('fibonacci' or other, default 'fibonacci')
        max_bins: Maximum bin number (default 7)
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
    
    # Collect exercise results from this lesson
    exercise_results = [ex.result for ex in lesson_exercises]
    has_any_fail = 'fail' in exercise_results
    all_correct = not has_any_fail  # All are either 'success' or 'hint'
    
    # Find last success time from lesson exercises
    last_success_time: Optional[datetime] = None
    for exercise in lesson_exercises:
        if exercise.result == 'success':
            if last_success_time is None or exercise.end_time > last_success_time:
                last_success_time = exercise.end_time
    
    # Apply bin logic
    if is_new:
        # New user_lemma: set bins to 1
        new_bin = 1
    elif all_correct:
        # Existing + all exercises correct: increment bins +1 (max max_bins)
        current_bin = user_lemma.leitner_bin if user_lemma.leitner_bin is not None else 0
        new_bin = min(max_bins, current_bin + 1)
    else:
        # Existing + any exercise failed: decrement bins -2 (min 1)
        current_bin = user_lemma.leitner_bin if user_lemma.leitner_bin is not None else 0
        new_bin = max(1, current_bin - 2)
    
    # Update user_lemma fields
    user_lemma.leitner_bin = new_bin
    
    # Update last_success_time if there was any success in this lesson
    if last_success_time:
        if user_lemma.last_success_time is None or last_success_time > user_lemma.last_success_time:
            user_lemma.last_success_time = last_success_time
    
    # Calculate next review time based on new bin using Fibonacci intervals
    # Use last_success_time as base if available, otherwise use the most recent exercise end_time
    if user_lemma.last_success_time:
        base_time = user_lemma.last_success_time
    else:
        # No success time available, use the most recent exercise end_time
        base_time = lesson_exercises[-1].end_time
    
    if interval_style == 'fibonacci':
        interval_days = calculate_fibonacci_interval(new_bin, first_day_interval)
    else:
        # Fallback to old Leitner intervals if needed
        bin_index = max(0, min(5, new_bin))
        interval_days = LEITNER_INTERVALS[bin_index]
    
    # Use 23 hours per day to account for users doing exercises around the same time each day
    user_lemma.next_review_at = base_time + timedelta(hours=interval_days * 23)


def update_user_lemma_srs(
    user_lemma: UserLemma,
    exercise_results: List[str],
    last_success_time: datetime = None
) -> None:
    """
    Update UserLemma SRS fields based on exercise results.
    
    This function aggregates all exercise results for a user lemma and updates:
    - leitner_bin: Based on the overall performance
    - last_success_time: Set if any exercise was successful
    - next_review_at: Calculated based on new bin
    
    Args:
        user_lemma: UserLemma instance to update
        exercise_results: List of exercise result strings ('success', 'hint', 'fail')
        last_success_time: Latest success time from exercises (optional)
    """
    if not exercise_results:
        # No exercises, no update needed
        return
    
    # Determine overall result: if any success, treat as success; otherwise use last result
    has_success = 'success' in exercise_results
    if has_success:
        overall_result = 'success'
    else:
        # Use the last result to determine bin movement
        overall_result = exercise_results[-1]
    
    # Update bin based on overall result
    new_bin = update_leitner_bin(user_lemma.leitner_bin, overall_result)
    user_lemma.leitner_bin = new_bin
    
    # Update last_success_time if there was any success
    if has_success and last_success_time:
        user_lemma.last_success_time = last_success_time
    
    # Calculate next review time based on new bin
    user_lemma.next_review_at = calculate_next_review_at(new_bin)




