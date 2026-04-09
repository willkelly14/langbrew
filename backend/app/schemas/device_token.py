"""Pydantic schemas for device token endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class DeviceTokenCreate(BaseModel):
    """Request body for registering a push-notification device token."""

    token: str = Field(..., min_length=1, max_length=512)
    platform: str = Field(default="ios", max_length=16)


class DeviceTokenResponse(BaseModel):
    """Public representation of a device token."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    token: str
    platform: str
    created_at: datetime
