from fastapi import APIRouter, Depends
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import Language
from app.schemas.language import LanguagesResponse, LanguageResponse

router = APIRouter(prefix="/languages", tags=["languages"])


@router.get("", response_model=LanguagesResponse)
async def get_languages(
    session: Session = Depends(get_session)
):
    """Get all available languages."""
    languages = session.exec(select(Language)).all()
    return LanguagesResponse(
        languages=[LanguageResponse(code=lang.code, name=lang.name) for lang in languages]
    )

