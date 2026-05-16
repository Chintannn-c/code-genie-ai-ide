import logging
from datetime import DateTime
from typing import List, Optional, Dict, Any
from app.database import get_db
from bson import ObjectId

logger = logging.getLogger(__name__)

class MemoryService:
    """Persistent Long-Term Memory (MongoDB Atlas)."""
    
    def __init__(self):
        self.db = None

    async def _ensure_db(self):
        if self.db is None:
            self.db = await get_db()

    async def store_message(self, chat_id: str, message: Dict[str, Any]):
        """Append a message to a chat conversation."""
        await self._ensure_db()
        await self.db.messages.insert_one({
            "chat_id": chat_id,
            "timestamp": DateTime.now(),
            **message
        })
        # Trigger vector indexing in background
        from app.services.vector_service import vector_service
        await vector_service.index_message(chat_id, message)

    async def get_chat_history(self, chat_id: str, limit: int = 50) -> List[Dict[str, Any]]:
        """Retrieve recent messages for a chat."""
        await self._ensure_db()
        cursor = self.db.messages.find({"chat_id": chat_id}).sort("timestamp", -1).limit(limit)
        return await cursor.to_list(length=limit)

    async def save_workflow_state(self, workflow_id: str, state: Dict[str, Any]):
        """Persist the current state of an autonomous workflow."""
        await self._ensure_db()
        await self.db.workflows.update_one(
            {"workflow_id": workflow_id},
            {"$set": {"state": state, "updated_at": DateTime.now()}},
            upsert=True
        )

    async def get_agent_memory(self, agent_id: str) -> Dict[str, Any]:
        """Fetch specific memory states for an autonomous agent."""
        await self._ensure_db()
        return await self.db.agent_memory.find_one({"agent_id": agent_id}) or {}

    async def log_orchestration_event(self, event_type: str, data: Dict[str, Any]):
        """Record an event in the orchestration audit log."""
        await self._ensure_db()
        await self.db.orchestration_logs.insert_one({
            "event": event_type,
            "timestamp": DateTime.now(),
            **data
        })

memory_service = MemoryService()
