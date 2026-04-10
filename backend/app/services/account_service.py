"""Business logic for account deletion."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import TYPE_CHECKING

import httpx
import structlog

from app.core.config import settings
from app.core.redis import redis_client
from app.models.enums import SubscriptionTier

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User
    from app.schemas.account import DeleteAccountRequest

logger = structlog.stdlib.get_logger()


class InvalidConfirmationError(Exception):
    """Raised when the confirmation string does not match."""


class ActiveSubscriptionError(Exception):
    """Raised when the user has an active paid subscription."""


def _is_subscription_active(expires_at: datetime | None) -> bool:
    """Check whether a subscription expiration datetime is in the future.

    Handles both timezone-aware and timezone-naive datetimes by normalising
    to UTC before comparison.
    """
    if expires_at is None:
        return False
    now = datetime.now(tz=UTC)
    # If the stored datetime is naive, assume it is UTC.
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=UTC)
    return expires_at > now


async def delete_account(
    db: AsyncSession,
    user: User,
    body: DeleteAccountRequest,
) -> None:
    """Orchestrate full account deletion.

    Steps:
    1. Validate the confirmation string.
    2. Check for active paid subscription.
    3. Collect R2 paths for cleanup.
    4. Delete the Postgres user row (cascades to all child tables).
    5. Delete R2 objects (best-effort).
    6. Delete Redis keys (best-effort).
    7. Delete the Supabase Auth user (best-effort).
    """
    # 1. Validate confirmation string
    expected = f"{user.first_name}-delete-account".lower()
    if body.confirmation.lower() != expected:
        raise InvalidConfirmationError(
            f"Expected '{expected}', got '{body.confirmation.lower()}'."
        )

    # 2. Check for active paid subscription
    if user.subscription_tier == SubscriptionTier.FLUENCY and _is_subscription_active(
        user.subscription_expires_at
    ):
        raise ActiveSubscriptionError(
            "Cannot delete account with an active Fluency subscription. "
            "Please cancel your subscription first."
        )

    # 3. Collect R2 paths before deletion
    r2_paths: list[str] = []
    if user.avatar_url:
        r2_paths.append(user.avatar_url)

    # Capture IDs needed for cleanup before deleting the user row
    user_id = str(user.id)
    supabase_uid = user.supabase_uid

    # 4. Delete Postgres data (ON DELETE CASCADE handles child rows)
    await db.delete(user)
    await db.flush()

    # 5. Delete R2 objects (best-effort)
    # R2 integration is deferred; log paths for manual cleanup if needed.
    if r2_paths:
        logger.info(
            "account_deletion_r2_cleanup",
            user_id=user_id,
            paths=r2_paths,
        )

    # 6. Delete Redis keys (best-effort)
    await _cleanup_redis(user_id)

    # 7. Delete Supabase Auth user (best-effort)
    await _delete_supabase_auth_user(supabase_uid)

    logger.info("account_deleted", user_id=user_id)


async def _cleanup_redis(user_id: str) -> None:
    """Remove all Redis keys for the given user. Best-effort."""
    patterns = [
        f"usage:{user_id}:*",
        f"ratelimit:{user_id}:*",
    ]
    single_keys = [
        f"forecast:{user_id}",
    ]

    try:
        for pattern in patterns:
            cursor = None
            while cursor != 0:
                cursor, keys = await redis_client.scan(
                    cursor=cursor or 0,
                    match=pattern,
                    count=100,
                )
                if keys:
                    await redis_client.delete(*keys)

        for key in single_keys:
            await redis_client.delete(key)
    except Exception:
        logger.warning(
            "account_deletion_redis_cleanup_failed",
            user_id=user_id,
            exc_info=True,
        )


async def _delete_supabase_auth_user(supabase_uid: str) -> None:
    """Delete the user from Supabase Auth via the admin API. Best-effort."""
    if not settings.SUPABASE_URL or not settings.SUPABASE_SERVICE_ROLE_KEY:
        logger.warning(
            "account_deletion_supabase_skipped",
            reason="SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured",
        )
        return

    url = f"{settings.SUPABASE_URL}/auth/v1/admin/users/{supabase_uid}"
    headers = {
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.delete(url, headers=headers, timeout=10.0)
            if response.status_code not in (200, 204, 404):
                logger.warning(
                    "account_deletion_supabase_failed",
                    supabase_uid=supabase_uid,
                    status_code=response.status_code,
                    body=response.text[:500],
                )
    except Exception:
        logger.warning(
            "account_deletion_supabase_failed",
            supabase_uid=supabase_uid,
            exc_info=True,
        )
