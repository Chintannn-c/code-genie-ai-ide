import logging
import asyncio
from typing import AsyncGenerator
from app.services import gemini_service, groq_service, orchestrator_service
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

async def stream_generate(contents: list[dict], type: str = "generate") -> AsyncGenerator[str, None]:
    """
    Always-on Orchestration: Queries multiple models in parallel
    and streams the synthesized result.
    """
    # Extract prompt text
    prompt_text = ""
    for item in contents:
        for part in item.get("parts", []):
            if "text" in part:
                prompt_text += part["text"]

    try:
        logger.info(f"🚀 [Orchestrator] Initiating parallel generation for: {type}")
        
        # Parallel Execution
        # We use history from contents if available (simplified for now)
        result = await orchestrator_service.orchestrator.get_parallel_response(
            prompt=prompt_text,
            user_level="intermediate"
        )
        
        answer = result["answer"]
        
        # Stream the synthesized answer in chunks to simulate real-time thinking
        # (This allows the frontend to show the typing animation synced with "incoming" data)
        words = answer.split(' ')
        for i in range(0, len(words), 2): # Send 2 words at a time for speed
            chunk = " ".join(words[i:i+2]) + " "
            yield chunk
            await asyncio.sleep(0.02) # Subtle delay for natural feel

    except Exception as e:
        logger.error(f"❌ [Orchestrator] Global failure: {e}")
        yield f"\n[System Error: Orchestration failed. Last error: {str(e)}]"

async def generate(contents: list[dict], type: str = "generate") -> str:
    """
    Always-on Orchestration (Non-streaming).
    """
    prompt_text = ""
    for item in contents:
        for part in item.get("parts", []):
            if "text" in part:
                prompt_text += part["text"]

    result = await orchestrator_service.orchestrator.get_parallel_response(
        prompt=prompt_text,
        user_level="intermediate"
    )
    return result["answer"]
