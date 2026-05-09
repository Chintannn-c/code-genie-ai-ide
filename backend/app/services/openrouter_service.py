import json
import logging
import httpx
from typing import AsyncGenerator
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

async def stream_generate(messages: list[dict], model: str = "mistralai/mistral-7b-instruct") -> AsyncGenerator[str, None]:
    """
    Stream a response from OpenRouter API.
    """
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
                        if content:
                            yield content
                    except Exception as e:
                        logger.error(f"Error parsing OpenRouter chunk: {e}")
                        continue

    except Exception as e:
        logger.error(f"OpenRouter Connection Error: {e}")
        yield f"[Error: Could not connect to OpenRouter. {str(e)}]"

async def generate(messages: list[dict], model: str = "mistralai/mistral-7b-instruct") -> str:
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
