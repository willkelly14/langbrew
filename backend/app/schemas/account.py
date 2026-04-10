"""Schemas for account management (deletion)."""

from pydantic import BaseModel


class DeleteAccountRequest(BaseModel):
    """Request body for account deletion.

    The ``confirmation`` field must match ``{first_name}-delete-account``
    (case-insensitive) to proceed.
    """

    confirmation: str


class DeleteAccountResponse(BaseModel):
    """Response body for a successful account deletion."""

    message: str
