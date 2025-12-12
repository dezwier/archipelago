#!/usr/bin/env python3
"""
Standalone script to sync images from source directory to Railway volume and update database.

This script is designed to run ON Railway:
    railway run python api/sync_images_from_local.py --source-path /path/to/images

It will:
1. Scan source directory for image files
2. Extract concept_id from filename (e.g., "44204.png" -> concept_id 44204)
3. Process each image (resize to 300x300, convert to JPEG)
4. Save to Railway ASSETS_PATH volume (REQUIRED - set ASSETS_PATH env var)
5. Update or create database records in Railway database

SETUP INSTRUCTIONS:
===================

1. Copy images to Railway (choose one method):

   Option A - Using Railway CLI to copy from local:
     railway run mkdir -p /tmp/images
     # Then copy files (you may need to use railway shell or upload via API)
   
   Option B - Upload images to Railway volume first:
     # If you have a source volume mounted, copy images there
     railway shell
     # Then inside Railway shell, copy your images to a directory

   Option C - Use the API upload endpoint for each image (slower but works)

2. Ensure ASSETS_PATH is set in Railway Variables (e.g., /data/assets)

3. Run the sync script:
   railway run python api/sync_images_from_local.py --source-path /tmp/images
   
   Or if images are in a Railway volume:
   railway run python api/sync_images_from_local.py --source-path /path/to/volume/images
"""
import os
import sys
import logging
import io
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional
from PIL import Image as PILImage, ImageOps
from sqlmodel import Session, select

# Add the api directory to the path so we can import app modules
api_dir = Path(__file__).parent
sys.path.insert(0, str(api_dir))

