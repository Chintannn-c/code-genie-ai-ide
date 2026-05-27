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

    async def check_sliding_window(self, key: str, limit: int, window: int) -> tuple[bool, int, int]:
        """
        Thread-safe sliding window rate limiter using Redis ZSET and transactions (pipeline).
        Returns (is_limited, remaining_requests, reset_seconds).
        """
        if not self._redis:
            return False, limit, window
            
        import time
        import uuid
        now = time.time()
        clear_before = now - window
        request_id = str(uuid.uuid4())
        
        try:
            pipe = self._redis.pipeline()
            # Remove timestamps older than window
            pipe.zremrangebyscore(key, 0, clear_before)
            # Add current request timestamp
            pipe.zadd(key, {request_id: now})
            # Get total requests in the window
            pipe.zcard(key)
            # Get the oldest score in ZSET to calculate reset time
            pipe.zrange(key, 0, 0, withscores=True)
            # Set TTL on key
            pipe.expire(key, window)
            
            results = await pipe.execute()
            
            count = results[2]
            oldest_elements = results[3]
            
            # Remaining requests left
            remaining = max(0, limit - count)
            
            # Calculate reset seconds
            if oldest_elements:
                oldest_score = oldest_elements[0][1]
                reset_seconds = int(max(0, window - (now - oldest_score)))
            else:
                reset_seconds = window
                
            if count > limit:
                # Exceeded limit, delete the mock ZADD request to avoid polluting ZSET
                await self._redis.zrem(key, request_id)
                return True, 0, reset_seconds
                
            return False, remaining, reset_seconds
        except Exception as e:
            logger.error(f"Redis Sliding Window Error: {e}")
            return False, limit, window

    async def is_rate_limited(self, user_id: str, limit: int = 50, window: int = 3600) -> bool:
        """Sliding window rate limiter backward-compatible helper."""
        key = f"rate_limit:{user_id}"
        is_limited, _, _ = await self.check_sliding_window(key, limit, window)
        return is_limited

    async def get_semantic(self, prompt_hash: str) -> Optional[str]:
        """Retrieve answer from semantic cache."""
        return await self.get(f"semantic_cache:{prompt_hash}")

    async def set_semantic(self, prompt_hash: str, answer: str, ttl: int = 86400):
        """Store answer in semantic cache for 24 hours."""
        await self.set(f"semantic_cache:{prompt_hash}", answer, expire_seconds=ttl)

    async def publish(self, channel: str, message: Any):
        if not self._redis: return
        try:
            await self._redis.publish(channel, json.dumps(message))
            logger.info(f"📣 [REDIS-PUB] Published to channel {channel}")
        except Exception as e:
            logger.error(f"Redis Publish Error: {e}")

    async def close(self):
        if self._redis:
            await self._redis.close()

# Global instance
redis_service = RedisService()
