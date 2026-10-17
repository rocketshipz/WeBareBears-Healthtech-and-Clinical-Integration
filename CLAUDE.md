# MedicTri: Agent & Developer Guidelines

> **Target Audience**: Future AI Agents and Developers working on the **MedicTri** codebase.
> **Last Updated**: October 2026
> **System Purpose**: First-level emergency medical triage assessment and intelligent hospital routing for patients in Malaysia.
> **Project Context**: Team hackathon project, demo-grade. Prioritize a working end-to-end demo over production hardening, but never compromise on the triage rules contract (§4).

---

## 1. System Overview & Core Philosophy

MedicTri (**TriageMY**) is a dual-tier emergency medical assistance application:
1. **Clinical Emergency Triage**: A fully agentic LLM (`MedicalTriageAgent`) talks to the patient, pulls their past history, and gathers inputs. The **triage level itself is decided strictly by the deterministic MTS-derived knowledge base** (`backend/app/tools/mts_screening_kb.json`), not by the LLM. See §4.
2. **Proximity & Capability Routing**: Matches patients to healthcare facilities based on their **live GPS location**, facility emergency capabilities (24/7 ER, ICU capacity), required medical specialties, and travel time.

### Triage levels (canonical, from the KB)
| Level | KB name | UI zone (presentation only) |
|---|---|---|
| 1 | Resuscitation | Red |
| 2 | Emergency | Red |
| 3 | Urgent | Yellow |
| 4 | Early Care | Green |
| 5 | Routine | Green |

The **level number** is the source of truth. Colour zones are a UI convenience only. Never do logic on zones, and never map to other scales (CTAS/ESI). The KB's `decision_policy.no_cross_scale_mapping` forbids it.

---

## 2. Architecture & Tech Stack

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Web / Mobile UI              │
│       (lib/pages, lib/screens, lib/services)           │
└───────────────────────────┬────────────────────────────┘
                            │ REST / JSON (HTTP), base path /api
                            ▼
┌────────────────────────────────────────────────────────┐
│                   FastAPI Backend API                  │
│               (app/api/routes, app/services)           │
└─────────────┬────────────────────────────┬─────────────┘
              │                            │
              ▼                            ▼
┌───────────────────────────┐  ┌─────────────────────────┐
│ MedicalTriageAgent (Azure) │  │   Core Utilities        │
│  orchestrates, never      │  │   - Location Detector   │
│  decides the level        │  │     (Haversine math)    │
│ ├── evaluate_triage_rules │◄─┤   - Database (Supabase) │
│ │    (mts_screening_kb)   │  │   - Auth & Security     │
│ ├── get_patient_history   │  └─────────────────────────┘
│ ├── query_hospital_facil. │
│ ├── route_to_recommended  │
│ └── search_medical_embed. │
└───────────────────────────┘
```

### Stack Components
- **Frontend**: Flutter 3.x (Dart 3.x), app name `triagemy`
  - UI: Material 3, custom gradient design system in `lib/theme.dart`.
  - Mapping: `flutter_map` (v8) + `latlong2`. Geolocation: `geolocator` (v14).
  - Documents: `pdf` + `printing` for triage report exports. Networking: `http`.
- **Backend**: Python 3.11+ / FastAPI
  - Validation: `pydantic` v2, `pydantic-settings`.
  - Database: PostgreSQL / **Supabase** via SQLAlchemy repositories. Falls back to `sqlite:///./local_placeholder.db` if no DB creds are set.
  - LLM: `langchain-openai` (`ChatOpenAI`) against an **Azure OpenAI** v1 endpoint, deployment **`gpt-4.1-mini`**, temperature 0.0 (`OPENAI_*` settings; the Foundry project URL is converted to `/openai/v1/` in `config.py`).
  - Embeddings: Google Gemini **`gemini-embedding-2`** (`GEMINI_API_KEY` or `GOOGLE_API_KEY`).
  - `backend/app/core/config.py` is the source of truth for model names and settings. If this file disagrees with it, config.py wins.
  - Tests: `pytest`, `pytest-asyncio`.

---

## 3. Directory Map

