import logging
from fastapi import APIRouter, HTTPException, Query, Depends
from app.models.responses import PaginatedChats, PaginatedMessages
from app.services import chat_service
from app.routes.deps import get_current_user_id

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["history"])


@router.get("/chats/{user_id}", response_model=PaginatedChats)
async def get_user_chats(
    user_id: str,
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    current_user_id: str = Depends(get_current_user_id)
):
    """Get paginated list of chats for a user."""
    # Ensure user is only fetching their own chats
    if user_id != current_user_id:
        raise HTTPException(status_code=403, detail="Not authorized to access these chats")
        
    try:
        result = await chat_service.get_chats(user_id, page, limit)
        return PaginatedChats(**result)
    except Exception as e:
        logger.error(f"Get chats error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/chats/{chat_id}/messages", response_model=PaginatedMessages)
async def get_chat_messages(
    chat_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user_id: str = Depends(get_current_user_id)
):
    """Get paginated messages for a specific chat."""
    # Verify ownership
    if not await chat_service.is_chat_owner(chat_id, current_user_id):
        raise HTTPException(status_code=403, detail="Not authorized to access this chat")
        
    try:
        result = await chat_service.get_messages(chat_id, page, limit)
        return PaginatedMessages(**result)
    except Exception as e:
        logger.error(f"Get messages error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/chats/{chat_id}")
async def delete_chat(chat_id: str, current_user_id: str = Depends(get_current_user_id)):
    """Delete a chat and all its messages."""
    # Verify ownership
    if not await chat_service.is_chat_owner(chat_id, current_user_id):
        raise HTTPException(status_code=403, detail="Not authorized to delete this chat")
        
    try:
        deleted = await chat_service.delete_chat(chat_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Chat not found")
        return {"status": "deleted", "chat_id": chat_id}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Delete chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
