import time
import logging
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from fastapi.responses import JSONResponse
import os

logger = logging.getLogger(__name__)

class ProductionMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # 1. Request Timing
        start_time = time.time()
        
        # 2. Process Request
        try:
            response = await call_next(request)
        except Exception as e:
            import uuid
            error_id = str(uuid.uuid4())
            logger.error(f"Unhandled Exception [{error_id}]: {e}", exc_info=True)
            return JSONResponse(
                status_code=500,
                content={
                    "detail": "An internal server error occurred.",
                    "error_id": error_id
                }
            )
        
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        
        # 3. Security Headers
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://www.gstatic.com; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "font-src 'self' https://fonts.gstatic.com; "
            "img-src 'self' data: https:; "
            "connect-src 'self' https://code-genie.up.railway.app wss://code-genie.up.railway.app;"
        )
        
        # 4. Logging Slow Requests
        if process_time > 2.0:
            logger.warning({
                "event": "slow_request",
                "path": request.url.path,
                "method": request.method,
                "duration": process_time,
                "client": request.client.host if request.client else "unknown"
            })
            
        return response
