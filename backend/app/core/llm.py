import logging
from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from app.core.config import get_settings

logger = logging.getLogger(__name__)

_llm_instance: Optional[ChatOpenAI] = None
_embeddings_instance: Optional[GoogleGenerativeAIEmbeddings] = None


def get_llm() -> ChatOpenAI:
    """Returns a lazily initialized ChatOpenAI client (Azure OpenAI v1 endpoint) for the main agent.

    Falls back to a placeholder key if not configured to permit offline or test initialization.
    """
    global _llm_instance
    if _llm_instance is not None:
        return _llm_instance

    settings = get_settings()
    api_key = settings.OPENAI_API_KEY
    if not api_key or api_key.startswith("your_"):
        logger.warning(
            "OPENAI_API_KEY is not configured. Initializing ChatOpenAI with a placeholder key. "
            "Please set OPENAI_API_KEY in your .env file for live inference."
        )
        api_key = "dummy-openai-key"

    kwargs = {
        "model": settings.OPENAI_MODEL_NAME,
        "api_key": api_key,
        "temperature": settings.OPENAI_TEMPERATURE,
    }
    base_url = settings.get_openai_base_url()
    if base_url:
        kwargs["base_url"] = base_url
    logger.info(f"Initializing Azure OpenAI LLM client (deployment='{settings.OPENAI_MODEL_NAME}').")
    _llm_instance = ChatOpenAI(**kwargs)
    return _llm_instance


def get_embeddings() -> GoogleGenerativeAIEmbeddings:
    """Returns a singleton or lazily initialized GoogleGenerativeAIEmbeddings instance (Gemini)."""
    global _embeddings_instance
    if _embeddings_instance is not None:
        return _embeddings_instance

    settings = get_settings()
    api_key = settings.get_gemini_api_key()

    if not api_key or api_key.strip() == "your_gemini_api_key_here" or api_key.startswith("your_"):
        logger.warning(
            "Gemini API key is not configured for embeddings. Initializing GoogleGenerativeAIEmbeddings with a placeholder key."
        )
        api_key = "dummy-gemini-key"

    logger.info(f"Initializing Gemini Embeddings client (model='{settings.GEMINI_EMBEDDING_MODEL}').")
    _embeddings_instance = GoogleGenerativeAIEmbeddings(
        model=settings.GEMINI_EMBEDDING_MODEL,
        api_key=api_key,
    )
    return _embeddings_instance


def reset_llm_cache() -> None:
    """Resets cached LLM and embeddings instances (primarily useful for tests or config reloads)."""
    global _llm_instance, _embeddings_instance
    _llm_instance = None
    _embeddings_instance = None
