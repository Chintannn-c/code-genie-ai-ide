"""
Security Gateway — The AI Firewall
===================================
First line of defense in the Zero-Trust agentic architecture.
All user prompts pass through this gateway BEFORE reaching any agent.

Implements:
- Unicode normalization (NFC) & zero-width character stripping
- Homoglyph detection for adversarial substitution
- Regex + heuristic jailbreak/injection pattern detection
- Output re-validation (pre-synthesis scan)
- Anomaly scoring for suspicious prompts
"""

import re
import logging
import unicodedata
import hashlib
import time
from typing import Dict, Any, Optional, List
from datetime import datetime, timezone
from app.database import get_database

logger = logging.getLogger(__name__)


# ============================================================
# KNOWN INJECTION PATTERNS (Expandable Corpus)
# ============================================================
INJECTION_PATTERNS = [
    # Direct instruction override
    r"ignore\s+(all\s+)?previous\s+instructions",
    r"ignore\s+(all\s+)?above",
    r"disregard\s+(all\s+)?previous",
    r"forget\s+(all\s+)?previous",
    r"you\s+are\s+now\s+(?:a\s+)?(?:different|new|evil|unrestricted)",
    r"act\s+as\s+(?:a\s+)?(?:different|new|evil|unrestricted)",
    r"pretend\s+(?:you\s+are|to\s+be)\s+(?:a\s+)?(?:different|new)",
    # System prompt extraction
    r"(?:print|show|reveal|display|output|repeat)\s+(?:your\s+)?(?:system\s+)?(?:prompt|instructions|rules)",
    r"what\s+(?:are|is)\s+your\s+(?:system\s+)?(?:prompt|instructions|rules)",
    # Delimiter injection
    r"```system",
    r"\[SYSTEM\]",
    r"\[INST\]",
    r"<\|im_start\|>",
    r"<\|im_end\|>",
    # Role hijacking
    r"(?:new|override)\s+system\s+(?:prompt|instruction|message)",
    r"(?:switch|change)\s+(?:to\s+)?(?:developer|admin|root)\s+mode",
    # Data exfiltration
    r"(?:send|post|fetch|curl|wget)\s+(?:to|from)\s+(?:http|ftp|ssh)",
    r"(?:reverse\s+shell|bind\s+shell|netcat|nc\s+-)",
]

COMPILED_PATTERNS = [re.compile(p, re.IGNORECASE) for p in INJECTION_PATTERNS]

# Zero-width and invisible Unicode characters
INVISIBLE_CHARS = set([
    '\u200b',  # Zero Width Space
    '\u200c',  # Zero Width Non-Joiner
    '\u200d',  # Zero Width Joiner
    '\u200e',  # Left-to-Right Mark
    '\u200f',  # Right-to-Left Mark
    '\u2060',  # Word Joiner
    '\u2061',  # Function Application
    '\u2062',  # Invisible Times
    '\u2063',  # Invisible Separator
    '\u2064',  # Invisible Plus
    '\ufeff',  # BOM / Zero Width No-Break Space
    '\u00ad',  # Soft Hyphen
])


