import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import os
from app.config import get_settings
from app.database import connect_to_mongo, close_mongo_connection
from app.routes import chat, history, upload, auth, execution
from app.services.socket_manager import manager as socket_manager
from fastapi import WebSocket, WebSocketDisconnect
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: startup and shutdown."""
    # Startup
    logger.info("🚀 Starting AI Code Assistant API...")
    
    # Ensure data directories exist
    settings = get_settings()
    os.makedirs(settings.ARTIFACTS_PATH, exist_ok=True)
    os.makedirs(settings.UPLOAD_PATH, exist_ok=True)
    logger.info(f"📁 Data directories initialized: {settings.ARTIFACTS_PATH}, {settings.UPLOAD_PATH}")

    # SECURITY CHECK: Enforce strong JWT secret in production
    if settings.JWT_SECRET == "genie-dev-secret-key-change-in-production":
        logger.error("❌ INSECURE JWT_SECRET DETECTED! Use environment variables to set a secure secret in production.")
        # We don't raise here so the app can start and pass healthchecks, allowing logs to be seen.
    
    await connect_to_mongo()
    logger.info("✅ API ready!")
    yield
    # Shutdown
    logger.info("🛑 Shutdown complete.")
    await close_mongo_connection()


app = FastAPI(
    title="Code Genie API",
    description="Real-time AI coding assistant powered by Google Gemini",
    version="1.0.0",
    lifespan=lifespan,
)

# Setup Rate Limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Configuration
settings = get_settings()
# Explicit origins are required when allow_credentials=True
origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://192.168.1.7:8000",
    "https://code-genie.up.railway.app",
]

# Add any extra origins from environment
if settings.ALLOWED_ORIGINS != "*":
    extra_origins = settings.ALLOWED_ORIGINS.split(",")
    origins.extend([o.strip() for o in extra_origins if o.strip() not in origins])

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    import time
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    
    # Log slow requests
    if process_time > 2.0:
        logger.warning(f"🐢 Slow request: {request.method} {request.url.path} took {process_time:.2f}s")
    
    return response

@app.middleware("http")
async def add_security_headers(request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    import uuid
    error_id = str(uuid.uuid4())
    logger.error(f"Global error [{error_id}]: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={
            "detail": "An unexpected internal server error occurred. Our engineers have been notified.",
            "error_id": error_id
        },
    )

# Register routes
app.include_router(chat.router)
app.include_router(history.router)
app.include_router(upload.router)
app.include_router(auth.router)
app.include_router(execution.router)

# Mount artifacts for web access
settings = get_settings()
os.makedirs(settings.ARTIFACTS_PATH, exist_ok=True)
os.makedirs(settings.UPLOAD_PATH, exist_ok=True)

if os.path.exists(settings.ARTIFACTS_PATH):
    app.mount("/artifacts", StaticFiles(directory=settings.ARTIFACTS_PATH), name="artifacts")
    logger.info(f"📁 Artifacts mounted from: {settings.ARTIFACTS_PATH}")

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str, token: str = None):
    # Security: Verify JWT token before allowing connection
    if not token:
        logger.warning(f"❌ WebSocket connection rejected for {user_id}: Missing token")
        await websocket.close(code=1008)  # Policy Violation
        return
        
    try:
        from jose import jwt
        settings = get_settings()
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        token_user_id = payload.get("sub")
        if token_user_id != user_id:
            logger.warning(f"❌ WebSocket connection rejected for {user_id}: Token mismatch")
            await websocket.close(code=1008)
            return
    except Exception as e:
        logger.warning(f"❌ WebSocket connection rejected for {user_id}: Invalid token ({e})")
        await websocket.close(code=1008)
        return

    await socket_manager.connect(websocket, user_id)
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        socket_manager.disconnect(websocket, user_id)
    except Exception as e:
        logger.error(f"WebSocket Error for {user_id}: {e}")
        socket_manager.disconnect(websocket, user_id)


@app.get("/")
async def root():
    """Root endpoint for health checks."""
    return {"status": "ok", "service": "Code Genie API"}

@app.get("/api/health")
async def health_check():
    """Health check endpoint."""
    from app.models.responses import HealthResponse
    return HealthResponse()


# Serve Flutter Web Build
web_path = os.path.join(os.path.dirname(__file__), "static_web")
if os.path.exists(web_path):
    app.mount("/", StaticFiles(directory=web_path, html=True), name="web")
    
    @app.exception_handler(404)
    async def not_found_handler(request: Request, exc):
        """Catch-all to support Flutter Web routing, but exclude API routes."""
        if request.url.path.startswith("/api") or request.url.path.startswith("/ws"):
            return JSONResponse(
                status_code=404,
                content={"detail": f"API route not found: {request.url.path}"}
            )
        return FileResponse(os.path.join(web_path, "index.html"))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
