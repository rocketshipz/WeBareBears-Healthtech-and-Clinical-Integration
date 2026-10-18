from datetime import date

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.api.routes.auth import get_auth_service
from app.core.database import Base, get_engine, get_session_factory
from app.models.staff import StaffAccount
from app.services.auth_service import _hash_password
from app.models.user import User
from app.models.user_information import UserInformation


@pytest.mark.asyncio
async def test_staff_lookup_requires_auth_and_returns_profile_and_latest_report(monkeypatch):
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as session:
        session.add(StaffAccount(id=100, staff_id='N-100', name='Staff Test',
                                 hospital='Test Hospital', department='Emergency', role='Nurse',
                                 password_hash=_hash_password('staff-test-password'), is_active=True))
        session.add(User(id="lookup-patient", ic="001010-10-1234", phone="0128888888",
                         email="lookup@example.com", name="Lookup Patient", password_hash="private"))
        session.flush()
        session.add(UserInformation(user_id="lookup-patient", date_of_birth=date(2000, 10, 10),
                                    blood_type="O+", allergies=[{"substance": "Penicillin"}],
                                    emergency_contact_name="Family Contact"))
        session.commit()
    auth = get_auth_service()
    auth._active_sessions["patient-test-token"] = {"id": "lookup-patient"}
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        assert (await client.get("/api/admin/patients?ic=001010101234")).status_code == 401
        patient_headers = {"Authorization": "Bearer patient-test-token"}
        assert (await client.get("/api/admin/patients?ic=001010101234", headers=patient_headers)).status_code == 401
        assert (await client.post("/api/admin/login", json={"staff_id": "N-100", "password": "bad"})).status_code == 401
        login = await client.post("/api/admin/login", json={"staff_id": "N-100", "password": "staff-test-password"})
        assert login.status_code == 200
        assert login.json()['staff']['hospital'] == 'Test Hospital'
        assert login.json()['staff']['name'] == 'Staff Test'
        assert 'password_hash' not in login.json()['staff']
        headers = {"Authorization": f"Bearer {login.json()['token']}"}
        lookup = await client.get("/api/admin/patients?ic=001010101234", headers=headers)
        assert lookup.status_code == 200
        assert lookup.json()["triage"] is None
        for symptom in ["Headache", "Chest pain"]:
            saved = await client.post("/api/triage/reports", headers=patient_headers, json={
                "symptom": symptom, "severity": "Severe", "duration": "1 hour",
                "danger_signs": ["Shortness of breath"], "level": 1,
                "submitted_at": "2026-10-18T10:00:00Z",
            })
            assert saved.status_code == 200
        lookup = await client.get("/api/admin/patients?ic=001010-10-1234", headers=headers)
        data = lookup.json()
        assert data["profile"]["emergency_contact_name"] == "Family Contact"
        assert data["profile"]["allergies"] == [{"substance": "Penicillin"}]
        assert "password_hash" not in data["profile"]
        assert data["triage"]["symptom"] == "Chest pain"
        assert (await client.get("/api/admin/patients?ic=not-an-ic", headers=headers)).status_code == 422
        assert (await client.get("/api/admin/patients?ic=999999999999", headers=headers)).status_code == 404
        assert (await client.post("/api/triage/reports", json={})).status_code in (401, 422)
    auth._active_sessions.pop("patient-test-token")


@pytest.mark.asyncio
async def test_staff_login_rejects_inactive_missing_hash_and_duplicate_ids():
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as session:
        for ident, staff_id, active, password_hash in [
            (201, "inactive", False, _hash_password("password")),
            (202, "missing-hash", True, ""),
            (203, "duplicate", True, _hash_password("password")),
            (204, "duplicate", True, _hash_password("password")),
        ]:
            session.add(StaffAccount(id=ident, staff_id=staff_id, is_active=active,
                                     password_hash=password_hash))
        session.commit()
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        for staff_id in ["inactive", "missing-hash", "duplicate", "unknown"]:
            response = await client.post("/api/admin/login", json={"staff_id": staff_id, "password": "password"})
            assert response.status_code == 401
            assert response.json()["detail"] == "Invalid staff ID or password."


@pytest.mark.asyncio
async def test_staff_default_password_and_password_change():
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as session:
        session.add(StaffAccount(id=301, staff_id='starter', is_active=True))
        session.commit()
        assert session.get(StaffAccount, (301, 'starter')).password_hash != 'triagemy123'
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        login = await client.post('/api/admin/login', json={'staff_id': 'starter', 'password': 'triagemy123'})
        assert login.status_code == 200
        headers = {'Authorization': f"Bearer {login.json()['token']}"}
        other = await client.post('/api/admin/login', json={'staff_id': 'starter', 'password': 'triagemy123'})
        url = '/api/admin/change-password'
        payload = {'current_password': 'wrong', 'new_password': 'my-new-password'}
        assert (await client.post(url, json=payload)).status_code == 401
        assert (await client.post(url, json=payload, headers=headers)).status_code == 400
        payload['current_password'] = 'triagemy123'
        assert (await client.post(url, json=payload, headers=headers)).status_code == 200
        assert (await client.post('/api/admin/login', json={'staff_id': 'starter', 'password': 'triagemy123'})).status_code == 401
        assert (await client.post('/api/admin/login', json={'staff_id': 'starter', 'password': 'my-new-password'})).status_code == 200
        other_headers = {'Authorization': f"Bearer {other.json()['token']}"}
        assert (await client.post(url, json=payload, headers=other_headers)).status_code == 401
