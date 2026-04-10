"""Application settings loaded from environment variables."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """LangBrew API configuration.

    All values are read from environment variables or a `.env` file in the
    project root.  Pydantic-settings handles type coercion automatically.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Application
    APP_ENV: str = "development"
    API_V1_PREFIX: str = "/v1"

    # Database (Supabase Postgres)
    DATABASE_URL: str

    # Cache (Upstash Redis)
    REDIS_URL: str

    # Auth (Supabase)
    SUPABASE_JWT_SECRET: str
    SUPABASE_JWT_JWK: str = ""
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_ROLE_KEY: str = ""

    # AI (OpenRouter)
    OPENROUTER_API_KEY: str

    # STT (Mistral)
    MISTRAL_API_KEY: str

    # Storage (Cloudflare R2)
    R2_ACCESS_KEY_ID: str
    R2_SECRET_ACCESS_KEY: str
    R2_BUCKET_NAME: str = "langbrew"
    R2_ENDPOINT_URL: str

    @property
    def is_development(self) -> bool:
        return self.APP_ENV == "development"


settings = Settings()  # type: ignore[call-arg]
