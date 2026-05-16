import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.config import get_settings
from app.database import connect_to_mongo, close_mongo_connection
from app.routes import chat, history, upload, auth, execution
from app.services.socket_manager import manager as socket_manager
from app.logging_config import setup_logging
from app.middleware import production_security_middleware
from app.limiter import limiter

# Initialize Production Logging
setup_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: startup and shutdown."""
    import asyncio

    # Startup
    logger.info("🚀 Booting Code Genie Architecture...")

    settings = get_settings()
    os.makedirs(settings.ARTIFACTS_PATH, exist_ok=True)
    os.makedirs(settings.UPLOAD_PATH, exist_ok=True)

    # Initialize Database
    try:
        await connect_to_mongo()
        logger.info("✅ Database connected successfully.")
    except Exception as e:
        logger.error(f"❌ Database connection failed: {e}")

    # Mount artifacts directory (deferred to lifespan so errors are caught cleanly)
    logger.info(f"📁 Mounting artifacts from: {settings.ARTIFACTS_PATH}")
    try:
        if os.path.isdir(settings.ARTIFACTS_PATH):
            app.mount(
                "/artifacts",
                StaticFiles(directory=settings.ARTIFACTS_PATH),
                name="artifacts",
            )
            logger.info("✅ Artifacts directory mounted.")
        else:
            logger.warning(
                f"⚠️  Artifacts directory not found, skipping mount: {settings.ARTIFACTS_PATH}"
            )
    except Exception as e:
        logger.error(f"❌ Failed to mount artifacts directory: {e}")

    # Mount Flutter Web build (deferred to lifespan so errors are caught cleanly)
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    logger.info(f"🌐 Checking Flutter Web build at: {web_path}")
    try:
        if os.path.isdir(web_path):
            app.mount("/", StaticFiles(directory=web_path, html=True), name="web")
            logger.info(f"✅ Flutter Web mounted from: {web_path}")
        else:
            logger.warning(
                f"⚠️  Flutter Web directory not found, skipping mount: {web_path}"
            )
    except Exception as e:
        logger.error(f"❌ Failed to mount Flutter Web directory: {e}")

    # Start Heartbeat Task
    async def heartbeat():
        while True:
            await asyncio.sleep(30)
            await socket_manager.send_heartbeat()

    heartbeat_task = asyncio.create_task(heartbeat())
    logger.info("✅ Heartbeat system active.")

    logger.info("✅ Application fully initialized — ready to serve requests.")

    yield

    # Shutdown
    logger.info("🛑 Shutdown initiated.")
    heartbeat_task.cancel()
    await close_mongo_connection()


app = FastAPI(
    title="Code Genie API",
    description="Real-time AI coding assistant powered by Google Gemini",
    version="1.1.0",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# Rate Limiting
# ---------------------------------------------------------------------------
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ---------------------------------------------------------------------------
# Middlewares
# ---------------------------------------------------------------------------
# Security & Monitoring
app.middleware("http")(production_security_middleware)

# CORS (must be outermost layer)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:8000",
        "https://code-genie.up.railway.app",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# ---------------------------------------------------------------------------
# API Routes (registered before any catch-all static mount)
# ---------------------------------------------------------------------------

@app.get("/api/health")
async def health_check():
    """Detailed health check including database status."""
    from app.database import get_db
    db_status = "disconnected"
    try:
        db = await get_db()
        await db.command("ping")
        db_status = "connected"
    except Exception as e:
        logger.error(f"Healthcheck DB failure: {e}")

    return {
        "status": "healthy",
        "service": "Code Genie API",
        "database": db_status,
    }


@app.get("/api/ready")
async def readiness_check():
    """Lightweight readiness probe — returns 200 as soon as the app is up."""
    return {"status": "ok", "service": "Code Genie API"}


app.include_router(chat.router)
app.include_router(history.router)
app.include_router(upload.router)
app.include_router(auth.router)
app.include_router(execution.router)


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


# ---------------------------------------------------------------------------
# Flutter Web catch-all 404 handler
# (registered here so it is available regardless of whether the static mount
#  succeeded; the actual mount happens inside lifespan above)
# ---------------------------------------------------------------------------

@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    """Serve Flutter Web index.html for unknown paths; return JSON for API routes."""
    api_prefixes = ("/api", "/ws", "/docs", "/redoc", "/openapi.json", "/artifacts")
    if any(request.url.path.startswith(p) for p in api_prefixes):
        return JSONResponse(
            status_code=404,
            content={"detail": f"Route not found: {request.url.path}"},
        )
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    index = os.path.join(web_path, "index.html")
    if os.path.isfile(index):
        return FileResponse(index)
    return JSONResponse(status_code=404, content={"detail": "Not found"})


# ---------------------------------------------------------------------------
# Direct entrypoint
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
