"""Single-use invitations request access; only the patient can grant it."""
import hashlib
import json
import secrets
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy import update

from app.api.routes.progress import database, patient_identity
from app.core.config import get_settings
from app.models.family_access import FamilyAccess, FamilyInvitation, ensure_family_tables
from app.models.user import User

router = APIRouter(prefix='/family', tags=['Family access'])


def family_database(session=Depends(database)):
    ensure_family_tables(session.get_bind())
    return session


def digest(token):
    return hashlib.sha256(token.encode()).hexdigest()


class RequestInput(BaseModel):
    token: str = Field(min_length=40, max_length=100)


class DecisionInput(BaseModel):
    status: Literal['approved', 'rejected', 'revoked']


@router.post('/invitations')
def create_invitation(request: Request, user=Depends(patient_identity), session=Depends(family_database)):
    token = secrets.token_urlsafe(32)
    expiry = datetime.now(timezone.utc) + timedelta(hours=24)
    session.add(FamilyInvitation(token_hash=digest(token), patient_id=user['id'], expires_at=expiry))
    session.commit()
    public_url = get_settings().PUBLIC_BACKEND_URL.strip().rstrip('/')
    # Preserve any reverse proxy path prefix in the named route URL.
    link = str(request.url_for('family_invitation_page', token=token))
    if public_url:
        link = f'{public_url}/api/family/invitations/{token}'
    return {'invitation_url': link, 'expires_at': expiry}


def available_invitation(session, token):
    invite = session.get(FamilyInvitation, digest(token))
    if invite is None:
        raise HTTPException(404, 'Invitation not found. Ask the patient for a new link.')
    expiry = invite.expires_at
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    if invite.consumed_at is not None or expiry <= datetime.now(timezone.utc):
        raise HTTPException(410, 'This invitation has already been used or has expired. Ask the patient for a new link.')
    return invite


@router.get('/invitations/{token}', response_class=HTMLResponse, name='family_invitation_page')
def invitation_page(token: str, session=Depends(family_database)):
    # Reading/WhatsApp previews never consume a link or disclose the patient's identity.
    headers = {'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer',
               'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY',
               'Content-Security-Policy': "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; form-action 'none'; frame-ancestors 'none'; base-uri 'none'"}
    try:
        available_invitation(session, token)
    except HTTPException as exc:
        return HTMLResponse('<!doctype html><html><meta name="viewport" content="width=device-width, initial-scale=1">'
                            '<title>TriageMY invitation</title><body><h1>Invitation unavailable</h1>'
                            '<p>This link has been used or has expired. Ask the patient for a new link.</p></body></html>',
                            status_code=exc.status_code, headers=headers)
    template = (Path(__file__).parents[2] / 'templates' / 'family_invitation.html').read_text(encoding='utf-8')
    return HTMLResponse(template.replace('__INVITATION_TOKEN__', json.dumps(token)), headers=headers)


@router.post('/requests')
def request_access(body: RequestInput, user=Depends(patient_identity), session=Depends(family_database)):
    invite = available_invitation(session, body.token)
    if invite.patient_id == user['id']:
        raise HTTPException(422, 'You cannot request access to your own progress.')
    patient_id = invite.patient_id
    # One transaction claims the invitation and records the request. Concurrent
    # attempts (even by different accounts) cannot consume the same link twice.
    claimed = session.execute(update(FamilyInvitation).where(
        FamilyInvitation.token_hash == digest(body.token),
        FamilyInvitation.consumed_at.is_(None),
        FamilyInvitation.expires_at > datetime.now(timezone.utc),
    ).values(consumed_at=datetime.now(timezone.utc), consumed_by=user['id']),
        execution_options={'synchronize_session': False})
    if claimed.rowcount != 1:
        session.rollback()
        raise HTTPException(410, 'This invitation has already been used or has expired. Ask the patient for a new link.')
    # Serialize requests for this viewer across different invitation links.
    session.query(User).filter_by(id=user['id']).with_for_update().first()
    row = session.query(FamilyAccess).filter_by(patient_id=patient_id, viewer_id=user['id']).with_for_update().first()
    if row is None:
        row = FamilyAccess(patient_id=patient_id, viewer_id=user['id'], status='pending')
        session.add(row)
    elif row.status != 'approved':
        row.status = 'pending'
    row.updated_at = datetime.now(timezone.utc)
    session.commit()
    return {'status': row.status}


@router.get('/requests')
def list_requests(user=Depends(patient_identity), session=Depends(family_database)):
    def entry(row, other_id):
        person = session.get(User, other_id)
        return {'patient_id': row.patient_id, 'viewer_id': row.viewer_id,
                'name': person.name if person else 'User', 'status': row.status,
                'updated_at': row.updated_at}
    incoming = session.query(FamilyAccess).filter_by(patient_id=user['id']).all()
    outgoing = session.query(FamilyAccess).filter_by(viewer_id=user['id']).all()
    return {'incoming': [entry(r, r.viewer_id) for r in incoming],
            'outgoing': [entry(r, r.patient_id) for r in outgoing]}


@router.put('/requests/{viewer_id}')
def decide(viewer_id: str, body: DecisionInput, user=Depends(patient_identity), session=Depends(family_database)):
    row = session.query(FamilyAccess).filter_by(patient_id=user['id'], viewer_id=viewer_id).with_for_update().first()
    if row is None:
        raise HTTPException(404, 'Request not found.')
    if body.status in ('approved', 'rejected') and row.status != 'pending':
        raise HTTPException(409, 'This request is no longer pending. Refresh the list.')
    row.status = body.status
    row.updated_at = datetime.now(timezone.utc)
    session.commit()
    return {'status': row.status}
