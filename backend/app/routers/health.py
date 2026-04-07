"""Health-check endpoint that verifies DB and Redis connectivity."""

from typing import Any

import structlog
from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.redis import get_redis

logger = structlog.stdlib.get_logger()

router = APIRouter(tags=["health"])


@router.get("/health")
async def health_check(
    db: AsyncSession = Depends(get_db),
    redis: Any = Depends(get_redis),
) -> JSONResponse:
    """Return connectivity status for the database and Redis.

    Returns 200 when both services are reachable, 503 otherwise.
    """
    status_payload: dict[str, str] = {"status": "ok"}
    http_status = 200

    # Database check
    try:
        await db.execute(text("SELECT 1"))
        status_payload["database"] = "connected"
    except Exception:
        logger.error("health_check_db_failed", exc_info=True)
        status_payload["database"] = "unavailable"
        status_payload["status"] = "degraded"
        http_status = 503

    # Redis check
    try:
        await redis.ping()
        status_payload["redis"] = "connected"
    except Exception:
        logger.error("health_check_redis_failed", exc_info=True)
        status_payload["redis"] = "unavailable"
        status_payload["status"] = "degraded"
        http_status = 503

    return JSONResponse(content=status_payload, status_code=http_status)
