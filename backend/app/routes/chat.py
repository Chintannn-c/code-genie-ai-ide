import json
import logging
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from app.models.requests import GenerateRequest, DebugRequest, ExplainRequest, StreamRequest, StopGenerationRequest
from app.models.responses import ChatResponse
from app.services import chat_service, file_service, ai_service as gemini_service, groq_service, orchestrator_service
from app.services.socket_manager import manager as socket_manager
from app.prompts.templates import build_prompt
from app.routes.deps import get_current_user_id
from app.services.llm_gateway import active_streams

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["chat"])

@router.post("/chat/stop")
async def stop_generation(request: StopGenerationRequest, current_user_id: str = Depends(get_current_user_id)):
    """Triggers cancellation of an active inference stream by setting its asyncio.Event flag."""
    chat_id = request.chat_id
    if chat_id in active_streams:
        active_streams[chat_id].set()
        logger.info(f"🛑 [STREAM CONTROL] Stop event triggered for chat {chat_id} by user {current_user_id}")
        return {"status": "success", "message": "Termination signal sent to inference pipeline."}
    return {"status": "success", "message": "No active stream found to terminate."}

async def _build_file_context(file_ids: list[str] | None, current_user_id: str) -> str:
    """Validate and extract document contents to inject into system/user prompts."""
    file_context = ""
    if file_ids:
        logger.info(f"📁 [FILE INJECTION] Processing {len(file_ids)} files for user {current_user_id}")
        for fid in file_ids:
            meta = await chat_service.get_file_metadata(fid)
            if not meta:
                raise HTTPException(
                    status_code=400,
                    detail=f"Document failed to attach to AI context: File '{fid}' not found in registry."
                )
            if meta["user_id"] != current_user_id:
                raise HTTPException(
                    status_code=403,
                    detail=f"Document failed to attach to AI context: Access denied for file '{meta['file_name']}'."
                )
            try:
                content = await file_service.read_file_content(meta["file_path"])
                file_context += f"\n\n--- FILE ATTACHED: {meta['file_name']} ---\n{content}\n"
                logger.info(f"✅ [FILE INJECTION] Appended {len(content)} chars from '{meta['file_name']}'")
            except Exception as fe:
                logger.error(f"❌ [FILE INJECTION] Failed to read {meta['file_name']}: {fe}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Document failed to attach to AI context: Failed to read content of file '{meta['file_name']}'."
                )
    return file_context

@router.post("/generate", response_model=ChatResponse)
async def generate_code(request: GenerateRequest, current_user_id: str = Depends(get_current_user_id)):
    """Generate code (non-streaming). Returns complete response."""
    try:
        chat_id = request.chat_id
        if chat_id:
            if not await chat_service.is_chat_owner(chat_id, current_user_id):
                raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        else:
            title = f"Generate: {request.prompt[:50]}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        # SECURITY FIX: Pass current_user_id for ownership verification
        await chat_service.save_message(
            chat_id=chat_id,
            role="user",
            content=request.prompt,
            current_user_id=current_user_id,
            msg_type="generate",
            language=request.language,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id)
        prompt_text = build_prompt(prompt=request.prompt + file_context, language=request.language, difficulty=request.difficulty, type="generate")
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents)

        # SECURITY FIX: Pass current_user_id for ownership verification
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=content,
            current_user_id=current_user_id,
            msg_type="generate",
            language=request.language,
        )

        from datetime import datetime, timezone
        return ChatResponse(
            chat_id=chat_id,
            message_id=message_id,
            content=content,
            type="generate",
            language=request.language,
            timestamp=datetime.now(timezone.utc),
        )
    except Exception as e:
        logger.error(f"Generate error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/debug", response_model=ChatResponse)
async def debug_code(request: DebugRequest, current_user_id: str = Depends(get_current_user_id)):
    """Debug code with error analysis (non-streaming)."""
    try:
        chat_id = request.chat_id
        if chat_id:
            if not await chat_service.is_chat_owner(chat_id, current_user_id):
                raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        else:
            title = f"Debug: {request.error[:50]}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        user_content = f"**Code:**\n```{request.language}\n{request.code}\n```\n\n**Error:** {request.error}"
        
        # SECURITY FIX: Pass current_user_id
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=user_content,
            current_user_id=current_user_id,
            msg_type="debug", language=request.language,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id)
        prompt_text = build_prompt(prompt="Fix this code" + file_context, language=request.language, difficulty=request.difficulty, type="debug", code=request.code, error=request.error)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents)

        # SECURITY FIX: Pass current_user_id
        message_id = await chat_service.save_message(
            chat_id=chat_id, role="ai", content=content,
            current_user_id=current_user_id,
            msg_type="debug", language=request.language,
        )

        from datetime import datetime, timezone
        return ChatResponse(
            chat_id=chat_id, message_id=message_id, content=content,
            type="debug", language=request.language, timestamp=datetime.now(timezone.utc),
        )
    except Exception as e:
        logger.error(f"Debug error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/explain", response_model=ChatResponse)
