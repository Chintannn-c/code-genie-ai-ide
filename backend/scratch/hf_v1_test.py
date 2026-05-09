import httpx
import asyncio
import os
from dotenv import load_dotenv

load_dotenv()

async def test():
    hf_key = os.getenv("HUGGINGFACE_API_KEY")
    headers = {"Authorization": f"Bearer {hf_key}"}
    
    # Try the v1/chat/completions structure
    urls = [
        "https://api-inference.huggingface.co/v1/chat/completions",
        "https://api-inference.huggingface.co/models/HuggingFaceH4/zephyr-7b-beta/v1/chat/completions"
    ]
    
    payload = {
        "model": "HuggingFaceH4/zephyr-7b-beta",
        "messages": [{"role": "user", "content": "hello"}],
        "max_tokens": 10
    }
    
    async with httpx.AsyncClient() as client:
        for url in urls:
            r = await client.post(url, headers=headers, json=payload)
            print(f"{url}: {r.status_code}")
            if r.status_code == 200:
                print(r.json())

asyncio.run(test())
