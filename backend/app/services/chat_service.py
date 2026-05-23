import logging
from datetime import datetime, timezone
from uuid import uuid4
from app.database import get_database

logger = logging.getLogger(__name__)


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _uuid() -> str:
    return str(uuid4())


async def create_chat(user_id: str, title: str) -> str:
    """Create a new chat session. Returns the chat_id."""
    db = get_database()
    chat_id = _uuid()
    await db.chats.insert_one({
        "chat_id": chat_id,
        "user_id": user_id,
        "title": title[:100],
        "message_count": 0,
        "created_at": _now(),
        "updated_at": _now(),
    })
    logger.info(f"Created chat {chat_id} for user {user_id}")
    return chat_id


async def update_chat_timestamp(chat_id: str) -> None:
    """Update the chat's last activity timestamp."""
    db = get_database()
    await db.chats.update_one(
        {"chat_id": chat_id},
        {"$set": {"updated_at": _now()}}
    )


async def save_message(
    chat_id: str,
    role: str,
    content: str,
    current_user_id: str, # SECURITY FIX: Require current_user_id for ownership verification
    msg_type: str = "generate",
    language: str = "python",
    file_id: str | None = None,
    is_image: bool = False,
    model_name: str | None = None,
) -> str:
    """Save a message to the database. Returns message_id."""
    db = get_database()
    
    # SECURITY FIX: Verify ownership before saving to prevent IDOR attacks
    chat = await db.chats.find_one({"chat_id": chat_id}, {"user_id": 1})
    if not chat:
        logger.warning(f"Attempted to save message to non-existent chat: {chat_id}")
        return ""
    
    if chat["user_id"] != current_user_id:
        logger.error(f"IDOR ATTEMPT: User {current_user_id} tried to save message to chat {chat_id} owned by {chat['user_id']}")
        return ""

    message_id = _uuid()
    await db.messages.insert_one({
        "message_id": message_id,
        "chat_id": chat_id,
        "role": role,
        "content": content,
        "type": msg_type,
        "language": language,
        "file_id": file_id,
        "is_image": is_image,
        "model_name": model_name,
        "timestamp": _now(),
    })

    await db.chats.update_one(
        {"chat_id": chat_id},
        {
            "$inc": {"message_count": 1},
            "$set": {"updated_at": _now()}
        }
    )

    try:
        from app.services.socket_manager import manager as socket_manager
        await socket_manager.broadcast_to_user(current_user_id, {
            "type": "message_received",
            "chat_id": chat_id,
            "message_id": message_id
        })
    except Exception as e:
        logger.error(f"Broadcast error in save_message: {e}")

    return message_id


async def get_chats(user_id: str, page: int = 1, limit: int = 20) -> dict:
    """Get paginated list of chats for a user using aggregation for efficiency."""
    db = get_database()
    skip = (page - 1) * limit
    total = await db.chats.count_documents({"user_id": user_id})

    pipeline = [
        {"$match": {"user_id": user_id}},
        {"$sort": {"updated_at": -1}},
        {"$skip": skip},
        {"$limit": limit},
        {
            "$project": {
                "_id": 0,
                "chat_id": 1,
                "title": 1,
                "created_at": 1,
                "updated_at": 1,
                "message_count": 1
            }
        }
    ]

    cursor = db.chats.aggregate(pipeline)
    chats = [chat async for chat in cursor]

    return {
        "chats": chats,
        "total": total,
        "page": page,
        "limit": limit,
        "has_more": (skip + limit) < total,
    }


async def get_messages(chat_id: str, page: int = 1, limit: int = 50) -> dict:
    """Get paginated messages for a chat."""
    db = get_database()
    skip = (page - 1) * limit
    total = await db.messages.count_documents({"chat_id": chat_id})

    cursor = db.messages.find(
        {"chat_id": chat_id},
        {"_id": 0}
    ).sort("timestamp", 1).skip(skip).limit(limit)

    messages = []
    async for msg in cursor:
        messages.append({
            "message_id": msg["message_id"],
            "role": msg["role"],
            "content": msg["content"],
            "type": msg.get("type", "generate"),
            "language": msg.get("language", "python"),
            "file_id": msg.get("file_id"),
            "is_image": msg.get("is_image", False),
            "model_name": msg.get("model_name"),
            "timestamp": msg["timestamp"],
        })

    return {
        "messages": messages,
        "total": total,
        "page": page,
        "limit": limit,
        "has_more": (skip + limit) < total,
    }


