import logging
from typing import AsyncGenerator
from google import genai
from google.genai import types
from app.config import get_settings
from app.prompts.templates import SYSTEM_INSTRUCTION

logger = logging.getLogger(__name__)

# Cache for multiple clients
_clients: list[genai.Client] = []

def get_gemini_clients() -> list[genai.Client]:
    """Get or create the pool of Gemini clients based on rotated keys."""
    global _clients
    if not _clients:
        settings = get_settings()
        keys = settings.gemini_keys
        if not keys:
            logger.error("No GEMINI_API_KEY found in settings!")
            return []
            
        for key in keys:
            try:
                client = genai.Client(api_key=key)
                _clients.append(client)
            except Exception as e:
                logger.error(f"Failed to initialize Gemini client for key ending in ...{key[-4:]}: {e}")
        
        logger.info(f"Initialized {len(_clients)} Gemini clients for rotation.")
    return _clients

async def stream_generate(
    contents: list[dict], 
    model: str = None,
    temperature: float = None,
    max_output_tokens: int = None,
    api_key: str = None
) -> AsyncGenerator[str, None]:
    """
    Stream a response from Gemini API with automatic model AND key rotation failover.
    """
    settings = get_settings()
    
    # Custom API Key overrides from client settings
    if api_key and api_key.strip():
        try:
            logger.info("Using custom client Gemini API key override")
            clients = [genai.Client(api_key=api_key)]
        except Exception as e:
            logger.error(f"Failed to initialize custom Gemini client: {e}")
            clients = get_gemini_clients()
    else:
        clients = get_gemini_clients()
    
    if not clients:
        yield "\n[Error: No valid Gemini API keys configured. Check your Railway/Local variables.]"
        return

    # Failover strategy: Try each model with each key if necessary
    # Using more stable model aliases to avoid 404s
    models_to_try = [
        model or settings.GEMINI_MODEL, 
        "gemma-4-31b-it",
        "gemma-4-26b-a4b-it",
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash-lite",
        "gemini-pro-latest",
        "gemini-flash-latest",
    ]
    models_to_try = list(dict.fromkeys(models_to_try))
    
    last_error = None
    
    # Outer loop: Rotate models
    for model_name in models_to_try:
        # Inner loop: Rotate keys (clients) for the current model
        for i, client in enumerate(clients):
            try:
                logger.info(f"Attempting stream with model {model_name} (Key #{i+1})")
                response = await client.aio.models.generate_content_stream(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        temperature=temperature if temperature is not None else 0.7,
                        max_output_tokens=max_output_tokens if max_output_tokens is not None else 8192,
                    ),
                )

                async for chunk in response:
                    try:
                        text = chunk.text
                        if text:
                            yield text
                    except Exception:
                        continue
                
                logger.info(f"Stream completed successfully using {model_name} (Key #{i+1}).")
                return # Success! Exit both loops

            except Exception as e:
                last_error = e
                error_str = str(e).upper()
                
                # If rate limited (429), overloaded (503), or Not Found (404), try next key/model
                if "429" in error_str or "503" in error_str or "404" in error_str or "UNAVAILABLE" in error_str or "QUOTA" in error_str:
                    logger.warning(f"Key #{i+1} failed with {model_name} ({error_str}). Rotating...")
                    continue
                else:
                    # For fatal errors like 400 (Invalid Key), log and try next key
                    logger.error(f"Error with key #{i+1} for model {model_name}: {e}")
                    if "API KEY NOT VALID" in error_str or "400" in error_str:
                        continue # Try next key
                    break # Break inner loop and try next model

    # Final fallback if everything fails
    error_msg = f"Code Genie failed to respond. (AI Engine Error: {last_error})"
    logger.error(f"❌ ALL KEYS AND MODELS FAILED: {last_error}")
    yield f"\n{error_msg}"

async def generate(contents: list[dict], model: str = None) -> str:
    """
    Generate a complete response with key and model rotation.
    """
    settings = get_settings()
    clients = get_gemini_clients()
    if not clients:
        return "[Error: No valid Gemini API keys configured.]"

    models_to_try = [
        model or settings.GEMINI_MODEL, 
        "gemma-4-31b-it",
        "gemma-4-26b-a4b-it",
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-3.1-pro-preview",
        "gemini-pro-latest",
    ]
    models_to_try = list(dict.fromkeys(models_to_try))
    
    last_error = None
    for model_name in models_to_try:
        for i, client in enumerate(clients):
            try:
                logger.info(f"Attempting generate with model {model_name} (Key #{i+1})")
                response = await client.aio.models.generate_content(
                    model=model_name,
                    contents=contents,
                    config=types.GenerateContentConfig(
                        system_instruction=SYSTEM_INSTRUCTION,
                        temperature=0.7,
                    ),
                )
                return response.text
            except Exception as e:
                last_error = e
                error_str = str(e).upper()
                if "429" in error_str or "503" in error_str or "404" in error_str or "UNAVAILABLE" in error_str:
                    logger.warning(f"Generate Key #{i+1} failed with {model_name} ({error_str}). Rotating...")
                    continue
                break
    return f"Error: All Gemini models failed. Last error: {last_error}"

    return f"Error: {last_error}"
