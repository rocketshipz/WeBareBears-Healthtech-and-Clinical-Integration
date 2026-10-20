"""Plain-language display wording (app/tools/plain_language.json): display only, never changes a finding."""
import pytest

from app.agents.triage_agent import kb_selection
from app.core.config import get_settings
from app.services import plain_language
from app.services.triage_controller import PARTS_CHECKLIST_MIN, HybridTriageController, _label
from app.services.triage_rules_engine import COMPOUND_NOTE, get_triage_rules_engine
from tests.test_triage_controller import FakeLLM, controller_with, default_tap, opening

FEVER = "Fever"


@pytest.fixture
def plain(monkeypatch):
    monkeypatch.setattr(get_settings(), "PLAIN_LANGUAGE", True)


def kb_texts(engine):
    texts = set()
    for q in engine.questions_by_id.values():
        texts.update(q["answers"])
        texts.update(_label(p["when"]) for p in q.get("maps_to", []))
    texts.update(v.split(COMPOUND_NOTE)[0].strip() for v in engine.ask_as.values())
    texts.update(c.text for c in engine.conditions.values())
    return texts


def test_every_entry_rewords_something_in_the_kb():
    engine = get_triage_rules_engine()
    questions, labels = plain_language.overlay()
    assert set(questions) <= set(engine.questions_by_id)
    assert set(labels) <= kb_texts(engine)
    assert not any("911" in t for t in list(questions.values()) + list(labels.values()))


def test_tick_list_headings_only_on_tick_list_questions():
    controller = HybridTriageController()
    for qid, text in plain_language.overlay()[0].items():
        q = controller.engine.questions_by_id[qid]
        items = controller._items({"kind": "question", "question_id": qid})
        is_parts = q["answers"] == ["Yes", "No"] and len(items) >= PARTS_CHECKLIST_MIN
        assert ("Tick all that apply" in text) == (is_parts or "Tick all that apply" in q["text"]), qid


def test_every_question_maps_each_shown_option_back_to_one_kb_option(plain):
    engine = get_triage_rules_engine()
    for q in engine.questions_by_id.values():
        options = kb_selection(q)["response"]
        shown = plain_language.options(options)
        assert sorted(shown.values()) == sorted(options), q["question_id"]


def test_off_shows_the_kb_text(monkeypatch):
    monkeypatch.setattr(get_settings(), "PLAIN_LANGUAGE", False)
    assert plain_language.label("Red currant jelly stools") == "Red currant jelly stools"


def test_a_plain_tap_records_the_same_findings_as_the_kb_tap(plain):
    controller = controller_with(FakeLLM(opening([FEVER], 30)))
    session = controller.run_session("I have a fever", session_id="s")
    while session.last_output.get("question_id") != "Q_FEVER_01":
        picked = default_tap(controller.engine, session.last_output)
        session = controller.run_session(picked[0], session_id="s", selected_options=picked)
    out = session.last_output
    assert out["question"] == "Do any of these come with the fever? Tick all that apply."
    shown = "Weak immune system (e.g. chemotherapy, steroids, HIV)"
    assert shown in out["response"]
    session = controller.run_session(shown, session_id="s", selected_options=[shown])
    item = next(it for it in controller._items({"kind": "question", "question_id": "Q_FEVER_01"})
                if plain_language.label(it["label"]) == shown)
    assert set(item["condition_ids"]) <= set(session.findings["present_condition_ids"])
