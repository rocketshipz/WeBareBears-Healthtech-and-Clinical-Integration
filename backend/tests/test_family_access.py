import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.api.routes.auth import get_auth_service
from app.api.routes.family import digest
from app.core.config import get_settings
from app.core.database import Base, get_engine, get_session_factory
from app.models.family_access import FamilyAccess, FamilyInvitation
from app.models.progress import PatientProgress
from app.models.user import User
from app.services.auth_service import _hash_password


@pytest.fixture
def accounts(monkeypatch):
    monkeypatch.setattr(get_settings(), 'PUBLIC_BACKEND_URL', '')
    Base.metadata.create_all(get_engine())
    ids = [f'family-{uuid4().hex[:12]}' for _ in range(3)]
    auth = get_auth_service()
    with get_session_factory()() as session:
        for ident in ids:
            session.add(User(id=ident, ic=ident, name=ident, email=f'{ident}@example.com',
                             phone=ident, password_hash=_hash_password('password123')))
            auth._active_sessions[ident] = {'id': ident}
        session.add(PatientProgress(visit_id=ids[0], user_id=ids[0],
                                   visit_status='active', arrival_time=datetime.now(timezone.utc)))
        session.commit()
    yield ids, [{'Authorization': f'Bearer {ident}'} for ident in ids]
    for ident in ids:
        auth._active_sessions.pop(ident, None)


@pytest.mark.asyncio
async def test_single_use_link_login_request_approval_and_revocation(accounts):
    ids, (patient, family, stranger) = accounts
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        assert (await client.post('/api/family/invitations')).status_code == 401
        invitation = (await client.post('/api/family/invitations', headers=patient)).json()
        url = invitation['invitation_url']
        token = url.rsplit('/', 1)[1]
        assert url.startswith('http://test/api/family/invitations/')
        # WhatsApp previews and repeated opens must not use the invitation.
        for _ in range(2):
            page = await client.get(url)
            assert page.status_code == 200
            assert 'Log in and request access' in page.text
            assert page.headers['cache-control'] == 'no-store'
            assert ids[0] not in page.text
        assert (await client.post('/api/family/requests', json={'token': token})).status_code == 401
        assert (await client.post('/api/family/requests', headers=patient, json={'token': token})).status_code == 422
        # The shared web page can authenticate with the recipient's own account.
        login = await client.post('/api/auth/login', json={'identifier': f'{ids[1]}@example.com', 'password': 'password123'})
        assert login.status_code == 200
        web_family = {'Authorization': f"Bearer {login.json()['data']['token']}"}
        result = await client.post('/api/family/requests', headers=web_family, json={'token': token})
        assert result.status_code == 200 and result.json()['status'] == 'pending'
        for headers in (family, stranger):
            assert (await client.post('/api/family/requests', headers=headers, json={'token': token})).status_code == 410
        assert (await client.get(url)).status_code == 410
        with get_session_factory()() as session:
            stored = session.get(FamilyInvitation, digest(token))
            assert stored.consumed_by == ids[1] and stored.consumed_at
            assert stored.token_hash != token
        assert (await client.get('/api/progress/family', headers=family)).json()['visits'] == []
        incoming = (await client.get('/api/family/requests', headers=patient)).json()['incoming']
        assert len(incoming) == 1 and incoming[0]['viewer_id'] == ids[1]
        assert (await client.get('/api/family/requests', headers=stranger)).json() == {'incoming': [], 'outgoing': []}
        decision_url = f'/api/family/requests/{ids[1]}'
        assert (await client.put(decision_url, headers=stranger, json={'status': 'approved'})).status_code == 404
        assert (await client.put(decision_url, headers=patient, json={'status': 'approved'})).status_code == 200
        shared = (await client.get('/api/progress/family', headers=family)).json()['visits']
        assert [v['id'] for v in shared] == [ids[0]]
        assert shared[0]['profile'] == {'name': ids[0]}
        assert shared[0]['triage'] is None and shared[0]['diagnosis'] is None
        assert (await client.get('/api/progress/family', headers=stranger)).json()['visits'] == []
        assert (await client.put(decision_url, headers=patient, json={'status': 'revoked'})).status_code == 200
        assert (await client.get('/api/progress/family', headers=family)).json()['visits'] == []
        # A rejected/revoked request requires a fresh invitation and fresh approval.
        fresh = (await client.post('/api/family/invitations', headers=patient)).json()['invitation_url'].rsplit('/', 1)[1]
        assert fresh != token
        assert (await client.post('/api/family/requests', headers=family, json={'token': fresh})).json()['status'] == 'pending'
        assert (await client.put(decision_url, headers=patient, json={'status': 'rejected'})).status_code == 200
        assert (await client.get('/api/progress/family', headers=family)).json()['visits'] == []
        await client.post('/api/auth/logout', headers=web_family)


@pytest.mark.asyncio
async def test_expired_invitations_and_public_link_origin(accounts, monkeypatch):
    ids, (patient, family, _) = accounts
    monkeypatch.setattr(get_settings(), 'PUBLIC_BACKEND_URL', 'https://triagemy.example/backend/')
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        link = (await client.post('/api/family/invitations', headers=patient)).json()['invitation_url']
        assert link.startswith('https://triagemy.example/backend/api/family/invitations/')
        token = link.rsplit('/', 1)[1]
        with get_session_factory()() as session:
            session.get(FamilyInvitation, digest(token)).expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
            session.commit()
        assert (await client.post('/api/family/requests', headers=family, json={'token': token})).status_code == 410
        assert (await client.get(f'/api/family/invitations/{token}')).status_code == 410
        with get_session_factory()() as session:
            assert session.get(FamilyAccess, (ids[0], ids[1])) is None


@pytest.mark.asyncio
async def test_concurrent_claims_can_only_create_one_request(accounts):
    ids, (patient, first, second) = accounts
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        link = (await client.post('/api/family/invitations', headers=patient)).json()['invitation_url']
        token = link.rsplit('/', 1)[1]
        responses = await asyncio.gather(*[
            client.post('/api/family/requests', headers=headers, json={'token': token})
            for headers in (first, second)
        ])
        assert sorted(r.status_code for r in responses) == [200, 410]
        with get_session_factory()() as session:
            assert session.query(FamilyAccess).filter_by(patient_id=ids[0]).count() == 1
