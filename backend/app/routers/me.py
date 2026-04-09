"""Endpoints for the authenticated user's profile, settings, and languages."""

import uuid

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.models.user import User
from app.schemas.device_token import DeviceTokenCreate, DeviceTokenResponse
from app.schemas.usage import UsageResponse
from app.schemas.user import MeResponse, UserResponse, UserUpdate
from app.schemas.user_language import (
    UserLanguageCreate,
    UserLanguageResponse,
    UserLanguageUpdate,
)
from app.schemas.user_settings import UserSettingsResponse, UserSettingsUpdate
from app.services import user_service

logger = structlog.stdlib.get_logger()

router = APIRouter(prefix="/me", tags=["me"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up (or create) the DB user for the authenticated JWT subject."""
    return await user_service.get_or_create_user(db, auth.sub, auth.email)


# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------


@router.get("", response_model=MeResponse)
async def get_me(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> MeResponse:
    """Return the current user's profile, active language, and settings."""
    user = await _resolve_user(db, auth)
    settings = await user_service.get_user_settings(db, user.id)

    return MeResponse(
        user=UserResponse.model_validate(user),
        active_language=(
            UserLanguageResponse.model_validate(user.active_language)
            if user.active_language
            else None
        ),
        settings=UserSettingsResponse.model_validate(settings),
    )


@router.patch("", response_model=UserResponse)
async def update_me(
    body: UserUpdate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UserResponse:
    """Update the current user's profile fields."""
    user = await _resolve_user(db, auth)
    updated = await user_service.update_user(db, user.id, body)
    return UserResponse.model_validate(updated)


@router.post("/avatar", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UserResponse:
    """Upload a user avatar.

    For now, stores the filename as ``avatar_url``.  R2 integration is deferred
    to a later milestone.
    """
    user = await _resolve_user(db, auth)

    # Placeholder: store filename (R2 upload will replace this)
    filename = file.filename or "avatar"
    user.avatar_url = filename
    await db.flush()
    await db.refresh(user)

    return UserResponse.model_validate(user)


# ---------------------------------------------------------------------------
# Settings
# ---------------------------------------------------------------------------


@router.patch("/settings", response_model=UserSettingsResponse)
async def update_settings(
    body: UserSettingsUpdate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UserSettingsResponse:
    """Update the current user's settings."""
    user = await _resolve_user(db, auth)
    settings = await user_service.update_user_settings(db, user.id, body)
    return UserSettingsResponse.model_validate(settings)


# ---------------------------------------------------------------------------
# Languages
# ---------------------------------------------------------------------------


@router.post("/languages", response_model=UserLanguageResponse, status_code=201)
async def create_language(
    body: UserLanguageCreate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UserLanguageResponse:
    """Add a new target language (sets it as active)."""
    user = await _resolve_user(db, auth)
    try:
        language = await user_service.create_user_language(db, user.id, body)
    except IntegrityError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error": {
                    "code": "LANGUAGE_EXISTS",
                    "message": (f"You are already studying {body.target_language}."),
                    "details": {"target_language": body.target_language},
                }
            },
        ) from exc
    return UserLanguageResponse.model_validate(language)


@router.get("/languages", response_model=list[UserLanguageResponse])
async def list_languages(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> list[UserLanguageResponse]:
    """List all target languages for the current user."""
    user = await _resolve_user(db, auth)
    languages = await user_service.list_user_languages(db, user.id)
    return [UserLanguageResponse.model_validate(lang) for lang in languages]


@router.patch("/languages/{language_id}", response_model=UserLanguageResponse)
async def update_language(
    language_id: uuid.UUID,
    body: UserLanguageUpdate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UserLanguageResponse:
    """Update a target language."""
    user = await _resolve_user(db, auth)
    language = await user_service.update_user_language(db, user.id, language_id, body)
    if language is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "LANGUAGE_NOT_FOUND",
                    "message": "Language not found.",
                    "details": {},
                }
            },
        )
    return UserLanguageResponse.model_validate(language)


@router.delete("/languages/{language_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_language(
    language_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> None:
    """Remove a target language."""
    user = await _resolve_user(db, auth)
    deleted = await user_service.delete_user_language(db, user.id, language_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "LANGUAGE_NOT_FOUND",
                    "message": "Language not found.",
                    "details": {},
                }
            },
        )


# ---------------------------------------------------------------------------
# Device Tokens
# ---------------------------------------------------------------------------


@router.post("/devices", response_model=DeviceTokenResponse, status_code=201)
async def register_device(
    body: DeviceTokenCreate,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> DeviceTokenResponse:
    """Register or update a push-notification device token."""
    user = await _resolve_user(db, auth)
    token = await user_service.upsert_device_token(db, user.id, body)
    return DeviceTokenResponse.model_validate(token)


@router.delete("/devices/{token}", status_code=status.HTTP_204_NO_CONTENT)
async def unregister_device(
    token: str,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> None:
    """Remove a device token."""
    user = await _resolve_user(db, auth)
    deleted = await user_service.delete_device_token(db, user.id, token)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "DEVICE_TOKEN_NOT_FOUND",
                    "message": "Device token not found.",
                    "details": {},
                }
            },
        )


# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------


@router.get("/usage", response_model=UsageResponse)
async def get_usage(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
) -> UsageResponse:
    """Return current-period usage counters and tier limits."""
    user = await _resolve_user(db, auth)
    return await user_service.get_usage_response(db, user.id, user.subscription_tier)
