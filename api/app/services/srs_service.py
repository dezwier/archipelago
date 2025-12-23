"""
SRS (Spaced Repetition System) service implementing the Leitner system.

This service handles updating user lemma progress based on exercise results.
"""
from datetime import datetime, timedelta
from typing import List
from app.models.user_lemma import UserLemma


# Leitner bin review intervals in days
# Bin 0 = 1 day, Bin 1 = 2 days, Bin 2 = 4 days, Bin 3 = 8 days, Bin 4 = 16 days, Bin 5 = 32 days
LEITNER_INTERVALS = [1, 2, 4, 8, 16, 32]
MAX_BIN = 5
MIN_BIN = 0


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


