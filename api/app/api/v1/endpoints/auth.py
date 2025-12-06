from fastapi import APIRouter, Depends, HTTPException, status
from sqlmodel import Session, select
from app.core.database import get_session
from app.models.models import User, Language
from app.schemas.auth import LoginRequest, RegisterRequest, AuthResponse, UserResponse
from datetime import datetime

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
    language = session.exec(select(Language).where(Language.code == register_data.native_language)).first()
    if not language:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid language code: {register_data.native_language}"
        )
    
    # Create new user
    hashed_password = User.hash_password(register_data.password)
    new_user = User(
        username=register_data.username,
        email=register_data.email,
        password=hashed_password,
        lang_native=register_data.native_language,
        lang_learning=""  # Can be set later
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

