import json
import logging
import httpx
from typing import AsyncGenerator
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

GROQ_API_BASE = "https://api.groq.com/openai/v1/chat/completions"

def sanitize_messages(messages: list[dict]) -> list[dict]:
    """Ensures roles are compatible with Groq API (system, user, assistant)."""
    sanitized = []
    for msg in messages:
        # Map our internal 'ai' role to Groq's 'assistant'
        role = msg.get("role", "user")
        if role == "ai":
            role = "assistant"
        elif role not in ["system", "user", "assistant"]:
            role = "user"
            
        sanitized.append({
            "role": role, 
            "content": str(msg.get("content", ""))
        })
    return sanitized

async def stream_generate(
    messages: list[dict], 
    model: str = "llama-3.3-70b-versatile",
    temperature: float = None,
    max_tokens: int = None,
    api_key: str = None
) -> AsyncGenerator[str, None]:
    settings = get_settings()
    active_key = api_key or settings.GROQ_API_KEY
    if not active_key:
        yield "[Error: Groq API Key is missing in .env]"
        return

    # Sanitize and prepend system instruction
    messages = sanitize_messages(messages)
    messages.insert(0, {"role": "system", "content": SYSTEM_INSTRUCTION})

    headers = {
        "Authorization": f"Bearer {active_key}",
        "Content-Type": "application/json",
    }

    payload = {
        "model": model,
        "messages": messages,
        "temperature": temperature if temperature is not None else 0.7,
        "max_tokens": max_tokens if max_tokens is not None else 1024,
        "stream": True,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream("POST", GROQ_API_BASE, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    text = await response.aread()
                    yield f"[Error: Groq API returned {response.status_code} - {text.decode('utf-8')}]"
                    return

                async for line in response.aiter_lines():
                    line = line.strip()
                    if line.startswith("data: "):
                        data_str = line[6:]
                        if data_str == "[DONE]":
                            break
                        try:
                            data = json.loads(data_str)
                            content = data["choices"][0]["delta"].get("content", "")
                            if content:
                                yield content
                        except json.JSONDecodeError:
                            continue
    except Exception as e:
        logger.error(f"Groq Stream Error: {e}")
        yield f"[Error: {str(e)}]"

async def generate(messages: list[dict], model: str = "llama-3.3-70b-versatile") -> str:
    settings = get_settings()
    if not settings.GROQ_API_KEY:
        return "[Error: Groq API Key is missing in .env]"

    headers = {
        "Authorization": f"Bearer {settings.GROQ_API_KEY}",
        "Content-Type": "application/json",
    }

    # Sanitize and prepend system instruction
    messages = sanitize_messages(messages)
    messages.insert(0, {"role": "system", "content": SYSTEM_INSTRUCTION})

    payload = {
        "model": model,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 1024,
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(GROQ_API_BASE, headers=headers, json=payload)
            if response.status_code != 200:
                return f"[Error: Groq API returned {response.status_code} - {response.text}]"
            
            data = response.json()
            return data["choices"][0]["message"].get("content", "")
    except Exception as e:
        logger.error(f"Groq Error: {e}")
        return f"[Error: {str(e)}]"
