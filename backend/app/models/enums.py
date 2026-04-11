"""Shared enumeration types used across ORM models and schemas."""

import enum


class SubscriptionTier(enum.StrEnum):
    """User subscription level."""

    FREE = "free"
    FLUENCY = "fluency"


class CEFRLevel(enum.StrEnum):
    """Common European Framework of Reference language proficiency levels."""

    A1 = "A1"
    A2 = "A2"
    B1 = "B1"
    B2 = "B2"
    C1 = "C1"


class ReadingTheme(enum.StrEnum):
    """Reading view colour theme."""

    LIGHT = "light"
    SEPIA = "sepia"
    DARK = "dark"


class ReadingFont(enum.StrEnum):
    """Reading view typeface family."""

    SERIF = "serif"
    SANS = "sans"


class LineSpacing(enum.StrEnum):
    """Reading view line spacing preset."""

    COMPACT = "compact"
    NORMAL = "normal"
    RELAXED = "relaxed"


class PassageStyle(enum.StrEnum):
    """Writing style for AI-generated passages."""

    ARTICLE = "article"
    DIALOGUE = "dialogue"
    STORY = "story"
    LETTER = "letter"


class PassageLength(enum.StrEnum):
    """Desired length for AI-generated passages."""

    SHORT = "short"
    MEDIUM = "medium"
    LONG = "long"


class VocabularyType(enum.StrEnum):
    """Type of vocabulary item."""

    WORD = "word"
    PHRASE = "phrase"
    SENTENCE = "sentence"


class VocabularyStatus(enum.StrEnum):
    """Learning status of a vocabulary item."""

    NEW = "new"
    LEARNING = "learning"
    KNOWN = "known"
    MASTERED = "mastered"


class SourceType(enum.StrEnum):
    """Origin of a vocabulary encounter."""

    PASSAGE = "passage"
    BOOK_CHAPTER = "book_chapter"
    CONVERSATION = "conversation"


class GenerateMode(enum.StrEnum):
    """Passage generation mode."""

    AUTO = "auto"
    CUSTOM = "custom"


class StudyMode(enum.StrEnum):
    """Flashcard study session mode."""

    DAILY = "daily"
    HARDEST = "hardest"
    NEW = "new"
    AHEAD = "ahead"
    RANDOM = "random"


class CardTypeFilter(enum.StrEnum):
    """Filter vocabulary items by type in a study session."""

    ALL = "all"
    WORDS = "words"
    PHRASES = "phrases"
    SENTENCES = "sentences"
