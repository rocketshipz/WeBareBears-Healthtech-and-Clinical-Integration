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
Triage reports are saved by the server: once a logged-in screening on `POST /api/triage/chat` is classified, it is stored in `patient_triage_reports`, keyed by the triage `session_id`, built from the rules engine result (clients cannot post a report or level).
If the screening was for someone else, the user can link it to that person's account with `PUT /api/triage/reports/{session_id}/subject` (`{"ic": "..."}`), so staff find it when that person checks in.
Existing databases: run `python migrate_triage_reports.py` once (renames `id` to `session_id`, adds `subject`, `subject_user_id`, `updated_at`; keeps existing rows).
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

Family progress uses `/api/progress/family` and requires an explicit patient-approved request. Emergency-contact phone matching and the legacy per-visit sharing flag no longer grant access.
In Profile, create an invitation and share it through WhatsApp. The recipient opens the link, logs in with their own TriageMY account and sends a request. The patient accepts/rejects in Profile, and can revoke access anytime. Approved family members use Progress > Family. Approval covers the patient's visits until revoked.
Each invitation permits exactly one submitted request and expires after 24 hours if unused. Opening links or WhatsApp previews does not consume them. Claims use an atomic database update, so simultaneous requests cannot reuse a link. Only token hashes are stored. Create separate invitations for separate family members.
Set `PUBLIC_BACKEND_URL` in `backend/.env` to the backend origin reachable from recipients' phones (for example `https://api.your-domain.com`, with any reverse proxy path prefix). If unset, links use the incoming API request origin; emulator/localhost addresses are only useful for local testing. The shared page is served by the backend and needs no separate tracking website.
The API creates `patient_family_invitations` and `patient_family_access` on first use. For deployment run `python migrate_family_access.py` beforehand; it preserves existing rows and enables PostgreSQL RLS. Routes are `POST /api/family/invitations`, `GET /api/family/invitations/{token}`, `POST/GET /api/family/requests`, and `PUT /api/family/requests/{viewer_id}`.
Family responses omit medical profiles and diagnoses. Public sharing links still require the separately configured tracking website.
PDFs currently persist as bounded base64 documents in `patient_test_tracking.result_documents` (maximum 5 MB per PDF, 8 MB per step payload), rather than a separate Supabase Storage bucket. These documents are staff-only.


## Signup email TAC (Gmail)

Signup sends a six-digit TAC from `triagemy.wbb@gmail.com` to the user's
email address. The code expires after five minutes, permits five failed
attempts, and can be resent after 60 seconds. Phone numbers are checked for
format; this flow verifies email ownership rather than phone ownership.

1. Sign into the sender's Google account and enable 2-Step Verification.
2. Create a Google App Password for TriageMY:
   https://support.google.com/accounts/answer/185833
3. Set the following in `backend/.env` (keep this file out of Git):

   ```dotenv
   TAC_DELIVERY=email
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   SMTP_USERNAME=triagemy.wbb@gmail.com
   SMTP_FROM_EMAIL=triagemy.wbb@gmail.com
   SMTP_PASSWORD=your_google_app_password
   ```

4. Restart the backend, then request a code from signup and check the
   recipient's inbox and spam folder. Port 587 with STARTTLS is also supported.

Use the App Password rather than the account's regular password. Without
SMTP credentials, signup reports that email delivery is not configured.
Automated tests use explicit `TAC_DELIVERY=test` with `ENVIRONMENT=test`;
this returns a test-only `debug_code` and sends no email. Production refuses
that mode. Live SMTP delivery does not return or log the TAC.
