import time
import logging
import uuid
from fastapi import Request
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

async def production_security_middleware(request: Request, call_next):
    # 1. Request Timing
    start_time = time.time()
    
    # 2. Process Request
    try:
        response = await call_next(request)
    except Exception as e:
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
    
    # 4. Logging Slow Requests
    if process_time > 2.0:
        logger.warning({
            "event": "slow_request",
            "path": request.url.path,
            "method": request.method,
            "duration": process_time
        })
        
    return response
