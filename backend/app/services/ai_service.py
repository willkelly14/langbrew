"""OpenRouter LLM client for passage generation, definitions, and translations."""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

import httpx
import structlog

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

from app.core.config import settings

logger = structlog.stdlib.get_logger()


class AIServiceError(Exception):
    """Raised when the AI service returns an unusable response."""

    def __init__(self, message: str, *, details: dict[str, Any] | None = None) -> None:
        super().__init__(message)
        self.details = details or {}


OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_MODEL = "google/gemma-4-31b-it"
FAST_MODEL = "google/gemma-4-31b-it"


# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

_WORD_COUNT_MAP = {
    "short": "150-250",
    "medium": "300-500",
    "long": "600-900",
}


def _build_passage_prompt(
    language: str,
    cefr_level: str,
    topic: str,
    style: str | None,
    length: str | None,
    interests: list[str],
    known_vocabulary_sample: list[str] | None = None,
) -> str:
    """Build a structured prompt for passage generation."""
    word_range = _WORD_COUNT_MAP.get(length or "medium", "300-500")
    style_desc = style or "article"
    interests_str = ", ".join(interests) if interests else "general"
    known_words_str = ""
    if known_vocabulary_sample:
        known_words_str = (
            f"\n- Try to naturally include some of these known words for "
            f"reinforcement: {', '.join(known_vocabulary_sample[:20])}"
        )

    return f"""You are an expert language teacher creating reading \
material for language learners.

Generate a reading passage with the following requirements:
- Language: {language}
- CEFR Level: {cefr_level} (adjust vocabulary and grammar complexity accordingly)
- Topic: {topic}
- Style: {style_desc}
- Word count: {word_range} words
- Reader interests: {interests_str}{known_words_str}

Guidelines for CEFR levels:
- A1: Very simple sentences, basic vocabulary, present tense, concrete topics
- A2: Simple sentences, everyday vocabulary, basic past/future tense
- B1: Connected text, broader vocabulary, various tenses, opinions
- B2: Clear detailed text, complex sentences, abstract topics, idiomatic expressions
- C1: Well-structured complex text, sophisticated vocabulary, nuanced arguments

Respond ONLY with a valid JSON object (no markdown, no code fences):
{{
  "title": "A short, engaging title for the passage",
  "content": "The full passage text",
  "topic": "{topic}",
  "vocabulary": [
    {{
      "word": "highlighted word or phrase",
      "start_index": 0,
      "end_index": 5,
      "definition": "definition in {language}",
      "translation": "English translation",
      "phonetic": "phonetic transcription or null",
      "word_type": "noun/verb/adjective/adverb/phrase/etc",
      "example_sentence": "example sentence using the word"
    }}
  ]
}}

Select 8-15 vocabulary items that are appropriate for the CEFR \
level. The start_index and end_index must correspond to the \
character positions in the content string. Ensure the JSON is \
valid and complete."""


def _build_define_prompt(word: str, language: str, context_sentence: str | None) -> str:
    """Build a prompt for word definition lookup."""
    context_part = ""
    if context_sentence:
        context_part = f'\nContext sentence: "{context_sentence}"'

    return f"""You are a language expert. Define the following word/phrase.

Word: "{word}"
Language: {language}{context_part}

Respond ONLY with a valid JSON object (no markdown, no code fences):
{{
  "word": "{word}",
  "phonetic": "phonetic transcription or null",
  "word_type": "noun/verb/adjective/adverb/phrase/etc",
  "definitions": [
    {{
      "definition": "definition in {language}",
      "example": "example sentence in {language}",
      "meaning": "English meaning"
    }}
  ],
  "example_sentence": "an example sentence using the word in {language}"
}}

Provide 1-3 definitions. Ensure the JSON is valid and complete."""


def build_sense_selection_prompt(
    word: str,
    language: str,
    context_sentence: str,
    senses: list[dict[str, Any]],
) -> str:
    """Minimal prompt to select which dictionary sense applies in context.

    Designed to produce a very short response (just a number).
    """
    sense_lines = "\n".join(
        f"{s.get('sense_id', i)}: {s.get('definition', '')}"
        for i, s in enumerate(senses)
    )
    return (
        f'Word: "{word}" ({language})\n'
        f'Sentence: "{context_sentence}"\n'
        f"Senses:\n{sense_lines}\n"
        f"Reply with ONLY the sense number that fits."
    )


def _build_translate_prompt(
    text: str,
    source_language: str,
    target_language: str,
    context: str | None,
) -> str:
    """Build a prompt for phrase translation."""
    context_part = ""
    if context:
        context_part = f'\nContext: "{context}"'

    return f"""You are a professional translator. Translate the following text.

Text: "{text}"
From: {source_language}
To: {target_language}{context_part}

Respond ONLY with a valid JSON object (no markdown, no code fences):
{{
  "text": "{text}",
  "translation": "the translation in {target_language}"
}}

Provide an accurate, natural-sounding translation. Ensure the JSON is valid."""


