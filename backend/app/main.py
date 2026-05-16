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
from app.middleware import production_security_middleware
from fastapi import WebSocket, WebSocketDisconnect
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from app.limiter import limiter

# Initialize Production Logging
setup_logging()
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle: startup and shutdown."""
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

    # Start Heartbeat Task
    import asyncio
    async def heartbeat():
        while True:
            await asyncio.sleep(30)
            await socket_manager.send_heartbeat()
    
    heartbeat_task = asyncio.create_task(heartbeat())
    logger.info("✅ Heartbeat system active.")

    # Static File Mounting (Moved to lifespan to prevent startup hangs)
    try:
        if os.path.exists(settings.ARTIFACTS_PATH):
            app.mount("/artifacts", StaticFiles(directory=settings.ARTIFACTS_PATH), name="artifacts")
            logger.info(f"📁 Artifacts mounted from: {settings.ARTIFACTS_PATH}")
        else:
            logger.warning(f"⚠️ Artifacts path not found: {settings.ARTIFACTS_PATH}")

        web_path = os.path.join(os.path.dirname(__file__), "static_web")
        if os.path.exists(web_path):
            logger.info(f"🌐 Flutter Web detected at: {web_path}")
            # Mount without html=True to avoid greedy root shadowing
            app.mount("/web_static", StaticFiles(directory=web_path), name="web_static")
        else:
            logger.warning(f"⚠️ Flutter Web build not found at: {web_path}")

    except Exception as e:
        logger.error(f"❌ Static files mounting failed: {e}")

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

# 1. Immediate Health Check (High Priority)
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
        "database": db_status
    }

@app.get("/")
async def root(request: Request):
    """Serve SPA index or API status."""
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    index_path = os.path.join(web_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
    return {"status": "ok", "service": "Code Genie API", "message": "Flutter Web build not found"}

# 2. Rate Limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# 3. Middlewares
# Security & Monitoring (Using stable decorator approach)
app.middleware("http")(production_security_middleware)

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
    
    # 2. Check if it's a static file request that missed the /web_static mount
    # (Flutter often expects files at root)
    web_path = os.path.join(os.path.dirname(__file__), "static_web")
    static_file = os.path.join(web_path, request.url.path.lstrip("/"))
    if os.path.isfile(static_file):
        return FileResponse(static_file)

    # 3. Default to SPA index for all other routes
    index_path = os.path.join(web_path, "index.html")
    if os.path.exists(index_path):
        return FileResponse(index_path)
        
    return JSONResponse(status_code=404, content={"detail": "Not found"})


if __name__ == "__main__":
    import uvicorn
    # Respect Railway's PORT environment variable
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
