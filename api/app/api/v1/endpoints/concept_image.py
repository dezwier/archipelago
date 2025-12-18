"""
Endpoint for generating images for concepts.
"""
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.responses import FileResponse
from sqlmodel import Session
from typing import Optional
import logging
from datetime import datetime, timezone

from app.core.database import get_session
from app.core.config import settings
from app.models.models import Concept, Topic
from app.schemas.concept import GenerateImageRequest, GenerateImagePreviewRequest
from app.services.image_service import (
    build_image_prompt,
    generate_image_with_gemini,
    process_uploaded_image,
    save_concept_image,
    delete_concept_image_file,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/concept-image", tags=["concept-image"])


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
    
    # Save image to assets folder
    image_path = save_concept_image(request.concept_id, image_bytes)
    image_filename = image_path.name
    image_url = f"/assets/{image_filename}"
    
    # Delete existing image file if it exists (different filename)
    if concept.image_url and concept.image_url != image_url:
        delete_concept_image_file(concept.image_url)
    
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
        
        # Process the uploaded image
        image_bytes = process_uploaded_image(file_content)
        
        # Determine filename and path
        # If concept_id is provided, use it; otherwise use the original filename
        if concept_id:
            # Verify concept exists
            concept = session.get(Concept, concept_id)
            if not concept:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Concept with ID {concept_id} not found"
                )
            
            # Save image for concept
            image_path = save_concept_image(concept_id, image_bytes)
            image_filename = image_path.name
            image_url = f"/assets/{image_filename}"
            
            # Delete existing image file if it exists (different filename)
            if concept.image_url and concept.image_url != image_url:
                delete_concept_image_file(concept.image_url)
            
            # Update concept with new image URL
            concept.image_url = image_url
            concept.updated_at = datetime.now(timezone.utc)
            session.add(concept)
            session.commit()
        else:
            # Use original filename but ensure .jpg extension
            from pathlib import Path
            original_name = Path(file.filename).stem if file.filename else "uploaded"
            image_filename = f"{original_name}.jpg"
            from app.utils.assets_utils import ensure_assets_directory
            assets_dir = ensure_assets_directory()
            image_path = assets_dir / image_filename
            
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
    
    # Process the uploaded image
    image_bytes = process_uploaded_image(file_content)
    
    # Save image for concept
    image_path = save_concept_image(concept_id, image_bytes)
    image_filename = image_path.name
    image_url = f"/assets/{image_filename}"
    
    # Delete existing image file if it exists (different filename)
    if concept.image_url and concept.image_url != image_url:
        delete_concept_image_file(concept.image_url)
    
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
    from fastapi.responses import Response as FastAPIResponse
    return FastAPIResponse(
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
    if concept.image_url:
        if delete_concept_image_file(concept.image_url):
            deleted_files = 1
    
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
