# MedicTri: Agent & Developer Guidelines

> **Target Audience**: Future AI Agents and Developers working on the **MedicTri** codebase.  
> **Last Updated**: October 2026  
> **System Purpose**: First-level emergency medical triage assessment and intelligent hospital routing for patients in Malaysia.

---

## 1. System Overview & Core Philosophy

MedicTri (**TriageMY**) is a dual-tier emergency medical assistance application:
1. **Clinical Emergency Triage**: Screens patient complaints, symptoms, duration, and red-flag danger signs inspired by standard clinical protocols (Manchester Triage System / CTAS / ESI) to assign an emergency triage level:
   * **Red Zone (Level 1)**: Resuscitation / Immediate emergency care advised.
   * **Yellow Zone (Levels 2–3)**: Emergent / Urgent medical assessment advised.
   * **Green Zone (Levels 4–5)**: Non-urgent / primary care or walk-in clinic advised.
2. **Proximity & Capability Routing**: Dynamically matches patients to healthcare facilities based on their **live GPS location**, facility emergency capabilities (24/7 ER, ICU capacity), required medical specialties (Trauma, Cardiology, Pediatrics, etc.), and travel time.

---

## 2. Architecture & Tech Stack

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Mobile / Web UI              │
│       (lib/pages, lib/screens, lib/services)           │
└───────────────────────────┬────────────────────────────┘
                            │ REST / JSON (HTTP)
                            ▼
┌────────────────────────────────────────────────────────┐
│                   FastAPI Backend API                  │
│               (app/api/routes, app/services)           │
└─────────────┬────────────────────────────┬─────────────┘
              │                            │
              ▼                            ▼
┌───────────────────────────┐  ┌─────────────────────────┐
│     Medical Triage Agent  │  │   Core Utilities        │
│     (LangChain + Groq)    │  │   - Location Detector   │
│   ├── Triage Tool         │  │     (Haversine math)    │
│   ├── Hospital Data Tool  │  │   - Database (Supabase) │
│   ├── Routing Tool        │  │   - Auth & Security     │
│   ├── Patient History Tool│  └─────────────────────────┘
│   └── Embedding Tool      │
└───────────────────────────┘
```

### Stack Components:
- **Frontend**: Flutter 3.x (Dart 3.x)
  - State & UI: Material 3, custom gradient design system in `lib/theme.dart`.
  - Mapping: `flutter_map` (v8) + `latlong2`.
  - Geolocation: `geolocator` (v14).
  - Documents: `pdf` + `printing` for triage report exports.
  - Networking: `http`.
- **Backend**: Python 3.11+ / FastAPI
  - Data Validation: `pydantic` v2, `pydantic-settings`.
  - Database: PostgreSQL / Supabase with SQLAlchemy repositories.
  - Agentic LLM: `langchain-groq` (default: `llama-3.3-70b-versatile`), `langchain-google-genai` (embeddings: `text-embedding-004`).
  - Unit Tests: `pytest`, `pytest-asyncio`.

---

## 3. Directory Map

```
MedicTri/
├── AGENT_GUIDELINES.md                  # This file
├── README.md                            # High-level project summary
├── hospital_data.xlsx                   # Facility registry & coordinates dataset
├── backend/
│   ├── main.py                          # Root entry point for Uvicorn
│   ├── requirements.txt                 # Backend dependencies
│   ├── app/
│   │   ├── main.py                      # FastAPI application definition & CORS
│   │   ├── api/routes/                  # Endpoints (auth.py, triage.py, health.py)
│   │   ├── core/                        # Config, DB connection, location_detector.py, llm.py
│   │   ├── models/                      # Domain entities (hospital, patient, triage, user)
│   │   ├── schemas/                     # Pydantic schemas (hospital, triage, auth, common)
│   │   ├── repositories/                # Data access layer (hospital, patient, user)
│   │   ├── services/                    # Business logic (triage_service, routing_service, auth_service)
│   │   ├── tools/                       # 5 LangChain tools for MedicalTriageAgent
│   │   └── agents/                      # MedicalTriageAgent runner
│   └── tests/                           # Unit & integration tests
└── frontend/
    ├── pubspec.yaml                     # Flutter dependencies
    └── lib/
        ├── main.dart                    # Flutter entry point
        ├── theme.dart                   # Typography, brand colors, custom widgets
        ├── screens/                     # login_screen, signup_page, forgot_password
        ├── pages/
        │   ├── home_page.dart           # Home dashboard & triage history
        │   ├── triage_engine.dart       # Interactive questionnaire flow
        │   ├── triage_report.dart       # Triage assessment results & PDF generator
        │   ├── hospital_routing.dart    # Dynamic recommended hospitals & navigation
        │   └── hospital_homepage.dart   # Interactive map view of nearby facilities
        └── services/
            ├── api_service.dart         # Base URL routing (Android 10.0.2.2 vs Web localhost)
            ├── auth_service.dart        # Authentication, JWT tokens, OTP verification
            └── location_service.dart    # High-accuracy GPS, distance & travel time
