"""Short plain-language summary of the patient's main symptom, for the triage report.

Written once per screening, after it is classified, from what the user said (typed messages and picked options)
and the KB findings. It only describes; it never diagnoses or mentions a triage level. Anything that breaks those
rules, or a failed call, falls back to the user's own words (`chief_complaint`).
"""
import logging
import re
from typing import List, Optional

from langchain_core.messages import HumanMessage, SystemMessage

from app.core.llm import get_llm

logger = logging.getLogger(__name__)

SUMMARY_PROMPT = """Summarise a patient's main symptom for an emergency triage report in Malaysia.
Input: what the person said during the screening (their messages and the answers they picked), and the screening's findings.
Write ONE short phrase in English, at most 15 words, in plain words: who it is if not the user (e.g. "Mother, 45:"), the main problem, and key details they gave (where, how it happened, how long, how bad).
Describe only what they said. Never diagnose or guess a condition, never mention a triage level, never add advice.
Return only the phrase, no quotes."""

MAX_WORDS = 20
_BANNED = re.compile(r"\blevel\s*[1-5]\b|\btriage\b|\bdiagnos|\b911\b", re.IGNORECASE)


def summarize_main_symptom(user_messages: List[str], key_findings: List[str]) -> Optional[str]:
    """The summary phrase, or None if the LLM call fails or its answer breaks the rules."""
    said = [m.strip()[:200] for m in user_messages if m and m.strip()][-15:]
    if not said:
        return None
    content = "Person said:\n- " + "\n- ".join(said)
    if key_findings:
        content += "\nFindings: " + "; ".join(key_findings)
    messages = [SystemMessage(content=SUMMARY_PROMPT), HumanMessage(content=content)]
    llm = get_llm()
    try:
        try:
            response = llm.bind(reasoning_effort="minimal").invoke(messages)
        except Exception as e:
            if "reasoning" not in str(e).lower():
                raise
            response = llm.invoke(messages)  # deployment without reasoning_effort
    except Exception as e:
        logger.warning(f"[symptom_summary] Summary failed, using the user's words: {e}")
        return None
    text = str(getattr(response, "content", "") or "").strip().strip('"').strip()
    if not text or len(text.split()) > MAX_WORDS or "\n" in text or _BANNED.search(text):
        logger.warning(f"[symptom_summary] Summary rejected, using the user's words: {text!r}")
        return None
    return text


def ensure_main_symptom(session) -> None:
    """Once the screening is classified, write `session.main_symptom` (once; falls back to the user's words)."""
    result = session.triage_result or {}
    if result.get("status") != "classified" or getattr(session, "main_symptom", None):
        return
    # "[...]" messages are the app's own placeholders (e.g. after a content-filter refusal), not the user's words.
    user_messages = [m.content for m in session.messages if isinstance(m, HumanMessage)
                     and isinstance(m.content, str) and not m.content.startswith("[")]
    session.main_symptom = (summarize_main_symptom(user_messages, result.get("key_findings", []))
                            or session.chief_complaint)
