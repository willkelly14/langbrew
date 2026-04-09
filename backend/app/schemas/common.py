"""Shared Pydantic schemas: errors and cursor pagination."""

from typing import Any

from pydantic import BaseModel, Field


class ErrorDetail(BaseModel):
    """Structured API error body."""

    code: str
    message: str
    details: dict[str, Any] = Field(default_factory=dict)


class ErrorResponse(BaseModel):
    """Standard envelope for all error responses.

    Example::

        {
            "error": {
                "code": "USAGE_LIMIT_EXCEEDED",
                "message": "Monthly passage limit reached.",
                "details": {"limit": 10, "used": 10, "resource": "passages"}
            }
        }
    """

    error: ErrorDetail


class CursorParams(BaseModel):
    """Query parameters for cursor-based pagination."""

    cursor: str | None = None
    limit: int = Field(default=20, ge=1, le=100)
