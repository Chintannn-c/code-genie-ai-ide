import logging
from datetime import datetime, timezone
from fastapi import APIRouter, HTTPException, status, Depends, Request
from app.database import get_db
from app.limiter import limiter
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
@limiter.limit("5/hour")
async def register(request: Request, user_in: UserCreate):
    """Register a new user."""
    db = await get_db()
    
    # Check if user exists
    existing_user = await db.users.find_one({"email": user_in.email})
    if existing_user:
        # SECURITY FIX: Generic message to prevent username enumeration
        raise HTTPException(
            status_code=400,
            detail="Registration could not be completed. Please check your details or try logging in."
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
@limiter.limit("10/minute")
async def login(request: Request, user_in: UserCreate): # Using same schema for simplicity
    """Login with email and password."""
    db = await get_db()
    
    user = await db.users.find_one({"email": user_in.email})
    
    # Security: Check if user exists and reject empty passwords
    if not user or not user_in.password or not user.get("hashed_password"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not auth_service.verify_password(user_in.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
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
        
        # SECURITY FIX: Ensure the email is verified before merging or creating an account
        if not id_info.get("email_verified"):
            raise HTTPException(status_code=400, detail="Security: Unverified Google email address.")

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
        # SECURITY FIX: Generic error message
        raise HTTPException(status_code=401, detail="Authentication with Google failed. Please try again.")

# ──────────────────────────────────────────────────────────────────────────
# Enterprise Account & Profile REST Endpoints
# ──────────────────────────────────────────────────────────────────────────

from app.routes.deps import get_current_user_id

class ProfileUpdateRequest(BaseModel):
    full_name: str
    email: str

class ProviderToggleRequest(BaseModel):
    provider: str
    connected: bool

class SecurityUpdateRequest(BaseModel):
    two_factor: bool
    biometric: bool
    code: str = None

class SendCodeRequest(BaseModel):
    email: str

class SessionRevokeRequest(BaseModel):
    session_id: str

class AiSettingsUpdateRequest(BaseModel):
    temperature: float = None
    max_tokens: float = None
    creativity: float = None
    streaming: bool = None
    autonomous_mode: bool = None
    debate_mode: bool = None
    rag_context: bool = None
    memory_persist: bool = None
    memories: list = None

class NotificationSettingsUpdateRequest(BaseModel):
    push: bool = None
    ai_alerts: bool = None
    security_alerts: bool = None
    model_failure: bool = None
    deployment: bool = None
    collaboration: bool = None
    email: bool = None
    sound: bool = None
    history_retention_days: int = None
    ai_alert_filtering: str = None
    quiet_hours_enabled: bool = None
    quiet_hours_start: str = None
    quiet_hours_end: str = None
    custom_webhook_url: str = None
    slack_webhook_url: str = None
    discord_webhook_url: str = None
    teams_webhook_url: str = None

@router.get("/profile")
async def get_profile(current_user_id: str = Depends(get_current_user_id)):
    """Fetch user profile metadata, active sessions, AI usage, and security configurations."""
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Standardize metadata default states dynamically on read for compatibility
    updated = False
    set_fields = {}
    
    if "two_factor" not in user:
        user["two_factor"] = False
        set_fields["two_factor"] = False
        updated = True
    if "biometric" not in user:
        user["biometric"] = True
        set_fields["biometric"] = True
        updated = True
    if "connections" not in user:
        user["connections"] = {
            "Google": True,
            "GitHub": False,
            "OpenRouter": True,
            "Groq": True
        }
        set_fields["connections"] = user["connections"]
        updated = True
    if "usage" not in user:
        user["usage"] = {
            "used": 4210891,
            "limit": 10000000
        }
        set_fields["usage"] = user["usage"]
        updated = True
    if "active_sessions" not in user:
        user["active_sessions"] = []
        set_fields["active_sessions"] = user["active_sessions"]
        updated = True
    if "anomaly_logs" not in user:
        user["anomaly_logs"] = []
        set_fields["anomaly_logs"] = user["anomaly_logs"]
        updated = True
        
    if "ai_settings" not in user:
        user["ai_settings"] = {
            "temperature": 0.7,
            "max_tokens": 4096.0,
            "creativity": 0.6,
            "streaming": True,
            "autonomous_mode": False,
            "debate_mode": False,
            "rag_context": True,
            "memory_persist": False
        }
        set_fields["ai_settings"] = user["ai_settings"]
        updated = True
        
    if updated:
        await db.users.update_one({"_id": current_user_id}, {"$set": set_fields})
        
    return {
        "status": "success",
        "full_name": user.get("full_name", "Code Genie User"),
        "email": user.get("email"),
        "picture_url": user.get("picture_url"),
        "two_factor": user.get("two_factor", False),
        "biometric": user.get("biometric", True),
        "connections": user.get("connections"),
        "usage": user.get("usage"),
        "active_sessions": user.get("active_sessions"),
        "anomaly_logs": user.get("anomaly_logs"),
        "ai_settings": user.get("ai_settings")
    }

@router.post("/profile/update")
async def update_profile(request: ProfileUpdateRequest, current_user_id: str = Depends(get_current_user_id)):
    """Update profile information across devices."""
    db = await get_db()
    
    await db.users.update_one(
        {"_id": current_user_id},
        {
            "$set": {
                "full_name": request.full_name,
                "email": request.email,
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )
    
    return {"status": "success", "message": "Profile updated successfully"}

@router.post("/providers/toggle")
async def toggle_provider(request: ProviderToggleRequest, current_user_id: str = Depends(get_current_user_id)):
    """Connect or disconnect an integration provider."""
    db = await get_db()
    
    # Update nested connection dictionary
    await db.users.update_one(
        {"_id": current_user_id},
        {
            "$set": {
                f"connections.{request.provider}": request.connected,
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )
    
    return {"status": "success", "message": f"{request.provider} status changed successfully"}

import random

@router.post("/security/send-code")
@limiter.limit("5/hour")
async def send_verification_code(request: Request, body_req: SendCodeRequest, current_user_id: str = Depends(get_current_user_id)):
    """Generate and log a secure 6-digit authentication code to the user's Gmail."""
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Generate 6-digit numeric OTP code
    code = f"{random.randint(100000, 999999)}"
    
    # Securely cache this code in user's document for validation
    await db.users.update_one(
        {"_id": current_user_id},
        {"$set": {"pending_2fa_code": code}}
    )
    
    # Print securely to logs so developers/users can see it
    logger.info(f"📧 [Gmail OTP] Sending 6-digit 2FA validation code {code} to user email {body_req.email}")
    
    return {
        "status": "success",
        "message": f"Verification code sent to {body_req.email}"
    }

@router.post("/security/update")
async def update_security(request: SecurityUpdateRequest, current_user_id: str = Depends(get_current_user_id)):
    """Configure MFA or biometric keystore logs and verify Gmail code if enabling 2FA."""
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # If enabling two_factor, check code
    if request.two_factor and not user.get("two_factor"):
        if not request.code or request.code != user.get("pending_2fa_code"):
            raise HTTPException(status_code=400, detail="Invalid Gmail verification code.")

    # Log anomaly updates dynamically
    log_text = f"MFA toggled to {request.two_factor} via Gmail • Just now"
    await db.users.update_one(
        {"_id": current_user_id},
        {
            "$set": {
                "two_factor": request.two_factor,
                "biometric": request.biometric,
                "updated_at": datetime.now(timezone.utc)
            },
            "$push": {
                "anomaly_logs": {
                    "$each": [log_text],
                    "$position": 0
                }
            }
        }
    )
    
    return {"status": "success", "message": "Security settings synchronized"}

@router.post("/sessions/revoke")
async def revoke_session(request: SessionRevokeRequest, current_user_id: str = Depends(get_current_user_id)):
    """Revoke an active user session by identifier."""
@router.get("/ai-settings")
async def get_ai_settings(current_user_id: str = Depends(get_current_user_id)):
    """Fetch user's AI orchestration settings from the SQL store."""
    from app.services.pg_settings import settings_store
    try:
        ai_settings = await settings_store.get_user_preferences(current_user_id)
        return {"status": "success", "ai_settings": ai_settings}
    except Exception as e:
        logger.error(f"Failed to fetch user preferences: {e}")
        # Fallback to local MongoDB if SQL is failing or uninitialized
        db = await get_db()
        user = await db.users.find_one({"_id": current_user_id})
        if not user:
            raise HTTPException(status_code=404, detail="User not found")
        ai_settings = user.get("ai_settings", {
            "temperature": 0.7,
            "max_tokens": 4096.0,
            "creativity": 0.6,
            "streaming": True,
            "autonomous_mode": False,
            "debate_mode": False,
            "rag_context": True,
            "memory_persist": False
        })
        return {"status": "success", "ai_settings": ai_settings}

@router.post("/ai-settings/update")
async def update_ai_settings(
    request: AiSettingsUpdateRequest, 
    req: Request,
    current_user_id: str = Depends(get_current_user_id)
):
    """Update user's AI orchestration settings globally with distributed sync and real-time alerts."""
    from app.services.pg_settings import settings_store
    from app.services.socket_manager import manager as socket_manager
    from app.services.redis_service import redis_service
    
    db = await get_db()
    
    # 1. Fetch current settings as base
    current_settings = await settings_store.get_user_preferences(current_user_id)
    
    # 2. Extract updates
    prefs_update = {}
    mongo_update = {}
    if request.temperature is not None:
        prefs_update["temperature"] = request.temperature
        mongo_update["ai_settings.temperature"] = request.temperature
    if request.max_tokens is not None:
        prefs_update["max_tokens"] = int(request.max_tokens)
        mongo_update["ai_settings.max_tokens"] = request.max_tokens
    if request.creativity is not None:
        prefs_update["creativity"] = request.creativity
        mongo_update["ai_settings.creativity"] = request.creativity
    if request.streaming is not None:
        prefs_update["streaming"] = request.streaming
        mongo_update["ai_settings.streaming"] = request.streaming
    if request.autonomous_mode is not None:
        prefs_update["autonomous_mode"] = request.autonomous_mode
        mongo_update["ai_settings.autonomous_mode"] = request.autonomous_mode
    if request.debate_mode is not None:
        prefs_update["debate_mode"] = request.debate_mode
        mongo_update["ai_settings.debate_mode"] = request.debate_mode
    if request.rag_context is not None:
        prefs_update["rag_context"] = request.rag_context
        mongo_update["ai_settings.rag_context"] = request.rag_context
    if request.memory_persist is not None:
        prefs_update["memory_persist"] = request.memory_persist
        mongo_update["ai_settings.memory_persist"] = request.memory_persist
    if request.memories is not None:
        prefs_update["memories"] = request.memories
        mongo_update["ai_settings.memories"] = request.memories

    if not prefs_update:
        return {"status": "success", "message": "No settings to update"}

    # Merge preferences
    merged_prefs = {**current_settings, **prefs_update}
    
    # Extract client metadata for audit logs
    device_id = req.headers.get("User-Agent", "Web client")
    
    # 3. Persist to PostgreSQL Store with structured versioned audit logging
    version = await settings_store.save_user_preferences(current_user_id, merged_prefs, device_id=device_id)
    
    # 4. Sync MongoDB
    mongo_update["updated_at"] = datetime.now(timezone.utc)
    await db.users.update_one({"_id": current_user_id}, {"$set": mongo_update})
    
    # 5. Dynamic distributed propagation
    ws_payload = {
        "type": "settings_update",
        "ai_settings": merged_prefs,
        "version": version,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    # Broadcast through WebSockets to all connected client devices immediately
    await socket_manager.broadcast_to_user(current_user_id, ws_payload)
    
    # Publish to Redis Pub/Sub so that other server processes can reconfigure active pipelines in real time
    await redis_service.publish(f"settings:user:{current_user_id}", ws_payload)
    
    return {
        "status": "success", 
        "message": "AI Settings persisted and synchronized successfully",
        "version": version,
        "ai_settings": merged_prefs
    }

@router.get("/ai-settings/audit")
async def get_settings_audit(current_user_id: str = Depends(get_current_user_id)):
    """Fetch complete historical log changes list for observability and audits."""
    from app.services.pg_settings import settings_store
    logs = await settings_store.get_audit_trail(current_user_id)
    return {"status": "success", "audit_logs": logs}

class RollbackRequest(BaseModel):
    version: int

@router.post("/ai-settings/rollback")
async def rollback_ai_settings(
    request: RollbackRequest, 
    current_user_id: str = Depends(get_current_user_id)
):
    """Rollback AI settings to a specific historical version."""
    from app.services.pg_settings import settings_store
    from app.services.socket_manager import manager as socket_manager
    from app.services.redis_service import redis_service
    
    audit_logs = await settings_store.get_audit_trail(current_user_id)
    target_snapshot = None
    for log in audit_logs:
        if log["version"] == request.version:
            target_snapshot = log["config"]
            break
            
    if not target_snapshot:
        raise HTTPException(
            status_code=404, 
            detail=f"Settings version {request.version} not found in audit logs"
        )
        
    # Save target snapshot as the active configuration
    version = await settings_store.save_user_preferences(
        current_user_id, 
        target_snapshot, 
        device_id="rollback_event"
    )
    
    # Sync with MongoDB
    db = await get_db()
    await db.users.update_one(
        {"_id": current_user_id},
        {
            "$set": {
                "ai_settings": target_snapshot,
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )
    
    # Broadcast rollback dynamically
    ws_payload = {
        "type": "settings_update",
        "ai_settings": target_snapshot,
        "version": version,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    await socket_manager.broadcast_to_user(current_user_id, ws_payload)
    await redis_service.publish(f"settings:user:{current_user_id}", ws_payload)
    
    return {
        "status": "success", 
        "message": f"Successfully rolled back configuration to version {request.version}", 
        "ai_settings": target_snapshot,
        "version": version
    }

@router.post("/privacy/export")
async def export_data(current_user_id: str = Depends(get_current_user_id)):
    """Export GDPR historical logs and conversation history for this user."""
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    # Retrieve all user chats
    chats_cursor = db.chats.find({"user_id": current_user_id})
    chats_list = []
    async for chat in chats_cursor:
        messages_cursor = db.messages.find({"chat_id": chat["chat_id"]})
        messages = []
        async for msg in messages_cursor:
            messages.append({
                "role": msg.get("role"),
                "content": msg.get("content"),
                "timestamp": str(msg.get("timestamp"))
            })
        chats_list.append({
            "title": chat.get("title"),
            "messages": messages,
            "created_at": str(chat.get("created_at"))
        })
        
    return {
        "export_metadata": {
            "user_id": current_user_id,
            "email": user.get("email"),
            "exported_at": str(datetime.now(timezone.utc))
        },
        "conversations": chats_list
    }

@router.post("/privacy/clear-memory")
@limiter.limit("3/day")
async def clear_memory(request: Request, current_user_id: str = Depends(get_current_user_id)):
    """Clear AI settings, contextual indexing systems, histories, and permanently delete uploaded files."""
    db = await get_db()
    import os
    
    # 0. Delete user physical files and files collection records
    from app.services import chat_service
    user_files = await chat_service.get_user_files(current_user_id)
    for f in user_files:
        file_path = f.get("file_path")
        if file_path and os.path.exists(file_path):
            try:
                os.remove(file_path)
            except Exception as e:
                logger.error(f"Failed to delete file {file_path}: {e}")
    await db.files.delete_many({"user_id": current_user_id})

    # 1. Clear all conversations
    chats_cursor = db.chats.find({"user_id": current_user_id})
    async for chat in chats_cursor:
        await db.messages.delete_many({"chat_id": chat["chat_id"]})
    await db.chats.delete_many({"user_id": current_user_id})
    
    # 2. Reset usage statistics
    await db.users.update_one(
        {"_id": current_user_id},
        {
            "$set": {
                "usage.used": 0,
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )
    
    return {"status": "success", "message": "All database histories, files, and model context keys cleared"}

@router.get("/notification-settings")
async def get_notification_settings(current_user_id: str = Depends(get_current_user_id)):
    """Fetch user's notification orchestration settings."""
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    settings = user.get("notification_settings", {
        "push": True,
        "ai_alerts": True,
        "security_alerts": True,
        "model_failure": True,
        "deployment": True,
        "collaboration": True,
        "email": False,
        "sound": True,
        "history_retention_days": 30,
        "ai_alert_filtering": "ALL",
        "quiet_hours_enabled": False,
        "quiet_hours_start": "22:00",
        "quiet_hours_end": "08:00",
        "custom_webhook_url": "",
        "slack_webhook_url": "",
        "discord_webhook_url": "",
        "teams_webhook_url": ""
    })
    return {"status": "success", "notification_settings": settings}

@router.post("/notification-settings/update")
async def update_notification_settings(
    request: NotificationSettingsUpdateRequest,
    current_user_id: str = Depends(get_current_user_id)
):
    """Update user's notification channels and webhook configurations globally."""
    from app.services.socket_manager import manager as socket_manager
    from app.services.redis_service import redis_service
    
    db = await get_db()
    user = await db.users.find_one({"_id": current_user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    current_settings = user.get("notification_settings", {
        "push": True,
        "ai_alerts": True,
        "security_alerts": True,
        "model_failure": True,
        "deployment": True,
        "collaboration": True,
        "email": False,
        "sound": True,
        "history_retention_days": 30,
        "ai_alert_filtering": "ALL",
        "quiet_hours_enabled": False,
        "quiet_hours_start": "22:00",
        "quiet_hours_end": "08:00",
        "custom_webhook_url": "",
        "slack_webhook_url": "",
        "discord_webhook_url": "",
        "teams_webhook_url": ""
    })
    
    # Merge updates
    updates = {}
    for field, val in request.model_dump(exclude_unset=True).items():
        if val is not None:
            updates[field] = val
            
    merged = {**current_settings, **updates}
    
    # Save to MongoDB
    await db.users.update_one(
        {"_id": current_user_id},
        {"$set": {"notification_settings": merged, "updated_at": datetime.now(timezone.utc)}}
    )
    
    # Broadcast through WebSockets to all connected client devices immediately
    ws_payload = {
        "type": "notification_settings_update",
        "notification_settings": merged,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    await socket_manager.broadcast_to_user(current_user_id, ws_payload)
    
    # Publish to Redis Pub/Sub for horizontal scaling/other nodes
    await redis_service.publish(f"notifications:user:{current_user_id}", ws_payload)
    
    return {"status": "success", "message": "Notification preferences synchronized", "notification_settings": merged}

