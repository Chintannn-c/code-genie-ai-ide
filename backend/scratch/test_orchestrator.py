import asyncio
import os
import sys
from dotenv import load_dotenv

# Ensure backend directory is in python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Load environment
load_dotenv()

async def main():
    print("============================================================")
    print(" TESTING CODE GENIE 2.0 ORCHESTRATION PIPELINE WITH GEMMA 4 ")
    print("============================================================")
    
    # Check if mongo/redis are running, if not, mock or let them fail gracefully
    # We will import the orchestrator now
    try:
        from app.services.orchestrator_service import orchestrator
        from app.config import get_settings
        
        settings = get_settings()
        print(f"Loaded config. GEMINI_MODEL default is: {settings.GEMINI_MODEL}")
        
        prompt = "Design a simple microservice that handles user registration. Explain the architecture."
        print(f"\n[*] Running prompt: '{prompt}'...")
        print("[*] Calling get_collaborative_response...")
        
        # Execute the collaborative pipeline
        response = await orchestrator.get_collaborative_response(
            prompt=prompt,
            history=[],
            user_id="dev_tester",
            user_level="intermediate"
        )
        
        print("\n==================== ORCHESTRATION RESULT ====================")
        print(f"Strategy used: {response.get('strategy')}")
        print(f"Task Type: {response.get('task_type')}")
        print(f"Latency: {response.get('latency')}s")
        print(f"Models Participated: {response.get('models_participated')}")
        print("\n--- Synthesis Summary Preview ---")
        answer = response.get('answer', '') or ""
        # Safe encode print to avoid Windows charmap encoding errors
        safe_answer = answer.encode('ascii', errors='ignore').decode('ascii')
        print(safe_answer[:500] + "\n..." if len(safe_answer) > 500 else safe_answer)
        print("==============================================================")
        
    except Exception as e:
        print(f"\n[x] Orchestrator test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
