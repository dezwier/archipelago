"""
Endpoint for generating audio recordings for lemmas.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlmodel import Session
import logging
from datetime import datetime, timezone

from app.core.database import get_session
from app.models.models import Lemma
from app.schemas.lemma import GenerateAudioRequest
from app.services.audio_service import (
    generate_audio_with_google_tts,
    get_audio_file_path,
    get_audio_file_path_from_url,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lemma-audio", tags=["lemma-audio"])


@router.post("/generate")
async def generate_lemma_audio(
    request: GenerateAudioRequest,
    session: Session = Depends(get_session)
):
    """
    Generate an audio recording for a lemma.
    
    This endpoint:
    1. Takes the lemma term (and optionally description for context)
    2. Generates audio using Google Cloud Text-to-Speech API
    3. Saves it to the assets/audio folder as {lemma_id}.mp3
    4. Updates the lemma's audio_url field
    5. Returns the audio file
    
    Args:
        request: GenerateAudioRequest with lemma_id, optional term and description
        session: Database session
        
    Returns:
        The generated audio file
    """
    # Verify lemma exists and get lemma data
    lemma = session.get(Lemma, request.lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lemma with ID {request.lemma_id} not found"
        )
    
    # Use provided term or fall back to lemma.term
    term = request.term if request.term else (lemma.term or "")
    if not term:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term is required (either in request or lemma)"
        )
    
    # Get language code from request or fall back to lemma
    language_code = request.language_code if request.language_code else lemma.language_code
    if not language_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Language code is required (either in request or lemma)"
        )
    
    # Build text for TTS (use term, optionally include description for context)
    # For TTS, we typically only use the term itself, not the description
    text_to_speak = term.strip()
    
    # Optionally, if description is provided and might help with pronunciation context,
    # we could include it, but typically we just speak the term
    # For now, we'll just use the term
    
    logger.info(f"Generating audio for lemma {request.lemma_id} with term: '{text_to_speak}' in language {language_code}")
    
    # Generate the audio using Google Cloud TTS
    try:
        audio_bytes = generate_audio_with_google_tts(text_to_speak, language_code)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate audio: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate audio: {str(e)}"
        )
    
    # Get audio file path
    audio_path = get_audio_file_path(request.lemma_id)
    audio_filename = audio_path.name
    
    # Save audio file
    try:
        with open(audio_path, "wb") as f:
            f.write(audio_bytes)
        logger.info(f"Saved audio file to: {audio_path}")
    except Exception as e:
        logger.error(f"Failed to save audio file: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save audio file: {str(e)}"
        )
    
    # Create audio URL (relative path)
    audio_url = f"/assets/audio/{audio_filename}"
    
    # Check if there's an existing audio file and remove it if different
    if lemma.audio_url and lemma.audio_url != audio_url:
        existing_audio_path = get_audio_file_path_from_url(lemma.audio_url)
        if existing_audio_path and existing_audio_path.exists() and existing_audio_path != audio_path:
            try:
                existing_audio_path.unlink()
                logger.info(f"Removed old audio file: {existing_audio_path}")
            except Exception as e:
                logger.warning(f"Failed to remove old audio file: {existing_audio_path}: {str(e)}")
    
    # Update lemma with new audio URL
    lemma.audio_url = audio_url
    lemma.updated_at = datetime.now(timezone.utc)
    
    try:
        session.add(lemma)
        session.commit()
        session.refresh(lemma)
    except Exception as e:
        logger.error(f"Failed to update lemma with audio URL: {str(e)}")
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to update lemma: {str(e)}"
        )
    
    # Return the audio file
    return FileResponse(
        path=str(audio_path),
        media_type="audio/mpeg",
        filename=audio_filename
    )


@router.get("/{lemma_id}")
async def get_lemma_audio(
    lemma_id: int,
    session: Session = Depends(get_session)
):
    """
    Get the audio file for a lemma.
    
    Args:
        lemma_id: The lemma ID
        session: Database session
        
    Returns:
        The audio file if it exists
    """
    # Verify lemma exists
    lemma = session.get(Lemma, lemma_id)
    if not lemma:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Lemma with ID {lemma_id} not found"
        )
    
    # Check if audio URL exists
    if not lemma.audio_url:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No audio file found for lemma {lemma_id}"
        )
    
    # Get audio file path
    audio_path = get_audio_file_path_from_url(lemma.audio_url)
    if not audio_path:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Audio URL format not supported: {lemma.audio_url}"
        )
    
    if not audio_path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Audio file not found at path: {audio_path}"
        )
    
    return FileResponse(
        path=str(audio_path),
        media_type="audio/mpeg",
        filename=audio_path.name
    )

