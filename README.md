# TriageMY (MedicTri)

First-level emergency triage and hospital routing for patients in Malaysia.

A patient describes what is wrong in a chat. The app works out how urgent it is using the **Malaysian Triage Scale (MTS) 2019**, then recommends nearby hospitals ranked by travel time and how busy each emergency department is. Hospital staff use the same app to check patients in and log each stage of the visit, and family members can follow the visit's progress.

> Hackathon / demo project. TriageMY does not diagnose and does not replace a clinician. In an emergency, call **999** (or **112** from a mobile phone).

---

## Features

**Patients**
- **Triage chat.** A guided screening that asks the MTS discriminator questions and ends with a level (1 Resuscitation to 5 Routine), advice for that level, and "call 999" when needed. It works in English and Malay.
- **Triage report.** Shows the result and main symptom, and exports a PDF.
- **Hospital routing.** Recommends hospitals from the patient's live GPS location, ranked by travel time (live Google traffic when configured) and how busy each ED is, weighted by the triage level.
- **Hospitals tab.** A map of nearby facilities with name and address search.
- **Progress tracking.** Follow the stages of an ED visit (check-in, tests, results).
- **Family access.** Invite a family member through a one-time link (for example by WhatsApp). The patient approves the request and can revoke it at any time.

**Hospital staff** (choose "Admin" on the start screen)
- Live emergency queue, check-in, one-tap stage logging, tests, diagnosis and treatment notes, and patient lookup by IC.

## How triage works

The triage level is **never decided by the LLM**. It is computed by a deterministic rules engine from a knowledge base built from the MTS 2019 PDF (Appendix 8):

```
patient message ─► LLM extracts facts as condition IDs ─► rules engine ─► level + advice
                   (and phrases the questions)            (mts_screening_kb.json)
```

- The engine keeps asking the next most urgent tier of questions until every more urgent condition has been ruled out. Only then is the level final.
- Hospital routing uses the level but can never change it.
- There are two chat modes (`TRIAGE_MODE`):
  - `hybrid`: code drives the flow, and the LLM only turns free text into answers and phrases each question. About 8k tokens per screening.
  - `agent` (default): an LLM tool-calling loop. About 50k tokens per screening.

The full contract (what the LLM may and may not do, how the KB maps to the PDF, the levels) is in [CLAUDE.md](CLAUDE.md) §4. The source PDF is [`malaysiantriagescalenewrevised2019.pdf`](malaysiantriagescalenewrevised2019.pdf).

## Architecture

```
┌──────────────────────────────────────────────┐
│ Flutter app (web / Android), "triagemy"      │
│ patient side + staff side                    │
└──────────────────────┬───────────────────────┘
                       │ REST/JSON under /api
┌──────────────────────▼───────────────────────┐
│ FastAPI backend                              │
│ routes → services → repositories             │
├──────────────┬───────────────┬───────────────┤
│ Triage       │ Routing       │ Auth, profile,│
│ rules engine │ Haversine +   │ progress,     │
│ + LLM (Azure │ Google Routes │ family access │
│ gpt-4.1-mini)│ + ED activity │               │
└──────────────┴───────┬───────┴───────────────┘
                       ▼
          PostgreSQL / Supabase (SQLite fallback)
```

| Layer | Stack |
|---|---|
| Frontend | Flutter 3.x / Dart 3.x, Material 3, `flutter_map`, `geolocator`, `pdf` + `printing`, `http` |
| Backend | Python 3.11+, FastAPI, Pydantic v2, SQLAlchemy, APScheduler |
| LLM | Azure OpenAI `gpt-4.1-mini` via `langchain-openai`, temperature 0 |
| Embeddings | Google Gemini `gemini-embedding-2` |
| Maps | Google Routes API (live traffic) and Places API (location checks), both optional |
| Database | Supabase PostgreSQL, falling back to local SQLite when no credentials are set |

## Repository layout

```
MedicTri/
├── backend/
│   ├── main.py                  # entry point: python main.py
│   ├── app/
│   │   ├── api/routes/          # auth, triage, hospitals, patients, progress, family, admin, health
│   │   ├── agents/              # MedicalTriageAgent + prompts (agent and hybrid modes)
│   │   ├── services/            # triage_rules_engine, triage_controller, routing, traffic, auth, ...
│   │   ├── repositories/        # data access
│   │   ├── models/ schemas/     # SQLAlchemy entities and Pydantic schemas
│   │   ├── core/                # config, database, llm, location_detector, scheduler
│   │   ├── tools/               # LangChain tools + mts_screening_kb.json (the triage rules)
│   │   └── templates/           # family invitation page
│   ├── scripts/                 # triage evaluation, hospital location check, wait-label update
│   ├── migrate_*.py             # one-off database migrations (see below)
│   ├── setup_staff_passwords.py
│   └── tests/
├── frontend/
│   └── lib/
│       ├── main.dart            # entry point → role selection (patient / admin)
│       ├── screens/             # login, sign-up, forgot password, role selection
│       ├── pages/               # home, triage chat, report, routing, hospitals, progress, profile
│       ├── admin/               # staff app (queue, check-in, patient detail, ...)
│       ├── services/            # API clients, GPS
│       └── widgets/
├── malaysiantriagescalenewrevised2019.pdf   # source for the triage KB
└── CLAUDE.md                    # rules and notes for developers and AI agents
```

## Getting started

### Prerequisites
- Python 3.11+
- Flutter SDK 3.x (Chrome for web)
- An Azure OpenAI deployment (needed for the triage chat)
- Optional: Supabase/PostgreSQL credentials, a Google Maps Platform key, and a Gmail App Password for sign-up codes

### 1. Backend

