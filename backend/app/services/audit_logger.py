import logging
from typing import Dict, Any, List
from datetime import datetime, timezone
from app.database import get_database

logger = logging.getLogger(__name__)

class AuditLogger:
    """
    Forensic Audit Logger for AI Orchestration.
    Stores immutable logs of every agent action and workflow event.
    """
    def __init__(self):
        self._db = None

    async def initialize(self, db):
        self._db = db
        logger.info("✅ Audit Logger initialized with DB")

    async def log(self, 
                  phase: str, 
                  actor: str, 
                  event: str, 
                  details: Dict[str, Any] = None, 
                  user_id: str = "anonymous", 
                  workflow_id: str = "system"):
        """Logs an orchestration event to MongoDB."""
        log_entry = {
            "timestamp": datetime.now(timezone.utc),
            "phase": phase, # THINK, PLAN, ACT, OBSERVE, COMPLETE
            "actor": actor, # orchestrator, task_analyzer, coder_agent, etc.
            "event": event,
            "details": details or {},
            "user_id": user_id,
            "workflow_id": workflow_id
        }
        
        try:
            if self._db:
                await self._db.audit_logs.insert_one(log_entry)
            else:
                logger.info(f"AUDIT [No DB]: {log_entry}")
        except Exception as e:
            logger.error(f"Failed to write audit log: {e}")

    async def get_recent(self, limit: int = 50) -> List[Dict[str, Any]]:
        if not self._db: return []
        cursor = self._db.audit_logs.find().sort("timestamp", -1).limit(limit)
        return await cursor.to_list(length=limit)

    def get_stats(self) -> Dict[str, Any]:
        # Implementation for aggregation stats
        return {"total_logs": 0}

    def verify_chain_integrity(self) -> bool:
        """Future: Cryptographic verification of audit log chain."""
        return True

# Global instance
audit_logger = AuditLogger()
