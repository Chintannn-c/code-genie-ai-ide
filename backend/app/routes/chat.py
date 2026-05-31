import json
import logging
import asyncio
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from app.models.requests import GenerateRequest, DebugRequest, ExplainRequest, StreamRequest, StopGenerationRequest, SearchRequest
from app.models.responses import ChatResponse
from app.services import chat_service, file_service, ai_service as gemini_service, groq_service, orchestrator_service
from app.services.socket_manager import manager as socket_manager
from app.prompts.templates import build_prompt
from app.routes.deps import get_current_user_id
from app.services.llm_gateway import active_streams

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["chat"])

from fastapi import Request
from app.limiter import limiter

@router.post("/chat/stop")
@limiter.limit("20/minute")
async def stop_generation(request: Request, body_req: StopGenerationRequest, current_user_id: str = Depends(get_current_user_id)):
    """Triggers cancellation of an active inference stream by setting its asyncio.Event flag."""
    chat_id = body_req.chat_id
    
    # SECURITY FIX: Ensure the user actually owns the chat before terminating it
    if not await chat_service.is_chat_owner(chat_id, current_user_id):
        logger.warning(f"IDOR Attempt: User {current_user_id} tried to stop chat {chat_id}")
        raise HTTPException(status_code=403, detail="Not authorized to stop this chat")
        
    if chat_id in active_streams:
        active_streams[chat_id].set()
        logger.info(f"🛑 [STREAM CONTROL] Stop event triggered for chat {chat_id} by user {current_user_id}")
        return {"status": "success", "message": "Termination signal sent to inference pipeline."}
    return {"status": "success", "message": "No active stream found to terminate."}

@router.post("/search")
@limiter.limit("30/minute")
async def workspace_search(request: Request, body_req: SearchRequest, current_user_id: str = Depends(get_current_user_id)):
    """Semantic workspace search using ChromaDB vector index."""
    from app.services.indexer_service import indexer
    results = await indexer.search_context(body_req.query, limit=body_req.limit or 10)
    return {"results": results, "query": body_req.query}

async def _build_file_context(file_ids: list[str] | None, current_user_id: str, prompt_text: str = "") -> str:
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
            if meta.get("status", "safe") not in {"safe", "ready"}:
                raise HTTPException(
                    status_code=409,
                    detail=f"Document '{meta['file_name']}' is not available because its security status is '{meta.get('status')}'."
                )
            try:
                if meta.get("mime_type", "").startswith("image/"):
                    logger.info(f"📸 [FILE INJECTION] Found image file attachment: '{meta['file_name']}'")
                    file_context += f"\n\n--- SCREENSHOT ATTACHED: {meta['file_name']} ---\n[Image will be processed by vision model]\n"
                    continue

                # Use semantic search if we have a prompt and the file is large, otherwise fallback to full text
                from app.services.indexer_service import indexer
                if prompt_text and indexer.collection and meta.get("size", 0) > 10000:
                    logger.info(f"🔍 [FILE INJECTION] Using semantic retrieval for large file '{meta['file_name']}'")
                    # Ideally we'd filter by file_id, but for now we search globally and filter client side or just append.
                    # As a safe fallback, we'll read the first 10000 chars
                    content = await file_service.read_file_content(meta["file_path"])
                    content = content[:10000] + "\n...[Content truncated for token limits]..."
                else:
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

