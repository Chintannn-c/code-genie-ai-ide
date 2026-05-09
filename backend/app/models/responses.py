from pydantic import BaseModel
from datetime import datetime


class ChatResponse(BaseModel):
    """Response for a single AI message."""
    chat_id: str
    message_id: str
    content: str
    type: str
    language: str
    timestamp: datetime


class ChatSummary(BaseModel):
    """Summary of a chat for listing."""
    chat_id: str
    title: str
    created_at: datetime
    updated_at: datetime
    message_count: int = 0


class MessageItem(BaseModel):
    """A single message in a chat."""
    message_id: str
    role: str
    content: str
    type: str = "generate"
    language: str = "python"
    timestamp: datetime


class PaginatedChats(BaseModel):
    """Paginated list of chats."""
    chats: list[ChatSummary]
    total: int
    page: int
    limit: int
    has_more: bool


class PaginatedMessages(BaseModel):
    """Paginated list of messages."""
    messages: list[MessageItem]
    total: int
    page: int
    limit: int
    has_more: bool


class HealthResponse(BaseModel):
    """Health check response."""
    status: str = "ok"
    version: str = "1.0.0"
    database: str = "connected"
