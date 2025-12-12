"""
Endpoint for generating images for concepts.
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query
from fastapi.responses import FileResponse
from sqlmodel import Session, select
from typing import Optional
from pydantic import BaseModel, Field
import requests
import os
import logging
import base64
from pathlib import Path
from datetime import datetime, timezone
from PIL import Image as PILImage
import io

from app.core.database import get_session
from app.core.config import settings
from app.models.models import Concept, Topic, Image
from app.api.v1.endpoints.flashcard_helpers import retrieve_images_for_concept
from app.services.image_service import image_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concept-image", tags=["concept-image"])


class GenerateImageRequest(BaseModel):
    """Request schema for generating a concept image."""
    concept_id: int = Field(..., description="The concept ID")
    term: Optional[str] = Field(None, description="The concept term (will use concept.term if not provided)")
    description: Optional[str] = Field(None, description="The concept description (will use concept.description if not provided)")
    topic_id: Optional[int] = Field(None, description="The topic ID (will use concept.topic_id if not provided)")
    topic_description: Optional[str] = Field(None, description="The topic description (will use topic.description if not provided)")


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
        response = requests.post(
            f"{base_url}?key={api_key}",
            json=payload,
            headers=headers,
            timeout=60
        )
        response.raise_for_status()
        data = response.json()
        
        # Extract base64 encoded image
        if "data" not in data or len(data["data"]) == 0:
            raise Exception("No image data in response")
        
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
                error_msg += f" - {error_data}"
            except:
                error_msg += f" - Status: {e.response.status_code}"
        logger.error(error_msg)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image with Gemini: {error_msg}"
        )
    except Exception as e:
        logger.error(f"Failed to process Gemini image response: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to generate image: {str(e)}"
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
    
    # Enforce one image per concept: Delete ALL existing images for this concept
    existing_images = session.exec(
        select(Image).where(Image.concept_id == request.concept_id)
    ).all()
    
    # Delete all existing images (both database records and files)
    if existing_images:
        assets_dir = ensure_assets_directory()
        for img in existing_images:
            # Delete image file if it's a local asset
            if img.url and img.url.startswith("/assets/"):
                image_filename_to_delete = img.url.replace("/assets/", "")
                image_path_to_delete = assets_dir / image_filename_to_delete
                if image_path_to_delete.exists():
                    try:
                        image_path_to_delete.unlink()
                        logger.info(f"Deleted existing image file: {image_path_to_delete}")
                    except Exception as e:
                        logger.warning(f"Failed to delete image file {image_path_to_delete}: {str(e)}")
            
            # Delete database record
            session.delete(img)
        
        session.commit()
        logger.info(f"Deleted {len(existing_images)} existing image(s) for concept {request.concept_id}")
    
    # The new generated image is always the only (and therefore primary) image
    is_primary = True
    
    image_record = Image(
        concept_id=request.concept_id,
        url=image_url,
        image_type="illustration",
        is_primary=is_primary,
        source="generated",
        created_at=datetime.now(timezone.utc)
    )
    session.add(image_record)
    session.commit()
    session.refresh(image_record)
    
    # Return the image file
    return FileResponse(
        path=str(image_path),
        media_type="image/jpeg",
        filename=image_filename
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
            
            # Enforce one image per concept: Delete ALL existing images for this concept
            existing_images = session.exec(
                select(Image).where(Image.concept_id == concept_id)
            ).all()
            
            # Delete all existing images (both database records and files)
            if existing_images:
                for img in existing_images:
                    # Delete image file if it's a local asset
                    if img.url and img.url.startswith("/assets/"):
                        image_filename_to_delete = img.url.replace("/assets/", "")
                        image_path_to_delete = assets_dir / image_filename_to_delete
                        if image_path_to_delete.exists() and image_path_to_delete != image_path:
                            # Only delete if it's a different file (not the one we're about to save)
                            try:
                                image_path_to_delete.unlink()
                                logger.info(f"Deleted existing image file: {image_path_to_delete}")
                            except Exception as e:
                                logger.warning(f"Failed to delete image file {image_path_to_delete}: {str(e)}")
                    
                    # Delete database record
                    session.delete(img)
                
                session.commit()
                logger.info(f"Deleted {len(existing_images)} existing image(s) for concept {concept_id}")
            
            # The new uploaded image is always the only (and therefore primary) image
            is_primary = True
            
            # Create new image record
            image_record = Image(
                concept_id=concept_id,
                url=image_url,
                image_type="illustration",
                is_primary=is_primary,
                source="uploaded",
                created_at=datetime.now(timezone.utc)
            )
            session.add(image_record)
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
    
    # Enforce one image per concept: Delete ALL existing images for this concept
    existing_images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    # Delete all existing images (both database records and files)
    if existing_images:
        for img in existing_images:
            # Delete image file if it's a local asset
            if img.url and img.url.startswith("/assets/"):
                image_filename_to_delete = img.url.replace("/assets/", "")
                image_path_to_delete = assets_dir / image_filename_to_delete
                if image_path_to_delete.exists() and image_path_to_delete != image_path:
                    # Only delete if it's a different file (not the one we're about to save)
                    try:
                        image_path_to_delete.unlink()
                        logger.info(f"Deleted existing image file: {image_path_to_delete}")
                    except Exception as e:
                        logger.warning(f"Failed to delete image file {image_path_to_delete}: {str(e)}")
            
            # Delete database record
            session.delete(img)
        
        session.commit()
        logger.info(f"Deleted {len(existing_images)} existing image(s) for concept {concept_id}")
    
    # The new uploaded image is always the only (and therefore primary) image
    is_primary = True
    
    # Create new image record
    image_record = Image(
        concept_id=concept_id,
        url=image_url,
        image_type="illustration",
        is_primary=is_primary,
        source="uploaded",
        created_at=datetime.now(timezone.utc)
    )
    session.add(image_record)
    session.commit()
    
    # Return the image file
    return FileResponse(
        path=str(image_path),
        media_type="image/jpeg",
        filename=image_filename
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
    
    # Get all images for this concept
    images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    if not images:
        return {
            "success": True,
            "message": f"No images found for concept {concept_id}",
            "deleted_count": 0
        }
    
    # Delete image files from assets directory
    assets_dir = ensure_assets_directory()
    deleted_files = 0
    for image in images:
        # Extract filename from URL (e.g., "/assets/45405.jpg" -> "45405.jpg")
        if image.url and image.url.startswith("/assets/"):
            image_filename = image.url.replace("/assets/", "")
            image_path = assets_dir / image_filename
            
            # Delete the image file if it exists
            if image_path.exists():
                try:
                    image_path.unlink()
                    logger.info(f"Deleted image file: {image_path}")
                    deleted_files += 1
                except Exception as e:
                    logger.warning(f"Failed to delete image file {image_path}: {str(e)}")
        elif image.url and (image.url.startswith("http://") or image.url.startswith("https://")):
            # External URL, no file to delete
            logger.info(f"Skipping external image URL: {image.url}")
    
    # Delete all image records
    for image in images:
        session.delete(image)
    
    session.commit()
    
    return {
        "success": True,
        "message": f"Deleted {len(images)} image record(s) and {deleted_files} file(s) for concept {concept_id}",
        "deleted_count": len(images),
        "deleted_files": deleted_files
    }


@router.post("/retrieve-from-library/{concept_id}")
async def retrieve_images_from_library(
    concept_id: int,
    force_refresh: bool = Query(False, description="Whether to force refresh (delete existing images first)"),
    session: Session = Depends(get_session)
):
    """
    Retrieve images from library (Google Image Search) for a concept.
    
    This endpoint enforces one image per concept:
    1. Deletes ALL existing images for the concept
    2. Gets the concept and its term/description
    3. Uses the concept text to search for images using Google Image Search
    4. Stores only the first retrieved image in the database
    
    Args:
        concept_id: The concept ID
        force_refresh: If True, delete existing images before retrieving new ones (always True for this endpoint)
        session: Database session
        
    Returns:
        Dict with 'images_retrieved' (int), 'success' (bool), and optional 'error' or 'message'
    """
    # Verify concept exists
    concept = session.get(Concept, concept_id)
    if not concept:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Concept with ID {concept_id} not found"
        )
    
    # Get concept text (term or description)
    concept_text = concept.term or ""
    if not concept_text and concept.description:
        concept_text = concept.description
    
    if not concept_text or not concept_text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Concept term or description is required for image retrieval"
        )
    
    # Enforce one image per concept: Always delete all existing images first
    existing_images = session.exec(
        select(Image).where(Image.concept_id == concept_id)
    ).all()
    
    if existing_images:
        assets_dir = ensure_assets_directory()
        for img in existing_images:
            # Delete image file if it's a local asset
            if img.url and img.url.startswith("/assets/"):
                image_filename_to_delete = img.url.replace("/assets/", "")
                image_path_to_delete = assets_dir / image_filename_to_delete
                if image_path_to_delete.exists():
                    try:
                        image_path_to_delete.unlink()
                        logger.info(f"Deleted existing image file: {image_path_to_delete}")
                    except Exception as e:
                        logger.warning(f"Failed to delete image file {image_path_to_delete}: {str(e)}")
            
            # Delete database record
            session.delete(img)
        
        session.commit()
        logger.info(f"Deleted {len(existing_images)} existing image(s) for concept {concept_id}")
    
    # Retrieve only 1 image (enforce one image per concept)
    image_urls = image_service.get_images_for_concept(
        concept_text=concept_text.strip(),
        num_images=1  # Only retrieve 1 image
    )
    
    if not image_urls:
        return {
            'images_retrieved': 0,
            'success': False,
            'error': 'No images found'
        }
    
    # Create Image record for the first (and only) image
    image_record = Image(
        concept_id=concept_id,
        url=image_urls[0],
        image_type='illustration',
        is_primary=True,  # Always primary since it's the only image
        source='google',
        created_at=datetime.now(timezone.utc)
    )
    session.add(image_record)
    session.commit()
    
    logger.info(f"Retrieved and stored 1 image for concept {concept_id}")
    
    return {
        'images_retrieved': 1,
        'success': True
    }


def get_local_images_directory(custom_path: Optional[str] = None) -> Optional[Path]:
    """
    Get the path to the local images directory.
    
    Checks multiple possible locations:
    1. Custom path if provided
    2. Environment variable LOCAL_IMAGES_PATH
    3. Relative to API root: ../app/assets/images (for local development)
    4. Absolute path: /app/assets/images (for Railway if app directory is mounted)
    5. Relative to current working directory: app/assets/images
    
    Args:
        custom_path: Optional custom path to images directory
        
    Returns:
        Path to images directory if found, None otherwise
    """
    # Try custom path first
    if custom_path:
        path = Path(custom_path)
        if path.exists() and path.is_dir():
            return path
    
    # Try environment variable
    env_path = os.getenv("LOCAL_IMAGES_PATH")
    if env_path:
        path = Path(env_path)
        if path.exists() and path.is_dir():
            return path
    
    # Try relative to API root (for local development)
    # From api/app/api/v1/endpoints/concept_image.py
    api_root = Path(__file__).parent.parent.parent.parent.parent  # api/
    project_root = api_root.parent  # project root
    local_images_dir = project_root / "app" / "assets" / "images"
    if local_images_dir.exists() and local_images_dir.is_dir():
        return local_images_dir
    
    # Try absolute path (for Railway if app directory is available)
    absolute_path = Path("/app/assets/images")
    if absolute_path.exists() and absolute_path.is_dir():
        return absolute_path
    
    # Try relative to current working directory
    cwd_path = Path("app/assets/images")
    if cwd_path.exists() and cwd_path.is_dir():
        return cwd_path
    
    # Try in api directory (if someone copied images there)
    api_images_dir = api_root / "assets" / "images"
    if api_images_dir.exists() and api_images_dir.is_dir():
        return api_images_dir
    
    # Try api/assets/ directly (images might be in the assets root)
    api_assets_dir = api_root / "assets"
    if api_assets_dir.exists() and api_assets_dir.is_dir():
        # Check if it contains image files
        image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}
        has_images = any(
            f.is_file() and f.suffix.lower() in image_extensions
            for f in api_assets_dir.iterdir()
        )
        if has_images:
            return api_assets_dir
    
    # Try the configured assets path (might be where images are stored)
    if settings.assets_path:
        assets_path = Path(settings.assets_path)
        if assets_path.exists() and assets_path.is_dir():
            # Check if it contains image files
            image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}
            has_images = any(
                f.is_file() and f.suffix.lower() in image_extensions
                for f in assets_path.iterdir()
            )
            if has_images:
                return assets_path
    
    return None


@router.post("/sync-from-local")
async def sync_images_from_local(
    session: Session = Depends(get_session),
    overwrite: bool = Query(True, description="Whether to overwrite existing images"),
    source_path: Optional[str] = Query(None, description="Custom path to source images directory (optional)")
):
    """
    Sync images from local directory to Railway volume and update database records.
    
    This endpoint:
    1. Scans source directory for image files (defaults to app/assets/images)
    2. Extracts concept_id from filename (e.g., "44204.png" -> concept_id 44204)
    3. Processes each image (resize to 300x300, convert to JPEG)
    4. Saves to Railway volume (or local assets if ASSETS_PATH not set)
    5. Updates or creates database records
    
    The source directory is determined by checking (in order):
    1. source_path parameter (if provided)
    2. LOCAL_IMAGES_PATH environment variable
    3. ../app/assets/images (relative to API root, for local development)
    4. /app/assets/images (absolute path, for Railway)
    5. app/assets/images (relative to current working directory)
    6. api/assets/images (if images were copied to API directory)
    
    Args:
        session: Database session
        overwrite: Whether to overwrite existing images (default: True)
        source_path: Optional custom path to source images directory
        
    Returns:
        Summary of sync operation with counts of processed, created, updated, and failed images
    """
    try:
        local_images_dir = get_local_images_directory(custom_path=source_path)
        
        if not local_images_dir:
            # Provide helpful error message with all checked paths
            api_root = Path(__file__).parent.parent.parent.parent.parent
            checked_paths = [
                source_path if source_path else "N/A (not provided)",
                os.getenv("LOCAL_IMAGES_PATH", "N/A (not set)"),
                str(api_root.parent / "app" / "assets" / "images"),
                "/app/assets/images",
                "app/assets/images",
                str(api_root / "assets" / "images"),
                str(api_root / "assets"),
                settings.assets_path if settings.assets_path else "N/A (not configured)",
            ]
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error": "Local images directory not found",
                    "checked_paths": checked_paths,
                    "hint": "Set LOCAL_IMAGES_PATH environment variable or provide source_path parameter. "
                           "In Railway, you may need to copy images to a location accessible by the API container, "
                           "or use the upload endpoint instead."
                }
            )
        
        # Get Railway/assets directory
        assets_dir = ensure_assets_directory()
        
        # Find all image files in local directory
        image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}
        image_files = [
            f for f in local_images_dir.iterdir()
            if f.is_file() and f.suffix.lower() in image_extensions
        ]
        
        if not image_files:
            return {
                "message": "No image files found in app/assets/images",
                "processed": 0,
                "created": 0,
                "updated": 0,
                "failed": 0,
                "errors": []
            }
        
        processed = 0
        created = 0
        updated = 0
        failed = 0
        errors = []
        file_results = []  # Track results for each file
        
        logger.info(f"Found {len(image_files)} image files to sync from {local_images_dir}")
        
        for image_file in image_files:
            try:
                # Extract concept_id from filename (e.g., "44204.png" -> 44204)
                # Remove extension and try to parse as integer
                filename_stem = image_file.stem
                try:
                    concept_id = int(filename_stem)
                except ValueError:
                    error_msg = f"{image_file.name}: Invalid concept ID in filename"
                    logger.warning(f"Skipping {image_file.name}: filename does not contain a valid concept ID")
                    failed += 1
                    errors.append(error_msg)
                    file_results.append({"file": image_file.name, "status": "failed", "reason": error_msg})
                    continue
                
                # Verify concept exists
                concept = session.get(Concept, concept_id)
                if not concept:
                    error_msg = f"{image_file.name}: Concept {concept_id} not found in database"
                    logger.warning(f"Skipping {image_file.name}: Concept {concept_id} not found in database")
                    failed += 1
                    errors.append(error_msg)
                    file_results.append({"file": image_file.name, "status": "failed", "reason": error_msg})
                    continue
                
                # Read and process the image
                try:
                    # Open image with explicit size limit to prevent memory issues
                    img = PILImage.open(image_file)
                    
                    # Check image size and warn if very large
                    width, height = img.size
                    if width * height > 10000000:  # > 10MP
                        logger.warning(f"Large image {image_file.name}: {width}x{height}, may take longer to process")
                    
                    # Convert to RGB if necessary
                    if img.mode != 'RGB':
                        img = img.convert('RGB')
                    
                    # Crop to square and resize to 300x300
                    img = crop_to_square_and_resize(img, target_size=300)
                    
                    # Convert to JPEG bytes with memory-efficient approach
                    output = io.BytesIO()
                    img.save(output, format="JPEG", quality=95, optimize=True)
                    image_bytes = output.getvalue()
                    
                    # Explicitly close the image to free memory
                    img.close()
                    output.close()
                    
                except PILImage.UnidentifiedImageError as e:
                    error_msg = f"{image_file.name}: Invalid or corrupted image file"
                    logger.error(f"Failed to open image {image_file.name}: {str(e)}")
                    failed += 1
                    errors.append(error_msg)
                    file_results.append({"file": image_file.name, "status": "failed", "reason": error_msg})
                    continue
                except Exception as e:
                    error_msg = f"{image_file.name}: Failed to process image - {str(e)}"
                    logger.error(f"Failed to process image {image_file.name}: {str(e)}")
                    failed += 1
                    errors.append(error_msg)
                    file_results.append({"file": image_file.name, "status": "failed", "reason": error_msg})
                    continue
                
                # Save to Railway/assets directory
                image_filename = f"{concept_id}.jpg"
                image_path = assets_dir / image_filename
                
                # Check if file already exists
                file_exists = image_path.exists()
                
                if file_exists and not overwrite:
                    logger.info(f"Skipping {image_file.name}: File {image_filename} already exists and overwrite=False")
                    processed += 1
                    continue
                
                # Explicitly remove existing file to ensure overwrite
                if file_exists:
                    try:
                        image_path.unlink()
                        logger.info(f"Removed existing file {image_path} before overwriting")
                    except Exception as e:
                        logger.warning(f"Failed to remove existing file {image_path}: {str(e)}, will attempt to overwrite anyway")
                
                try:
                    with open(image_path, "wb") as f:
                        f.write(image_bytes)
                    logger.info(f"Saved image {image_file.name} -> {image_path}")
                except Exception as e:
                    logger.error(f"Failed to save image {image_file.name} to {image_path}: {str(e)}")
                    failed += 1
                    errors.append(f"{image_file.name}: Failed to save - {str(e)}")
                    continue
                
                # Update database
                image_url = f"/assets/{image_filename}"
                
                # Check if image record already exists
                existing_image = session.exec(
                    select(Image).where(
                        Image.concept_id == concept_id,
                        Image.url == image_url
                    )
                ).first()
                
                if existing_image:
                    # Update existing record
                    existing_image.source = "synced"
                    existing_image.created_at = datetime.now(timezone.utc)
                    session.add(existing_image)
                    updated += 1
                    logger.info(f"Updated database record for concept {concept_id}")
                    file_results.append({"file": image_file.name, "concept_id": concept_id, "status": "updated"})
                else:
                    # Check if this is the first image for this concept (make it primary)
                    existing_images = session.exec(
                        select(Image).where(Image.concept_id == concept_id)
                    ).all()
                    is_primary = len(existing_images) == 0
                    
                    # Create new image record
                    image_record = Image(
                        concept_id=concept_id,
                        url=image_url,
                        image_type="illustration",
                        is_primary=is_primary,
                        source="synced",
                        created_at=datetime.now(timezone.utc)
                    )
                    session.add(image_record)
                    created += 1
                    logger.info(f"Created database record for concept {concept_id}")
                    file_results.append({"file": image_file.name, "concept_id": concept_id, "status": "created"})
                
                processed += 1
                
            except Exception as e:
                error_msg = f"{image_file.name}: Unexpected error - {str(e)}"
                logger.error(f"Error processing {image_file.name}: {str(e)}", exc_info=True)
                failed += 1
                errors.append(error_msg)
                file_results.append({"file": image_file.name, "status": "failed", "reason": error_msg})
                continue
        
        # Commit all database changes
        try:
            session.commit()
            logger.info(f"Committed database changes: {created} created, {updated} updated")
        except Exception as e:
            logger.error(f"Failed to commit database changes: {str(e)}")
            session.rollback()
            failed += len([e for e in errors if "database" in e.lower()])
            errors.append(f"Database commit failed: {str(e)}")
        
        return {
            "message": f"Sync completed: {processed} processed, {created} created, {updated} updated, {failed} failed",
            "total_files_found": len(image_files),
            "processed": processed,
            "created": created,
            "updated": updated,
            "failed": failed,
            "file_results": file_results,
            "errors": errors[:10] if len(errors) > 10 else errors,  # Limit errors in response
            "total_errors": len(errors)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Critical error in sync_images_from_local: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error": "Failed to sync images",
                "message": str(e),
                "type": type(e).__name__
            }
        )
