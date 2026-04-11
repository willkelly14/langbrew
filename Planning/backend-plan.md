# LangBrew Backend Architecture Plan

## Context

LangBrew is a language learning iOS app currently in the design/mockup phase with no backend code yet. The app is built around three pillars: AI-generated reading passages, AI conversation practice, and spaced repetition flashcards.

**Stack (all decisions finalized):**

| Layer | Choice | Details |
|-------|--------|---------|
| **Backend** | FastAPI (Python) | Supabase (Edge Functions or self-hosted) |
| **Auth** | Supabase Auth | Apple/Google/email, 50K free MAUs |
| **Database** | Supabase Postgres | SQLAlchemy + asyncpg |
| **Cache** | Upstash Redis | Rate limiting, caching |
| **Storage** | Cloudflare R2 | Books, chapters, audio |
| **LLM** | MiMo v2 Flash via OpenRouter | $0.09/$0.29 per M tokens. Config-swappable to Gemma 4 31B. |
| **TTS** | Qwen3-TTS 0.6B (on-device) | CoreML, ~1.0 GB, bundled in app binary, iOS 18+ |
| **STT** | Voxtral Realtime via Mistral | $0.006/min, sub-200ms |
| **Timestamps** | Sentence-level + Qwen3-ASR | On-device, see section 5 |
| **VAD** | Silero VAD v5 (on-device) | CoreML, ~3 MB, bundled in app binary |
| **Voices** | Qwen3-TTS preset speakers | Map built-in voices to 6 characters per language |
| **Languages** | 8 supported | Spanish, French, Portuguese, Italian, German, Japanese, Korean, Chinese |

**Key design principles:**
- **Easy model switching:** All LLM calls go through a single `AIService` with a `model` config parameter. Swapping MiMo -> Gemma 4 (or any future model) is a one-line config change in `settings.py`. OpenRouter's API format is identical across models.
- **Ship and iterate:** Launch with MiMo v2 Flash for all tasks. Monitor quality. Swap individual tasks to stronger models if needed.
- **Models bundled in app:** Qwen3-TTS (~1.0 GB), Silero VAD (~3 MB), and Qwen3-ASR (~180 MB) are included in the app binary. No post-install downloads. App Store size: ~1.2 GB+.

---

## 1. Architecture Overview

### Stack: FastAPI + Supabase Auth + Supabase Postgres + Redis

| Component | Service | Cost (MVP) |
|-----------|---------|------------|
| App Server | Supabase (FastAPI + uvicorn) | Free (included) |
| Auth | Supabase Auth (Apple/Google/email) | Free (50K MAUs) |
| Database | Supabase Postgres | Included with Supabase Pro ($25/mo covers auth + DB) |
| Cache/Rate Limiting | Upstash Redis (serverless) | Free (10K cmd/day) |
| Object Storage | Cloudflare R2 | Free (10 GB) |
| Push Notifications | APNs via aioapns | Free |
| Background Jobs | ARQ (Redis-backed async queue) | Included |

**Total estimated cost at ~100 users: $30-55/month** (mostly AI API calls).

### Key Business Rules
- **Free tier book limit:** 1 book total (ever), not per month. Free users can only have 1 imported book at a time. Must delete to upload a new one. `books_uploaded` on usage_meters is not used for free tier — instead check `COUNT(books) WHERE user_id = X`.
- **Today's Passage:** Server auto-generates a daily passage via background job (based on user interests + CEFR level). If already read, fall back to the most recent unread passage. Counts against passage usage limit.
- **Auto-adjust difficulty:** Composite score from vocabulary mastery (% of words mastered at current CEFR level) + passage completion rate + conversation feedback scores. When composite crosses a threshold, server suggests a level-up via the `GET /v1/me/languages/:id/stats` response (include `suggested_level?: str` field). User must confirm the change — it is not forced.

**Why Supabase Auth:** Eliminates 8+ auth endpoints. Apple Sign-In, Google Sign-In, email/password with verification, password reset, JWT issuance, and refresh token rotation are all handled by Supabase. The iOS app uses `supabase-swift` SDK. The FastAPI backend verifies Supabase JWTs with a single middleware dependency (~20 lines). User identity data lives in Supabase's `auth.users`; all app data (vocabulary, passages, progress) lives in Supabase Postgres, linked by the Supabase user UUID.

