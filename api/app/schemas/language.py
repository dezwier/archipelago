from pydantic import BaseModel
from typing import List


class LanguageResponse(BaseModel):
    """Language response schema."""
    code: str
    name: str

    class Config:
        from_attributes = True


class LanguagesResponse(BaseModel):
    """List of languages response schema."""
    languages: List[LanguageResponse]

