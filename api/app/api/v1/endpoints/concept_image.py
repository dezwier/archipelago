"""
Endpoint for generating images for concepts.
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import FileResponse
from sqlmodel import Session, select
from typing import Optional
from pydantic import BaseModel, Field
import requests
import logging
import traceback
import base64
from pathlib import Path
from datetime import datetime, timezone
from PIL import Image as PILImage, ImageOps
import io

from app.core.database import get_session
from app.core.config import settings
from app.models.models import Concept, Topic

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concept-image", tags=["concept-image"])


class GenerateImageRequest(BaseModel):
    """Request schema for generating a concept image."""
    concept_id: int = Field(..., description="The concept ID")
    term: Optional[str] = Field(None, description="The concept term (will use concept.term if not provided)")
    description: Optional[str] = Field(None, description="The concept description (will use concept.description if not provided)")
    topic_id: Optional[int] = Field(None, description="The topic ID (will use concept.topic_id if not provided)")
    topic_description: Optional[str] = Field(None, description="The topic description (will use topic.description if not provided)")


class GenerateImagePreviewRequest(BaseModel):
    """Request schema for generating an image preview without a concept."""
    term: str = Field(..., description="The term or phrase")
    description: Optional[str] = Field(None, description="The description")
    topic_description: Optional[str] = Field(None, description="The topic description")


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
    
    # Use Gemini's OpenAI-compatible endpoint for image generation
    base_url = "https://generativelanguage.googleapis.com/v1beta/openai/images/generations"
    model_name = "imagen-4.0-ultra-generate-001"  # Best quality Imagen model for highest detail and precision
    
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
        logger.debug(f"Request URL: {base_url}")
        logger.debug(f"Request payload: {payload}")
        # Use Authorization header (required for OpenAI-compatible endpoint)
        response = requests.post(
            base_url,
            json=payload,
            headers=headers,
            timeout=60
        )
        logger.info(f"Response status code: {response.status_code}")
        if response.status_code != 200:
            logger.error(f"Non-200 response: {response.status_code}, Response text: {response.text[:500]}")
        response.raise_for_status()
        
        # Try to parse JSON response
        try:
            data = response.json()
        except ValueError as e:
            logger.error(f"Failed to parse JSON response: {str(e)}, Response text: {response.text[:500]}")
            raise Exception(f"Invalid JSON response from Gemini API: {str(e)}")
        
        # Check for error in response
        if "error" in data:
            error_info = data["error"]
            error_msg = error_info.get("message", "Unknown error") if isinstance(error_info, dict) else str(error_info)
            logger.error(f"Gemini API returned error: {error_msg}")
            raise Exception(f"Gemini API error: {error_msg}")
        
        # Log the response structure for debugging
        logger.info(f"Gemini API response keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
        logger.debug(f"Gemini API response: {data}")
        
        # Extract base64 encoded image
        # Handle different possible response structures
        image_b64 = None
        
        # Try OpenAI-compatible format first: data[0].b64_json
        if "data" in data and isinstance(data["data"], list) and len(data["data"]) > 0:
            if "b64_json" in data["data"][0]:
                image_b64 = data["data"][0]["b64_json"]
            elif "url" in data["data"][0]:
                # If URL is returned instead, fetch it
                image_url = data["data"][0]["url"]
                logger.info(f"Image URL returned, fetching: {image_url}")
                img_response = requests.get(image_url, timeout=30)
                img_response.raise_for_status()
                image_bytes = img_response.content
                # Skip base64 decoding and go straight to image processing
                img = PILImage.open(io.BytesIO(image_bytes))
                img = crop_to_square_and_resize(img, target_size=300)
                output = io.BytesIO()
                img.save(output, format="JPEG", quality=95)
                return output.getvalue()
        
        # Try alternative response structure (direct b64_json field)
        if image_b64 is None and "b64_json" in data:
            image_b64 = data["b64_json"]
        
        # Try alternative response structure (images array)
        if image_b64 is None and "images" in data and isinstance(data["images"], list) and len(data["images"]) > 0:
            if "b64_json" in data["images"][0]:
                image_b64 = data["images"][0]["b64_json"]
        
        if image_b64 is None:
            logger.error(f"No image data found in response. Response structure: {data}")
            raise Exception(f"No image data in response. Response keys: {list(data.keys()) if isinstance(data, dict) else 'Not a dict'}")
        
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
                error_msg += f" - {error_data}"
            except:
                error_msg += f" - Status: {e.response.status_code}"
        logger.exception(f"Gemini API request exception: {error_msg}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image with Gemini: {error_msg}"
        )
    except Exception as e:
        error_detail = str(e)
        # If we have the response, try to include it in the error
        if 'response' in locals() and response is not None:
            try:
                response_text = response.text[:500] if hasattr(response, 'text') else str(response.content[:500])
                logger.exception(f"Failed to process Gemini image response: {error_detail}. Response: {response_text}")
                error_detail += f". API response: {response_text}"
            except:
                logger.exception(f"Failed to process Gemini image response: {error_detail}")
        else:
            logger.exception(f"Failed to process Gemini image response: {error_detail}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image: {error_detail}"
        )


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
    logger.info(f"Using assets directory: {assets_dir}")
    return assets_dir


@router.post("/generate")
async def generate_concept_image(
    request: GenerateImageRequest,
    session: Session = Depends(get_session)
):
    """
    Generate an image for a concept.
    
    This endpoint:
    1. Takes the concept term, description (if present), topic, and topic description
    2. Builds a prompt according to the specified format
    3. Generates an image using an image generation API
    4. Saves it to the assets folder as {concept_id}.jpg
    5. Stores the image record in the database
    6. Returns the image file
    
    Args:
        request: GenerateImageRequest with concept_id, term, description, topic_id, topic_description
        session: Database session
        
    Returns:
        The generated image file
    """
    # Verify concept exists and get concept data
    concept = session.get(Concept, request.concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept with ID {request.concept_id} not found"
        )
    
    # Use provided term or fall back to concept.term
    term = request.term if request.term else (concept.term or "")
    if not term:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term is required (either in request or concept)"
        )
    
    # Use provided description or fall back to concept.description
    description = request.description if request.description else concept.description
    
    # Get topic information
    topic_description = request.topic_description
    topic_id = request.topic_id if request.topic_id else concept.topic_id
    
    if topic_id:
        topic = session.get(Topic, topic_id)
        if topic:
            # Use provided topic_description or fall back to topic.description
            if not topic_description and topic.description:
                topic_description = topic.description
    
    # Build the prompt
    prompt = build_image_prompt(
        term=term,
        description=description,
        topic_description=topic_description
    )
    
    logger.info(f"Generating image for concept {request.concept_id} with prompt: {prompt[:200]}...")
    
    # Generate the image using Gemini
    # Try Gemini first (primary), fallback to OpenAI if Gemini key not available
    image_bytes = None
    try:
        # Try Gemini first (preferred)
        if settings.google_gemini_api_key:
            image_bytes = generate_image_with_gemini(prompt)
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No image generation API key configured. Please set GOOGLE_GEMINI_API_KEY or OPENAI_API_KEY environment variable."
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.exception(f"Failed to generate image for concept {request.concept_id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image: {str(e)}"
        )
    
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image generation returned no data"
        )
    
    # Ensure assets directory exists
    assets_dir = ensure_assets_directory()
    
    # Save image to assets folder
    image_filename = f"{request.concept_id}.jpg"
    image_path = assets_dir / image_filename
    
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
    
    # Create image URL (relative path or full URL depending on your setup)
    # For now, we'll store the relative path
    image_url = f"/assets/{image_filename}"
    
    # Delete existing image file if it exists (different filename)
    if concept.image_url and concept.image_url.startswith("/assets/"):
        existing_image_filename = concept.image_url.replace("/assets/", "")
        existing_image_path = assets_dir / existing_image_filename
        if existing_image_path.exists() and existing_image_path != image_path:
            try:
                existing_image_path.unlink()
                logger.info(f"Deleted existing image file: {existing_image_path}")
            except Exception as e:
                logger.warning(f"Failed to delete existing image file {existing_image_path}: {str(e)}")
    
    # Update concept with new image URL
    try:
        concept.image_url = image_url
        concept.updated_at = datetime.now(timezone.utc)
        session.add(concept)
        session.commit()
        session.refresh(concept)
    except Exception as e:
        logger.exception(f"Failed to update concept {request.concept_id} with image URL: {str(e)}")
        # Don't fail the request if database update fails - image was already saved
        logger.warning(f"Image saved to {image_path} but database update failed")
    
    # Return the image file
    try:
        return FileResponse(
            path=str(image_path),
            media_type="image/jpeg",
            filename=image_filename
        )
    except Exception as e:
        logger.exception(f"Failed to return image file {image_path}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to return image file: {str(e)}"
        )


@router.post("/upload")
async def upload_concept_image(
    file: UploadFile = File(...),
    concept_id: Optional[int] = Form(None),
    session: Session = Depends(get_session)
):
    """
    Upload an image file to overwrite an existing concept image.
    
    This endpoint:
    1. Accepts an image file upload
    2. Optionally accepts a concept_id as a form field
    3. If concept_id is provided, saves the image as {concept_id}.jpg and updates the database
    4. If concept_id is not provided, saves the file with its original name
    5. Resizes the image to 300x300 if needed
    6. Returns the saved image file
    
    Args:
        file: The image file to upload
        concept_id: Optional concept ID (provided as form field)
        session: Database session
        
    Returns:
        The uploaded image file
    """
    try:
        # Read the file content
        file_content = await file.read()
        
        # Validate it's an image
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
        image_bytes = output.getvalue()
        
        # Ensure assets directory exists
        assets_dir = ensure_assets_directory()
        
        # Determine filename
        # If concept_id is provided, use it; otherwise use the original filename
        if concept_id:
            image_filename = f"{concept_id}.jpg"
            
            # Verify concept exists
            concept = session.get(Concept, concept_id)
            if not concept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Concept with ID {concept_id} not found"
                )
        else:
            # Use original filename but ensure .jpg extension
            original_name = Path(file.filename).stem if file.filename else "uploaded"
            image_filename = f"{original_name}.jpg"
        
        image_path = assets_dir / image_filename
        
        # Explicitly remove existing file to ensure overwrite
        if image_path.exists():
            try:
                image_path.unlink()
                logger.info(f"Removed existing file {image_path} before overwriting")
            except Exception as e:
                logger.warning(f"Failed to remove existing file {image_path}: {str(e)}, will attempt to overwrite anyway")
        
        # Save the image
        try:
            with open(image_path, "wb") as f:
                f.write(image_bytes)
            logger.info(f"Uploaded and saved image to {image_path}")
        except Exception as e:
            logger.error(f"Failed to save uploaded image to {image_path}: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Failed to save image: {str(e)}"
            )
        
        # If concept_id was provided, update the database
        if concept_id:
            image_url = f"/assets/{image_filename}"
            
            # Get the concept
            concept = session.get(Concept, concept_id)
            if concept:
                # Delete existing image file if it exists (different filename)
                if concept.image_url and concept.image_url.startswith("/assets/"):
                    existing_image_filename = concept.image_url.replace("/assets/", "")
                    existing_image_path = assets_dir / existing_image_filename
                    if existing_image_path.exists() and existing_image_path != image_path:
                        try:
                            existing_image_path.unlink()
                            logger.info(f"Deleted existing image file: {existing_image_path}")
                        except Exception as e:
                            logger.warning(f"Failed to delete existing image file {existing_image_path}: {str(e)}")
                
                # Update concept with new image URL
                concept.image_url = image_url
                concept.updated_at = datetime.now(timezone.utc)
                session.add(concept)
                session.commit()
        
        # Return the image file
        return FileResponse(
            path=str(image_path),
            media_type="image/jpeg",
            filename=image_filename
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to upload image: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload image: {str(e)}"
        )


@router.post("/upload/{concept_id}")
async def upload_concept_image_with_id(
    concept_id: int,
    file: UploadFile = File(...),
    session: Session = Depends(get_session)
):
    """
    Upload an image file for a specific concept ID (path parameter version).
    
    This is a convenience endpoint that accepts concept_id as a path parameter.
    
    Args:
        concept_id: The concept ID
        file: The image file to upload
        session: Database session
        
    Returns:
        The uploaded image file
    """
    # Verify concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept with ID {concept_id} not found"
        )
    
    # Read the file content
    file_content = await file.read()
    
    # Validate it's an image
    try:
        img = PILImage.open(io.BytesIO(file_content))
        # Apply EXIF orientation correction to preserve original orientation
        img = ImageOps.exif_transpose(img)
        # Convert to RGB if necessary
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
    image_bytes = output.getvalue()
    
    # Ensure assets directory exists
    assets_dir = ensure_assets_directory()
    
    # Save as {concept_id}.jpg
    image_filename = f"{concept_id}.jpg"
    image_path = assets_dir / image_filename
    
    # Explicitly remove existing file to ensure overwrite
    if image_path.exists():
        try:
            image_path.unlink()
            logger.info(f"Removed existing file {image_path} before overwriting")
        except Exception as e:
            logger.warning(f"Failed to remove existing file {image_path}: {str(e)}, will attempt to overwrite anyway")
    
    # Save the image
    try:
        with open(image_path, "wb") as f:
            f.write(image_bytes)
        logger.info(f"Uploaded and saved image to {image_path}")
    except Exception as e:
        logger.error(f"Failed to save uploaded image to {image_path}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save image: {str(e)}"
        )
    
    # Update database
    image_url = f"/assets/{image_filename}"
    
    # Delete existing image file if it exists (different filename)
    if concept.image_url and concept.image_url.startswith("/assets/"):
        existing_image_filename = concept.image_url.replace("/assets/", "")
        existing_image_path = assets_dir / existing_image_filename
        if existing_image_path.exists() and existing_image_path != image_path:
            try:
                existing_image_path.unlink()
                logger.info(f"Deleted existing image file: {existing_image_path}")
            except Exception as e:
                logger.warning(f"Failed to delete existing image file {existing_image_path}: {str(e)}")
    
    # Update concept with new image URL
    concept.image_url = image_url
    concept.updated_at = datetime.now(timezone.utc)
    session.add(concept)
    session.commit()
    session.refresh(concept)
    
    # Return the image file
    return FileResponse(
        path=str(image_path),
        media_type="image/jpeg",
        filename=image_filename
    )


@router.post("/generate-preview")
async def generate_image_preview(
    request: GenerateImagePreviewRequest,
):
    """
    Generate an image preview without requiring a concept.
    
    This endpoint:
    1. Takes the term, description (if present), and topic description
    2. Builds a prompt according to the specified format
    3. Generates an image using Gemini
    4. Returns the image bytes directly (does not save to database)
    
    Args:
        request: GenerateImagePreviewRequest with term, description, topic_description
        
    Returns:
        The generated image file as bytes
    """
    # Validate term is not empty
    term = request.term.strip() if request.term else ""
    if not term:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Term is required"
        )
    
    # Build the prompt
    prompt = build_image_prompt(
        term=term,
        description=request.description,
        topic_description=request.topic_description
    )
    
    logger.info(f"Generating image preview for term '{term}' with prompt: {prompt[:200]}...")
    
    # Generate the image using Gemini
    image_bytes = None
    try:
        # Try Gemini first (preferred)
        if settings.google_gemini_api_key:
            image_bytes = generate_image_with_gemini(prompt)
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No image generation API key configured. Please set GOOGLE_GEMINI_API_KEY environment variable."
            )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to generate image: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image: {str(e)}"
        )
    
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Image generation returned no data"
        )
    
    # Return the image bytes directly
    from fastapi.responses import Response
    return Response(
        content=image_bytes,
        media_type="image/jpeg",
        headers={"Content-Disposition": "inline; filename=generated-image.jpg"}
    )


@router.delete("/{concept_id}")
async def delete_concept_images(
    concept_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete all images for a specific concept.
    
    This endpoint:
    1. Deletes all image records from the database for the concept
    2. Deletes the image files from the assets directory
    
    Args:
        concept_id: The concept ID
        session: Database session
        
    Returns:
        Dict with success status and message
    """
    # Verify concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept with ID {concept_id} not found"
        )
    
    # Check if concept has an image
    if not concept.image_url:
        return {
            "success": True,
            "message": f"No image found for concept {concept_id}",
            "deleted_count": 0,
            "deleted_files": 0
        }
    
    # Delete image file from assets directory if it's a local asset
    deleted_files = 0
    if concept.image_url.startswith("/assets/"):
        assets_dir = ensure_assets_directory()
        image_filename = concept.image_url.replace("/assets/", "")
        image_path = assets_dir / image_filename
        
        # Delete the image file if it exists
        if image_path.exists():
            try:
                image_path.unlink()
                logger.info(f"Deleted image file: {image_path}")
                deleted_files = 1
            except Exception as e:
                logger.warning(f"Failed to delete image file {image_path}: {str(e)}")
    elif concept.image_url.startswith("http://") or concept.image_url.startswith("https://"):
        # External URL, no file to delete
        logger.info(f"Skipping external image URL: {concept.image_url}")
    
    # Clear the image URL from the concept
    concept.image_url = None
    concept.updated_at = datetime.now(timezone.utc)
    session.add(concept)
    session.commit()
    
    return {
        "success": True,
        "message": f"Deleted image for concept {concept_id}",
        "deleted_count": 1,
        "deleted_files": deleted_files
    }
