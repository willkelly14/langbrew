"""Business logic for user profile, settings, languages, and usage."""

from __future__ import annotations

from calendar import monthrange
from datetime import UTC, date, datetime
from typing import TYPE_CHECKING

import structlog
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError

from app.models.device_token import DeviceToken
from app.models.enums import SubscriptionTier
from app.models.usage_meter import UsageMeter
from app.models.user import User
from app.models.user_language import UserLanguage
from app.models.user_settings import UserSettings
from app.schemas.usage import UsageResponse

if TYPE_CHECKING:
    import uuid

    from sqlalchemy.ext.asyncio import AsyncSession

    from app.schemas.device_token import DeviceTokenCreate
    from app.schemas.user import UserUpdate
    from app.schemas.user_language import UserLanguageCreate, UserLanguageUpdate
    from app.schemas.user_settings import UserSettingsUpdate

logger = structlog.stdlib.get_logger()

# ---------------------------------------------------------------------------
# Tier limits
# ---------------------------------------------------------------------------
FREE_LIMITS: dict[str, int | str] = {
    "passages_generated": 10,
    "talk_seconds": 3600,
    "books_uploaded": 1,
    "listening_seconds": 3600,
    "translations_used": 200,
}

FLUENCY_LIMITS: dict[str, int | str] = {
    "passages_generated": 1000,
    "talk_seconds": 108000,
    "books_uploaded": 15,
    "listening_seconds": "unlimited",
    "translations_used": "unlimited",
}


def _limits_for_tier(tier: SubscriptionTier) -> dict[str, int | str]:
    """Return usage limits for a subscription tier."""
    if tier == SubscriptionTier.FLUENCY:
        return FLUENCY_LIMITS
    return FREE_LIMITS


# ---------------------------------------------------------------------------
# User CRUD
# ---------------------------------------------------------------------------


async def get_or_create_user(db: AsyncSession, supabase_uid: str, email: str) -> User:
    """Look up a user by Supabase UID, creating them with defaults if new."""
    stmt = select(User).where(User.supabase_uid == supabase_uid)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if user is not None:
        # Sync email in case it changed on the auth side
        if email and user.email != email:
            user.email = email
        return user

    user = User(
        supabase_uid=supabase_uid,
        email=email or "",
    )
    db.add(user)
    await db.flush()

    # Auto-create default settings
    settings = UserSettings(user_id=user.id)
    db.add(settings)
    await db.flush()

    # Refresh to populate relationships
    await db.refresh(user, attribute_names=["settings", "languages"])

    logger.info("user_created", user_id=str(user.id), email=email)
    return user


async def update_user(db: AsyncSession, user_id: uuid.UUID, data: UserUpdate) -> User:
    """Apply partial updates to a user profile."""
    stmt = select(User).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one()

    update_fields = data.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(user, field, value)

    await db.flush()
    await db.refresh(user)
    return user


# ---------------------------------------------------------------------------
# User Settings
# ---------------------------------------------------------------------------


async def get_user_settings(db: AsyncSession, user_id: uuid.UUID) -> UserSettings:
    """Return settings for a user, creating defaults if missing."""
    stmt = select(UserSettings).where(UserSettings.user_id == user_id)
    result = await db.execute(stmt)
    settings = result.scalar_one_or_none()

    if settings is None:
        settings = UserSettings(user_id=user_id)
        db.add(settings)
        await db.flush()
        await db.refresh(settings)

    return settings


async def update_user_settings(
    db: AsyncSession, user_id: uuid.UUID, data: UserSettingsUpdate
) -> UserSettings:
    """Apply partial updates to user settings."""
    settings = await get_user_settings(db, user_id)

    update_fields = data.model_dump(exclude_unset=True)
    for field, value in update_fields.items():
        setattr(settings, field, value)

    await db.flush()
    await db.refresh(settings)
    return settings


# ---------------------------------------------------------------------------
# User Languages
# ---------------------------------------------------------------------------


async def create_user_language(
    db: AsyncSession, user_id: uuid.UUID, data: UserLanguageCreate
) -> UserLanguage:
    """Add a new target language for the user, setting it as active.

    Deactivates any previously active language.  Raises ``IntegrityError``
    (caught by the router as 409) if the language already exists.
    """
    # Deactivate all existing languages for this user
    stmt = select(UserLanguage).where(
        UserLanguage.user_id == user_id,
        UserLanguage.is_active.is_(True),
    )
    result = await db.execute(stmt)
    for lang in result.scalars():
        lang.is_active = False

    language = UserLanguage(
        user_id=user_id,
        target_language=data.target_language,
        cefr_level=data.cefr_level,
        reading_level=data.cefr_level,  # default to overall level
        interests=data.interests,
        is_active=True,
    )
    db.add(language)

    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise

    await db.refresh(language)
    return language