```powershell
cd backend
python -m venv venv
.\venv\Scripts\Activate.ps1          # macOS/Linux: source venv/bin/activate
pip install -r requirements.txt
copy .env.example .env               # then fill in your keys
python main.py
```

The API runs at `http://127.0.0.1:8000` under `/api`. Swagger UI is at `/docs`.

### 2. Frontend

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

The app calls `http://localhost:8000/api` on web and `http://10.0.2.2:8000/api` on the Android emulator (`lib/services/api_service.dart`). Browser geolocation needs `localhost` or HTTPS.

VS Code users can start both together with the **Full Stack (Backend + Frontend)** launch configuration.

## Configuration

All settings are in `backend/.env` (template: [`backend/.env.example`](backend/.env.example)). `backend/app/core/config.py` holds the defaults.

| Variable | Purpose |
|---|---|
| `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `OPENAI_MODEL_NAME` | Azure OpenAI endpoint and deployment for the triage LLM |
| `TRIAGE_MODE` | `agent` (default) or `hybrid` |
| `PLAIN_LANGUAGE` | Everyday wording for questions in hybrid mode. Keep it off until the wording has been clinically reviewed |
| `GEMINI_API_KEY` / `GOOGLE_API_KEY` | Gemini embeddings |
| `GOOGLE_MAPS_API_KEY` | Live traffic and location checks. Without it, routing uses a 35 km/h estimate |
| `DATABASE_URL` or `POSTGRES_DB_*` | Supabase/PostgreSQL. Without them, a local SQLite file is used |
| `PUBLIC_BACKEND_URL` | Public origin for family invitation links |
| `CORS_ORIGINS` | Browser origins allowed to call the API, comma-separated (default `*`). localhost on any port is always allowed |
| `TAC_DELIVERY`, `SMTP_*` | Email verification codes for sign-up (Gmail SMTP) |
| `EMAIL_PROVIDER`, `BREVO_API_KEY` | `smtp` (default) or `brevo`, which sends the same email through Brevo's HTTP API for hosts that block SMTP |

Never commit `.env`.

## Deployment

The frontend is a static site (for example on Vercel), and the backend runs separately over HTTPS. Local development needs neither of the settings below: without them the app uses `localhost` as before.

**Backend.** Host it as **one long-running instance**, for example on Render, Railway, Fly.io or Azure App Service. Serverless hosting does not work, because triage chat sessions are kept in memory and APScheduler runs background jobs.

On Render's free tier:
- Start command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`, root directory `backend`.
- The service sleeps after 15 minutes idle and loses chats in progress. Keep it awake with a free pinger (e.g. cron-job.org) on `/api/health` every 10 minutes.
- SMTP ports are blocked, so set `EMAIL_PROVIDER=brevo` and `BREVO_API_KEY` (see [backend/README.md](backend/README.md#signup-email-tac-gmail)).
- Use Supabase's Session pooler URL for `DATABASE_URL`, because Render cannot reach Supabase's IPv6-only direct host.

In the backend's environment, set:
- `CORS_ORIGINS=https://<your-app>.vercel.app`
- `PUBLIC_BACKEND_URL=https://<your-backend>`
- the usual keys from `.env.example`

**Frontend.** Vercel has no Flutter SDK, so build locally and upload the output:

```powershell
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://<your-backend>/api
vercel deploy build/web --prod
```

`web/vercel.json` is copied into the build. It sends every path to `index.html` and stops browsers caching the app shell, so users get new releases. Anything passed with `--dart-define` ends up readable in the browser bundle, so never put secrets there.

## Testing

```powershell
cd backend;  .\venv\Scripts\python.exe -m pytest -q
cd frontend; flutter analyze; flutter test
```

To evaluate triage end to end with a scripted patient (writes to `backend/scripts/sim_results/`, which is gitignored):

```powershell
cd backend
python scripts/scripted_triage_eval.py --oracle-only           # engine only, no LLM calls
python scripts/scripted_triage_eval.py --mode hybrid --only 1,2,3
```

## Database maintenance

Run these once, from `backend/`, against an existing database. Each one keeps existing rows.

| Script | What it does |
|---|---|
| `migrate_triage_reports.py` | Brings `patient_triage_reports` up to the current schema |
| `migrate_patient_progress.py`, then `migrate_patient_relationships.py` | Progress-tracking tables and their foreign keys |
| `migrate_family_access.py` | Family invitation and access tables, with RLS |
| `setup_staff_passwords.py` | Sets the default staff password and repairs uninitialised hashes |
| `scripts/verify_hospital_locations.py [--only-new]` | Checks hospital coordinates against Google Places |
| `scripts/update_wait_labels.py` | Runs the ED activity-label update once (it also runs on a schedule) |

More detail on staff accounts, progress tracking, family access and email setup is in [backend/README.md](backend/README.md).

## Known gaps

- `POST /api/triage/assess` is a placeholder that always returns `URGENT`. The app uses `/api/triage/chat`.
- The agent tools `route_to_recommended_hospital`, `query_hospital_facilities` and `search_medical_embeddings` are placeholders. Routing is done by `GET /api/hospitals/recommendations`.
- Triage chat sessions are kept in memory and are lost when the backend restarts. Classified screenings are saved as reports.
- `frontend/test/localization_test.dart` ("Profile switch saves language…") currently fails.

## Roadmap

1. Reduce token use in agent mode by trimming old turns from the history sent to the LLM.
2. Shorten paediatric screenings by adding a first-look checklist for children.
3. Turn the remaining multi-part yes/no questions into option lists.
4. Review the Azure content-filter settings so self-harm messages reach the screening.
5. Add the chat transcript to the PDF report.
