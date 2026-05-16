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

# Initialize Docker client
try:
    docker_client = docker.from_env()
    logger.info("✅ Docker client initialized for secure code execution.")
except Exception as e:
    # Railway/Cloud detection
    is_cloud = os.getenv("RAILWAY_ENVIRONMENT") or os.getenv("DYNO")
    if is_cloud:
        logger.info("ℹ️ Code execution sandbox: Using native mode (Docker unavailable in cloud container).")
    else:
        logger.warning(f"⚠️ Docker not available: {e}. Falling back to insecure execution (DEV ONLY).")
    docker_client = None

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
    
    if not docker_client:
        return ExecutionResponse(
            output="",
            error="Runtime Error: Docker sandbox is not initialized. Execution blocked for security.",
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
