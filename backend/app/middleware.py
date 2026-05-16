import time
import logging
import uuid
from fastapi import Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

from starlette.datastructures import MutableHeaders

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
