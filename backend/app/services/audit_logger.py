"""
Audit Logger — Immutable Action Trail
=======================================
Implements a tamper-evident, append-only audit log for all agent actions.
Every THINK, PLAN, ACT, OBSERVE, REFLECT, and COMPLETE event is recorded
with timestamps and agent identity.

Stores to MongoDB for persistence and provides forensic replay capability.
"""

import logging
import time
import hashlib
import json
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

logger = logging.getLogger(__name__)


class AuditEvent:
    """A single immutable audit record."""

    def __init__(
        self,
        event_type: str,
        agent_name: str,
        action: str,
        details: Optional[Dict[str, Any]] = None,
        user_id: str = "system",
        workflow_id: Optional[str] = None,
    ):
        self.timestamp = datetime.now(timezone.utc).isoformat()
        self.event_type = event_type
        self.agent_name = agent_name
        self.action = action
        self.details = details or {}
        self.user_id = user_id
        self.workflow_id = workflow_id
        self.hash = self._compute_hash()

    def _compute_hash(self) -> str:
        """Creates a SHA-256 hash of the event for integrity verification."""
        payload = json.dumps({
            "timestamp": self.timestamp,
            "event_type": self.event_type,
            "agent_name": self.agent_name,
            "action": self.action,
            "user_id": self.user_id,
            "workflow_id": self.workflow_id,
        }, sort_keys=True)
        return hashlib.sha256(payload.encode()).hexdigest()[:16]

    def to_dict(self) -> Dict[str, Any]:
        return {
            "timestamp": self.timestamp,
            "event_type": self.event_type,
            "agent_name": self.agent_name,
            "action": self.action,
            "details": self.details,
            "user_id": self.user_id,
            "workflow_id": self.workflow_id,
            "hash": self.hash,
        }


class AuditLogger:
    """
    Append-only audit logger with integrity chain verification.
    Stores events in-memory with periodic flush to MongoDB.
    """

    def __init__(self):
        self._chain: List[Dict[str, Any]] = []
        self._db_collection = None
        self._chain_hash = "GENESIS"

    async def initialize(self, db):
        """Connect to MongoDB for persistent audit storage."""
        try:
            self._db_collection = db["audit_log"]
            # Create indexes
            await self._db_collection.create_index("timestamp")
            await self._db_collection.create_index("workflow_id")
            await self._db_collection.create_index("agent_name")
            logger.info("📝 [AUDIT] MongoDB audit log initialized.")
        except Exception as e:
            logger.warning(f"⚠️ [AUDIT] MongoDB init failed (in-memory only): {e}")

    async def log(
        self,
        event_type: str,
        agent_name: str,
        action: str,
        details: Optional[Dict[str, Any]] = None,
        user_id: str = "system",
        workflow_id: Optional[str] = None,
    ):
        """
        Append an immutable event to the audit chain.
        
        Event types: THINK, PLAN, ACT, OBSERVE, REFLECT, RETRY, 
                      QUARANTINE, AUDIT, COMPLETE, SECURITY, ERROR
        """
        event = AuditEvent(
            event_type=event_type,
            agent_name=agent_name,
            action=action,
            details=details,
            user_id=user_id,
            workflow_id=workflow_id,
        )

        # Chain integrity: link to previous event
        record = event.to_dict()
        record["prev_hash"] = self._chain_hash
        self._chain_hash = event.hash

        # Append to in-memory chain
        self._chain.append(record)

        # Cap in-memory chain at 5000 events
        if len(self._chain) > 5000:
            self._chain = self._chain[-2500:]

        # Persist to MongoDB (async, non-blocking)
        if self._db_collection is not None:
            try:
                await self._db_collection.insert_one(record)
            except Exception as e:
                logger.error(f"❌ [AUDIT] Persistence failed: {e}")

        # Log to stdout for observability
        logger.info(
            f"📝 [AUDIT] [{event_type}] Agent: {agent_name} | "
            f"Action: {action} | Workflow: {workflow_id} | Hash: {event.hash}"
        )

    async def get_workflow_trail(self, workflow_id: str) -> List[Dict[str, Any]]:
        """Retrieves the full audit trail for a specific workflow."""
        if self._db_collection is not None:
            try:
                cursor = self._db_collection.find(
                    {"workflow_id": workflow_id}
                ).sort("timestamp", 1)
                return await cursor.to_list(length=500)
            except Exception:
                pass
        # Fallback to in-memory
        return [e for e in self._chain if e.get("workflow_id") == workflow_id]

    def get_recent(self, count: int = 20) -> List[Dict[str, Any]]:
        """Returns the most recent audit events."""
        return self._chain[-count:]

    def verify_chain_integrity(self) -> Dict[str, Any]:
        """Verifies the integrity of the in-memory audit chain."""
        if not self._chain:
            return {"status": "EMPTY", "length": 0}

        broken_at = None
        for i in range(1, len(self._chain)):
            expected_prev = self._chain[i - 1].get("hash", "")
            actual_prev = self._chain[i].get("prev_hash", "")
            if expected_prev != actual_prev:
                broken_at = i
                break

        return {
            "status": "INTACT" if broken_at is None else "BROKEN",
            "length": len(self._chain),
            "broken_at_index": broken_at,
            "chain_head": self._chain_hash,
        }

    def get_stats(self) -> Dict[str, Any]:
        """Returns audit statistics for the SOC dashboard."""
        events_by_type = {}
        events_by_agent = {}
        for event in self._chain:
            et = event.get("event_type", "UNKNOWN")
            events_by_type[et] = events_by_type.get(et, 0) + 1
            ag = event.get("agent_name", "UNKNOWN")
            events_by_agent[ag] = events_by_agent.get(ag, 0) + 1

        return {
            "total_events": len(self._chain),
            "by_type": events_by_type,
            "by_agent": events_by_agent,
            "chain_integrity": self.verify_chain_integrity(),
        }


# Singleton
audit_logger = AuditLogger()
