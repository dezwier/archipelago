"""
User Lemma statistics endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlmodel import Session, select, func
from sqlalchemy import and_, cast, Date
from sqlalchemy.orm import aliased
from typing import Optional, Dict, List
from datetime import date, datetime
import logging

from app.core.database import get_session
from app.models.models import Lemma, UserLemma, Exercise, User, Lesson
from app.schemas.user_lemma import (
    SummaryStatsResponse,
    LanguageStat,
    LeitnerDistributionResponse,
    LeitnerBinData,
    PracticeDailyResponse,
    LanguagePracticeData,
    PracticeDailyData
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
    
    # Query: Get lesson counts per language
    # Join: Lesson -> filter by learning_language matching lemma language_code
    lesson_alias = aliased(Lesson)
    
    # Get all language codes from results
    language_codes_from_results = [row.language_code for row in results]
    
    lesson_counts_map: Dict[str, int] = {}
    if language_codes_from_results:
        lesson_query = (
            select(
                lesson_alias.learning_language,
                func.count(func.distinct(lesson_alias.id)).label('lesson_count')
            )
            .select_from(lesson_alias)
            .where(
                lesson_alias.user_id == user_id,
                lesson_alias.learning_language.in_(language_codes_from_results)  # type: ignore[attr-defined]
            )
            .group_by(lesson_alias.learning_language)
        )
        
        lesson_results = session.exec(lesson_query).all()
        lesson_counts_map = {row.learning_language: row.lesson_count for row in lesson_results}
    
    # Build response
    language_stats = [
        LanguageStat(
            language_code=row.language_code,
            lemma_count=row.lemma_count or 0,
            exercise_count=row.exercise_count or 0,
            lesson_count=lesson_counts_map.get(row.language_code, 0)
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


@router.get("/exercises-daily", response_model=PracticeDailyResponse)
async def get_exercises_daily(
    user_id: int = Query(..., description="User ID"),
    metric_type: str = Query("exercises", description="Metric type: 'exercises', 'lessons', or 'lemmas'"),
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
    Get practice data per language per day.
    
    Returns the count of exercises, lessons, or lemmas practiced per language per day,
    filtered by the same criteria as the dictionary/learn features.
    
    metric_type: 'exercises' (default), 'lessons', or 'lemmas'
    """
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Validate metric_type
    if metric_type not in ["exercises", "lessons", "lemmas"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="metric_type must be 'exercises', 'lessons', or 'lemmas'"
        )
    
    # Parse filter parameters
    visible_language_codes = parse_visible_languages(visible_languages)
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    language_data_map: Dict[str, List[PracticeDailyData]] = {}
    
    if metric_type == "lessons":
        # Query: Get lessons per language per day
        lesson_alias = aliased(Lesson)
        
        lessons_query = (
            select(
                lesson_alias.learning_language.label('language_code'),
                cast(lesson_alias.end_time, Date).label('practice_date'),
                func.count(func.distinct(lesson_alias.id)).label('count')
            )
            .select_from(lesson_alias)
            .where(
                lesson_alias.user_id == user_id,
                lesson_alias.end_time.isnot(None)
            )
        )
        
        # Apply visible languages filter if provided
        if visible_language_codes:
            lessons_query = lessons_query.where(lesson_alias.learning_language.in_(visible_language_codes))  # type: ignore[attr-defined]
        
        lessons_query = lessons_query.group_by(
            lesson_alias.learning_language,
            cast(lesson_alias.end_time, Date)
        ).order_by(
            lesson_alias.learning_language,
            cast(lesson_alias.end_time, Date)
        )
        
        # Execute query
        results = session.exec(lessons_query).all()
        
        # Group results by language_code
        for row in results:
            lang_code = row.language_code
            practice_date = row.practice_date
            count = row.count
            
            # Convert date to ISO format string
            if isinstance(practice_date, date):
                date_str = practice_date.isoformat()
            elif isinstance(practice_date, datetime):
                date_str = practice_date.date().isoformat()
            else:
                date_str = str(practice_date)
            
            if lang_code not in language_data_map:
                language_data_map[lang_code] = []
            
            language_data_map[lang_code].append(
                PracticeDailyData(date=date_str, count=count)
            )
    
    elif metric_type == "lemmas":
        # Query: Get distinct lemmas practiced per language per day
        # Join: Concept -> Lemma -> UserLemma -> Exercise
        # Count distinct user_lemma_id per day
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
        
        lemma_alias3 = aliased(Lemma)
        user_lemma_alias3 = aliased(UserLemma)
        exercise_alias3 = aliased(Exercise)
        
        lemmas_query = (
            select(
                lemma_alias3.language_code,
                cast(exercise_alias3.end_time, Date).label('practice_date'),
                func.count(func.distinct(user_lemma_alias3.id)).label('count')
            )
            .select_from(lemma_alias3)
            .join(
                user_lemma_alias3,
                and_(
                    user_lemma_alias3.lemma_id == lemma_alias3.id,
                    user_lemma_alias3.user_id == user_id
                )
            )
            .join(
                exercise_alias3,
                exercise_alias3.user_lemma_id == user_lemma_alias3.id
            )
            .where(
                lemma_alias3.concept_id.in_(filtered_concept_ids),  # type: ignore[attr-defined]
                lemma_alias3.term.isnot(None),
                lemma_alias3.term != "",
                exercise_alias3.end_time.isnot(None)
            )
        )
        
        # Apply visible languages filter if provided
        if visible_language_codes:
            lemmas_query = lemmas_query.where(lemma_alias3.language_code.in_(visible_language_codes))  # type: ignore[attr-defined]
        
        lemmas_query = lemmas_query.group_by(
            lemma_alias3.language_code,
            cast(exercise_alias3.end_time, Date)
        ).order_by(
            lemma_alias3.language_code,
            cast(exercise_alias3.end_time, Date)
        )
        
        # Execute query
        results = session.exec(lemmas_query).all()
        
        # Group results by language_code
        for row in results:
            lang_code = row.language_code
            practice_date = row.practice_date
            count = row.count
            
            # Convert date to ISO format string
            if isinstance(practice_date, date):
                date_str = practice_date.isoformat()
            elif isinstance(practice_date, datetime):
                date_str = practice_date.date().isoformat()
            else:
                date_str = str(practice_date)
            
            if lang_code not in language_data_map:
                language_data_map[lang_code] = []
            
            language_data_map[lang_code].append(
                PracticeDailyData(date=date_str, count=count)
            )
    
    else:  # metric_type == "exercises" (default)
        # Query: Get exercises per language per day
        # Join: Concept -> Lemma -> UserLemma -> Exercise
        # Group by language_code and date (cast end_time to date)
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
        
        lemma_alias3 = aliased(Lemma)
        user_lemma_alias3 = aliased(UserLemma)
        exercise_alias3 = aliased(Exercise)
        
        exercises_query = (
            select(
                lemma_alias3.language_code,
                cast(exercise_alias3.end_time, Date).label('practice_date'),
                func.count(exercise_alias3.id).label('count')
            )
            .select_from(lemma_alias3)
            .join(
                user_lemma_alias3,
                and_(
                    user_lemma_alias3.lemma_id == lemma_alias3.id,
                    user_lemma_alias3.user_id == user_id
                )
            )
            .join(
                exercise_alias3,
                exercise_alias3.user_lemma_id == user_lemma_alias3.id
            )
            .where(
                lemma_alias3.concept_id.in_(filtered_concept_ids),  # type: ignore[attr-defined]
                lemma_alias3.term.isnot(None),
                lemma_alias3.term != "",
                exercise_alias3.end_time.isnot(None)
            )
        )
        
        # Apply visible languages filter if provided
        if visible_language_codes:
            exercises_query = exercises_query.where(lemma_alias3.language_code.in_(visible_language_codes))  # type: ignore[attr-defined]
        
        exercises_query = exercises_query.group_by(
            lemma_alias3.language_code,
            cast(exercise_alias3.end_time, Date)
        ).order_by(
            lemma_alias3.language_code,
            cast(exercise_alias3.end_time, Date)
        )
        
        # Execute query
        results = session.exec(exercises_query).all()
        
        # Group results by language_code
        for row in results:
            lang_code = row.language_code
            practice_date = row.practice_date
            count = row.count
            
            # Convert date to ISO format string
            if isinstance(practice_date, date):
                date_str = practice_date.isoformat()
            elif isinstance(practice_date, datetime):
                date_str = practice_date.date().isoformat()
            else:
                date_str = str(practice_date)
            
            if lang_code not in language_data_map:
                language_data_map[lang_code] = []
            
            language_data_map[lang_code].append(
                PracticeDailyData(date=date_str, count=count)
            )
    
    # Build response
    language_data = [
        LanguagePracticeData(
            language_code=lang_code,
            daily_data=daily_data
        )
        for lang_code, daily_data in sorted(language_data_map.items())
    ]
    
    return PracticeDailyResponse(language_data=language_data)

