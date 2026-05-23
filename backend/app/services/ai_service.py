import logging
import asyncio
from typing import AsyncGenerator
from app.services import gemini_service, groq_service, orchestrator_service
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

async def stream_generate(
    contents: list[dict], 
    type: str = "generate",
    temperature: float = None,
    max_output_tokens: int = None,
    api_key: str = None,
    custom_api_keys: dict = None
) -> AsyncGenerator[str, None]:
    """
    Always-on Orchestration: Queries multiple models in parallel
    and streams the synthesized result.
    """
    try:
        logger.info(f"🚀 [AI Service] Primary stream (Gemini) initiated for: {type}")
        
        # 1. Try Gemini with a strict watchdog timer
        # If Gemini doesn't yield a single chunk in 10s, it's considered failed
        gemini_stream = gemini_service.stream_generate(
            contents,
            temperature=temperature,
            max_output_tokens=max_output_tokens,
            api_key=api_key
        )
        iterator = gemini_stream.__aiter__()
        try:
            # Wait for the first chunk to arrive to verify Gemini is healthy
            first_chunk = await asyncio.wait_for(iterator.__anext__(), timeout=10.0)
            yield first_chunk
            
            # Once started, continue the stream normally
            async for chunk in iterator:
                yield chunk
        except (asyncio.TimeoutError, Exception) as e:
            logger.error(f"⚠️ Gemini watchdog triggered or failed: {e}. Pivoting to Groq...")
            raise e # Trigger the catch block below for Groq fallback
 
    except Exception as e:
        logger.error(f"Attempting Groq fallback due to: {e}")
        try:
            # 2. Fallback to Groq for reliability
            messages = []
            for item in contents:
                messages.append({"role": item["role"], "content": "".join([p.get("text", "") for p in item.get("parts", [])])})
            
            async for chunk in groq_service.stream_generate(
                messages,
                temperature=temperature,
                max_tokens=max_output_tokens,
                api_key=custom_api_keys.get("groq") if custom_api_keys else None
            ):
                yield chunk
        except Exception as groq_e:
            logger.error(f"⚠️ Groq fallback failed: {groq_e}. Attempting OMNI-POOL failover...")
            try:
                # 3. Omni-Pool Fallback: Try all free models from orchestrator
                from .orchestrator_service import orchestrator
                from . import openrouter_service
                
                # Convert contents to common format
                messages = []
                for item in contents:
                    messages.append({"role": item["role"], "content": "".join([p.get("text", "") for p in item.get("parts", [])])})
                
                success = False
                pool_attempts = 0
                max_pool_attempts = 2
                
                for model_id in orchestrator.free_pool:
                    if pool_attempts >= max_pool_attempts:
                        logger.warning(f"⏩ Pool fallback limit reached ({max_pool_attempts}). Moving to final safety net.")
                        break
                        
                    try:
                        logger.info(f"🔄 Attempting OMNI-FAILOVER with: {model_id}")
                        async for chunk in openrouter_service.stream_generate(
                            messages, 
                            model=model_id,
                            temperature=temperature,
                            max_tokens=max_output_tokens,
                            api_key=custom_api_keys.get("openrouter") if custom_api_keys else None
                        ):
                            yield chunk
                        success = True
                        break # Exit pool loop on success
                    except Exception as pool_e:
                        pool_attempts += 1
                        logger.warning(f"⏩ Pool model {model_id} failed: {pool_e}. Trying next...")
                        continue
                
                if not success:
                    # 4. Final Safety Net: Hugging Face
                    from . import huggingface_service
                    async for chunk in huggingface_service.stream_generate(messages):
                        yield chunk
            except Exception as hf_e:
                logger.error(f"❌ All AI failovers exhausted: {hf_e}")
                yield f"\nCode Genie failed to respond. (System Error: {hf_e})"

async def generate(
    contents: list[dict], 
    type: str = "generate",
    temperature: float = None,
    max_output_tokens: int = None
) -> str:
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
