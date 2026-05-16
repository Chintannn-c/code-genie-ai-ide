from pydantic import BaseModel, Field
from typing import Literal


class GenerateRequest(BaseModel):
    """Request schema for code generation."""
    user_id: str = Field(..., min_length=1, description="User identifier")
    chat_id: str | None = Field(None, description="Existing chat ID, or None to create new")
    prompt: str = Field(..., min_length=1, max_length=10000, description="User's prompt")
    language: str = Field("python", description="Target programming language")
    difficulty: Literal["beginner", "intermediate", "advanced"] = Field("beginner")
    file_ids: list[str] | None = Field(None, description="Optional file IDs to include as context")


class DebugRequest(BaseModel):
    """Request schema for code debugging."""
    user_id: str = Field(..., min_length=1)
    chat_id: str | None = None
    code: str = Field(..., min_length=1, max_length=50000, description="Code to debug")
    error: str = Field(..., min_length=1, max_length=5000, description="Error message")
    language: str = Field("python")
    difficulty: Literal["beginner", "intermediate", "advanced"] = Field("beginner")


class ExplainRequest(BaseModel):
    """Request schema for code explanation."""
    user_id: str = Field(..., min_length=1)
    chat_id: str | None = None
    code: str = Field(..., min_length=1, max_length=50000, description="Code to explain")
    language: str = Field("python")
    difficulty: Literal["beginner", "intermediate", "advanced"] = Field("beginner")


class StreamRequest(BaseModel):
    """Unified request schema for SSE streaming endpoint."""
    user_id: str = Field(..., min_length=1)
    chat_id: str | None = None
    prompt: str = Field(default="", max_length=10000, description="User prompt (for generate)")
    code: str = Field(default="", max_length=50000, description="Code input (for debug/explain)")
    error: str = Field(default="", max_length=5000, description="Error message (for debug)")
    language: str = Field("python")
    difficulty: Literal["beginner", "intermediate", "advanced"] = Field("beginner")
    type: Literal["generate", "debug", "explain", "file_analysis", "file_debug"] = Field("generate")
    provider: Literal["gemini", "openrouter", "huggingface"] = Field("gemini")
    model_name: str | None = Field(None, description="Specific model to use (for OpenRouter/HuggingFace)")
    file_ids: list[str] | None = Field(None, description="Optional file IDs to include as context")
