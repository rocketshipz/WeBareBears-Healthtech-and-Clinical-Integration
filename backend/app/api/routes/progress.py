"""Authenticated staff writes and patient reads over the existing tracking tables."""
import secrets
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field
from sqlalchemy import func, text, or_

from app.api.routes.admin import require_staff
from app.api.routes.auth import get_auth_service
from app.core.database import get_db_session
from app.models.staff import StaffAccount
from app.models.user import User
from app.models.user_information import UserInformation
from app.models.triage_report import SavedReport
from app.models.progress import PatientProgress, PatientTestTracking, PatientDiagnosisTreatment
from app.models.hospital_directory import HospitalDirectory
from app.services.hospital_identity import staff_hospital

router = APIRouter(tags=['Patient progress'])


def now():
    return datetime.now(timezone.utc)


def iso(value):
    if value is None:
        return None
    if isinstance(value, str):
        return value
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.isoformat()


def normalized_status(value):
    value = (value or '').lower().replace(' ', '_')
    if value in {'done', 'completed', 'complete'}:
        return 'done'
    if value in {'started', 'in_progress', 'inprogress', 'current'}:
        return 'in_progress'
    return 'waiting'


class StepInput(BaseModel):
    id: str = Field(min_length=1, max_length=200)
    name: str = Field(min_length=1, max_length=200)
    is_test: bool = False
    status: Literal['waiting', 'in_progress', 'done'] = 'waiting'
    started_at: datetime | None = None
    completed_at: datetime | None = None
    note: str = Field(default='', max_length=10000)
    results: list[dict] = Field(default_factory=list, max_length=20)


class VisitWrite(BaseModel):
    patient_id: str | None = None
    ic: str | None = None
    triage_report_id: str | None = None
    acuity: Literal['red', 'yellow', 'green'] = 'green'
    complaint: str = Field(default='', max_length=2000)
    steps: list[StepInput] = Field(min_length=4, max_length=100)
    logs: list[dict] = Field(default_factory=list, max_length=2000)
    outcome: str | None = Field(default=None, max_length=200)
    version: int = Field(default=0, ge=0)
    family_sharing: bool = False
    share_token: str | None = Field(default=None, max_length=100)


class SharingInput(BaseModel):
    enabled: bool


class DiagnosisInput(BaseModel):
    diagnosis: str = Field(default='', max_length=10000)
    treatment_notes: str = Field(default='', max_length=10000)
    medications: list[str] = Field(default_factory=list, max_length=100)
    follow_up_instructions: str = Field(default='', max_length=10000)
    release: bool = False


def database(session=Depends(get_db_session)):
    if session is None:
        raise HTTPException(503, 'Database unavailable.')
    return session


def staff_account(identity=Depends(require_staff), session=Depends(database)):
    staff = session.get(StaffAccount, (identity['account_id'], identity['staff_id']))
    if staff is None or staff.is_active is not True:
        raise HTTPException(403, 'Active staff account and hospital assignment required.')
    staff_hospital(session, staff)
    return staff


def patient_identity(authorization: str = Header(default=''), auth=Depends(get_auth_service)):
    user = auth.get_user_by_token(authorization.removeprefix('Bearer '))
    if not user:
        raise HTTPException(401, 'Please log in to view your progress.')
    return user


def authorized_visit(session, visit_id, staff, lock=False):
    query = session.query(PatientProgress).filter_by(visit_id=visit_id, hospital_id=staff.hospital_id)
    if lock:
        query = query.with_for_update()
    visit = query.first()
    if visit is None:
        raise HTTPException(404, 'Visit not found in your hospital.')
    return visit


