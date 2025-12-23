"""
User Lemma statistics endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func
from sqlalchemy import and_
from sqlalchemy.orm import aliased
from typing import Optional, List, Dict
import logging

from app.core.database import get_session
from app.models.models import Concept, Lemma, UserLemma, Exercise, User
from app.schemas.user_lemma import (
    SummaryStatsResponse,
    LanguageStat,
    LeitnerDistributionResponse,
    LeitnerBinData
)
from app.services.dictionary_service import (
    parse_visible_languages,
    parse_topic_ids,
    parse_levels,
    parse_part_of_speech,
    build_base_filtered_query,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/user-lemma-stats", tags=["user-lemma-stats"])


@router.get("/summary", response_model=SummaryStatsResponse)
async def get_language_summary_stats(
    user_id: int = Query(..., description="User ID"),
    visible_languages: Optional[str] = Query(None, description="Comma-separated list of visible language codes"),
    include_lemmas: bool = Query(True, description="Include lemmas"),
    include_phrases: bool = Query(True, description="Include phrases"),
    topic_ids: Optional[str] = Query(None, description="Comma-separated list of topic IDs"),
    include_without_topic: bool = Query(True, description="Include concepts without a topic"),
    levels: Optional[str] = Query(None, description="Comma-separated list of CEFR levels"),
    part_of_speech: Optional[str] = Query(None, description="Comma-separated list of part of speech values"),
    has_images: Optional[int] = Query(None, description="1 = with images, 0 = without images, null = all"),
    has_audio: Optional[int] = Query(None, description="1 = with audio, 0 = without audio, null = all"),
    is_complete: Optional[int] = Query(None, description="1 = complete, 0 = incomplete, null = all"),
    search: Optional[str] = Query(None, description="Search query"),
    session: Session = Depends(get_session)
):
    """
    Get summary statistics for all languages.
    
    Returns lemma counts and exercise counts per language, filtered by the same
    criteria as the dictionary/learn features.
    """
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Parse filter parameters
    visible_language_codes = parse_visible_languages(visible_languages)
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    # Build base filtered concept query
    concept_query = build_base_filtered_query(
        user_id=user_id,
        include_lemmas=include_lemmas,
        include_phrases=include_phrases,
        topic_id_list=topic_id_list,
        include_without_topic=include_without_topic,
        level_list=level_list,
        pos_list=pos_list,
        has_images=has_images,
        has_audio=has_audio,
        is_complete=is_complete,
        visible_language_codes=visible_language_codes,
        search=search
    )
    
    # Get filtered concept IDs
    filtered_concept_ids_subquery = concept_query.subquery()
    filtered_concept_ids = select(filtered_concept_ids_subquery.c.id)
    
    # Query: Get lemma counts and exercise counts per language
    # Join: Concept -> Lemma -> UserLemma -> Exercise
    lemma_alias = aliased(Lemma)
    user_lemma_alias = aliased(UserLemma)
    exercise_alias = aliased(Exercise)
    
    stats_query = (
        select(
            lemma_alias.language_code,
            func.count(func.distinct(user_lemma_alias.id)).label('lemma_count'),
            func.count(func.distinct(exercise_alias.id)).label('exercise_count')
        )
        .select_from(lemma_alias)
        .join(
            user_lemma_alias,
            and_(
                user_lemma_alias.lemma_id == lemma_alias.id,
                user_lemma_alias.user_id == user_id
            )
        )
        .outerjoin(
            exercise_alias,
            exercise_alias.user_lemma_id == user_lemma_alias.id
        )
        .where(
            lemma_alias.concept_id.in_(filtered_concept_ids),  # type: ignore[attr-defined]
            lemma_alias.term.isnot(None),
            lemma_alias.term != ""
        )
    )
    
    # Apply visible languages filter if provided
    if visible_language_codes:
        stats_query = stats_query.where(lemma_alias.language_code.in_(visible_language_codes))  # type: ignore[attr-defined]
    
    stats_query = stats_query.group_by(lemma_alias.language_code)
    
    # Execute query
    results = session.exec(stats_query).all()
    
    # Build response
    language_stats = [
        LanguageStat(
            language_code=row.language_code,
            lemma_count=row.lemma_count or 0,
            exercise_count=row.exercise_count or 0
        )
        for row in results
    ]
    
    return SummaryStatsResponse(language_stats=language_stats)


@router.get("/leitner-distribution", response_model=LeitnerDistributionResponse)
async def get_leitner_distribution(
    user_id: int = Query(..., description="User ID"),
    language_code: str = Query(..., description="Learning language code"),
    include_lemmas: bool = Query(True, description="Include lemmas"),
    include_phrases: bool = Query(True, description="Include phrases"),
    topic_ids: Optional[str] = Query(None, description="Comma-separated list of topic IDs"),
    include_without_topic: bool = Query(True, description="Include concepts without a topic"),
    levels: Optional[str] = Query(None, description="Comma-separated list of CEFR levels"),
    part_of_speech: Optional[str] = Query(None, description="Comma-separated list of part of speech values"),
    has_images: Optional[int] = Query(None, description="1 = with images, 0 = without images, null = all"),
    has_audio: Optional[int] = Query(None, description="1 = with audio, 0 = without audio, null = all"),
    is_complete: Optional[int] = Query(None, description="1 = complete, 0 = incomplete, null = all"),
    search: Optional[str] = Query(None, description="Search query"),
    session: Session = Depends(get_session)
):
    """
    Get Leitner bin distribution for a specific language.
    
    Returns the distribution of user_lemmas across Leitner bins (dynamically inferred
    from actual data, not hardcoded to 0-5).
    """
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Normalize language code
    language_code = language_code.lower()
    
    # Parse filter parameters
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    # Build base filtered concept query
    concept_query = build_base_filtered_query(
        user_id=user_id,
        include_lemmas=include_lemmas,
        include_phrases=include_phrases,
        topic_id_list=topic_id_list,
        include_without_topic=include_without_topic,
        level_list=level_list,
        pos_list=pos_list,
        has_images=has_images,
        has_audio=has_audio,
        is_complete=is_complete,
        visible_language_codes=[language_code],
        search=search
    )
    
    # Get filtered concept IDs
    filtered_concept_ids_subquery = concept_query.subquery()
    filtered_concept_ids = select(filtered_concept_ids_subquery.c.id)
    
    # Query: Get Leitner bin distribution
    # Join: Concept -> Lemma -> UserLemma
    lemma_alias2 = aliased(Lemma)
    user_lemma_alias2 = aliased(UserLemma)
    
    distribution_query = (
        select(
            user_lemma_alias2.leitner_bin,
            func.count(user_lemma_alias2.id).label('count')
        )
        .select_from(lemma_alias2)
        .join(
            user_lemma_alias2,
            and_(
                user_lemma_alias2.lemma_id == lemma_alias2.id,
                user_lemma_alias2.user_id == user_id
            )
        )
        .where(
            lemma_alias2.concept_id.in_(filtered_concept_ids),  # type: ignore[attr-defined]
            lemma_alias2.language_code == language_code,
            lemma_alias2.term.isnot(None),
            lemma_alias2.term != ""
        )
        .group_by(user_lemma_alias2.leitner_bin)
        .order_by(user_lemma_alias2.leitner_bin)
    )
    
    # Execute query
    results = session.exec(distribution_query).all()
    
    # Build response - dynamically infer bins from data
    distribution = [
        LeitnerBinData(
            bin=row.leitner_bin,
            count=row.count
        )
        for row in results
    ]
    
    return LeitnerDistributionResponse(
        language_code=language_code,
        distribution=distribution
    )

