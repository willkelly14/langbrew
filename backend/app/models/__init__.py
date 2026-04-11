"""ORM models package — import all models so Alembic can discover them."""

from app.models.base import Base
from app.models.device_token import DeviceToken
from app.models.dictionary import DictionaryEntry, DictionaryForm
from app.models.enums import (
    CardTypeFilter,
    CEFRLevel,
    GenerateMode,
    LineSpacing,
    PassageLength,
    PassageStyle,
    ReadingFont,
    ReadingTheme,
    SourceType,
    StudyMode,
    SubscriptionTier,
    VocabularyStatus,
    VocabularyType,
)
from app.models.passage import Passage
from app.models.passage_vocabulary import PassageVocabulary
from app.models.review_event import ReviewEvent
from app.models.session_review import SessionReview
from app.models.study_session import StudySession
from app.models.usage_meter import UsageMeter
from app.models.user import User
from app.models.user_language import UserLanguage
from app.models.user_settings import UserSettings
from app.models.user_streak import UserStreak
from app.models.vocabulary import VocabularyEncounter, VocabularyItem

__all__ = [
    "Base",
    "CEFRLevel",
    "CardTypeFilter",
    "DeviceToken",
    "DictionaryEntry",
    "DictionaryForm",
    "GenerateMode",
    "LineSpacing",
    "Passage",
    "PassageLength",
    "PassageStyle",
    "PassageVocabulary",
    "ReadingFont",
    "ReadingTheme",
    "ReviewEvent",
    "SessionReview",
    "SourceType",
    "StudyMode",
    "StudySession",
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
