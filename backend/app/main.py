import logging
import sys
import os
from pathlib import Path

# Ensure the backend directory is in the python path for module imports
backend_dir = Path(__file__).resolve().parent.parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import get_settings
from app.core.scheduler import start_scheduler, stop_scheduler
from app.api.routes import health, triage, auth, patients

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("medictri")

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    start_scheduler()
    yield
    stop_scheduler()


app = FastAPI(
    lifespan=lifespan,
    title=settings.APP_NAME,
    description="First-level medical emergency triage and hospital routing backend API.",
    version="0.1.0",
    debug=settings.DEBUG
)

# Enable CORS for Flutter mobile application
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routes
app.include_router(health.router, prefix="/api")
app.include_router(triage.router, prefix="/api")
app.include_router(auth.router, prefix="/api")
app.include_router(patients.router, prefix="/api")


@app.get("/")
async def root():
    """Root entry point with service metadata."""
    return {
        "service": settings.APP_NAME,
        "status": "online",
        "docs_url": "/docs",
        "api_endpoints": {
            "health": "/api/health",
            "auth_send_code": "/api/auth/send-code",
            "auth_verify_code": "/api/auth/verify-code",
            "auth_register": "/api/auth/register",
            "auth_login": "/api/auth/login",
            "triage_assess": "/api/triage/assess",
            "triage_chat": "/api/triage/chat"
        }
    }


def main():
    """Entry point to run the Uvicorn ASGI server."""
    import uvicorn
    print("=" * 60)
    print(f"Starting {settings.APP_NAME}")
    print(f"Host: {settings.HOST}:{settings.PORT}")
    print(f"Docs: http://{settings.HOST}:{settings.PORT}/docs")
    print("=" * 60)
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )


if __name__ == "__main__":
    main()
