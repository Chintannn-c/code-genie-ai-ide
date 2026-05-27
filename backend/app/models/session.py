from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional

class UserSessionModel(BaseModel):
    id: str = Field(..., alias="_id")
    user_id: str
    session_token_hash: str
    refresh_token_hash: Optional[str] = None
    device_name: str
    browser: str
    operating_system: str
    ip_address: str
    platform: str  # Web / Android / iOS / Desktop
    user_agent: str
    device_fingerprint: Optional[str] = None
    is_active: bool = True
    revoked: bool = False
    created_at: datetime
    last_seen: datetime

    class Config:
        populate_by_name = True
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }
