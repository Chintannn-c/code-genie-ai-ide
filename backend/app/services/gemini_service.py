import logging
from typing import AsyncGenerator
from google import genai
from google.genai import types
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

_client: genai.Client | None = None


def get_gemini_client() -> genai.Client:
    """Get or create the Gemini client."""
    global _client
    if _client is None:
        settings = get_settings()
        # Use aio=True or similar if available, but usually we just use client.aio for async calls
        _client = genai.Client(api_key=settings.GEMINI_API_KEY)
        logger.info("Gemini client initialized.")
    return _client


async def stream_generate(contents: list[dict]) -> AsyncGenerator[str, None]:
    """
    Stream a response from Gemini API with automatic model failover.
    If the primary model is unavailable (503/429), it tries fallback models.
    """
    settings = get_settings()
    client = get_gemini_client()
    
    # Prioritized list of models to try
    models_to_try = [
        settings.GEMINI_MODEL,           # 1. Gemini 3.1 Pro (Preferred)
        "gemini-3.1-flash",              # 2. High-Speed 3.1 Fallback
        "gemini-3-flash",                # 3. Stable 3.0 Fallback
    ]
    
    # Remove duplicates while preserving order
    models_to_try = list(dict.fromkeys(models_to_try))
    
    last_error = None
    
    for model_name in models_to_try:
        try:
            logger.info(f"Attempting stream with model: {model_name}")
            response = await client.aio.models.generate_content_stream(
                model=model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_INSTRUCTION,
                    temperature=0.7,
                    max_output_tokens=8192,
                ),
            )

            async for chunk in response:
                try:
                    text = chunk.text
                    if text:
                        yield text
                except Exception:
                    continue
            
            logger.info(f"Stream completed successfully using {model_name}.")
            return # Success! Exit the failover loop

        except Exception as e:
            last_error = e
            error_str = str(e).upper()
            
            # Check if we should retry with a different model
            if "503" in error_str or "429" in error_str or "UNAVAILABLE" in error_str:
                logger.warning(f"Model {model_name} failed ({error_str}). Trying next fallback...")
                continue
            else:
                # If it's a different kind of error (e.g. 401 Unauthorized), don't bother retrying
                logger.error(f"Fatal Gemini error with {model_name}: {e}")
                break

    # If we get here, all models failed
    yield f"\n[Error: All AI engines are currently unavailable. Please try again in a few seconds. (Last error: {last_error})]"


async def generate(contents: list[dict]) -> str:
    """
    Generate a complete response from Gemini API with automatic model failover.
    """
    settings = get_settings()
    client = get_gemini_client()

    models_to_try = [
        settings.GEMINI_MODEL,
        "gemini-3.1-flash",
        "gemini-3-flash",
    ]
    models_to_try = list(dict.fromkeys(models_to_try))

    last_error = None
    for model_name in models_to_try:
        try:
            logger.info(f"Attempting generate with model: {model_name}")
            response = await client.aio.models.generate_content(
                model=model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_INSTRUCTION,
                    temperature=0.7,
                    max_output_tokens=8192,
                ),
            )
            return response.text or "No response generated."
        except Exception as e:
            last_error = e
            error_str = str(e).upper()
            if "503" in error_str or "429" in error_str or "UNAVAILABLE" in error_str:
                logger.warning(f"Model {model_name} failed ({error_str}). Trying next fallback...")
                continue
            else:
                logger.error(f"Fatal Gemini error with {model_name}: {e}")
                break

    raise RuntimeError(f"All AI engines are currently unavailable. Last error: {last_error}")
