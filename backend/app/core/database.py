import logging
from typing import Optional, Generator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session, declarative_base
from app.core.config import get_settings

logger = logging.getLogger(__name__)

Base = declarative_base()

_engine = None
_SessionFactory = None


def get_engine():
    """Returns SQLAlchemy engine for PostgreSQL/Supabase."""
    global _engine
    if _engine is None:
        settings = get_settings()
        uri = settings.get_database_uri()
        # For SQLite fallback during early local development
        connect_args = {"check_same_thread": False} if uri.startswith("sqlite") else {}
        try:
            _engine = create_engine(uri, connect_args=connect_args)
            logger.info("Database engine initialized.")
        except Exception as e:
            logger.warning(f"Failed to initialize database engine: {e}")
            return None
    return _engine


def get_session_factory():
    """Returns SQLAlchemy session factory."""
    global _SessionFactory
    if _SessionFactory is None:
        engine = get_engine()
        if engine:
            _SessionFactory = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return _SessionFactory


def get_db_session() -> Generator[Optional[Session], None, None]:
    """Dependency generator for database sessions in FastAPI routes."""
    session_factory = get_session_factory()
    if session_factory is None:
        yield None
        return

    session = session_factory()
    try:
        yield session
    finally:
        session.close()


def reset_db_engine() -> None:
    """Resets cached engine and session factory instances (useful for testing or config reload)."""
    global _engine, _SessionFactory
    if _engine is not None:
        try:
            _engine.dispose()
        except Exception:
            pass
    _engine = None
    _SessionFactory = None


def test_db_connection(timeout: int = 5) -> dict:
    """Tests the database connection and returns connection diagnostics.
    
    Args:
        timeout: Connection timeout in seconds.
        
    Returns:
        dict: Diagnostics dictionary containing connection status and error details if any.
    """
    from sqlalchemy import text
    from app.core.config import get_database_uri

    uri = get_database_uri()

    # Mask password for secure logging / output
    masked_uri = uri
    if "@" in uri and "://" in uri:
        prefix, rest = uri.split("://", 1)
        creds, host_part = rest.split("@", 1)
        if ":" in creds:
            user, _ = creds.split(":", 1)
            masked_uri = f"{prefix}://{user}:****@{host_part}"

    engine = get_engine()
    if engine is None:
        return {
            "status": "error",
            "connected": False,
            "database_uri": masked_uri,
            "error": "Failed to create SQLAlchemy engine instance."
        }

    try:
        connect_args = {"check_same_thread": False} if uri.startswith("sqlite") else {"connect_timeout": timeout}
        test_engine = create_engine(uri, connect_args=connect_args)
        with test_engine.connect() as conn:
            result = conn.execute(text("SELECT 1")).scalar()
            return {
                "status": "connected",
                "connected": True,
                "database_uri": masked_uri,
                "result": result,
                "message": "Database connection established successfully."
            }
    except Exception as e:
        return {
            "status": "error",
            "connected": False,
            "database_uri": masked_uri,
            "error": str(e),
            "message": "Database connection failed. Please verify database server is running and credentials/host are correct."
        }