# ---------------------------------------------------------------------------
# API calls
# ---------------------------------------------------------------------------


async def _call_openrouter(
    prompt: str,
    *,
    stream: bool = False,
    model: str = DEFAULT_MODEL,
    max_retries: int = 2,
) -> dict[str, Any]:
    """Make a non-streaming call to OpenRouter and return parsed JSON.

    Retries on 429 (rate limit) with exponential backoff.
    """
    import asyncio

    async with httpx.AsyncClient(timeout=60.0) as client:
        for attempt in range(max_retries + 1):
            response = await client.post(
                f"{OPENROUTER_BASE_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://langbrew.app",
                    "X-Title": "LangBrew",
                },
                json={
                    "model": model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.7,
                    "max_tokens": 4096,
                    "stream": stream,
                },
            )
            if (
                response.status_code == 429 or response.status_code >= 500
            ) and attempt < max_retries:
                wait = 2**attempt  # 1s, 2s
                logger.warning(
                    "openrouter_retryable_error",
                    status_code=response.status_code,
                    attempt=attempt + 1,
                    wait=wait,
                    model=model,
                )
                await asyncio.sleep(wait)
                continue
            try:
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise AIServiceError(
                    f"OpenRouter returned HTTP {response.status_code}",
                    details={
                        "status_code": response.status_code,
                        "model": model,
                    },
                ) from exc
            break

    try:
        data = response.json()
        content: str = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, ValueError) as exc:
        raise AIServiceError(
            "Unexpected response structure from OpenRouter",
            details={"model": model},
        ) from exc

    # Strip markdown code fences if the model wraps them
    content = content.strip()
    if content.startswith("```"):
        # Remove opening fence (```json or ```)
        first_newline = content.index("\n")
        content = content[first_newline + 1 :]
    if content.endswith("```"):
        content = content[:-3]
    content = content.strip()

    try:
        return json.loads(content)
    except json.JSONDecodeError as exc:
        raise AIServiceError(
            "Failed to parse JSON from OpenRouter response",
            details={"model": model, "raw_content": content[:500]},
        ) from exc


async def call_openrouter_raw(
    prompt: str,
    *,
    max_tokens: int = 16,
    model: str = DEFAULT_MODEL,
    max_retries: int = 2,
) -> str:
    """Make a non-streaming call to OpenRouter and return raw text content.

    Unlike ``_call_openrouter`` this does **not** attempt JSON parsing,
    which is useful for tiny completions (e.g. sense-selection returning
    just a number).  Retries on 429 with exponential backoff.
    """
    import asyncio

    async with httpx.AsyncClient(timeout=30.0) as client:
        for attempt in range(max_retries + 1):
            response = await client.post(
                f"{OPENROUTER_BASE_URL}/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": "https://langbrew.app",
                    "X-Title": "LangBrew",
                },
                json={
                    "model": model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": 0.0,
                    "max_tokens": max_tokens,
                    "stream": False,
                },
            )
            if (
                response.status_code == 429 or response.status_code >= 500
            ) and attempt < max_retries:
                wait = 2**attempt
                logger.warning(
                    "openrouter_retryable_error",
                    status_code=response.status_code,
                    attempt=attempt + 1,
                    wait=wait,
                    model=model,
                )
                await asyncio.sleep(wait)
                continue
            try:
                response.raise_for_status()
            except httpx.HTTPStatusError as exc:
                raise AIServiceError(
                    f"OpenRouter returned HTTP {response.status_code}",
                    details={
                        "status_code": response.status_code,
                        "model": model,
                    },
                ) from exc
            break

        data = response.json()

    try:
        return data["choices"][0]["message"]["content"]
    except (KeyError, IndexError) as exc:
        raise AIServiceError(
            "Unexpected response structure from OpenRouter",
            details={"model": model},
        ) from exc


async def generate_passage_stream(
    language: str,
    cefr_level: str,
    topic: str,
    style: str | None,
    length: str | None,
    interests: list[str],
    known_vocabulary_sample: list[str] | None = None,
) -> AsyncGenerator[str, None]:
    """Stream passage generation via OpenRouter SSE.

    Yields raw SSE chunks of the passage content as they arrive. The final
    accumulated text is also yielded as a special ``[DONE]`` event.
    """
    prompt = _build_passage_prompt(
        language=language,
        cefr_level=cefr_level,
        topic=topic,
        style=style,
        length=length,
        interests=interests,
        known_vocabulary_sample=known_vocabulary_sample,
    )

    accumulated = ""
    async with (
        httpx.AsyncClient(timeout=120.0) as client,
        client.stream(
            "POST",
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://langbrew.app",
                "X-Title": "LangBrew",
            },
            json={
                "model": DEFAULT_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 4096,
                "stream": True,
            },
        ) as response,
    ):
        response.raise_for_status()
        async for line in response.aiter_lines():
            if not line.startswith("data: "):
                continue
            payload = line[6:]
            if payload.strip() == "[DONE]":
                break
            try:
                chunk = json.loads(payload)
                delta = chunk["choices"][0].get("delta", {})
                content = delta.get("content", "")
                if content:
                    accumulated += content
                    yield content
            except (json.JSONDecodeError, KeyError, IndexError):
                logger.warning("stream_parse_error", line=line)
                continue

    # Yield the final accumulated JSON as a special event
    yield f"[FINAL]{accumulated}"


