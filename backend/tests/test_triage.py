import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_triage_assess_endpoint():
    """Verify triage assess endpoint processes request."""
    payload = {
        "chief_complaint": "Persistent chest tightness and dizziness",
        "symptoms": ["chest tightness", "dizziness"],
        "patient_location": {"latitude": 3.1390, "longitude": 101.6869}
    }
    response = client.post("/api/triage/assess", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "assessment" in data["data"]
    assert "recommended_hospitals" in data["data"]


def test_triage_chat_endpoint_graceful_fallback():
    """Verify triage chat endpoint handles agent conversation and fallback safely."""
    payload = {
        "message": "I have sudden numbness on my left side."
    }
    response = client.post("/api/triage/chat", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["success"] is True
    assert "reply" in data["data"]
    assert len(data["data"]["reply"]) > 0
