"""
API v1 router aggregation.
"""
from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth, languages, dictionary, concepts, lemma, topics,
    lemma_generation, concept_image, lemma_audio, flashcard_export, lessons
)

api_router = APIRouter()

# Include all endpoint routers
# Note: Each router already defines its own prefix, so we don't add another one here
api_router.include_router(auth.router)
api_router.include_router(languages.router)
api_router.include_router(dictionary.router)
api_router.include_router(concepts.router)
api_router.include_router(lemma.router)
api_router.include_router(topics.router)
api_router.include_router(lemma_generation.router)
api_router.include_router(concept_image.router)
api_router.include_router(lemma_audio.router)
api_router.include_router(flashcard_export.router)
api_router.include_router(lessons.router)

