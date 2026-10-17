import pytest
from pydantic import ValidationError
from app.schemas.auth import RegisterRequest


@pytest.mark.parametrize("sex", ["male", "female", "intersex"])
def test_required_registration_details(sex):
    request = RegisterRequest(ic="990101145555", phone="0123456789",
        email="test@example.com", nationality="Malaysia", password="Password123!", name="  Test User  ", sex_at_birth=sex)
    assert request.name == "Test User"
    assert request.sex_at_birth == sex


@pytest.mark.parametrize("details", [{}, {"name": "Test"}, {"sex_at_birth": "male"},
    {"name": "   ", "sex_at_birth": "male"}, {"name": "Test", "sex_at_birth": "other"}])
def test_missing_or_invalid_registration_details(details):
    with pytest.raises(ValidationError):
        RegisterRequest(ic="990101145555", phone="0123456789", email="test@example.com",
            nationality="Malaysia", password="Password123!", **details)


def test_foreign_registration_accepts_passport_and_birth_date():
    request = RegisterRequest(ic="A12345678", phone="0123456789", email="foreign@example.com",
        password="Password123!", name="Test User", sex_at_birth="female",
        nationality="Indonesia", date_of_birth="1995-06-12")
    assert request.nationality == "Indonesia"
    assert request.date_of_birth.isoformat() == "1995-06-12"


def test_foreign_registration_requires_birth_date():
    with pytest.raises(ValidationError):
        RegisterRequest(ic="A12345678", phone="0123456789", email="foreign@example.com",
            password="Password123!", name="Test User", sex_at_birth="female", nationality="Indonesia")
