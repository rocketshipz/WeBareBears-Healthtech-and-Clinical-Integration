from fastapi import HTTPException
from sqlalchemy import func, or_
from app.models.hospital_directory import HospitalDirectory


def staff_hospital(session, staff):
    if staff.hospital_id:
        hospital = session.get(HospitalDirectory, staff.hospital_id)
        if hospital:
            return hospital
    label = (staff.hospital or '').strip().lower()
    matches = session.query(HospitalDirectory).filter(or_(
        func.lower(func.trim(HospitalDirectory.hospital_name)) == label,
        func.lower(func.trim(HospitalDirectory.hospital_code)) == label,
        func.lower(func.trim(HospitalDirectory.hospital_id)) == label)).limit(2).all() if label else []
    if len(matches) != 1:
        raise HTTPException(403, 'Your staff account needs a valid hospital_id linked to hospital_data.')
    staff.hospital_id = matches[0].hospital_id
    return matches[0]
