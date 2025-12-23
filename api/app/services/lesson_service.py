"""
Lesson generation service for creating lessons with concepts and lemmas.
"""
# pyright: reportAttributeAccessIssue=false
# pyright: reportCallIssue=false
# pyright: reportArgumentType=false
from sqlmodel import Session, select
from sqlalchemy import func, and_, or_
from typing import Optional
import logging
import random

from app.models.models import Concept, Lemma, UserLemma, User
from app.schemas.lemma import NewCardsResponse, ConceptWithLemmas, LemmaResponse
from app.utils.text_utils import ensure_capitalized
from app.services.lemma_service import validate_language_codes
from app.services.dictionary_service import (
    parse_topic_ids,
    parse_levels,
    parse_part_of_speech,
    build_base_filtered_query,
)

logger = logging.getLogger(__name__)


def generate_lesson_concepts(
    session: Session,
    user_id: int,
    language: str,  # Learning language
    native_language: Optional[str] = None,  # Native language (optional, will use user's if not provided)
    max_n: Optional[int] = None,  # Randomly select n concepts to return
    search: Optional[str] = None,  # Optional search query for concept.term and lemma.term
    include_lemmas: bool = True,  # Include lemmas (concept.is_phrase is False)
    include_phrases: bool = True,  # Include phrases (concept.is_phrase is True)
    topic_ids: Optional[str] = None,  # Comma-separated list of topic IDs to filter by
    include_without_topic: bool = True,  # Include concepts without a topic (topic_id is null)
    levels: Optional[str] = None,  # Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
    part_of_speech: Optional[str] = None,  # Comma-separated list of part of speech values to filter by
    has_images: Optional[int] = None,  # 1 = include only concepts with images, 0 = include only concepts without images, null = include all
    has_audio: Optional[int] = None,  # 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
    is_complete: Optional[int] = None,  # 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
    include_with_user_lemma: bool = False,  # Include concepts that have a user lemma for the user
    include_without_user_lemma: bool = True,  # Include concepts that don't have a user lemma for the user
) -> NewCardsResponse:
    """
    Generate lesson concepts based on filters and user_lemma inclusion criteria.
    
    Filters concepts using the same parameters as the dictionary endpoint.
    Only returns concepts that have lemmas in both native and learning languages.
    Returns concepts with both learning and native language lemmas coupled together.
    
    Args:
        session: Database session
        user_id: The user ID (required)
        language: Learning language code (required)
        native_language: Native language code (optional, will use user's native language if not provided)
        max_n: Optional maximum number of concepts to randomly return. If not provided, returns all matching concepts.
        search: Optional search query to filter by concept.term and lemma.term
        include_lemmas: Include lemmas (concept.is_phrase is False)
        include_phrases: Include phrases (concept.is_phrase is True)
        topic_ids: Comma-separated list of topic IDs to filter by
        include_without_topic: Include concepts without a topic (topic_id is null)
        levels: Comma-separated list of CEFR levels (A1, A2, B1, B2, C1, C2) to filter by
        part_of_speech: Comma-separated list of part of speech values to filter by
        has_images: 1 = include only concepts with images, 0 = include only concepts without images, null = include all
        has_audio: 1 = include only concepts with audio, 0 = include only concepts without audio, null = include all
        is_complete: 1 = include only complete concepts, 0 = include only incomplete concepts, null = include all
        include_with_user_lemma: Include concepts that have a user lemma for the user
        include_without_user_lemma: Include concepts that don't have a user lemma for the user
    
    Returns:
        NewCardsResponse containing concepts with both native and learning language lemmas
    """
    learning_language_code = language.lower()
    
    # Validate learning language code exists
    validate_language_codes(session, [learning_language_code])
    
    # Get user to retrieve native language if not provided
    user = session.get(User, user_id)
    if not user:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Use provided native_language or fall back to user's native language
    native_language_code = (native_language or user.lang_native).lower()
    
    # Validate native language code exists
    validate_language_codes(session, [native_language_code])
    
    # Validate max_n if provided
    if max_n is not None and max_n < 1:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="max_n must be >= 1"
        )
    
    # Validate that at least one inclusion parameter is True
    if not include_with_user_lemma and not include_without_user_lemma:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one of include_with_user_lemma or include_without_user_lemma must be True"
        )
    
    # Count 0: Total concepts visible to user (before any filtering)
    # Count public concepts (user_id IS NULL) OR concepts belonging to this user
    total_concepts_query = select(func.count(Concept.id)).where(
        or_(
            Concept.user_id.is_(None),
            Concept.user_id == user_id
        )
    )
    total_concepts_count = session.exec(total_concepts_query).one()
    
    # Parse filter parameters (same as dictionary endpoint)
    topic_id_list = parse_topic_ids(topic_ids)
    level_list = parse_levels(levels)
    pos_list = parse_part_of_speech(part_of_speech)
    
    # Set visible_languages to [native_language, learning_language] for filtering
    visible_language_codes = [native_language_code, learning_language_code]
    
    # Log filter parameters for debugging
    logger.info(
        "generate_lesson_concepts: user_id=%s, language=%s, include_lemmas=%s, include_phrases=%s, topic_ids=%s, include_without_topic=%s, include_with_user_lemma=%s, include_without_user_lemma=%s",
        user_id, learning_language_code, include_lemmas, include_phrases, topic_ids, include_without_topic, include_with_user_lemma, include_without_user_lemma
    )
    
    # Build base filtered query using dictionary logic
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
    
    # Execute query to get filtered concepts
    filtered_concepts = session.exec(concept_query).all()
    
    # Deduplicate concepts by ID (in case join created duplicates)
    seen_concept_ids = set()
    unique_concepts = []
    for concept in filtered_concepts:
        if concept.id not in seen_concept_ids:
            seen_concept_ids.add(concept.id)
            unique_concepts.append(concept)
    filtered_concepts = unique_concepts
    
    concept_ids = [c.id for c in filtered_concepts]
    
    # Count 1: Concepts after dictionary filtering
    filtered_concepts_count = len(filtered_concepts)
    logger.info("After dictionary filtering: %s concepts found", filtered_concepts_count)
    
    if not concept_ids:
        return NewCardsResponse(
            concepts=[],
            native_language=user.lang_native,
            total_concepts_count=total_concepts_count,
            filtered_concepts_count=filtered_concepts_count,
            concepts_with_both_languages_count=0,
            concepts_without_cards_count=0
        )
    
    # Get lemmas for these concepts in both native and learning languages
    lemmas_query = (
        select(Lemma)
        .where(
            Lemma.concept_id.in_(concept_ids),  # type: ignore[attr-defined]
            Lemma.language_code.in_([native_language_code, learning_language_code]),
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
    )
    all_lemmas = session.exec(lemmas_query).all()
    
    # Group lemmas by concept_id and language_code
    concept_lemmas_map = {}
    for lemma in all_lemmas:
        if lemma.concept_id not in concept_lemmas_map:
            concept_lemmas_map[lemma.concept_id] = {}
        concept_lemmas_map[lemma.concept_id][lemma.language_code] = lemma
    
    # Filter to concepts that have lemmas in both languages
    concepts_with_both_languages = []
    for concept in filtered_concepts:
        lemmas = concept_lemmas_map.get(concept.id, {})
        if native_language_code in lemmas and learning_language_code in lemmas:
            concepts_with_both_languages.append(concept)
    
    # Count 2: Concepts with lemmas in both languages
    concepts_with_both_languages_count = len(concepts_with_both_languages)
    logger.info("Concepts with lemmas in both languages: %s", concepts_with_both_languages_count)
    
    if not concepts_with_both_languages:
        return NewCardsResponse(
            concepts=[],
            native_language=user.lang_native,
            total_concepts_count=total_concepts_count,
            filtered_concepts_count=filtered_concepts_count,
            concepts_with_both_languages_count=concepts_with_both_languages_count,
            concepts_without_cards_count=0
        )
    
    # Get learning language lemmas for concepts with both languages
    learning_concept_ids = [c.id for c in concepts_with_both_languages]
    
    # Build queries for lemmas with and without user_lemma based on parameters
    learning_lemmas_without = []
    learning_lemmas_with = []
    
    if include_without_user_lemma:
        # Query for lemmas WITHOUT user_lemma
        learning_lemmas_query_without = (
            select(Lemma)
            .outerjoin(
                UserLemma,
                and_(
                    UserLemma.lemma_id == Lemma.id,
                    UserLemma.user_id == user_id
                )
            )
            .where(
                Lemma.concept_id.in_(learning_concept_ids),  # type: ignore[attr-defined]
                Lemma.language_code == learning_language_code,
                Lemma.term.isnot(None),
                Lemma.term != "",
                UserLemma.id.is_(None)  # type: ignore[attr-defined] # No user_lemma exists for this user
            )
        )
        learning_lemmas_without = session.exec(learning_lemmas_query_without).all()
    
    if include_with_user_lemma:
        # Query for lemmas WITH user_lemma
        learning_lemmas_query_with = (
            select(Lemma)
            .join(
                UserLemma,
                and_(
                    UserLemma.lemma_id == Lemma.id,
                    UserLemma.user_id == user_id
                )
            )
            .where(
                Lemma.concept_id.in_(learning_concept_ids),  # type: ignore[attr-defined]
                Lemma.language_code == learning_language_code,
                Lemma.term.isnot(None),
                Lemma.term != ""
            )
        )
        learning_lemmas_with = session.exec(learning_lemmas_query_with).all()
    
    # Combine learning lemmas from both queries
    learning_lemmas = list(learning_lemmas_without) + list(learning_lemmas_with)
    
    # Get unique concept IDs from learning lemmas
    eligible_concept_ids = list({lemma.concept_id for lemma in learning_lemmas})
    
    # Count 3: Concepts matching user_lemma criteria
    concepts_without_cards_count = len(eligible_concept_ids)
    logger.info("Concepts matching user_lemma criteria: %s", concepts_without_cards_count)
    
    # Randomly select n concepts if max_n is provided
    if max_n is not None and len(eligible_concept_ids) > max_n:
        eligible_concept_ids = random.sample(eligible_concept_ids, max_n)
    
    # Filter learning lemmas to only those from selected concepts
    selected_concept_ids = set(eligible_concept_ids)
    learning_lemmas = [lemma for lemma in learning_lemmas if lemma.concept_id in selected_concept_ids]
    
    # Get native language lemmas for the selected concepts
    native_lemmas_query = (
        select(Lemma)
        .where(
            Lemma.concept_id.in_(eligible_concept_ids),  # type: ignore[attr-defined]
            Lemma.language_code == native_language_code,
            Lemma.term.isnot(None),
            Lemma.term != ""
        )
    )
    native_lemmas = session.exec(native_lemmas_query).all()
    
    # Create maps for quick lookup
    native_lemma_map = {lemma.concept_id: lemma for lemma in native_lemmas}
    concept_map = {concept.id: concept for concept in concepts_with_both_languages if concept.id in selected_concept_ids}
    
    # Build response - each item is a concept with both lemmas
    concept_responses = []
    for learning_lemma in learning_lemmas:
        # Create learning language lemma response
        learning_lemma_response = LemmaResponse(
            id=learning_lemma.id,
            concept_id=learning_lemma.concept_id,
            language_code=learning_lemma.language_code,
            translation=ensure_capitalized(learning_lemma.term),
            description=learning_lemma.description,
            ipa=learning_lemma.ipa,
            audio_path=learning_lemma.audio_url,
            gender=learning_lemma.gender,
            article=learning_lemma.article,
            plural_form=learning_lemma.plural_form,
            verb_type=learning_lemma.verb_type,
            auxiliary_verb=learning_lemma.auxiliary_verb,
            formality_register=learning_lemma.formality_register,
            notes=learning_lemma.notes
        )
        
        # Get native language lemma (should always exist since we filtered for both languages)
        native_lemma = native_lemma_map.get(learning_lemma.concept_id)
        native_lemma_response = None
        if native_lemma:
            native_lemma_response = LemmaResponse(
                id=native_lemma.id,
                concept_id=native_lemma.concept_id,
                language_code=native_lemma.language_code,
                translation=ensure_capitalized(native_lemma.term),
                description=native_lemma.description,
                ipa=native_lemma.ipa,
                audio_path=native_lemma.audio_url,
                gender=native_lemma.gender,
                article=native_lemma.article,
                plural_form=native_lemma.plural_form,
                verb_type=native_lemma.verb_type,
                auxiliary_verb=native_lemma.auxiliary_verb,
                formality_register=native_lemma.formality_register,
                notes=native_lemma.notes
            )
        
        # Get concept to retrieve image_url
        concept = concept_map.get(learning_lemma.concept_id)
        image_url = concept.image_url if concept else None
        
        # Create concept with both lemmas
        concept_responses.append(
            ConceptWithLemmas(
                concept_id=learning_lemma.concept_id,
                learning_lemma=learning_lemma_response,
                native_lemma=native_lemma_response,
                image_url=image_url
            )
        )
    
    return NewCardsResponse(
        concepts=concept_responses,
        native_language=user.lang_native,
        total_concepts_count=total_concepts_count,
        filtered_concepts_count=filtered_concepts_count,
        concepts_with_both_languages_count=concepts_with_both_languages_count,
        concepts_without_cards_count=concepts_without_cards_count
    )

