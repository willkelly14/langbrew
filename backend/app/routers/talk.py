"""Endpoints for AI conversation (Talk)."""

from __future__ import annotations

import json
import uuid  # noqa: TC003
from typing import TYPE_CHECKING, Any

import structlog
from fastapi import APIRouter, Depends, Form, HTTPException, Query, UploadFile, status
from sse_starlette.sse import EventSourceResponse

from app.core.auth import AuthenticatedUser, get_current_user
from app.core.database import get_db
from app.middleware.rate_limit import rate_limit_ai, rate_limit_default
from app.middleware.usage_meter import check_talk_usage, increment_talk_seconds
from app.schemas.talk import (
    ConversationDetailResponse,
    ConversationResponse,
    CreateConversationRequest,
    FeedbackResponse,
    MessageResponse,
    PaginatedConversationsResponse,
    PartnerResponse,
    SendMessageRequest,
    TranscribeResponse,
)
from app.services import ai_service, talk_service
from app.services.transcription_service import TranscriptionError, transcribe_audio
from app.services.user_service import get_or_create_user

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from sqlalchemy.ext.asyncio import AsyncSession

    from app.models.user import User

logger = structlog.stdlib.get_logger()

router = APIRouter(prefix="/talk", tags=["talk"])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _resolve_user(db: AsyncSession, auth: AuthenticatedUser) -> User:
    """Look up (or create) the DB user for the authenticated JWT subject."""
    return await get_or_create_user(db, auth.sub, auth.email)


# ---------------------------------------------------------------------------
# POST /v1/talk/transcribe — Transcribe audio
# ---------------------------------------------------------------------------

_ALLOWED_AUDIO_TYPES = {
    "audio/wav",
    "audio/x-wav",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mp4",
    "audio/mpeg",
    "audio/mp3",
    "audio/webm",
    "audio/ogg",
    "audio/flac",
    "audio/x-flac",
}

_MAX_AUDIO_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio_endpoint(
    file: UploadFile,
    language: str | None = Form(default=None, max_length=10),
    db: AsyncSession = Depends(get_db),
    user_id: uuid.UUID = Depends(check_talk_usage),
    _rate: None = Depends(rate_limit_ai),
) -> TranscribeResponse:
    """Transcribe an audio file to text using Mistral STT."""
    # Validate content type
    content_type = file.content_type or ""
    if content_type not in _ALLOWED_AUDIO_TYPES:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "error": {
                    "code": "INVALID_AUDIO_FORMAT",
                    "message": (
                        "Unsupported audio format. "
                        "Accepted: wav, m4a, mp3, webm, ogg, flac."
                    ),
                    "details": {"content_type": content_type},
                }
            },
        )

    # Read and validate file size
    audio_data = await file.read()
    if len(audio_data) > _MAX_AUDIO_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail={
                "error": {
                    "code": "FILE_TOO_LARGE",
                    "message": "Audio file must be 10 MB or smaller.",
                    "details": {
                        "max_bytes": _MAX_AUDIO_BYTES,
                        "received_bytes": len(audio_data),
                    },
                }
            },
        )

    try:
        result = await transcribe_audio(
            audio_data,
            file.filename or "audio.wav",
            language_hint=language,
        )
    except TranscriptionError as exc:
        logger.error(
            "transcription_failed",
            user_id=str(user_id),
            error=str(exc),
            details=exc.details,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error": {
                    "code": "TRANSCRIPTION_FAILED",
                    "message": str(exc),
                    "details": exc.details,
                }
            },
        ) from exc

    # Increment talk seconds usage
    duration_secs = int(result.duration_seconds) if result.duration_seconds else 0
    if duration_secs > 0:
        from sqlalchemy import select as sa_select

        from app.models.user import User as UserModel

        user_stmt = sa_select(UserModel).where(UserModel.id == user_id)
        user_result = await db.execute(user_stmt)
        user_obj = user_result.scalar_one()
        await increment_talk_seconds(
            db, user_id, user_obj.subscription_tier, duration_secs
        )
        await db.commit()

    return TranscribeResponse(
        text=result.text,
        confidence=result.confidence,
        language=result.language,
        duration_seconds=result.duration_seconds,
    )


