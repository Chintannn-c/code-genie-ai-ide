import logging
from urllib.parse import urlsplit, urlunsplit
from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING
from app.config import get_settings

logger = logging.getLogger(__name__)

_client: AsyncIOMotorClient | None = None
_database: AsyncIOMotorDatabase | None = None


def _redact_mongo_uri(uri: str) -> str:
    """Return a log-safe Mongo URI with credentials removed."""
    try:
        parsed = urlsplit(uri)
        if not parsed.username and not parsed.password:
            return uri
        host = parsed.hostname or ""
        if parsed.port:
            host = f"{host}:{parsed.port}"
        return urlunsplit((parsed.scheme, host, parsed.path, parsed.query, parsed.fragment))
    except Exception:
        return "<invalid mongo uri>"


async def connect_to_mongo() -> None:
    """Initialize MongoDB connection and create indexes."""
    global _client, _database
    settings = get_settings()

    logger.info("Connecting to MongoDB at %s...", _redact_mongo_uri(settings.MONGO_URI))
    _client = AsyncIOMotorClient(
        settings.MONGO_URI,
        serverSelectionTimeoutMS=5000,
        connectTimeoutMS=5000
    )
    _database = _client[settings.DB_NAME]

    # Verify connection with a ping
    try:
        await _client.admin.command('ping')
        logger.info("📡 Database Ping Successful!")
    except Exception as e:
        logger.error(f"❌ Database Ping Failed: {e}")
        raise e

    # Create indexes for performance
    await _database.chats.create_index([("user_id", ASCENDING), ("created_at", DESCENDING)])
    await _database.messages.create_index([("chat_id", ASCENDING), ("timestamp", ASCENDING)])
    await _database.security_logs.create_index([("timestamp", DESCENDING)])
    await _database.audit_logs.create_index([("timestamp", DESCENDING)])
    await _database.orchestration_events.create_index([("workflow_id", ASCENDING)])
    await _database.user_sessions.create_index([("user_id", ASCENDING)])
    await _database.user_sessions.create_index([("session_token_hash", ASCENDING)])

    logger.info(f"Connected to MongoDB database: {settings.DB_NAME}")


async def close_mongo_connection() -> None:
    """Close MongoDB connection."""
    global _client, _database
    if _client:
        _client.close()
        _client = None
        _database = None
        logger.info("MongoDB connection closed.")


def get_database() -> AsyncIOMotorDatabase:
    """Get the database instance."""
    if _database is None:
        raise RuntimeError("Database not initialized. Call connect_to_mongo() first.")
    return _database

async def get_db() -> AsyncIOMotorDatabase:
    """Get the database instance (async helper)."""
    return get_database()
