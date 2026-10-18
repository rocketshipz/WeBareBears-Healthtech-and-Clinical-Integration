from datetime import date
from types import SimpleNamespace

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.api.routes.auth import get_auth_service
from app.api.routes.triage import get_triage_agent
from app.core.database import Base, get_engine, get_session_factory
from app.models.hospital_directory import HospitalDirectory
from app.models.staff import StaffAccount
from app.models.triage_report import SavedReport
from app.models.user import User
from app.models.user_information import UserInformation
from app.services.auth_service import _hash_password
from app.services.triage_report_service import save_report

CLASSIFIED = {
    "status": "classified", "triage_level": 2, "triage_name": "Emergency", "triage_code": "LEVEL_2_EMERGENT",
    "key_findings": ["Severe ongoing chest pain"], "level_advice": "Go to the emergency department now.",
    "emergency_advice": [], "call_999": False,
    "source_references": [{"rule_id": "RULE_CP_L2_01", "criterion": "Severe pain"}],
}


def screening(session_id, owner_id, result=CLASSIFIED, subject=None):
    return SimpleNamespace(session_id=session_id, owner_id=owner_id, triage_result=result, subject=subject,
                           chief_complaint="my chest hurts", main_symptom="Severe chest pain for 1 hour")


def seed_users():
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as session:
        for ident, ic in [("report-owner", "950101-01-1111"), ("report-mother", "600202-02-2222"),
                          ("report-stranger", "990303-03-3333")]:
            if session.get(User, ident) is None:
                session.add(User(id=ident, ic=ic, name=ident, email=f"{ident}@example.com",
                                 phone=f"01{len(ident)}{ic[-4:]}", password_hash="private"))
                session.flush()
                session.add(UserInformation(user_id=ident, date_of_birth=date(1960, 2, 2)))
        session.commit()


class StubAgent:
    """Stands in for the chat engine: every turn returns the given screening (no LLM)."""

    def __init__(self, session):
        self.session = session

    def has_session(self, session_id):
        return session_id == self.session.session_id

    def session_owner(self, session_id):
        return self.session.owner_id

    def run_session(self, message, **kwargs):
        self.session.last_output = {"type": "text", "question": None, "response": "Done."}
        return self.session


def test_save_report_upserts_by_session_id_from_engine_result():
    seed_users()
    with get_session_factory()() as db:
        assert save_report(screening("s-unclassified", "report-owner",
                                     result={"status": "insufficient_information"}), db) is None
        assert save_report(screening("s-anonymous", None), db) is None
        assert save_report(screening("s-upsert", "report-owner"), db) == "s-upsert"
        updated = dict(CLASSIFIED, triage_level=3, triage_name="Urgent")
        assert save_report(screening("s-upsert", "report-owner", result=updated, subject="self"), db) == "s-upsert"
        # A stale session id reused by another user never overwrites the owner's report.
        assert save_report(screening("s-upsert", "report-stranger"), db) is None
    with get_session_factory()() as db:
        assert db.get(SavedReport, "s-unclassified") is None and db.get(SavedReport, "s-anonymous") is None
        row = db.get(SavedReport, "s-upsert")
        assert row.user_id == "report-owner" and row.subject == "self"
        assert row.report["level"] == 3 and row.report["severity"] == "Level 3 - Urgent"
        assert row.report["symptom"] == "Severe chest pain for 1 hour"
        assert row.main_symptom == "Severe chest pain for 1 hour"
        assert row.reported_severity == "Level 3 - Urgent" and row.danger_signs == "Severe ongoing chest pain"
        assert row.report["source_references"] == [{"rule_id": "RULE_CP_L2_01", "criterion": "Severe pain"}]


@pytest.mark.asyncio
async def test_chat_stores_report_and_links_someone_else_for_checkin():
    seed_users()
    with get_session_factory()() as db:
        db.add(HospitalDirectory(hospital_id="H-901", hospital_name="Report Hospital"))
        db.flush()
        db.add(StaffAccount(id=901, staff_id="R-901", hospital="Report Hospital", department="ED", name="Staff R",
                            is_active=True, role="Nurse", password_hash=_hash_password("password123")))
        db.commit()
    auth = get_auth_service()
    auth._active_sessions["report-owner-token"] = {"id": "report-owner"}
    auth._active_sessions["report-stranger-token"] = {"id": "report-stranger"}
    owner = {"Authorization": "Bearer report-owner-token"}
    stranger = {"Authorization": "Bearer report-stranger-token"}
    app.dependency_overrides[get_triage_agent] = lambda: StubAgent(
        screening("s-mother", "report-owner", subject="other"))
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            reply = (await client.post("/api/triage/chat", headers=owner,
                                       json={"message": "for my mother", "session_id": "s-mother"})).json()["data"]
            assert reply["report_id"] == "s-mother" and reply["subject"] == "other"
            assert reply["assessment"]["triage_level"] == "LEVEL_2_EMERGENT"

            url = "/api/triage/reports/s-mother/subject"
            assert (await client.put(url, json={"ic": "600202022222"})).status_code == 401
            assert (await client.put(url, headers=stranger, json={"ic": "600202022222"})).status_code == 404
            assert (await client.put(url, headers=owner, json={"ic": "123"})).status_code == 422
            missing = await client.put(url, headers=owner, json={"ic": "111111-11-1111"})
            assert missing.status_code == 404 and "No TriageMY account" in missing.json()["detail"]
            linked = await client.put(url, headers=owner, json={"ic": "600202-02-2222"})
            assert linked.json() == {"linked": True}

            login = await client.post("/api/admin/login", json={"staff_id": "R-901", "password": "password123"})
            staff = {"Authorization": f"Bearer {login.json()['token']}"}
            mother = (await client.get("/api/admin/patients?ic=600202022222", headers=staff)).json()
            assert mother["report_id"] == "s-mother" and mother["triage"]["level"] == 2
            # Not shown as the account holder's own triage.
            own = (await client.get("/api/admin/patients?ic=950101011111", headers=staff)).json()
            assert own["report_id"] != "s-mother"

            visit = {"patient_id": "report-mother", "triage_report_id": "s-mother", "acuity": "red",
                     "complaint": "Chest pain", "logs": [], "version": 0, "steps": [
                         {"id": key, "name": key, "status": "waiting"}
                         for key in ["registration", "triage", "doctor", "discharge"]]}
            checked_in = await client.post("/api/admin/visits/report-visit", headers=staff, json=visit)
            assert checked_in.status_code == 200, checked_in.text
            assert checked_in.json()["triage_report_id"] == "s-mother"
            wrong = dict(visit, patient_id="report-owner")
            assert (await client.post("/api/admin/visits/report-visit-2", headers=staff,
                                      json=wrong)).status_code == 422

            # Linking your own IC marks the screening as being for yourself.
            assert (await client.put(url, headers=owner, json={"ic": "950101011111"})).status_code == 200
        with get_session_factory()() as db:
            row = db.get(SavedReport, "s-mother")
            assert row.subject == "self" and row.subject_user_id is None
    finally:
        app.dependency_overrides.pop(get_triage_agent, None)
        auth._active_sessions.pop("report-owner-token", None)
        auth._active_sessions.pop("report-stranger-token", None)