def parse_passage_json(raw: str) -> dict[str, Any]:
    """Parse the accumulated passage JSON from a streaming response.

    Handles markdown code fences and extra whitespace.
    """
    text = raw.strip()
    if text.startswith("```"):
        first_newline = text.index("\n")
        text = text[first_newline + 1 :]
    if text.endswith("```"):
        text = text[:-3]
    text = text.strip()
    return json.loads(text)


async def define_word(
    word: str,
    language: str,
    context_sentence: str | None = None,
) -> dict[str, Any]:
    """Look up a word definition via the LLM."""
    prompt = _build_define_prompt(word, language, context_sentence)
    return await _call_openrouter(prompt, model=FAST_MODEL)


async def translate_phrase(
    text: str,
    source_language: str,
    target_language: str,
    context: str | None = None,
) -> dict[str, Any]:
    """Translate a phrase or sentence via the LLM."""
    prompt = _build_translate_prompt(text, source_language, target_language, context)
    return await _call_openrouter(prompt, model=DEFAULT_MODEL)


# ---------------------------------------------------------------------------
# Chat / Talk
# ---------------------------------------------------------------------------


def _build_chat_system_prompt(
    partner_name: str,
    partner_personality: str,
    system_prompt_template: str,
    language: str,
    cefr_level: str,
) -> str:
    """Build system prompt for conversation partner."""
    return f"""{system_prompt_template}

Your name is {partner_name}. Your personality: {partner_personality}.
Conversation language: {language}
Student's CEFR level: {cefr_level}

Guidelines:
- Respond naturally in {language} at the {cefr_level} level
- Keep responses concise (2-4 sentences typically)
- Gently introduce new vocabulary appropriate for the level
- If the student makes errors, continue naturally (don't correct inline)
- Be encouraging and conversational
- Stay in character as {partner_name}"""


async def stream_chat_response(
    system_prompt: str,
    messages: list[dict[str, str]],
) -> AsyncGenerator[str, None]:
    """Stream chat response tokens from MiMo v2 Flash via OpenRouter."""
    # Build the messages list with system prompt
    api_messages: list[dict[str, str]] = [
        {"role": "system", "content": system_prompt},
    ]
    api_messages.extend(messages)

    async with (
        httpx.AsyncClient(timeout=60.0) as client,
        client.stream(
            "POST",
            f"{OPENROUTER_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://langbrew.app",
                "X-Title": "LangBrew",
            },
            json={
                "model": DEFAULT_MODEL,
                "messages": api_messages,
                "stream": True,
                "max_tokens": 500,
                "temperature": 0.8,
            },
        ) as response,
    ):
        response.raise_for_status()
        async for line in response.aiter_lines():
            if not line.startswith("data: "):
                continue
            data = line[6:]
            if data.strip() == "[DONE]":
                break
            try:
                chunk = json.loads(data)
                delta = chunk["choices"][0].get("delta", {})
                content = delta.get("content", "")
                if content:
                    yield content
            except (json.JSONDecodeError, KeyError, IndexError):
                logger.warning("chat_stream_parse_error", line=line)
                continue


async def generate_chat_feedback(
    transcript: str,
    language: str,
    cefr_level: str,
) -> dict[str, Any]:
    """Generate structured feedback for a completed conversation."""
    prompt = f"""Analyze this language learning conversation and \
provide detailed feedback.

The student is learning {language} at CEFR level {cefr_level}.

Transcript:
{transcript}

Respond with ONLY valid JSON in this exact format:
{{
    "overall_score": <int 0-100>,
    "grammar_score": <int 0-100>,
    "vocabulary_score": <int 0-100>,
    "fluency_score": <int 0-100>,
    "confidence_score": <int 0-100>,
    "summary": "<2-3 sentence overall assessment>",
    "strengths": {{
        "label": "Strength",
        "text": "<specific praise with examples from the conversation>"
    }},
    "tips": {{
        "label": "Try this",
        "text": "<specific actionable advice for improvement>"
    }},
    "corrections": [
        {{
            "original": "<what the student said>",
            "corrected": "<correct version>",
            "explanation": "<brief grammar/usage explanation>"
        }}
    ]
}}

If the student made no errors, return an empty corrections array.
Be encouraging but honest. Reference specific words/phrases from the conversation."""

    return await _call_openrouter(prompt, model=DEFAULT_MODEL)
