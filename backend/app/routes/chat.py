import json
import logging
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from sse_starlette.sse import EventSourceResponse, ServerSentEvent
from app.models.requests import GenerateRequest, DebugRequest, ExplainRequest, StreamRequest
from app.models.responses import ChatResponse
from app.services import chat_service, ai_service as gemini_service, groq_service, orchestrator_service
from app.services.socket_manager import manager as socket_manager
from app.prompts.templates import build_prompt
from app.routes.deps import get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["chat"])

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

        prompt_text = build_prompt(prompt=request.prompt, language=request.language, difficulty=request.difficulty, type="generate")
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

        prompt_text = build_prompt(prompt="Fix this code", language=request.language, difficulty=request.difficulty, type="debug", code=request.code, error=request.error)
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

        prompt_text = build_prompt(prompt="Explain this code", language=request.language, difficulty=request.difficulty, type="explain", code=request.code)
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

        history = await chat_service.get_chat_context(chat_id, max_messages=10)
        result = await orchestrator_service.orchestrator.get_parallel_response(
            prompt=request.prompt,
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

@router.post("/plan")
async def create_plan(request: GenerateRequest, background_tasks: BackgroundTasks, current_user_id: str = Depends(get_current_user_id)):
    """Generates a proactive execution plan and starts it IMMEDIATELY."""
    try:
        # 1. Generate the plan
        plan = await orchestrator_service.orchestrator.generate_plan(request.prompt)
        
        # 2. Broadcast via WebSocket for real-time UI reaction
        await socket_manager.broadcast_to_user(
            current_user_id,
            {
                "type": "plan_created",
                "plan": plan
            }
        )
        
        # 3. PROACTIVE TRANSFORMATION: Start execution immediately without waiting for approval
        background_tasks.add_task(
            orchestrator_service.orchestrator.run_autonomous_plan,
            user_id=current_user_id,
            plan_id=plan["id"],
            plan_data=plan
        )
        
        return plan
    except Exception as e:
        logger.error(f"Planning route error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/plan/{plan_id}/execute")
async def execute_plan_route(
    plan_id: str, 
    plan_data: dict, 
    background_tasks: BackgroundTasks, 
    current_user_id: str = Depends(get_current_user_id)
):
    """Triggers autonomous execution of an approved plan."""
    try:
        # Start execution in background so user doesn't wait
        background_tasks.add_task(
            orchestrator_service.orchestrator.run_autonomous_plan,
            user_id=current_user_id,
            plan_id=plan_id,
            plan_data=plan_data
        )
        
        return {"status": "execution_started", "plan_id": plan_id}
    except Exception as e:
        logger.error(f"Execution route error: {e}")
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
        prompt_text = build_prompt(
            prompt=request.prompt if request.prompt else f"Process this {request.type} request",
            language=request.language,
            difficulty=request.difficulty,
            type=request.type,
            code=request.code,
            error=request.error,
        )

        from app.services import openrouter_service, groq_service

        async def event_generator():
            full_response = []
            final_model_name = "unknown"
            try:
                # --- PHASE 1: Primary Request ---
                try:
                    if request.provider == "openrouter":
                        model = request.model_name or "meta-llama/llama-3.3-70b-instruct:free"
                        messages = history + [{"role": "user", "content": prompt_text}]
                        stream = openrouter_service.stream_generate(messages, model=model)
                        final_model_name = model
                    elif request.provider == "huggingface" or request.provider == "groq":
                        model = request.model_name or "llama3-8b-8192"
                        messages = history + [{"role": "user", "content": prompt_text}]
                        stream = groq_service.stream_generate(messages, model=model)
                        final_model_name = model
                    else:
                        raise ValueError("Defaulting to Gemini")
                    
                    # Test if stream is actually working
                    async for chunk in stream:
                        full_response.append(chunk)
                        yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
                
                except Exception as e:
                    logger.warning(f"Primary provider ({request.provider}) failed: {e}. Attempting failover to Gemini...")
                    # --- PHASE 2: Failover to Gemini ---
                    contents = []
                    for msg in history:
                        contents.append({"role": msg["role"], "parts": [{"text": msg["content"]}]})
                    contents.append({"role": "user", "parts": [{"text": prompt_text}]})
                    
                    from app.config import get_settings
                    final_model_name = f"GEMINI-BACKUP ({get_settings().GEMINI_MODEL})"
                    
                    stream = gemini_service.stream_generate(contents)
                    async for chunk in stream:
                        full_response.append(chunk)
                        yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))

                # --- PHASE 3: Success Handling ---
                if not full_response:
                    # If we got here with no response, it's a failure
                    raise ValueError("No response generated from any provider")

                # Save success message
                complete_text = "".join(full_response)
                message_id = await chat_service.save_message(
                    chat_id=chat_id, role="ai", content=complete_text,
                    current_user_id=current_user_id,
                    msg_type=request.type, language=request.language,
                    model_name=final_model_name,
                )

                yield ServerSentEvent(
                    event="message",
                    data=json.dumps({
                        "text": "",
                        "done": True,
                        "chat_id": chat_id,
                        "message_id": message_id,
                        "model_name": final_model_name,
                    }),
                )

            except Exception as e:
                logger.error(f"Stream generation error: {e}")
                error_msg = "AI Fails to response..."
                yield ServerSentEvent(data=json.dumps({"text": error_msg, "done": False}))
                yield ServerSentEvent(
                    event="message",
                    data=json.dumps({
                        "text": "",
                        "done": True,
                        "chat_id": chat_id,
                        "error": error_msg
                    }),
                )

        return EventSourceResponse(event_generator(), headers={"X-Accel-Buffering": "no"})
    except Exception as e:
        logger.error(f"Stream setup error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
