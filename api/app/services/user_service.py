"""
User service for business logic related to user operations.
"""
import logging
from sqlmodel import Session, select
from typing import Dict, Any
from sqlalchemy import and_

from app.models.models import User, UserLemma, Exercise, Lesson

logger = logging.getLogger(__name__)


def delete_user_data(
    session: Session,
    user_id: int
) -> Dict[str, Any]:
    """
    Delete all exercises, user_lemmas, and lessons for a user.
    
    This function deletes in the correct order to respect foreign key constraints:
    1. All Exercises (they reference user_lemmas via foreign key)
    2. All UserLemmas (they reference lemmas and users)
    3. All Lessons (they reference users)
    
    Args:
        session: Database session
        user_id: The user ID whose data should be deleted
        
    Returns:
        Dict with counts of deleted items:
        {
            'exercises_deleted': int,
            'user_lemmas_deleted': int,
            'lessons_deleted': int
        }
        
    Raises:
        ValueError: If user not found
    """
    # Verify user exists
    user = session.get(User, user_id)
    if not user:
        raise ValueError(f"User with id {user_id} not found")
    
    # Get all user_lemmas for this user
    user_lemmas = session.exec(
        select(UserLemma).where(UserLemma.user_id == user_id)
    ).all()
    
    user_lemma_ids = [ul.id for ul in user_lemmas]
    
    # 1. Delete all Exercises that reference these user_lemmas
    exercises_deleted = 0
    if user_lemma_ids:
        exercises = session.exec(
            select(Exercise).where(Exercise.user_lemma_id.in_(user_lemma_ids))  # type: ignore
        ).all()
        exercises_deleted = len(exercises)
        for exercise in exercises:
            session.delete(exercise)
    
    # 2. Delete all UserLemmas for this user
    user_lemmas_deleted = len(user_lemmas)
    for user_lemma in user_lemmas:
        session.delete(user_lemma)
    
    # 3. Delete all Lessons for this user
    lessons = session.exec(
        select(Lesson).where(Lesson.user_id == user_id)
    ).all()
    lessons_deleted = len(lessons)
    for lesson in lessons:
        session.delete(lesson)
    
    # Commit all deletions
    session.commit()
    
    logger.info(
        f"Deleted user data for user {user_id}: "
        f"{exercises_deleted} exercises, "
        f"{user_lemmas_deleted} user_lemmas, "
        f"{lessons_deleted} lessons"
    )
    
    return {
        'exercises_deleted': exercises_deleted,
        'user_lemmas_deleted': user_lemmas_deleted,
        'lessons_deleted': lessons_deleted
    }

