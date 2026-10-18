"""Main-symptom summary for the triage report: an LLM phrase with guardrails and a fallback."""
from langchain_core.messages import AIMessage, HumanMessage

from app.agents.triage_agent import TriageSession
from app.services import symptom_summary
from app.services.symptom_summary import ensure_main_symptom, summarize_main_symptom


class FakeLLM:
    def __init__(self, reply):
        self.reply, self.calls = reply, []

    def bind(self, **kwargs):
        return self

    def invoke(self, messages):
        self.calls.append(messages)
        if isinstance(self.reply, Exception):
            raise self.reply
        return AIMessage(content=self.reply)


def _use(monkeypatch, reply):
    llm = FakeLLM(reply)
    monkeypatch.setattr(symptom_summary, "get_llm", lambda: llm)
    return llm


def _classified_session():
    session = TriageSession(session_id="s", chief_complaint="i twisted my ankle playing futsal")
    session.messages = [HumanMessage(content="hi"), AIMessage(content="What is the problem?"),
                        HumanMessage(content="i twisted my ankle playing futsal"),
                        HumanMessage(content="[The user's previous message could not be processed.]"),
                        HumanMessage(content="Mild pain (1-3)")]
    session.triage_result = {"status": "classified", "key_findings": ["Mild symptoms"]}
    return session


def test_summary_is_written_once_when_classified(monkeypatch):
    llm = _use(monkeypatch, "Twisted ankle while playing futsal, mild pain")
    session = _classified_session()
    ensure_main_symptom(session)
    assert session.main_symptom == "Twisted ankle while playing futsal, mild pain"
    sent = llm.calls[0][1].content
    assert "futsal" in sent and "Mild pain (1-3)" in sent and "could not be processed" not in sent
    ensure_main_symptom(session)
    assert len(llm.calls) == 1  # not rewritten on later turns


def test_not_written_before_classification(monkeypatch):
    llm = _use(monkeypatch, "anything")
    session = _classified_session()
    session.triage_result = {"status": "insufficient_information"}
    ensure_main_symptom(session)
    assert session.main_symptom is None and not llm.calls


def test_rule_breaking_or_failed_summary_falls_back_to_the_users_words(monkeypatch):
    for reply in ("Sprained ankle, Level 5 triage", "Likely an ankle fracture needing diagnosis",
                  " ".join(["word"] * 25), RuntimeError("service down")):
        _use(monkeypatch, reply)
        session = _classified_session()
        ensure_main_symptom(session)
        assert session.main_symptom == "i twisted my ankle playing futsal", reply


def test_nothing_said_means_no_call(monkeypatch):
    llm = _use(monkeypatch, "x")
    assert summarize_main_symptom(["", "  "], []) is None and not llm.calls
