from fastapi import Depends
import logging
import json
from uuid import uuid4
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Query
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from app.models.files import UploadResponse, FileAnalysisRequest, FileDebugRequest, PatchRequest
from app.models.responses import ChatResponse
from app.services import chat_service, file_service, ai_service as gemini_service
from app.prompts.templates import build_prompt
from app.routes.deps import get_current_user_id
from datetime import datetime, timezone

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["files"])


@router.post("/upload", response_model=list[UploadResponse])
async def upload_files(
    files: list[UploadFile] = File(...),
    current_user_id: str = Depends(get_current_user_id)
):
    """Upload one or more files and store metadata."""
    responses = []
    try:
        for file in files:
            file_id = str(uuid4())
            # Save file to local storage
            path = await file_service.save_upload(current_user_id, file)
            
            # Detect language
            lang = file_service.get_language_from_ext(file.filename)
            
            # Read size
            import os
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
        raise HTTPException(status_code=500, detail=str(e))


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
        ai_response = await gemini_service.generate(contents)
        
        # Save AI message
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=ai_response,
            current_user_id=current_user_id,
            msg_type="file_analysis",
            language=file_meta["language"]
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
        ai_response = await gemini_service.generate(contents)
        
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=ai_response,
            current_user_id=current_user_id,
            msg_type="file_debug",
            language=file_meta["language"]
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

        async def event_generator():
            full_response = []
            try:
                async for chunk in gemini_service.stream_generate(contents):
                    full_response.append(chunk)
                    yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
                
                complete_text = "".join(full_response)
                message_id = await chat_service.save_message(
                    chat_id=chat_id, role="ai", content=complete_text,
                    current_user_id=current_user_id,
                    msg_type="file_analysis", language=file_meta["language"]
                )

                yield ServerSentEvent(
                    data=json.dumps({
                        "text": "", "done": True, 
                        "chat_id": chat_id, "message_id": message_id
                    })
                )
            except Exception as e:
                yield ServerSentEvent(data=json.dumps({"error": str(e)}))

        return EventSourceResponse(
            event_generator(),
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

        async def event_generator():
            full_response = []
            try:
                async for chunk in gemini_service.stream_generate(contents):
                    full_response.append(chunk)
                    yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
                
                complete_text = "".join(full_response)
                message_id = await chat_service.save_message(
                    chat_id=chat_id, role="ai", content=complete_text,
                    current_user_id=current_user_id,
                    msg_type="file_debug", language=file_meta["language"]
                )

                yield ServerSentEvent(
                    data=json.dumps({
                        "text": "", "done": True, 
                        "chat_id": chat_id, "message_id": message_id
                    })
                )
            except Exception as e:
                yield ServerSentEvent(data=json.dumps({"error": str(e)}))

        return EventSourceResponse(
            event_generator(),
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
