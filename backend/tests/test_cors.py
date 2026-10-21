import importlib

from fastapi.testclient import TestClient

from app.core.config import get_settings


def _preflight(client, origin):
    return client.options("/api/health", headers={
        "Origin": origin, "Access-Control-Request-Method": "GET",
    }).headers.get("access-control-allow-origin")


def test_restricted_origins_still_allow_localhost(monkeypatch):
    """With CORS_ORIGINS set for a deployment, the listed site and local dev servers work; others do not."""
    import app.main as main_module

    monkeypatch.setenv("CORS_ORIGINS", "https://triagemy.vercel.app/, https://other.example")
    get_settings.cache_clear()
    try:
        client = TestClient(importlib.reload(main_module).app)
        assert _preflight(client, "https://triagemy.vercel.app") == "https://triagemy.vercel.app"
        assert _preflight(client, "http://localhost:53124") == "http://localhost:53124"
        assert _preflight(client, "http://127.0.0.1:8080") == "http://127.0.0.1:8080"
        assert _preflight(client, "https://evil.example") is None
        assert _preflight(client, "http://localhost.evil.example") is None
    finally:
        monkeypatch.delenv("CORS_ORIGINS")
        get_settings.cache_clear()
        importlib.reload(main_module)


def test_default_allows_any_origin():
    from app.main import app
    client = TestClient(app)
    assert _preflight(client, "https://anything.example") == "https://anything.example"
