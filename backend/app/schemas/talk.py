"""Pydantic schemas for talk/conversation endpoints."""

from __future__ import annotations

import uuid
from datetime import datetime

from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Requests
# ---------------------------------------------------------------------------


class CreateConversationRequest(BaseModel):
    """Request body for POST /v1/talk/conversations."""

    partner_id: str
    topic: str = Field(max_length=255)
    language: str | None = None


class SendMessageRequest(BaseModel):
    """Request body for POST /v1/talk/conversations/:id/messages."""

    text_content: str = Field(max_length=5000)


# ---------------------------------------------------------------------------
# Responses
# ---------------------------------------------------------------------------


class PartnerResponse(BaseModel):
    """Conversation partner summary."""

    model_config = {"from_attributes": True}

    id: str
    name: str
    personality_tag: str
    avatar_url: str


class MessageResponse(BaseModel):
    """A single conversation message."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    conversation_id: uuid.UUID
    sequence_number: int
    role: str
    content_type: str
    text_content: str | None
    created_at: datetime


class ConversationResponse(BaseModel):
    """Conversation summary for list and detail views."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    partner_id: str
    partner_name: str = ""
    topic: str
    language: str
    cefr_level: str
    status: str
    message_count: int
    last_message_preview: str | None
    last_message_at: datetime | None
    has_unread: bool
    started_at: datetime
    ended_at: datetime | None
    created_at: datetime


class ConversationDetailResponse(BaseModel):
    """Full conversation with message history."""

    conversation: ConversationResponse
    messages: list[MessageResponse]


class FeedbackResponse(BaseModel):
    """AI-generated post-conversation feedback."""

    model_config = {"from_attributes": True}

    id: uuid.UUID
    conversation_id: uuid.UUID
    overall_score: int
    grammar_score: int
    vocabulary_score: int
    fluency_score: int
    confidence_score: int
    summary: str | None
    strengths: dict | None
    tips: dict | None
    corrections: list | None
    created_at: datetime


class PaginatedConversationsResponse(BaseModel):
    """Paginated list of conversations."""

    items: list[ConversationResponse]
    next_cursor: str | None = None
