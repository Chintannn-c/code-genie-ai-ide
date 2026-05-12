import os
from pyngrok import ngrok
from dotenv import load_dotenv

def start_tunnel():
    # Load .env file
    load_dotenv()
    
    # Get auth token from env (optional but recommended for longer sessions)
    auth_token = os.getenv("NGROK_AUTH_TOKEN")
    if auth_token:
        ngrok.set_auth_token(auth_token)
        print("[INFO] Ngrok Auth Token set from .env")
    else:
        print("[WARN] No NGROK_AUTH_TOKEN found in .env. Tunnel may expire quickly.")
    
    # Start the tunnel on port 8000
    public_url = ngrok.connect(8000).public_url
    
    print("\n" + "="*50)
    print("NGROK TUNNEL IS LIVE!")
    print(f"Public URL: {public_url}")
    print(f"WebSocket: {public_url.replace('http', 'ws')}/ws/{{user_id}}")
    print("="*50 + "\n")
    
    print("Update 'lib/config/api_config.dart' with this new URL.")
    print("Press Ctrl+C to close the tunnel.\n")

    try:
        # Keep the tunnel open
        ngrok_process = ngrok.get_ngrok_process()
        ngrok_process.proc.wait()
    except KeyboardInterrupt:
        print("\nClosing tunnel...")
        ngrok.kill()

if __name__ == "__main__":
    start_tunnel()
