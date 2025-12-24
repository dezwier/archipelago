"""
Filter configuration schema for concept filtering across endpoints.
"""
from pydantic import BaseModel
from typing import Optional


class FilterConfig(BaseModel):
    """Filter configuration for concept queries.
    
    This config groups all filter parameters used across dictionary,
    lesson generation, and statistics endpoints.
    """
    user_id: Optional[int] = None
    visible_languages: Optional[str] = None  # Comma-separated list of visible language codes
    include_lemmas: bool = True  # Include lemmas (concept.is_phrase is False)
    include_phrases: bool = True  # Include phrases (concept.is_phrase is True)
    topic_ids: Optional[str] = None  # Comma-separated list of topic IDs to filter by
    include_without_topic: bool = True  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None  # Comma-separated list of part of speech values to filter by
    has_images: Optional[int] = None  # 1 = include only concepts with images, 0 = include only concepts without images, null = include all
    has_audio: Optional[int] = None  # 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
    is_complete: Optional[int] = None  # 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    search: Optional[str] = None  # Optional search query for concept.term and lemma.term

    class Config:
        """Pydantic config."""
        json_schema_extra = {
            "example": {
                "user_id": 1,
                "visible_languages": "en,es",
                "include_lemmas": True,
                "include_phrases": True,
                "topic_ids": "1,2,3",
                "include_without_topic": True,
                "levels": "A1,A2",
                "part_of_speech": "noun,verb",
                "has_images": 1,
                "has_audio": 0,
                "is_complete": 1,
                "search": "hello"
            }
        }


class DictionaryFilterRequest(BaseModel):
    """Request model for dictionary endpoint."""
    filter_config: FilterConfig
    page: int = 1
    page_size: int = 20
    sort_by: str = "alphabetical"  # Options: "alphabetical", "recent", "random"


class LessonGenerateRequest(BaseModel):
    """Request model for lesson generation endpoint."""
    filter_config: FilterConfig
    language: str  # Learning language
    native_language: Optional[str] = None  # Native language (optional, will use user's if not provided)
    max_n: Optional[int] = None  # Randomly select n concepts to return
    include_with_user_lemma: bool = False  # Include concepts that have a user lemma for the user
    include_without_user_lemma: bool = True  # Include concepts that don't have a user lemma for the user


class StatsSummaryRequest(BaseModel):
    """Request model for stats summary endpoint."""
    filter_config: FilterConfig


class StatsLeitnerRequest(BaseModel):
    """Request model for Leitner distribution stats endpoint."""
    filter_config: FilterConfig
    language_code: str  # Learning language code


class StatsExercisesDailyRequest(BaseModel):
    """Request model for exercises daily stats endpoint."""
    filter_config: FilterConfig
    metric_type: str = "exercises"  # Options: "exercises", "lessons", "lemmas", "time"

