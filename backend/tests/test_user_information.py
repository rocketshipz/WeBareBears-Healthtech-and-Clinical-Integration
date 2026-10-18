from datetime import date

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.user import User
from app.models.user_information import UserInformation
from app.repositories.patient_repository import PatientRepository
from app.services.patient_service import PatientService


def _session():
    engine = create_engine("sqlite://")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add(User(id="u1", ic="900101015555", phone="0123456789", email="a@b.com", password_hash="x"))
    session.commit()
    return session


def test_age_derived_from_dob():
    today = date.today()
    info = UserInformation(user_id="u1", date_of_birth=date(today.year - 12, today.month, today.day))
    assert info.age == 12
    # Birthday tomorrow -> still 11 (paediatric boundary)
    tomorrow_dob = date(today.year - 12, today.month, today.day)
    if today.day < 28:
        tomorrow_dob = tomorrow_dob.replace(day=today.day + 1)
        assert UserInformation(user_id="u1", date_of_birth=tomorrow_dob).age == 11


def test_upsert_and_agent_context_respects_consent():
    session = _session()
    repo = PatientRepository(session)
    repo.upsert(
        "u1",
        date_of_birth=date(1990, 1, 1),
        sex_at_birth="female",
        chronic_conditions=[{"name": "Asthma"}],
        allergies=[{"substance": "Penicillin"}],
    )
    service = PatientService(repo)
    assert service.get_agent_context("u1") != {}  # no consent yet

    ctx = service.get_agent_context("u1")
    assert ctx["sex_at_birth"] == "female"
    assert ctx["chronic_conditions"] == ["Asthma"]
    assert ctx["allergies"] == ["Penicillin"]
    assert "current_medications" not in ctx
    assert service.get_patient_profile("u1").age == ctx["age"]
