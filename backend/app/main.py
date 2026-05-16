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
from app.logging_config import setup_logging
from app.middleware import ProductionSecurityMiddleware
from fastapi import WebSocket, WebSocketDisconnect
from starlette.middleware.base import BaseHTTPMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter

# Initialize Production Logging
setup_logging()
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: startup and shutdown."""
    logger.info("🚩 [STARTUP] Phase 1: Initializing Lifecycle...")
    
    settings = get_settings()
    
    # --- NON-BLOCKING BACKGROUND INIT ---
    async def initialize_infrastructure():
        # 1. Database Connection
        try:
            logger.info(f"🚩 [STARTUP] Background: Connecting to MongoDB (DB: {settings.DB_NAME})...")
            await connect_to_mongo()
            logger.info("✅ [STARTUP] MongoDB Connection: SUCCESS")
        except Exception as e:
            logger.error(f"❌ [STARTUP] MongoDB Connection: FAILED - {e}")

        # 2. Redis Connection
        if settings.REDIS_URL:
            try:
                logger.info("🚩 [STARTUP] Background: Connecting to Redis...")
                import redis.asyncio as redis
                r = redis.from_url(settings.REDIS_URL, socket_timeout=5.0)
                await r.ping()
                logger.info("✅ [STARTUP] Redis Connection: SUCCESS")
                app.state.redis = r
            except Exception as e:
                logger.warning(f"⚠️ [STARTUP] Redis Connection: OPTIONAL FAILURE - {e}")
                app.state.redis = None
        else:
            app.state.redis = None

        # 3. Directories
        try:
            os.makedirs(settings.ARTIFACTS_PATH, exist_ok=True)
            os.makedirs(settings.UPLOAD_PATH, exist_ok=True)
            logger.info("✅ [STARTUP] Directories verified.")
        except Exception as e:
            logger.error(f"❌ [STARTUP] Directory creation: FAILED - {e}")

    # Start initialization in background
    asyncio.create_task(initialize_infrastructure())

    # 4. Background Tasks
    logger.info("🚩 [STARTUP] Phase 5: Starting Background Workers...")
    import asyncio
    async def heartbeat():
        try:
            while True:
                await asyncio.sleep(30)
                await socket_manager.send_heartbeat()
        except asyncio.CancelledError:
            pass
    
    heartbeat_task = asyncio.create_task(heartbeat())
    logger.info("✅ [STARTUP] Heartbeat system: ACTIVE")

    logger.info("🚀 [STARTUP] COMPLETE: Application fully initialized - ready to serve requests.")
    yield
    # Shutdown
    logger.info("🛑 [SHUTDOWN] Cleanup initiated.")
    heartbeat_task.cancel()
    await close_mongo_connection()
    logger.info("🛑 [SHUTDOWN] Finished.")


app = FastAPI(
    title="Code Genie API",
    description="Real-time AI coding assistant powered by Google Gemini",
    version="1.1.0",
    lifespan=lifespan,
)

# 1. Immediate Health Check (High Priority & Non-Blocking)
@app.get("/api/health")
async def health_check():
    """Lightweight health check for Railway."""
    return {
        "status": "healthy",
        "service": "Code Genie API",
        "timestamp": os.environ.get("RAILWAY_DEPLOY_TIMESTAMP", "local")
    }

@app.get("/api/health/detailed")
async def detailed_health_check():
    """Deep health check for manual diagnostics."""
    from app.database import get_db
    db_status = "disconnected"
    try:
        db = await get_db()
        await db.command("ping")
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {e}"

    return {
        "status": "online",
        "database": db_status,
        "redis": "connected" if hasattr(app.state, 'redis') and app.state.redis else "not_configured"
    }

@app.get("/")
async def root(request: Request):
    """Serve SPA index or API status."""
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    index_path = os.path.join(web_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"status": "ok", "service": "Code Genie API", "message": "SPA Index not found"}

# 2. Rate Limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# 3. Middlewares
# Security & Monitoring (Using pure ASGI middleware to support file uploads)
app.add_middleware(ProductionSecurityMiddleware)

# CORS (Must be outer layer)
settings = get_settings()
origins = [o.strip() for o in settings.ALLOWED_ORIGINS.split(",")] if settings.ALLOWED_ORIGINS != "*" else ["*"]

# Also include defaults for local dev
if "*" not in origins:
    origins.extend(["http://localhost", "http://localhost:8000"])

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Register routes
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

# Exception Handlers
@app.exception_handler(404)
async def not_found_handler(request: Request, exc):
    """Catch-all to support Flutter Web routing, but exclude API and Docs."""
    # 1. API/Docs should return JSON 404
    if any(request.url.path.startswith(p) for p in ["/api", "/ws", "/docs", "/redoc", "/openapi.json"]):
        return JSONResponse(
            status_code=404,
            content={"detail": f"Route not found: {request.url.path}"}
        )
    
    # 2. Check if it's a static file request
    # Flutter Web builds place assets, main.dart.js, etc. in the static_web folder
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    path = request.url.path.lstrip("/")
    
    if path:
        static_file = os.path.join(web_path, path)
        if os.path.isfile(static_file):
            return FileResponse(static_file)

    # 3. Default to SPA index for root or client-side routes
    index_path = os.path.join(web_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
        
    return JSONResponse(status_code=404, content={"detail": "Resource not found"})


# 4. Static File Mounting (Initial placeholders)
# These remain at module level for routing, but the directories are ensured in lifespan
try:
    app.mount("/artifacts", StaticFiles(directory=settings.ARTIFACTS_PATH), name="artifacts")
    logger.info(f"📁 Artifacts route registered")
except Exception as e:
    logger.warning(f"⚠️ Initial mounting warning (expected if dir missing): {e}")

logger.info("🚀 Code Genie Module Loaded Successfully")

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    logger.info(f"Starting production server on port {port}")
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