def serialize(session, visit, patient=False):
    hospital = session.get(HospitalDirectory, visit.hospital_id) if visit.hospital_id else None
    assigned_staff = session.query(StaffAccount).filter_by(id=visit.assigned_staff_account_id).first() if visit.assigned_staff_account_id else None
    user = session.get(User, visit.user_id)
    info = session.get(UserInformation, visit.user_id)
    profile = {c.name: getattr(info, c.name) for c in UserInformation.__table__.columns} if info else {}
    if user:
        profile.update(user.to_dict(), age=info.age if info else 0)
    steps = session.query(PatientTestTracking).filter_by(visit_id=visit.visit_id).order_by(
        PatientTestTracking.position, PatientTestTracking.test_id).all()
    report = session.get(SavedReport, visit.triage_report_id) if visit.triage_report_id else None
    diagnosis = session.get(PatientDiagnosisTreatment, visit.visit_id)
    diagnosis_data = None
    if diagnosis and (not patient or diagnosis.released_to_patient_at):
        diagnosis_data = {c.name: getattr(diagnosis, c.name) for c in PatientDiagnosisTreatment.__table__.columns}
    serialized_steps = [{'id': s.test_id, 'name': s.test_name, 'is_test': s.is_test,
                   'status': normalized_status(s.test_status), 'started_at': s.started_at,
                   'completed_at': s.completed_at, 'note': '' if patient else s.result_summary or '',
                   'results': [] if patient else s.result_documents or [],
                   'result_status': s.result_status} for s in steps]
    # Older rows may predate the app's core timeline stages.
    keys = {s['id'] for s in serialized_steps}
    complete = (visit.visit_status or '').lower() in {'completed', 'discharged'}
    defaults = [
        {'id': 'registration', 'name': 'Registration', 'status': 'done'},
        {'id': 'triage', 'name': 'Nurse triage', 'status': 'done' if visit.triage_zone or complete else 'waiting'},
        {'id': 'doctor', 'name': 'Doctor consultation', 'status': 'done' if complete else 'in_progress' if visit.consultation_started_at else 'waiting'},
        {'id': 'discharge', 'name': 'Discharge', 'status': 'done' if complete else 'waiting'},
    ]
    for stage in defaults:
        if stage['id'] not in keys:
            item = {**stage, 'is_test': False, 'note': '', 'results': [],
                    'started_at': iso(visit.consultation_started_at) if stage['id'] == 'doctor' else None,
                    'completed_at': visit.discharged_at if complete else None}
            if stage['id'] in {'registration', 'triage'}:
                serialized_steps.insert(0 if stage['id'] == 'registration' else 1, item)
            else:
                serialized_steps.append(item)
    return jsonable_encoder({
        'id': visit.visit_id, 'patient_id': visit.user_id, 'triage_report_id': visit.triage_report_id,
        'queue_no': visit.queue_number or visit.visit_id,
        'hospital_id': visit.hospital_id, 'hospital': hospital.hospital_name if hospital else 'Hospital not linked',
        'department': visit.department or 'Emergency Department', 'assigned_staff_id': assigned_staff.staff_id if assigned_staff else visit.assigned_staff_id,
        'acuity': visit.triage_zone or 'green', 'complaint': visit.chief_complaint or '',
        'arrived_at': iso(visit.arrival_time), 'completed_at': visit.discharged_at,
        'outcome': visit.outcome, 'version': visit.version, 'profile': profile,
        'family_sharing': visit.family_sharing is True, 'share_token': visit.share_token,
        'triage': report.report if report else None, 'diagnosis': diagnosis_data,
        'steps': serialized_steps,
        'logs': [] if patient else visit.audit_log or [],
    })


@router.get('/admin/visits')
def staff_visits(staff=Depends(staff_account), session=Depends(database)):
    visits = session.query(PatientProgress).filter_by(hospital_id=staff.hospital_id).order_by(
        PatientProgress.arrival_time.desc()).all()
    return {'visits': [serialize(session, v) for v in visits]}


