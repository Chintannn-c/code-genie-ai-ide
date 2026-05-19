import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Request
from app.models.requests import SyncDeltaRequest
from app.routes.deps import get_current_user_id
from app.database import get_database

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/sync", tags=["sync"])


def _now() -> datetime:
    return datetime.now(timezone.utc)


@router.post("/delta")
async def sync_deltas(
    request: Request,
    payload: SyncDeltaRequest,
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Sync offline delta queue operations with the database cluster.
    Resolves concurrent updates using Vector Clock Last-Write-Wins (LWW).
    Returns server vector clock updates that client needs to download.
    """
    db = get_database()
    response_deltas = []
    
    # 1. Fetch current global clock sequence count for this user
    user_meta = await db.users.find_one({"_id": current_user_id}) or {}
    server_global_clock = user_meta.get("global_sync_clock", 1)

    # 2. Process all pending local client changes
    for change in payload.pending_changes:
        entity_id = change.entity_id
        entity_type = change.entity_type
        op = change.operation
        delta = change.delta_payload
        
        # Security validation: Verify ownership/isolation
        if entity_type == "chats":
            existing = await db.chats.find_one({"chat_id": entity_id})
            if existing and existing["user_id"] != current_user_id:
                logger.warning(f"Unauthorized sync attempt: Chat {entity_id} by user {current_user_id}")
                continue
                
            if op == "INSERT":
                if not existing:
                    await db.chats.insert_one({
                        "chat_id": entity_id,
                        "user_id": current_user_id,
                        "title": delta.get("title", "New Chat"),
                        "message_count": delta.get("message_count", 0),
                        "vector_clock": change.vector_clock,
                        "created_at": _now(),
                        "updated_at": _now(),
                    })
            elif op == "UPDATE":
                if existing:
                    # LWW Conflict Resolution
                    existing_clock = existing.get("vector_clock", 0)
                    if change.vector_clock > existing_clock:
                        await db.chats.update_one(
                            {"chat_id": entity_id},
                            {
                                "$set": {
                                    "title": delta.get("title", existing["title"]),
                                    "vector_clock": change.vector_clock,
                                    "updated_at": _now(),
                                }
                            }
                        )
            elif op == "DELETE":
                if existing:
                    await db.chats.delete_one({"chat_id": entity_id})
                    await db.messages.delete_many({"chat_id": entity_id})

        elif entity_type == "messages":
            existing = await db.messages.find_one({"message_id": entity_id})
            # Verify chat belongs to this user
            chat_id = delta.get("chat_id")
            if chat_id:
                chat = await db.chats.find_one({"chat_id": chat_id})
                if chat and chat["user_id"] != current_user_id:
                    logger.warning(f"Unauthorized sync: Message {entity_id} in Chat {chat_id}")
                    continue
            
            if op == "INSERT":
                if not existing:
                    await db.messages.insert_one({
                        "message_id": entity_id,
                        "chat_id": chat_id,
                        "role": delta.get("role", "user"),
                        "content": delta.get("content", ""),
                        "type": delta.get("type", "generate"),
                        "language": delta.get("language", "python"),
                        "file_id": delta.get("file_id"),
                        "is_image": delta.get("is_image", False),
                        "model_name": delta.get("model_name"),
                        "vector_clock": change.vector_clock,
                        "timestamp": _now(),
                    })
            elif op == "UPDATE":
                if existing:
                    existing_clock = existing.get("vector_clock", 0)
                    if change.vector_clock > existing_clock:
                        await db.messages.update_one(
                            {"message_id": entity_id},
                            {
                                "$set": {
                                    "content": delta.get("content", existing["content"]),
                                    "vector_clock": change.vector_clock,
                                }
                            }
                        )
            elif op == "DELETE":
                if existing:
                    await db.messages.delete_one({"message_id": entity_id})

        # Log operation in persistent sync trail
        server_global_clock += 1
        await db.sync_logs.insert_one({
            "user_id": current_user_id,
            "device_id": payload.device_id,
            "entity_type": entity_type,
            "entity_id": entity_id,
            "operation": op,
            "delta_payload": delta,
            "vector_clock": server_global_clock,
            "timestamp": _now(),
        })

    # Update global clock for the user
    await db.users.update_one(
        {"_id": current_user_id},
        {"$set": {"global_sync_clock": server_global_clock}},
        upsert=True
    )

    # 3. Pull all server delta logs generated by OTHER devices since the client's last_sync_clock
    cursor = db.sync_logs.find({
        "user_id": current_user_id,
        "device_id": {"$ne": payload.device_id},
        "vector_clock": {"$gt": payload.last_sync_clock}
    }).sort("vector_clock", 1)

    async for log in cursor:
        response_deltas.append({
            "entity_type": log["entity_type"],
            "entity_id": log["entity_id"],
            "operation": log["operation"],
            "delta_payload": log["delta_payload"],
            "vector_clock": log["vector_clock"],
        })

    return {
        "status": "success",
        "current_server_clock": server_global_clock,
        "deltas_to_apply": response_deltas
    }
