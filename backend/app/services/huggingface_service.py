import json
import logging
import httpx
from typing import AsyncGenerator
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

# Standard Hugging Face Inference API URL pattern
HF_API_BASE_URL = "https://api-inference.huggingface.co/models/"

async def stream_generate(prompt: str, model: str = "mistralai/Mistral-7B-Instruct-v0.2") -> AsyncGenerator[str, None]:
    """
    Stream a response from Hugging Face Inference API.
    Note: Not all HF models support standard streaming via Inference API, 
    but we'll implement it for those that do (SSE).
    """
    settings = get_settings()
    if not settings.HUGGINGFACE_API_KEY:
        yield "[Error: Hugging Face API Key is missing.]"
        return

    url = f"{HF_API_BASE_URL}{model}"
    headers = {
        "Authorization": f"Bearer {settings.HUGGINGFACE_API_KEY}",
        "Content-Type": "application/json",
    }

    # Prep prompt with system instruction
    full_prompt = f"{SYSTEM_INSTRUCTION}\n\nUser: {prompt}\nAssistant:"

    payload = {
        "inputs": full_prompt,
        "parameters": {
            "max_new_tokens": 1024,
            "temperature": 0.7,
            "return_full_text": False,
        },
        "options": {
            "use_cache": True,
            "wait_for_model": True,
        }
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                yield f"[Error: Hugging Face API returned {response.status_code} - {response.text}]"
                return

            data = response.json()
            # HF Inference API usually returns a list for non-streaming
            if isinstance(data, list) and len(data) > 0:
                text = data[0].get("generated_text", "")
                if text:
                    yield text
            else:
                yield "[Error: Unexpected response format from Hugging Face.]"

    except Exception as e:
        logger.error(f"Hugging Face Error: {e}")
        yield f"[Error: {str(e)}]"

async def generate(prompt: str, model: str = "mistralai/Mistral-7B-Instruct-v0.2") -> str:
    """
    Generate a complete response from Hugging Face Inference API.
    """
    settings = get_settings()
    if not settings.HUGGINGFACE_API_KEY:
        return "[Error: Hugging Face API Key is missing.]"

    url = f"{HF_API_BASE_URL}{model}"
    headers = {
        "Authorization": f"Bearer {settings.HUGGINGFACE_API_KEY}",
        "Content-Type": "application/json",
    }

    full_prompt = f"{SYSTEM_INSTRUCTION}\n\nUser: {prompt}\nAssistant:"

    payload = {
        "inputs": full_prompt,
        "parameters": {
            "max_new_tokens": 1024,
            "temperature": 0.7,
            "return_full_text": False,
        }
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                return f"[Error: Hugging Face API returned {response.status_code}]"
            
            data = response.json()
            if isinstance(data, list) and len(data) > 0:
                return data[0].get("generated_text", "")
            return "[Error: Unexpected response format]"
    except Exception as e:
        logger.error(f"Hugging Face Error: {e}")
        return f"[Error: {str(e)}]"
