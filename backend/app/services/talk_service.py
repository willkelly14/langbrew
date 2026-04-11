"""Business logic for AI conversations."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Any

import structlog
from sqlalchemy import func, select

from app.models.conversation import Conversation
from app.models.conversation_feedback import ConversationFeedback
from app.models.conversation_partner import ConversationPartner
from app.models.message import Message
from app.services import ai_service

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

logger = structlog.stdlib.get_logger()

# Preview length for last_message_preview
_PREVIEW_LENGTH = 100


# ---------------------------------------------------------------------------
# Partners
# ---------------------------------------------------------------------------


async def get_partners(db: AsyncSession) -> list[ConversationPartner]:
    """Return all conversation partner characters."""
    stmt = select(ConversationPartner).order_by(ConversationPartner.name)
    result = await db.execute(stmt)
    return list(result.scalars().all())


# ---------------------------------------------------------------------------
# Create
# ---------------------------------------------------------------------------


async def create_conversation(
    db: AsyncSession,
    user_id: uuid.UUID,
    partner_id: str,
    topic: str,
    language: str,
    cefr_level: str,
) -> Conversation:
    """Create a new conversation session."""
    conversation = Conversation(
        user_id=user_id,
        partner_id=partner_id,
        topic=topic,
        language=language,
        cefr_level=cefr_level,
        status="active",
        started_at=datetime.utcnow(),
    )
    db.add(conversation)
    await db.flush()
    await db.refresh(conversation, attribute_names=["partner"])

    logger.info(
        "conversation_created",
        conversation_id=str(conversation.id),
        user_id=str(user_id),
        partner_id=partner_id,
        language=language,
    )
    return conversation


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------


async def list_conversations(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    language: str | None = None,
    cursor: str | None = None,
    limit: int = 20,
) -> tuple[list[Conversation], str | None]:
    """Query conversations ordered by last_message_at desc with cursor pagination.

    Returns ``(items, next_cursor)``.
    """
    # Use last_message_at with fallback to created_at for ordering
    sort_col = func.coalesce(Conversation.last_message_at, Conversation.created_at)

    stmt = select(Conversation).where(Conversation.user_id == user_id)

    if language:
        stmt = stmt.where(Conversation.language == language)

    stmt = stmt.order_by(sort_col.desc(), Conversation.id.desc())

    # Cursor-based pagination: cursor is the last conversation id
    if cursor:
        try:
            cursor_uuid = uuid.UUID(cursor)
            cursor_stmt = select(Conversation).where(Conversation.id == cursor_uuid)
            cursor_result = await db.execute(cursor_stmt)
            cursor_conv = cursor_result.scalar_one_or_none()
            if cursor_conv:
                cursor_sort_val = cursor_conv.last_message_at or cursor_conv.created_at
                stmt = stmt.where(
                    (sort_col < cursor_sort_val)
                    | ((sort_col == cursor_sort_val) & (Conversation.id < cursor_uuid))
                )
        except ValueError:
            pass  # Invalid cursor, ignore

    # Fetch one extra to determine if there's a next page
    stmt = stmt.limit(limit + 1)

    result = await db.execute(stmt)
    conversations = list(result.scalars().all())

    next_cursor: str | None = None
    if len(conversations) > limit:
        conversations = conversations[:limit]
        next_cursor = str(conversations[-1].id)

    return conversations, next_cursor


# ---------------------------------------------------------------------------
# Get with messages
# ---------------------------------------------------------------------------


async def get_conversation_with_messages(
    db: AsyncSession,
    user_id: uuid.UUID,
    conversation_id: uuid.UUID,
) -> tuple[Conversation, list[Message]] | None:
    """Fetch a conversation with all its messages ordered by sequence_number.

    Marks ``has_unread`` as False. Returns ``None`` if not found or not owned.
    """
    stmt = select(Conversation).where(
        Conversation.id == conversation_id,
        Conversation.user_id == user_id,
    )
    result = await db.execute(stmt)
    conversation = result.scalar_one_or_none()

    if conversation is None:
        return None

    # Mark as read
    if conversation.has_unread:
        conversation.has_unread = False
        await db.flush()

    # Fetch messages
    msg_stmt = (
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.sequence_number.asc())
    )
    msg_result = await db.execute(msg_stmt)
    messages = list(msg_result.scalars().all())

    return conversation, messages


# ---------------------------------------------------------------------------
# Store message
# ---------------------------------------------------------------------------


async def store_message(
    db: AsyncSession,
    conversation_id: uuid.UUID,
    role: str,
    text_content: str,
) -> Message:
    """Store a new message and update conversation metadata."""
    # Get current max sequence number
    seq_stmt = select(func.coalesce(func.max(Message.sequence_number), 0)).where(
        Message.conversation_id == conversation_id
    )
    seq_result = await db.execute(seq_stmt)
    max_seq: int = seq_result.scalar_one()

    message = Message(
        conversation_id=conversation_id,
        sequence_number=max_seq + 1,
        role=role,
        content_type="text",
        text_content=text_content,
    )
    db.add(message)
    await db.flush()

    # Update conversation metadata
    conv_stmt = select(Conversation).where(Conversation.id == conversation_id)
    conv_result = await db.execute(conv_stmt)
    conversation = conv_result.scalar_one()

    conversation.message_count = max_seq + 1
    preview = text_content[:_PREVIEW_LENGTH] if text_content else ""
    conversation.last_message_preview = preview
    conversation.last_message_at = datetime.utcnow()
    conversation.has_unread = role == "assistant"

    await db.flush()
    await db.refresh(message)

    logger.info(
        "message_stored",
        message_id=str(message.id),
        conversation_id=str(conversation_id),
        role=role,
        sequence_number=message.sequence_number,
    )
    return message


# ---------------------------------------------------------------------------
# End conversation
# ---------------------------------------------------------------------------


async def end_conversation(
    db: AsyncSession,
    conversation_id: uuid.UUID,
) -> Conversation | None:
    """End a conversation by setting status to ENDED."""
    stmt = select(Conversation).where(Conversation.id == conversation_id)
    result = await db.execute(stmt)
    conversation = result.scalar_one_or_none()

    if conversation is None:
        return None

    conversation.status = "ended"
    conversation.ended_at = datetime.utcnow()
    await db.flush()
    await db.refresh(conversation)

    logger.info(
        "conversation_ended",
        conversation_id=str(conversation_id),
    )
    return conversation


# ---------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------


async def get_feedback(
    db: AsyncSession,
    conversation_id: uuid.UUID,
) -> ConversationFeedback | None:
    """Fetch feedback for a conversation, or None if not yet generated."""
    stmt = select(ConversationFeedback).where(
        ConversationFeedback.conversation_id == conversation_id
    )
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def delete_feedback(
    db: AsyncSession,
    conversation_id: uuid.UUID,
) -> None:
    """Delete existing feedback for a conversation (allows regeneration)."""
    stmt = select(ConversationFeedback).where(
        ConversationFeedback.conversation_id == conversation_id
    )
    result = await db.execute(stmt)
    existing = result.scalar_one_or_none()
    if existing:
        await db.delete(existing)
        await db.flush()


async def generate_and_store_feedback(
    db: AsyncSession,
    conversation_id: uuid.UUID,
) -> ConversationFeedback:
    """Load messages, generate AI feedback, and store the result."""
    # Load all messages for the conversation
    msg_stmt = (
        select(Message)
        .where(Message.conversation_id == conversation_id)
        .order_by(Message.sequence_number.asc())
    )
    msg_result = await db.execute(msg_stmt)
    messages = list(msg_result.scalars().all())

    # Build transcript
    transcript_lines: list[str] = []
    for msg in messages:
        role_label = "Student" if msg.role == "user" else "Partner"
        transcript_lines.append(f"{role_label}: {msg.text_content or ''}")
    transcript = "\n".join(transcript_lines)

    # Get conversation for language and CEFR level
    conv_stmt = select(Conversation).where(Conversation.id == conversation_id)
    conv_result = await db.execute(conv_stmt)
    conversation = conv_result.scalar_one()

    # Call AI service for feedback
    feedback_data: dict[str, Any] = await ai_service.generate_chat_feedback(
        transcript=transcript,
        language=conversation.language,
        cefr_level=conversation.cefr_level,
    )

    # Store feedback
    feedback = ConversationFeedback(
        conversation_id=conversation_id,
        overall_score=feedback_data.get("overall_score", 0),
        grammar_score=feedback_data.get("grammar_score", 0),
        vocabulary_score=feedback_data.get("vocabulary_score", 0),
        fluency_score=feedback_data.get("fluency_score", 0),
        confidence_score=feedback_data.get("confidence_score", 0),
        summary=feedback_data.get("summary"),
        strengths=feedback_data.get("strengths"),
        tips=feedback_data.get("tips"),
        corrections=feedback_data.get("corrections"),
    )
    db.add(feedback)
    await db.flush()
    await db.refresh(feedback)

    logger.info(
        "feedback_generated",
        conversation_id=str(conversation_id),
        overall_score=feedback.overall_score,
    )
    return feedback


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------


async def delete_conversation(
    db: AsyncSession,
    conversation_id: uuid.UUID,
) -> bool:
    """Delete a conversation and all associated messages (cascade).

    Returns ``False`` if not found.
    """
    stmt = select(Conversation).where(Conversation.id == conversation_id)
    result = await db.execute(stmt)
    conversation = result.scalar_one_or_none()

    if conversation is None:
        return False

    await db.delete(conversation)
    await db.flush()

    logger.info(
        "conversation_deleted",
        conversation_id=str(conversation_id),
    )
    return True
