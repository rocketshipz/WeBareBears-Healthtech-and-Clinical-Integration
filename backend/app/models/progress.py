from sqlalchemy import BigInteger, Boolean, Column, DateTime, Integer, JSON, String, Text
from app.core.database import Base


class PatientProgress(Base):
    __tablename__ = 'patient_progress'
    visit_id = Column(Text, primary_key=True)
    user_id = Column(Text, nullable=False)
    hospital_id = Column(Text)
    triage_zone = Column(Text)
    triage_level = Column(BigInteger)
    visit_status = Column(Text)
    arrival_time = Column(DateTime(timezone=True))
    consultation_started_at = Column(DateTime(timezone=True))
    discharged_at = Column(Text)
    updated_at = Column(DateTime(timezone=True))
    department = Column(Text)
    assigned_staff_id = Column(Text)
    assigned_staff_account_id = Column(BigInteger)
    queue_number = Column(Text)
    triage_report_id = Column(Text)
    chief_complaint = Column(Text)
    outcome = Column(Text)
    version = Column(Integer, default=1, nullable=False)
    audit_log = Column(JSON, default=list)
    family_sharing = Column(Boolean, default=False)
    share_token = Column(Text)


class PatientTestTracking(Base):
    __tablename__ = 'patient_test_tracking'
    visit_id = Column(Text, primary_key=True)
    test_id = Column(Text, primary_key=True)
    test_name = Column(Text)
    test_status = Column(Text)
    queue_number = Column(Text)
    ordered_at = Column(DateTime(timezone=True))
    queued_at = Column(DateTime(timezone=True))
    started_at = Column(Text)
    completed_at = Column(Text)
    result_status = Column(Text)
    result_summary = Column(Text)
    result_file_url = Column(Text)
    result_released_at = Column(Text)
    updated_by = Column(Text)
    updated_by_account_id = Column(BigInteger)
    updated_at = Column(DateTime(timezone=True))
    position = Column(Integer, default=0)
    is_test = Column(Boolean, default=True)
    result_documents = Column(JSON, default=list)


class PatientDiagnosisTreatment(Base):
    __tablename__ = 'patient_diagnosis_treatment'
    visit_id = Column(Text, primary_key=True)
    outcome_id = Column(Text)
    diagnosis = Column(Text)
    diagnosis_status = Column(Text)
    treatment_notes = Column(Text)
    medications = Column(JSON)
    follow_up_instructions = Column(Text)
    recorded_by = Column(Text)
    recorded_by_account_id = Column(BigInteger)
    recorded_at = Column(Text)
    released_to_patient_at = Column(Text)