@router.post('/admin/visits/{visit_id}')
def write_visit(visit_id: str, request: VisitWrite, staff=Depends(staff_account), session=Depends(database)):
    if len(visit_id) > 100:
        raise HTTPException(422, 'Invalid visit ID.')
    keys = [s.id for s in request.steps]
    if len(keys) != len(set(keys)) or not {'registration', 'triage', 'doctor', 'discharge'}.issubset(keys):
        raise HTTPException(422, 'Every visit needs unique registration, triage, doctor and discharge steps.')
    if any(s.is_test for s in request.steps if s.id in {'registration', 'triage', 'doctor', 'discharge'}):
        raise HTTPException(422, 'Core stages cannot be tests.')
    # Serialize simultaneous check-ins for the same patient, including across workers.
    patient_id = request.patient_id
    if not patient_id and request.ic:
        user = session.query(User).filter(func.replace(User.ic, '-', '') == request.ic.replace('-', '').strip()).first()
        patient_id = user.id if user else None
    user = session.get(User, patient_id) if patient_id else None
    if user is None:
        raise HTTPException(404, 'Registered patient not found.')
    if session.bind.dialect.name == 'postgresql':
        session.execute(text('SELECT pg_advisory_xact_lock(hashtext(:key))'), {'key': f'{staff.hospital_id}:{user.id}'})
    visit = session.query(PatientProgress).filter_by(visit_id=visit_id).with_for_update().first()
    if visit:
        if visit.hospital_id != staff.hospital_id:
            raise HTTPException(404, 'Visit not found.')
        if visit.user_id != user.id:
            raise HTTPException(409, 'A visit cannot be moved to another patient.')
        if request.version != visit.version:
            raise HTTPException(409, 'This visit was updated elsewhere. Refresh before editing again.')
    else:
        duplicate = session.query(PatientProgress).filter_by(user_id=user.id, hospital_id=staff.hospital_id).filter(
            or_(PatientProgress.visit_status.is_(None),
                func.lower(PatientProgress.visit_status).notin_(['completed', 'discharged', 'cancelled']))).first()
        if duplicate:
            raise HTTPException(409, 'This patient already has an active visit in this hospital.')
        visit = PatientProgress(visit_id=visit_id, user_id=user.id, hospital_id=staff.hospital_id,
            department=staff.department, assigned_staff_id=staff.staff_id, assigned_staff_account_id=staff.id, arrival_time=now(),
            queue_number='Q-' + secrets.token_hex(4).upper(), version=0, audit_log=[])
        session.add(visit)
    if request.triage_report_id:
        report = session.get(SavedReport, request.triage_report_id)
        # The report is about this patient: linked to them by IC, or their own screening not for someone else.
        if report is None or not (report.subject_user_id == user.id
                                  or (report.user_id == user.id and report.subject != 'other')):
            raise HTTPException(422, 'Triage report does not belong to this patient.')
        visit.triage_report_id = report.session_id
        visit.triage_level = report.report.get('level')
    if not all(step.status == 'done' for step in request.steps):
        other_active = session.query(PatientProgress).filter(
            PatientProgress.user_id == user.id, PatientProgress.hospital_id == staff.hospital_id,
            PatientProgress.visit_id != visit_id,
            or_(PatientProgress.visit_status.is_(None),
                func.lower(PatientProgress.visit_status).notin_(['completed', 'discharged', 'cancelled']))).first()
        if other_active:
            raise HTTPException(409, 'Another active visit exists. The completed visit cannot be reopened.')
    visit.triage_zone = request.acuity
    visit.family_sharing = request.family_sharing
    visit.share_token = request.share_token or visit.share_token or secrets.token_urlsafe(24)
    visit.chief_complaint = request.complaint
    visit.updated_at = now()
    visit.outcome = request.outcome
    visit.visit_status = 'completed' if all(s.status == 'done' for s in request.steps) else 'active'
    visit.discharged_at = iso(now()) if visit.visit_status == 'completed' else None
    doctor = next(s for s in request.steps if s.id == 'doctor')
    visit.consultation_started_at = doctor.started_at
    visit.version += 1
    existing_logs = {entry['id']: dict(entry) for entry in (visit.audit_log or [])}
    for entry in request.logs:
        ident = str(entry.get('id', ''))
        if not ident:
            continue
        if ident in existing_logs:
            existing_logs[ident]['undone'] = bool(entry.get('undone', False))
        else:
            existing_logs[ident] = {**{k: entry.get(k) for k in ['id', 'text', 'step_id', 'from', 'to', 'is_undo_record', 'undone']},
                'staff_id': staff.staff_id, 'staff_name': staff.name, 'time': iso(now())}
    visit.audit_log = list(existing_logs.values())
    records = {s.test_id: s for s in session.query(PatientTestTracking).filter_by(visit_id=visit_id).all()}
    for position, step in enumerate(request.steps):
        record = records.pop(step.id, None)
        if record is None:
            record = PatientTestTracking(visit_id=visit_id, test_id=step.id, ordered_at=now())
            session.add(record)
        record.test_name, record.test_status = step.name, step.status
        record.is_test, record.position = step.is_test, position
        record.started_at, record.completed_at = iso(step.started_at), iso(step.completed_at)
        record.result_summary, record.updated_by, record.updated_at = step.note, staff.staff_id, now()
        record.updated_by_account_id = staff.id
        # PDFs are persisted in the existing JSON extension, with a bounded payload.
        if len(str(step.results)) > 8_000_000:
            raise HTTPException(413, 'Test documents exceed the 8 MB limit.')
        record.result_documents = step.results
        record.result_status = 'available' if step.results else 'pending'
    for removed in records.values():
        session.delete(removed)
    session.commit()
    return serialize(session, visit)


