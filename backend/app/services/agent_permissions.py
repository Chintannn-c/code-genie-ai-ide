"""
Agent Permissions — Least-Privilege Access Control (Hardened)
=============================================================
Deny-by-default permission system with regex-based command blocking
and proper audit logging of all access decisions.
"""
import re
import logging
from typing import Dict, Any, List, Set
from enum import Enum
from .agent_roles import AgentRole, ToolPermission, get_agent_config

logger = logging.getLogger(__name__)

class ToolAction(str, Enum):
    READ_FILE = "read_file"
    WRITE_FILE = "write_file"
    LIST_FILES = "list_files"
    RUN_COMMAND = "run_command"
    SEARCH_INDEX = "search_index"
    DEPLOY = "deploy"
    DELETE_FILE = "delete_file"
    GIT_PUSH = "git_push"

PERMISSION_MATRIX = {
    ToolPermission.READ_ONLY: {ToolAction.READ_FILE, ToolAction.LIST_FILES, ToolAction.SEARCH_INDEX},
    ToolPermission.READ_WRITE: {ToolAction.READ_FILE, ToolAction.WRITE_FILE, ToolAction.LIST_FILES, ToolAction.SEARCH_INDEX},
    ToolPermission.EXECUTE: {ToolAction.READ_FILE, ToolAction.WRITE_FILE, ToolAction.LIST_FILES, ToolAction.RUN_COMMAND, ToolAction.SEARCH_INDEX},
    ToolPermission.SCAN_ONLY: {ToolAction.READ_FILE, ToolAction.LIST_FILES, ToolAction.SEARCH_INDEX},
    ToolPermission.DEPLOY_ONLY: {ToolAction.READ_FILE, ToolAction.LIST_FILES, ToolAction.DEPLOY},
    ToolPermission.NONE: set(),
}

APPROVAL_REQUIRED = {ToolAction.DELETE_FILE, ToolAction.GIT_PUSH, ToolAction.DEPLOY}

# Regex-based blocked command patterns (matches shell obfuscation)
BLOCKED_COMMAND_PATTERNS = [
    r"rm\s+(-\w+\s+)*-r",
    r"rmdir\s+/s",
    r"del\s+/[sfq]",
    r"format\s+[a-z]:",
    r"mkfs\b",
    r"dd\s+if=",
    r"\bshutdown\b",
    r"\breboot\b",
    r":\(\)\s*\{",
    r"\bnc\s+-[elp]",
    r"reverse.?shell",
    r"bind.?shell",
    r"bash\s+-i\s+>&",
    r"/dev/tcp/",
    r"\bprintenv\b",
    r"\benv\b\s*$",
    r"\bset\b\s*$",
    r"echo\s+\$\w*(KEY|SECRET|TOKEN|PASSWORD|URI)",
    r"cat\s+.*\.(env|pem|key)",
    r"curl\s+.*\|\s*(ba)?sh",
    r"wget\s+.*\|\s*(ba)?sh",
    r"\bsudo\b",
    r"\bsu\s+-",
]

COMPILED_BLOCKED = [re.compile(p, re.IGNORECASE) for p in BLOCKED_COMMAND_PATTERNS]


class AgentPermissionManager:
    def __init__(self):
        self._denied = 0
        self._approved = 0
        self._log: List[Dict] = []

    def check_permission(self, agent_role: AgentRole, action: ToolAction, details: Dict = None) -> Dict[str, Any]:
        config = get_agent_config(agent_role)
        if not config:
            self._denied += 1
            self._record(agent_role.value if isinstance(agent_role, AgentRole) else str(agent_role), action.value, False, "Unknown role")
            return {"allowed": False, "reason": f"Unknown role: {agent_role}"}

        perm = config.get("permission", ToolPermission.NONE)
        allowed = PERMISSION_MATRIX.get(perm, set())

        if action not in allowed:
            self._denied += 1
            reason = f"'{agent_role.value}' with '{perm.value}' cannot '{action.value}'"
            self._record(agent_role.value, action.value, False, reason)
            logger.warning(f"🚫 [PERMISSIONS] DENIED: {reason}")
            return {"allowed": False, "reason": reason, "requires_approval": action in APPROVAL_REQUIRED}

        # Regex-based command blocking (not simple substring)
        if action == ToolAction.RUN_COMMAND and details:
            cmd = details.get("command", "")
            for i, pattern in enumerate(COMPILED_BLOCKED):
                if pattern.search(cmd):
                    self._denied += 1
                    reason = f"Blocked dangerous pattern: {BLOCKED_COMMAND_PATTERNS[i]}"
                    self._record(agent_role.value, action.value, False, reason)
                    logger.warning(f"🚫 [PERMISSIONS] {reason} in: {cmd[:60]}")
                    return {"allowed": False, "reason": reason}

        self._approved += 1
        self._record(agent_role.value, action.value, True, f"Permitted under '{perm.value}'")
        return {"allowed": True, "reason": f"Permitted under '{perm.value}'", "requires_approval": action in APPROVAL_REQUIRED}

    def _record(self, agent: str, action: str, allowed: bool, reason: str):
        self._log.append({"agent": agent, "action": action, "allowed": allowed, "reason": reason})
        if len(self._log) > 500:
            self._log = self._log[-250:]

    def get_stats(self):
        return {
            "approved": self._approved,
            "denied": self._denied,
            "total_checks": self._approved + self._denied,
            "recent_decisions": self._log[-10:],
        }

permission_manager = AgentPermissionManager()
