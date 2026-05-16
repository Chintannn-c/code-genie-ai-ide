"""
Agent Permissions — Least-Privilege Access Control
"""
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
BLOCKED_COMMANDS = ["rm -rf", "rmdir /s", "format ", "mkfs", "dd if=", ":(){:|:&};:", "shutdown", "reboot"]

class AgentPermissionManager:
    def __init__(self):
        self._denied = 0
        self._approved = 0
        self._log: List[Dict] = []

    def check_permission(self, agent_role: AgentRole, action: ToolAction, details: Dict = None) -> Dict[str, Any]:
        config = get_agent_config(agent_role)
        if not config:
            self._denied += 1
            return {"allowed": False, "reason": f"Unknown role: {agent_role}"}

        perm = config.get("permission", ToolPermission.NONE)
        allowed = PERMISSION_MATRIX.get(perm, set())

        if action not in allowed:
            self._denied += 1
            r = {"allowed": False, "reason": f"'{agent_role.value}' cannot '{action.value}'", "requires_approval": action in APPROVAL_REQUIRED}
            logger.warning(f"🚫 [PERMISSIONS] DENIED: {r['reason']}")
            return r

        if action == ToolAction.RUN_COMMAND and details:
            cmd = details.get("command", "").lower()
            for blocked in BLOCKED_COMMANDS:
                if blocked in cmd:
                    self._denied += 1
                    return {"allowed": False, "reason": f"Blocked: '{blocked}'"}

        self._approved += 1
        return {"allowed": True, "reason": f"Permitted under '{perm.value}'", "requires_approval": action in APPROVAL_REQUIRED}

    def get_stats(self):
        return {"approved": self._approved, "denied": self._denied}

permission_manager = AgentPermissionManager()
