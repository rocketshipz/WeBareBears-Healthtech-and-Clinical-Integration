<<<<<<< HEAD
# MedicTri - Medical Emergency Triage & Hospital Routing System

A mobile-based first-level medical emergency triage and hospital routing system.

## Overview

MedicTri provides immediate emergency triage assessments and intelligently routes patients to appropriate healthcare facilities based on clinical urgency, specialty requirements, and facility proximity.

## System Architecture

```
Flutter Mobile App (Frontend)
       ↓
  Backend API (FastAPI)
       ↓
 Medical Triage Agent
 ├── Triage Tool
 ├── Patient History Tool
 ├── Hospital Data Tool
 ├── Hospital Routing Tool
 └── Embedding Tool
       ↓
 Database / Data Sources (PostgreSQL / Supabase)
```

## Repository Structure

- `backend/`: FastAPI backend service, Agentic AI, deterministic triage tools, and data access layer.
  - `backend/app/`: Core application modules (API, agents, tools, services, models, schemas, repositories, core).
  - `backend/data/`: Data storage directories (`patients/`, `triage/`, `hospitals/`).
  - `backend/tests/`: Integration and unit tests.
- `frontend/`: Flutter mobile frontend application (`triagemy`).
  - `frontend/lib/`: Mobile application code and UI screens.
  - `frontend/android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Platform support configurations.

## Getting Started

### 1. Backend Service (FastAPI)

1. Open a terminal and navigate to `backend/`:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment, then install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Configure your `.env` (copy from `.env.example`).
4. Run the backend server:
   ```bash
   python main.py
   ```
   Or using Uvicorn:
   ```bash
   uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
   ```
See [backend/README.md](backend/README.md) for full backend documentation.

### 2. Frontend Application (Flutter)

1. Open a terminal and navigate to `frontend/`:
   ```bash
   cd frontend
   ```
2. Install Flutter packages:
   ```bash
   flutter pub get
   ```
=======
# MedicTri - Flutter Mobile Frontend (`triagemy`)

The mobile client application for the MedicTri Emergency Triage & Hospital Routing System.

## Overview

The mobile frontend provides:
- Patient triage assessment questionnaire and symptom input
- Real-time communication with the FastAPI backend
- Hospital recommendations, routing, and emergency facility status

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13.4 or higher)
- Android Studio / Xcode / VS Code with Flutter extension
- An emulator or physical device

### Installation & Run

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```

>>>>>>> 4e23d20 (Add triage app updates)
3. Run the application:
   ```bash
   flutter run
   ```
<<<<<<< HEAD
See [frontend/README.md](frontend/README.md) for full mobile client documentation.

## AI Architecture

```
                         USER
                           │
                           ▼
                ┌────────────────────┐
                │   AGENTIC AI       │
                │   One LLM          │
                └─────────┬──────────┘
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
       Triage Tool   Health Tool   Hospital Tool
             │            │            │
             ▼            ▼            ▼
      Triage JSON     User Health    Hospital DB
      Principles      History        + Live Status
             │            │            │
             └────────────┼────────────┘
                          │
                          ▼
                  Embedding Search
                          │
                          ▼
                 Relevant information
                          │
                          ▼
                  Agent reasoning
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
      TRIAGE RESULT              HOSPITAL OPTIONS
      RED/YELLOW/GREEN           distance / ETA /
                                  waiting / capability
            │                           │
            └─────────────┬─────────────┘
                          ▼
                    REPORT TOOL
                          │
                          ▼
                  Patient Report
=======

To specify a target device (e.g. Chrome, Windows desktop, or a connected mobile emulator):
```bash
flutter run -d chrome
# or
flutter run -d windows
```

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart                 # Application entry point
│   └── screens/
│       └── login_screen.dart     # Authentication & initial screen
├── test/
│   └── widget_test.dart          # Widget tests
├── android/                      # Android native project files
├── ios/                          # iOS native project files
├── web/                          # Web platform files
├── windows/                      # Windows desktop files
├── macos/                        # macOS desktop files
├── linux/                        # Linux desktop files
├── pubspec.yaml                  # Flutter package dependencies
└── analysis_options.yaml         # Lint rules & static analysis configuration
>>>>>>> 4e23d20 (Add triage app updates)
```