async def explain_code(request: ExplainRequest, current_user_id: str = Depends(get_current_user_id)):
    """Explain code in simple terms (non-streaming)."""
    try:
        chat_id = request.chat_id
        if chat_id:
            if not await chat_service.is_chat_owner(chat_id, current_user_id):
                raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        else:
            title = f"Explain: {request.code[:50]}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        # SECURITY FIX: Pass current_user_id
        await chat_service.save_message(
            chat_id=chat_id, role="user",
            content=f"```{request.language}\n{request.code}\n```",
            current_user_id=current_user_id,
            msg_type="explain", language=request.language,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id)
        prompt_text = build_prompt(prompt="Explain this code" + file_context, language=request.language, difficulty=request.difficulty, type="explain", code=request.code)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents)

        # SECURITY FIX: Pass current_user_id
        message_id = await chat_service.save_message(
            chat_id=chat_id, role="ai", content=content,
            current_user_id=current_user_id,
            msg_type="explain", language=request.language,
        )

        from datetime import datetime, timezone
        return ChatResponse(
            chat_id=chat_id, message_id=message_id, content=content,
            type="explain", language=request.language, timestamp=datetime.now(timezone.utc),
        )
    except Exception as e:
        logger.error(f"Explain error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/orchestrate")
async def orchestrate_response(request: StreamRequest, current_user_id: str = Depends(get_current_user_id)):
    """Parallel AI Orchestration."""
    try:
        chat_id = request.chat_id
        if chat_id:
            if not await chat_service.is_chat_owner(chat_id, current_user_id):
                raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        else:
            chat_id = await chat_service.create_chat(current_user_id, f"Parallel: {request.prompt[:50]}")

        # SECURITY FIX: Pass current_user_id
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=request.prompt,
            current_user_id=current_user_id,
            msg_type="orchestrate", language=request.language,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id)
        history = await chat_service.get_chat_context(chat_id, max_messages=10)
        result = await orchestrator_service.orchestrator.get_parallel_response(
            prompt=request.prompt + file_context,
            history=history,
            user_level="intermediate" 
        )

        # SECURITY FIX: Pass current_user_id
        message_id = await chat_service.save_message(
            chat_id=chat_id, role="ai", content=result["answer"],
            current_user_id=current_user_id,
            msg_type="orchestrate", language=request.language,
            model_name=f"ORCHESTRATOR ({', '.join(result['models_participated'])})"
        )

        return {
            "chat_id": chat_id,
            "message_id": message_id,
            "content": result["answer"],
            "strategy": result["strategy"],
            "models_participated": result["models_participated"],
            "latency": result["latency"]
        }
    except Exception as e:
        logger.error(f"Orchestration Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stream")
async def stream_response(request: StreamRequest, current_user_id: str = Depends(get_current_user_id)):
    """SSE streaming endpoint."""
    try:
        chat_id = request.chat_id
        if chat_id:
            if not await chat_service.is_chat_owner(chat_id, current_user_id):
                raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        else:
            if request.type == "generate":
                title = f"Generate: {request.prompt[:50]}"
            elif request.type == "debug":
                title = f"Debug: {request.error[:50]}"
            else:
                title = f"Explain: {request.code[:50]}"
            chat_id = await chat_service.create_chat(current_user_id, title)

        if request.type == "generate":
            user_content = request.prompt
        elif request.type == "debug":
            user_content = f"**Code:**\n```{request.language}\n{request.code}\n```\n\n**Error:** {request.error}"
        else:
            user_content = f"```{request.language}\n{request.code}\n```"

        # SECURITY FIX: Pass current_user_id
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=user_content,
            current_user_id=current_user_id,
            msg_type=request.type, language=request.language,
        )

        history = await chat_service.get_chat_context(chat_id, max_messages=10)
        
        # FILE CONTEXT INJECTION: Fetch and append file contents if provided
        file_context = await _build_file_context(request.file_ids, current_user_id)

        prompt_text = build_prompt(
            prompt=(request.prompt if request.prompt else f"Process this {request.type} request") + file_context,
            language=request.language,
            difficulty=request.difficulty,
            type=request.type,
            code=request.code,
            error=request.error,
        )

        from app.services import openrouter_service, groq_service

        from app.services.llm_gateway import stream_with_failover
        return EventSourceResponse(
            stream_with_failover(
                provider=request.provider,
                model_name=request.model_name,
                prompt_text=prompt_text,
                history=history,
                current_user_id=current_user_id,
                chat_id=chat_id,
                msg_type=request.type,
                language=request.language,
                temperature=request.temperature,
                max_tokens=request.max_tokens,
                custom_api_keys=request.custom_api_keys,
            ),
            headers={"X-Accel-Buffering": "no"}
        )
    except Exception as e:
        logger.error(f"Stream setup error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