from app.core.database import engine
from app.core.config import settings
from app.models.models import Concept, Image

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def crop_to_square_and_resize(img: PILImage.Image, target_size: int = 300) -> PILImage.Image:
    """
    Crop image to square (center crop, equally from both sides) and resize to target size.
    
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


def ensure_assets_directory() -> Path:
    """
    Ensure the assets directory exists and return its path.
    
    Uses ASSETS_PATH from environment/.env (required).
    
    Returns:
        Path to the assets directory
        
    Raises:
        ValueError: If ASSETS_PATH is not set or cannot be created
    """
    if not settings.assets_path:
        raise ValueError(
            "ASSETS_PATH environment variable is required! "
            "Set it in your .env file (e.g., ASSETS_PATH=/data/assets)"
        )
    
    assets_dir = Path(settings.assets_path)
    
    # Check if directory already exists
    if assets_dir.exists() and assets_dir.is_dir():
        logger.info(f"Using ASSETS_PATH: {assets_dir}")
        return assets_dir
    
    # Try to create the directory
    try:
        assets_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Created and using ASSETS_PATH: {assets_dir}")
    except PermissionError as e:
        raise ValueError(
            f"Permission denied creating ASSETS_PATH: {assets_dir}. "
            f"Error: {e}. "
            f"On macOS, /data is protected. Create it with: sudo mkdir -p {assets_dir} && sudo chown $USER {assets_dir}"
        )
    except OSError as e:
        if e.errno == 30:  # Read-only file system
            raise ValueError(
                f"Cannot create ASSETS_PATH: {assets_dir}. "
                f"Error: {e}. "
                f"On macOS, /data is read-only. Create it with: sudo mkdir -p {assets_dir} && sudo chown $USER {assets_dir}"
            )
        raise ValueError(
            f"Cannot create ASSETS_PATH: {assets_dir}. "
            f"Error: {e}. "
            f"Create the directory first: mkdir -p {assets_dir}"
        )
    
    return assets_dir


def sync_images_from_local(
    source_path: str,
    overwrite: bool = True
) -> dict:
    """
    Sync images from source directory to Railway volume and update database records.
    
    Args:
        source_path: Path to source images directory (must exist on Railway)
        overwrite: Whether to overwrite existing images (default: True)
        
    Returns:
        Summary of sync operation with counts of processed, created, updated, and failed images
        
    Raises:
        ValueError: If ASSETS_PATH is not set or source directory doesn't exist
    """
    # Log configuration at start
    db_url_preview = settings.database_url[:50] + "..." if len(settings.database_url) > 50 else settings.database_url
    logger.info("="*60)
    logger.info("SYNC CONFIGURATION")
    logger.info("="*60)
    logger.info(f"Database URL: {db_url_preview}")
    logger.info(f"ASSETS_PATH: {settings.assets_path if settings.assets_path else 'Not set (using api/assets)'}")
    logger.info(f"Source path: {source_path}")
    logger.info("="*60)
    
    local_images_dir = Path(source_path)
    
    if not local_images_dir.exists() or not local_images_dir.is_dir():
        raise ValueError(f"Source directory not found: {source_path}")
    
    # Get assets directory
    assets_dir = ensure_assets_directory()
    
    # Find all image files in local directory
    image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'}
    image_files = [
        f for f in local_images_dir.iterdir()
        if f.is_file() and f.suffix.lower() in image_extensions
    ]
    
    if not image_files:
        logger.info("No image files found in source directory")
        return {
            "message": "No image files found",
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
    file_results = []
    
    logger.info(f"Found {len(image_files)} image files to sync from {local_images_dir}")
    
    with Session(engine) as session:
        for image_file in image_files:
            try:
                # Extract concept_id from filename (e.g., "44204.png" -> 44204)
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
                    img = PILImage.open(image_file)
                    # Apply EXIF orientation correction to preserve original orientation
                    img = ImageOps.exif_transpose(img)
                    
                    # Check image size and warn if very large
                    width, height = img.size
                    if width * height > 10000000:  # > 10MP
                        logger.warning(f"Large image {image_file.name}: {width}x{height}, may take longer to process")
                    
                    # Convert to RGB if necessary
                    if img.mode != 'RGB':
                        img = img.convert('RGB')
                    
                    # Crop to square and resize to 300x300
                    img = crop_to_square_and_resize(img, target_size=300)
                    
                    # Convert to JPEG bytes
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
                
                # Save to assets directory
                image_filename = f"{concept_id}.jpg"
                image_path = assets_dir / image_filename
                
                # Check if file already exists
                file_exists = image_path.exists()
                
                if file_exists and not overwrite:
                    logger.info(f"Skipping {image_file.name}: File {image_filename} already exists and overwrite=False")
                    processed += 1
                    continue
                
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
            errors.append(f"Database commit failed: {str(e)}")
    
    return {
        "message": f"Sync completed: {processed} processed, {created} created, {updated} updated, {failed} failed",
        "total_files_found": len(image_files),
        "processed": processed,
        "created": created,
        "updated": updated,
        "failed": failed,
        "file_results": file_results,
        "errors": errors[:10] if len(errors) > 10 else errors,
        "total_errors": len(errors)
    }


def main():
    """Main entry point for the script."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Sync images from source directory to Railway volume and update database",
        epilog="""
This script must be run ON Railway:
  railway run python api/sync_images_from_local.py --source-path /path/to/images

Before running:
1. Copy images to Railway (e.g., upload to a temp directory or volume)
2. Ensure ASSETS_PATH is set in Railway Variables
3. Run the script with --source-path pointing to where images are located

Example workflow:
  # Copy images to Railway temp directory
  railway run mkdir -p /tmp/images
  railway run cp /path/to/local/images/* /tmp/images/
  
  # Run sync script
  railway run python api/sync_images_from_local.py --source-path /tmp/images
        """
    )
    parser.add_argument(
        "--source-path",
        type=str,
        default=None,
        help="Path to source images directory on Railway. "
             "If not provided, will try: api/assets/images (if images are in the repo)"
    )
    parser.add_argument(
        "--no-overwrite",
        action="store_true",
        help="Don't overwrite existing images"
    )
    
    args = parser.parse_args()
    
    # If source_path not provided, try default locations
    source_path = args.source_path
    if not source_path:
        # Try api/assets/images (if images are in the repo)
        api_root = Path(__file__).parent
        default_path = api_root / "assets" / "images"
        if default_path.exists():
            source_path = str(default_path)
            logger.info(f"No --source-path provided, using default: {source_path}")
        else:
            parser.error(
                "--source-path is required. "
                "Images not found at default location (api/assets/images). "
                "Provide --source-path or copy images to api/assets/images in your repo."
            )
    
    try:
        result = sync_images_from_local(
            source_path=source_path,
            overwrite=not args.no_overwrite
        )
        
        print("\n" + "="*60)
        print("SYNC SUMMARY")
        print("="*60)
        print(f"Total files found: {result['total_files_found']}")
        print(f"Processed: {result['processed']}")
        print(f"Created: {result['created']}")
        print(f"Updated: {result['updated']}")
        print(f"Failed: {result['failed']}")
        print("="*60)
        
        if result['errors']:
            print(f"\nErrors ({result['total_errors']} total):")
            for error in result['errors']:
                print(f"  - {error}")
        
        if result['failed'] > 0:
            sys.exit(1)
        else:
            print("\n✓ Sync completed successfully!")
            sys.exit(0)
            
    except Exception as e:
        logger.error(f"Critical error: {str(e)}", exc_info=True)
        print(f"\n✗ Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
