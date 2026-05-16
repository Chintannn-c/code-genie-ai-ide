import json
import logging
import httpx
from typing import AsyncGenerator
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# Comprehensive list of currently available FREE models on OpenRouter
FREE_MODELS = [
    "meta-llama/llama-3.3-70b-instruct:free",
    "qwen/qwen-2.5-coder-32b:free",
    "openai/gpt-oss-120b:free",
    "google/gemini-3.1-flash:free",
    "google/gemini-3.1-pro:free",
    "google/gemini-3-pro:free",
    "google/gemini-3-flash:free",
    "google/gemini-2.0-flash-exp:free",
    "google/gemini-pro-1.5:free",
    "google/lyria-3-pro-preview",
    "qwen/qwen3-coder:free",
    "z-ai/glm-4.5-air:free",
    "nousresearch/hermes-3-llama-3.1-405b:free",
    "liquid/lfm-2.5-1.2b-thinking:free",
    "nvidia/nemotron-3-super-120b-a12b:free",
    "google/gemma-4-31b-it:free",
    "meta-llama/llama-3.2-3b-instruct:free",
    "openai/gpt-oss-120b:free",
    "openrouter/owl-alpha",
    "liquid/lfm-2.5-1.2b-instruct:free",
    "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"
]

# List of models that are free but might not have the :free suffix
VERIFIED_FREE_MODELS = [
    "google/gemini-3.1-pro",
    "google/gemini-3.1-flash",
    "google/gemini-3-pro",
    "google/gemini-3-flash",
    "google/gemini-2.0-flash-exp",
    "google/gemini-pro-1.5",
    "google/gemini-flash-1.5",
    "google/lyria-3-pro-preview"
]

def validate_free_model(model_id: str):
    """
    CRITICAL SAFETY FILTER: Ensures we NEVER call a paid model by accident.
    """
    if ":free" in model_id or model_id in VERIFIED_FREE_MODELS:
        return True
    
    logger.error(f"❌ BLOCKING PAID MODEL CALL: {model_id}")
    raise ValueError(f"Safety Error: {model_id} is not a verified FREE model. Request blocked to prevent billing.")

async def stream_generate(messages: list[dict], model: str = "meta-llama/llama-3.3-70b-instruct:free") -> AsyncGenerator[str, None]:
    """
    Stream a response from OpenRouter API.
    """
    # 1. Enforce safety check
    validate_free_model(model)
    
    settings = get_settings()
    if not settings.OPENROUTER_API_KEY:
        yield "[Error: OpenRouter API Key is missing. Please check your .env file.]"
        return

    headers = {
        "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://localhost:3000", # Optional, for OpenRouter analytics
        "X-Title": "Code Genie AI",
    }

    # Prep messages with system instruction
    full_messages = [{"role": "system", "content": SYSTEM_INSTRUCTION}] + messages

    payload = {
        "model": model,
        "messages": full_messages,
        "stream": True,
        "temperature": 0.7,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream("POST", OPENROUTER_URL, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    error_body = await response.aread()
                    yield f"[Error: OpenRouter API returned {response.status_code} - {error_body.decode()}]"
                    return

                async for line in response.aiter_lines():
                    if not line or not line.startswith("data: "):
                        continue
                    
                    data_str = line[6:].strip()
                    if data_str == "[DONE]":
                        break
                    
                    try:
                        data = json.loads(data_str)
                        content = data["choices"][0]["delta"].get("content", "")
                        if content and content.strip():
                            yield content
                    except Exception as e:
                        logger.error(f"Error parsing OpenRouter chunk: {e}")
                        continue

    except Exception as e:
        logger.error(f"OpenRouter Connection Error: {e}")
        yield f"[Error: Could not connect to OpenRouter. {str(e)}]"

async def generate(messages: list[dict], model: str = "meta-llama/llama-3.3-70b-instruct:free") -> str:
    """
    Generate a complete response from OpenRouter API.
    """
    settings = get_settings()
    if not settings.OPENROUTER_API_KEY:
        return "[Error: OpenRouter API Key is missing.]"

    headers = {
        "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }

    full_messages = [{"role": "system", "content": SYSTEM_INSTRUCTION}] + messages

    payload = {
        "model": model,
        "messages": full_messages,
        "temperature": 0.7,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(OPENROUTER_URL, headers=headers, json=payload)
            if response.status_code != 200:
                return f"[Error: OpenRouter API returned {response.status_code}]"
            
            data = response.json()
            return data["choices"][0]["message"]["content"]
    except Exception as e:
        logger.error(f"OpenRouter Error: {e}")
        return f"[Error: {str(e)}]"
