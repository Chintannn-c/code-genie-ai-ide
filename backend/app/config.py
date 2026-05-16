from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache
from typing import Optional


class Settings(BaseSettings):
    """Application settings loaded from .env file."""

    # API Keys
    GEMINI_API_KEY: str
    GROQ_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""
    HUGGINGFACE_API_KEY: str = ""
    GITHUB_API_KEY: str = ""
    MISTRAL_API_KEY: str = ""
    
    # Google Auth
    GOOGLE_CLIENT_ID: Optional[str] = None
    GOOGLE_CLIENT_ID_WEB: Optional[str] = None

    # Database
    MONGO_URI: str = "mongodb://localhost:27017"
    DB_NAME: str = "ai_code_assistant"
    REDIS_URL: Optional[str] = None
    GEMINI_MODEL: str = "gemini-3.1-pro"
    ALLOWED_ORIGINS: str = "*" 
    
    # Paths (Safe defaults that work in any environment)
    ARTIFACTS_PATH: str = "data/artifacts"
    UPLOAD_PATH: str = "data/uploads"
    EXECUTION_TIMEOUT: float = 10.0
    
    # Auth Settings (Default provided for stability, override in .env)
    JWT_SECRET: str = "genie-dev-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Pydantic Config: Allow extra fields in .env without crashing
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore", 
        env_file_encoding="utf-8"
    )


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
