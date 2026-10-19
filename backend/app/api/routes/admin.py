"""Staff login and staff-only patient lookup."""
import secrets
import json
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field

from app.core.database import get_db_session
from app.models.user_information import UserInformation
from app.models.staff import StaffAccount
from app.repositories.triage_report_repository import TriageReportRepository
from app.services.auth_service import _verify_password, _hash_password
from app.services.hospital_identity import staff_hospital
from app.services.triage_report_service import find_user_by_ic, normalize_ic

router = APIRouter(tags=["Patient registration"])
_staff_sessions = {}


class StaffLogin(BaseModel):
    staff_id: str
    password: str


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


def require_staff(authorization: str = Header(default="")):
    token = authorization.removeprefix("Bearer ")
    identity = _staff_sessions.get(token)
    if identity is None or identity['expires_at'] < datetime.now(timezone.utc):
        raise HTTPException(401, "Please log in with a valid staff account.")
    return identity


@router.post("/admin/login")
def staff_login(request: StaffLogin, session=Depends(get_db_session)):
    if session is None:
        raise HTTPException(503, "Database unavailable.")
    accounts = session.query(StaffAccount).filter(
        StaffAccount.staff_id == request.staff_id.strip()).limit(2).all()
    # A composite database key may allow duplicate staff IDs: fail closed.
    account = accounts[0] if len(accounts) == 1 else None
    if (account is None or account.is_active is not True
            or not _verify_password(request.password, account.password_hash or "")):
        raise HTTPException(401, "Invalid staff ID or password.")
    account.last_login_at = datetime.now(timezone.utc).replace(tzinfo=None)
    hospital = None
    if account.hospital_id or account.hospital:
        try:
            hospital = staff_hospital(session, account)
        except HTTPException:
            pass  # Login is allowed; progress endpoints require a linked hospital.
    session.commit()
    token = secrets.token_urlsafe(32)
    _staff_sessions[token] = {
        'account_id': account.id, 'staff_id': account.staff_id,
        'expires_at': datetime.now(timezone.utc) + timedelta(hours=8),
    }
    return {"token": token, "staff": {
        "id": account.id, "staff_id": account.staff_id, "name": account.name,
        "hospital": hospital.hospital_name if hospital else account.hospital,
        "hospital_id": account.hospital_id, "department": account.department, "role": account.role,
    }}


@router.post('/admin/change-password')
def change_password(request: PasswordChange, identity=Depends(require_staff),
                    session=Depends(get_db_session)):
    if session is None:
        raise HTTPException(503, 'Database unavailable.')
    account = session.get(StaffAccount, (identity['account_id'], identity['staff_id']))
    if account is None or account.is_active is not True:
        raise HTTPException(401, 'Staff account is unavailable.')
    if not _verify_password(request.current_password, account.password_hash or ''):
        raise HTTPException(400, 'Current password is incorrect.')
    if request.new_password == request.current_password:
        raise HTTPException(400, 'Choose a different new password.')
    account.password_hash = _hash_password(request.new_password)
    account.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    session.commit()
    for token, existing in list(_staff_sessions.items()):
        if existing['account_id'] == account.id and existing['staff_id'] == account.staff_id and existing is not identity:
            del _staff_sessions[token]
    return {'message': 'Password changed successfully.'}


@router.get("/admin/patients", dependencies=[Depends(require_staff)])
def lookup_patient(ic: str, session=Depends(get_db_session)):
    normalized = normalize_ic(ic)
    if normalized is None:
        raise HTTPException(422, "Enter a valid 12-digit IC number.")
    if session is None:
        raise HTTPException(503, "Database unavailable.")
    user = find_user_by_ic(session, normalized)
    if user is None:
        raise HTTPException(404, "No registered user found for this IC number.")
    info = session.get(UserInformation, user.id)
    if info is None:
        raise HTTPException(404, "This user's profile is missing.")
    profile = {c.name: getattr(info, c.name) for c in UserInformation.__table__.columns}
    profile.update(user.to_dict(), age=info.age)
    report = TriageReportRepository(session).latest_for_patient(user.id)
    return {"profile": jsonable_encoder(profile),
            "report_id": report.session_id if report else None,
            "triage": report.report if report else None}
