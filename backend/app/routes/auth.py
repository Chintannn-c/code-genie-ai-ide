import logging
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status
from app.database import get_db
from app.models.user import UserCreate, Token
from app.services import auth_service
from uuid import uuid4
from pydantic import BaseModel

class GoogleLoginRequest(BaseModel):
    id_token: str

class ForgotPasswordRequest(BaseModel):
    email: str

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/register", response_model=Token)
async def register(user_in: UserCreate):
    """Register a new user."""
    db = await get_db()
    
    # Check if user exists
    existing_user = await db.users.find_one({"email": user_in.email})
    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="A user with this email already exists."
        )
    
    # Create user
    user_id = str(uuid4())
    hashed_password = auth_service.get_password_hash(user_in.password)
    
    user_dict = {
        "_id": user_id,
        "email": user_in.email,
        "full_name": user_in.full_name,
        "hashed_password": hashed_password,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    
    await db.users.insert_one(user_dict)
    
    # Create token
    access_token = auth_service.create_access_token(subject=user_id)
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user_id=user_id,
        email=user_in.email,
        full_name=user_in.full_name
    )

@router.post("/login", response_model=Token)
async def login(user_in: UserCreate): # Using same schema for simplicity
    """Login with email and password."""
    db = await get_db()
    
    user = await db.users.find_one({"email": user_in.email})
    
    # Security: Reject empty passwords (often used by Google-only accounts)
    if not user_in.password or not user.get("hashed_password"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
        )

    if not auth_service.verify_password(user_in.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Create token
    access_token = auth_service.create_access_token(subject=user["_id"])
    
    return Token(
        access_token=access_token,
        token_type="bearer",
        user_id=user["_id"],
        email=user["email"],
        full_name=user.get("full_name")
    )

@router.post("/google", response_model=Token)
async def google_login(request: GoogleLoginRequest):
    """Verify Google token and login/register user."""
    db = await get_db()
    
    try:
        # Verify token with Google
        id_info = await auth_service.verify_google_token(request.id_token)
        email = id_info['email']
        name = id_info.get('name')
        picture = id_info.get('picture') # ASSET FIX: Capture profile image URL
        
        # Check if user exists
        user = await db.users.find_one({"email": email})
        
        if not user:
            # Register new user from Google info
            user_id = str(uuid4())
            user = {
                "_id": user_id,
                "email": email,
                "full_name": name,
                "picture_url": picture, # ASSET FIX: Persist picture URL
                "hashed_password": auth_service.get_password_hash(str(uuid4())), 
                "created_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc),
            }
            await db.users.insert_one(user)
        else:
            # ASSET FIX: Update existing user's picture if it changed
            if user.get("picture_url") != picture:
                await db.users.update_one(
                    {"_id": user["_id"]},
                    {"$set": {"picture_url": picture, "updated_at": datetime.now(timezone.utc)}}
                )
                user["picture_url"] = picture
        
        # Create our custom JWT
        access_token = auth_service.create_access_token(subject=user["_id"])
        
        return Token(
            access_token=access_token,
            token_type="bearer",
            user_id=user["_id"],
            email=email,
            full_name=name,
            picture_url=picture
        )
    except Exception as e:
        logger.error(f"Google login failed: {e}")
        raise HTTPException(status_code=401, detail=str(e))
