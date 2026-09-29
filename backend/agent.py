import httpx
import os
from langchain_openai import ChatOpenAI
from langchain_community.agent_toolkits import create_sql_agent, SQLDatabaseToolkit
from database import get_db, get_nopims_data

_llm_instance = None

def get_llm():
    global _llm_instance
    if _llm_instance is not None:
        return _llm_instance
        
    endpoint = "https://hackathon-llm-2026.services.ai.azure.com/openai/v1"
    deployment_name = "gpt-5.4-mini"
    api_key = os.getenv("API_KEY")

    _llm_instance = ChatOpenAI(
        model=deployment_name,
        api_key=api_key,
        base_url=endpoint,
        temperature=0,
        http_client=httpx.Client(verify=False)
    )
    return _llm_instance

def get_agent_executor():
    llm = get_llm()
    db = get_nopims_data()
    
    agent_executor = create_sql_agent(
        llm=llm,
        toolkit=SQLDatabaseToolkit(db=db, llm=llm),
        verbose=True,
        agent_type="openai-tools",
        top_k=50
    )
    return agent_executor
