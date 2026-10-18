# MedicTri - Medical Emergency Triage & Hospital Routing Backend

Backend API and Agentic AI system for the MedicTri mobile emergency triage application.

## High-Level Architecture

```
Flutter Mobile App
       ↓
  Backend API (FastAPI)
       ↓
 Medical Triage Agent
 ├── Triage Tool (Deterministic Rules)
 ├── Patient History Tool (Patient Profile & Health Records)
 ├── Hospital Data Tool (Facility Capabilities & Capacity)
 ├── Hospital Routing Tool (Geo-Routing & Recommendation)
 └── Embedding Tool (Semantic Medical Knowledge Search)
       ↓
 Database / Data Sources (PostgreSQL / Supabase & Data Files)
```

## AI Model Structure

- **Main Agent Model (Azure OpenAI)**: Powers reasoning, multi-turn clinical triage dialogs, and tool calling via `ChatOpenAI` against an Azure OpenAI v1 endpoint (default deployment: `gpt-4.1-mini`).
- **Embedding Model (Google Gemini)**: Powers semantic vector search over medical protocols, MTS guidelines, and symptom embeddings via `GoogleGenerativeAIEmbeddings` (default: `gemini-embedding-2`).

## Directory Structure

```
backend/
├── app/
│   ├── api/
│   │   └── routes/             # FastAPI route handlers (health, triage)
│   ├── agents/                 # Medical Triage Agent & system prompts
│   ├── tools/                  # 5 LangChain tools for triage & routing
│   ├── services/               # Core business logic services
│   ├── models/                 # Domain entities (patient, hospital, triage)
│   ├── schemas/                # Pydantic validation models
│   ├── repositories/           # Data access layers (PostgreSQL/Supabase)
│   ├── core/                   # Configuration, DB session, & LLM client
│   └── main.py                 # FastAPI application definition
│
├── data/
│   ├── patients/               # Placeholder for patient health datasets
│   ├── triage/                 # Placeholder for clinical triage rules
│   └── hospitals/              # Placeholder for hospital facility datasets
│
├── tests/                      # Automated test suite
├── .env.example                # Example environment variables
├── requirements.txt            # Python dependencies
└── main.py                     # Convenience entry point
```

## Setup & Running

### 1. Prerequisites
- Python 3.11+
- Virtual environment (`venv`)

### 2. Install Dependencies
```powershell
# From the backend directory
pip install -r requirements.txt
```

### 3. Environment Variables
Copy `.env.example` to `.env` and fill in necessary API keys:
```powershell
cp .env.example .env
```

### 4. Start the Application
Run using the entry point:
```powershell
python main.py
```
Or with Uvicorn directly:
```powershell
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

### 5. Interactive API Documentation
Open your browser to:
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`


## Hospital registration
Staff login reads the existing `staff_login` table and issues an eight-hour in-memory session.
Use a unique `staff_id`, set `is_active=true`, and populate name, hospital, department and role.
`password_hash` must use the application's PBKDF2 format (`salt_hex:key_hex`), never plaintext.
To generate a hash locally, run from `backend`:
```powershell
.\venv\Scripts\python.exe -c "from getpass import getpass; from app.services.auth_service import _hash_password; print(_hash_password(getpass('Staff password: ')))"
```
Store the resulting hash in `staff_login.password_hash`. The old `ADMIN_STAFF_ID` / `ADMIN_STAFF_PASSWORD` environment variables are no longer used.
Patient lookup is staff-only: `GET /api/admin/patients?ic=...`.
Patients completing triage now save reports through `POST /api/triage/reports` using their own login session.
Older reports generated before this change are not stored; complete triage again to make one available.
The admin queue and progress now use the authenticated API and the three existing Supabase patient tables. They persist across app restarts.

Staff starter passwords default to `triagemy123` (PBKDF2 hashed). Run `python setup_staff_passwords.py` once to configure the database default and repair uninitialized passwords. Existing valid hashes are preserved. Staff can change their password from Account > Change password by entering their current password and confirming a new one.

## Patient progress database connection

Use the existing `DATABASE_URL` configuration. No Supabase secret or service key is sent to Flutter.
Run `python migrate_patient_progress.py` once against the configured database, then restart the API.
Then run `python migrate_patient_relationships.py` to link the existing hospital, patient, visit and staff keys.
The migration preserves existing rows and enables RLS without granting new direct client access.

- `patient_progress` holds check-ins, hospital/department assignment, queue numbers, visit state, audit history, sharing consent and an optimistic version counter.
  `hospital_id` references `hospital_data.hospital_id`; staff accounts use the same canonical key. Hospital names remain display values. `assigned_staff_account_id` references `staff_login.id`, while the existing `assigned_staff_id` remains the display/login code.
- `patient_test_tracking` holds the ordered timeline (standard stages and custom tests distinguished by `is_test`). Its primary key is `(visit_id, test_id)` so one visit can have many tests.
- `patient_diagnosis_treatment` holds clinical notes, medications and follow-up, hidden from patients until staff explicitly release them.

Admin reads/writes use `/api/admin/visits`; patient reads use `/api/progress/visits`, scoped to the logged-in user.
Both frontends poll every five seconds. Concurrent stale writes return 409 instead of overwriting newer changes.
Check-in waits for database confirmation; duplicate active visits per patient/hospital are rejected.
Without a saved triage report, staff must select a nurse-assessed zone before check-in.

Family progress uses `/api/progress/family` and requires patient opt-in plus a matching registered emergency-contact phone.
Family responses omit medical profiles and diagnoses. Public sharing links still require the separately configured tracking website.
PDFs currently persist as bounded base64 documents in `patient_test_tracking.result_documents` (maximum 5 MB per PDF, 8 MB per step payload), rather than a separate Supabase Storage bucket. These documents are staff-only.
