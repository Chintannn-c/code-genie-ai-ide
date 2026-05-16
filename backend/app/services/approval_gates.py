"""
Approval Gates — Human-in-the-Loop Safety
"""
import logging
import asyncio
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone
from enum import Enum

logger = logging.getLogger(__name__)

class RiskLevel(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"

class ApprovalStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    DENIED = "denied"
    EXPIRED = "expired"

RISK_CLASSIFICATION = {
    "write_file": RiskLevel.LOW,
    "read_file": RiskLevel.LOW,
    "list_files": RiskLevel.LOW,
    "run_command": RiskLevel.MEDIUM,
    "delete_file": RiskLevel.HIGH,
    "git_push": RiskLevel.HIGH,
    "deploy": RiskLevel.CRITICAL,
    "db_migrate": RiskLevel.CRITICAL,
    "secret_access": RiskLevel.CRITICAL,
}

# Actions that require manual approval
GATED_ACTIONS = {"delete_file", "git_push", "deploy", "db_migrate", "secret_access"}

class ApprovalRequest:
    def __init__(self, action: str, agent: str, description: str, affected_files: List[str] = None, user_id: str = "system"):
        self.request_id = f"apr_{int(datetime.now(timezone.utc).timestamp())}"
        self.action = action
        self.agent = agent
        self.description = description
        self.affected_files = affected_files or []
        self.risk_level = RISK_CLASSIFICATION.get(action, RiskLevel.MEDIUM)
        self.status = ApprovalStatus.PENDING
        self.user_id = user_id
        self.created_at = datetime.now(timezone.utc).isoformat()
        self.resolved_at = None
        self.ttl_seconds = 300  # 5 min timeout

    def to_dict(self):
        return {
            "request_id": self.request_id,
            "action": self.action,
            "agent": self.agent,
            "description": self.description,
            "affected_files": self.affected_files,
            "risk_level": self.risk_level.value,
            "status": self.status.value,
            "user_id": self.user_id,
            "created_at": self.created_at,
        }

class ApprovalGateManager:
    def __init__(self):
        self._pending: Dict[str, ApprovalRequest] = {}
        self._history: List[Dict] = []

    def requires_approval(self, action: str) -> bool:
        return action in GATED_ACTIONS

    async def request_approval(self, action: str, agent: str, description: str,
                                affected_files: List[str] = None, user_id: str = "system") -> ApprovalRequest:
        req = ApprovalRequest(action, agent, description, affected_files, user_id)
        self._pending[req.request_id] = req
        logger.info(f"🔒 [APPROVAL GATE] New request: {req.request_id} | {action} | Risk: {req.risk_level.value}")

        # Broadcast to frontend via WebSocket
        try:
            from .socket_manager import manager as socket_manager
            await socket_manager.broadcast_to_user(user_id, {
                "type": "approval_request",
                "data": req.to_dict(),
            })
        except Exception as e:
            logger.warning(f"Could not broadcast approval request: {e}")

        return req

    def resolve(self, request_id: str, approved: bool) -> Optional[Dict]:
        req = self._pending.pop(request_id, None)
        if not req:
            return None
        req.status = ApprovalStatus.APPROVED if approved else ApprovalStatus.DENIED
        req.resolved_at = datetime.now(timezone.utc).isoformat()
        self._history.append(req.to_dict())
        logger.info(f"{'✅' if approved else '❌'} [APPROVAL GATE] {request_id} → {req.status.value}")
        return req.to_dict()

    def get_pending(self, user_id: str = None) -> List[Dict]:
        reqs = list(self._pending.values())
        if user_id:
            reqs = [r for r in reqs if r.user_id == user_id]
        return [r.to_dict() for r in reqs]

    def get_stats(self):
        return {
            "pending": len(self._pending),
            "total_resolved": len(self._history),
            "recent": self._history[-10:],
        }

approval_gate_manager = ApprovalGateManager()
