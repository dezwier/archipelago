"""
Models module - re-exports all models for backward compatibility.

This module maintains backward compatibility for imports like:
    from app.models.models import Concept

All models are now in separate files in the models package.
"""
# Re-export everything from the models package
from app.models.enums import UserCardStatus, CEFRLevel
from app.models.topic import Topic
from app.models.image import Image
from app.models.concept import Concept
from app.models.language import Language
from app.models.lemma import Lemma
from app.models.user import User
from app.models.user_card import UserCard
from app.models.user_practice import UserPractice

__all__ = [
    'UserCardStatus',
    'CEFRLevel',
    'Topic',
    'Image',
    'Concept',
    'Language',
    'Lemma',
    'User',
    'UserCard',
    'UserPractice',
]
