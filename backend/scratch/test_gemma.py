import os
import time
from google import genai
from dotenv import load_dotenv

load_dotenv()

def test_gemma_model(model_name):
    key = os.getenv("GEMINI_API_KEY_1") or os.getenv("GEMINI_API_KEY_2")
    if not key:
        print("[-] No GEMINI_API_KEY found in .env")
        return
    
    print(f"\n[*] Testing {model_name} with Gemini key ending in ...{key[-4:]}")
    try:
        client = genai.Client(api_key=key)
        start_time = time.time()
        response = client.models.generate_content(
            model=model_name,
            contents='Respond with only the word "OK" if you receive this.'
        )
        latency = round(time.time() - start_time, 2)
        print(f"[+] SUCCESS | Model: {model_name} | Latency: {latency}s | Response: '{response.text.strip()}'")
    except Exception as e:
        print(f"[x] FAILED | Model: {model_name} | Error: {e}")

if __name__ == "__main__":
    test_gemma_model("gemma-4-26b-a4b-it")
    test_gemma_model("gemma-4-31b-it")
