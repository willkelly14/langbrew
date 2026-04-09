"""ORM models package — import all models so Alembic can discover them."""

from app.models.base import Base
from app.models.device_token import DeviceToken
from app.models.enums import (
    CEFRLevel,
    GenerateMode,
    LineSpacing,
    PassageLength,
    PassageStyle,
    ReadingFont,
    ReadingTheme,
    SourceType,
    SubscriptionTier,
    VocabularyStatus,
    VocabularyType,
)
from app.models.passage import Passage
from app.models.passage_vocabulary import PassageVocabulary
from app.models.usage_meter import UsageMeter
from app.models.user import User
from app.models.user_language import UserLanguage
from app.models.user_settings import UserSettings
from app.models.user_streak import UserStreak
from app.models.vocabulary import VocabularyEncounter, VocabularyItem

__all__ = [
    "Base",
    "CEFRLevel",
    "DeviceToken",
    "GenerateMode",
    "LineSpacing",
    "Passage",
    "PassageLength",
    "PassageStyle",
    "PassageVocabulary",
    "ReadingFont",
    "ReadingTheme",
    "SourceType",
    "SubscriptionTier",
    "UsageMeter",
    "User",
    "UserLanguage",
    "UserSettings",
    "UserStreak",
    "VocabularyEncounter",
    "VocabularyItem",
    "VocabularyStatus",
    "VocabularyType",
]
