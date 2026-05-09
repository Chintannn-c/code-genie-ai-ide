import requests
import json

def test_stream():
    url = "http://127.0.0.1:8000/api/stream"
    payload = {
        "user_id": "test_user",
        "type": "generate",
        "prompt": "Write a simple python hello world function",
        "language": "python"
    }
    
    print(f"Connecting to {url}...")
    try:
        response = requests.post(url, json=payload, stream=True, timeout=10)
        print(f"Status Code: {response.status_code}")
        
        for line in response.iter_lines():
            if line:
                line_str = line.decode('utf-8')
                print(f"Received: {line_str}")
                if "[DONE]" in line_str:
                    print("Stream finished successfully!")
                    break
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    test_stream()
