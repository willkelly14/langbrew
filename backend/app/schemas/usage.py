"""Pydantic schemas for usage metering endpoints."""

from __future__ import annotations

from datetime import date
from typing import Any

from pydantic import BaseModel

from app.models.enums import SubscriptionTier


class UsageResponse(BaseModel):
    """Current billing-period usage counters and tier limits."""

    model_config = {"from_attributes": True}

    subscription_tier: SubscriptionTier
    period_start: date
    period_end: date
    passages_generated: int
    talk_seconds: int
    books_uploaded: int
    listening_seconds: int
    translations_used: int
    limits: dict[str, Any]