async def list_user_languages(
    db: AsyncSession, user_id: uuid.UUID
) -> list[UserLanguage]:
    """Return all target languages for a user."""
    stmt = (
        select(UserLanguage)
        .where(UserLanguage.user_id == user_id)
        .order_by(UserLanguage.created_at)
    )
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def update_user_language(
    db: AsyncSession,
    user_id: uuid.UUID,
    language_id: uuid.UUID,
    data: UserLanguageUpdate,
) -> UserLanguage | None:
    """Update a target language.  Returns ``None`` if not found/not owned."""
    stmt = select(UserLanguage).where(
        UserLanguage.id == language_id,
        UserLanguage.user_id == user_id,
    )
    result = await db.execute(stmt)
    language = result.scalar_one_or_none()

    if language is None:
        return None

    update_fields = data.model_dump(exclude_unset=True)

    # If activating this language, deactivate all others first
    if update_fields.get("is_active") is True:
        others_stmt = select(UserLanguage).where(
            UserLanguage.user_id == user_id,
            UserLanguage.id != language_id,
            UserLanguage.is_active.is_(True),
        )
        others_result = await db.execute(others_stmt)
        for other in others_result.scalars():
            other.is_active = False

    for field, value in update_fields.items():
        setattr(language, field, value)

    await db.flush()
    await db.refresh(language)
    return language


async def delete_user_language(
    db: AsyncSession, user_id: uuid.UUID, language_id: uuid.UUID
) -> bool:
    """Delete a user language.  Returns ``False`` if not found/not owned."""
    stmt = select(UserLanguage).where(
        UserLanguage.id == language_id,
        UserLanguage.user_id == user_id,
    )
    result = await db.execute(stmt)
    language = result.scalar_one_or_none()

    if language is None:
        return False

    await db.delete(language)
    await db.flush()
    return True


# ---------------------------------------------------------------------------
# Device Tokens
# ---------------------------------------------------------------------------


async def upsert_device_token(
    db: AsyncSession, user_id: uuid.UUID, data: DeviceTokenCreate
) -> DeviceToken:
    """Register or update a push-notification device token."""
    stmt = select(DeviceToken).where(DeviceToken.token == data.token)
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()

    if existing is not None:
        existing.user_id = user_id
        existing.platform = data.platform
        await db.flush()
        await db.refresh(existing)
        return existing

    token = DeviceToken(
        user_id=user_id,
        token=data.token,
        platform=data.platform,
    )
    db.add(token)
    await db.flush()
    await db.refresh(token)
    return token


async def delete_device_token(
    db: AsyncSession, user_id: uuid.UUID, token_value: str
) -> bool:
    """Remove a device token.  Returns ``False`` if not found/not owned."""
    stmt = select(DeviceToken).where(
        DeviceToken.token == token_value,
        DeviceToken.user_id == user_id,
    )
    result = await db.execute(stmt)
    device_token = result.scalar_one_or_none()

    if device_token is None:
        return False

    await db.delete(device_token)
    await db.flush()
    return True


# ---------------------------------------------------------------------------
# Usage Meters
# ---------------------------------------------------------------------------


def _current_period() -> tuple[date, date]:
    """Return (start, end) dates for the current calendar month."""
    today = datetime.now(tz=UTC).date()
    start = today.replace(day=1)
    _, last_day = monthrange(today.year, today.month)
    end = today.replace(day=last_day)
    return start, end


async def get_or_create_usage_meter(
    db: AsyncSession, user_id: uuid.UUID, tier: SubscriptionTier
) -> UsageMeter:
    """Return the usage meter for the current month, creating if needed."""
    period_start, period_end = _current_period()

    stmt = select(UsageMeter).where(
        UsageMeter.user_id == user_id,
        UsageMeter.period_start == period_start,
    )
    result = await db.execute(stmt)
    meter = result.scalar_one_or_none()

    if meter is not None:
        return meter

    meter = UsageMeter(
        user_id=user_id,
        subscription_tier=tier,
        period_start=period_start,
        period_end=period_end,
    )
    db.add(meter)
    await db.flush()
    await db.refresh(meter)
    return meter


async def get_usage_response(
    db: AsyncSession, user_id: uuid.UUID, tier: SubscriptionTier
) -> UsageResponse:
    """Build a full usage response with limits for the current period."""
    meter = await get_or_create_usage_meter(db, user_id, tier)
    limits = _limits_for_tier(tier)

    return UsageResponse(
        subscription_tier=meter.subscription_tier,
        period_start=meter.period_start,
        period_end=meter.period_end,
        passages_generated=meter.passages_generated,
        talk_seconds=meter.talk_seconds,
        books_uploaded=meter.books_uploaded,
        listening_seconds=meter.listening_seconds,
        translations_used=meter.translations_used,
        limits=limits,
    )
