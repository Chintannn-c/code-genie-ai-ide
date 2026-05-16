from fastapi import Depends
import logging
import json
from uuid import uuid4
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Query
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from app.models.files import UploadResponse, FileAnalysisRequest, FileDebugRequest, PatchRequest
from app.models.responses import ChatResponse
from app.services import chat_service, file_service, ai_service as gemini_service, groq_service, openrouter_service
from app.prompts.templates import build_prompt
from app.routes.deps import get_current_user_id
from datetime import datetime, timezone

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["files"])


from fastapi import APIRouter, HTTPException, UploadFile, File, Request, Depends
from app.limiter import limiter
import aiofiles

@router.post("/upload", response_model=list[UploadResponse])
@limiter.limit("20/minute")
async def upload_files(
    request: Request,
    files: list[UploadFile] = File(...),
    current_user_id: str = Depends(get_current_user_id)
):
    """Upload one or more files and store metadata using streaming to prevent OOM."""
    responses = []
    try:
        for file in files:
            file_id = str(uuid4())
            
            # 1. Create user directory
            from app.services import file_service
            import os
            safe_user_id = "".join([c for c in current_user_id if c.isalnum() or c in ('-', '_')])
            user_dir = os.path.join(file_service.UPLOAD_DIR, safe_user_id)
            os.makedirs(user_dir, exist_ok=True)
            
            # 2. Generate safe path
            ext = os.path.splitext(file.filename)[1]
            safe_name = f"{file_id}{ext}"
            path = os.path.join(user_dir, safe_name)
            
            # 3. STREAM the file to disk in chunks to prevent memory spikes
            async with aiofiles.open(path, 'wb') as out_file:
                while content := await file.read(1024 * 1024): # 1MB chunks
                    await out_file.write(content)
            
            # Detect language
            lang = file_service.get_language_from_ext(file.filename)
            size = os.path.getsize(path)
            
            # Save metadata to DB
            await chat_service.save_file_metadata(
                user_id=current_user_id,
                file_id=file_id,
                file_name=file.filename,
                file_path=path,
                language=lang,
                size=size
            )
            
            responses.append(UploadResponse(
                file_id=file_id,
                file_name=file.filename,
                language=lang,
                size=size
            ))
            
        return responses
    except Exception as e:
        logger.error(f"Upload error: {e}")
        # SECURITY FIX: Generic message
        raise HTTPException(status_code=500, detail="File upload failed due to a server error.")


@router.get("/user-files")
async def list_files(current_user_id: str = Depends(get_current_user_id)):
    """List all files for the authenticated user."""
    return await chat_service.get_user_files(current_user_id)


@router.post("/analyze-file", response_model=ChatResponse)
async def analyze_file(
    request: FileAnalysisRequest, 
    current_user_id: str = Depends(get_current_user_id), 
    chat_id: str | None = None
):
    """Analyze a specific file using Gemini."""
    try:
        file_meta = await chat_service.get_file_metadata(request.file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")
            
        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")
            
        content = await file_service.read_file_content(file_meta["file_path"])
        
        # Create chat if needed
        if not chat_id:
            chat_id = await chat_service.create_chat(current_user_id, f"Analysis: {file_meta['file_name']}")
            
        # Save user message
        await chat_service.save_message(
            chat_id=chat_id,
            role="user",
            content=f"Analyze this file: {file_meta['file_name']}",
            current_user_id=current_user_id,
            msg_type="file_analysis",
            language=file_meta["language"]
        )
        
        prompt_text = build_prompt(prompt=f"Analyze this file: {file_meta['file_name']}", language=file_meta["language"], difficulty=request.difficulty if hasattr(request, 'difficulty') else "beginner", type="file_analysis", code=content)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        
        # Use selected provider
        if request.provider == "groq":
            ai_response = await groq_service.generate([{"role": "user", "content": prompt_text}], model=request.model_name or "llama3-8b-8192")
        elif request.provider == "openrouter":
            ai_response = await openrouter_service.generate([{"role": "user", "content": prompt_text}], model=request.model_name or "meta-llama/llama-3.3-70b-instruct:free")
        else:
            ai_response = await gemini_service.generate(contents)
        
        # Save AI message
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=ai_response,
            current_user_id=current_user_id,
            msg_type="file_analysis",
            language=file_meta["language"],
            model_name=request.model_name or f"{request.provider.upper() if request.provider else 'GEMINI'} (Direct)"
        )
        
        return ChatResponse(
            chat_id=chat_id,
            message_id=message_id,
            content=ai_response,
            type="file_analysis",
            language=file_meta["language"],
            timestamp=datetime.now(timezone.utc)
        )
    except Exception as e:
        logger.error(f"Analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/debug-file", response_model=ChatResponse)
