"""Patient profile (user_information) as triage context: DB lookup, routes, profile -> KB mapping, both modes."""
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.user import User
from app.repositories.patient_repository import PatientRepository
from app.services.patient_context import HISTORY_GROUPS, load_profile, pregnancy_condition_ids, profile_findings
from app.services.patient_service import PatientService
from app.services.triage_rules_engine import get_triage_rules_engine

TRAUMA = "Trauma & Physical Injuries"


@pytest.fixture
def session_factory(monkeypatch):
    """In-memory database with one user and their user_information, used by PatientService()."""
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine)
    session = factory()
    session.add(User(id="u1", ic="900101015555", phone="0123456789", email="a@b.com", password_hash="x"))
    session.commit()
    PatientRepository(session).upsert(
        "u1", date_of_birth=date(date.today().year - 71, 1, 1), sex_at_birth="male",
        chronic_conditions=[{"name": "Atrial fibrillation"}], current_medications=[{"name": "Warfarin 3mg"}])
    session.close()
    monkeypatch.setattr("app.services.patient_service.get_session_factory", lambda: factory)
    return factory


def test_patient_service_opens_its_own_db_session(session_factory):
    ctx = PatientService().get_agent_context("u1")
    assert ctx["sex_at_birth"] == "male" and ctx["current_medications"] == ["Warfarin 3mg"]
    assert ctx["age"] in (70, 71)
    assert PatientService().get_patient_profile("u1").gender == "male"
    assert load_profile("nobody") == {} and load_profile(None) == {}


def test_load_profile_never_raises(monkeypatch):
    def broken():
        raise RuntimeError("database down")
    monkeypatch.setattr("app.services.patient_service.get_session_factory", broken)
    assert load_profile("u1") == {}


def test_patients_me_routes(session_factory):
    from app.api.routes.auth import get_auth_service
    from app.main import app
    get_auth_service()._active_sessions["tok"] = {"id": "u1"}
    client = TestClient(app)
    try:
        assert client.get("/api/patients/me").status_code == 401
        me = client.get("/api/patients/me", headers={"Authorization": "Bearer tok"})
        assert me.status_code == 200 and me.json()["data"]["patient_id"] == "u1"
        ctx = client.get("/api/patients/me/triage-context", headers={"Authorization": "Bearer tok"})
        assert ctx.json()["data"]["current_medications"] == ["Warfarin 3mg"]
    finally:
        get_auth_service()._active_sessions.pop("tok", None)


def test_triage_chat_queries_the_profile_once_per_new_session(monkeypatch):
    from app.api.routes import triage as route
    from app.api.routes.auth import get_auth_service
    from app.main import app
    loaded, contexts = [], []
    monkeypatch.setattr(route, "load_profile", lambda pid: loaded.append(pid) or {"age": 40})

    class Engine:
        sessions = set()

        def has_session(self, sid):
            return sid in self.sessions

        def run_session(self, message, context=None, session_id=None, selected_options=None, note=None):
            contexts.append(context)
            self.sessions.add("s1")

            class S:
                session_id, triage_result, messages = "s1", None, []
                last_output = {"type": "text", "question": None, "response": "ok"}
            return S()

    app.dependency_overrides[route.get_triage_agent] = lambda: Engine()
    get_auth_service()._active_sessions["tok"] = {"id": "u1"}
    try:
        client = TestClient(app)
        headers = {"Authorization": "Bearer tok"}
        client.post("/api/triage/chat", json={"message": "hi"}, headers=headers)
        client.post("/api/triage/chat", json={"message": "again", "session_id": "s1"}, headers=headers)
    finally:
        app.dependency_overrides.clear()
        get_auth_service()._active_sessions.pop("tok", None)
    assert loaded == ["u1"]  # queried before the first turn only
    assert contexts == [{"patient_id": "u1", "profile": {"age": 40}}, None]


def test_history_table_ids_exist_in_the_kb():
    engine = get_triage_rules_engine()
    for group in HISTORY_GROUPS:
        for condition_id in group["condition_ids"]:
            assert condition_id in engine.conditions, condition_id
    assert all(i in engine.conditions for i in pregnancy_condition_ids())


def test_profile_findings_uses_only_what_is_listed():
    found = profile_findings({"age": 70, "sex_at_birth": "male", "current_medications": ["Warfarin"],
                              "chronic_conditions": ["Type 2 diabetes"]})
    assert found["age_years"] == 70
    assert "RULE_TRAUMA_L4_01.C3" in found["history_condition_ids"]  # anticoagulant use
    assert "RULE_ABD_L3_01.C5" in found["absent_condition_ids"]  # male: not pregnant
    assert "warfarin" in found["note"].lower()
    # Nothing listed -> nothing ruled out (except pregnancy for male) and no history.
    empty = profile_findings({"sex_at_birth": "female"})
    assert empty["history_condition_ids"] == [] and empty["absent_condition_ids"] == []
    assert profile_findings({"chronic_conditions": ["Epilepsy"]})["history_condition_ids"][0] == "RULE_NEURO_L4_01.C4"
    # Word-start matching: "itp" in another word is not a bleeding disorder.
    assert profile_findings({"chronic_conditions": ["Gitpain"]})["history_condition_ids"] == []


def test_history_only_counts_in_the_screened_categories():
    engine = get_triage_rules_engine()
    epilepsy = "RULE_NEURO_L4_01.C4"
    res = engine.evaluate(categories=[TRAUMA], age_years=25, history_condition_ids=[epilepsy])
    assert res["at_least_level"] is None  # a sprained ankle does not become Level 4
    res = engine.evaluate(categories=[TRAUMA], age_years=70, history_condition_ids=["RULE_TRAUMA_L4_01.C3"])
    assert res["at_least_level"] == 4  # anticoagulant use is a Trauma rule
