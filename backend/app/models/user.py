from pydantic import BaseModel, EmailStr, Field
from datetime import datetime
from typing import Optional

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    picture_url: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserInDB(UserBase):
    id: str = Field(alias="_id")
    hashed_password: str
    created_at: datetime
    updated_at: datetime

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    email: str
    full_name: Optional[str]
    picture_url: Optional[str] = None

class TokenData(BaseModel):
    email: Optional[str] = None
