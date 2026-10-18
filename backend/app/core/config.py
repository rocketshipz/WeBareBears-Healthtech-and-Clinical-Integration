from functools import lru_cache
import os
from pathlib import Path
from typing import Optional
from dotenv import load_dotenv
from pydantic import field_validator
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
    
    # Main Agent LLM Configuration (Azure OpenAI, OpenAI-compatible v1 endpoint)
    OPENAI_API_KEY: Optional[str] = None
    OPENAI_MODEL_NAME: str = "gpt-5-mini"  # Azure: the *deployment name*
    OPENAI_BASE_URL: Optional[str] = None
    OPENAI_TEMPERATURE: float = 0.0

    # /triage/chat engine: "agent" (LLM tool-calling loop) or "hybrid" (code runs the screening; the LLM only
    # reads free text and phrases replies). See app/services/triage_controller.py.
    TRIAGE_MODE: str = "agent"

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
    
    # Waiting-time label job (ratio = numerator / denominator -> label, every N minutes).
    # TODO: set these to the real Supabase table/column names (override via backend/.env).
    WAIT_LABEL_ENABLED: bool = True
    WAIT_LABEL_INTERVAL_MINUTES: int = 5
    WAIT_LABEL_TABLE: str = "MOCK_level_1_waiting_time"
    WAIT_LABEL_KEY_COL: str = "hospital_id"
    WAIT_LABEL_NUMERATOR_COL: str = "current_ed_patients"
    WAIT_LABEL_DENOMINATOR_COL: str = "operational_ed_spaces"
    WAIT_LABEL_COL: str = "activity_level"  # the column to update with "low", "moderate", "busy", "very busy"
    # Upper bounds (exclusive) for low / moderate / busy; anything above is "very busy".
    WAIT_LABEL_LOW_MAX: float = 0.5
    WAIT_LABEL_MODERATE_MAX: float = 1.0
    WAIT_LABEL_BUSY_MAX: float = 1.5 # Anything above is "very busy".

    # Data Directory
    DATA_DIR: str = str(Path(__file__).resolve().parent.parent.parent / "data")
    
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

    @field_validator("DEBUG", mode="before")
    @classmethod
    def parse_debug_mode(cls, value):
        """Accept build-mode names used by development environments."""
        if isinstance(value, str):
            mode = value.strip().lower()
            if mode == "release":
                return False
            if mode == "debug":
                return True
        return value

    def get_database_uri(self) -> str:
        """Returns the PostgreSQL connection string.
        
        Supports both PostgreSQL and Supabase. On networks without IPv6 connectivity,
        automatically translates direct Supabase hosts (db.<ref>.supabase.co) to the
        IPv4 connection pooler to prevent DNS resolution errors.
        """
        if self.DATABASE_URL:
            uri = self.DATABASE_URL
        elif self.POSTGRES_DB_USER and self.POSTGRES_DB_PASSWORD:
            import urllib.parse
            encoded_password = urllib.parse.quote_plus(self.POSTGRES_DB_PASSWORD)
            uri = (
                f"postgresql://{self.POSTGRES_DB_USER}:{encoded_password}@"
                f"{self.POSTGRES_DB_HOST}:{self.POSTGRES_DB_PORT}/{self.POSTGRES_DB_NAME}"
            )
        else:
            return "sqlite:///./local_placeholder.db"

        # Check if URI uses a Supabase direct domain (db.<project_ref>.supabase.co)
        # On IPv4-only networks, direct host fails DNS resolution because Supabase direct host is IPv6-only.
        # Fall back gracefully to Supabase IPv4 connection pooler.
        if "@db." in uri and ".supabase.co" in uri:
            import re
            import socket
            match = re.search(r"@db\.([a-z0-9]+)\.supabase\.co(?::(\d+))?", uri)
            if match:
                ref = match.group(1)
                direct_host = f"db.{ref}.supabase.co"
                try:
                    socket.getaddrinfo(direct_host, 5432)
                except socket.gaierror:
                    prefix, rest = uri.split("://", 1)
                    creds, host_part = rest.split("@", 1)
                    user_pwd = creds.split(":", 1)
                    user = user_pwd[0]
                    pwd = user_pwd[1] if len(user_pwd) > 1 else ""
                    if not user.endswith(f".{ref}"):
                        user = f"{user}.{ref}"
                    path_part = host_part.split("/", 1)[1] if "/" in host_part else "postgres"
                    uri = f"{prefix}://{user}:{pwd}@aws-0-ap-southeast-1.pooler.supabase.com:5432/{path_part}"

        return uri

    def get_openai_base_url(self) -> Optional[str]:
        """Returns an OpenAI-compatible base URL.

        Azure AI Foundry project endpoints (https://<res>.services.ai.azure.com/api/projects/<p>)
        are converted to the resource's v1 endpoint (https://<res>.services.ai.azure.com/openai/v1/).
        """
        url = (self.OPENAI_BASE_URL or "").strip().rstrip("/")
        if not url:
            return None
        if ".azure.com" in url and "/openai/v1" not in url:
            url = url.split(".azure.com", 1)[0] + ".azure.com/openai/v1"
        return url + "/" if ".azure.com" in url else url

    def get_gemini_api_key(self) -> Optional[str]:
        """Returns the configured Gemini API key, falling back between GEMINI_API_KEY and GOOGLE_API_KEY."""
        return self.GEMINI_API_KEY or self.GOOGLE_API_KEY or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")


@lru_cache()
def get_settings() -> Settings:
    """Returns cached settings instance and ensures os.environ is populated."""
    s = Settings()

    # Synchronize and ensure database URI is evaluated and stored in environment/settings
    db_uri = s.get_database_uri()
    if db_uri:
        if not os.environ.get("DATABASE_URL"):
            os.environ["DATABASE_URL"] = db_uri
        s.DATABASE_URL = db_uri

    gemini_key = s.get_gemini_api_key()
    if gemini_key and not gemini_key.startswith("your_"):
        if not os.environ.get("GEMINI_API_KEY"):
            os.environ["GEMINI_API_KEY"] = gemini_key
        if not os.environ.get("GOOGLE_API_KEY"):
            os.environ["GOOGLE_API_KEY"] = gemini_key
    return s


def get_database_uri() -> str:
    """Convenience function to retrieve the configured database URI from cached settings."""
    return get_settings().get_database_uri()
