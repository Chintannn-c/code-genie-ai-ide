import subprocess
import os
import tempfile
import time
import re
import logging
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

@router.post("", response_model=ExecutionResponse)
async def execute_code(
    request: ExecutionRequest, 
    current_user_id: str = Depends(get_current_user_id) # SECURITY FIX: Authentication required
):
    """
    Execute user code in a semi-sandboxed subprocess.
    SECURITY HARDENING: Strict auth, environment scrubbing, and pattern detection.
    """
    lang = request.language.lower()
    code = request.code
    start_time = time.time()
    
    # SECURITY FIX: Extensive pattern detection for sandbox escape attempts
    # We check for obfuscated imports, system calls, and reflective execution
    forbidden_patterns = [
        r"os\.(system|popen|remove|chmod|chown)", 
        r"subprocess\.", 
        r"shutil\.", 
        r"getattr\(", 
        r"__import__", 
        r"exec\(", 
        r"eval\(", 
        r"globals\(", 
        r"locals\(",
        r"builtins\.",
        r"pty\.",
        r"socket\.",
        r"requests\.",
        r"urllib\.",
        r"pickle\.",
        r"marshal\."
    ]
    
    for pattern in forbidden_patterns:
        if re.search(pattern, code):
            logger.warning(f"SECURITY VIOLATION: User {current_user_id} attempted blocked pattern '{pattern}'")
            return ExecutionResponse(
                output="",
                error=f"Security Violation: Pattern detection blocked this execution. Access to system modules is restricted.",
                execution_time=round(time.time() - start_time, 3)
            )

    # SECURITY FIX: Absolute environment scrubbing. 
    # Only allow minimal, non-sensitive environment variables.
    safe_env = {
        "PATH": "/usr/bin:/bin", # Restricted path
        "LANG": "en_US.UTF-8",
        "PYTHONIOENCODING": "utf-8",
    }
    
    # SMART INTERPRETER DETECTION: Use python3 on Linux (Railway) and python on Windows
    python_cmd = "python3" if os.name != "nt" else "python"
    
    runtimes = {
        "python": [python_cmd, "-c", code],
        "javascript": ["node", "-e", code],
        "js": ["node", "-e", code],
    }

    try:
        if lang in runtimes:
            # SECURITY FIX: Subprocess hardening with strict timeouts and pipe isolation
            process = subprocess.Popen(
                runtimes[lang],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env=safe_env,
                start_new_session=True # Isolate from parent process group
            )
            try:
                stdout, stderr = process.communicate(timeout=5.0) # Reduced timeout for safety
            except subprocess.TimeoutExpired:
                process.kill()
                stdout, stderr = "", "Execution Timed Out (Limit: 5s)"
        
        elif lang == "java":
            with tempfile.TemporaryDirectory() as tmpdir:
                match = re.search(r'public\s+class\s+(\w+)', code)
                class_name = match.group(1) if match else "Main"
                
                file_path = os.path.join(tmpdir, f"{class_name}.java")
                with open(file_path, "w") as f:
                    f.write(code)
                
                # Compilation step
                compile_proc = subprocess.run(
                    ["javac", f"{class_name}.java"],
                    cwd=tmpdir,
                    capture_output=True,
                    text=True,
                    env=safe_env,
                    timeout=10.0
                )
                
                if compile_proc.returncode != 0:
                    execution_time = round(time.time() - start_time, 3)
                    return ExecutionResponse(output="", error=compile_proc.stderr, execution_time=execution_time)
                
                # Execution step
                run_proc = subprocess.run(
                    ["java", class_name],
                    cwd=tmpdir,
                    capture_output=True,
                    text=True,
                    env=safe_env,
                    timeout=5.0
                )
                stdout, stderr = run_proc.stdout, run_proc.stderr
        else:
            raise HTTPException(status_code=400, detail=f"Language {lang} not supported for execution.")

        execution_time = round(time.time() - start_time, 3)
        return ExecutionResponse(
            output=stdout,
            error=stderr if stderr.strip() else None,
            execution_time=execution_time
        )
        
    except Exception as e:
        logger.error(f"Execution failed for user {current_user_id}: {e}")
        execution_time = round(time.time() - start_time, 3)
        return ExecutionResponse(
            output="",
            error=f"Runtime Error: {str(e)}",
            execution_time=execution_time
        )
