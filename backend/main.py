import sys
import os
# Ensure the backend module can be imported when running from the root folder
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from api import app

def main():
    print("=====================================================")
    print("Starting Energy Company AI Assistant Backend Server")
    print("Running on http://127.0.0.1:8000")
    print("=====================================================")
    
    # Run the flask app on port 8000
    app.run(host="127.0.0.1", port=8000, debug=True)

if __name__ == "__main__":
    main()
