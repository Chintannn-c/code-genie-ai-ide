import os
import subprocess
import asyncio
import logging
import difflib
from typing import Dict, Any, List
from app.config import get_settings

logger = logging.getLogger(__name__)

class AgentToolsService:
    def __init__(self):
        self.settings = get_settings()
        # Default to the root of the project (one level up from backend)
        self.workspace_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        logger.info(f"📁 Agent Workspace Root Initialized: {self.workspace_root}")

    def _get_safe_path(self, relative_path: str) -> str:
        """Ensures the path is within the workspace root."""
        # Convert to absolute path
        full_path = os.path.abspath(os.path.join(self.workspace_root, relative_path))
        
        # Security: Prevent path traversal
        if not full_path.startswith(self.workspace_root):
            logger.warning(f"🚨 Security Violation: Attempted access to {relative_path}")
            raise PermissionError(f"Access denied: {relative_path} is outside workspace.")
        return full_path

    async def write_file(self, path: str, content: str) -> Dict[str, Any]:
        """Creates or updates a file safely."""
        try:
            full_path = self._get_safe_path(path)
            
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
        except Exception as e:
            return {"status": "error", "message": str(e)}

    async def run_command(self, command: str) -> Dict[str, Any]:
        """Executes a terminal command in the workspace root."""
        try:
            logger.info(f"🐚 Agent running command: {command}")
            # Use asyncio for non-blocking command execution
            process = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=self.workspace_root
            )
            
            # Set a timeout for safety
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            except asyncio.TimeoutError:
                process.kill()
                return {"status": "error", "message": "Command timed out after 30s"}
                
            return {
                "status": "success",
                "stdout": stdout.decode(errors="ignore"),
                "stderr": stderr.decode(errors="ignore"),
                "exit_code": process.returncode
            }
        except Exception as e:
            logger.error(f"❌ Command failed: {e}")
            return {"status": "error", "message": str(e)}

# Singleton instance
agent_tools = AgentToolsService()
