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

- **Main Agent Model (Groq)**: Powers reasoning, multi-turn clinical triage dialogs, and tool calling via `ChatGroq` (default: `openai/gpt-oss-120b`).
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
