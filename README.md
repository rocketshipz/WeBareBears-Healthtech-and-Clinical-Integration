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
- Flutter mobile frontend (to be connected).

## Getting Started

See [backend/README.md](file:///C:/Users/user/OneDrive/Documents/Projects/MedicTri/backend/README.md) for detailed backend setup and startup instructions.

AI Architecture

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
# triagemy

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
