from app.core.config import settings
import requests
import logging
import os
from typing import List, Dict, Union


def ensure_capitalized(text: str) -> str:
    """
    Ensure the first letter is capitalized while preserving the rest of the case.
    If text is empty, return as is.
    """
    if not text:
        return text
    return text[0].upper() + text[1:] if len(text) > 0 else text

logger = logging.getLogger(__name__)


class TranslationService:
    """Service for translating text using Google Cloud Translation API."""
    
    # Mapping from our internal language codes to Google Translate API codes
    LANGUAGE_CODE_MAPPING = {
        'jp': 'ja',  # Japanese: our code 'jp' -> Google API code 'ja'
        # Add other mappings here if needed
    }
    
    def __init__(self):
        """Initialize the translation service."""
        self.api_key = settings.google_translate_api_key
        self.base_url = "https://translation.googleapis.com/language/translate/v2"
        
        # Debug logging
        logger.info(f"TranslationService initialized. API key present: {bool(self.api_key)}")
        if self.api_key:
            logger.info(f"API key length: {len(self.api_key)}, starts with: {self.api_key[:10]}...")
        else:
            logger.warning("Google Translate API key not configured. Translation will fail.")
            logger.warning(f"Settings google_translate_api_key value: '{settings.google_translate_api_key}'")
            logger.warning(f"Environment variable GOOGLE_TRANSLATE_API_KEY: {os.getenv('GOOGLE_TRANSLATE_API_KEY', 'NOT SET')}")
    
    def _map_language_code(self, lang_code: str) -> str:
        """
        Map internal language code to Google Translate API language code.
        
        Args:
            lang_code: Internal language code (e.g., 'jp')
        
        Returns:
            Google Translate API language code (e.g., 'ja')
        """
        return self.LANGUAGE_CODE_MAPPING.get(lang_code.lower(), lang_code.lower())
    
    def translate_text(
        self,
        text: str,
        target_language: str,
        source_language: str = None
    ) -> str:
        """
        Translate text from source language to target language.
        
        Args:
            text: Text to translate
            target_language: Target language code (e.g., 'fr', 'es', 'de')
            source_language: Source language code (e.g., 'en'). If None, auto-detect.
        
        Returns:
            Translated text
        
        Raises:
            Exception: If translation fails
        """
        # Re-check API key from settings in case it was loaded after initialization
        if not self.api_key:
            self.api_key = settings.google_translate_api_key
        
        if not self.api_key:
            raise ValueError("Google Translate API key not configured")
        
        try:
            # Map language codes to Google Translate API codes
            mapped_target = self._map_language_code(target_language)
            mapped_source = self._map_language_code(source_language) if source_language else None
            
            # Build request parameters
            params = {
                'key': self.api_key,
                'q': text,
                'target': mapped_target
            }
            
            # Add source language if provided
            if mapped_source:
                params['source'] = mapped_source
            
            logger.debug(f"Translation request: '{text}' from '{mapped_source or 'auto'}' to '{mapped_target}' "
                        f"(original codes: '{source_language or 'auto'}' -> '{target_language}')")
            
            # Make API request
            response = requests.post(
                self.base_url,
                params=params,
                timeout=10
            )
            
            # Check for errors
            response.raise_for_status()
            data = response.json()
            
            # Extract translated text
            if 'data' in data and 'translations' in data['data']:
                translated_text = data['data']['translations'][0]['translatedText']
                logger.info(f"Translated '{text}' from {source_language or 'auto'} to {target_language}: '{translated_text}'")
                return translated_text
            else:
                raise Exception(f"Unexpected API response format: {data}")
            
        except requests.exceptions.RequestException as e:
            error_msg = f"Translation API request failed: {str(e)}"
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_data = e.response.json()
                    error_msg += f" - {error_data}"
                except:
                    error_msg += f" - Status: {e.response.status_code}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            logger.error(f"Translation failed: {str(e)}")
            raise Exception(f"Translation failed: {str(e)}")
    
    def translate_to_multiple_languages(
        self,
        text: str,
        source_language: str,
        target_languages: List[str],
        skip_source_language: bool = True
    ) -> Dict[str, Union[Dict[str, str], List[str]]]:
        """
        Translate text to multiple target languages.
        
        Args:
            text: Text to translate
            source_language: Source language code (e.g., 'en')
            target_languages: List of target language codes (e.g., ['fr', 'es', 'de'])
            skip_source_language: If True, skip translation for source language and use original text
        
        Returns:
            Dictionary with:
                - 'translations': dict mapping language_code -> translated_text
                - 'failed_languages': list of language codes that failed to translate
        """
        translations = {}
        failed_languages = []
        
        # Preserve original case, just strip whitespace
        text_stripped = text.strip()
        source_lang_normalized = source_language.lower()
        
        logger.info(f"Translating '{text_stripped}' from '{source_lang_normalized}' to {len(target_languages)} language(s)")
        
        for lang_code in target_languages:
            lang_code_normalized = lang_code.lower()
            
            # Skip source language if requested
            if skip_source_language and lang_code_normalized == source_lang_normalized:
                # Preserve original case and ensure first letter is capitalized
                translations[lang_code_normalized] = ensure_capitalized(text_stripped)
                logger.info(f"Source language '{lang_code_normalized}' - using original text (no API call)")
                continue
            
            logger.info(f"API call: Translating '{text_stripped}' from '{source_lang_normalized}' to '{lang_code_normalized}'")
            
            try:
                translated_text = self.translate_text(
                    text=text_stripped,
                    target_language=lang_code_normalized,
                    source_language=source_lang_normalized
                )
                # Preserve API case and ensure first letter is capitalized
                translated_text_stripped = translated_text.strip()
                translations[lang_code_normalized] = ensure_capitalized(translated_text_stripped)
                logger.info(f"API success: '{lang_code_normalized}' -> '{translations[lang_code_normalized]}'")
            except Exception as e:
                error_msg = str(e).lower()
                # Check for common bad language pair errors
                if 'bad language pair' in error_msg or 'invalid language' in error_msg or 'unsupported' in error_msg:
                    logger.warning(f"API failed (bad language pair): '{lang_code_normalized}' - {str(e)}")
                else:
                    logger.error(f"API failed (other error): '{lang_code_normalized}' - {str(e)}")
                failed_languages.append(lang_code_normalized)
        
        logger.info(f"Translation summary: successful: {len(translations)}, failed: {len(failed_languages)}")
        if translations:
            logger.info(f"Languages successfully translated: {sorted(translations.keys())}")
        if failed_languages:
            logger.warning(f"Languages that failed translation: {sorted(failed_languages)}")
        
        return {
            'translations': translations,
            'failed_languages': failed_languages
        }


# Create a singleton instance
translation_service = TranslationService()

