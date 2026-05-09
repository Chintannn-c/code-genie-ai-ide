from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from .env file."""

    GEMINI_API_KEY: str
    MONGO_URI: str = "mongodb://localhost:27017"
    DB_NAME: str = "ai_code_assistant"
    GEMINI_MODEL: str = "gemini-2.0-flash-lite"
    GROQ_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""
    HUGGINGFACE_API_KEY: str = ""
    
    # Paths
    ARTIFACTS_PATH: str = "C:\\Users\\sharm\\.gemini\\antigravity\\brain\\7de4a6eb-952b-4dab-8c53-1d99bd684c04"
    EXECUTION_TIMEOUT: float = 10.0
    
    # Auth Settings
    JWT_SECRET: str = "your-super-secret-key-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Google Auth (Required for non-Firebase Google Sign-In)
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_ID_WEB: str = ""

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Pagination defaults
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
