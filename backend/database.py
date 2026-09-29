import os
import urllib.parse
import requests
from langchain_community.utilities import SQLDatabase
from dotenv import load_dotenv

load_dotenv()

def get_db() -> SQLDatabase:
    """Creates and returns the SQLAlchemy database connection."""
    db_user = os.getenv("POSTGRES_DB_USER")
    db_password = os.getenv("POSTGRES_DB_PASSWORD")
    db_host = os.getenv("POSTGRES_DB_HOST")
    db_name = os.getenv("POSTGRES_DB_NAME")
    db_port = os.getenv("POSTGRES_DB_PORT", "5432")
    
    encoded_password = urllib.parse.quote_plus(db_password)
    # The options flag ensures that the database transaction is read-only
    db_uri = f"postgresql+psycopg2://{db_user}:{encoded_password}@{db_host}:{db_port}/{db_name}?options=-c%20default_transaction_read_only=on"
    
    # Langchain SQLDatabase wrapper
    return SQLDatabase.from_uri(db_uri)

def get_nopims_data() -> SQLDatabase:
    import pandas as pd
    from sqlalchemy import create_engine
    import json

    url = os.getenv("NOPIMS_API_KEY")
    response = requests.get(url)
    data = response.json()
    
    if isinstance(data, dict):
        for key, value in data.items():
            if isinstance(value, list):
                data = value
                break
        else:
            data = [data]
            
    df = pd.DataFrame(data)
    engine = create_engine("sqlite:///nopims.db")
    
    for col in df.columns:
        if df[col].dtype == 'object':
            df[col] = df[col].apply(lambda x: json.dumps(x) if isinstance(x, (dict, list)) else str(x) if x is not None else None)
            
    df.to_sql("api_data", engine, index=False, if_exists="replace")
    
    return SQLDatabase(engine)