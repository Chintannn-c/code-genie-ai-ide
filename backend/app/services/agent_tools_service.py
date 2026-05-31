import os
import subprocess
import asyncio
import logging
import re
import difflib
from typing import Dict, Any, List
from app.config import get_settings

logger = logging.getLogger(__name__)


# ============================================================
# ENVIRONMENT SCRUBBING — Keys that must NEVER leak to agents
# ============================================================
SCRUBBED_ENV_KEYS = {
    "GEMINI_API_KEY", "OPENROUTER_API_KEY", "GROQ_API_KEY",
    "GITHUB_TOKEN", "MISTRAL_API_KEY", "JWT_SECRET",
    "MONGODB_URI", "REDIS_URL", "DATABASE_URL",
    "SECRET_KEY", "AWS_SECRET_ACCESS_KEY", "AWS_ACCESS_KEY_ID",
    "STRIPE_SECRET_KEY", "SENDGRID_API_KEY", "TWILIO_AUTH_TOKEN",
    "RAILWAY_TOKEN", "DOCKER_PASSWORD",
}

# ============================================================
# COMMAND BLOCKLIST — Patterns always denied (case-insensitive)
# Includes shell obfuscation countermeasures
# ============================================================
BLOCKED_COMMAND_PATTERNS = [
    # Destructive filesystem ops
    r"rm\s+(-\w+\s+)*-r",          # rm -rf, rm -r, rm --recursive
    r"rmdir\s+/s",                  # Windows rmdir /s
    r"del\s+/[sfq]",               # Windows del /s /f /q
    r"format\s+[a-z]:",            # format C:
    r"mkfs\b",                      # mkfs.*
    r"dd\s+if=",                    # dd if=
    # System disruption
    r"\bshutdown\b",
    r"\breboot\b",
    r"\binit\s+[06]\b",
    # Fork bombs / resource exhaustion
    r":\(\)\s*\{",                  # :(){ :|:& };:
    r"while\s+true.*fork",
    # Reverse shells / C2
    r"\bnc\s+-[elp]",              # netcat
    r"\bncat\b",
    r"reverse.?shell",
    r"bind.?shell",
    r"bash\s+-i\s+>&",             # bash -i >& /dev/tcp
    r"/dev/tcp/",
    # Credential harvesting
    r"\bprintenv\b",               # printenv
    r"\benv\b\s*$",                # bare 'env' to list all env vars
    r"\bset\b\s*$",                # bare 'set' to list all env vars (Windows)
    r"echo\s+\$\w*(KEY|SECRET|TOKEN|PASSWORD|URI|MONGO|REDIS|JWT)",
    r"echo\s+%\w*(KEY|SECRET|TOKEN|PASSWORD|URI|MONGO|REDIS|JWT)%",
    r"cat\s+.*\.(env|pem|key|crt|p12)",
    r"type\s+.*\.(env|pem|key|crt|p12)",
    # Package injection / supply chain
    r"curl\s+.*\|\s*(ba)?sh",      # curl | bash
    r"wget\s+.*\|\s*(ba)?sh",      # wget | sh
    r"pip\s+install\s+--index-url", # PyPI typosquat vector
    # Privilege escalation
    r"\bsudo\b",
    r"\bsu\s+-",
    r"\bchmod\s+[0-7]*7",          # world-writable
    r"\bchown\b",
]

COMPILED_BLOCKED = [re.compile(p, re.IGNORECASE) for p in BLOCKED_COMMAND_PATTERNS]

# File extensions that agents must never write to
PROTECTED_EXTENSIONS = {".env", ".pem", ".key", ".crt", ".p12", ".pfx", ".jks"}

# Directories agents cannot touch (relative to workspace root)
PROTECTED_DIRS = {".git", ".ssh", ".gnupg", "node_modules", "__pycache__", ".venv", "venv"}


