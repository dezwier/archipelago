"""
User Lemma statistics endpoints.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select, func
from sqlalchemy import and_, cast, Date
from sqlalchemy.orm import aliased
from typing import Dict, List
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
from app.schemas.filter import StatsSummaryRequest, StatsLeitnerRequest, StatsExercisesDailyRequest
from app.services.filter_service import (
    build_filtered_query,
    get_visible_language_codes,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/user-lemma-stats", tags=["user-lemma-stats"])


@router.post("/summary", response_model=SummaryStatsResponse)
async def get_language_summary_stats(
    request: StatsSummaryRequest,
    session: Session = Depends(get_session)
):
    """
    Get summary statistics for all languages.
    
    Returns lemma counts and exercise counts per language, filtered by the same
    criteria as the dictionary/learn features.
    """
    # Extract user_id from filter_config
    user_id = request.filter_config.user_id
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="user_id is required in filter_config"
        )
    
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Get visible language codes for later use
    visible_language_codes = get_visible_language_codes(request.filter_config)
    
    # Build filtered concept query using FilterConfig
    concept_query = build_filtered_query(request.filter_config)
    
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
    total_time_map: Dict[str, int] = {}
    if language_codes_from_results:
        lesson_query = (
            select(
                lesson_alias.learning_language,
                func.count(func.distinct(lesson_alias.id)).label('lesson_count'),
                func.sum(
                    func.extract('epoch', lesson_alias.end_time - lesson_alias.start_time)
                ).label('total_time_seconds')
            )
            .select_from(lesson_alias)
            .where(
                lesson_alias.user_id == user_id,
                lesson_alias.learning_language.in_(language_codes_from_results),  # type: ignore[attr-defined]
                lesson_alias.start_time.isnot(None),
                lesson_alias.end_time.isnot(None)
            )
            .group_by(lesson_alias.learning_language)
        )
        
        lesson_results = session.exec(lesson_query).all()
        lesson_counts_map = {row.learning_language: row.lesson_count for row in lesson_results}
        total_time_map = {
            row.learning_language: int(row.total_time_seconds or 0) 
            for row in lesson_results
        }
    
    # Build response
    language_stats = [
        LanguageStat(
            language_code=row.language_code,
            lemma_count=row.lemma_count or 0,
            exercise_count=row.exercise_count or 0,
            lesson_count=lesson_counts_map.get(row.language_code, 0),
            total_time_seconds=total_time_map.get(row.language_code, 0)
        )
        for row in results
    ]
    
    return SummaryStatsResponse(language_stats=language_stats)


@router.post("/leitner-distribution", response_model=LeitnerDistributionResponse)
async def get_leitner_distribution(
    request: StatsLeitnerRequest,
    session: Session = Depends(get_session)
):
    """
    Get Leitner bin distribution for a specific language.
    
    Returns the distribution of user_lemmas across Leitner bins (dynamically inferred
    from actual data, not hardcoded to 0-5).
    """
    # Extract user_id from filter_config
    user_id = request.filter_config.user_id
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="user_id is required in filter_config"
        )
    
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Normalize language code
    language_code = request.language_code.lower()
    
    # Update filter_config with language_code
    request.filter_config.visible_languages = language_code
    
    # Build filtered concept query using FilterConfig
    concept_query = build_filtered_query(request.filter_config)
    
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


@router.post("/exercises-daily", response_model=PracticeDailyResponse)
async def get_exercises_daily(
    request: StatsExercisesDailyRequest,
    session: Session = Depends(get_session)
):
    """
    Get practice data per language per day.
    
    Returns the count of exercises, lessons, or lemmas practiced per language per day,
    or minutes spent per language per day, filtered by the same criteria as the dictionary/learn features.
    
    metric_type: 'exercises' (default), 'lessons', 'lemmas', or 'time'
    """
    # Extract user_id from filter_config
    user_id = request.filter_config.user_id
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="user_id is required in filter_config"
        )
    
    # Validate user exists
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    
    # Validate metric_type
    if request.metric_type not in ["exercises", "lessons", "lemmas", "time"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="metric_type must be 'exercises', 'lessons', 'lemmas', or 'time'"
        )
    
    # Get visible language codes for later use
    visible_language_codes = get_visible_language_codes(request.filter_config)
    
    language_data_map: Dict[str, List[PracticeDailyData]] = {}
    
    if request.metric_type == "time":
        # Query: Get total minutes spent per language per day from lessons
        lesson_alias = aliased(Lesson)
        
        time_query = (
            select(
                lesson_alias.learning_language.label('language_code'),
                cast(lesson_alias.end_time, Date).label('practice_date'),
                func.sum(
                    func.extract('epoch', lesson_alias.end_time - lesson_alias.start_time) / 60
                ).label('count')  # Convert seconds to minutes
            )
            .select_from(lesson_alias)
            .where(
                lesson_alias.user_id == user_id,
                lesson_alias.end_time.isnot(None),
                lesson_alias.start_time.isnot(None)
            )
        )
        
        # Apply visible languages filter if provided
        if visible_language_codes:
            time_query = time_query.where(lesson_alias.learning_language.in_(visible_language_codes))  # type: ignore[attr-defined]
        
        time_query = time_query.group_by(
            lesson_alias.learning_language,
            cast(lesson_alias.end_time, Date)
        ).order_by(
            lesson_alias.learning_language,
            cast(lesson_alias.end_time, Date)
        )
        
        # Execute query
        results = session.exec(time_query).all()
        
        # Group results by language_code
        for row in results:
            lang_code = row.language_code
            practice_date = row.practice_date
            count = int(row.count or 0)  # Round to integer minutes
            
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
    
    elif request.metric_type == "lessons":
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
    
    elif request.metric_type == "lemmas":
        # Query: Get distinct lemmas practiced per language per day
        # Join: Concept -> Lemma -> UserLemma -> Exercise
        # Count distinct user_lemma_id per day
        concept_query = build_filtered_query(request.filter_config)
        
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
        concept_query = build_filtered_query(request.filter_config)
        
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

