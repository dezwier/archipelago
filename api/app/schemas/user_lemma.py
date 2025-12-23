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


class SummaryStatsResponse(BaseModel):
    """Response for language summary statistics."""
    language_stats: List[LanguageStat]


class LeitnerBinData(BaseModel):
    """Data for a single Leitner bin."""
    bin: int
    count: int


class LeitnerDistributionResponse(BaseModel):
    """Response for Leitner bin distribution."""
    language_code: str
    distribution: List[LeitnerBinData]

