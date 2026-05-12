import json
import logging
import httpx
from typing import AsyncGenerator
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

HF_API_BASE = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3"

async def stream_generate(messages: list[dict]) -> AsyncGenerator[str, None]:
    settings = get_settings()
    if not settings.HUGGINGFACE_API_KEY:
        yield "[Error: Hugging Face API Key is missing in .env]"
        return

    headers = {
        "Authorization": f"Bearer {settings.HUGGINGFACE_API_KEY}",
        "Content-Type": "application/json",
    }

    # Format prompt for Mistral
    prompt = f"<s>[INST] {SYSTEM_INSTRUCTION}\n\n"
    for msg in messages:
        role = "User" if msg["role"] == "user" else "Assistant"
        prompt += f"{role}: {msg['content']}\n"
    prompt += "[/INST]"

    payload = {
        "inputs": prompt,
        "parameters": {
            "max_new_tokens": 1024,
            "temperature": 0.7,
            "return_full_text": False,
        },
        "stream": True
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream("POST", HF_API_BASE, headers=headers, json=payload) as response:
                if response.status_code != 200:
                    text = await response.aread()
                    yield f"[Error: Hugging Face API returned {response.status_code}]"
                    return

                async for line in response.aiter_lines():
                    line = line.strip()
                    if line.startswith("data:"):
                        try:
                            data = json.loads(line[5:])
                            content = data.get("token", {}).get("text", "")
                            if content and content != "</s>":
                                yield content
                        except:
                            continue
    except Exception as e:
        logger.error(f"Hugging Face Stream Error: {e}")
        yield f"[Error: {str(e)}]"
