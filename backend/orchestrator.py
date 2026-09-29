import os
import time
from pydantic import BaseModel, Field
from langchain_core.prompts import ChatPromptTemplate
from agent import get_llm, get_agent_executor
from database import get_db, get_nopims_data
from prompts import system_instructions
# Fetch column headers/schemas on init
print("[Orchestrator] Fetching database schema on initialization...")
try:
    _db = get_nopims_data()
    DB_SCHEMA_INFO = _db.get_table_info()
    print("[Orchestrator] Successfully fetched database schema.")
except Exception as e:
    print(f"[Orchestrator] Failed to fetch database schema on init: {e}")
    DB_SCHEMA_INFO = "Failed to fetch schema."

import re

class IntentClassification(BaseModel):
    intent: str = Field(description="The intent of the user. Either 'DATABASE' if the user is asking for specific data or metrics requiring database lookup, or 'GENERAL' for greetings, casual chat, or general knowledge questions.")

def classify_intent(user_query: str, llm) -> str:
    # Fast heuristic for basic conversational greetings to bypass LLM classification
    greetings = r"^(hi|hello|hey|howdy|good morning|good afternoon|good evening|how are you|what's up)\b"
    #if re.match(greetings, user_query.strip(), re.IGNORECASE):
    #    print("[Orchestrator] Fast heuristic matched: GENERAL")
    #    return "GENERAL"

    prompt = ChatPromptTemplate.from_messages([
        ("system", """You are an intent routing orchestrator. Classify the user's intent as either 'DATABASE' or 'GENERAL'. 
        Use 'DATABASE' if they are querying specific data, metrics, or records that would exist in the database. 
        Use 'GENERAL' for casual talk or questions that don't need a database lookup.

        Here is the database schema to help you contextualize if the query is related to the database:
        {schema_info}
        """),
        ("user", "{query}")
    ])
    
    chain = prompt | llm.with_structured_output(IntentClassification)
    
    try:
        result = chain.invoke({
            "query": user_query,
            "schema_info": DB_SCHEMA_INFO
        })
        return result.intent
    except Exception as e:
        print(f"[Orchestrator] Intent classification error: {e}")
        # Fallback to general if structured output fails
        return "GENERAL"

def run_agent(user_query: str):
    start_time = time.perf_counter()
    """Orchestrates the request by classifying intent and routing to the right agent."""
    llm = get_llm()
    intent = classify_intent(user_query, llm)
    print(f"[Orchestrator] Intent classified as: {intent}")
    
    if intent == "DATABASE":
        print("[Orchestrator] Routing to SQL Database Agent...")
        agent_executor = get_agent_executor()
        full_prompt = f"{system_instructions}\n\nUser request: {user_query}"
        try:
            result = agent_executor.invoke({"input": full_prompt})
            
            end_time = time.perf_counter()
            print(f"[Orchestrator] Database Agent execution time: {end_time - start_time:.4f} seconds")

            yield result.get("output", "No response generated.")
        except Exception as e:
            yield f"Database Agent error during execution: {str(e)}"
    else:
        print("[Orchestrator] Routing to Conversational Agent...")
        try:
            prompt = ChatPromptTemplate.from_messages([
                ("system", "You are a helpful AI assistant. Answer the user's question conversationally. Format your responses with markdown when appropriate (e.g., **bold**, *italics*)."),
                ("user", "{query}")
            ])
            chain = prompt | llm
            
            # Stream the conversational response token by token
            for chunk in chain.stream({"query": user_query}):
                yield chunk.content
                
            end_time = time.perf_counter()
            print(f"[Orchestrator] Conversational Agent execution time: {end_time - start_time:.4f} seconds")
        except Exception as e:
            yield f"Conversational Agent error: {str(e)}"
