from pydantic import BaseModel
from datetime import datetime


class FileMetadata(BaseModel):
    """Metadata for uploaded files."""
    file_id: str
    user_id: str
    file_name: str
    file_path: str
    language: str
    size: int
    created_at: datetime


class UploadResponse(BaseModel):
    """Response after file upload."""
    file_id: str
    file_name: str
    language: str
    size: int


class FileAnalysisRequest(BaseModel):
    """Request for file analysis."""
    file_id: str
    analysis_type: str = "summary"  # summary | issues | architecture
    provider: str = "gemini"
    model_name: str | None = None
    difficulty: str = "beginner"


class FileDebugRequest(BaseModel):
    """Request for file-level debugging."""
    file_id: str
    error: str
    provider: str = "gemini"
    model_name: str | None = None
    difficulty: str = "beginner"


class PatchRequest(BaseModel):
    """Request for unified diff patch."""
    file_id: str
    issue: str
    provider: str = "gemini"
    model_name: str | None = None