# ---------------------------------------------------------------------------
# GET /v1/talk/partners — List conversation partners
# ---------------------------------------------------------------------------


@router.get("/partners", response_model=list[PartnerResponse])
async def list_partners(
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> list[PartnerResponse]:
    """Return all available AI conversation partners."""
    partners = await talk_service.get_partners(db)
    return [PartnerResponse.model_validate(p) for p in partners]


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations — Create a new conversation
# ---------------------------------------------------------------------------


@router.post(
    "/conversations",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_conversation(
    body: CreateConversationRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> ConversationResponse:
    """Start a new AI conversation session."""
    user = await _resolve_user(db, auth)

    # Resolve language and CEFR level from active language
    active_lang = user.active_language
    if active_lang is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error": {
                    "code": "NO_ACTIVE_LANGUAGE",
                    "message": "You must set an active target language first.",
                    "details": {},
                }
            },
        )

    language = body.language or active_lang.target_language
    resolved_cefr = active_lang.speaking_level or active_lang.cefr_level
    cefr_level = (
        resolved_cefr.value if hasattr(resolved_cefr, "value") else str(resolved_cefr)
    )

    conversation = await talk_service.create_conversation(
        db,
        user_id=user.id,
        partner_id=body.partner_id,
        topic=body.topic,
        language=language,
        cefr_level=cefr_level,
    )
    await db.commit()

    resp = ConversationResponse.model_validate(conversation)
    resp.partner_name = conversation.partner.name
    return resp


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations — List conversations
# ---------------------------------------------------------------------------


