import logging
import hashlib
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status, Request
from app.database import get_db
from app.routes.deps import get_current_user_id
from app.services.redis_service import redis_service
from app.services.socket_manager import manager as socket_manager
from fastapi.security import OAuth2PasswordBearer

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/security", tags=["security"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

async def get_current_token_hash(token: str = Depends(oauth2_scheme)) -> str:
    """Helper dependency to calculate the hash of the current active token."""
    return hashlib.sha256(token.encode('utf-8')).hexdigest()

@router.get("/sessions")
async def get_active_sessions(
    request: Request,
    current_user_id: str = Depends(get_current_user_id),
    current_token_hash: str = Depends(get_current_token_hash)
):
    """
    Fetch all active, non-revoked sessions for the current user.
    Identify which session represents the current request.
    """
    db = await get_db()
    sessions_cursor = db.user_sessions.find({"user_id": current_user_id, "revoked": False})
    
    sessions = []
    async for s in sessions_cursor:
        sessions.append({
            "id": s["_id"],
            "device_name": s.get("device_name", "Unknown Device"),
            "browser": s.get("browser", "Unknown Browser"),
            "operating_system": s.get("operating_system", "Unknown OS"),
            "ip_address": s.get("ip_address", "Unknown IP"),
            "platform": s.get("platform", "Web"),
            "user_agent": s.get("user_agent", ""),
            "created_at": s["created_at"].isoformat() if isinstance(s.get("created_at"), datetime) else s.get("created_at"),
            "last_seen": s["last_seen"].isoformat() if isinstance(s.get("last_seen"), datetime) else s.get("last_seen"),
            "is_current": s["session_token_hash"] == current_token_hash,
            "is_active": s.get("is_active", True)
        })
        
    return {"status": "success", "sessions": sessions}

@router.delete("/sessions/{session_id}")
async def revoke_user_session(
    session_id: str,
    current_user_id: str = Depends(get_current_user_id),
    current_token_hash: str = Depends(get_current_token_hash)
):
    """
    Revoke a specific active session. Blacklist the associated token in Redis,
    update its status in MongoDB, and instantly terminate any active WebSockets.
    """
    db = await get_db()
    session = await db.user_sessions.find_one({"_id": session_id, "user_id": current_user_id})
    
    if not session:
        raise HTTPException(status_code=404, detail="Active session not found")
        
    token_hash = session["session_token_hash"]
    
    # 1. Update session status in MongoDB
    await db.user_sessions.update_one(
        {"_id": session_id},
        {"$set": {
            "revoked": True, 
            "is_active": False, 
            "updated_at": datetime.now(timezone.utc)
        }}
    )
    
    # 2. Store blacklist signature in Redis cache layer (24 hours expiration)
    await redis_service.set(f"revoked_token:{token_hash}", True, expire_seconds=86400)
    
    # 3. Securely tear down target WebSocket connections instantly
    await socket_manager.disconnect_session(token_hash)
    
    # 4. Broadcast dynamic real-time event through active sockets to sync local states
    await socket_manager.broadcast_to_user(
        current_user_id,
        {
            "type": "session_revoked_event",
            "session_id": session_id,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    )
    
    logger.info(f"🔒 [SECURITY] Session {session_id} successfully revoked by user {current_user_id}")
    return {"status": "success", "message": "Session revoked and disconnected successfully"}

@router.delete("/sessions/revoke-all")
async def revoke_all_other_sessions(
    current_user_id: str = Depends(get_current_user_id),
    current_token_hash: str = Depends(get_current_token_hash)
):
    """
    Revoke all active sessions for the current user except the current active session.
    """
    db = await get_db()
    
    # Query all active non-revoked sessions excluding the active session token
    sessions_cursor = db.user_sessions.find({
        "user_id": current_user_id,
        "session_token_hash": {"$ne": current_token_hash},
        "revoked": False
    })
    
    revoked_hashes = []
    revoked_ids = []
    async for s in sessions_cursor:
        revoked_hashes.append(s["session_token_hash"])
        revoked_ids.append(s["_id"])
        
    if not revoked_ids:
        return {"status": "success", "message": "No other active sessions exist to revoke"}
        
    # 1. Update database records
    await db.user_sessions.update_many(
        {"_id": {"$in": revoked_ids}},
        {"$set": {
            "revoked": True,
            "is_active": False,
            "updated_at": datetime.now(timezone.utc)
        }}
    )
    
    # 2. Add to Redis blacklist and close WebSockets
    for token_hash in revoked_hashes:
        await redis_service.set(f"revoked_token:{token_hash}", True, expire_seconds=86400)
        await socket_manager.disconnect_session(token_hash)
        
    # 3. Broadcast sync notification event
    await socket_manager.broadcast_to_user(
        current_user_id,
        {
            "type": "all_sessions_revoked_event",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    )
    
    logger.info(f"🔒 [SECURITY] User {current_user_id} revoked {len(revoked_ids)} other concurrent sessions")
    return {"status": "success", "message": f"Successfully revoked {len(revoked_ids)} other sessions"}
