import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Union
from jose import jwt
from passlib.context import CryptContext
from google.oauth2 import id_token
from google.auth.transport import requests
from app.config import get_settings

logger = logging.getLogger(__name__)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
settings = get_settings()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a hashed one."""
    try:
        if not plain_password or not hashed_password:
            return False
        # Bcrypt has a strict 72-byte limit on the raw password bytes
        # We encode and truncate to ensure we never exceed this limit
        return pwd_context.verify(plain_password.encode('utf-8')[:72], hashed_password)
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False

def get_password_hash(password: str) -> str:
    """Generate a bcrypt hash of a password."""
    # Bcrypt has a strict 72-byte limit on the raw password bytes
    return pwd_context.hash(password.encode('utf-8')[:72])

def create_access_token(subject: Union[str, Any], expires_delta: timedelta = None) -> str:
    """Create a JWT access token."""
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    
    to_encode = {"exp": expire, "sub": str(subject)}
    encoded_jwt = jwt.encode(
        to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM
    )
    return encoded_jwt

async def verify_google_token(token: str) -> dict:
    """Verify a Google ID token."""
    try:
        # If no client ID is set, we can't verify (except in dev mode maybe)
        if not settings.GOOGLE_CLIENT_ID:
            logger.warning("GOOGLE_CLIENT_ID not set. Skipping verification (DEV ONLY!)")
            # In real app, this should fail. For now, let's return a dummy or fail.
            raise ValueError("GOOGLE_CLIENT_ID is not configured on backend")

        # Support both Android and Web client IDs
        audiences = [settings.GOOGLE_CLIENT_ID, settings.GOOGLE_CLIENT_ID_WEB]
        audiences = [aud for aud in audiences if aud] # Filter out empty ones

        # Attempt verification with clock_skew (requires google-auth >= 1.10.0)
        try:
            idinfo = id_token.verify_oauth2_token(
                token, requests.Request(), audiences, clock_skew=300
            )
        except TypeError:
            # Fallback for older versions of google-auth that don't support clock_skew
            logger.warning("Installed google-auth version is old. Attempting verification without clock_skew.")
            idinfo = id_token.verify_oauth2_token(
                token, requests.Request(), audiences
            )

        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Wrong issuer.')

        return idinfo
    except Exception as e:
        logger.error(f"Google token verification failed: {e}")
        raise ValueError(str(e))
