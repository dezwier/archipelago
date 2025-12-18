"""
Image service for concept image generation and processing.
"""
import logging
import base64
import io
import requests
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, status
from PIL import Image as PILImage, ImageOps

from app.core.config import settings
from app.utils.assets_utils import ensure_assets_directory

logger = logging.getLogger(__name__)


def crop_to_square_and_resize(img: PILImage.Image, target_size: int = 300) -> PILImage.Image:
    """
    Crop image to square (center crop, equally from both sides) and resize to target size.
    
    This function:
    1. Crops the image to a square by taking the center, cropping equally from both sides
    2. Resizes the square crop to the target size
    
    Args:
        img: PIL Image to process
        target_size: Target size for the final square image (default: 300)
        
    Returns:
        Processed square image at target_size x target_size
    """
    width, height = img.size
    
    # Determine the size of the square crop (use the smaller dimension)
    crop_size = min(width, height)
    
    # Calculate crop coordinates (center crop, equally from both sides)
    left = (width - crop_size) // 2
    top = (height - crop_size) // 2
    right = left + crop_size
    bottom = top + crop_size
    
    # Crop to square
    img = img.crop((left, top, right, bottom))
    
    # Resize to target size
    img = img.resize((target_size, target_size), PILImage.Resampling.LANCZOS)
    
    return img


def build_image_prompt(term: str, description: Optional[str] = None, topic_description: Optional[str] = None) -> str:
    """
    Build the image generation prompt according to the specified format.
    
    Args:
        term: The concept term
        description: Optional concept description
        topic_description: Optional topic description
        
    Returns:
        The formatted prompt string
    """
    prompt = "Create a realistic square 300px image in the context of a language learning app. It should convey the meaning of this term as good as possible.\n\n"
    prompt += f"Term or phrase: {term}\n"
    
    if description:
        prompt += f"Use this meaning: {description}\n"
    
    if topic_description:
        prompt += f"\nConsider following context when illustrating the phrase above: {topic_description}"
    
    prompt += "IMPORTANT: The image must contain NO TEXT, NO WORDS, NO LETTERS, NO WRITING, NO LABELS, and NO WRITTEN SYMBOLS of any kind. The illustration should be purely visual and convey meaning through imagery only.\n\n"
    prompt += "There should also be no borders, outlines, or other elements in the image that are not part of the concept or term.\n\n"
    prompt += "Make it realistic looking.\n\n"
    return prompt


def generate_image_with_gemini(prompt: str) -> bytes:
    """
    Generate an image using Google's Gemini Imagen API.
    
    Uses the OpenAI-compatible endpoint for image generation.
    
    Args:
        prompt: The image generation prompt
        
    Returns:
        Image bytes (300x300 JPEG)
        
    Raises:
        HTTPException: If image generation fails
    """
    api_key = settings.google_gemini_api_key
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Google Gemini API key not configured. Please set GOOGLE_GEMINI_API_KEY environment variable."
        )
    
    # Use Gemini's native API endpoint for image generation (OpenAI-compatible format)
    # Note: Imagen currently only available via OpenAI-compatible endpoint
    base_url = "https://generativelanguage.googleapis.com/v1beta/openai/images/generations"
    model_name = "imagen-4.0-ultra-generate-001"  # Best quality Imagen model for highest detail and precision
    
    # Use both query parameter (like other Gemini endpoints) and Authorization header (required by endpoint)
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "model": model_name,
        "prompt": prompt,
        "n": 1,
        "response_format": "b64_json",  # Get base64 encoded image
        "size": "1024x1024"  # Minimum supported size, will be resized to 300x300
    }
    
    try:
        logger.info(f"Generating image with Gemini Imagen model: {model_name}")
        logger.info(f"Request URL: {base_url}?key=***")
        logger.info(f"Request payload: {payload}")
        # Use query parameter (standard Gemini auth) AND Authorization header (required by endpoint)
        response = requests.post(
            f"{base_url}?key={api_key}",
            json=payload,
            headers=headers,
            timeout=60
        )
        
        # Log response status and initial structure for debugging
        logger.info(f"Gemini API response status: {response.status_code}")
        logger.info(f"Gemini API response headers: {dict(response.headers)}")
        
        # Check for HTTP errors
        if not response.ok:
            try:
                error_data = response.json()
                logger.error(f"Gemini API HTTP error response: {error_data}")
                error_info = error_data.get("error", {})
                if isinstance(error_info, dict):
                    error_msg = error_info.get("message", f"HTTP {response.status_code}: {response.text[:200]}")
                else:
                    error_msg = str(error_info) if error_info else f"HTTP {response.status_code}: {response.text[:200]}"
                raise Exception(f"Gemini API error: {error_msg}")
            except ValueError:
                # Response is not JSON
                raise Exception(f"Gemini API HTTP error {response.status_code}: {response.text[:500]}")
        
        response.raise_for_status()
        data = response.json()
        
        # Log the full response structure for debugging
        logger.info(f"Gemini API response structure: {list(data.keys())}")
        logger.info(f"Gemini API full response: {data}")
        
        # Check for error in response first
        if "error" in data:
            error_info = data.get("error", {})
            error_msg = error_info.get("message", "Unknown error") if isinstance(error_info, dict) else str(error_info)
            logger.error(f"Gemini API returned error: {error_info}")
            raise Exception(f"Gemini API error: {error_msg}")
        
        # Check if response only contains model name (indicates an error or incomplete response)
        # This can happen if the API key doesn't have image generation access, quota exceeded, or model not available
        if len(data) == 1 and "model" in data and "data" not in data:
            error_detail = (
                f"Gemini API returned incomplete response (only model name). "
                f"Full response: {data}. "
                f"This may indicate: (1) API key doesn't have image generation access, "
                f"(2) Quota exceeded, (3) Model not available, or (4) Authentication issue. "
                f"Response status was {response.status_code}."
            )
            logger.error(error_detail)
            raise Exception(error_detail)
        
        # Log the response structure for debugging
        if "data" in data:
            logger.debug(f"Gemini API data array length: {len(data.get('data', []))}")
        else:
            logger.warning(f"Gemini API response missing 'data' field. Full response: {data}")
        
        # Extract base64 encoded image
        if "data" not in data or len(data["data"]) == 0:
            error_detail = f"No image data in response. Response keys: {list(data.keys())}. Full response: {data}"
            logger.error(error_detail)
            raise Exception(error_detail)
        
        # Check if b64_json is present
        if "b64_json" not in data["data"][0]:
            error_detail = f"Response data missing 'b64_json' field. Available keys: {list(data['data'][0].keys())}"
            logger.error(error_detail)
            raise Exception(error_detail)
        
        image_b64 = data["data"][0]["b64_json"]
        image_bytes = base64.b64decode(image_b64)
        
        # Crop to square and resize to 300x300
        img = PILImage.open(io.BytesIO(image_bytes))
        img = crop_to_square_and_resize(img, target_size=300)
        
        # Convert to JPEG bytes
        output = io.BytesIO()
        img.save(output, format="JPEG", quality=95)
        return output.getvalue()
        
    except requests.exceptions.RequestException as e:
        error_msg = f"Gemini API request failed: {str(e)}"
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_data = e.response.json()
                error_msg += f" - Response: {error_data}"
                logger.error(f"Gemini API error response: {error_data}")
            except:
                error_msg += f" - Status: {e.response.status_code}, Body: {e.response.text[:500]}"
                logger.error(f"Gemini API error (non-JSON): Status {e.response.status_code}, Body: {e.response.text[:500]}")
        logger.error(error_msg)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image with Gemini: {error_msg}"
        )
    except Exception as e:
        logger.error(f"Failed to process Gemini image response: {str(e)}")
        # Include more context in the error message
        error_detail = str(e)
        if "No image data in response" in error_detail:
            error_detail += ". The Gemini API may have returned an error or unexpected response format."
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image: {error_detail}"
        )


