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
