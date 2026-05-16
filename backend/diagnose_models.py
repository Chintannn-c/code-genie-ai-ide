import os
from google import genai
from dotenv import load_dotenv

load_dotenv()

keys = [os.getenv("GEMINI_API_KEY_1"), os.getenv("GEMINI_API_KEY_2")]

for i, key in enumerate(keys):
    print(f"\n--- Checking Key #{i+1} ---")
    if not key:
        print(f"[MISSING] Key #{i+1} is MISSING from .env")
        continue
    
    # Redacted print for security
    print(f"Key starts with: {key[:8]}... (Total length: {len(key)})")
    
    if len(key) < 30:
        print(f"[WARNING] Key #{i+1} looks TOO SHORT. Standard keys are ~39 chars.")
        continue

    client = genai.Client(api_key=key)
    try:
        # Just try to list models to verify the key
        print("Available Models:")
        models = client.models.list()
        for model in models:
            print(f"  - {model.name}")
        print(f"[VALID] Key #{i+1} is VALID.")
    except Exception as e:
        print(f"[INVALID] Key #{i+1} is INVALID. Error: {e}")

print("\n--- Diagnostic Complete ---")
