from app.core.config import settings
import requests
import logging
import os
from typing import List, Dict, Union, Optional

logger = logging.getLogger(__name__)


class DescriptionService:
    """Service for generating descriptions using Google Generative AI (Gemini) API."""
    
    def __init__(self):
        """Initialize the description service."""
        self.api_key = settings.google_gemini_api_key
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"
        
        # Debug logging
        logger.info(f"DescriptionService initialized. API key present: {bool(self.api_key)}")
        if self.api_key:
            logger.info(f"API key length: {len(self.api_key)}, starts with: {self.api_key[:10]}...")
        else:
            logger.warning("Google Gemini API key not configured. Description generation will fail.")
            logger.warning(f"Settings google_gemini_api_key value: '{settings.google_gemini_api_key}'")
            logger.warning(f"Environment variable GOOGLE_GEMINI_API_KEY: {os.getenv('GOOGLE_GEMINI_API_KEY', 'NOT SET')}")
    
    def _get_language_name(self, lang_code: str) -> str:
        """
        Map language code to language name for better prompts.
        
        Args:
            lang_code: Language code (e.g., 'en', 'fr', 'es')
        
        Returns:
            Language name (e.g., 'English', 'French', 'Spanish')
        """
        language_names = {
            'en': 'English',
            'fr': 'French',
            'es': 'Spanish',
            'de': 'German',
            'it': 'Italian',
            'pt': 'Portuguese',
            'ru': 'Russian',
            'ja': 'Japanese',
            'zh': 'Chinese',
            'ko': 'Korean',
            'ar': 'Arabic',
            'hi': 'Hindi',
            'nl': 'Dutch',
            'sv': 'Swedish',
            'pl': 'Polish',
            'tr': 'Turkish',
            'cs': 'Czech',
            'hu': 'Hungarian',
            'fi': 'Finnish',
            'da': 'Danish',
            'no': 'Norwegian',
            'ro': 'Romanian',
            'el': 'Greek',
            'he': 'Hebrew',
            'th': 'Thai',
            'vi': 'Vietnamese',
            'id': 'Indonesian',
            'uk': 'Ukrainian',
            'jp': 'Japanese',  # Our internal code
        }
        return language_names.get(lang_code.lower(), lang_code.upper())
    
    def generate_description(
        self,
        text: str,
        target_language: str,
        source_language: Optional[str] = None
    ) -> str:
        """
        Generate a description for a word or phrase in the target language.
        
        Args:
            text: The word or phrase to generate a description for
            target_language: Target language code (e.g., 'en', 'fr', 'es')
            source_language: Optional source language code for context
        
        Returns:
            Generated description text
        
        Raises:
            Exception: If description generation fails
        """
        # Re-check API key from settings in case it was loaded after initialization
        if not self.api_key:
            self.api_key = settings.google_gemini_api_key
        
        # Fallback: try reading directly from environment
        if not self.api_key:
            self.api_key = os.getenv("GOOGLE_GEMINI_API_KEY", "")
        
        if not self.api_key:
            raise ValueError("Google Gemini API key not configured. Please set GOOGLE_GEMINI_API_KEY environment variable or add it to your .env file.")
        
        try:
            target_lang_name = self._get_language_name(target_language)
            
            # Build the prompt
            if source_language:
                source_lang_name = self._get_language_name(source_language)
                prompt = (
                    f"Generate a concise, educational description for the word or phrase '{text}' in {target_lang_name}. "
                    f"The original text is in {source_lang_name}. "
                    f"Write exactly 1 sentence if the concept is simple (common words, basic objects), or 2-3 sentences if it's more complex (abstract concepts, verbs with multiple meanings, technical terms). "
                    f"Write the description entirely in {target_lang_name}. Do not include the word or phrase itself in the description. "
                    f"Make it suitable for language learning - clear, informative, and helpful for understanding the meaning."
                )
            else:
                prompt = (
                    f"Generate a concise, educational description for the word or phrase '{text}' in {target_lang_name}. "
                    f"Write exactly 1 sentence if the concept is simple (common words, basic objects), or 2-3 sentences if it's more complex (abstract concepts, verbs with multiple meanings, technical terms). "
                    f"Write the description entirely in {target_lang_name}. Do not include the word or phrase itself in the description. "
                    f"Make it suitable for language learning - clear, informative, and helpful for understanding the meaning."
                )
            
            logger.debug(f"Generating description for '{text}' in {target_lang_name}")
            
            # Build request payload
            payload = {
                "contents": [{
                    "parts": [{
                        "text": prompt
                    }]
                }],
                "generationConfig": {
                    "temperature": 0.7,
                    "topK": 40,
                    "topP": 0.95,
                    "maxOutputTokens": 200,
                }
            }
            
            # Make API request
            response = requests.post(
                f"{self.base_url}?key={self.api_key}",
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30
            )
            
            # Check for errors
            response.raise_for_status()
            data = response.json()
            
            # Extract generated text
            if 'candidates' in data and len(data['candidates']) > 0:
                candidate = data['candidates'][0]
                # Check for finishReason - if it's SAFETY or other blocking reasons, handle it
                if 'finishReason' in candidate:
                    finish_reason = candidate['finishReason']
                    if finish_reason not in ['STOP', 'MAX_TOKENS']:
                        logger.warning(f"Description generation finished with reason: {finish_reason}")
                
                if 'content' in candidate and 'parts' in candidate['content']:
                    if len(candidate['content']['parts']) > 0:
                        description = candidate['content']['parts'][0].get('text', '').strip()
                        if description:
                            logger.info(f"Generated description for '{text}' in {target_language}: '{description[:100]}...'")
                            return description
                        else:
                            logger.warning(f"Generated description is empty for '{text}' in {target_language}")
            
            # Log the full response for debugging
            logger.error(f"Unexpected API response format. Response: {data}")
            raise Exception(f"Unexpected API response format: {data}")
            
        except requests.exceptions.RequestException as e:
            error_msg = f"Description generation API request failed: {str(e)}"
            if hasattr(e, 'response') and e.response is not None:
                try:
                    error_data = e.response.json()
                    error_msg += f" - {error_data}"
                except:
                    error_msg += f" - Status: {e.response.status_code}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            logger.error(f"Description generation failed: {str(e)}")
            raise Exception(f"Description generation failed: {str(e)}")
    
    def generate_descriptions_for_multiple_languages(
        self,
        text: str,
        target_languages: List[str],
        source_language: Optional[str] = None,
        prefer_english: bool = False
    ) -> Dict[str, Union[Dict[str, str], List[str]]]:
        """
        Generate descriptions for a word or phrase in multiple target languages.
        
        Args:
            text: The word or phrase to generate descriptions for
            target_languages: List of target language codes (e.g., ['en', 'fr', 'es'])
            source_language: Optional source language code for context
            prefer_english: If True and 'en' is in target_languages, use English text for other languages
        
        Returns:
            Dictionary with:
                - 'descriptions': dict mapping language_code -> description_text
                - 'failed_languages': list of language codes that failed to generate descriptions
        """
        descriptions = {}
        failed_languages = []
        
        text_stripped = text.strip()
        
        logger.info(f"Generating descriptions for '{text_stripped}' in {len(target_languages)} language(s)")
        
        # If prefer_english is True, try to get English translation first
        english_text = None
        if prefer_english and 'en' in target_languages:
            try:
                # Try to generate English description first
                english_text = self.generate_description(
                    text=text_stripped,
                    target_language='en',
                    source_language=source_language
                )
                descriptions['en'] = english_text
                logger.info(f"Generated English description: '{english_text[:100]}...'")
            except Exception as e:
                logger.warning(f"Failed to generate English description: {str(e)}")
                failed_languages.append('en')
        
        # Generate descriptions for all target languages
        for lang_code in target_languages:
            lang_code_normalized = lang_code.lower()
            
            # Skip if already generated (e.g., English)
            if lang_code_normalized in descriptions:
                continue
            
            logger.info(f"API call: Generating description for '{text_stripped}' in '{lang_code_normalized}'")
            
            try:
                # If we have English text and prefer_english, use it as source
                if prefer_english and english_text and lang_code_normalized != 'en':
                    description = self.generate_description(
                        text=english_text,
                        target_language=lang_code_normalized,
                        source_language='en'
                    )
                else:
                    description = self.generate_description(
                        text=text_stripped,
                        target_language=lang_code_normalized,
                        source_language=source_language
                    )
                
                descriptions[lang_code_normalized] = description.strip()
                logger.info(f"API success: '{lang_code_normalized}' -> '{descriptions[lang_code_normalized][:100]}...'")
            except Exception as e:
                error_msg = str(e).lower()
                logger.error(f"API failed: '{lang_code_normalized}' - {str(e)}")
                failed_languages.append(lang_code_normalized)
        
        logger.info(f"Description generation summary: successful: {len(descriptions)}, failed: {len(failed_languages)}")
        if descriptions:
            logger.info(f"Languages successfully generated: {sorted(descriptions.keys())}")
        if failed_languages:
            logger.warning(f"Languages that failed description generation: {sorted(failed_languages)}")
        
        return {
            'descriptions': descriptions,
            'failed_languages': failed_languages
        }


# Create a singleton instance
description_service = DescriptionService()

