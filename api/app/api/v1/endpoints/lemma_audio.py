"""
Endpoint for generating audio recordings for lemmas.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlmodel import Session, select
import logging
from pathlib import Path
from datetime import datetime, timezone
import os

from app.core.database import get_session
from app.core.config import settings
from app.models.models import Lemma
from app.schemas.lemma import GenerateAudioRequest

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/lemma-audio", tags=["lemma-audio"])


def ensure_assets_directory() -> Path:
    """
    Ensure the assets directory exists and return its path.
    
    Uses ASSETS_PATH environment variable if set (for Railway volumes),
    otherwise falls back to api/assets directory.
    
    Returns:
        Path to the assets directory
    """
    # Check if ASSETS_PATH is configured (for Railway volumes)
    if settings.assets_path:
        assets_dir = Path(settings.assets_path)
    else:
        # Fallback to API root/assets for local development
        api_root = Path(__file__).parent.parent.parent.parent.parent
        assets_dir = api_root / "assets"
    
    # Ensure directory exists
    assets_dir.mkdir(parents=True, exist_ok=True)
    
    # Ensure audio subdirectory exists
    audio_dir = assets_dir / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    
    logger.info(f"Using assets directory: {assets_dir}")
    return assets_dir


def get_language_code_for_tts(language_code: str) -> str:
    """
    Map language codes to Google Cloud TTS language codes.
    
    Args:
        language_code: The language code from the database (e.g., 'en', 'fr', 'es')
        
    Returns:
        Google Cloud TTS language code (e.g., 'en-US', 'fr-FR', 'es-ES')
    """
    # Map common language codes to Google Cloud TTS codes
    language_map = {
        'en': 'en-US',
        'fr': 'fr-FR',
        'es': 'es-ES',
        'de': 'de-DE',
        'it': 'it-IT',
        'pt': 'pt-BR',
        'ar': 'ar-XA',  # Arabic
        'ja': 'ja-JP',  # Japanese
        'zh': 'zh-CN',  # Chinese
        'ko': 'ko-KR',  # Korean
        'ru': 'ru-RU',  # Russian
        'nl': 'nl-NL',  # Dutch
        'pl': 'pl-PL',  # Polish
        'tr': 'tr-TR',  # Turkish
        'sv': 'sv-SE',  # Swedish
        'da': 'da-DK',  # Danish
        'no': 'nb-NO',  # Norwegian
        'fi': 'fi-FI',  # Finnish
        'cs': 'cs-CZ',  # Czech
        'hu': 'hu-HU',  # Hungarian
        'ro': 'ro-RO',  # Romanian
        'el': 'el-GR',  # Greek
        'he': 'he-IL',  # Hebrew
        'hi': 'hi-IN',  # Hindi
        'th': 'th-TH',  # Thai
        'vi': 'vi-VN',  # Vietnamese
    }
    
    # Return mapped code or default to en-US
    return language_map.get(language_code.lower(), 'en-US')


def get_voice_name_for_language(language_code: str) -> str:
    """
    Get a suitable voice name for the given language.
    
    Args:
        language_code: The language code from the database
        
    Returns:
        Google Cloud TTS voice name
    """
    # Map language codes to voice names (using neural voices for better quality)
    voice_map = {
        'en': 'en-US-Neural2-D',
        'fr': 'fr-FR-Neural2-D',
        'es': 'es-ES-Neural2-D',
        'de': 'de-DE-Neural2-D',
        'it': 'it-IT-Neural2-F',  # Male voice (Neural2-D doesn't exist for Italian)
        'pt': 'pt-BR-Neural2-D',
        'ar': 'ar-XA-Wavenet-A',
        'ja': 'ja-JP-Neural2-D',
        'zh': 'zh-CN-Neural2-D',
        'ko': 'ko-KR-Neural2-D',
        'ru': 'ru-RU-Neural2-D',
        'nl': 'nl-NL-Neural2-B',  # Male voice (Neural2-D doesn't exist for Dutch)
        'pl': 'pl-PL-Neural2-D',
        'tr': 'tr-TR-Neural2-D',
        'sv': 'sv-SE-Neural2-D',
        'da': 'da-DK-Neural2-D',
        'no': 'nb-NO-Neural2-D',
        'fi': 'fi-FI-Neural2-D',
        'cs': 'cs-CZ-Neural2-D',
        'hu': 'hu-HU-Neural2-D',
        'ro': 'ro-RO-Neural2-D',
        'el': 'el-GR-Neural2-D',
        'he': 'he-IL-Neural2-D',
        'hi': 'hi-IN-Neural2-D',
        'th': 'th-TH-Neural2-D',
        'vi': 'vi-VN-Neural2-D',
    }
    
    # Return mapped voice or default to en-US
    return voice_map.get(language_code.lower(), 'en-US-Neural2-D')


def generate_audio_with_google_tts(text: str, language_code: str) -> bytes:
    """
    Generate audio using Google Cloud Text-to-Speech API.
    
    Note: Google Cloud TTS requires service account credentials.
    Set GOOGLE_APPLICATION_CREDENTIALS environment variable to point to your
    service account JSON file, or configure Application Default Credentials.
    
    Args:
        text: The text to convert to speech
        language_code: The language code (e.g., 'en', 'fr', 'es')
        
    Returns:
        Audio bytes (MP3 format)
        
    Raises:
        HTTPException: If audio generation fails
    """
    try:
        from google.cloud import texttospeech
    except ImportError:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google Cloud Text-to-Speech library not installed. Please install it with: pip install google-cloud-texttospeech"
        )
    
    # Google Cloud TTS requires service account credentials via:
    # 1. GOOGLE_APPLICATION_CREDENTIALS environment variable (points to service account JSON file)
    # 2. GOOGLE_APPLICATION_CREDENTIALS_JSON (base64-encoded JSON credentials) - Railway-friendly
    # 3. Application Default Credentials (ADC) if running on GCP/Cloud Run
    # 4. Or credentials passed explicitly to the client
    
    # Try to load credentials from base64-encoded JSON (Railway-friendly approach)
    credentials_json_b64 = os.getenv("GOOGLE_APPLICATION_CREDENTIALS_JSON")
    credentials = None
    
    if credentials_json_b64:
        try:
            import base64
            import json
            from google.oauth2 import service_account
            
            # Decode base64 JSON
            credentials_json = base64.b64decode(credentials_json_b64).decode('utf-8')
            credentials_dict = json.loads(credentials_json)
            
            # Create credentials object
            credentials = service_account.Credentials.from_service_account_info(credentials_dict)
            logger.info("Loaded credentials from GOOGLE_APPLICATION_CREDENTIALS_JSON")
        except Exception as e:
            logger.warning(f"Failed to load credentials from GOOGLE_APPLICATION_CREDENTIALS_JSON: {str(e)}")
    
    # Check if credentials file path is available
    if not credentials and not os.getenv("GOOGLE_APPLICATION_CREDENTIALS"):
        logger.warning("GOOGLE_APPLICATION_CREDENTIALS not set. Attempting to use Application Default Credentials.")
    
    try:
        # Initialize the client with credentials if available, otherwise use default
        if credentials:
            client = texttospeech.TextToSpeechClient(credentials=credentials)
        else:
            # Will use GOOGLE_APPLICATION_CREDENTIALS or ADC
            client = texttospeech.TextToSpeechClient()
        
        # Get language and voice settings
        tts_language_code = get_language_code_for_tts(language_code)
        voice_name = get_voice_name_for_language(language_code)
        
        # Configure the synthesis input
        synthesis_input = texttospeech.SynthesisInput(text=text)
        
        # Configure the voice
        voice = texttospeech.VoiceSelectionParams(
            language_code=tts_language_code,
            name=voice_name,
            ssml_gender=texttospeech.SsmlVoiceGender.MALE
        )
        
        # Configure the audio output
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=1.0,  # Normal speed
            pitch=0.0,  # Normal pitch
            volume_gain_db=0.0  # Normal volume
        )
        
        # Perform the text-to-speech request
        logger.info(f"Generating audio for text: '{text[:50]}...' in language {tts_language_code} with voice {voice_name}")
        response = client.synthesize_speech(
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config
        )
        
        # Return the audio content
        return response.audio_content
        
    except Exception as e:
        error_detail = str(e)
        logger.error(f"Failed to generate audio with Google Cloud TTS: {error_detail}")
        
        # Provide helpful error messages
        if "credentials" in error_detail.lower() or "authentication" in error_detail.lower():
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Google Cloud Text-to-Speech authentication failed. Please set GOOGLE_APPLICATION_CREDENTIALS environment variable or configure Application Default Credentials."
            )
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to generate audio: {error_detail}"
            )


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
    
    # Ensure assets directory exists
    assets_dir = ensure_assets_directory()
    audio_dir = assets_dir / "audio"
    
    # Create audio filename
    audio_filename = f"{request.lemma_id}.mp3"
    audio_path = audio_dir / audio_filename
    
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
        if lemma.audio_url.startswith("/assets/audio/"):
            existing_audio_filename = lemma.audio_url.replace("/assets/audio/", "")
            existing_audio_path = audio_dir / existing_audio_filename
            if existing_audio_path.exists() and existing_audio_filename != audio_filename:
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
    if lemma.audio_url.startswith("/assets/audio/"):
        audio_filename = lemma.audio_url.replace("/assets/audio/", "")
        assets_dir = ensure_assets_directory()
        audio_dir = assets_dir / "audio"
        audio_path = audio_dir / audio_filename
        
        if not audio_path.exists():
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Audio file not found at path: {audio_path}"
            )
        
        return FileResponse(
            path=str(audio_path),
            media_type="audio/mpeg",
            filename=audio_filename
        )
    else:
        # External URL or other format
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Audio URL format not supported: {lemma.audio_url}"
        )

