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

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_MODEL = "moonshotai/mimo-v2-flash"


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
) -> dict[str, Any]:
    """Make a non-streaming call to OpenRouter and return parsed JSON."""
    async with httpx.AsyncClient(timeout=60.0) as client:
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
        response.raise_for_status()
        data = response.json()

    content = data["choices"][0]["message"]["content"]
    # Strip markdown code fences if the model wraps them
    content = content.strip()
    if content.startswith("```"):
        # Remove opening fence (```json or ```)
        first_newline = content.index("\n")
        content = content[first_newline + 1 :]
    if content.endswith("```"):
        content = content[:-3]
    content = content.strip()

    return json.loads(content)


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
    return await _call_openrouter(prompt)


async def translate_phrase(
    text: str,
    source_language: str,
    target_language: str,
    context: str | None = None,
) -> dict[str, Any]:
    """Translate a phrase or sentence via the LLM."""
    prompt = _build_translate_prompt(text, source_language, target_language, context)
    return await _call_openrouter(prompt)
