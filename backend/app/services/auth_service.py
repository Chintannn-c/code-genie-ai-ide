import logging
import bcrypt
from datetime import datetime, timedelta, timezone
from typing import Any, Union, Optional
from jose import jwt
import asyncio
from google.auth.transport import requests as google_requests
from app.config import get_settings

logger = logging.getLogger(__name__)

# Removed passlib CryptContext due to bcrypt 4.0+ compatibility issues
settings = get_settings()

# Create a persistent session for Google public key retrieval to speed up verification
_google_request_session = google_requests.Request()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash."""
    try:
        if not plain_password or not hashed_password:
            return False
        return bcrypt.checkpw(
            plain_password.encode('utf-8')[:72], 
            hashed_password.encode('utf-8')
        )
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False

def get_password_hash(password: str) -> str:
    """Generate a bcrypt hash of a password."""
    # Use native bcrypt for maximum compatibility
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8')[:72], salt)
    return hashed.decode('utf-8')

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
    """Verify a Google ID token asynchronously."""
    try:
        # If no client ID is set, we can't verify
        if not settings.GOOGLE_CLIENT_ID:
            logger.warning("GOOGLE_CLIENT_ID not set. Skipping verification (DEV ONLY!)")
            raise ValueError("GOOGLE_CLIENT_ID is not configured on backend")

        # Support both Android and Web client IDs
        audiences = [settings.GOOGLE_CLIENT_ID, settings.GOOGLE_CLIENT_ID_WEB]
        audiences = [aud for aud in audiences if aud]

        # The Google library uses 'clock_skew_in_seconds' in newer versions.
        # We wrap the call to handle both argument names or no argument for maximum compatibility.
        from google.oauth2 import id_token
        
        def _verify():
            try:
                return id_token.verify_oauth2_token(
                    token, _google_request_session, audiences, clock_skew_in_seconds=300
                )
            except TypeError:
                return id_token.verify_oauth2_token(
                    token, _google_request_session, audiences
                )

        idinfo = await asyncio.to_thread(_verify)

        if idinfo['iss'] not in ['accounts.google.com', 'https://accounts.google.com']:
            raise ValueError('Wrong issuer.')

        return idinfo
    except Exception as e:
        logger.error(f"Google token verification failed: {e}")
        raise ValueError(str(e))
