import asyncio
import logging
from app.database import get_database

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def backfill_message_counts():
    """
    MIGRATION FIX: One-time script to backfill message_count on existing chats.
    This resolves the N+1 lookup bottleneck by denormalizing message counts.
    """
    db = get_database()
    logger.info("Starting message_count backfill migration...")
    
    # Get all existing chats
    chats = await db.chats.find({}, {"chat_id": 1}).to_list(None)
    logger.info(f"Found {len(chats)} chats to process.")
    
    for chat in chats:
        chat_id = chat["chat_id"]
        # Count messages for this chat
        count = await db.messages.count_documents({"chat_id": chat_id})
        
        # Update the chat document with the correct count
        await db.chats.update_one(
            {"chat_id": chat_id},
            {"$set": {"message_count": count}}
        )
        logger.info(f"Updated chat {chat_id} with count: {count}")
    
    logger.info("Migration complete!")

if __name__ == "__main__":
    asyncio.run(backfill_message_counts())
