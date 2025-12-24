"""
User Lemma statistics schemas.
"""
from pydantic import BaseModel
from typing import List


class LanguageStat(BaseModel):
    """Statistics for a single language."""
    language_code: str
    lemma_count: int
    exercise_count: int
    lesson_count: int
    total_time_seconds: int


class SummaryStatsResponse(BaseModel):
    """Response for language summary statistics."""
    language_stats: List[LanguageStat]


class LeitnerBinData(BaseModel):
    """Data for a single Leitner bin."""
    bin: int
    count: int
    count_due: int = 0  # Count of lemmas where next_review_at is before current time
    count_not_due: int = 0  # Count of lemmas where next_review_at is after current time


class LeitnerDistributionResponse(BaseModel):
    """Response for Leitner bin distribution."""
    language_code: str
    distribution: List[LeitnerBinData]


class PracticeDailyData(BaseModel):
    """Data for practice on a single day."""
    date: str  # ISO format date string (YYYY-MM-DD)
    count: int


class LanguagePracticeData(BaseModel):
    """Practice data for a single language."""
    language_code: str
    daily_data: List[PracticeDailyData]


class PracticeDailyResponse(BaseModel):
    """Response for practice per language per day."""
    language_data: List[LanguagePracticeData]


# Keep old names for backward compatibility
ExerciseDailyData = PracticeDailyData
LanguageExerciseData = LanguagePracticeData
ExercisesDailyResponse = PracticeDailyResponse

