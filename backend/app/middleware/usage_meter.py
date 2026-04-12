"""Dependency that checks tier-based usage limits before AI calls."""

from __future__ import annotations

from typing import TYPE_CHECKING

import structlog
from fastapi import Depends, HTTPException, status

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.enums import SubscriptionTier
from app.services.user_service import get_or_create_usage_meter

if TYPE_CHECKING:
    import uuid

    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()

# ---------------------------------------------------------------------------
# Tier limits
# ---------------------------------------------------------------------------
FREE_LIMITS: dict[str, int] = {
    "passages_generated": 10,
    "talk_seconds": 1800,
    "books_uploaded": 1,
    "translations_used": 100,
}

FLUENCY_LIMITS: dict[str, int] = {
    "passages_generated": 1000,
    "talk_seconds": 108000,
    "books_uploaded": 15,
    "translations_used": 999_999_999,  # effectively unlimited
}


def _get_limit(tier: SubscriptionTier, resource: str) -> int:
    """Return the numeric limit for a resource on the given tier."""
    limits = FLUENCY_LIMITS if tier == SubscriptionTier.FLUENCY else FREE_LIMITS
    return limits.get(resource, 0)


# ---------------------------------------------------------------------------
# Usage check dependency
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up the DB user from the JWT claims."""
    from app.services.user_service import get_or_create_user

    return await get_or_create_user(db, auth.sub, auth.email)


async def check_passage_usage(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> uuid.UUID:
    """Verify the user has not exceeded their monthly passage generation limit.

    Returns the ``user_id`` for downstream use.  Raises HTTP 402 if the limit
    is exceeded.
    """
    user = await _resolve_user(db, auth)
    meter = await get_or_create_usage_meter(db, user.id, user.subscription_tier)
    limit = _get_limit(user.subscription_tier, "passages_generated")

    if meter.passages_generated >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": {
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "message": (
                        "Monthly passage limit reached. "
                        "Upgrade to Fluency for 1,000 passages/month."
                    ),
                    "details": {
                        "limit": limit,
                        "used": meter.passages_generated,
                        "resource": "passages",
                    },
                }
            },
        )

    return user.id


async def check_translation_usage(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> uuid.UUID:
    """Verify the user has not exceeded their monthly translation limit.

    Returns the ``user_id`` for downstream use.  Raises HTTP 402 if exceeded.
    """
    user = await _resolve_user(db, auth)
    meter = await get_or_create_usage_meter(db, user.id, user.subscription_tier)
    limit = _get_limit(user.subscription_tier, "translations_used")

    if meter.translations_used >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": {
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "message": (
                        "Monthly translation limit reached. "
                        "Upgrade to Fluency for unlimited translations."
                    ),
                    "details": {
                        "limit": limit,
                        "used": meter.translations_used,
                        "resource": "translations",
                    },
                }
            },
        )

    return user.id


async def increment_passages_used(
    db: AsyncSession,
    user_id: uuid.UUID,
    tier: SubscriptionTier,
) -> None:
    """Increment the passage generation counter for the current period."""
    meter = await get_or_create_usage_meter(db, user_id, tier)
    meter.passages_generated += 1
    await db.flush()


async def increment_translations_used(
    db: AsyncSession,
    user_id: uuid.UUID,
    tier: SubscriptionTier,
) -> None:
    """Increment the translation counter for the current period."""
    meter = await get_or_create_usage_meter(db, user_id, tier)
    meter.translations_used += 1
    await db.flush()


async def check_talk_usage(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> uuid.UUID:
    """Verify the user has not exceeded their monthly talk seconds limit.

    Returns the ``user_id`` for downstream use.  Raises HTTP 402 if the limit
    is exceeded.
    """
    user = await _resolve_user(db, auth)
    meter = await get_or_create_usage_meter(db, user.id, user.subscription_tier)
    limit = _get_limit(user.subscription_tier, "talk_seconds")

    if meter.talk_seconds >= limit:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail={
                "error": {
                    "code": "USAGE_LIMIT_EXCEEDED",
                    "message": (
                        "Monthly talk time limit reached. "
                        "Upgrade to Fluency for 30 hours/month."
                    ),
                    "details": {
                        "limit": limit,
                        "used": meter.talk_seconds,
                        "resource": "talk_seconds",
                    },
                }
            },
        )

    return user.id


async def increment_talk_seconds(
    db: AsyncSession,
    user_id: uuid.UUID,
    tier: SubscriptionTier,
    seconds: int,
) -> None:
    """Increment the talk seconds counter for the current period."""
    meter = await get_or_create_usage_meter(db, user_id, tier)
    meter.talk_seconds += seconds
    await db.flush()
