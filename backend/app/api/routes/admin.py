"""Staff-only patient lookup and authenticated patient report storage."""
import secrets
import json
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel, Field
from sqlalchemy import Column, DateTime, ForeignKey, JSON, String, Text, func

from app.api.routes.auth import get_auth_service
from app.core.database import Base, get_db_session, get_engine
from app.models.user import User
from app.models.user_information import UserInformation
from app.models.staff import StaffAccount
from app.services.auth_service import _verify_password, _hash_password
from app.services.hospital_identity import staff_hospital

router = APIRouter(tags=["Patient registration"])
_staff_sessions = {}


class SavedReport(Base):
    __tablename__ = "patient_triage_reports"
    id = Column(String(64), primary_key=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False, index=True)
    report = Column(JSON, nullable=True)
    # Keep the original report fields populated for existing database constraints.
    report_id = Column(String(64), nullable=True)
    main_symptom = Column(Text, nullable=True)
    reported_severity = Column(Text, nullable=True)
    danger_signs = Column(Text, nullable=True)
    duration = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)


class StaffLogin(BaseModel):
    staff_id: str
    password: str


class PasswordChange(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class ReportInput(BaseModel):
    symptom: str = Field(max_length=2000)
    severity: str = Field(max_length=100)
    duration: str = Field(max_length=200)
    danger_signs: list[str] = Field(default_factory=list, max_length=50)
    level: int = Field(ge=1, le=5)
    submitted_at: datetime


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


@router.post("/triage/reports")
def save_report(request: ReportInput, authorization: str = Header(default=""),
                session=Depends(get_db_session), auth=Depends(get_auth_service)):
    user = auth.get_user_by_token(authorization.removeprefix("Bearer "))
    if not user:
        raise HTTPException(401, "Please log in to save your report.")
    if session is None:
        raise HTTPException(503, "Database unavailable.")
    SavedReport.__table__.create(get_engine(), checkfirst=True)
    report_id = secrets.token_hex(16)
    report = SavedReport(id=report_id, report_id=report_id, user_id=user["id"],
                         report=jsonable_encoder(request), main_symptom=request.symptom,
                         reported_severity=request.severity, danger_signs=json.dumps(request.danger_signs),
                         duration=request.duration)
    session.add(report)
    session.commit()
    return {"id": report.id}


@router.get("/admin/patients", dependencies=[Depends(require_staff)])
def lookup_patient(ic: str, session=Depends(get_db_session)):
    normalized = ic.replace("-", "").replace(" ", "")
    if len(normalized) != 12 or not normalized.isascii() or not normalized.isdigit():
        raise HTTPException(422, "Enter a valid 12-digit IC number.")
    if session is None:
        raise HTTPException(503, "Database unavailable.")
    user = session.query(User).filter(
        func.replace(func.replace(User.ic, "-", ""), " ", "") == normalized).first()
    if user is None:
        raise HTTPException(404, "No registered user found for this IC number.")
    info = session.get(UserInformation, user.id)
    if info is None:
        raise HTTPException(404, "This user's profile is missing.")
    profile = {c.name: getattr(info, c.name) for c in UserInformation.__table__.columns}
    profile.update(user.to_dict(), age=info.age)
    SavedReport.__table__.create(get_engine(), checkfirst=True)
    report = session.query(SavedReport).filter_by(user_id=user.id).order_by(
        SavedReport.created_at.desc(), SavedReport.id.desc()).first()
    return {"profile": jsonable_encoder(profile),
            "report_id": report.id if report else None,
            "triage": report.report if report else None}
