import subprocess
import os
import tempfile
import time
import re
import logging
import docker
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from app.routes.deps import get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/execute", tags=["execution"])

class ExecutionRequest(BaseModel):
    code: str
    language: str

class ExecutionResponse(BaseModel):
    output: str
    error: Optional[str] = None
    execution_time: float

# Initialize Docker client (Skip in cloud/remote environments)
docker_client = None
# Robust cloud detection
is_cloud = any([
    os.getenv("RAILWAY_ENVIRONMENT"),
    os.getenv("RAILWAY_PROJECT_ID"),
    os.getenv("DYNO"),           # Heroku
    os.getenv("K_SERVICE"),      # Google Cloud Run
    os.environ.get("PORT") and not os.environ.get("LOCAL_DEV") # General cloud heuristic
])

if not is_cloud:
    try:
        docker_client = docker.from_env()
        logger.info("✅ [EXECUTION] Docker client initialized for secure sandbox.")
    except Exception as e:
        logger.warning(f"⚠️ [EXECUTION] Docker not found: {e}. Falling back to insecure mode (DEV ONLY).")
else:
    logger.info("ℹ️ [EXECUTION] Remote/Cloud environment detected: Skipping Docker initialization (native mode active).")

@router.post("", response_model=ExecutionResponse)
async def execute_code(
    request: ExecutionRequest, 
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Execute user code in a secure Docker container.
    """
    lang = request.language.lower()
    code = request.code
    start_time = time.time()

    # Security: Code size limit (prevent resource exhaustion)
    MAX_CODE_SIZE = 10240  # 10KB
    if len(code) > MAX_CODE_SIZE:
        return ExecutionResponse(
            output="",
            error=f"Code size ({len(code)} bytes) exceeds the {MAX_CODE_SIZE} byte limit.",
            execution_time=round(time.time() - start_time, 3)
        )

    # Security: Reject null bytes and control characters
    if "\x00" in code:
        return ExecutionResponse(
            output="",
            error="Code contains invalid null bytes.",
            execution_time=round(time.time() - start_time, 3)
        )

    if not docker_client:
        logger.warning(f"🚨 [EXECUTION] Blocked: User {current_user_id} attempted code execution without Docker sandbox.")
        return ExecutionResponse(
            output="",
            error="Security: Code execution requires Docker sandbox. Execution blocked in this environment.",
            execution_time=round(time.time() - start_time, 3)
        )

    # Map languages to Docker images and commands
    config = {
        "python": {
            "image": "python:3.11-alpine",
            "command": ["python", "-c", code],
        },
        "javascript": {
            "image": "node:18-alpine",
            "command": ["node", "-e", code],
        },
        "js": {
            "image": "node:18-alpine",
            "command": ["node", "-e", code],
        }
    }

    if lang not in config:
        return ExecutionResponse(
            output="",
            error=f"Language '{lang}' is not supported for secure execution.",
            execution_time=round(time.time() - start_time, 3)
        )

    try:
        # Create and run container with strict resource limits
        container = docker_client.containers.run(
            image=config[lang]["image"],
            command=config[lang]["command"],
            network_disabled=True,      # No internet access
            mem_limit="128m",           # Max 128MB RAM
            cpu_period=100000,
            cpu_quota=50000,            # 0.5 CPU core limit
            stderr=True,
            stdout=True,
            detach=True,
            remove=True,                # Auto-remove after finish
            user="nobody",              # Run as non-root
            working_dir="/tmp"
        )

        # Wait for completion or timeout
        exit_code = 0
        try:
            # wait() returns a dict with 'StatusCode'
            result = container.wait(timeout=5.0)
            exit_code = result.get('StatusCode', 0)
            logs = container.logs().decode('utf-8')
        except Exception:
            container.kill()
            return ExecutionResponse(
                output="",
                error="Execution Timed Out (Limit: 5s)",
                execution_time=round(time.time() - start_time, 3)
            )

        execution_time = round(time.time() - start_time, 3)
        
        if exit_code != 0:
            return ExecutionResponse(
                output="",
                error=logs if logs else f"Runtime Error (Exit Code: {exit_code})",
                execution_time=execution_time
            )

        return ExecutionResponse(
            output=logs,
            error=None,
            execution_time=execution_time
        )
        
    except Exception as e:
        logger.error(f"Docker Execution failed for user {current_user_id}: {e}")
        return ExecutionResponse(
            output="",
            error=f"Infrastructure Error: {str(e)}",
            execution_time=round(time.time() - start_time, 3)
        )
