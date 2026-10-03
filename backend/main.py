from pathlib import Path
from dotenv import load_dotenv

# Load .env variables immediately
load_dotenv()

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from app.main import app, main

if __name__ == "__main__":
    main()
