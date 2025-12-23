from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import User, Language
from app.schemas.auth import LoginRequest, RegisterRequest, AuthResponse, UserResponse, UpdateUserLanguagesRequest
from app.services.user_service import delete_user_data

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
            created_at=user.created_at.isoformat()
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
        lang_learning=learning_lang_code
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
            created_at=new_user.created_at.isoformat()
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
            created_at=user.created_at.isoformat()
        ),
        message="Languages updated successfully"
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

