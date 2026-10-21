"""Isolate automated tests from developer databases and API credentials."""
import tempfile
from pathlib import Path

import pytest

_environment = pytest.MonkeyPatch()
_directory = None


def pytest_configure(config):
    global _directory
    _directory = tempfile.TemporaryDirectory(prefix="triagemy-tests-")
    database = Path(_directory.name) / "tests.db"
    for key, value in {
        "TAC_DELIVERY": "test",
        "ENVIRONMENT": "test",
        "DATABASE_URL": "sqlite:///" + database.as_posix(),
        "OPENAI_API_KEY": "dummy-openai-key",
        "OPENAI_BASE_URL": "http://127.0.0.1:1/v1",
        "GEMINI_API_KEY": "dummy-gemini-key",
        "GOOGLE_API_KEY": "dummy-gemini-key",
        "WAIT_LABEL_ENABLED": "false",
        "GOOGLE_MAPS_API_KEY": "",
        "ROUTING_TRAFFIC_ENABLED": "false",
        "CLINIC_HOURS_LOOKUP": "false",
    }.items():
        _environment.setenv(key, value)


def pytest_unconfigure(config):
    from app.core.database import reset_db_engine
    from app.core.config import get_settings
    from app.core.llm import reset_llm_cache

    reset_db_engine()
    get_settings.cache_clear()
    reset_llm_cache()
    _environment.undo()
    if _directory is not None:
        _directory.cleanup()
