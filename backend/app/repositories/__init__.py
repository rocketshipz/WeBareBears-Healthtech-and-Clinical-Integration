"""Data repositories and database access module."""
from app.repositories.base import BaseRepository
from app.repositories.hospital_repository import HospitalRepository
from app.repositories.patient_repository import PatientRepository
from app.repositories.user_repository import UserRepository

__all__ = [
    "BaseRepository",
    "HospitalRepository",
    "PatientRepository",
    "UserRepository",
]