async def debug_file(
    request: FileDebugRequest, 
    current_user_id: str = Depends(get_current_user_id), 
    chat_id: str | None = None
):
    """Debug a specific file based on an error message."""
    try:
        file_meta = await chat_service.get_file_metadata(request.file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")

        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")
            
        content = await file_service.read_file_content(file_meta["file_path"])
        
        if not chat_id:
            chat_id = await chat_service.create_chat(current_user_id, f"Debug: {file_meta['file_name']}")
            
        await chat_service.save_message(
            chat_id=chat_id,
            role="user",
            content=f"Debug {file_meta['file_name']}: {request.error}",
            current_user_id=current_user_id,
            msg_type="file_debug",
            language=file_meta["language"]
        )
        
        prompt_text = build_prompt(prompt=f"Debug {file_meta['file_name']}: {request.error}", language=file_meta["language"], difficulty=request.difficulty if hasattr(request, 'difficulty') else "beginner", type="file_debug", code=content, error=request.error)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        
        if request.provider == "groq":
            ai_response = await groq_service.generate([{"role": "user", "content": prompt_text}], model=request.model_name or "llama3-8b-8192")
        elif request.provider == "openrouter":
            ai_response = await openrouter_service.generate([{"role": "user", "content": prompt_text}], model=request.model_name or "meta-llama/llama-3.3-70b-instruct:free")
        else:
            ai_response = await gemini_service.generate(contents)
        
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=ai_response,
            current_user_id=current_user_id,
            msg_type="file_debug",
            language=file_meta["language"],
            model_name=request.model_name or f"{request.provider.upper() if request.provider else 'GEMINI'} (Direct)"
        )
        
        return ChatResponse(
            chat_id=chat_id,
            message_id=message_id,
            content=ai_response,
            type="file_debug",
            language=file_meta["language"],
            timestamp=datetime.now(timezone.utc)
        )
    except Exception as e:
        logger.error(f"Debug error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream-analyze-file")
async def stream_analyze_file(request: dict, current_user_id: str = Depends(get_current_user_id)):
    """
    SSE streaming endpoint for file analysis.
    Expected body: {"file_id": "...", "analysis_type": "...", "chat_id": "..."}
    """
    try:
        file_id = request.get("file_id")
        chat_id = request.get("chat_id")
        difficulty = request.get("difficulty", "beginner")

        file_meta = await chat_service.get_file_metadata(file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")

        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")

        content = await file_service.read_file_content(file_meta["file_path"])
        
        if not chat_id:
            title = f"Analysis: {file_meta['file_name']}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        prompt_text = build_prompt(
            "file_analysis", file_meta["language"], difficulty=difficulty,
            code=content
        )
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]

        from app.services.llm_gateway import stream_with_failover
        return EventSourceResponse(
            stream_with_failover(
                provider=request.get("provider", "gemini"),
                model_name=request.get("model_name"),
                prompt_text=prompt_text,
                history=[], # Analysis doesn't usually need deep history
                current_user_id=current_user_id,
                chat_id=chat_id,
                msg_type="file_analysis",
                language=file_meta["language"]
            ),
            headers={"X-Accel-Buffering": "no"}
        )

    except Exception as e:
        logger.error(f"Stream analysis error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/stream-debug-file")
async def stream_debug_file(request: dict, current_user_id: str = Depends(get_current_user_id)):
    """
    SSE streaming endpoint for file debugging.
    Expected body: {"file_id": "...", "error": "...", "chat_id": "..."}
    """
    try:
        file_id = request.get("file_id")
        error = request.get("error", "Unknown error")
        chat_id = request.get("chat_id")
        difficulty = request.get("difficulty", "beginner")

        file_meta = await chat_service.get_file_metadata(file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")

        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")

        content = await file_service.read_file_content(file_meta["file_path"])
        
        if not chat_id:
            title = f"Debug File: {file_meta['file_name']}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        prompt_text = build_prompt(
            "file_debug", file_meta["language"], difficulty=difficulty,
            code=content, error=error
        )
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]

        from app.services.llm_gateway import stream_with_failover
        return EventSourceResponse(
            stream_with_failover(
                provider=request.get("provider", "gemini"),
                model_name=request.get("model_name"),
                prompt_text=prompt_text,
                history=[],
                current_user_id=current_user_id,
                chat_id=chat_id,
                msg_type="file_debug",
                language=file_meta["language"]
            ),
            headers={"X-Accel-Buffering": "no"}
        )

    except Exception as e:
        logger.error(f"Stream debug error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/generate-patch")
async def generate_patch(request: PatchRequest, current_user_id: str = Depends(get_current_user_id)):
    """Generate a unified diff patch for a file issue."""
    try:
        file_meta = await chat_service.get_file_metadata(request.file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")
        
        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")
            
        content = await file_service.read_file_content(file_meta["file_path"])
        prompt = build_prompt("patch", file_meta["language"], code=content, error=request.issue)
        patch = await gemini_service.generate(prompt)
        
        return {"patch": patch, "file_name": file_meta["file_name"]}
    except Exception as e:
        logger.error(f"Patch error: {e}")

@router.get("/file/{file_id}")
async def download_file(file_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Download or view a specific file."""
    try:
        file_meta = await chat_service.get_file_metadata(file_id)
        if not file_meta:
            raise HTTPException(status_code=404, detail="File not found")
            
        # SECURITY FIX: Verify ownership
        if file_meta["user_id"] != current_user_id:
            raise HTTPException(status_code=403, detail="Not authorized to access this file")
            
        from fastapi.responses import FileResponse
        return FileResponse(file_meta["file_path"])
    except Exception as e:
        logger.error(f"Download error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