async def delete_chat(chat_id: str) -> bool:
    """Delete a chat and all its messages."""
    db = get_database()
    chat_result = await db.chats.delete_one({"chat_id": chat_id})
    await db.messages.delete_many({"chat_id": chat_id})
    deleted = chat_result.deleted_count > 0
    return deleted


async def is_chat_owner(chat_id: str, user_id: str) -> bool:
    """Verify if a chat belongs to the specified user."""
    db = get_database()
    chat = await db.chats.find_one({"chat_id": chat_id}, {"user_id": 1})
    return chat is not None and chat["user_id"] == user_id


async def get_user_id_by_chat(chat_id: str) -> str | None:
    """Retrieve the user_id associated with a chat_id."""
    db = get_database()
    chat = await db.chats.find_one({"chat_id": chat_id}, {"user_id": 1})
    return chat["user_id"] if chat else None


async def get_chat_context(chat_id: str, max_messages: int = 10) -> list[dict]:
    """Get recent messages for conversation context."""
    db = get_database()
    cursor = db.messages.find(
        {"chat_id": chat_id},
        {"_id": 0, "role": 1, "content": 1}
    ).sort("timestamp", -1).limit(max_messages)
    messages = []
    async for msg in cursor:
        messages.append(msg)
    messages.reverse()
    return messages


async def ensure_indexes():
    """Create compound indexes for performance."""
    db = get_database()
    await db.chats.create_index(
        [("user_id", 1), ("updated_at", -1)],
        name="user_chats_sort_idx"
    )
    logger.info("✅ Database indexes verified.")


# --- File Metadata Operations ---

async def save_file_metadata(
    user_id: str,
    file_id: str,
    file_name: str,
    file_path: str,
    language: str,
    size: int
) -> None:
    """Save file metadata to MongoDB."""
    db = get_database()
    await db.files.insert_one({
        "file_id": file_id,
        "user_id": user_id,
        "file_name": file_name,
        "file_path": file_path,
        "language": language,
        "size": size,
        "sha256": "",
        "status": "uploading",
        "risk_score": 0,
        "risk_level": "low",
        "quarantine_reason": None,
        "mime_type": "text/plain",
        "created_at": _now()
    })


async def update_file_security_status(
    file_id: str,
    status: str,
    sha256: str | None = None,
    risk_score: int | None = None,
    risk_level: str | None = None,
    quarantine_reason: str | None = None,
    mime_type: str | None = None,
) -> None:
    """Update security scanning details and reputation states in MongoDB."""
    db = get_database()
    update_data = {"status": status}
    
    if sha256 is not None:
        update_data["sha256"] = sha256
    if risk_score is not None:
        update_data["risk_score"] = risk_score
    if risk_level is not None:
        update_data["risk_level"] = risk_level
    if quarantine_reason is not None:
        update_data["quarantine_reason"] = quarantine_reason
    if mime_type is not None:
        update_data["mime_type"] = mime_type

    await db.files.update_one(
        {"file_id": file_id},
        {"$set": update_data}
    )

    file_meta = await db.files.find_one({"file_id": file_id}, {"user_id": 1})
    if file_meta:
        user_id = file_meta["user_id"]
        try:
            from app.services.socket_manager import manager as socket_manager
            await socket_manager.broadcast_to_user(user_id, {
                "type": "file_status_updated",
                "file_id": file_id,
                "status": status,
                "risk_score": risk_score or 0,
                "risk_level": risk_level or "low",
                "quarantine_reason": quarantine_reason,
            })
        except Exception as e:
            logger.error(f"Broadcast error in update_file_security_status: {e}")


async def get_file_metadata(file_id: str) -> dict | None:
    """Fetch file metadata by ID."""
    db = get_database()
    return await db.files.find_one({"file_id": file_id}, {"_id": 0})


async def get_user_files(user_id: str) -> list[dict]:
    """List all files uploaded by a user."""
    db = get_database()
    cursor = db.files.find({"user_id": user_id}, {"_id": 0}).sort("created_at", -1)
    return [f async for f in cursor]
