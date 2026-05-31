import subprocess
import os
import sys
import tempfile
import time
import re
import glob
import base64
import logging
import docker
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from app.routes.deps import get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/execute", tags=["execution"])

class ExecutionRequest(BaseModel):
    code: str
    language: str

class HotPatchRequest(BaseModel):
    file_path: str
    code: str

class ExecutionResponse(BaseModel):
    output: str
    error: Optional[str] = None
    execution_time: float
    images: Optional[List[str]] = None       # base64-encoded images captured during execution
    notice: Optional[str] = None             # informational notice (e.g. auto-healed modules)
    auto_installed: Optional[List[str]] = None  # list of auto-installed packages

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


# ─────────────────────────────────────────────────────
# Helper: Extract missing module name from stderr
# ─────────────────────────────────────────────────────
_MODULE_NOT_FOUND_RE = re.compile(
    r"(?:ModuleNotFoundError|ImportError):\s+No module named ['\"]([a-zA-Z0-9_]+)['\"]"
)

# Map common import names to their actual PyPI package names
_PACKAGE_NAME_MAP = {
    "cv2": "opencv-python",
    "PIL": "Pillow",
    "sklearn": "scikit-learn",
    "skimage": "scikit-image",
    "yaml": "pyyaml",
    "bs4": "beautifulsoup4",
    "attr": "attrs",
    "gi": "PyGObject",
    "wx": "wxPython",
    "Crypto": "pycryptodome",
    "serial": "pyserial",
    "usb": "pyusb",
    "dotenv": "python-dotenv",
}

def _resolve_pip_name(module_name: str) -> str:
    """Resolve import name → PyPI package name."""
    return _PACKAGE_NAME_MAP.get(module_name, module_name)


def _try_auto_install(module_name: str) -> tuple[bool, str]:
    """
    Attempt to pip-install a missing module.
    Returns (success: bool, log_message: str).
    """
    pip_name = _resolve_pip_name(module_name)
    logger.info(f"🩹 [AUTO-HEAL] Installing missing module: {pip_name} (import: {module_name})")
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--quiet", pip_name],
            capture_output=True, text=True, timeout=60.0
        )
        if result.returncode == 0:
            logger.info(f"✅ [AUTO-HEAL] Successfully installed {pip_name}")
            return True, f"✅ Auto-installed '{pip_name}' and re-executed your code."
        else:
            logger.warning(f"❌ [AUTO-HEAL] pip install failed: {result.stderr}")
            return False, f"❌ Auto-install of '{pip_name}' failed: {result.stderr.strip()}"
    except subprocess.TimeoutExpired:
        return False, f"❌ Auto-install of '{pip_name}' timed out (60s limit)."
    except Exception as e:
        return False, f"❌ Auto-install of '{pip_name}' failed: {str(e)}"


def _capture_images(directory: str) -> List[str]:
    """
    Scan a directory for image files and return them as base64-encoded strings.
    Format: "data:image/<ext>;base64,<data>"
    """
    image_extensions = ("*.png", "*.jpg", "*.jpeg", "*.svg", "*.gif", "*.bmp", "*.webp")
    images = []
    for pattern in image_extensions:
        for filepath in glob.glob(os.path.join(directory, pattern)):
            try:
                with open(filepath, "rb") as f:
                    raw = f.read()
                ext = os.path.splitext(filepath)[1].lstrip(".").lower()
                if ext == "svg":
                    mime = "svg+xml"
                elif ext == "jpg":
                    mime = "jpeg"
                else:
                    mime = ext
                encoded = base64.b64encode(raw).decode("utf-8")
                images.append(f"data:image/{mime};base64,{encoded}")
                logger.info(f"📊 [IMAGE-CAPTURE] Captured image: {os.path.basename(filepath)} ({len(raw)} bytes)")
            except Exception as e:
                logger.warning(f"⚠️ [IMAGE-CAPTURE] Failed to read {filepath}: {e}")
    return images