def process_uploaded_image(file_content: bytes) -> bytes:
    """
    Process an uploaded image file: validate, apply EXIF correction, and resize.
    
    Args:
        file_content: Raw image file bytes
        
    Returns:
        Processed image bytes (300x300 JPEG)
        
    Raises:
        HTTPException: If image processing fails
    """
    try:
        img = PILImage.open(io.BytesIO(file_content))
        # Apply EXIF orientation correction to preserve original orientation
        img = ImageOps.exif_transpose(img)
        # Convert to RGB if necessary (handles RGBA, P, etc.)
        if img.mode != 'RGB':
            img = img.convert('RGB')
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid image file: {str(e)}"
        )
    
    # Crop to square and resize to 300x300
    img = crop_to_square_and_resize(img, target_size=300)
    
    # Convert to JPEG bytes
    output = io.BytesIO()
    img.save(output, format="JPEG", quality=95)
    return output.getvalue()


def get_concept_image_path(concept_id: int) -> Path:
    """
    Get the file path for a concept's image file.
    
    Args:
        concept_id: The concept ID
        
    Returns:
        Path to the image file
    """
    assets_dir = ensure_assets_directory()
    return assets_dir / f"{concept_id}.jpg"


def get_image_path_from_url(image_url: str) -> Optional[Path]:
    """
    Get the file path from an image URL.
    
    Args:
        image_url: The image URL (e.g., "/assets/123.jpg")
        
    Returns:
        Path to the image file, or None if URL format is not supported
    """
    if not image_url or not image_url.startswith("/assets/"):
        return None
    
    image_filename = image_url.replace("/assets/", "")
    assets_dir = ensure_assets_directory()
    return assets_dir / image_filename


def save_concept_image(concept_id: int, image_bytes: bytes) -> Path:
    """
    Save image bytes to the assets directory for a concept.
    
    Args:
        concept_id: The concept ID
        image_bytes: Image bytes to save
        
    Returns:
        Path to the saved image file
    """
    image_path = get_concept_image_path(concept_id)
    
    # Explicitly remove existing file to ensure overwrite
    if image_path.exists():
        try:
            image_path.unlink()
            logger.info(f"Removed existing file {image_path} before overwriting")
        except Exception as e:
            logger.warning(f"Failed to remove existing file {image_path}: {str(e)}, will attempt to overwrite anyway")
    
    try:
        with open(image_path, "wb") as f:
            f.write(image_bytes)
        logger.info(f"Saved image to {image_path}")
    except Exception as e:
        logger.error(f"Failed to save image to {image_path}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save image: {str(e)}"
        )
    
    return image_path


def delete_concept_image_file(image_url: Optional[str]) -> bool:
    """
    Delete an image file from the assets directory if it's a local asset.
    
    Args:
        image_url: The image URL (e.g., "/assets/123.jpg")
        
    Returns:
        True if file was deleted, False otherwise
    """
    if not image_url:
        return False
    
    image_path = get_image_path_from_url(image_url)
    if not image_path:
        return False
    
    if image_path.exists():
        try:
            image_path.unlink()
            logger.info(f"Deleted image file: {image_path}")
            return True
        except Exception as e:
            logger.warning(f"Failed to delete image file {image_path}: {str(e)}")
            return False
    
    return False