class AgentToolsService:
    def __init__(self):
        self.settings = get_settings()
        # Default to the root of the project (one level up from backend)
        self.workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        logger.info(f"📁 Agent Workspace Root Initialized: {self.workspace_root}")

    # ============================================================
    # PATH SECURITY
    # ============================================================

    def _get_safe_path(self, relative_path: str) -> str:
        """Ensures the path is within the workspace root and not in a protected directory."""
        # Normalize to prevent path traversal via ../ or symlinks
        full_path = os.path.realpath(os.path.abspath(os.path.join(self.workspace_root, relative_path)))

        # Security: Prevent path traversal, including sibling-prefix paths.
        workspace_root = os.path.realpath(self.workspace_root)
        try:
            inside_workspace = (
                os.path.commonpath([os.path.normcase(workspace_root), os.path.normcase(full_path)])
                == os.path.normcase(workspace_root)
            )
        except ValueError:
            inside_workspace = False

        if not inside_workspace:
            logger.warning(f"🚨 [PATH TRAVERSAL] Blocked: {relative_path}")
            raise PermissionError(f"Access denied: path traversal detected.")

        # Security: Block protected directories
        path_parts = relative_path.replace("\\", "/").split("/")
        for part in path_parts:
            if part in PROTECTED_DIRS:
                logger.warning(f"🚨 [PROTECTED DIR] Blocked access to: {part}")
                raise PermissionError(f"Access denied: '{part}' is a protected directory.")

        return full_path

    def _check_protected_extension(self, path: str):
        """Blocks writes to sensitive file types and filenames."""
        basename = os.path.basename(path).lower()
        _, ext = os.path.splitext(path)

        # Block by extension
        if ext.lower() in PROTECTED_EXTENSIONS:
            logger.warning(f"🚨 [PROTECTED FILE] Blocked write to: {path}")
            raise PermissionError(f"Access denied: writing to '{ext}' files is prohibited.")

        # Block by exact filename (catches .env, .gitignore, etc.)
        protected_filenames = {".env", ".env.local", ".env.production", ".env.staging",
                               ".gitignore", ".npmrc", ".pypirc", "id_rsa", "id_ed25519",
                               ".htpasswd", ".htaccess", "shadow", "passwd"}
        if basename in protected_filenames:
            logger.warning(f"🚨 [PROTECTED FILE] Blocked write to protected filename: {basename}")
            raise PermissionError(f"Access denied: writing to '{basename}' is prohibited.")

    # ============================================================
    # COMMAND SECURITY
    # ============================================================

    def _sanitize_command(self, command: str) -> str:
        """
        Multi-layer command sanitization:
        1. Pattern blocklist matching
        2. Shell metacharacter neutralization for chained attacks
        """
        # Strip null bytes (common bypass technique)
        command = command.replace("\x00", "")

        # Check against compiled blocklist patterns
        for i, pattern in enumerate(COMPILED_BLOCKED):
            if pattern.search(command):
                blocked_desc = BLOCKED_COMMAND_PATTERNS[i]
                logger.warning(f"🚨 [COMMAND BLOCKED] Pattern '{blocked_desc}' matched in: {command[:80]}")
                raise PermissionError(f"Command blocked: matches dangerous pattern.")

        # Block command chaining that could bypass individual checks
        # Detect: cmd1 && cmd2, cmd1 || cmd2, cmd1 ; cmd2, cmd1 | cmd2 (pipe)
        # We allow single pipes for grep-like usage, but block double operators
        if re.search(r'[;&]|&&|\|\|', command):
            # Allow semicolons inside quoted strings (common in echo/printf)
            stripped = re.sub(r'"[^"]*"|\'[^\']*\'', '', command)
            if re.search(r'[;&]|&&|\|\|', stripped):
                logger.warning(f"🚨 [COMMAND CHAIN] Blocked chained command: {command[:80]}")
                raise PermissionError("Command blocked: command chaining is not permitted.")

        return command

    def _build_scrubbed_env(self) -> Dict[str, str]:
        """
        Creates a copy of the environment with all sensitive keys removed.
        This prevents agents from accessing secrets via subprocess inheritance.
        """
        clean_env = dict(os.environ)

        # Remove explicitly listed keys
        for key in SCRUBBED_ENV_KEYS:
            clean_env.pop(key, None)

        # Also scrub any key containing these substrings
        sensitive_substrings = ["_KEY", "_SECRET", "_TOKEN", "_PASSWORD", "_URI", "MONGO", "REDIS", "JWT"]
        keys_to_remove = [
            k for k in clean_env
            if any(sub in k.upper() for sub in sensitive_substrings)
        ]
        for k in keys_to_remove:
            del clean_env[k]

        return clean_env

    # ============================================================
    # FILE OPERATIONS
    # ============================================================

    async def write_file(self, path: str, content: str) -> Dict[str, Any]:
        """Creates or updates a file safely."""
        try:
            full_path = self._get_safe_path(path)
            self._check_protected_extension(path)

            # 1. Capture old content for diffing
            old_content = ""
            if os.path.exists(full_path):
                with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                    old_content = f.read()

            # 2. Write new content
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            with open(full_path, "w", encoding="utf-8") as f:
                f.write(content)

            # 3. Generate Unified Diff
            diff = ""
            if old_content:
                diff_lines = difflib.unified_diff(
                    old_content.splitlines(),
                    content.splitlines(),
                    fromfile=f"a/{path}",
                    tofile=f"b/{path}",
                    lineterm=""
                )
                diff = "\n".join(diff_lines)

            logger.info(f"💾 File written: {path} (Diff size: {len(diff)})")
            return {
                "status": "success",
                "path": path,
                "diff": diff,
                "is_new": not bool(old_content)
            }
        except PermissionError as e:
            logger.error(f"🚨 Write blocked: {e}")
            return {"status": "error", "message": str(e)}
        except Exception as e:
            logger.error(f"❌ Write error: {e}")
            return {"status": "error", "message": str(e)}

    async def read_file(self, path: str) -> Dict[str, Any]:
        """Reads content from a workspace file."""
        try:
            full_path = self._get_safe_path(path)
            if not os.path.exists(full_path):
                return {"status": "error", "message": f"File {path} does not exist."}

            with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
            return {"status": "success", "content": content}
        except PermissionError as e:
            return {"status": "error", "message": str(e)}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    async def list_files(self, path: str = ".") -> Dict[str, Any]:
        """Lists directory contents within the workspace."""
        try:
            full_path = self._get_safe_path(path)
            if not os.path.isdir(full_path):
                return {"status": "error", "message": f"{path} is not a directory."}

            items = []
            for item in os.listdir(full_path):
                # Skip hidden files and common ignore folders
                if item.startswith('.') or item in ['node_modules', 'build', '__pycache__']:
                    continue
                items.append(item)
            return {"status": "success", "items": items}
        except PermissionError as e:
            return {"status": "error", "message": str(e)}
        except Exception as e:
            return {"status": "error", "message": str(e)}

    # ============================================================
    # COMMAND EXECUTION (Hardened)
    # ============================================================

    async def run_command(self, command: str) -> Dict[str, Any]:
        """
        Executes a terminal command in the workspace root with:
        - Pattern-based command blocklist
        - Command chaining prevention
        - Environment secret scrubbing
        - Output size capping
        - Timeout enforcement
        """
        try:
            # Phase 1: Sanitize the command
            command = self._sanitize_command(command)

            # Phase 2: Build a scrubbed environment
            clean_env = self._build_scrubbed_env()

            # Redact command in logs (don't log raw user input verbatim)
            safe_log = command[:100] + ("..." if len(command) > 100 else "")
            logger.info(f"🐚 Agent command (sanitized): {safe_log}")

            # Phase 3: Execute with scrubbed env
            process = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.workspace_root,
                env=clean_env,
            )

            # Phase 4: Timeout enforcement
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            except asyncio.TimeoutError:
                process.kill()
                return {"status": "error", "message": "Command timed out after 30s"}

            # Phase 5: Cap output size to prevent memory bombs
            max_output = 50000  # 50KB max
            stdout_str = stdout.decode(errors="ignore")[:max_output]
            stderr_str = stderr.decode(errors="ignore")[:max_output]

            return {
                "status": "success",
                "stdout": stdout_str,
                "stderr": stderr_str,
                "exit_code": process.returncode
            }
        except PermissionError as e:
            logger.warning(f"🚨 Command denied: {e}")
            return {"status": "error", "message": str(e)}
        except Exception as e:
            logger.error(f"❌ Command failed: {e}")
            return {"status": "error", "message": str(e)}


# Singleton instance
agent_tools = AgentToolsService()
