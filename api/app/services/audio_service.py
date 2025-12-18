"""
Audio service for text-to-speech generation using Google Cloud TTS.
"""
import logging
import os
import base64
import json
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, status
from google.oauth2 import service_account

from app.utils.assets_utils import ensure_assets_directory

logger = logging.getLogger(__name__)


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


def _get_tts_client():
    """
    Get a Google Cloud TTS client with proper credentials.
    
    Returns:
        TextToSpeechClient instance
        
    Raises:
        HTTPException: If client initialization fails
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
            return texttospeech.TextToSpeechClient(credentials=credentials)
        else:
            # Will use GOOGLE_APPLICATION_CREDENTIALS or ADC
            return texttospeech.TextToSpeechClient()
    except Exception as e:
        error_detail = str(e)
        logger.error(f"Failed to initialize TTS client: {error_detail}")
        if "credentials" in error_detail.lower() or "authentication" in error_detail.lower():
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Google Cloud Text-to-Speech authentication failed. Please set GOOGLE_APPLICATION_CREDENTIALS environment variable or configure Application Default Credentials."
            )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to initialize TTS client: {error_detail}"
        )


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
    
    try:
        client = _get_tts_client()
        
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
        
    except HTTPException:
        raise
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


def get_audio_file_path(lemma_id: int) -> Path:
    """
    Get the file path for a lemma's audio file.
    
    Args:
        lemma_id: The lemma ID
        
    Returns:
        Path to the audio file
    """
    assets_dir = ensure_assets_directory(subdirectories=["audio"])
    audio_dir = assets_dir / "audio"
    return audio_dir / f"{lemma_id}.mp3"


def get_audio_file_path_from_url(audio_url: str) -> Optional[Path]:
    """
    Get the file path from an audio URL.
    
    Args:
        audio_url: The audio URL (e.g., "/assets/audio/123.mp3")
        
    Returns:
        Path to the audio file, or None if URL format is not supported
    """
    if not audio_url or not audio_url.startswith("/assets/audio/"):
        return None
    
    audio_filename = audio_url.replace("/assets/audio/", "")
    assets_dir = ensure_assets_directory(subdirectories=["audio"])
    audio_dir = assets_dir / "audio"
    return audio_dir / audio_filename

