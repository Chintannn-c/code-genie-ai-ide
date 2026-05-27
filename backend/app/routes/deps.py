import logging
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

async def get_current_user_id(token: str = Depends(oauth2_scheme)) -> str:
    """
    Dependency to verify JWT and return the current user_id (sub).
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
            
        # Verify if token is revoked
        import hashlib
        from app.services.redis_service import redis_service
        from app.database import get_db
        from datetime import datetime, timezone
        import asyncio
        
        token_hash = hashlib.sha256(token.encode('utf-8')).hexdigest()
        
        # 1. Fast Redis Blacklist check
        is_revoked = await redis_service.get(f"revoked_token:{token_hash}")
        if is_revoked:
            logger.warning(f"🔒 [SECURITY] Access rejected: token hash {token_hash} is blacklisted in Redis.")
            raise credentials_exception
            
        # 2. MongoDB Fallback lookup & session activity logging
        db = await get_db()
        session = await db.user_sessions.find_one({"session_token_hash": token_hash})
        if session:
            if session.get("revoked"):
                # Cache revoked status in Redis for 1 hour to prevent DB spam
                await redis_service.set(f"revoked_token:{token_hash}", True, expire_seconds=3600)
                logger.warning(f"🔒 [SECURITY] Access rejected: session {session['_id']} was revoked in MongoDB.")
                raise credentials_exception
                
            # Asynchronously update last_seen timestamp in the background
            async def update_last_seen_task():
                try:
                    await db.user_sessions.update_one(
                        {"_id": session["_id"]},
                        {"$set": {"last_seen": datetime.now(timezone.utc)}}
                    )
                except Exception as ex:
                    logger.error(f"Failed to update session last_seen: {ex}")
            
            asyncio.create_task(update_last_seen_task())
            
        return user_id
    except JWTError as e:
        logger.error(f"JWT Verification Error: {e}")
        raise credentials_exception
