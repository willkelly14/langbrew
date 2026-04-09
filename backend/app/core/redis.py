"""Upstash Redis client using redis.asyncio."""

from redis.asyncio import Redis

from app.core.config import settings

redis_client = Redis.from_url(
    settings.REDIS_URL,
    decode_responses=True,
)


async def get_redis() -> Redis:  # type: ignore[type-arg]
    """FastAPI dependency that returns the shared Redis client."""
    return redis_client
