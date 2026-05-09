import httpx
import asyncio
import os
from dotenv import load_dotenv

load_dotenv()

async def test():
    hf_key = os.getenv("HUGGINGFACE_API_KEY")
    headers = {"Authorization": f"Bearer {hf_key}"}
    
    url = "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.2/v1/chat/completions"
    
    payload = {
        "model": "mistralai/Mistral-7B-Instruct-v0.2",
        "messages": [{"role": "user", "content": "hello"}],
        "max_tokens": 10
    }
    
    async with httpx.AsyncClient() as client:
        r = await client.post(url, headers=headers, json=payload)
        print(f"Status: {r.status_code}")
        print(f"Body: {r.text}")

asyncio.run(test())
