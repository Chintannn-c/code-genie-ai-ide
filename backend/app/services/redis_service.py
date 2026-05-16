import logging
import redis.asyncio as redis
from typing import Optional, Any
import json
from app.config import get_settings

logger = logging.getLogger(__name__)

class RedisService:
    """
    Distributed Caching & Rate Limiting service using Upstash Redis.
    Provides semantic caching, session management, and orchestration state tracking.
    """
    def __init__(self):
        self._redis: Optional[redis.Redis] = None
        self.settings = get_settings()

    async def connect(self):
        if not self.settings.REDIS_URL:
            logger.warning("⚠️ REDIS_URL not configured. Semantic caching will be disabled.")
            return
        
        try:
            self._redis = redis.from_url(
                self.settings.REDIS_URL,
                decode_responses=True,
                socket_timeout=5.0
            )
            await self._redis.ping()
            logger.info("✅ Connected to Upstash Redis")
        except Exception as e:
            logger.error(f"❌ Redis connection failed: {e}")
            self._redis = None

    async def get(self, key: str) -> Optional[Any]:
        if not self._redis: return None
        try:
            data = await self._redis.get(key)
            return json.loads(data) if data else None
        except Exception:
            return None

    async def set(self, key: str, value: Any, expire_seconds: int = 3600):
        if not self._redis: return
        try:
            await self._redis.set(
                key, 
                json.dumps(value), 
                ex=expire_seconds
            )
        except Exception as e:
            logger.error(f"Redis Set Error: {e}")

    async def delete(self, key: str):
        if not self._redis: return
        try:
            await self._redis.delete(key)
        except Exception:
            pass

    async def is_rate_limited(self, user_id: str, limit: int = 50, window: int = 3600) -> bool:
        """Sliding window rate limiter."""
        if not self._redis: return False
        key = f"rate_limit:{user_id}"
        try:
            current = await self._redis.incr(key)
            if current == 1:
                await self._redis.expire(key, window)
            return current > limit
        except Exception:
            return False

    async def get_semantic(self, prompt_hash: str) -> Optional[str]:
        """Retrieve answer from semantic cache."""
        return await self.get(f"semantic_cache:{prompt_hash}")

    async def set_semantic(self, prompt_hash: str, answer: str, ttl: int = 86400):
        """Store answer in semantic cache for 24 hours."""
        await self.set(f"semantic_cache:{prompt_hash}", answer, expire_seconds=ttl)

    async def close(self):
        if self._redis:
            await self._redis.close()

# Global instance
redis_service = RedisService()
