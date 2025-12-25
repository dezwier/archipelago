from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import User, Language
from app.schemas.auth import LoginRequest, RegisterRequest, AuthResponse, UserResponse, UpdateUserLanguagesRequest, UpdateLeitnerConfigRequest
from app.services.user_service import delete_user_data
from app.services.image_service import process_user_profile_image, save_user_image, delete_user_image_file

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=AuthResponse)
async def login(
    login_data: LoginRequest,
    session: Session = Depends(get_session)
):
    """Login with username/email and password."""
    # Try to find user by username or email
    statement = select(User).where(
        (User.username == login_data.username) | (User.email == login_data.username)
    )
    user = session.exec(statement).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username/email or password"
        )
    
    # Verify password
    if not user.verify_password(login_data.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username/email or password"
        )
    
    return AuthResponse(
        user=UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            lang_native=user.lang_native,
            lang_learning=user.lang_learning,
            created_at=user.created_at.isoformat(),
            full_name=user.full_name,
            image_url=user.image_url,
            leitner_max_bins=user.leitner_max_bins,
            leitner_algorithm=user.leitner_algorithm,
            leitner_interval_factor=user.leitner_interval_factor,
            leitner_interval_start=user.leitner_interval_start
        ),
        message="Login successful"
    )


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    register_data: RegisterRequest,
    session: Session = Depends(get_session)
):
    """Register a new user."""
    # Check if username already exists
    existing_user = session.exec(select(User).where(User.username == register_data.username)).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )
    
    # Check if email already exists
    existing_email = session.exec(select(User).where(User.email == register_data.email)).first()
    if existing_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already exists"
        )
    
    # Verify that the native language exists
    native_lang = session.exec(select(Language).where(Language.code == register_data.native_language)).first()
    if not native_lang:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language code: {register_data.native_language}"
        )
    
    # Verify learning language if provided
    learning_lang_code = register_data.learning_language or ""
    if learning_lang_code:
        learning_lang = session.exec(select(Language).where(Language.code == learning_lang_code)).first()
        if not learning_lang:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid language code: {learning_lang_code}"
            )
    
    # Create new user
    hashed_password = User.hash_password(register_data.password)
    new_user = User(
        username=register_data.username,
        email=register_data.email,
        password=hashed_password,
        lang_native=register_data.native_language,
        lang_learning=learning_lang_code,
        full_name=register_data.full_name,
        image_url=None,
        leitner_max_bins=7,
        leitner_algorithm='fibonacci',
        leitner_interval_factor=None,
        leitner_interval_start=23
    )
    
    session.add(new_user)
    session.commit()
    session.refresh(new_user)
    
    return AuthResponse(
        user=UserResponse(
            id=new_user.id,
            username=new_user.username,
            email=new_user.email,
            lang_native=new_user.lang_native,
            lang_learning=new_user.lang_learning,
            created_at=new_user.created_at.isoformat(),
            full_name=new_user.full_name,
            image_url=new_user.image_url,
            leitner_max_bins=new_user.leitner_max_bins,
            leitner_algorithm=new_user.leitner_algorithm,
            leitner_interval_factor=new_user.leitner_interval_factor,
            leitner_interval_start=new_user.leitner_interval_start
        ),
        message="Registration successful"
    )


@router.patch("/update-languages", response_model=AuthResponse)
async def update_user_languages(
    user_id: int,
    update_data: UpdateUserLanguagesRequest,
    session: Session = Depends(get_session)
):
    """Update user's native and/or learning language."""
    # Find user
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Validate and update native language if provided
    if update_data.lang_native is not None:
        language = session.exec(select(Language).where(Language.code == update_data.lang_native)).first()
        if not language:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid language code: {update_data.lang_native}"
            )
        user.lang_native = update_data.lang_native
    
    # Validate and update learning language if provided
    if update_data.lang_learning is not None:
        if update_data.lang_learning:  # Only validate if not empty string
            language = session.exec(select(Language).where(Language.code == update_data.lang_learning)).first()
            if not language:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Invalid language code: {update_data.lang_learning}"
                )
        user.lang_learning = update_data.lang_learning if update_data.lang_learning else ""
    
    session.add(user)
    session.commit()
    session.refresh(user)
    
    return AuthResponse(
        user=UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            lang_native=user.lang_native,
            lang_learning=user.lang_learning,
            created_at=user.created_at.isoformat(),
            full_name=user.full_name,
            image_url=user.image_url,
            leitner_max_bins=user.leitner_max_bins,
            leitner_algorithm=user.leitner_algorithm,
            leitner_interval_factor=user.leitner_interval_factor,
            leitner_interval_start=user.leitner_interval_start
        ),
        message="Languages updated successfully"
    )


