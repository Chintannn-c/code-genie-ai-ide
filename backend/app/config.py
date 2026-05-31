from functools import lru_cache
import os
from typing import Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


DEFAULT_JWT_SECRET = "genie-dev-secret-key-change-in-production"


class Settings(BaseSettings):
    """Application settings loaded from .env file."""

    # API Keys
    GEMINI_API_KEY_1: str = ""
    GEMINI_API_KEY_2: str = ""
    GROQ_API_KEY: str = ""
    OPENROUTER_API_KEY: str = ""
    HUGGINGFACE_API_KEY: str = ""
    GITHUB_API_KEY: str = ""
    MISTRAL_API_KEY: str = ""
    
    @property
    def gemini_keys(self) -> list[str]:
        """Returns the list of configured Gemini keys."""
        return [k for k in [self.GEMINI_API_KEY_1, self.GEMINI_API_KEY_2] if k]
    
    # Google Auth
    GOOGLE_CLIENT_ID: Optional[str] = None
    GOOGLE_CLIENT_ID_WEB: Optional[str] = None

    # Database & Memory
    MONGO_URI: str = "mongodb://localhost:27017"
    DB_NAME: str = "ai_code_assistant"
    REDIS_URL: Optional[str] = None
    CHROMADB_URL: Optional[str] = None
    
    # Runtime environment
    ENVIRONMENT: str = "development"

    # AI Config
    GEMINI_MODEL: str = "gemma-4-31b-it"
    ALLOWED_ORIGINS: str = "http://localhost,http://localhost:8000,http://127.0.0.1:8000"

    # Risky operational capabilities are opt-in and must stay disabled in production.
    ENABLE_HOTPATCH: bool = False
    HOTPATCH_WORKSPACE: str = "."
    ALLOW_NATIVE_CODE_EXECUTION: bool = False
    ALLOW_EXECUTION_AUTO_INSTALL: bool = False
    
    # Paths (Safe defaults that work in any environment)
    ARTIFACTS_PATH: str = "data/artifacts"
    UPLOAD_PATH: str = "data/uploads"
    EXECUTION_TIMEOUT: float = 10.0
    
    # Auth Settings (default is allowed only for local development)
    JWT_SECRET: str = DEFAULT_JWT_SECRET
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7

    # Rate Limiting Settings
    RATE_LIMIT_FREE: int = 20
    RATE_LIMIT_PREMIUM: int = 200
    RATE_LIMIT_WINDOW_SECONDS: int = 3600

    # Pydantic Config: Allow extra fields in .env without crashing
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore", 
        env_file_encoding="utf-8"
    )

    @property
    def is_production(self) -> bool:
        """True when running in a deployed production-like environment."""
        env = (self.ENVIRONMENT or os.getenv("RAILWAY_ENVIRONMENT", "")).lower()
        return env in {"prod", "production"} or bool(os.getenv("RAILWAY_ENVIRONMENT"))

    @property
    def allowed_origins(self) -> list[str]:
        """Parse comma-separated CORS origins, dropping blanks."""
        return [origin.strip().rstrip("/") for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

    def validate_production_safety(self) -> None:
        """Fail fast when production is configured with unsafe development defaults."""
        if not self.is_production:
            return

        if self.JWT_SECRET == DEFAULT_JWT_SECRET or len(self.JWT_SECRET) < 32:
            raise RuntimeError(
                "JWT_SECRET must be replaced with a strong secret before running in production."
            )

        if "*" in self.allowed_origins:
            raise RuntimeError(
                "ALLOWED_ORIGINS cannot be '*' when credentials are enabled in production."
            )

        if "localhost" in self.MONGO_URI or "127.0.0.1" in self.MONGO_URI:
            raise RuntimeError(
                "MONGO_URI must point to a production database before running in production."
            )

        if self.ENABLE_HOTPATCH:
            raise RuntimeError("ENABLE_HOTPATCH must stay disabled in production.")

        if self.ALLOW_NATIVE_CODE_EXECUTION:
            raise RuntimeError("ALLOW_NATIVE_CODE_EXECUTION must stay disabled in production.")


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
