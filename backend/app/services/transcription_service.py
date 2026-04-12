"""Mistral Audio transcription service for speech-to-text."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Any

import httpx
import structlog

from app.core.config import settings

logger = structlog.stdlib.get_logger()

MISTRAL_TRANSCRIPTION_URL = "https://api.mistral.ai/v1/audio/transcriptions"
MISTRAL_MODEL = "voxtral-mini-latest"


class TranscriptionError(Exception):
    """Raised when the transcription service returns an unusable response."""

    def __init__(self, message: str, *, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.details = details or {}


@dataclass(frozen=True)
class TranscriptionResult:
    """Result of a successful audio transcription."""

    text: str
    confidence: float
    language: str | None
    duration_seconds: float | None


async def transcribe_audio(
    audio_data: bytes,
    filename: str,
    language_hint: str | None = None,
) -> TranscriptionResult:
    """Transcribe audio bytes via the Mistral Audio Transcriptions API.

    Retries once on 429/5xx with a 1-second backoff.

    Parameters
    ----------
    audio_data:
        Raw audio file bytes.
    filename:
        Original filename (used for content-type detection by the API).
    language_hint:
        Optional BCP-47 language code to guide transcription.

    Returns
    -------
    TranscriptionResult with the transcribed text and metadata.

    Raises
    ------
    TranscriptionError
        If the Mistral API returns an error or an unparseable response.
    """
    max_retries = 1

    files: dict[str, tuple[str, bytes]] = {
        "file": (filename, audio_data),
    }
    form_data: dict[str, str] = {"model": MISTRAL_MODEL}
    if language_hint:
        form_data["language"] = language_hint

    async with httpx.AsyncClient(timeout=60.0) as client:
        for attempt in range(max_retries + 1):
            try:
                response = await client.post(
                    MISTRAL_TRANSCRIPTION_URL,
                    headers={
                        "Authorization": f"Bearer {settings.MISTRAL_API_KEY}",
                    },
                    files=files,
                    data=form_data,
                )
            except httpx.HTTPError as exc:
                raise TranscriptionError(
                    "Failed to connect to Mistral transcription API",
                    details={"error": str(exc)},
                ) from exc

            if (
                response.status_code == 429 or response.status_code >= 500
            ) and attempt < max_retries:
                logger.warning(
                    "mistral_transcription_retryable_error",
                    status_code=response.status_code,
                    attempt=attempt + 1,
                )
                await asyncio.sleep(1)
                continue

            try:
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                logger.error(
                    "mistral_transcription_error",
                    status_code=response.status_code,
                    body=response.text[:500],
                )
                if response.status_code == 401:
                    msg = "Invalid Mistral API key — check MISTRAL_API_KEY in .env"
                elif response.status_code == 403:
                    msg = "Mistral API access denied — your plan may not include audio transcription"
                else:
                    msg = f"Mistral transcription API error (HTTP {response.status_code}): {response.text[:200]}"
                raise TranscriptionError(
                    msg,
                    details={
                        "status_code": response.status_code,
                        "body": response.text[:500],
                    },
                ) from exc

            break

    try:
        data = response.json()
    except ValueError as exc:
        raise TranscriptionError(
            "Failed to parse JSON from Mistral transcription response",
            details={"raw": response.text[:500]},
        ) from exc

    text = data.get("text", "")
    if not text:
        logger.warning("mistral_transcription_empty", response_data=data)

    logger.info(
        "transcription_completed",
        filename=filename,
        text_length=len(text),
        language_hint=language_hint,
    )

    return TranscriptionResult(
        text=text,
        confidence=1.0,
        language=language_hint,
        duration_seconds=data.get("duration"),
    )