@router.patch("/update-leitner-config", response_model=AuthResponse)
async def update_leitner_config(
    user_id: int,
    update_data: UpdateLeitnerConfigRequest,
    session: Session = Depends(get_session)
):
    """Update user's Leitner algorithm configuration."""
    # Find user
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    # Validate and update max_bins if provided
    if update_data.leitner_max_bins is not None:
        if update_data.leitner_max_bins < 5 or update_data.leitner_max_bins > 20:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="leitner_max_bins must be between 5 and 20"
            )
        user.leitner_max_bins = update_data.leitner_max_bins
    
    # Validate and update algorithm if provided
    if update_data.leitner_algorithm is not None:
        if update_data.leitner_algorithm != 'fibonacci':
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Only 'fibonacci' algorithm is currently supported"
            )
        user.leitner_algorithm = update_data.leitner_algorithm
    
    # Validate and update interval_start if provided
    if update_data.leitner_interval_start is not None:
        if update_data.leitner_interval_start < 1 or update_data.leitner_interval_start > 24:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="leitner_interval_start must be between 1 and 24"
            )
        user.leitner_interval_start = update_data.leitner_interval_start
    
    session.add(user)
    session.commit()
    session.refresh(user)
    
    return AuthResponse(
        user=UserResponse(
            id=user.id,
            username=user.username,
            email=user.email,
            lang_native=user.lang_native,
            lang_learning=user.lang_learning,
            created_at=user.created_at.isoformat(),
            full_name=user.full_name,
            image_url=user.image_url,
            leitner_max_bins=user.leitner_max_bins,
            leitner_algorithm=user.leitner_algorithm,
            leitner_interval_factor=user.leitner_interval_factor,
            leitner_interval_start=user.leitner_interval_start
        ),
        message="Leitner configuration updated successfully"
    )


@router.post("/upload-profile-image", response_model=AuthResponse)
async def upload_profile_image(
    user_id: int,
    file: UploadFile = File(...),
    session: Session = Depends(get_session)
):
    """
    Upload a profile image for a user.
    
    This endpoint:
    1. Accepts an image file upload
    2. Processes the image to 150x150 square format
    3. Saves the image as users/<username>.jpg
    4. Updates the user's image_url field
    5. Deletes the old image file if it exists and is different
    
    Args:
        user_id: The user ID
        file: The image file to upload
        session: Database session
        
    Returns:
        Updated user object with new image_url
    """
    # Find user
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found"
        )
    
    try:
        # Read the file content
        file_content = await file.read()
        
        # Process the uploaded image (150x150 square format)
        image_bytes = process_user_profile_image(file_content)
        
        # Save image for user
        image_path = save_user_image(user.username, image_bytes)
        image_url = f"/assets/users/{user.username}.jpg"
        
        # Delete existing image file if it exists (different filename)
        if user.image_url and user.image_url != image_url:
            delete_user_image_file(user.image_url)
        
        # Update user with new image URL
        user.image_url = image_url
        session.add(user)
        session.commit()
        session.refresh(user)
        
        return AuthResponse(
            user=UserResponse(
                id=user.id,
                username=user.username,
                email=user.email,
                lang_native=user.lang_native,
                lang_learning=user.lang_learning,
                created_at=user.created_at.isoformat(),
                full_name=user.full_name,
                image_url=user.image_url,
                leitner_max_bins=user.leitner_max_bins,
                leitner_algorithm=user.leitner_algorithm,
                leitner_interval_factor=user.leitner_interval_factor,
                leitner_interval_start=user.leitner_interval_start
            ),
            message="Profile image uploaded successfully"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload profile image: {str(e)}"
        )


@router.delete("/delete-user-data")
async def delete_user_data_endpoint(
    user_id: int,
    session: Session = Depends(get_session)
):
    """
    Delete all exercises, user_lemmas, and lessons for a user.
    
    This endpoint permanently deletes:
    - All exercises associated with the user's user_lemmas
    - All user_lemmas for the user
    - All lessons for the user
    
    Args:
        user_id: The user ID whose data should be deleted
        session: Database session
        
    Returns:
        Dict with success status and deletion counts
    """
    try:
        result = delete_user_data(session, user_id)
        return {
            "success": True,
            "message": "User data deleted successfully",
            "exercises_deleted": result["exercises_deleted"],
            "user_lemmas_deleted": result["user_lemmas_deleted"],
            "lessons_deleted": result["lessons_deleted"]
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e)
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete user data: {str(e)}"
        ) from e

