"""Everyday wording for triage questions and answer options (display only).

`app/tools/plain_language.json` rewords KB question text and option labels for the public. It holds no rules:
the hybrid controller shows the plain text, maps a tapped option back to its KB label before recording it, and
the rules engine only ever sees KB labels and condition IDs. Missing entries keep the KB text.
Used only when PLAIN_LANGUAGE is on (the wording is clinical content and needs review).
"""
import json
from functools import lru_cache
from pathlib import Path
from typing import Dict, List, Tuple

from app.core.config import get_settings

PATH = Path(__file__).resolve().parent.parent / "tools" / "plain_language.json"


@lru_cache
def overlay() -> Tuple[Dict[str, str], Dict[str, str]]:
    """(question_id -> question text, KB label -> plain label)."""
    data = json.loads(PATH.read_text(encoding="utf-8"))
    return data.get("questions", {}), data.get("labels", {})


def enabled() -> bool:
    return get_settings().PLAIN_LANGUAGE


def question(question_id: str, text: str) -> str:
    return overlay()[0].get(question_id, text) if enabled() else text


def label(text: str) -> str:
    return overlay()[1].get(text, text) if enabled() else text


def options(kb_options: List[str]) -> Dict[str, str]:
    """{shown text: KB label} for one question's options, in order. If two options would read the same, the KB
    text is shown for all of them, so every tap maps back to exactly one KB label."""
    mapping = dict(zip((label(o) for o in kb_options), kb_options))
    return mapping if len(mapping) == len(kb_options) else {o: o for o in kb_options}
