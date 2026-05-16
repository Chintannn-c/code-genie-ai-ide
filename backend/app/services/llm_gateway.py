import json
import logging
from typing import AsyncGenerator, List, Dict, Optional
from sse_starlette.sse import ServerSentEvent
from app.services import chat_service, ai_service as gemini_service, groq_service, openrouter_service, github_service, mistral_service
from app.config import get_settings

logger = logging.getLogger(__name__)

async def stream_with_failover(
    provider: str,
    model_name: Optional[str],
    prompt_text: str,
    history: List[Dict],
    current_user_id: str,
    chat_id: str,
    msg_type: str,
    language: str
) -> AsyncGenerator[ServerSentEvent, None]:
    """
    Centralized streaming logic with automatic failover to Gemini.
    Returns an async generator of ServerSentEvents.
    """
    full_response = []
    final_model_name = "unknown"
    settings = get_settings()

    try:
        # --- PHASE 1: Primary Request ---
        try:
            if provider == "openrouter":
                model = model_name or "meta-llama/llama-3.3-70b-instruct:free"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = openrouter_service.stream_generate(messages, model=model)
                final_model_name = model
            elif provider in ["huggingface", "groq"]:
                model = model_name or "llama3-8b-8192"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = groq_service.stream_generate(messages, model=model)
                final_model_name = model
            elif provider == "github":
                model = model_name or "gpt-4o-mini"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = github_service.stream_generate(messages, model=model)
                final_model_name = model
            elif provider == "mistral":
                model = model_name or "mistral-large-latest"
                messages = history + [{"role": "user", "content": prompt_text}]
                stream = mistral_service.stream_generate(messages, model=model)
                final_model_name = model
            else:
                raise ValueError("Defaulting to Gemini")
            
            async for chunk in stream:
                full_response.append(chunk)
                yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))
        
        except Exception as e:
            logger.warning(f"Primary provider ({provider}) failed: {e}. Attempting failover to Gemini...")
            # --- PHASE 2: Failover to Gemini ---
            contents = []
            for msg in history:
                role = msg.get("role", "user")
                if role == "assistant": role = "model" # Gemini compatibility
                contents.append({"role": role, "parts": [{"text": msg["content"]}]})
            
            contents.append({"role": "user", "parts": [{"text": prompt_text}]})
            final_model_name = f"GEMINI-BACKUP ({settings.GEMINI_MODEL})"
            
            stream = gemini_service.stream_generate(contents)
            async for chunk in stream:
                full_response.append(chunk)
                yield ServerSentEvent(data=json.dumps({"text": chunk, "done": False}))

        # --- PHASE 3: Success Handling ---
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