@router.get('/progress/visits')
def patient_visits(user=Depends(patient_identity), session=Depends(database)):
    visits = session.query(PatientProgress).filter_by(user_id=user['id']).order_by(PatientProgress.arrival_time.desc()).all()
    return {'visits': [serialize(session, v, patient=True) for v in visits]}


@router.post('/progress/visits/{visit_id}/sharing')
def set_sharing(visit_id: str, request: SharingInput, user=Depends(patient_identity), session=Depends(database)):
    visit = session.query(PatientProgress).filter_by(visit_id=visit_id, user_id=user['id']).with_for_update().first()
    if visit is None:
        raise HTTPException(404, 'Visit not found.')
    visit.family_sharing = request.enabled
    visit.version += 1
    visit.updated_at = now()
    session.commit()
    return {'message': 'Sharing preference saved.'}


def family_view(session, visit):
    data = serialize(session, visit, patient=True)
    data['profile'] = {'name': data['profile'].get('name', 'Patient')}
    data['diagnosis'] = None
    data['triage'] = None
    data['share_token'] = None
    data['complaint'] = ''
    data['triage_report_id'] = None
    return data


@router.get('/progress/family')
def family_visits(user=Depends(patient_identity), session=Depends(database)):
    account = session.get(User, user['id'])
    def phone_key(value):
        digits = ''.join(c for c in (value or '') if c.isdigit())
        return '60' + digits[1:] if digits.startswith('0') else digits
    phone = phone_key(account.phone if account else '')
    if not phone:
        return {'visits': []}
    visits = session.query(PatientProgress).join(UserInformation, UserInformation.user_id == PatientProgress.user_id).filter(
        PatientProgress.family_sharing.is_(True), PatientProgress.user_id != user['id']).order_by(PatientProgress.arrival_time.desc()).all()
    matches = []
    for visit in visits:
        info = session.get(UserInformation, visit.user_id)
        contact = phone_key(info.emergency_contact_phone)
        if contact == phone:
            matches.append(family_view(session, visit))
    return {'visits': matches}


@router.get('/admin/visits/{visit_id}/diagnosis')
def get_diagnosis(visit_id: str, staff=Depends(staff_account), session=Depends(database)):
    visit = authorized_visit(session, visit_id, staff)
    return {'diagnosis': serialize(session, visit)['diagnosis']}


@router.post('/admin/visits/{visit_id}/diagnosis')
def save_diagnosis(visit_id: str, request: DiagnosisInput, staff=Depends(staff_account), session=Depends(database)):
    visit = authorized_visit(session, visit_id, staff, lock=True)
    doctor = session.get(PatientTestTracking, (visit_id, 'doctor'))
    if ((doctor is not None and normalized_status(doctor.test_status) != 'done')
            or (doctor is None and (visit.visit_status or '').lower() not in {'completed', 'discharged'})):
        raise HTTPException(409, 'Complete doctor consultation before recording diagnosis and treatment.')
    record = session.get(PatientDiagnosisTreatment, visit_id)
    if record is None:
        record = PatientDiagnosisTreatment(visit_id=visit_id, outcome_id=secrets.token_hex(16))
        session.add(record)
    for key in ['diagnosis', 'treatment_notes', 'medications', 'follow_up_instructions']:
        setattr(record, key, getattr(request, key))
    record.diagnosis_status = 'released' if request.release else 'draft'
    record.released_to_patient_at = iso(now()) if request.release else None
    record.recorded_at, record.recorded_by = iso(now()), staff.staff_id
    record.recorded_by_account_id = staff.id
    session.commit()
    return {'message': 'Diagnosis and treatment saved.'}
