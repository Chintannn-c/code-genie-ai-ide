import httpx
import asyncio

async def test():
    models = [
        "google/gemma-7b-it",
        "Qwen/Qwen2.5-7B-Instruct",
        "meta-llama/Llama-3.2-3B-Instruct",
        "distilbert-base-uncased-finetuned-sst-2-english"
    ]
    
    async with httpx.AsyncClient() as client:
        for model in models:
            url = f"https://api-inference.huggingface.co/models/{model}"
            r = await client.post(url, json={"inputs": "hello"})
            print(f"{model}: {r.status_code}")

asyncio.run(test())
