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
        # Use gemini-2.5-flash as the primary model (fast, cost-effective, and doesn't use thinking tokens)
        # gemini-pro-latest may use thinking tokens which consume output budget
        # Based on ListModels API, available models are: gemini-2.5-flash and gemini-2.5-pro
        self.model_name = "gemini-2.5-flash"
        self.base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model_name}:generateContent"
        
        # Fallback model in case primary model is not available
        self.fallback_models = [
            "gemini-2.5-pro",  # More powerful but may use thinking tokens
            "gemini-pro-latest",  # Last resort (may have thinking token issues)
        ]
        
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
                    f"This is for a language learning app. Generate a concise, educational description for the word or phrase '{text}' in {target_lang_name}. "
                    f"The original text is in {source_lang_name}. "
                    f"Write exactly 1 sentence if the concept is simple (common words, basic objects), or 2-3 sentences if it's more complex (abstract concepts, verbs with multiple meanings, technical terms). "
                    f"Write the description entirely in {target_lang_name}. "
                    f"IMPORTANT: Do not include the word or phrase itself in the description. Describe what it means without mentioning the actual words (when possible). "
                    f"Make it suitable for language learning - clear, informative, and helpful for understanding the meaning without directly stating the word or phrase."
                )
            else:
                prompt = (
                    f"This is for a language learning app. Generate a concise, educational description for the word or phrase '{text}' in {target_lang_name}. "
                    f"Write exactly 1 sentence if the concept is simple (common words, basic objects), or 2-3 sentences if it's more complex (abstract concepts, verbs with multiple meanings, technical terms). "
                    f"Write the description entirely in {target_lang_name}. "
                    f"IMPORTANT: Do not include the word or phrase itself in the description. Describe what it means without mentioning the actual words (when possible). "
                    f"Make it suitable for language learning - clear, informative, and helpful for understanding the meaning without directly stating the word or phrase."
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
                    "maxOutputTokens": 1024,  # Increased to account for thinking tokens in models that support it
                    # Note: Some models support thinking tokens which count against maxOutputTokens
                    # If thinking tokens consume too much, consider using gemini-2.5-flash which uses thinking more efficiently
                }
            }
            
            # Try gemini-pro first, then fallback models if needed
            models_to_try = [self.model_name] + self.fallback_models
            last_error = None
            data = None
            
            for model_name in models_to_try:
                base_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
                try:
                    logger.debug(f"Trying model: {model_name}")
                    # Make API request
                    response = requests.post(
                        f"{base_url}?key={self.api_key}",
                        json=payload,
                        headers={"Content-Type": "application/json"},
                        timeout=30
                    )
                    
                    # Check for errors
                    response.raise_for_status()
                    data = response.json()
                    
                    # If we get here, the model worked - update our default if using fallback
                    if model_name != self.model_name:
                        self.model_name = model_name
                        self.base_url = base_url
                        logger.info(f"Successfully using fallback model: {model_name}")
                    else:
                        logger.debug(f"Successfully using primary model: {model_name}")
                    break  # Success, exit the loop
                    
                except requests.exceptions.HTTPError as e:
                    if e.response and e.response.status_code == 404:
                        # Model not found, try next one
                        logger.warning(f"Model {model_name} not found (404), trying next model...")
                        last_error = e
                        continue
                    else:
                        # Other HTTP error, re-raise
                        raise
                except Exception as e:
                    # Other error, re-raise
                    raise
            
            # If we exhausted all models, provide helpful error message
            if not data:
                error_detail = ""
                if last_error and hasattr(last_error, 'response') and last_error.response:
                    try:
                        error_data = last_error.response.json()
                        error_detail = f" - {error_data}"
                    except:
                        error_detail = f" - Status: {last_error.response.status_code}"
                
                raise Exception(
                    f"All Gemini models failed. Tried: {', '.join(models_to_try)}. "
                    f"Last error: {str(last_error) if last_error else 'Unknown'}{error_detail}. "
                    f"Please check: 1) Your API key is valid, 2) Generative Language API is enabled in your Google Cloud project, "
                    f"3) Your API key has access to Gemini models."
                )
            
            # Extract generated text
            if 'candidates' in data and len(data['candidates']) > 0:
                candidate = data['candidates'][0]
                
                # Check for finishReason
                finish_reason = candidate.get('finishReason', 'UNKNOWN')
                
                # Check if content has parts with text
                if 'content' in candidate:
                    content = candidate['content']
                    
                    # Check if parts exist and have text
                    if 'parts' in content and len(content['parts']) > 0:
                        description = content['parts'][0].get('text', '').strip()
                        if description:
                            if finish_reason == 'MAX_TOKENS':
                                logger.warning(f"Description was truncated (MAX_TOKENS) for '{text}' in {target_language}, but returning partial description")
                            logger.info(f"Generated description for '{text}' in {target_language}: '{description[:100]}...'")
                            return description
                        else:
                            logger.warning(f"Generated description is empty for '{text}' in {target_language}")
                    else:
                        # Content exists but no parts - might be truncated or empty
                        if finish_reason == 'MAX_TOKENS':
                            # Check if thinking tokens consumed the budget
                            usage_metadata = data.get('usageMetadata', {})
                            thoughts_tokens = usage_metadata.get('thoughtsTokenCount', 0)
                            if thoughts_tokens > 0:
                                logger.error(f"Description generation hit MAX_TOKENS limit. Thinking tokens used: {thoughts_tokens}. No text generated for '{text}' in {target_language}")
                                raise Exception(f"Description generation was truncated (MAX_TOKENS). The model used {thoughts_tokens} thinking tokens, leaving no room for output text. Try increasing maxOutputTokens further or using a model without thinking capabilities.")
                            else:
                                logger.error(f"Description generation hit MAX_TOKENS limit and returned no text for '{text}' in {target_language}")
                                raise Exception(f"Description generation was truncated (MAX_TOKENS) and returned no text. Try increasing maxOutputTokens or simplifying the prompt.")
                        else:
                            logger.warning(f"Content exists but no parts found. Finish reason: {finish_reason}")
                else:
                    # No content in candidate
                    if finish_reason == 'MAX_TOKENS':
                        logger.error(f"Description generation hit MAX_TOKENS limit for '{text}' in {target_language}")
                        raise Exception(f"Description generation was truncated (MAX_TOKENS) and returned no content. Try increasing maxOutputTokens.")
                    else:
                        logger.warning(f"No content in candidate. Finish reason: {finish_reason}")
                
                # If we get here, something unexpected happened
                if finish_reason not in ['STOP', 'MAX_TOKENS']:
                    logger.warning(f"Description generation finished with unexpected reason: {finish_reason}")
            
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

