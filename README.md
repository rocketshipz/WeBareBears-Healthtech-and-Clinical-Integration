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
3. Run the application:
   ```bash
   flutter run
   ```
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
```