async def _apply_user_settings(prompt_text: str, current_user_id: str, chat_id: str | None = None) -> tuple[str, float | None, int | None]:
    """Hydrate prompt text and model parameters based on user's active cloud settings resolved globally."""
    from app.services.pg_settings import resolve_active_configuration
    try:
        ai_settings = await resolve_active_configuration(current_user_id, chat_id)
    except Exception as dbe:
        logger.warning(f"SQL layered settings resolution failed: {dbe}")
        ai_settings = {}

    temperature = None
    max_tokens = None

    if ai_settings:
        if ai_settings.get("temperature") is not None:
            temperature = float(ai_settings["temperature"])
        if ai_settings.get("max_tokens") is not None:
            max_tokens = int(ai_settings["max_tokens"])

        # Pinned Memories
        if ai_settings.get("memory_persist", False):
            memories = ai_settings.get("memories", [])
            pinned_memories = [m for m in memories if m.get("pinned") == True and not m.get("encrypted")]
            if pinned_memories:
                prompt_text += "\n\n[STRICT USER COGNITIVE MEMORIES & STYLE GUIDELINES]:\n"
                for pm in pinned_memories:
                    prompt_text += f"- {pm.get('text')}\n"

        # RAG suppression
        if not ai_settings.get("rag_context", True):
            import re
            prompt_text = re.sub(r"--- FILE ATTACHED:.*?\n.*?(?=\n--- FILE ATTACHED:|\Z)", "", prompt_text, flags=re.DOTALL)
            prompt_text = re.sub(r"--- FILE:.*?\n.*?(?=\n--- FILE:|\Z)", "", prompt_text, flags=re.DOTALL)

    return prompt_text, temperature, max_tokens

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
        fid = request.file_ids[0] if request.file_ids else None
        await chat_service.save_message(
            chat_id=chat_id,
            role="user",
            content=request.prompt,
            current_user_id=current_user_id,
            msg_type="generate",
            language=request.language,
            file_id=fid,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id, request.prompt)
        prompt_text = build_prompt(prompt=request.prompt + file_context, language=request.language, difficulty=request.difficulty, type="generate")
        prompt_text, temperature, max_tokens = await _apply_user_settings(prompt_text, current_user_id, chat_id)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents, temperature=temperature, max_output_tokens=max_tokens)

        # SECURITY FIX: Pass current_user_id for ownership verification
        message_id = await chat_service.save_message(
            chat_id=chat_id,
            role="ai",
            content=content,
            current_user_id=current_user_id,
            msg_type="generate",
            language=request.language,
            file_id=fid,
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
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Generate error: {e}")
        raise HTTPException(status_code=500, detail="Code generation failed due to a server error.")

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
        fid = request.file_ids[0] if request.file_ids else None
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=user_content,
            current_user_id=current_user_id,
            msg_type="debug", language=request.language,
            file_id=fid,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id, request.error)
        prompt_text = build_prompt(prompt="Fix this code" + file_context, language=request.language, difficulty=request.difficulty, type="debug", code=request.code, error=request.error)
        prompt_text, temperature, max_tokens = await _apply_user_settings(prompt_text, current_user_id, chat_id)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents, temperature=temperature, max_output_tokens=max_tokens)

        # SECURITY FIX: Pass current_user_id
        message_id = await chat_service.save_message(
            chat_id=chat_id, role="ai", content=content,
            current_user_id=current_user_id,
            msg_type="debug", language=request.language,
            file_id=fid,
        )

        from datetime import datetime, timezone
        return ChatResponse(
            chat_id=chat_id, message_id=message_id, content=content,
            type="debug", language=request.language, timestamp=datetime.now(timezone.utc),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Debug error: {e}")
        raise HTTPException(status_code=500, detail="Debugging failed due to a server error.")

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
        fid = request.file_ids[0] if request.file_ids else None
        await chat_service.save_message(
            chat_id=chat_id, role="user",
            content=f"```{request.language}\n{request.code}\n```",
            current_user_id=current_user_id,
            msg_type="explain", language=request.language,
            file_id=fid,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id, request.code)
        prompt_text = build_prompt(prompt="Explain this code" + file_context, language=request.language, difficulty=request.difficulty, type="explain", code=request.code)
        prompt_text, temperature, max_tokens = await _apply_user_settings(prompt_text, current_user_id, chat_id)
        contents = [{"role": "user", "parts": [{"text": prompt_text}]}]
        content = await gemini_service.generate(contents, temperature=temperature, max_output_tokens=max_tokens)

        # SECURITY FIX: Pass current_user_id
        message_id = await chat_service.save_message(
            chat_id=chat_id, role="ai", content=content,
            current_user_id=current_user_id,
            msg_type="explain", language=request.language,
            file_id=fid,
        )

        from datetime import datetime, timezone
        return ChatResponse(
            chat_id=chat_id, message_id=message_id, content=content,
            type="explain", language=request.language, timestamp=datetime.now(timezone.utc),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Explain error: {e}")
        raise HTTPException(status_code=500, detail="Explanation failed due to a server error.")

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
        fid = request.file_ids[0] if request.file_ids else None
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=request.prompt,
            current_user_id=current_user_id,
            msg_type="orchestrate", language=request.language,
            file_id=fid,
        )

        file_context = await _build_file_context(request.file_ids, current_user_id, request.prompt)
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
            model_name=f"ORCHESTRATOR ({', '.join(result['models_participated'])})",
            file_id=fid,
        )

        return {
            "chat_id": chat_id,
            "message_id": message_id,
            "content": result["answer"],
            "strategy": result["strategy"],
            "models_participated": result["models_participated"],
            "latency": result["latency"]
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Orchestration Error: {e}")
        raise HTTPException(status_code=500, detail="Orchestration failed due to a server error.")

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
        fid = request.file_ids[0] if request.file_ids else None
        await chat_service.save_message(
            chat_id=chat_id, role="user", content=user_content,
            current_user_id=current_user_id,
            msg_type=request.type, language=request.language,
            file_id=fid,
        )

        history = await chat_service.get_chat_context(chat_id, max_messages=10)
        
        # FILE CONTEXT INJECTION: Fetch and append file contents if provided
        file_context = await _build_file_context(request.file_ids, current_user_id, request.prompt)

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
                file_id=fid,
            ),
            headers={"X-Accel-Buffering": "no"}
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Stream setup error: {e}")
        raise HTTPException(status_code=500, detail="Stream setup failed due to a server error.")

@router.get("/resume-stream")
async def resume_stream(chat_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Resume a dropped SSE stream using the in-memory buffer."""
    if not await chat_service.is_chat_owner(chat_id, current_user_id):
        raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        
    from app.services.llm_gateway import active_streams, stream_buffers
    
    async def buffer_generator():
        # First yield everything in the buffer
        buffer = stream_buffers.get(chat_id, [])
        for chunk in buffer:
            yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
            await asyncio.sleep(0.01)
            
        # If the stream is still active, wait for new chunks? 
        # For simplicity, we'll just yield the buffer and let the client know we recovered.
        # True stream continuation requires hooking back into the generator queue, which is complex.
        # This yields the buffered state.
        if chat_id not in active_streams:
            yield ServerSentEvent(data=json.dumps({"text": "", "done": True, "chat_id": chat_id}))
            
    return EventSourceResponse(buffer_generator(), headers={"X-Accel-Buffering": "no"})