@router.get("/conversations", response_model=PaginatedConversationsResponse)
async def list_conversations(
    cursor: str | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
    language: str | None = Query(default=None, max_length=10),
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> PaginatedConversationsResponse:
    """List the current user's conversations with pagination."""
    user = await _resolve_user(db, auth)

    items, next_cursor = await talk_service.list_conversations(
        db,
        user.id,
        language=language,
        cursor=cursor,
        limit=limit,
    )

    responses: list[ConversationResponse] = []
    for conv in items:
        resp = ConversationResponse.model_validate(conv)
        resp.partner_name = conv.partner.name
        responses.append(resp)

    return PaginatedConversationsResponse(items=responses, next_cursor=next_cursor)


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations/{conversation_id} — Get conversation detail
# ---------------------------------------------------------------------------


@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationDetailResponse,
)
async def get_conversation(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> ConversationDetailResponse:
    """Return a conversation with its full message history."""
    user = await _resolve_user(db, auth)

    result = await talk_service.get_conversation_with_messages(
        db, user.id, conversation_id
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    conversation, messages = result
    await db.commit()

    conv_resp = ConversationResponse.model_validate(conversation)
    conv_resp.partner_name = conversation.partner.name

    return ConversationDetailResponse(
        conversation=conv_resp,
        messages=[MessageResponse.model_validate(m) for m in messages],
    )


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations/{conversation_id}/messages — Send + stream reply
# ---------------------------------------------------------------------------


@router.post("/conversations/{conversation_id}/messages")
async def send_message(
    conversation_id: uuid.UUID,
    body: SendMessageRequest,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_ai),
) -> EventSourceResponse:
    """Send a message and stream the AI partner's response via SSE.

    SSE event types:
    - ``token``: partial response content as it streams
    - ``done``: final JSON with the assistant message id
    - ``error``: if something goes wrong during generation
    """
    user = await _resolve_user(db, auth)

    # Verify conversation belongs to user and is active
    result = await talk_service.get_conversation_with_messages(
        db, user.id, conversation_id
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    conversation, existing_messages = result

    # Reactivate if previously ended (feedback no longer ends conversations)
    if conversation.status != "active":
        conversation.status = "active"
        conversation.ended_at = None
        await db.flush()

    # Store the user's message
    await talk_service.store_message(
        db,
        conversation_id,
        role="user",
        text_content=body.text_content,
        content_type=body.content_type,
        audio_transcription=body.audio_transcription,
        audio_duration_seconds=body.audio_duration_seconds,
    )
    await db.commit()

    # Build system prompt from partner config
    partner = conversation.partner
    system_prompt = ai_service._build_chat_system_prompt(
        partner_name=partner.name,
        partner_personality=partner.personality_tag,
        system_prompt_template=partner.system_prompt_template,
        language=conversation.language,
        cefr_level=conversation.cefr_level,
    )

    # Build message history for the AI
    chat_messages: list[dict[str, str]] = []
    for msg in existing_messages:
        chat_messages.append(
            {
                "role": msg.role,
                "content": msg.text_content or "",
            }
        )
    # Add the new user message
    chat_messages.append(
        {
            "role": "user",
            "content": body.text_content,
        }
    )

    # Capture values for the async generator closure
    conv_id = conversation_id

    async def event_generator() -> AsyncGenerator[dict[str, Any], None]:
        """Yield SSE events as the AI response streams in."""
        accumulated = ""
        try:
            async for token in ai_service.stream_chat_response(
                system_prompt=system_prompt,
                messages=chat_messages,
            ):
                accumulated += token
                yield {"event": "token", "data": token}

            # Store the complete assistant message
            assistant_message = await talk_service.store_message(
                db,
                conv_id,
                role="assistant",
                text_content=accumulated,
            )
            await db.commit()

            yield {
                "event": "done",
                "data": json.dumps({"message_id": str(assistant_message.id)}),
            }
        except Exception:
            logger.exception("chat_stream_error", conversation_id=str(conv_id))
            yield {
                "event": "error",
                "data": json.dumps(
                    {
                        "error": {
                            "code": "GENERATION_FAILED",
                            "message": "An error occurred during response generation.",
                            "details": {},
                        }
                    }
                ),
            }

    return EventSourceResponse(event_generator())


# ---------------------------------------------------------------------------
# POST /v1/talk/conversations/{conversation_id}/feedback — Generate feedback
# ---------------------------------------------------------------------------


@router.post("/conversations/{conversation_id}/feedback")
async def generate_feedback(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_ai),
) -> dict[str, str]:
    """Generate feedback on the conversation so far (does not end it)."""
    user = await _resolve_user(db, auth)

    result = await talk_service.get_conversation_with_messages(
        db, user.id, conversation_id
    )
    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    # Delete any old feedback so it regenerates fresh
    await talk_service.delete_feedback(db, conversation_id)

    try:
        await talk_service.generate_and_store_feedback(db, conversation_id)
    except Exception:
        logger.exception(
            "feedback_generation_failed",
            conversation_id=str(conversation_id),
        )

    await db.commit()

    return {"status": "generated"}


# ---------------------------------------------------------------------------
# GET /v1/talk/conversations/{conversation_id}/feedback — Get feedback
# ---------------------------------------------------------------------------


@router.get("/conversations/{conversation_id}/feedback")
async def get_feedback(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> FeedbackResponse | dict[str, str]:
    """Return AI-generated feedback for a completed conversation."""
    user = await _resolve_user(db, auth)

    # Verify ownership
    conv_result = await talk_service.get_conversation_with_messages(
        db, user.id, conversation_id
    )
    if conv_result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    feedback = await talk_service.get_feedback(db, conversation_id)
    if feedback is None:
        # Feedback not yet available — return 202
        from starlette.responses import JSONResponse

        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content={"status": "generating"},
        )

    return FeedbackResponse.model_validate(feedback)


# ---------------------------------------------------------------------------
# DELETE /v1/talk/conversations/{conversation_id} — Delete conversation
# ---------------------------------------------------------------------------


@router.delete(
    "/conversations/{conversation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_conversation(
    conversation_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    auth: AuthenticatedUser = Depends(get_current_user),
    _rate: None = Depends(rate_limit_default),
) -> None:
    """Delete a conversation and all its messages."""
    user = await _resolve_user(db, auth)

    # Verify ownership first
    conv_result = await talk_service.get_conversation_with_messages(
        db, user.id, conversation_id
    )
    if conv_result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    deleted = await talk_service.delete_conversation(db, conversation_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error": {
                    "code": "CONVERSATION_NOT_FOUND",
                    "message": "Conversation not found.",
                    "details": {},
                }
            },
        )

    await db.commit()