**Auth flow:**
1. iOS app authenticates via `supabase-swift` (Apple/Google/email)
2. Supabase issues a JWT (HS256, signed with your project's JWT secret)
3. iOS app sends JWT as `Authorization: Bearer <token>` on all API calls
4. FastAPI middleware decodes and verifies JWT locally using `PyJWT` + the Supabase JWT secret
5. Extracts `sub` (user UUID) from the token — used as `user_id` FK in all app tables
6. On first authenticated request, FastAPI creates a `users` record in Supabase Postgres if one doesn't exist (upsert by `supabase_uid`)

**Supabase free tier note:** Project pauses after 7 days of inactivity. Any real user activity prevents this. For production, upgrade to Supabase Pro ($25/mo) if needed.

---

## 2. API Design

All endpoints versioned under `/v1/`. All require Supabase Bearer JWT except webhooks and health. AI-streaming endpoints use SSE. List endpoints use cursor-based pagination (`?cursor=&limit=`).

**Standard error response:**
```json
{
  "error": {
    "code": "USAGE_LIMIT_EXCEEDED",
    "message": "Monthly passage limit reached. Upgrade to Fluency for 1,000 passages/month.",
    "details": { "limit": 10, "used": 10, "resource": "passages" }
  }
}
```

### Home
```
GET    /v1/home                 — aggregated home screen data (user, streak, cards_due, todays_passage,
                                  current_book, recent_books, word_stats) — single call for home tab
```

### User & Profile
```
GET    /v1/me                   — profile, preferences, subscription status (creates user on first call)
PATCH  /v1/me                   — update profile (name, daily_goal_minutes, new_words_per_day, auto_adjust_difficulty, timezone)
PATCH  /v1/me/settings          — update reading/talk/notification preferences
POST   /v1/me/avatar            — upload avatar (multipart)
GET    /v1/me/stats             — words, passages, chats, streaks, achievements, topic word counts
GET    /v1/me/achievements      — list achievements with progress toward locked ones
GET    /v1/me/usage             — current period usage vs limits
POST   /v1/me/devices           — register APNs device token
DELETE /v1/me/devices/:token    — unregister device token
DELETE /v1/me/account           — delete all app data; body: {"confirmation": "{username}-delete-account"}
```

### Languages (multi-language support)
```
POST   /v1/me/languages             — add a new target language (onboarding step 1-3 or later)
GET    /v1/me/languages             — list user's languages with levels, interests, active flag
PATCH  /v1/me/languages/:id         — update CEFR level, interests, reading/speaking/listening levels, set active
DELETE /v1/me/languages/:id         — remove a target language
GET    /v1/me/languages/:id/stats   — per-language statistics (hours, words, streak, skill breakdown, topics)
```

### Subscription
```
POST   /v1/me/subscription/verify   — validate App Store transaction JWS, update subscription tier
POST   /v1/me/subscription/restore  — restore purchases (re-validate existing App Store transactions)
POST   /v1/me/usage/listening       — report listening session (passage/book, duration, language)
POST   /v1/me/reading-speed        — report a reading speed measurement (passage_id, words_read, seconds_spent)
```

### Passages
```
POST   /v1/passages/generate    — generate passage (SSE streaming)
         Body: { mode: "auto"|"custom", topic?: str, cefr_level?: str,
                 style?: "article"|"dialogue"|"story"|"letter",
                 length?: "short"|"medium"|"long" }
GET    /v1/passages              — list user's passages
         ?search=               — full-text search in title + content
         ?cefr_level=           — filter by difficulty (A1, A2, B1, B2, C1)
         ?topic=                — filter by topic
         ?is_generated=         — filter AI-generated vs book-sourced
         ?sort_by=              — date (default), difficulty, topic
         ?sort_order=           — desc (default), asc
         ?cursor=&limit=        — pagination
GET    /v1/passages/:id         — full passage with vocabulary annotations
PATCH  /v1/passages/:id         — update reading progress, bookmark position
DELETE /v1/passages/:id         — soft delete
```

### Books
```
POST   /v1/books/upload                — upload book (multipart), returns job ID
GET    /v1/books                       — list books with progress
         ?status=                      — all (default), reading, finished
         ?language=                    — filter by language
         ?cursor=&limit=              — pagination
GET    /v1/books/:id                   — book metadata + chapter list (without chapter content)
GET    /v1/books/:id/status            — processing status with progress %
GET    /v1/books/:id/chapters/:n       — chapter content (from R2) with annotations
PATCH  /v1/books/:id                   — update reading_progress, last_read_chapter, last_read_position
DELETE /v1/books/:id                   — delete book + R2 files
```

### Talk (Conversation)
```
GET    /v1/talk/partners                         — list conversation partners (name, personality, avatar, voice_config)
POST   /v1/talk/conversations                    — create conversation (partner_id, topic, language)
GET    /v1/talk/conversations                    — list conversations (paginated)
GET    /v1/talk/conversations/:id                — conversation metadata + messages
POST   /v1/talk/conversations/:id/messages       — send message, get AI response (SSE)
POST   /v1/talk/conversations/:id/end            — end chat, trigger feedback
GET    /v1/talk/conversations/:id/feedback       — get feedback (202 if still generating)
DELETE /v1/talk/conversations/:id                — delete conversation
POST   /v1/talk/transcribe                       — transcribe audio (Voxtral Realtime)
```

### Vocabulary & Language Bank
```
GET    /v1/vocabulary               — list words/phrases/sentences (paginated)
         ?search=                   — search in text + translation
         ?type=                     — word, phrase, sentence
         ?status=                   — new, learning, known, mastered
         ?language=                 — filter by target language
         ?cursor=&limit=            — pagination
GET    /v1/vocabulary/stats         — aggregate counts: total, by_status, by_type, due_for_review
GET    /v1/vocabulary/:id           — single item with full detail (SM-2 stats, accuracy, definition)
POST   /v1/vocabulary               — add item
POST   /v1/vocabulary/batch         — add multiple items at once
PATCH  /v1/vocabulary/:id           — update status, reset flashcard
DELETE /v1/vocabulary/:id           — remove from language bank
POST   /v1/vocabulary/define        — word definition in context (tap-to-define)
POST   /v1/vocabulary/translate     — context-aware phrase/sentence translation
GET    /v1/vocabulary/:id/encounters — list all passages/conversations where word appeared
```

### Flashcards
```
GET    /v1/flashcards/due           — cards due for review
         ?mode=                     — daily (default), hardest, new, ahead, random
         ?type=                     — word, phrase, sentence (filter by card type)
         ?limit=                    — cards per batch (default 25)
         ?count_only=               — true: return only counts (for home screen badge), no card data
POST   /v1/flashcards/:id/review    — submit review result (quality 0-5, optional session_id)
GET    /v1/flashcards/stats         — mastery breakdown, forecast, learning velocity (cached hourly)
POST   /v1/flashcards/sessions      — create study session (mode, card_limit, type_filter) → session_id
GET    /v1/flashcards/sessions      — past study sessions (paginated)
GET    /v1/flashcards/sessions/:id  — session detail with per-card breakdown
PATCH  /v1/flashcards/sessions/:id  — complete session (duration, correct_count, incorrect_count)
POST   /v1/flashcards/sessions/:id/restudy — create new session from missed cards of previous session
```

### Sync
```
POST   /v1/sync                     — bidirectional delta sync (see section 5 for full payload)
```

### System
```
GET    /v1/health                   — health check (DB + Redis connectivity)
POST   /v1/feedback                 — submit user feedback (bug, feature, general)
POST   /v1/webhooks/appstore        — App Store Server Notifications V2 (JWS-verified)
```

**Total: 50 endpoints**

---

## 3. Data Models (Supabase Postgres via SQLAlchemy + asyncpg)

All models include `id: UUID (PK)`, `created_at: Timestamp`, `updated_at: Timestamp` unless noted. Pydantic models handle API validation.

### User & Profile

**users** (app-side user record, linked to Supabase auth.users)
```
id: UUID (PK),
supabase_uid: str (unique) — from JWT sub claim,
email: str,
name: str,
avatar_url?: str,
native_language: str (default "en"),
subscription_tier: enum(free, fluency),
subscription_expires_at?: datetime,
app_store_transaction_id?: str,
daily_goal_minutes: int (default 10),
new_words_per_day: int (default 10),
auto_adjust_difficulty: bool (default true),
timezone: str (default "UTC"),
current_streak: int (default 0),          — cached streak count, updated when streaks recorded
onboarding_completed: bool (default false),
onboarding_step: int (default 0),         — 0=not started, 1-7=in progress, 8=complete
created_at, updated_at
```
Indexes: `supabase_uid` (unique)

**user_settings** (one per user)
```
id, user_id (FK unique),
— Reading:
reading_theme: enum(light, sepia, dark),
reading_font: enum(serif, sans),
font_size: int (default 16),
line_spacing: enum(compact, normal, relaxed),
vocabulary_highlights: bool (default true),
auto_play_audio: bool (default false),
highlight_following: bool (default true),
preferred_voice_id: str?,
voice_speed: float (default 1.0),
— Talk:
talk_voice_style: str (default "natural"),
talk_correction_style: str (default "gentle"),
show_transcript: bool (default true),
auto_save_words: bool (default true),
session_length_minutes: int (default 5),
— Flashcards:
reviews_per_session: int (default 20),
show_example_sentence: bool (default true),
audio_on_reveal: bool (default true),
— Notifications:
notifications_enabled: bool (default true),
reminder_time: str? (HH:mm),
streak_alerts: bool (default true),
review_reminder: bool (default true),
created_at, updated_at
```

**device_tokens** (APNs)
```
id, user_id (FK), token: str (unique),
platform: str (default "ios"),
created_at
```

### Language & Learning

**user_languages**
```
id, user_id (FK), target_language: str,
cefr_level: enum(A1, A2, B1, B2, C1),
reading_level, speaking_level, listening_level: enum(A1..C1),
interests: jsonb (array of strings),
is_active: bool (default true),
created_at, updated_at
```
Indexes: `(user_id, target_language)` unique

### Reading Content

**passages**
```
id, user_id (FK), user_language_id (FK),
title, content: text,
language, cefr_level: enum,
topic, word_count: int,
estimated_minutes: int,
known_word_percentage: float?,
is_generated: bool,
source_book_id?: uuid (FK),
source_chapter_number?: int,
style?: str,                           — article, dialogue, story, letter (for generated passages)
length?: str,                          — short, medium, long (for generated passages)
reading_progress: float (default 0.0),
bookmark_position?: int,
search_vector: tsvector,               — generated from title + content for full-text search
deleted_at?: datetime,
created_at, updated_at
```
Indexes: `(user_id, language)`, `(user_id, created_at desc)`, `GIN index on search_vector`

**passage_vocabulary** (word annotations — includes definition data from passage generation)
```
id, passage_id (FK), vocabulary_item_id?: uuid (FK),
word: str,
start_index: int, end_index: int,
is_highlighted: bool,
definition?: str,             — from LLM passage generation response
translation?: str,
phonetic?: str,
word_type?: str,              — noun, verb, adj, etc.
example_sentence?: str,
created_at
```
Indexes: `passage_id`, `vocabulary_item_id`

**books**
```
id, user_id (FK),
title, author?: str,
language, cefr_level?: enum,
cover_url?: str,
file_url: str (R2 path),
file_type: enum(epub, pdf, txt),
file_size_bytes: int,
total_chapters: int (default 0),
total_words: int (default 0),
processing_status: enum(queued, processing, ready, failed),
processing_progress: float (0.0-1.0),
processing_error?: str,
reading_progress: float (default 0.0),
last_read_chapter: int (default 1),
last_read_position: int (default 0),
last_read_at?: datetime,              — updated on reading progress changes; used for "Currently Reading" sort
created_at, updated_at
```

**book_chapters** (metadata in Postgres, content in R2)
```
id, book_id (FK),
chapter_number: int, title: str,
word_count: int, cefr_level?: enum,
content_url: str (R2: books/{book_id}/chapters/{n}.json),
reading_progress: float (default 0.0),    — per-chapter progress for Table of Contents display
created_at
```
Indexes: `(book_id, chapter_number)` unique

### Conversation

**conversation_partners** (reference table, seeded at deploy)
```
id: str (PK, e.g. "mia"),
name, personality_tag: str,
system_prompt_template: text,
avatar_url: str,
voice_config: jsonb — maps language to Qwen3-TTS preset speaker ID
  e.g. {"es": "Vivian", "fr": "Serena", "de": "Ryan", "ja": "Ono_Anna", ...}
created_at, updated_at
```

The 6 characters (Mia, Carlos, Elena, Lucia, Diego, Marco) each map to Qwen3-TTS preset speakers per language. The 9 available presets (Vivian, Serena, Uncle_Fu, Dylan, Eric, Ryan, Aiden, Ono_Anna, Sohee) are distributed across characters to maximize voice variety. Different characters use different presets for the same language where possible.

**conversations**
```
id, user_id (FK), partner_id (FK),
topic, language, cefr_level: enum,
status: enum(active, ended, abandoned),
message_count: int (default 0),
total_duration_seconds: int (default 0),
last_message_preview?: str,                — truncated to ~100 chars, updated on each new message
last_message_at?: datetime,                — timestamp of most recent message
has_unread: bool (default false),          — true when AI responds, false when user opens conversation
started_at: datetime, ended_at?: datetime,
created_at, updated_at
```
Indexes: `(user_id, language, created_at desc)`

**messages**
```
id, conversation_id (FK),
sequence_number: int,
role: enum(user, assistant),
content_type: enum(text, audio),
text_content?: str,
audio_transcription?: str,
audio_url?: str (R2 path),
audio_duration_seconds?: int,
created_at
```
Indexes: `(conversation_id, sequence_number)`

**conversation_feedback**
```
id, conversation_id (FK, unique),
overall_score, grammar_score, vocabulary_score,
speaking_score, listening_score: int (0-100),
strengths: jsonb, tips: jsonb,
corrections: jsonb (array of {original, corrected, explanation}),
created_at
```

### Vocabulary & Spaced Repetition

**vocabulary_items**
```
id, user_id (FK), user_language_id (FK),
language, type: enum(word, phrase, sentence),
text, translation: str,
phonetic?: str, word_type?: str,
definitions: jsonb,                        — array of {definition, example, meaning} for multi-definition display
example_sentence?: str,                    — quick-access for flashcard front
status: enum(new, learning, known, mastered),
— SM-2:
ease_factor: float (default 2.5),
interval: int (default 0),
repetitions: int (default 0),
next_review_date: date,
— Stats:
times_reviewed: int (default 0),
times_correct: int (default 0),
last_reviewed_at?: datetime,
created_at, updated_at
```
Indexes: `(user_id, language, next_review_date)`, `(user_id, language, status)`, `(user_id, language, text)` unique

**Status transitions:**
- `new` -> `learning`: after first review
- `learning` -> `known`: interval >= 21 days
- `known` -> `mastered`: interval >= 90 days AND accuracy >= 80%
- Any -> `learning`: on context reset

**vocabulary_encounters** (all contexts where a word appeared)
```
id, vocabulary_item_id (FK),
source_type: enum(passage, book_chapter, conversation),
source_id: uuid,
context_sentence: str,
created_at
```
Indexes: `vocabulary_item_id`, `(source_type, source_id)`

**review_events** (append-only, for sync conflict resolution)
```
id, vocabulary_item_id (FK), user_id (FK),
quality: int (0-5),
device_id: str,
reviewed_at: datetime,
synced_at: datetime,
created_at
```
Indexes: `(vocabulary_item_id, reviewed_at)`

**study_sessions**
```
id, user_id (FK), language: str,
mode: enum(daily, hardest, new, ahead, random),
type_filter?: str (word, phrase, sentence — null means all types),
restudy_of?: uuid (FK -> study_sessions.id — links to original session for re-study),
cards_reviewed, correct_count, incorrect_count: int,
duration_seconds: int,
started_at, completed_at: datetime,
created_at
```

**session_reviews** (per-card breakdown)
```
id, study_session_id (FK), vocabulary_item_id (FK),
quality: int (0-5),
created_at
```

### Progress & Engagement

**user_streaks**
```
id, user_id (FK), date: date,
language: str,                             — target language for this activity (enables per-language stats)
minutes_studied, passages_read,
cards_reviewed, chats_completed,
words_learned: int (all default 0),
created_at, updated_at
```
Indexes: `(user_id, date, language)` unique

**achievement_definitions** (reference table, seeded at deploy)
```
id: str (PK, e.g. "first_day", "streak_7", "words_100"),
name: str ("First Day", "7-Day Streak", "100 Words"),
description: str ("Complete your first study session"),
icon: str (emoji, e.g. "🎉", "🔥", "📚"),
target: int (1, 7, 100, etc.),
category: str (streak, vocabulary, reading, conversation),
sort_order: int,
created_at
```

**achievements** (user progress toward each achievement)
```
id, user_id (FK),
definition_id: str (FK -> achievement_definitions.id),
progress: int (default 0),
unlocked_at?: datetime,
created_at, updated_at
```
Indexes: `(user_id, definition_id)` unique

### Analytics & Tracking

**reading_speed_logs** (per-passage reading speed measurements)
```
id, user_id (FK), passage_id (FK),
language: str,
words_read: int,
seconds_spent: int,
wpm: float,                              — computed: words_read / (seconds_spent / 60)
created_at
```
Indexes: `(user_id, language, created_at)`

**listening_sessions** (individual listening session records for stats)
```
id, user_id (FK),
language: str,
passage_id?: uuid (FK),
book_id?: uuid (FK),
chapter_number?: int,
duration_seconds: int,
created_at
```
Indexes: `(user_id, language, created_at)`

### Billing & Usage

**usage_meters**
```
id, user_id (FK),
subscription_tier: enum,
period_start, period_end: date,
passages_generated, talk_seconds,
books_uploaded, listening_seconds,
translations_used: int (all default 0),
created_at, updated_at
```
Indexes: `(user_id, period_start)`

**subscription_events** (audit log)
```
id, user_id (FK),
event_type: str (purchase, renewal, expiration, refund, billing_retry),
app_store_transaction_id, product_id: str,
event_payload: jsonb,
created_at
```

**feedback_submissions**
```
id, user_id? (FK),
type: enum(bug, feature, general),
message: text, contact_email?: str,
created_at
```

---

## 4. AI Pipeline Architecture

### Model Routing

| Task | Model | Pricing | Notes |
|------|-------|---------|-------|
| Passage Generation | MiMo v2 Flash | $0.09/$0.29/M tokens | 262K context, structured JSON output |
| Chat Responses | MiMo v2 Flash | $0.09/$0.29/M tokens | Streaming via OpenRouter SSE |
| Post-Chat Feedback | MiMo v2 Flash | $0.09/$0.29/M tokens | Config-swap to Gemma 4 if quality insufficient |
| Word Definition | MiMo v2 Flash | $0.09/$0.29/M tokens | Cache aggressively in Redis |
| Context Translation | MiMo v2 Flash | $0.09/$0.29/M tokens | Cache aggressively |
| Book Analysis | MiMo v2 Flash | $0.09/$0.29/M tokens | One-time per book |
| Vocabulary Extraction | MiMo v2 Flash | $0.09/$0.29/M tokens | Batch processing |
| STT (Talk) | Voxtral Realtime | $0.006/min | Sub-200ms latency |
| STT (batch) | Voxtral Mini Transcribe | $0.003/min | Non-interactive only |
| TTS | Qwen3-TTS 0.6B on-device | Free | ~1.0 GB, bundled, iOS 18+ |
| VAD | Silero VAD v5 on-device | Free | ~3 MB, bundled |
| Timestamps | Qwen3-ASR on-device | Free | ~180 MB, bundled |

**Model swap strategy:** `app/core/config.py` contains a model routing table:
```python
MODEL_ROUTING = {
    "passage_generation": "xiaomi/mimo-v2-flash",
    "chat": "xiaomi/mimo-v2-flash",
    "feedback": "xiaomi/mimo-v2-flash",
    "definition": "xiaomi/mimo-v2-flash",
    "translation": "xiaomi/mimo-v2-flash",
    ...
}
```
Changing any task to `"google/gemma-4-31B"` (or any future model) is a single-line edit. No code changes needed. The `AIService` reads this config and passes it to OpenRouter.

### Prompt Injection Mitigation
1. Use OpenRouter's `system` vs `user` message roles — never concatenate user input into system prompts
2. Sanitize custom topics (max 200 chars, strip control characters)
3. Validate generated JSON against Pydantic schemas. Reject and retry malformed outputs.
4. Book uploads: sanitize EPUB HTML, validate file type by magic bytes, max 50 MB, reject DRM.

### Pipeline: Passage Generation
1. Check usage meter
2. Validate/sanitize topic input
3. Build prompt: CEFR level, interests, topic, style, length, sample of known vocabulary
4. Stream via SSE from MiMo v2 Flash (OpenRouter `stream: true`)
5. Validate JSON output against Pydantic schema
6. On completion: store passage + vocabulary annotations + encounters
7. Increment usage meter
8. On SSE drop: nothing stored, meter not incremented, client retries

### Pipeline: Talk (Real-time Chat)

**Text input:**
1. Check usage meter (talk seconds)
2. Build prompt: conversation history + partner personality (from conversation_partners.system_prompt_template) + CEFR level
3. Stream via SSE from MiMo v2 Flash
4. Store both messages with sequence_number
5. Client runs Qwen3-TTS locally on completed sentences

**Voice input:**
1. Silero VAD detects end of speech on-device
2. Audio -> `POST /v1/talk/transcribe` -> Voxtral Realtime (sub-200ms)
3. Transcription returned, then same flow as text

**Abandoned conversations:** Background job sets status=abandoned after 30 min inactivity, meters duration.

### Background Job: Daily Passage Generation
- Scheduled ARQ job runs daily (e.g., 4 AM in each user's timezone)
- For each active user with available passage quota: generate one passage based on active language, CEFR level, and interests
- Store as a normal passage with `is_generated: true`
- `GET /v1/home` returns this as `todays_passage`. If already read (reading_progress >= 1.0), fall back to most recent unread passage.

### Pipeline: Post-Conversation Feedback
1. Background job (ARQ) on conversation end
2. Full transcript -> MiMo v2 Flash
3. Structured analysis: scores, strengths, corrections
4. Store feedback, extract new vocabulary -> VocabularyItems + encounters
5. Push notify or client polls (202 while generating)

### Pipeline: Word Definition / Translation
1. Check Redis cache (`def:{lang}:{word}:{context_hash}`, TTL 30 days)
2. If miss, call MiMo Flash with word + context sentence
3. Cache result, return
4. Increment translations meter (translate only, not define)

### Pipeline: Book Import
1. Validate (magic bytes, max 50 MB, DRM check)
2. Upload to R2: `books/{book_id}/original.{ext}`
3. Create book record (status: queued)
4. ARQ background job:
   - Extract text (EPUB via ebooklib, PDF via pdfplumber, TXT direct)
   - Split chapters, store each as R2 JSON
   - Update processing_progress as chapters complete
   - Vocabulary extraction per chapter via MiMo Flash
   - Cross-reference Language Bank
   - Set overall CEFR level, status: ready
5. Push notify on completion/failure

---

## 5. On-Device Models & Timestamping

### On-Device Stack (bundled in app binary, iOS 18+)

| Model | Size | Purpose |
|-------|------|---------|
| Qwen3-TTS 0.6B (CoreML) | ~1.0 GB | TTS, 10 languages, preset speakers |
| Silero VAD v5 (CoreML) | ~3 MB | End-of-speech detection |
| Qwen3-ASR 0.6B (CoreML) | ~180 MB | Word-level timestamps |

**App Store binary size: ~1.2 GB+.** All models ship with the app. No post-install downloads. User gets full functionality immediately after install.

### Voice Personalities (Preset Speakers)

Qwen3-TTS provides 9 built-in speakers. These are mapped to the 6 app characters per language in the `conversation_partners.voice_config` JSONB column. Example mapping:

| Character | Personality | Speaker (primary) |
|-----------|------------|-------------------|
| Mia | Friendly · Natural | Vivian |
| Carlos | Calm · Clear | Ryan |
| Elena | Expressive · Warm | Serena |
| Lucia | Bright · Energetic | Sohee |
| Diego | Warm · Confident | Aiden |
| Marco | Deep · Thoughtful | Dylan |

Qwen3-TTS handles cross-lingual synthesis natively — a speaker trained on English can synthesize Spanish, French, German, etc. with natural accent adaptation. The voice_config can override per-language if a specific speaker sounds better in a given language.

### Timestamping Strategy (No Forced Aligner)

**Tier 1 — Sentence-level highlighting (default):**
- Split passage into sentences (`NLTokenizer` with `.sentence` unit)
- Generate TTS per sentence via Qwen3-TTS
- Highlight active sentence during playback
- Matches design spec (screen 4d): "The text dims except for the currently spoken sentence"

**Tier 2 — Word-level highlighting (bundled, +0 download):**
- After Qwen3-TTS generates audio for a sentence, run through Qwen3-ASR (already bundled)
- Clean TTS audio = near-perfect ASR accuracy
- Qwen3-ASR outputs word-level timestamps
- Map to character offsets for highlight-following

Both tiers work offline since all models are bundled.

### Offline Mode
**Works offline:** Reading cached passages, TTS, sentence/word highlighting, flashcard reviews, Language Bank browsing, cached definitions
**Requires network:** Passage generation, Talk conversations, new definitions/translations, book upload, account sync

### Sync Architecture

**`POST /v1/sync`** — event-sourced reviews, last-write-wins for everything else.

```json
{
  "device_id": "...",
  "last_synced_at": "2026-04-07T10:00:00Z",
  "review_events": [{"vocabulary_item_id": "...", "quality": 3, "reviewed_at": "..."}],
  "reading_progress": [{"passage_id": "...", "progress": 0.75, "updated_at": "..."}],
  "book_progress": [{"book_id": "...", "reading_progress": 0.55, "last_read_chapter": 4, "last_read_position": 1200, "updated_at": "..."}],
  "streak_updates": [{"date": "2026-04-07", "minutes_studied": 15, "cards_reviewed": 12, "passages_read": 1}],
  "vocabulary_changes": [{"action": "add|update|delete", "item": {"id": "...", "text": "...", "status": "..."}}],
  "listening_seconds": 360,
  "settings": {"updated_at": "...", "changes": {"voice_speed": 1.2}}
}
```

**Conflict resolution:**
- Review events: append-only. SM-2 state recomputed by replaying all events chronologically.
- Reading progress (passages): `MAX(local, remote)` — progress only moves forward
- Book progress: `MAX(reading_progress)`, latest `last_read_chapter`/`last_read_position` by updated_at
- Streak data: sum values for same date from different devices
- Vocabulary changes: server applies in order; conflicts on same item resolved by updated_at
- Listening seconds: sum (additive from all devices)
- Settings: last-write-wins by updated_at

---

## 6. Real-Time Chat: SSE over HTTP

FastAPI native SSE via `sse-starlette` (`EventSourceResponse`):

```python
@app.post("/v1/talk/conversations/{id}/messages")
async def send_message(id: str, body: MessageRequest):
    async def event_generator():
        async for chunk in openrouter_stream(model=settings.MODEL_ROUTING["chat"], messages=prompt):
            yield {"data": chunk.json()}
        yield {"data": "[DONE]"}
    return EventSourceResponse(event_generator())
```

**Supabase:** Send keepalive comments every 15s for long-running SSE connections.

**TTS streaming:** Client begins Qwen3-TTS synthesis on the first complete sentence from the SSE stream. Buffer tokens, detect sentence boundaries, dispatch to TTS immediately.

---

## 7. Authentication & Subscriptions

### Auth: Supabase Auth (fully managed)

**What Supabase handles:** Registration, login, Apple Sign-In, Google Sign-In, email verification, password reset, JWT issuance, refresh token rotation, session management.

**What FastAPI handles:** JWT verification middleware (~20 lines), user record creation in Supabase Postgres on first request, account deletion cascade.

**FastAPI auth dependency:**
```python
from fastapi import Depends, HTTPException
import jwt

async def get_current_user(authorization: str = Header(...)) -> User:
    token = authorization.replace("Bearer ", "")
    payload = jwt.decode(token, settings.SUPABASE_JWT_SECRET, algorithms=["HS256"], audience="authenticated")
    user = await get_or_create_user(supabase_uid=payload["sub"], email=payload.get("email"))
    return user
```

**iOS client:** Uses `supabase-swift` SDK for all auth flows. Token refresh is automatic.

**Account deletion:** `DELETE /v1/me/account` queues a cascade job that deletes all user data from Supabase Postgres + R2, then calls Supabase Admin API to delete the auth user.

### Subscriptions: StoreKit 2 + App Store Server Notifications V2
- Client handles purchase flow via StoreKit 2
- Client sends transaction JWS to `POST /v1/me/subscription/verify`
- "Restore Purchases" button calls `POST /v1/me/subscription/restore`
- Server validates JWS against Apple's certificate chain
- Webhook `POST /v1/webhooks/appstore` — **must verify JWS signature** on every notification
- Handles: SUBSCRIBED, DID_RENEW, EXPIRED, REVOKE, DID_FAIL_TO_RENEW, GRACE_PERIOD_EXPIRED
- All events logged to subscription_events table
- Usage limits enforced via middleware + Redis counters

**Usage metering:**
- Period boundaries: calendar month in user's timezone
- Chat duration: server-side, first message to /end (or abandoned timeout)
- SSE drop: passage not stored, meter not incremented
- Mid-month upgrade: meter's subscription_tier field updated, limits change immediately
- Redis failure: rate limiting fails open, usage metering falls back to Postgres

---

## 8. Spaced Repetition: Modified SM-2

### 2-Button UI
| Button | Label | Quality | Effect |
|--------|-------|---------|--------|
| Wrong | "I got it wrong" | q=1 | Reset to 1 day, ease factor drops |
| Right | "I got it right" | q=3 | Advance interval, ease factor adjusts slightly |

Two buttons keep the review frictionless — the user either knows it or doesn't. Using q=3 (not q=4) for "right" is deliberately conservative: it treats every correct answer as "recalled with some effort," which keeps intervals from growing too aggressively. This is the safer direction for language learning — better to review slightly too often than to forget.

### Algorithm
```python
if q >= 3:  # correct (q=3)
    if repetitions == 0: interval = 1
    elif repetitions == 1: interval = 6
    else: interval = round(interval * ease_factor)
    repetitions += 1
else:  # incorrect (q=1)
    repetitions = 0
    interval = 1

ease_factor = max(1.3, ease_factor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
next_review_date = start_of_next_day(user.timezone) + timedelta(days=interval - 1)
```

### Learning Steps (new cards)
1. First correct: show again in 1 minute (within session)
2. Second correct: show again in 10 minutes
3. Third correct: graduates to spaced queue (interval=1 day)

### Context Reset (re-highlight forgotten word)
- repetitions=0, interval=0, ease_factor = max(1.3, min(ease_factor, 2.0)), status=learning

### Ease Factor Recovery
After 5 consecutive correct at ease_factor <= 1.5, bump by 0.1.

### Study Modes
- **Daily Review** (default): cards where `next_review_date <= today`, ordered by next_review_date ASC
- **Hardest Cards**: cards where `ease_factor < 2.0` OR `times_correct / times_reviewed < 0.6`
- **New Cards Only**: cards where `status == new`, ordered by created_at ASC, limited by `new_words_per_day`
- **Review Ahead**: cards where `next_review_date <= today + 3 days`, ordered by next_review_date ASC
- **Random Mix**: random selection from all due + learning cards

All modes support `?type=word|phrase|sentence` filter and `?count_only=true` for badge counts.

---

## 9. Caching & Rate Limiting (Upstash Redis)

### Cache Strategy
| Key | TTL | Purpose |
|-----|-----|---------|
| `def:{lang}:{word}:{ctx}` | 30 days | Word definitions |
| `trans:{lang}:{hash}` | 7 days | Translations |
| `usage:{user_id}:{period}` | Period end | Usage counters |
| `ratelimit:{user_id}:{ep}` | 1 min | Rate limiting |
| `forecast:{user_id}` | 1 hour | Flashcard forecast |

### Rate Limits
| Endpoint | Limit | Window |
|----------|-------|--------|
| AI generation | 30 req | 1 min |
| Definitions/translations | 60 req | 1 min |
| Read endpoints | 120 req | 1 min |
| File upload | 5 req | 10 min |
| Sync | 10 req | 1 min |

Redis down: rate limiting fails open, usage metering reads from Postgres.

---

## 10. Deployment

```
iOS Client (SwiftUI, iOS 18+)
  Bundled: Qwen3-TTS (1.0 GB), Silero VAD (3 MB), Qwen3-ASR (180 MB)
  Local: Core Data (offline cache + SM-2)
       |
       | HTTPS + SSE (/v1/)
       v
Supabase Auth ←── iOS authenticates directly
  (Apple/Google/email, JWT issuance)
       |
       | JWT verified locally by FastAPI
       v
Supabase (FastAPI + uvicorn + ARQ worker)
       |
  +---------+---------+
  |         |         |
  v         v         v
Supabase  Upstash   Cloudflare R2
Postgres  Redis     (books, chapters)
          (free)    (free)

External APIs:
  - OpenRouter (MiMo v2 Flash, Gemma 4 fallback)
  - Mistral (Voxtral Realtime)

Webhooks:
  - Apple App Store Server Notifications V2
```

### Cost (~100 users)
| Service | Monthly |
|---------|---------|
| Supabase (Auth + Postgres + Backend) | $0 (free tier) |
| Upstash Redis | $0 |
| Cloudflare R2 | $0 |
| OpenRouter (MiMo) | ~$10-25 |
| Mistral (Voxtral) | ~$5-15 |
| Apple Developer | $8.25 |
| **Total** | **~$25-50/month** |

### CI/CD
- GitHub Actions: lint, test, deploy to Supabase
- Alembic for database migrations
- Docker build: ~30-60 seconds

---

## 11. Japanese Language Considerations

Japanese has no spaces between words.

**Word boundaries:** The LLM identifies vocabulary words with character offsets during passage generation. For non-highlighted words the user taps, use iOS `CFStringTokenizer` with Japanese locale.

**Timestamping:** Qwen3-TTS and Qwen3-ASR both natively support Japanese. Sentence-level highlighting works identically. Word-level via ASR handles Japanese tokenization natively.

---

## 12. MVP Build Sequence

**Phase 1 — Foundation (Week 1-2):**
- FastAPI scaffold + CI/CD on Supabase
- Supabase project setup (Apple/Google/email auth configured)
- SQLAlchemy models + Alembic migrations + Supabase Postgres setup
- Supabase JWT verification middleware
- `GET /v1/me` with auto-create user on first call
- User settings CRUD
- `GET /v1/health`

**Phase 2 — Core Reading (Week 3-4):**
- OpenRouter integration (`AIService` with config-based model routing)
- Passage generation with SSE streaming
- Word definition + translation with Redis caching
- Usage metering middleware
- Vocabulary encounters

**Phase 3 — Talk (Week 5-6):**
- ConversationPartner seed data (6 characters with voice_config)
- Conversation CRUD + SSE streaming
- Voxtral Realtime transcription
- Post-conversation feedback (ARQ background job)
- Abandoned conversation cleanup job

**Phase 4 — Flashcards & Vocabulary (Week 7-8):**
- Language Bank CRUD + batch endpoint
- Modified SM-2 with 3 buttons + learning steps
- ReviewEvent append-only log + sync endpoint
- Session tracking + cached forecast stats

**Phase 5 — Books & Polish (Week 9-10):**
- Book upload + R2 storage + validation (magic bytes, DRM, 50 MB limit)
- Processing pipeline (ARQ job with progress)
- Subscription management (StoreKit 2 + App Store webhooks with JWS verification)
- Achievement system + push notifications

---

## Key Files to Create

| File | Purpose |
|------|---------|
| `app/main.py` | FastAPI app, middleware, router registration |
| `app/core/config.py` | Settings, model routing table, API keys, limits |
| `app/core/auth.py` | Supabase JWT verification dependency (~20 lines) |
| `app/models/` | SQLAlchemy models |
| `app/schemas/` | Pydantic request/response models |
| `app/services/ai_service.py` | OpenRouter client, config-based model routing, SSE proxy |
| `app/services/transcription.py` | Voxtral Realtime client |
| `app/services/sync_service.py` | Delta sync + event-sourced review reconciliation |
| `app/api/v1/home.py` | Aggregated home screen endpoint |
| `app/api/v1/me.py` | User profile, settings, languages, subscription, account deletion |
| `app/api/v1/passages.py` | Passage generation + CRUD |
| `app/api/v1/talk.py` | Chat SSE, transcription, feedback |
| `app/api/v1/flashcards.py` | SM-2 engine, due cards, sessions |
| `app/api/v1/books.py` | Upload, status, chapters |
| `app/middleware/rate_limit.py` | Redis sliding window |
| `app/middleware/usage_meter.py` | Subscription limit enforcement |
| `app/jobs/book_processing.py` | EPUB/PDF parsing, R2, vocabulary extraction |
| `app/jobs/feedback.py` | Post-conversation analysis |
| `app/jobs/cleanup.py` | Abandoned conversations, account deletion cascade |
| `app/jobs/daily_passage.py` | Daily passage generation for each active user |
| `alembic/` | Database migrations |
| `Dockerfile` | Python slim + uvicorn |

---

## Verification Plan

1. **Auth:** Supabase Apple/Google/email sign-in from iOS. Verify JWT in FastAPI. Auto-create user on first `GET /v1/me`. Test account deletion cascade.
2. **Passage Generation:** SSE stream, validate JSON, test prompt injection, test mid-stream disconnect.
3. **Talk:** Text messages via SSE, voice via Voxtral Realtime, end -> feedback. Test abandoned timeout.
4. **Flashcards:** All 3 quality ratings, learning steps, context reset, sync with review events from 2 devices.
5. **Usage Limits:** Exhaust free tier, verify 402. Test mid-month upgrade.
6. **Book Import:** EPUB (valid), PDF, DRM file. Verify progress updates, chapter content from R2.
7. **Webhook:** Test App Store notification with JWS verification.
8. **Model Swap:** Change one task in config from MiMo to Gemma 4. Verify it works without code changes.
9. **Health:** `GET /v1/health` returns DB + Redis status.