```
MedicTri/
├── CLAUDE.md                            # This file
├── README.md                            # High-level project summary & setup
├── hospital_data.xlsx                   # Seed data only (untracked); Supabase is canonical
├── backend/
│   ├── main.py                          # Uvicorn entry point (`python main.py`)
│   ├── requirements.txt
│   ├── .env.example                     # Copy to backend/.env
│   ├── app/
│   │   ├── main.py                      # FastAPI app, CORS, routers mounted under /api
│   │   ├── api/routes/                  # auth.py, triage.py (/assess, /chat), health.py
│   │   ├── core/                        # config.py, database.py, llm.py, location_detector.py
│   │   ├── models/ schemas/             # Domain entities / Pydantic schemas
│   │   ├── repositories/                # Data access (hospital, patient, user)
│   │   ├── services/                    # triage_rules_engine (deterministic MTS engine), triage_service, routing_service, hospital_service, auth_service, patient_service
│   │   ├── agents/                      # triage_agent.py (MedicalTriageAgent), prompts.py
│   │   └── tools/                       # 5 LangChain tools + mts_screening_kb.json + triage_question_training.json
│   └── tests/
└── frontend/
    └── lib/
        ├── main.dart, theme.dart
        ├── screens/                     # login_screen, signup_page, forgot_password
        ├── pages/
        │   ├── home_page.dart           # Dashboard & triage history
        │   ├── triage_engine.dart       # Questionnaire flow (+ chat follow-up, planned)
        │   ├── triage_report.dart       # Results & PDF export
        │   ├── hospital_routing.dart    # Recommended hospitals & navigation
        │   ├── hospital_homepage.dart   # Map of nearby facilities
        │   └── profile_page.dart, notifications_page.dart
        └── services/
            ├── api_service.dart         # Base URL (web: localhost:8000/api, Android emu: 10.0.2.2)
            ├── auth_service.dart        # /auth/login, send-code, verify-code, register
            └── location_service.dart    # GPS, distance & travel time
```

---

## 4. Triage Rules Contract (Non-Negotiable)

`backend/app/tools/mts_screening_kb.json` (schema v3.0.0) is the **only** authority for triage structure and level. It contains its own `agent_contract`, `decision_policy`, `patient_context` and `safety_and_escalation` sections. Read them before touching triage code.

