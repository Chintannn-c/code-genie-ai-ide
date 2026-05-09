import httpx
import asyncio

async def test():
    models = [
        "mistralai/Mistral-7B-Instruct-v0.2",
        "mistralai/Mistral-7B-Instruct-v0.3",
        "HuggingFaceH4/zephyr-7b-beta"
    ]
    
    async with httpx.AsyncClient() as client:
        for model in models:
            url = f"https://api-inference.huggingface.co/models/{model}"
            r = await client.post(url, json={"inputs": "hello"})
            print(f"{model}: {r.status_code}")

asyncio.run(test())
