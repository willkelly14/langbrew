"""Redis sliding window rate limiter implemented as FastAPI dependencies."""

from __future__ import annotations

import time
from typing import TYPE_CHECKING

import structlog
from fastapi import Depends, HTTPException, status

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.redis import get_redis

if TYPE_CHECKING:
    from redis.asyncio import Redis

logger = structlog.stdlib.get_logger()

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DEFAULT_RATE_LIMIT = 30  # requests per minute
AI_RATE_LIMIT = 5  # requests per minute for AI endpoints
WINDOW_SECONDS = 60


# ---------------------------------------------------------------------------
# Core sliding window implementation
# ---------------------------------------------------------------------------


async def _check_rate_limit(
    redis: Redis,  # type: ignore[type-arg]
    key: str,
    limit: int,
    window: int = WINDOW_SECONDS,
) -> None:
    """Enforce a sliding window rate limit.

    Raises HTTP 429 if the user has exceeded the limit within the window.
    """
    now = time.time()
    window_start = now - window

    pipe = redis.pipeline()
    # Remove entries outside the current window
    pipe.zremrangebyscore(key, 0, window_start)
    # Add the current request
    pipe.zadd(key, {str(now): now})
    # Count entries in the window
    pipe.zcard(key)
    # Set expiry on the key so it auto-cleans
    pipe.expire(key, window)
    results = await pipe.execute()

    request_count: int = results[2]

    if request_count > limit:
        logger.warning(
            "rate_limit_exceeded",
            key=key,
            count=request_count,
            limit=limit,
        )
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": "Too many requests. Please try again later.",
                    "details": {
                        "limit": limit,
                        "window_seconds": window,
                        "retry_after": window,
                    },
                }
            },
            headers={"Retry-After": str(window)},
        )


# ---------------------------------------------------------------------------
# FastAPI dependencies
# ---------------------------------------------------------------------------


async def rate_limit_default(
    auth: AuthenticatedUser = Depends(get_current_user),
    redis: Redis = Depends(get_redis),  # type: ignore[type-arg]
) -> None:
    """Default rate limiter: 30 requests/minute per user."""
    key = f"rl:default:{auth.sub}"
    await _check_rate_limit(redis, key, DEFAULT_RATE_LIMIT)


async def rate_limit_ai(
    auth: AuthenticatedUser = Depends(get_current_user),
    redis: Redis = Depends(get_redis),  # type: ignore[type-arg]
) -> None:
    """AI endpoint rate limiter: 5 requests/minute per user."""
    key = f"rl:ai:{auth.sub}"
    await _check_rate_limit(redis, key, AI_RATE_LIMIT)
