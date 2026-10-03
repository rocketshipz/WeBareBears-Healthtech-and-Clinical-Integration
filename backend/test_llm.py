import os
import sys
from dotenv import load_dotenv
from app.core.llm import get_llm, get_embeddings
from app.core.config import get_settings

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

load_dotenv()

def test_models():
    settings = get_settings()
    print("=" * 60)
    print("MedicTri AI Architecture Validation")
    print(f"Main Agent Model (Groq):    {settings.GROQ_MODEL_NAME}")
    print(f"Embedding Model (Gemini):   {settings.GEMINI_EMBEDDING_MODEL}")
    print("=" * 60)

    # 1. Test Main Agent LLM (Groq)
    print("\n[1/2] Testing Groq Main Agent LLM...")
    try:
        llm = get_llm()
        response = llm.invoke("Briefly state your purpose as a medical triage assistant.")
        print(f" Groq LLM Response:\n{response.content.strip()}\n")
    except Exception as e:
        print(f" Groq LLM failed: {e}\n")

    # 2. Test Embedding Model (Gemini)
    print("[2/2] Testing Gemini Embedding Model...")
    try:
        embeddings = get_embeddings()
        sample_text = "Patient presenting with acute chest tightness and diaphoresis."
        vector = embeddings.embed_query(sample_text)
        print(f" Gemini Embeddings generated successfully! Vector dimension: {len(vector)}")
    except Exception as e:
        print(f" Gemini Embeddings failed: {e}")

    print("\n" + "=" * 60)
    print("Validation Complete.")
    print("=" * 60)

if __name__ == "__main__":
    test_models()


