from functools import lru_cache
import os
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv
from pydantic_settings import BaseSettings, SettingsConfigDict

# Automatically load .env into os.environ so os.environ.get("GEMINI_API_KEY") works immediately
_backend_dir = Path(__file__).resolve().parent.parent.parent
for _candidate in [_backend_dir / ".env", _backend_dir.parent / ".env"]:
    if _candidate.exists():
        load_dotenv(dotenv_path=_candidate, override=False)


class Settings(BaseSettings):
    """Application settings and environment configuration."""
    
    # Application Configuration
    APP_NAME: str = "MedicTri Backend"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    HOST: str = "127.0.0.1"
    PORT: int = 8000
    
    # Main Agent LLM Configuration (Groq)
    GROQ_API_KEY: Optional[str] = None
    GROQ_MODEL_NAME: str = "openai/gpt-oss-120b"
    GROQ_BASE_URL: Optional[str] = "https://api.groq.com"
    GROQ_TEMPERATURE: float = 0.0

    # Embedding Model Configuration (Google Gemini)
    GEMINI_API_KEY: Optional[str] = None
    GOOGLE_API_KEY: Optional[str] = None
    GEMINI_EMBEDDING_MODEL: str = "gemini-embedding-2"
    
    # Database Configuration (PostgreSQL / Supabase)
    POSTGRES_DB_USER: Optional[str] = None
    POSTGRES_DB_PASSWORD: Optional[str] = None
    POSTGRES_DB_HOST: Optional[str] = "localhost"
    POSTGRES_DB_PORT: str = "5432"
    POSTGRES_DB_NAME: Optional[str] = "postgres"
    DATABASE_URL: Optional[str] = None
    
    # Data Directory
    DATA_DIR: str = str(Path(__file__).resolve().parent.parent.parent / "data")
    
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    def get_database_uri(self) -> str:
        """Returns the PostgreSQL connection string."""
        if self.DATABASE_URL:
            return self.DATABASE_URL
        if self.POSTGRES_DB_USER and self.POSTGRES_DB_PASSWORD:
            import urllib.parse
            encoded_password = urllib.parse.quote_plus(self.POSTGRES_DB_PASSWORD)
            return (
                f"postgresql://{self.POSTGRES_DB_USER}:{encoded_password}@"
                f"{self.POSTGRES_DB_HOST}:{self.POSTGRES_DB_PORT}/{self.POSTGRES_DB_NAME}"
            )
        # Default fallback SQLite memory or dummy URI for testing without DB
        return "sqlite:///./local_placeholder.db"

    def get_groq_api_key(self) -> Optional[str]:
        """Returns the configured Groq API key."""
        return self.GROQ_API_KEY or os.getenv("GROQ_API_KEY")

    def get_groq_base_url(self) -> Optional[str]:
        """Returns the sanitized Groq base URL."""
        url = self.GROQ_BASE_URL or os.getenv("GROQ_BASE_URL") or "https://api.groq.com"
        url = url.rstrip("/")
        if url.endswith("/openai/v1"):
            url = url[:-len("/openai/v1")]
        return url

    def get_gemini_api_key(self) -> Optional[str]:
        """Returns the configured Gemini API key, falling back between GEMINI_API_KEY and GOOGLE_API_KEY."""
        return self.GEMINI_API_KEY or self.GOOGLE_API_KEY or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")


@lru_cache()
def get_settings() -> Settings:
    """Returns cached settings instance and ensures os.environ is populated."""
    s = Settings()
    groq_key = s.get_groq_api_key()
    if groq_key and not groq_key.startswith("your_"):
        if not os.environ.get("GROQ_API_KEY"):
            os.environ["GROQ_API_KEY"] = groq_key

    gemini_key = s.get_gemini_api_key()
    if gemini_key and not gemini_key.startswith("your_"):
        if not os.environ.get("GEMINI_API_KEY"):
            os.environ["GEMINI_API_KEY"] = gemini_key
        if not os.environ.get("GOOGLE_API_KEY"):
            os.environ["GOOGLE_API_KEY"] = gemini_key
    return s