**Source of truth for the KB is the PDF** `malaysiantriagescalenewrevised2019.pdf` (repo root; Appendix 8, Malaysian Triage Scale 2019). Every rule's `source_basis` cites its PDF page. How to read the PDF tables, which the KB follows:
- Critical First Look / Rapid Assessment columns: Level 1 / 2 / 3, then "Secondary Triage" (a pass-through column with no level; kept in `primary_triage_pass_criteria`, never as conditions).
- **Adult** complaints list columns are **Level 2 / 3 / 4 / 5**. **Paediatric** (under 12) complaints list columns are **Level 1 / 2 / 3 / 4**. Mixing these up shifts rules by one level.
- Each rule and question has `population`: `all` | `adult` | `paediatric`. The engine skips the other population (adult ≥ 12 years). With unknown age only `all` items apply, so age is asked first.
- **Only things a person can answer by questionnaire or verbally are screened** (the app's only input for now). Measurements (SpO2, BP, ECG, CRT, glucose, temperature), clinician-judged impressions ("septic appearance", "airway unprotected", "appears unwell", suspected vascular injury…) and staff decisions ("need for restraint", "referred cases") are not screened. They are kept per rule in `source_conditions_excluded_from_screening` and in `excluded_from_active_screening`. Do not add such conditions back.
- Judgement calls where the PDF is ambiguous or contradicts itself are recorded in `source_alignment_notes`. Read them before changing rules.
- 27 complaint categories are covered (all PDF complaint rows except "Referrals", which is all clinician diagnoses). Stroke (< 3 H / > 3 H) is screened under Altered Mental State / Seizures / Neurological, not under Lethargy & Weakness.
- **Advice**: every result carries level-native advice (`level_advice`, from the PDF target times) and the engine adds extra advice for specific conditions (`emergency_advice` in the KB). Level 1 always means "call 999". An ongoing seizure at Level 2 also gets "call 999" in addition to the Level 2 advice. For Level 1-2 the engine returns `interim_advice` as soon as the level is known to be at least that urgent, because those people mostly go straight to a hospital. `call_999` is true if either applies.
- **Adult chest pain** (product decision): the agent must establish whether ongoing pain is high (severe), moderate or mild. High ongoing = Level 2, moderate = Level 3, mild persisting = Level 4. See `source_alignment_notes`.

**The LLM agent MAY:**
- Converse with the patient, ask the follow-up/discriminator questions the KB requires, and extract structured inputs.
- Pull past medical history (`get_patient_history`) and pass it in as context. Use a history item as a modifier **only where the applicable KB rule explicitly supports it** (`patient_context.rule`).
- Explain and phrase the KB's result to the patient.

**The LLM agent MUST NOT:**
- Assign, override, adjust, or "sanity-check" a triage level itself.
- Invent, infer, interpolate, or substitute rules. It must not diagnose.
- Let hospital routing influence the triage level (`no_hospital_routing_influence_on_triage`).

**How the level is computed** (`backend/app/services/triage_rules_engine.py`):
- Each KB rule condition gets a stable ID `<rule_id>.C<n>` (e.g. `RULE_CP_L2_01.C3`). The LLM reports facts as present/absent condition IDs. The engine computes the level. The LLM never sends a level.
- A rule matches when **any** of its conditions is present. **Higher urgency wins.**
- A level is final only after every condition at a **more urgent** level in the screened categories has been ruled out. Until then the engine returns `insufficient_information`, with only the **next most-urgent tier** of conditions and KB questions. Simple complaints resolve in a few questions; complex ones take more.
- Critical First Look is always screened. The Paediatric category is added automatically for age < 12. Age is required unless a Level 1 condition is present. Under 8 is never Level 5 (`RULE_PAED_AGE_RESTRICT_01`).
- If a condition is reported both present and absent in one call, present wins. Across turns, the latest answer wins (`TriageSession.merge_findings`).

**When the KB cannot classify yet**, the agent **keeps asking** the questions the engine returns until the status is `classified`. It stops without a level only when the complaint fits no KB category. In that case it advises in-person assessment and never guesses.

**Emergency numbers**: Malaysia only, **999** (or **112** from mobile). Never reference 911 or other countries' numbers.

**Editing the KB**: `mts_screening_kb.json` and `triage_question_training.json` are clinical content. **Never modify them without explicit user approval**, and any KB change must be checked against the PDF, never invented. `triage_question_training.json` is a synthetic prototype dataset (it mixes in Australian Triage Scale material). Nothing in the code uses it, and it was not re-aligned with the PDF.

---

## 5. Current Implementation Status (as of Oct 2026)

Know these gaps before assuming something works:
- **Working**: `/api/triage/chat` runs the agent with the rules engine. Sessions are in memory, keyed by `session_id`, and lost on restart. `assessment` in the response is built from the engine's result, never from LLM text.
- `TriageService.evaluate_triage` (`/api/triage/assess`) is still a **placeholder** that always returns `URGENT`. It is not wired to the engine.
- The **frontend does not call `/api/triage/*` yet**. Only `/auth/*` is wired. Intended design: questionnaire → `/triage/assess`, then chat follow-up via `/triage/chat` (**both**).
- `route_to_recommended_hospital`, `get_patient_history`, `query_hospital_facilities` and `search_medical_embeddings` are still placeholders.
- **LLM rate limits**: a screening uses several LLM calls per user turn, so keep the system prompt and tool results compact. The condition catalogue is deliberately NOT in the prompt; the engine returns the IDs the agent needs.
- The LLM sometimes re-asks things the user already said, or emits malformed tool-call JSON. The agent retries `tool_use_failed` once.
- Hospital data: **Supabase is canonical**. The xlsx files at the repo root are seed/import material. `hospital_data (1).xlsx` is a stray duplicate.

---

## 6. Key Architectural Decisions & Past Findings

### A. Geolocation & Distance Calculation

**Problem**: An early version of `backend/app/core/location_detector.py` used `geocoder.ip('me')`. IP geolocation is off by 5–50+ km, fails under carrier-grade NAT/VPN, and on a server it resolves the **data centre's IP**, not the patient's. Do not reintroduce server-side IP geolocation.

**Solution**:
1. **Client-side GPS** (`frontend/lib/services/location_service.dart`): checks the permission and service, gets a `LocationAccuracy.high` fix with a 10 s timeout, falls back to `getLastKnownPosition()`, then to Kuala Lumpur `LatLng(3.1390, 101.6869)`.
2. **Backend distance engine** (`location_detector.py`): Haversine great-circle distance (`calculate_haversine_distance`, km). `estimate_travel_time_minutes` assumes 35 km/h urban speed with a 1-minute minimum. `is_valid_coordinates` checks lat/lon ranges and rejects NaN/Inf. It is used by `RoutingService`.
3. **Dynamic UI** (`RecommendedHospitalsPage` in `hospital_routing.dart`): cards recalculate from live coordinates. The badge shows `GPS Active` (teal) or `Default` (grey). Distances under 1 km display in metres; times over 60 min display as `X h Y min`.

---

## 7. Developer Rules of Engagement

- **Primary demo target is Flutter Web (Chrome)**. Browser geolocation needs `localhost` or HTTPS. Backend CORS must allow the web dev origin.
- **Run locally**:
  - Backend: `cd backend; .\venv\Scripts\Activate.ps1; python main.py` → `http://127.0.0.1:8000`, API under `/api`.
  - Frontend: `cd frontend; flutter run -d chrome`.
- **Always test before finishing**: `pytest` inside `backend/`, and `flutter analyze` inside `frontend/`.
- **Git**: Effectively solo. **Never commit, push, or branch unless the user explicitly asks.**
- **Secrets**: Real keys live in `backend/.env` (gitignored). Never commit `.env` or paste keys into code.
- Keep the backend layering: routes → services → repositories / agents → tools. Routes stay thin.
