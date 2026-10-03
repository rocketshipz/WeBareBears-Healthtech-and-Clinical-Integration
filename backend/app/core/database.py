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
