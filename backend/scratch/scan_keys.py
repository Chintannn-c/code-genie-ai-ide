import os
import time
import httpx
from google import genai
from dotenv import load_dotenv

# Load env variables
load_dotenv()

def print_banner(text):
    print("\n" + "=" * 60)
    print(f" {text.upper()} ")
    print("=" * 60)

def test_gemini(key, key_name):
    if not key:
        print(f"[-] {key_name} is not set in .env")
        return None
    
    print(f"[*] Testing {key_name} (starts with {key[:8]}...)")
    try:
        client = genai.Client(api_key=key)
        start_time = time.time()
        # Test with gemini-2.5-flash
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents='Respond with only the word "OK".'
        )
        latency = round(time.time() - start_time, 2)
        text = response.text.strip()
        print(f"[+] VALID | Latency: {latency}s | Response: '{text}'")
        return {"valid": True, "latency": latency, "model": "gemini-2.5-flash", "note": "High rate limits, highly capable, free tier"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def test_groq(key):
    if not key:
        print("[-] GROQ_API_KEY is not set in .env")
        return None
    
    print(f"[*] Testing GROQ_API_KEY (starts with {key[:8]}...)")
    try:
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "llama-3.3-70b-versatile",
            "messages": [{"role": "user", "content": 'Respond with only the word "OK".'}],
            "max_tokens": 10
        }
        start_time = time.time()
        response = httpx.post(
            "https://api.groq.com/openai/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        latency = round(time.time() - start_time, 2)
        
        if response.status_code == 200:
            data = response.json()
            text = data["choices"][0]["message"]["content"].strip()
            print(f"[+] VALID | Latency: {latency}s | Response: '{text}'")
            return {"valid": True, "latency": latency, "model": "llama-3.3-70b-versatile", "note": "Blazing fast speed, extremely strong 70B model, free tier has strict rate limits"}
        else:
            print(f"[x] INVALID | HTTP {response.status_code} | Response: {response.text}")
            return {"valid": False, "error": f"HTTP {response.status_code}: {response.text}"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def test_openrouter(key):
    if not key:
        print("[-] OPENROUTER_API_KEY is not set in .env")
        return None
    
    print(f"[*] Testing OPENROUTER_API_KEY (starts with {key[:8]}...)")
    try:
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "meta-llama/llama-3.3-70b-instruct:free",
            "messages": [{"role": "user", "content": 'Respond with only the word "OK".'}],
            "max_tokens": 10
        }
        start_time = time.time()
        response = httpx.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        latency = round(time.time() - start_time, 2)
        
        if response.status_code == 200:
            data = response.json()
            text = data["choices"][0]["message"]["content"].strip()
            print(f"[+] VALID | Latency: {latency}s | Response: '{text}'")
            return {"valid": True, "latency": latency, "model": "llama-3.3-70b-instruct:free", "note": "Gives access to many different free models, but free tier can be highly congested or slow"}
        else:
            print(f"[x] INVALID | HTTP {response.status_code} | Response: {response.text}")
            return {"valid": False, "error": f"HTTP {response.status_code}: {response.text}"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def test_github(key):
    if not key:
        print("[-] GITHUB_API_KEY is not set in .env")
        return None
    
    print(f"[*] Testing GITHUB_API_KEY (starts with {key[:8]}...)")
    try:
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "gpt-4o-mini",
            "messages": [{"role": "user", "content": 'Respond with only the word "OK".'}],
            "max_tokens": 10
        }
        start_time = time.time()
        response = httpx.post(
            "https://models.inference.ai.azure.com/chat/completions",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        latency = round(time.time() - start_time, 2)
        
        if response.status_code == 200:
            data = response.json()
            text = data["choices"][0]["message"]["content"].strip()
            print(f"[+] VALID | Latency: {latency}s | Response: '{text}'")
            return {"valid": True, "latency": latency, "model": "gpt-4o-mini", "note": "High rate limits, premium models (GPT-4o-mini, Llama 3.1) entirely free for developers"}
        else:
            print(f"[x] INVALID | HTTP {response.status_code} | Response: {response.text}")
            return {"valid": False, "error": f"HTTP {response.status_code}: {response.text}"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def test_mistral(key):
    if not key:
        print("[-] MISTRAL_API_KEY is not set in .env")
        return None
    
    print(f"[*] Testing MISTRAL_API_KEY (starts with {key[:8]}...)")
    try:
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "mistral-large-latest",
            "messages": [{"role": "user", "content": 'Respond with only the word "OK".'}],
            "max_tokens": 10
        }
        start_time = time.time()
        response = httpx.post(
            "https://api.mistral.ai/v1/chat/completions",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        latency = round(time.time() - start_time, 2)
        
        if response.status_code == 200:
            data = response.json()
            text = data["choices"][0]["message"]["content"].strip()
            print(f"[+] VALID | Latency: {latency}s | Response: '{text}'")
            return {"valid": True, "latency": latency, "model": "mistral-large-latest", "note": "Very strong European model, free tier key"}
        else:
            print(f"[x] INVALID | HTTP {response.status_code} | Response: {response.text}")
            return {"valid": False, "error": f"HTTP {response.status_code}: {response.text}"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def test_huggingface(key):
    if not key:
        print("[-] HUGGINGFACE_API_KEY is not set in .env")
        return None
    
    print(f"[*] Testing HUGGINGFACE_API_KEY (starts with {key[:8]}...)")
    try:
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        payload = {
            "inputs": "<s>[INST] Respond with only the word 'OK'. [/INST]"
        }
        start_time = time.time()
        response = httpx.post(
            "https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.3",
            headers=headers,
            json=payload,
            timeout=10.0
        )
        latency = round(time.time() - start_time, 2)
        
        if response.status_code == 200:
            data = response.json()
            text = data[0].get("generated_text", "") if isinstance(data, list) else data.get("generated_text", "")
            # clean response to just the text if instructions present
            if "[/INST]" in text:
                text = text.split("[/INST]")[-1].strip()
            print(f"[+] VALID | Latency: {latency}s | Response: '{text[:20]}...'")
            return {"valid": True, "latency": latency, "model": "Mistral-7B-Instruct-v0.3", "note": "HF inference endpoints are good for custom open-source models, free but can sleep/cold-start"}
        else:
            print(f"[x] INVALID | HTTP {response.status_code} | Response: {response.text}")
            return {"valid": False, "error": f"HTTP {response.status_code}: {response.text}"}
    except Exception as e:
        print(f"[x] INVALID | Error: {e}")
        return {"valid": False, "error": str(e)}

def main():
    print_banner("Code Genie 2.0 - API Keys Diagnostic Scan")
    
    results = {}
    
    # 1. Gemini Key 1
    results["GEMINI_API_KEY_1"] = test_gemini(os.getenv("GEMINI_API_KEY_1"), "GEMINI_API_KEY_1")
    
    # 2. Gemini Key 2
    results["GEMINI_API_KEY_2"] = test_gemini(os.getenv("GEMINI_API_KEY_2"), "GEMINI_API_KEY_2")
    
    # 3. Groq Key
    results["GROQ_API_KEY"] = test_groq(os.getenv("GROQ_API_KEY"))
    
    # 4. OpenRouter Key
    results["OPENROUTER_API_KEY"] = test_openrouter(os.getenv("OPENROUTER_API_KEY"))
    
    # 5. GitHub Key
    results["GITHUB_API_KEY"] = test_github(os.getenv("GITHUB_API_KEY"))
    
    # 6. Mistral Key
    results["MISTRAL_API_KEY"] = test_mistral(os.getenv("MISTRAL_API_KEY"))
    
    # 7. HuggingFace Key
    results["HUGGINGFACE_API_KEY"] = test_huggingface(os.getenv("HUGGINGFACE_API_KEY"))
    
    print_banner("Summary of Free Model Capabilities")
    valid_count = 0
    for key, res in results.items():
        if res and res.get("valid"):
            valid_count += 1
            print(f"[OK] {key:20} | Model: {res['model']:30} | Latency: {res['latency']}s")
            print(f"    +- Note: {res['note']}\n")
        elif res:
            print(f"[ERR] {key:20} | FAILED | Error: {res.get('error')[:60]}...\n")
            
    print(f"Scan complete. Found {valid_count} valid key(s).")

if __name__ == "__main__":
    main()
