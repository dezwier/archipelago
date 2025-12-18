"""
Flashcard schemas.
"""
from pydantic import BaseModel, Field
from typing import List


class FlashcardExportRequest(BaseModel):
    """Request schema for flashcard PDF export."""
    concept_ids: List[int] = Field(..., description="List of concept IDs to export")
    languages_front: List[str] = Field(..., description="Language codes for front side")
    languages_back: List[str] = Field(..., description="Language codes for back side")
    layout: str = Field('a6', description="Page format: 'a4', 'a5', 'a6', or 'a8' (default: 'a6')")
    fit_to_a4: bool = Field(False, description="Whether to fit multiple cards into A4 pages (only valid for A6 and A8)")
    include_image_front: bool = Field(True, description="Whether to include image on front side")
    include_text_front: bool = Field(True, description="Whether to include text (title/term) on front side")
    include_ipa_front: bool = Field(True, description="Whether to include IPA on front side")
    include_description_front: bool = Field(True, description="Whether to include description on front side")
    include_image_back: bool = Field(True, description="Whether to include image on back side")
    include_text_back: bool = Field(True, description="Whether to include text (title/term) on back side")
    include_ipa_back: bool = Field(True, description="Whether to include IPA on back side")
    include_description_back: bool = Field(True, description="Whether to include description on back side")

