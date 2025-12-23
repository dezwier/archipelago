"""
Lesson completion schemas.
"""
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class ExerciseData(BaseModel):
    """Exercise data for lesson completion."""
    lemma_id: int = Field(..., description="Lemma ID for this exercise")
    exercise_type: str = Field(..., description="Exercise type in snake_case (e.g., 'match_info_image')")
    result: str = Field(..., description="Exercise result: 'success', 'hint', or 'fail'")
    start_time: datetime = Field(..., description="Exercise start time")
    end_time: datetime = Field(..., description="Exercise end time")
    
    class Config:
        json_schema_extra = {
            "example": {
                "lemma_id": 123,
                "exercise_type": "match_info_image",
                "result": "success",
                "start_time": "2024-01-01T10:00:00Z",
                "end_time": "2024-01-01T10:00:30Z"
            }
        }


class UserLemmaUpdate(BaseModel):
    """UserLemma update data for lesson completion."""
    lemma_id: int = Field(..., description="Lemma ID")
    last_success_time: Optional[datetime] = Field(None, description="Latest success time if any exercise succeeded")
    leitner_bin: int = Field(..., description="Updated Leitner bin (0-5)")
    next_review_at: Optional[datetime] = Field(None, description="Next review time")
    
    class Config:
        json_schema_extra = {
            "example": {
                "lemma_id": 123,
                "last_success_time": "2024-01-01T10:00:30Z",
                "leitner_bin": 1,
                "next_review_at": "2024-01-03T10:00:30Z"
            }
        }


class CompleteLessonRequest(BaseModel):
    """Request to complete a lesson."""
    user_id: int = Field(..., description="User ID")
    exercises: List[ExerciseData] = Field(..., description="List of exercises completed (excluding discovery/summary)")
    user_lemmas: List[UserLemmaUpdate] = Field(..., description="List of user lemma updates")
    
    class Config:
        json_schema_extra = {
            "example": {
                "user_id": 1,
                "exercises": [
                    {
                        "lemma_id": 123,
                        "exercise_type": "match_info_image",
                        "result": "success",
                        "start_time": "2024-01-01T10:00:00Z",
                        "end_time": "2024-01-01T10:00:30Z"
                    }
                ],
                "user_lemmas": [
                    {
                        "lemma_id": 123,
                        "last_success_time": "2024-01-01T10:00:30Z",
                        "leitner_bin": 1,
                        "next_review_at": "2024-01-03T10:00:30Z"
                    }
                ]
            }
        }


class CompleteLessonResponse(BaseModel):
    """Response from lesson completion."""
    message: str = Field(..., description="Success message")
    created_exercises_count: int = Field(..., description="Number of exercise records created")
    updated_user_lemmas_count: int = Field(..., description="Number of user lemma records updated/created")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message": "Lesson completed successfully",
                "created_exercises_count": 5,
                "updated_user_lemmas_count": 3
            }
        }