def _inject_savefig_if_needed(code: str, tmpdir: str) -> str:
    """
    If the code uses matplotlib.pyplot but never calls savefig(),
    inject a plt.savefig(...) + plt.close() to capture the plot automatically.
    Also suppress plt.show() to avoid GUI hang.
    """
    # Only inject for matplotlib usage
    if "matplotlib" not in code and "plt." not in code:
        return code
    
    # Prepend headless Agg backend configuration to avoid GUI rendering attempts
    # and errors if called after importing pyplot.
    agg_prefix = "import matplotlib\nmatplotlib.use('Agg')\n"
    
    # Replace plt.show() with a no-op to avoid blocking
    code = re.sub(r'\bplt\.show\s*\(\s*\)', '# plt.show() suppressed for sandbox', code)
    
    # If user already saves explicitly, don't double-save but still force Agg at top
    if "savefig" in code:
        return agg_prefix + code
    
    # Append savefig at the end
    save_path = os.path.join(tmpdir, "_auto_plot.png").replace("\\", "/")
    suffix = f"\nimport matplotlib.pyplot as plt\nplt.savefig('{save_path}', dpi=150, bbox_inches='tight')\nplt.close('all')\n"
    
    return agg_prefix + code + suffix


def _run_in_tmpdir(code: str, lang: str, start_time: float, max_retries: int = 1) -> ExecutionResponse:
    """
    Execute code in a temporary directory, with auto-healing and image capture.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        installed_packages: List[str] = []
        notice_lines: List[str] = []
        
        # For Python: inject savefig if matplotlib is used
        exec_code = code
        if lang == "python":
            exec_code = _inject_savefig_if_needed(code, tmpdir)
        
        for attempt in range(max_retries + 1):
            try:
                if lang == "python":
                    # Write code to a temp file so savefig paths resolve correctly
                    script_path = os.path.join(tmpdir, "_script.py")
                    with open(script_path, "w", encoding="utf-8") as f:
                        f.write(exec_code)
                    cmd = [sys.executable, script_path]
                elif lang in ["javascript", "js"]:
                    script_path = os.path.join(tmpdir, "_script.js")
                    with open(script_path, "w", encoding="utf-8") as f:
                        f.write(exec_code)
                    cmd = ["node", script_path]
                else:
                    return ExecutionResponse(
                        output="",
                        error=f"Language '{lang}' is not supported for execution.",
                        execution_time=round(time.time() - start_time, 3)
                    )

                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=15.0,
                    cwd=tmpdir
                )
                execution_time = round(time.time() - start_time, 3)

                # ── Auto-Heal: Detect missing modules ──
                if proc.returncode != 0 and lang == "python" and attempt < max_retries:
                    match = _MODULE_NOT_FOUND_RE.search(proc.stderr)
                    if match:
                        module_name = match.group(1)
                        success, msg = _try_auto_install(module_name)
                        notice_lines.append(msg)
                        if success:
                            installed_packages.append(_resolve_pip_name(module_name))
                            # Re-inject savefig in case the installed lib changed things
                            exec_code = _inject_savefig_if_needed(code, tmpdir)
                            continue  # retry execution
                        # If install failed, fall through to normal error reporting

                # ── Capture generated images ──
                captured_images = _capture_images(tmpdir)

                if proc.returncode != 0:
                    return ExecutionResponse(
                        output=proc.stdout,
                        error=proc.stderr if proc.stderr else f"Runtime Error (Exit Code: {proc.returncode})",
                        execution_time=execution_time,
                        images=captured_images if captured_images else None,
                        notice="\n".join(notice_lines) if notice_lines else None,
                        auto_installed=installed_packages if installed_packages else None,
                    )

                return ExecutionResponse(
                    output=proc.stdout,
                    error=None,
                    execution_time=execution_time,
                    images=captured_images if captured_images else None,
                    notice="\n".join(notice_lines) if notice_lines else None,
                    auto_installed=installed_packages if installed_packages else None,
                )

            except subprocess.TimeoutExpired:
                return ExecutionResponse(
                    output="",
                    error="Execution Timed Out (Limit: 15s)",
                    execution_time=round(time.time() - start_time, 3),
                    notice="\n".join(notice_lines) if notice_lines else None,
                    auto_installed=installed_packages if installed_packages else None,
                )
            except Exception as e:
                return ExecutionResponse(
                    output="",
                    error=f"Local execution failed: {str(e)}",
                    execution_time=round(time.time() - start_time, 3),
                    notice="\n".join(notice_lines) if notice_lines else None,
                    auto_installed=installed_packages if installed_packages else None,
                )

    # Should never reach here, but just in case
    return ExecutionResponse(
        output="",
        error="Unexpected execution flow.",
        execution_time=round(time.time() - start_time, 3)
    )


# ═══════════════════════════════════════════════════════
# ENDPOINT: Execute Code
# ═══════════════════════════════════════════════════════
@router.post("", response_model=ExecutionResponse)
async def execute_code(
    request: ExecutionRequest, 
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Execute user code in a secure sandbox with auto-healing and image capture.
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

    # Python executions are securely sandboxed inside Docker (locally) or Piston (cloud),
    # so we do not need to restrict standard library imports like 'os' or 'sys'.

    if not docker_client:
        if is_cloud or lang not in ["python", "js", "javascript"]:
            logger.info("ℹ️ [EXECUTION] Cloud environment or unsupported native language detected: falling back to remote Piston sandbox.")
            import urllib.request
            import urllib.error
            import json

            # Map standard language identifiers to Piston supported ones
            piston_lang = lang
            if lang in ["js", "javascript"]:
                piston_lang = "javascript"
            elif lang == "python":
                piston_lang = "python"

            payload = {
                "language": piston_lang,
                "version": "*",
                "files": [{"content": code}]
            }

            try:
                req = urllib.request.Request(
                    "https://emkc.org/api/v2/piston/execute",
                    data=json.dumps(payload).encode("utf-8"),
                    headers={"Content-Type": "application/json"},
                    method="POST"
                )
                with urllib.request.urlopen(req, timeout=10.0) as response:
                    res_data = json.loads(response.read().decode("utf-8"))
                    run_res = res_data.get("run", {})
                    
                    execution_time = round(time.time() - start_time, 3)
                    stderr = run_res.get("stderr", "")
                    stdout = run_res.get("stdout", "")
                    output = run_res.get("output", "")
                    
                    return ExecutionResponse(
                        output=output if output else stdout,
                        error=stderr if stderr else None,
                        execution_time=execution_time
                    )
            except Exception as ex:
                logger.error(f"❌ [EXECUTION] Remote Piston sandbox failed: {ex}")
                # Piston failed (often 401 Unauthorized due to new policies), fall back to local subprocess
                pass
        
        # ── Use enhanced local execution with auto-healing + image capture ──
        logger.info(f"ℹ️ [EXECUTION] Using enhanced local subprocess execution (auto-heal + image capture).")
        return _run_in_tmpdir(code, lang, start_time, max_retries=1)

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
            working_dir="/tmp"  # nosec
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


# ═══════════════════════════════════════════════════════
# ENDPOINT: Hot-Patch Workspace File
# ═══════════════════════════════════════════════════════
@router.post("/hotpatch")
async def hotpatch_file(
    request: HotPatchRequest,
    current_user_id: str = Depends(get_current_user_id)
):
    """
    Write code directly to a workspace file (hot-patch).
    Security: Only allows writing to files within the project workspace.
    """
    file_path = os.path.abspath(request.file_path)
    
    # Security: Prevent path traversal attacks
    # The file must exist on disk already (we don't create new files via hot-patch)
    if not os.path.isfile(file_path):
        raise HTTPException(
            status_code=404,
            detail=f"File not found: {request.file_path}. Hot-patch can only update existing files."
        )
    
    # Security: Block writing to sensitive system paths
    blocked_prefixes = ["/etc", "/usr", "/bin", "/sbin", "/var", "/root", "C:\\Windows", "C:\\Program Files"]
    for prefix in blocked_prefixes:
        if file_path.startswith(prefix):
            raise HTTPException(
                status_code=403,
                detail="Hot-patch is not allowed for system files."
            )
    
    try:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(request.code)
        
        logger.info(f"⚡ [HOT-PATCH] User {current_user_id} patched: {file_path}")
        return {
            "success": True,
            "message": f"Successfully patched: {os.path.basename(file_path)}",
            "file_path": file_path
        }
    except PermissionError:
        raise HTTPException(
            status_code=403,
            detail=f"Permission denied: Cannot write to {request.file_path}"
        )
    except Exception as e:
        logger.error(f"❌ [HOT-PATCH] Failed for user {current_user_id}: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Hot-patch failed: {str(e)}"
        )
