"""MedicTri Backend Application Package."""
from pathlib import Path
from dotenv import load_dotenv

# Ensure .env is automatically loaded into os.environ on package import
_backend_dir = Path(__file__).resolve().parent.parent
for _candidate in [_backend_dir / ".env", _backend_dir.parent / ".env"]:
    if _candidate.exists():
        load_dotenv(dotenv_path=_candidate, override=False)

__version__ = "0.1.0"
