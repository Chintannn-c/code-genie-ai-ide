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
    file_ids: list[str] | None = Field(None, description="Optional file IDs to include as context")


class ExplainRequest(BaseModel):
    """Request schema for code explanation."""
    user_id: str = Field(..., min_length=1)
    chat_id: str | None = None
    code: str = Field(..., min_length=1, max_length=50000, description="Code to explain")
    language: str = Field("python")
    difficulty: Literal["beginner", "intermediate", "advanced"] = Field("beginner")
    file_ids: list[str] | None = Field(None, description="Optional file IDs to include as context")


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
    provider: Literal["gemini", "openrouter", "huggingface", "groq", "github", "mistral"] = Field("gemini")
    model_name: str | None = Field(None, description="Specific model to use (for OpenRouter/HuggingFace)")
    file_ids: list[str] | None = Field(None, description="Optional file IDs to include as context")
    temperature: float | None = Field(None, ge=0.0, le=2.0, description="Optional sampling temperature")
    max_tokens: int | None = Field(None, ge=1, le=8192, description="Optional output token limit")
    custom_api_keys: dict[str, str] | None = Field(None, description="Optional user-provided provider keys")
    creativity: float | None = Field(None, description="Creativity vs Accuracy override")
    
class PlanRequest(BaseModel):
    """Request schema for generating an autonomous plan."""
    user_id: str = Field(..., min_length=1)
    prompt: str = Field(..., min_length=1, max_length=10000, description="The mission goal")
    chat_id: str | None = Field(None, description="Optional chat ID to tie the plan to")
    
class PlanExecuteRequest(BaseModel):
    """Request schema for executing a generated plan."""
    user_id: str = Field(..., min_length=1)
    plan_data: dict = Field(..., description="The full plan JSON data to execute")

class SyncOperation(BaseModel):
    entity_type: Literal["chats", "messages"] = Field(..., description="Type of sync entity")
    entity_id: str = Field(..., description="Identifier of the target entity")
    operation: Literal["INSERT", "UPDATE", "DELETE"] = Field(..., description="State update operation")
    delta_payload: dict = Field(..., description="Attributes of change payload")
    vector_clock: int = Field(..., description="Logical timestamp vector clock")

class SyncDeltaRequest(BaseModel):
    last_sync_clock: int = Field(..., description="Last known master synchronization sequence clock")
    device_id: str = Field(..., description="Unique client hardware device string")
    pending_changes: list[SyncOperation] = Field(default=[], description="Unsynced local operations queue")


class StopGenerationRequest(BaseModel):
    """Request schema to interrupt/abort streaming AI generation sessions."""
    chat_id: str = Field(..., min_length=1, description="Target chat identifier to abort")


class SearchRequest(BaseModel):
    """Request schema for semantic workspace search."""
    query: str = Field(..., min_length=1, max_length=500)
    limit: int | None = Field(10, ge=1, le=50)


class CriticRequest(BaseModel):
    """Request schema for dual-pass AI review of generated code."""
    code: str = Field(..., min_length=1, max_length=50000)
    language: str = Field("python")
