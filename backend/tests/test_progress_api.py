from datetime import date
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.api.routes.auth import get_auth_service
from app.core.database import Base, get_engine, get_session_factory
from app.models.user import User
from app.models.user_information import UserInformation
from app.models.staff import StaffAccount
from app.models.hospital_directory import HospitalDirectory
from app.models.progress import PatientProgress, PatientTestTracking
from app.services.auth_service import _hash_password


def stages():
    return [{'id': key, 'name': name, 'is_test': test, 'status': status} for key, name, test, status in [
        ('registration', 'Registration', False, 'done'), ('triage', 'Nurse triage', False, 'waiting'),
        ('blood', 'Blood test', True, 'waiting'), ('custom', 'Custom ultrasound', True, 'waiting'),
        ('doctor', 'Doctor consultation', False, 'waiting'), ('discharge', 'Discharge', False, 'waiting')]]


@pytest.mark.asyncio
async def test_progress_checkin_persistence_auth_conflicts_and_diagnosis_release():
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as session:
        for ident in ['progress-user', 'progress-other']:
            session.add(User(id=ident, ic=ident, name=ident, email=ident+'@example.com', phone='+60123456789' if ident == 'progress-other' else '0199999999', password_hash='private'))
            session.flush()
            session.add(UserInformation(user_id=ident, date_of_birth=date(2000, 1, 1), emergency_contact_phone='0123456789'))
        for ident, hospital in [(801, 'Hospital A'), (802, 'Hospital B')]:
            session.add(HospitalDirectory(hospital_id=f'H-{ident}', hospital_name=hospital))
            session.flush()
            session.add(StaffAccount(id=ident, staff_id=f'P-{ident}', hospital=hospital, department='ED',
                name=f'Staff {ident}', is_active=True, role='Doctor', password_hash=_hash_password('password123')))
        session.commit()
    auth = get_auth_service()
    auth._active_sessions['progress-token'] = {'id': 'progress-user'}
    auth._active_sessions['other-token'] = {'id': 'progress-other'}
    patient_headers = {'Authorization': 'Bearer progress-token'}
    async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
        async def staff(ident):
            login = await client.post('/api/admin/login', json={'staff_id': f'P-{ident}', 'password': 'password123'})
            return {'Authorization': f"Bearer {login.json()['token']}"}
        headers = await staff(801)
        foreign_headers = await staff(802)
        url = '/api/admin/visits/persisted-visit'
        payload = {'patient_id': 'progress-user', 'acuity': 'yellow', 'complaint': 'Test complaint',
            'steps': stages(), 'logs': [], 'version': 0}
        assert (await client.get('/api/progress/visits')).status_code == 401
        assert (await client.post(url, headers=patient_headers, json=payload)).status_code == 401
        created = await client.post(url, headers=headers, json=payload)
        assert created.status_code == 200, created.text
        data = created.json()
        assert data['assigned_staff_id'] == 'P-801'
        assert data['hospital'] == 'Hospital A'
        assert data['queue_no'].startswith('Q-')
        assert (await client.post('/api/admin/visits/duplicate', headers=headers, json=payload)).status_code == 409
        assert (await client.post(url, headers=foreign_headers, json=payload)).status_code == 404
        assert (await client.get('/api/admin/visits', headers=foreign_headers)).json()['visits'] == []
        assert (await client.post(url, headers=headers, json=payload)).status_code == 409
        with get_session_factory()() as session:
            session.get(HospitalDirectory, 'H-801').hospital_name = 'Renamed Hospital A'
            session.commit()
        renamed = (await client.get('/api/admin/visits', headers=headers)).json()['visits']
        assert renamed[0]['hospital_id'] == 'H-801'
        assert renamed[0]['hospital'] == 'Renamed Hospital A'
        payload['version'] = data['version']
        payload['steps'][2]['status'] = 'in_progress'
        payload['steps'][2]['started_at'] = '2026-10-18T10:00:00Z'
        updated = await client.post(url, headers=headers, json=payload)
        assert updated.status_code == 200, updated.text
        with get_session_factory()() as session:
            assert session.get(PatientProgress, 'persisted-visit').version == 2
            assert session.get(PatientProgress, 'persisted-visit').hospital_id == 'H-801'
            assert session.get(PatientProgress, 'persisted-visit').assigned_staff_account_id == 801
            assert session.query(PatientTestTracking).filter_by(visit_id='persisted-visit').count() == 6
        listed = (await client.get('/api/progress/visits', headers=patient_headers)).json()['visits']
        assert listed[0]['steps'][2]['status'] == 'in_progress'
        assert 'password_hash' not in listed[0]['profile']
        assert (await client.get('/api/progress/visits', headers={'Authorization': 'Bearer other-token'})).json()['visits'] == []
        family_headers = {'Authorization': 'Bearer other-token'}
        assert (await client.get('/api/progress/family', headers=family_headers)).json()['visits'] == []
        assert (await client.post('/api/progress/visits/persisted-visit/sharing', headers=family_headers, json={'enabled': True})).status_code == 404
        assert (await client.post('/api/progress/visits/persisted-visit/sharing', headers=patient_headers, json={'enabled': True})).status_code == 200
        shared = (await client.get('/api/progress/family', headers=family_headers)).json()['visits']
        assert len(shared) == 1
        assert shared[0]['profile'] == {'name': 'progress-user'}
        assert shared[0]['diagnosis'] is None
        assert shared[0]['triage'] is None
        assert (await client.post('/api/progress/visits/persisted-visit/sharing', headers=patient_headers, json={'enabled': False})).status_code == 200
        assert (await client.get('/api/progress/family', headers=family_headers)).json()['visits'] == []
        diagnosis_url = url + '/diagnosis'
        diagnosis = {'diagnosis': 'Recorded diagnosis', 'treatment_notes': 'Care notes', 'medications': ['Medication A'], 'release': False}
        assert (await client.post(diagnosis_url, json=diagnosis, headers=headers)).status_code == 409
        payload['version'] = (await client.get('/api/admin/visits', headers=headers)).json()['visits'][0]['version']
        next(step for step in payload['steps'] if step['id'] == 'doctor')['status'] = 'done'
        assert (await client.post(url, headers=headers, json=payload)).status_code == 200
        assert (await client.post(diagnosis_url, json=diagnosis, headers=headers)).status_code == 200
        assert (await client.get('/api/progress/visits', headers=patient_headers)).json()['visits'][0]['diagnosis'] is None
        diagnosis['release'] = True
        assert (await client.post(diagnosis_url, json=diagnosis, headers=headers)).status_code == 200
        assert (await client.get('/api/progress/visits', headers=patient_headers)).json()['visits'][0]['diagnosis']['diagnosis'] == 'Recorded diagnosis'
        assert (await client.post(diagnosis_url, json=diagnosis, headers=foreign_headers)).status_code == 404
        # Completion survives a new session; a later visit is then permitted.
        payload['version'] = (await client.get('/api/admin/visits', headers=headers)).json()['visits'][0]['version']
        for step in payload['steps']:
            step['status'] = 'done'
        assert (await client.post(url, headers=headers, json=payload)).status_code == 200
        payload['version'] = 0
        payload['steps'] = stages()
        assert (await client.post('/api/admin/visits/next-visit', headers=headers, json=payload)).status_code == 200
        payload['version'] = (await client.get('/api/admin/visits', headers=headers)).json()['visits'][1]['version']
        assert (await client.post(url, headers=headers, json=payload)).status_code == 409
    auth._active_sessions.pop('progress-token')
    auth._active_sessions.pop('other-token')
