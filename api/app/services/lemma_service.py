"""
Lemma service for business logic related to lemma generation and validation.
"""
import logging
from typing import Dict, Any, Optional, List
from sqlmodel import Session, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy import func

from fastapi import HTTPException, status
from app.models.models import Lemma, Concept, Language
from app.utils.text_utils import normalize_lemma_term

logger = logging.getLogger(__name__)


def validate_llm_lemma_data(llm_data: Any, language_code: Optional[str] = None) -> Dict[str, Any]:
    """
    Validate LLM output for lemma generation.
    
    Args:
        llm_data: The LLM output data (should be a dict)
        language_code: Optional language code for error messages
        
    Returns:
        Validated LLM data as dict
        
    Raises:
        ValueError: If validation fails
    """
    lang_suffix = f" for {language_code}" if language_code else ""
    
    # Validate required fields
    if not isinstance(llm_data, dict):
        raise ValueError(f"LLM output must be a JSON object{lang_suffix}")
    
    required_fields = ['term', 'description']
    for field in required_fields:
        if field not in llm_data or not llm_data[field]:
            raise ValueError(f"Missing or empty required field: {field}{lang_suffix}")
    
    # Validate optional fields
    if 'gender' in llm_data and llm_data['gender'] is not None:
        valid_genders = ['masculine', 'feminine', 'neuter']
        if llm_data['gender'] not in valid_genders:
            raise ValueError(f"Invalid gender value: {llm_data['gender']}. Must be one of: {', '.join(valid_genders)}{lang_suffix}")
    
    if 'register' in llm_data and llm_data['register'] is not None:
        valid_registers = ['neutral', 'formal', 'informal', 'slang']
        if llm_data['register'] not in valid_registers:
            raise ValueError(f"Invalid register value: {llm_data['register']}. Must be one of: {', '.join(valid_registers)}{lang_suffix}")
    
    return llm_data


def create_or_update_lemma_from_llm_data(
    session: Session,
    concept_id: int,
    language_code: str,
    llm_data: Dict[str, Any],
    replace_existing: bool = True
) -> Lemma:
    """
    Create or update a lemma from LLM-generated data.
    
    Args:
        session: Database session
        concept_id: The concept ID
        language_code: The language code
        llm_data: Validated LLM output data
        replace_existing: If True, delete existing lemmas before creating new one
        
    Returns:
        The created or updated Lemma
        
    Raises:
        HTTPException: If concept not found or database error occurs
        IntegrityError: If unique constraint violation occurs
    """
    # Verify concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept with id {concept_id} not found"
        )
    
    # Normalize term (trim dots and whitespace)
    term = llm_data.get('term')
    if term:
        term = normalize_lemma_term(term)
    
    # Delete existing lemmas if replace_existing is True
    if replace_existing:
        if term:
            # Check for existing lemmas with same concept_id, language_code, and term (case-insensitive)
            existing_lemmas = session.exec(
                select(Lemma).where(
                    Lemma.concept_id == concept_id,
                    Lemma.language_code == language_code,
                    func.lower(func.trim(Lemma.term)) == term.lower()
                )
            ).all()
        else:
            # If no term, check by concept_id and language_code only
            existing_lemmas = session.exec(
                select(Lemma).where(
                    Lemma.concept_id == concept_id,
                    Lemma.language_code == language_code
                )
            ).all()
        
        for existing_lemma in existing_lemmas:
            session.delete(existing_lemma)
        if existing_lemmas:
            session.flush()
    
    # Create new lemma
    lemma = Lemma(
        concept_id=concept_id,
        language_code=language_code,
        term=term,
        ipa=llm_data.get('ipa'),
        description=llm_data.get('description'),
        gender=llm_data.get('gender'),
        article=llm_data.get('article'),
        plural_form=llm_data.get('plural_form'),
        verb_type=llm_data.get('verb_type'),
        auxiliary_verb=llm_data.get('auxiliary_verb'),
        formality_register=llm_data.get('register'),
        status="active",
        source="llm"
    )
    
    try:
        session.add(lemma)
        session.commit()
        session.refresh(lemma)
        logger.info("Lemma created/updated for concept %d, language %s", concept_id, language_code)
        return lemma
    except IntegrityError as e:
        session.rollback()
        logger.error("Database integrity error: %s", str(e))
        if "uq_lemma_concept_language_term" in str(e) or "unique constraint" in str(e).lower():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="A lemma with the same concept_id, language_code, and term already exists"
            ) from e
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database integrity error: {str(e)}"
        ) from e
    except Exception as e:
        session.rollback()
        logger.error("Failed to save lemma: %s", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save lemma: {str(e)}"
        ) from e


def validate_language_codes(session: Session, language_codes: List[str]) -> List[Language]:
    """
    Validate that all language codes exist in the database.
    
    Args:
        session: Database session
        language_codes: List of language codes to validate (will be lowercased)
        
    Returns:
        List of Language objects for valid codes
        
    Raises:
        HTTPException: If any language codes are invalid
    """
    normalized_codes = [lang.lower() for lang in language_codes]
    languages_list = list(session.exec(
        select(Language).where(Language.code.in_(normalized_codes))  # type: ignore[attr-defined]
    ).all())
    
    found_codes = {lang.code.lower() for lang in languages_list}
    missing_codes = set(normalized_codes) - found_codes
    
    if missing_codes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language codes: {', '.join(sorted(missing_codes))}"
        )
    
    return languages_list


def find_concept_by_term(
    session: Session,
    term: str,
    user_id: Optional[int] = None
) -> Optional[Concept]:
    """
    Find an existing concept by term (case-insensitive exact match).
    
    Priority:
    1. Concepts with matching user_id (if provided)
    2. Concepts with description
    3. Any matching concept
    
    Args:
        session: Database session
        term: The term to search for (will be stripped and lowercased)
        user_id: Optional user ID to prioritize
        
    Returns:
        Concept if found, None otherwise
    """
    term_stripped = term.strip()
    if not term_stripped:
        return None
    
    # Find all matching concepts (case-insensitive)
    all_matching_concepts = session.exec(
        select(Concept).where(
            func.lower(Concept.term) == term_stripped.lower()  # type: ignore[attr-defined]
        ).order_by(Concept.created_at.desc())  # type: ignore[attr-defined]
    ).all()
    
    if not all_matching_concepts:
        return None
    
    # Prioritize concepts: user_id match first, then concepts with description
    concept = None
    
    # First priority: concepts with matching user_id
    if user_id is not None:
        user_matched = [c for c in all_matching_concepts if c.user_id == user_id]
        if user_matched:
            # Among user-matched concepts, prefer those with description
            with_description = [c for c in user_matched if c.description and c.description.strip()]
            concept = with_description[0] if with_description else user_matched[0]
    
    # Second priority: concepts with description (if no user_id match or user_id not provided)
    if concept is None:
        with_description = [c for c in all_matching_concepts if c.description and c.description.strip()]
        if with_description:
            concept = with_description[0]
    
    # Third priority: any matching concept
    if concept is None:
        concept = all_matching_concepts[0]
    
    return concept

