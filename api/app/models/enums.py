"""
Model enums.
"""
from enum import Enum


class UserCardStatus(str, Enum):
    """Status enum for UserCard."""
    NEW = "new"
    LEARNING = "learning"
    REVIEW = "review"
    MASTERED = "mastered"


class CEFRLevel(str, Enum):
    """CEFR language proficiency levels."""
    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"
    C2 = "C2"

