from app.core.config import settings
import requests
import logging
import os
from typing import List
from datetime import date

logger = logging.getLogger(__name__)


class ImageService:
    """Service for retrieving images using Google Custom Search JSON API."""
    
    # Free tier limit: 100 queries per day
    FREE_TIER_LIMIT = 100
    WARNING_THRESHOLD_80 = 80
    WARNING_THRESHOLD_90 = 90
    
    def __init__(self):
        """Initialize the image service."""
        self.api_key = settings.google_custom_search_api_key
        self.search_engine_id = settings.google_custom_search_engine_id
        self.base_url = "https://www.googleapis.com/customsearch/v1"
        
        # Rate limiting: track daily API calls
        self._daily_call_count = 0
        self._last_reset_date = date.today()
        
        # Debug logging
        logger.info(f"ImageService initialized. API key present: {bool(self.api_key)}")
        logger.info(f"ImageService initialized. Search Engine ID present: {bool(self.search_engine_id)}")
        if not self.api_key:
            logger.warning("Google Custom Search API key not configured. Image retrieval will fail.")
        if not self.search_engine_id:
            logger.warning("Google Custom Search Engine ID not configured. Image retrieval will fail.")
    
    def _check_and_reset_daily_counter(self):
        """Reset daily counter if it's a new day."""
        today = date.today()
        if today != self._last_reset_date:
            logger.info(f"Resetting daily API call counter. Previous count: {self._daily_call_count}")
            self._daily_call_count = 0
            self._last_reset_date = today
    
    def _increment_and_check_limit(self) -> bool:
        """
        Increment API call counter and check if limit is reached.
        
        Returns:
            True if API call should proceed, False if limit exceeded
        """
        self._check_and_reset_daily_counter()
        
        self._daily_call_count += 1
        
        # Warn at thresholds
        if self._daily_call_count == self.WARNING_THRESHOLD_80:
            logger.warning(
                f"⚠️  Google Custom Search API: {self._daily_call_count}/{self.FREE_TIER_LIMIT} calls used today. "
                f"Approaching free tier limit. {self.FREE_TIER_LIMIT - self._daily_call_count} calls remaining."
            )
        elif self._daily_call_count == self.WARNING_THRESHOLD_90:
            logger.warning(
                f"⚠️  Google Custom Search API: {self._daily_call_count}/{self.FREE_TIER_LIMIT} calls used today. "
                f"Close to free tier limit! {self.FREE_TIER_LIMIT - self._daily_call_count} calls remaining."
            )
        elif self._daily_call_count >= self.FREE_TIER_LIMIT:
            logger.error(
                f"🚨 Google Custom Search API: {self._daily_call_count}/{self.FREE_TIER_LIMIT} calls used today. "
                f"FREE TIER LIMIT EXCEEDED! Additional calls will be charged. "
                f"Counter will reset tomorrow."
            )
            return False  # Don't block, but warn heavily
        else:
            # Log every 10 calls for visibility
            if self._daily_call_count % 10 == 0:
                logger.info(
                    f"Google Custom Search API: {self._daily_call_count}/{self.FREE_TIER_LIMIT} calls used today. "
                    f"{self.FREE_TIER_LIMIT - self._daily_call_count} calls remaining."
                )
        
        return True
    
    def _build_clean_image_query(self, query: str) -> str:
        """
        Build an enhanced query to find clean, relevant illustrations.
        
        Strategies:
        - Use "illustration" for cleaner, simpler images
        - Add "simple" or "clean" to avoid complex/cluttered images
        - Use quotes around the main concept to ensure it's the focus
        - Add "no text" to avoid images with text overlays
        - Use "educational" or "vocabulary" to find learning-appropriate images
        
        Args:
            query: Original search query (English phrase/concept)
            
        Returns:
            Enhanced query string optimized for clean illustrations
        """
        query = query.strip()
        
        # Remove quotes if present (we'll add our own)
        query = query.strip('"\'')
        
        # Build query optimized for vocabulary learning illustrations
        # Strategy: Put the concept first (in quotes for exact match), then add illustration keywords
        # This ensures the concept is the primary focus, not the illustration type
        # Using "simple illustration" helps find clean, educational-style images
        enhanced = f'"{query}" simple illustration'
        
        return enhanced
    
    def search_images(
        self,
        query: str,
        num_results: int = 4,
        image_size: str = "MEDIUM"
    ) -> List[str]:
        """
        Search for images using Google Custom Search JSON API.
        Queries are enhanced with "illustration without text" prefix to get cleaner, text-free images.
        
        Args:
            query: Search query text (will be prefixed with "illustration without text")
            num_results: Number of image URLs to return (default: 4, max: 10)
            image_size: Image size filter - "ICON", "SMALL", "MEDIUM", "LARGE", "XLARGE", "XXLARGE", "HUGE" (default: "MEDIUM")
        
        Returns:
            List of image URLs (up to num_results)
        
        Raises:
            Exception: If image search fails
        """
        # Re-check API key from settings in case it was loaded after initialization
        if not self.api_key:
            self.api_key = settings.google_custom_search_api_key
        
        if not self.search_engine_id:
            self.search_engine_id = settings.google_custom_search_engine_id
        
        # Fallback: try reading directly from environment
        if not self.api_key:
            self.api_key = os.getenv("GOOGLE_CUSTOM_SEARCH_API_KEY", "")
        
        if not self.search_engine_id:
            self.search_engine_id = os.getenv("GOOGLE_CUSTOM_SEARCH_ENGINE_ID", "")
        
        if not self.api_key:
            raise ValueError("Google Custom Search API key not configured. Please set GOOGLE_CUSTOM_SEARCH_API_KEY environment variable.")
        
        if not self.search_engine_id:
            raise ValueError("Google Custom Search Engine ID not configured. Please set GOOGLE_CUSTOM_SEARCH_ENGINE_ID environment variable.")
        
        # Limit num_results to API maximum
        num_results = min(num_results, 10)
        
        # Check rate limit before making API call
        if not self._increment_and_check_limit():
            # Limit exceeded, but we'll still try (user might have paid tier)
            logger.warning(f"Proceeding with API call despite exceeding free tier limit ({self._daily_call_count} calls today)")
        
        try:
            # Enhance query to get cleaner, text-free images
            enhanced_query = self._build_clean_image_query(query)
            
            logger.debug(f"Searching for images with query: '{enhanced_query}' (original: '{query}'), size: {image_size}, num_results: {num_results} (API call #{self._daily_call_count})")
            
            # Build request parameters
            # Try clipart first for cleaner illustrations, but also allow photos
            # We'll prioritize clipart but won't restrict too much
            params = {
                "key": self.api_key,
                "cx": self.search_engine_id,
                "q": enhanced_query,
                "searchType": "image",
                "num": num_results,
                "imgSize": "MEDIUM",  # Use LARGE for better quality illustrations
                "imgType": "clipart",  # Use clipart for cleaner, simpler illustrations (better for vocabulary)
                "safe": "active"  # Safe search
            }
            
            # Make API request
            response = requests.get(
                self.base_url,
                params=params,
                timeout=30
            )
            
            # Check for errors
            response.raise_for_status()
            data = response.json()
            
            # Extract image URLs
            image_urls = []
            if "items" in data:
                for item in data["items"]:
                    if "link" in item:
                        image_urls.append(item["link"])
                        logger.debug(f"Found image URL: {item['link']}")
            
            logger.info(f"Retrieved {len(image_urls)} image URL(s) for query: '{enhanced_query}' (original: '{query}')")
            
            # If we got fewer results than requested, that's okay - just return what we have
            if len(image_urls) < num_results:
                logger.warning(f"Requested {num_results} images but only found {len(image_urls)} for query: '{enhanced_query}' (original: '{query}')")
            
            return image_urls
            
        except requests.exceptions.HTTPError as e:
            error_msg = f"Image search API request failed: {str(e)}"
            if hasattr(e, 'response') and e.response is not None:
                status_code = e.response.status_code
                
                # Handle rate limiting (429 Too Many Requests)
                if status_code == 429:
                    logger.error(
                        f"🚨 Google Custom Search API rate limit exceeded (HTTP 429)! "
                        f"Daily calls used: {self._daily_call_count}/{self.FREE_TIER_LIMIT}. "
                        f"Please wait or upgrade your API quota."
                    )
                    error_msg = f"API rate limit exceeded. Daily calls used: {self._daily_call_count}/{self.FREE_TIER_LIMIT}"
                
                try:
                    error_data = e.response.json()
                    error_msg += f" - {error_data}"
                except:
                    error_msg += f" - Status: {status_code}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except requests.exceptions.RequestException as e:
            error_msg = f"Image search API request failed: {str(e)}"
            logger.error(error_msg)
            raise Exception(error_msg)
        except Exception as e:
            logger.error(f"Image search failed: {str(e)}")
            raise Exception(f"Image search failed: {str(e)}")
    
    def get_daily_usage(self) -> dict:
        """
        Get current daily API usage statistics.
        
        Returns:
            Dict with 'calls_used', 'calls_remaining', 'limit', 'date'
        """
        self._check_and_reset_daily_counter()
        return {
            'calls_used': self._daily_call_count,
            'calls_remaining': max(0, self.FREE_TIER_LIMIT - self._daily_call_count),
            'limit': self.FREE_TIER_LIMIT,
            'date': str(self._last_reset_date)
        }
    
    def get_images_for_concept(
        self,
        concept_text: str,
        num_images: int = 4
    ) -> List[str]:
        """
        Get images for a concept using the concept text as search query.
        
        Args:
            concept_text: The concept text to search for (typically English translation)
            num_images: Number of images to retrieve (default: 4)
        
        Returns:
            List of image URLs
        """
        if not concept_text or not concept_text.strip():
            logger.warning("Empty concept text provided for image search")
            return []
        
        try:
            return self.search_images(
                query=concept_text.strip(),
                num_results=num_images,
                image_size="LARGE"  # Large size for better quality illustrations
            )
        except Exception as e:
            logger.error(f"Failed to get images for concept '{concept_text}': {str(e)}")
            return []


# Create a singleton instance
image_service = ImageService()