```

---

## 4. Key Architectural Decisions & Past Findings

### A. Geolocation & Distance Calculation (Critical Insight)

#### The Problem:
An early script (`backend/app/core/location_detector.py`) used `geocoder.ip('me')`.
- **Finding**: IP geolocation is **not exact** (off by 5–50+ km, fails on mobile data carrier-grade NAT and VPNs). Crucially, in production, running `ip('me')` on a backend server resolves the **data center's IP**, not the patient.

#### The Solution Implemented:
1. **Client-Side GPS (`LocationService` in `frontend/lib/services/location_service.dart`)**:
   - The user's exact coordinates originate on the mobile device via GPS hardware and Wi-Fi trilateration.
   - Handles permissions (`isLocationServiceEnabled()`, `requestPermission()`), requests high-accuracy fix (`LocationAccuracy.high`) with a 10-second timeout, and falls back safely to `getLastKnownPosition()`.
   - Baseline fallback coordinates: Kuala Lumpur `LatLng(3.1390, 101.6869)`.
2. **Backend Distance Engine (`backend/app/core/location_detector.py`)**:
   - Implements the mathematical **Haversine formula** (`calculate_haversine_distance`) computing great-circle distance in kilometers.
   - Implements urban driving time estimation (`estimate_travel_time_minutes`) at an average urban speed of 35 km/h with a guaranteed 1-minute minimum clamp.
   - Coordinate validation (`is_valid_coordinates`) ensuring $-90 \le \text{lat} \le 90$ and $-180 \le \text{lon} \le 180$, rejecting NaN/Inf.
   - Connected directly into [`RoutingService`](file:///C:/Users/user/OneDrive/Documents/Projects/MedicTri/backend/app/services/routing_service.py).
3. **Dynamic UI (`RecommendedHospitalsPage` in `frontend/lib/pages/hospital_routing.dart`)**:
   - Hospital cards dynamically recalculate their distances and travel times using the live coordinates.
   - Visual status badge displays **`GPS Active`** (teal) or **`Default`** (grey fallback).
   - Formatter converts `< 1.0 km` to meters (e.g. `111 m`) and `> 60 min` to hours/minutes (e.g. `8 h 25 min`).

---

## 5. Testing & Verification Runbook

### 1. Backend Automated Tests
Always run the pytest suite before committing backend changes:
```powershell
# From project root:
backend\venv\Scripts\pytest backend\tests -v
```
*Current test suite*: 21 tests covering auth, health, location detector math, structure, and triage schemas.

### 2. Manual Testing of Location in Flutter Web (Fastest Method)
Chrome DevTools allows simulating any GPS coordinate on Earth:
1. **Start Backend**:
   ```powershell
   cd backend
   python -m uvicorn app.main:app --reload
   ```
2. **Start Frontend in Chrome**:
   ```powershell
   cd frontend
   flutter run -d chrome
   ```
3. Log in (or register; email verification codes print to the backend terminal log).
4. Open Chrome DevTools (`F12`) $\rightarrow$ Press `Esc` $\rightarrow$ Open **Sensors** tab from drawer menu $\rightarrow$ Select **Location: Other...**.
5. Set coordinates:
   - *Nearby test (KL City)*: `3.1466, 101.7115` $\rightarrow$ Central General Hospital displays `~2.3 km · 4 min`.
   - *Far test (Penang)*: `5.4164, 100.3327` $\rightarrow$ Central General Hospital displays `~294 km · 8 h 25 min`.
   - *Walking test (<1km)*: `3.1460, 101.6910` $\rightarrow$ displays `~111 m · 1 min`.

> **Note on UI Lifecycle**: `RecommendedHospitalsPage` queries GPS on `initState()`. If you modify DevTools Sensors coordinates while on the page, tap Back (`<`) and re-enter **Hospital routing** to refresh.

---

## 6. Roadmap & Next Steps for Incoming Agents

When tasked with further enhancements, prioritize the following known gaps:

1. **Hospital Dataset Ingestion (`hospital_data.xlsx`)**:
   - The root contains `hospital_data.xlsx` with Malaysian hospitals and emergency departments.
   - Task: Create an ETL script to seed these facilities into Supabase / PostgreSQL tables via [`HospitalRepository`](file:///C:/Users/user/OneDrive/Documents/Projects/MedicTri/backend/app/repositories/hospital_repository.py).
2. **Platform Permissions Declarations**:
   - For Android: Ensure `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`, `ACCESS_COARSE_LOCATION`, and `INTERNET` are declared in `frontend/android/app/src/main/AndroidManifest.xml`.
   - For iOS: Ensure `<key>NSLocationWhenInUseUsageDescription</key>` is added to `frontend/ios/Runner/Info.plist`.
3. **Connect MapController in `hospital_homepage.dart`**:
   - In `hospital_homepage.dart`, instantiate a `MapController` and call `mapController.move(currentLocation, 13.5)` in `_getCurrentLocation()` so the camera pans automatically to the user marker when GPS locks asynchronously.
4. **1-Tap Navigation Direct Route Intent**:
   - Update `_openGoogleMaps` in `hospital_routing.dart` to use Google Maps direction URL:
     `https://www.google.com/maps/dir/?api=1&origin=${userLat},${userLon}&destination=${hospitalName}`.
5. **Real Database Query in `RoutingService`**:
   - Replace the empty list in `RoutingService.recommend_hospitals` with spatial queries ranking facilities by calculated proximity (`calculate_haversine_distance`) and clinical suitability score.

---

## 7. Developer Rules of Engagement

- **No Mock Data in Core Services**: As per project conventions, business layer services must not return fake hardcoded business models; use data repositories or dynamic calculations.
- **Maintain Documentation Integrity**: Preserve existing comments and docstrings.
- **Always Test Before Finishing**: Verify changes with `pytest backend/tests` and `flutter analyze` inside `frontend/`.