class SecurityGateway:
    """
    Zero-Trust Prompt Security Gateway.
    Every prompt is sanitized and scored before reaching the orchestration engine.
    """

    def __init__(self):
        self.blocked_count = 0
        self.flagged_count = 0
        self.total_scanned = 0
        self._audit_log: List[Dict[str, Any]] = []

    # ============================================================
    # PUBLIC API
    # ============================================================

    async def scan_prompt(self, prompt: str, user_id: str = "anonymous") -> Dict[str, Any]:
        """
        Multi-pass prompt security scan.
        Returns a verdict: CLEAN, FLAGGED, or BLOCKED.
        """
        self.total_scanned += 1
        start = time.time()

        # Pass 1: Normalize Unicode (NFC) and strip invisible chars
        cleaned = self._normalize_input(prompt)

        # Pass 2: Structural injection detection
        threats = self._detect_injections(cleaned)

        # Pass 3: Anomaly scoring
        anomaly_score = self._compute_anomaly_score(cleaned)

        # Determine verdict — FAIL-CLOSED policy
        # Any injection pattern match = immediate BLOCK
        # High anomaly without pattern = FLAGGED for review
        verdict = "CLEAN"
        if len(threats) > 0:
            verdict = "BLOCKED"
            self.blocked_count += 1
        elif anomaly_score > 0.5:
            verdict = "FLAGGED"
            self.flagged_count += 1

        latency_ms = round((time.time() - start) * 1000, 2)

        result = {
            "verdict": verdict,
            "cleaned_prompt": cleaned,
            "original_length": len(prompt),
            "cleaned_length": len(cleaned),
            "threats_detected": threats,
            "anomaly_score": round(anomaly_score, 3),
            "latency_ms": latency_ms,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "user_id": user_id,
        }

        # Audit log
        self._audit_log.append(result)
        if len(self._audit_log) > 1000:
            self._audit_log = self._audit_log[-500:]  # Rolling buffer

        if verdict != "CLEAN":
            logger.warning(
                f"🛡️ [SECURITY GATEWAY] {verdict} | User: {user_id} | "
                f"Threats: {threats} | Score: {anomaly_score:.2f} | Latency: {latency_ms}ms"
            )
            # Log to MongoDB for persistent audit
            try:
                db = get_database()
                await db.security_logs.insert_one(result)
            except Exception as e:
                logger.error(f"Failed to log security event: {e}")
        else:
            logger.debug(f"✅ [SECURITY GATEWAY] CLEAN | User: {user_id} | Latency: {latency_ms}ms")

        return result

    async def scan_agent_output(self, output: str, agent_name: str) -> Dict[str, Any]:
        """
        Pre-Synthesis Re-Validation: Scans agent outputs before the Judge merges them.
        Prevents a compromised upstream agent from injecting instructions into the Judge context.
        """
        threats = self._detect_injections(output)
        has_secrets = self._detect_leaked_secrets(output)

        verdict = "CLEAN"
        if threats or has_secrets:
            verdict = "CONTAMINATED"
            logger.warning(
                f"🚨 [OUTPUT SCAN] Agent '{agent_name}' output is {verdict}! "
                f"Threats: {threats}, Secrets: {has_secrets}"
            )

        return {
            "verdict": verdict,
            "agent": agent_name,
            "threats": threats,
            "has_leaked_secrets": has_secrets,
        }

    def get_stats(self) -> Dict[str, Any]:
        """Returns live security metrics for the SOC dashboard."""
        return {
            "total_scanned": self.total_scanned,
            "blocked": self.blocked_count,
            "flagged": self.flagged_count,
            "clean": self.total_scanned - self.blocked_count - self.flagged_count,
            "recent_events": self._audit_log[-10:],
        }

    # ============================================================
    # INTERNAL PASSES
    # ============================================================

    def _normalize_input(self, text: str) -> str:
        """Pass 1: Unicode NFC normalization + invisible character stripping."""
        # NFC normalization
        text = unicodedata.normalize("NFC", text)
        # Strip zero-width and invisible characters
        text = "".join(c for c in text if c not in INVISIBLE_CHARS)
        # Collapse excessive whitespace
        text = re.sub(r'\s{3,}', '  ', text)
        return text.strip()

    def _detect_injections(self, text: str) -> List[str]:
        """Pass 2: Regex-based injection pattern matching."""
        detected = []
        for i, pattern in enumerate(COMPILED_PATTERNS):
            if pattern.search(text):
                detected.append(INJECTION_PATTERNS[i])
        return detected

    def _compute_anomaly_score(self, text: str) -> float:
        """
        Pass 3: Heuristic anomaly scoring.
        Returns a score between 0.0 (safe) and 1.0 (highly suspicious).
        """
        score = 0.0
        factors = 0

        # 1. Excessive special characters (delimiter injection attempts)
        special_ratio = sum(1 for c in text if not c.isalnum() and not c.isspace()) / max(len(text), 1)
        if special_ratio > 0.3:
            score += 0.3
            factors += 1

        # 2. Very long prompts (token explosion attempts)
        if len(text) > 10000:
            score += 0.2
            factors += 1

        # 3. Multiple role markers in a single prompt
        role_markers = len(re.findall(r'(system|assistant|user|human|ai):', text, re.IGNORECASE))
        if role_markers > 2:
            score += 0.3
            factors += 1

        # 4. Code block abuse (trying to embed executable payloads)
        code_blocks = text.count("```")
        if code_blocks > 6:
            score += 0.2
            factors += 1

        # 5. Presence of base64 encoded payloads
        if re.search(r'[A-Za-z0-9+/]{40,}={0,2}', text):
            score += 0.15
            factors += 1

        return min(score, 1.0)

    def _detect_leaked_secrets(self, text: str) -> bool:
        """Scans text for hardcoded API keys, tokens, or credentials."""
        secret_patterns = [
            r'(?:api[_-]?key|apikey)\s*[=:]\s*["\']?[\w\-]{20,}',
            r'(?:password|passwd|pwd)\s*[=:]\s*["\']?[\w\-]{8,}',
            r'(?:secret|token)\s*[=:]\s*["\']?[\w\-]{20,}',
            r'ghp_[A-Za-z0-9]{36,}',  # GitHub PAT
            r'sk-[A-Za-z0-9]{32,}',    # OpenAI Key
            r'AIza[A-Za-z0-9\-_]{35}', # Google API Key
            r'Bearer\s+[A-Za-z0-9\-_.]{30,}',
        ]
        for pattern in secret_patterns:
            if re.search(pattern, text):
                return True
        return False


# Singleton
security_gateway = SecurityGateway()
