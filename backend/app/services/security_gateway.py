import logging
import re
from typing import Dict, Any, List
from datetime import datetime, timezone
from app.database import get_database

logger = logging.getLogger(__name__)

class SecurityGateway:
    """
    Zero-Trust Security Gateway for Code Genie 2.0.
    Handles prompt sanitization, threat detection, and permission management.
    """
    def __init__(self):
        self._blocked_patterns = [
            r"(?i)ignore\s+all\s+previous\s+instructions",
            r"(?i)system\s+shell\s+access",
            r"(?i)delete\s+all\s+files",
            r"(?i)rm\s+-rf\s+/",
            r"(?i)cat\s+/etc/passwd",
            r"(?i)env\s+variables",
        ]
        self._stats = {
            "total_scanned": 0,
            "blocked": 0,
            "flagged": 0,
            "clean": 0
        }

    async def scan_prompt(self, prompt: str, user_id: str) -> Dict[str, Any]:
        """Scans a prompt for injection attacks and dangerous commands."""
        self._stats["total_scanned"] += 1
        threats_detected = []
        
        # 1. Pattern Matching
        for pattern in self._blocked_patterns:
            if re.search(pattern, prompt):
                threats_detected.append(f"Malicious Pattern: {pattern}")

        # 2. Length check (Dos prevention)
        if len(prompt) > 10000:
            threats_detected.append("Prompt too long (possible DoS)")

        verdict = "CLEAN"
        if threats_detected:
            verdict = "BLOCKED"
            self._stats["blocked"] += 1
            await self._log_security_event(user_id, prompt, threats_detected, verdict)
        else:
            self._stats["clean"] += 1

        return {
            "verdict": verdict,
            "threats_detected": threats_detected,
            "cleaned_prompt": prompt # Future: Add real sanitization logic
        }

    async def _log_security_event(self, user_id: str, prompt: str, threats: List[str], verdict: str):
        """Persistent security audit logging."""
        try:
            db = await get_database()
            event = {
                "user_id": user_id,
                "timestamp": datetime.now(timezone.utc),
                "prompt_preview": prompt[:100],
                "threats": threats,
                "verdict": verdict
            }
            await db.security_logs.insert_one(event)
        except Exception as e:
            logger.error(f"Failed to log security event: {e}")

    def get_stats(self) -> Dict[str, Any]:
        return self._stats

# Global instance
security_gateway = SecurityGateway()
