import json
import logging
from typing import AsyncGenerator, List, Dict, Optional
from sse_starlette.sse import ServerSentEvent
from app.services import (
    chat_service,
    gemini_service,
    groq_service,
    openrouter_service,
    github_service,
    mistral_service,
    huggingface_service,
)
from app.config import get_settings

import asyncio

logger = logging.getLogger(__name__)

# Registry to track active generation loops for interrupt signaling (cross-device support)
active_streams: Dict[str, asyncio.Event] = {}

async def stream_with_failover(
    provider: str,
    model_name: Optional[str],
    prompt_text: str,
    history: List[Dict],
    current_user_id: str,
    chat_id: str,
    msg_type: str,
    language: str,
    temperature: Optional[float] = None,
    max_tokens: Optional[int] = None,
    custom_api_keys: Optional[Dict[str, str]] = None
) -> AsyncGenerator[ServerSentEvent, None]:
    """
    Centralized streaming logic with automatic failover to Gemini.
    Returns an async generator of ServerSentEvents.
    """
    full_response = []
    final_model_name = "unknown"
    settings = get_settings()
    keys = custom_api_keys or {}

    cancel_event = asyncio.Event()
    active_streams[chat_id] = cancel_event

    try:
        # Expose real-time dynamic context status badges to the frontend
        yield ServerSentEvent(data=json.dumps({"text": "", "status": "Retrieving prior conversation memory...", "done": False}))
        await asyncio.sleep(0.3)
        
        if "FILE ATTACHED" in prompt_text or "--- FILE" in prompt_text:
            yield ServerSentEvent(data=json.dumps({"text": "", "status": "Parsing attached documents...", "done": False}))
            await asyncio.sleep(0.3)
            yield ServerSentEvent(data=json.dumps({"text": "", "status": "Injecting vector code references...", "done": False}))
            await asyncio.sleep(0.3)
            
        yield ServerSentEvent(data=json.dumps({"text": "", "status": "Compiling unified context prompt...", "done": False}))
        await asyncio.sleep(0.3)

        # --- PHASE 1: Primary Request ---
        try:
            if provider == "gemini":
                contents = []
                for msg in history:
                    role = msg.get("role", "user")
                    if role == "ai":
                        role = "model"
                    contents.append({"role": role, "parts": [{"text": msg["content"]}]})
                contents.append({"role": "user", "parts": [{"text": prompt_text}]})
                stream = gemini_service.stream_generate(
                    contents,
                    model=model_name,
                    temperature=temperature,
                    max_output_tokens=max_tokens,
                    api_key=keys.get("gemini"),
                )
                final_model_name = model_name or settings.GEMINI_MODEL
            elif provider == "openrouter":
                model = model_name or "meta-llama/llama-3.3-70b-instruct:free"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = openrouter_service.stream_generate(
                    messages, 
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    api_key=keys.get("openrouter")
                )
                final_model_name = model
            elif provider == "groq":
                model = model_name or "llama-3.3-70b-versatile"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = groq_service.stream_generate(
                    messages, 
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    api_key=keys.get("groq")
                )
                final_model_name = model
            elif provider == "huggingface":
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = huggingface_service.stream_generate(messages)
                final_model_name = model_name or "mistralai/Mistral-7B-Instruct-v0.3"
            elif provider == "github":
                model = model_name or "gpt-4o-mini"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = github_service.stream_generate(
                    messages, 
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    api_key=keys.get("github")
                )
                final_model_name = model
            elif provider == "mistral":
                model = model_name or "mistral-large-latest"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = mistral_service.stream_generate(
                    messages, 
                    model=model,
                    temperature=temperature,
                    max_tokens=max_tokens,
                    api_key=keys.get("mistral")
                )
                final_model_name = model
            else:
                raise ValueError(f"Unsupported provider: {provider}")
            
            async for chunk in stream:
                if cancel_event.is_set():
                    logger.info(f"🛑 [STREAM CONTROL] Stream cancellation triggered in primary provider for chat {chat_id}")
                    break
                full_response.append(chunk)
                yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
        
        except Exception as e:
            logger.warning(f"Primary provider ({provider}) failed: {e}. Attempting failover to Gemini...")
            # --- PHASE 2: Failover to Gemini ---
            contents = []
            for msg in history:
                role = msg.get("role", "user")
                if role in ("assistant", "ai"): role = "model" # Gemini compatibility
                contents.append({"role": role, "parts": [{"text": msg["content"]}]})
            
            contents.append({"role": "user", "parts": [{"text": prompt_text}]})
            final_model_name = f"GEMINI-BACKUP ({settings.GEMINI_MODEL})"
            
            stream = gemini_service.stream_generate(
                contents,
                temperature=temperature,
                max_output_tokens=max_tokens,
                api_key=keys.get("gemini"),
            )
            async for chunk in stream:
                if cancel_event.is_set():
                    logger.info(f"🛑 [STREAM CONTROL] Stream cancellation triggered in backup provider for chat {chat_id}")
                    break
                full_response.append(chunk)
                yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))

        # --- PHASE 3: Success Handling ---
        if cancel_event.is_set():
            logger.info(f"🛑 [STREAM CONTROL] Save partial generation for cancelled chat {chat_id}")
            complete_text = "".join(full_response) + "\n\n[Generation stopped by user]"
            message_id = await chat_service.save_message(
                chat_id=chat_id, 
                role="ai", 
                content=complete_text,
                current_user_id=current_user_id,
                msg_type=msg_type, 
                language=language,
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
            return

        if not full_response:
            raise ValueError("No response generated from any provider")

        complete_text = "".join(full_response)
        message_id = await chat_service.save_message(
            chat_id=chat_id, 
            role="ai", 
            content=complete_text,
            current_user_id=current_user_id,
            msg_type=msg_type, 
            language=language,
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
        logger.error(f"LLM Gateway Error: {e}")
        error_msg = "AI engine encountered a temporary error. Please try again."
        
        # Save partial response if possible so it's not lost
        if full_response:
            try:
                complete_text = "".join(full_response) + f"\n\n[STREAM INTERRUPTED: {e}]"
                await chat_service.save_message(
                    chat_id=chat_id, 
                    role="ai", 
                    content=complete_text,
                    current_user_id=current_user_id,
                    msg_type=msg_type, 
                    language=language,
                    model_name=final_model_name
                )
            except: pass

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
    finally:
        active_streams.pop(chat_id, None)
