import time
import logging
import uuid
import threading
from typing import Dict, List
from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.datastructures import MutableHeaders

logger = logging.getLogger(__name__)

class MemorySlidingWindow:
    """Thread-safe in-memory sliding window fallback rate limiter."""
    def __init__(self):
        self.history: Dict[str, List[float]] = {}
        self.lock = threading.Lock()
        
    def check_rate_limit(self, key: str, limit: int, window: int) -> tuple[bool, int, int]:
        now = time.time()
        clear_before = now - window
        
        with self.lock:
            if key not in self.history:
                self.history[key] = []
                
            # Filter out old requests
            self.history[key] = [t for t in self.history[key] if t > clear_before]
            
            count = len(self.history[key])
            
            if count >= limit:
                # Oldest score in history
                oldest_score = self.history[key][0] if self.history[key] else now
                reset_seconds = int(max(0, window - (now - oldest_score)))
                return True, 0, reset_seconds
                
            self.history[key].append(now)
            remaining = limit - len(self.history[key])
            
            oldest_score = self.history[key][0]
            reset_seconds = int(max(0, window - (now - oldest_score)))
            
            return False, remaining, reset_seconds

memory_limiter = MemorySlidingWindow()


class RateLimitMiddleware:
    """
    Pure ASGI middleware for per-user distributed sliding window rate limiting.
    Specifically protects expensive AI endpoints, falling back to memory cache if Redis is down.
    Supports JWT auth tier lookup and anonymous IP fallback.
    """
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        request = Request(scope)
        path = request.url.path

        # Protect expensive AI endpoints specifically
        protected_paths = {
            "/api/generate",
            "/api/stream",
            "/api/debug",
            "/api/explain",
            "/api/orchestrate",
            "/api/stream-analyze-file",
            "/api/stream-debug-file",
            "/api/generate-patch"
        }

        is_protected = False
        for p in protected_paths:
            if path == p or path.startswith(p + "/"):
                is_protected = True
                break

        if not is_protected:
            return await self.app(scope, receive, send)

        # 1. JWT User Authentication Extraction
        auth_header = request.headers.get("Authorization")
        user_id = None
        tier = "free"

        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            try:
                from jose import jwt
                from app.config import get_settings
                settings = get_settings()
                payload = jwt.decode(
                    token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM]
                )
                user_id = payload.get("sub")
            except Exception:
                pass # Invalid token falls back to IP rate limiting

        # 2. Tier Resolution & Caching (Redis Optimized)
        from app.services.redis_service import redis_service
        from app.config import get_settings
        settings = get_settings()

        if user_id:
            cache_key = f"user_tier:{user_id}"
            cached_tier = await redis_service.get(cache_key)
            if cached_tier:
                tier = cached_tier
            else:
                try:
                    from app.database import get_db
                    db = await get_db()
                    user = await db.users.find_one({"_id": user_id})
                    if user:
                        tier = user.get("tier", "free")
                        # Cache tier for 5 minutes (300 seconds)
                        await redis_service.set(cache_key, tier, expire_seconds=300)
                except Exception as ex:
                    logger.error(f"Error resolving user tier in middleware: {ex}")
                    tier = "free"

        # 3. Limit Configuration
        if user_id:
            rate_key = f"rate_limit:{user_id}"
            if tier == "premium":
                limit = settings.RATE_LIMIT_PREMIUM
            else:
                limit = settings.RATE_LIMIT_FREE
        else:
            # IP Fallback for anonymous users
            ip = request.client.host if request.client else "127.0.0.1"
            rate_key = f"rate_limit:ip:{ip}"
            limit = 5 # Strict limit of 5 requests per hour for anonymous visitors

        window = settings.RATE_LIMIT_WINDOW_SECONDS

        # 4. Execute Sliding Window (Redis with Memory Fallback)
        is_limited = False
        remaining = limit
        reset_seconds = window

        if hasattr(redis_service, "_redis") and redis_service._redis:
            is_limited, remaining, reset_seconds = await redis_service.check_sliding_window(rate_key, limit, window)
        else:
            # Memory cache fallback if Redis is down or not configured
            is_limited, remaining, reset_seconds = memory_limiter.check_rate_limit(rate_key, limit, window)

        # 5. Handle Rate Limit Exceeded
        if is_limited:
            response = JSONResponse(
                status_code=429,
                content={
                    "success": False,
                    "error": "Rate limit exceeded",
                    "retry_after": reset_seconds
                },
                headers={
                    "X-RateLimit-Limit": str(limit),
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset": str(reset_seconds),
                    "Retry-After": str(reset_seconds)
                }
            )
            await response(scope, receive, send)
            return

        # 6. Inject rate limit headers on successful request
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                headers["X-RateLimit-Limit"] = str(limit)
                headers["X-RateLimit-Remaining"] = str(remaining)
                headers["X-RateLimit-Reset"] = str(reset_seconds)
            await send(message)

        await self.app(scope, receive, send_wrapper)


class ProductionSecurityMiddleware:
    """
    Pure ASGI middleware to handle security headers and logging.
    Fixes the BaseHTTPMiddleware bug that hangs multipart/form-data (file uploads).
    """
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        start_time = time.time()
        
        async def send_wrapper(message):
            if message["type"] == "http.response.start":
                headers = MutableHeaders(scope=message)
                headers["X-Content-Type-Options"] = "nosniff"
                headers["X-Frame-Options"] = "DENY"
                headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
                headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://apis.google.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' data: https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self' ws: wss: http: https:; frame-ancestors 'none';"
                headers["X-XSS-Protection"] = "1; mode=block"
                headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
                headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=(), magnetometer=(), gyroscope=()"
                
                process_time = time.time() - start_time
                headers["X-Process-Time"] = str(process_time)
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception as e:
            error_id = str(uuid.uuid4())
            logger.error(f"Unhandled Exception [{error_id}]: {e}", exc_info=True)
            response = JSONResponse(
                status_code=500,
                content={
                    "detail": "An internal server error occurred.",
                    "error_id": error_id
                }
            )
            await response(scope, receive, send)
            
        process_time = time.time() - start_time
        if process_time > 2.0:
            logger.warning({
                "event": "slow_request",
                "path": scope.get("path", ""),
                "method": scope.get("method", ""),
                "duration": process_time
            })
