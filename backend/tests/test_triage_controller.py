"""Hybrid triage controller (TRIAGE_MODE=hybrid): the flow runs in code, the LLM only extracts and phrases.

The LLM is faked: the extractor answers from a per-test function, the presenter echoes the step's text.
"""
import json
import pytest
from langchain_core.messages import AIMessage
from app.agents.hybrid_prompts import EXTRACT_PROMPT
from app.agents.triage_agent import _FILTERED_REPLY, NOT_SURE
from app.services.triage_controller import CALL_999, DISCLAIMER, SAY, HybridTriageController, for_you, parse_age
from app.services.triage_rules_engine import NONE_ANSWERS, get_triage_rules_engine

TRAUMA = "Trauma & Physical Injuries"
FEVER = "Fever"
SEVERE_FEVER_HEADACHE = "Headache that makes normal activities hard, or worse (pain 5-10)"
MILD_FEVER_HEADACHE = "Mild headache - can still do normal activities (pain 0-4)"
LIMB = "Arm, leg, hand or foot"


class FakeLLM:
    """Extractor answers via `extract(payload)`; presenter echoes `say` (or `present(payload)` if given)."""

    def __init__(self, extract=None, present=None):
        self.extract = extract or (lambda payload: {})
        self.present = present or (lambda payload: {"text": payload["say"], "fixed": []})
        self.extract_calls, self.present_calls = [], []

    def bind(self, **kwargs):  # reasoning_effort
        return self

    def invoke(self, messages):
        payload = json.loads(messages[1].content)
        if messages[0].content == EXTRACT_PROMPT:
            self.extract_calls.append(payload)
            return AIMessage(content=json.dumps(self.extract(payload)))
        self.present_calls.append(payload)
        return AIMessage(content=json.dumps(self.present(payload)))


def controller_with(llm):
    controller = HybridTriageController()
    controller._llm = llm
    return controller


def opening(categories, age=None, facts=(), present=()):
    """Extractor for the opening message only; later free text records nothing."""
    def extract(payload):
        if payload["question"] is None and payload["categories"]:
            return {"categories": categories, "age_years": age, "facts": list(facts), "present": list(present)}
        return {}
    return extract


def default_tap(engine, out):
    q = engine.questions_by_id.get(out.get("question_id"))
    options = out["response"]
    for candidate in (list(q.get("none_answers", [])) if q else []) + ["No", *NONE_ANSWERS]:
        if candidate in options:
            return [candidate]
    raise AssertionError(f"no default answer in {options}")


def drive(controller, message, answers, max_turns=30):
    """Tap the scripted options (prefix match by question_id); everything else gets the "none" answer."""
    engine = get_triage_rules_engine()
    session = controller.run_session(message, session_id="s")
    asked = []
    for _ in range(max_turns):
        out = session.last_output
        if session.finished:
            return session, asked
        assert out["type"] == "selection", out
        qid = out.get("question_id")
        asked.append(qid)
        spec = answers.get(qid)
        if spec is None:
            picked = default_tap(engine, out)
        else:
            spec = spec if isinstance(spec, list) else [spec]
            picked = [next(o for o in out["response"] if o.lower().startswith(s.lower())) for s in spec]
        session = controller.run_session("; ".join(picked), session_id="s", selected_options=picked)
    raise AssertionError(f"did not finish: {asked}")


def test_parse_age():
    assert parse_age("30") == 30
    assert parse_age("I'm 21 years old") == 21
    assert parse_age("6 months") == 0.5
    assert parse_age("umur 40") == 40
    assert parse_age("no idea") is None


def test_taps_need_no_extraction_and_follow_the_engine_order():
    llm = FakeLLM(opening([TRAUMA], 21))
    controller = controller_with(llm)
    session, asked = drive(controller, "sprained ankle, i am 21", {
        "Q_TRAUMA_00": [LIMB], "Q_CRIT_05": "Can still do normal activities", "Q_TRAUMA_07": "Mild - can still use it",
        "Q_LIMB_04": "Yes"})
    assert session.triage_result["status"] == "classified" and session.triage_result["triage_level"] == 5
    assert len(llm.extract_calls) == 1  # the opening message only; every tap went straight to the engine
    assert len(llm.present_calls) == len(asked) + 1  # one phrasing per reply
    assert asked[0] == "Q_CRIT_01"
    text = session.last_output["response"]
    assert "Level 5 - Routine" in text and text.endswith(DISCLAIMER)


def test_age_is_asked_and_parsed_without_the_llm():
    llm = FakeLLM(opening([TRAUMA]))
    controller = controller_with(llm)
    session = controller.run_session("I twisted my ankle", session_id="s")
    assert session.pending == {"kind": "age"} and session.last_output["response"] == for_you(SAY["age"])
    session = controller.run_session("30 years old", session_id="s")
    assert session.findings["age_years"] == 30 and len(llm.extract_calls) == 1


def test_unknown_complaint_is_asked_then_stops_instead_of_looping():
    controller = controller_with(FakeLLM())
    for _ in range(2):
        session = controller.run_session("hello", session_id="s")
        assert session.pending == {"kind": "complaint"}
    session = controller.run_session("hello", session_id="s")
    assert session.finished and "in-person" in session.last_output["response"]


def test_danger_in_free_text_classifies_at_once_with_999_first():
    llm = FakeLLM(opening([], present=["RULE_CRIT_L1_01.C2"]))
    controller = controller_with(llm)
    session = controller.run_session("My dad collapsed and isn't breathing", session_id="s")
    assert session.triage_result["triage_level"] == 1
    assert session.last_output["response"].startswith(CALL_999)
    # The danger list is always offered with free text.
    assert any(c["id"] == "RULE_CRIT_L2_01.C4" for c in llm.extract_calls[0]["danger_conditions"])


def test_interim_advice_comes_first_and_only_once():
    # Severe pain (Level 2) reported up front: advise now, keep screening for more urgent items.
    controller = controller_with(FakeLLM(opening([TRAUMA], 30, present=["RULE_CRIT_L2_01.C3"])))
    session = controller.run_session("I hurt my leg, pain is 9/10, I'm 30", session_id="s")
    assert session.triage_result["status"] == "insufficient_information"
    assert session.last_output["question"].startswith("So far this is at least Level 2")
    picked = default_tap(get_triage_rules_engine(), session.last_output)
    session = controller.run_session(picked[0], session_id="s", selected_options=picked)
    assert "So far" not in (session.last_output["question"] or session.last_output["response"])


def test_extracted_ids_outside_the_offered_lists_are_dropped():
    def extract(payload):
        return {"categories": [TRAUMA, "Not a category"], "age_years": 30,
                "present": ["RULE_TRAUMA_L3_01.C1", "RULE_MADE_UP.C1"]}
    session = controller_with(FakeLLM(extract)).run_session("ankle", session_id="s")
    assert session.findings["categories"] == [TRAUMA]
    assert session.findings["present_condition_ids"] == []  # neither ID was offered at this tier


def test_catch_up_fills_in_reported_facts_but_never_rules_out():
    def extract(payload):
        if payload["question"] is None and payload["categories"]:
            # No question on screen: this "absent" must be ignored.
            return {"categories": [TRAUMA], "age_years": 30, "facts": ["pain 6/10"],
                    "absent": ["RULE_CRIT_L2_01.C2", "RULE_CRIT_L2_01.C3"]}
        offered = [c["id"] for c in payload["open_conditions"]]
        if payload["message"] == "pain 6/10":  # catch-up: an over-eager extractor rules out everything else
            return {"present": [i for i in offered if i == "RULE_CRIT_L3_01.C7"],
                    "absent": [i for i in offered if i != "RULE_CRIT_L3_01.C7"]}
        return {}
    llm = FakeLLM(extract)
    controller = controller_with(llm)
    session = controller.run_session("twisted ankle, pain 6/10, no chest pain, 30", session_id="s")
    assert session.findings["absent_condition_ids"] == []
    session, asked = drive(controller, "", {"Q_TRAUMA_00": [LIMB], "Q_TRAUMA_07": "Mild - can still use it",
                                            "Q_CRIT_05": "The pain makes normal activities hard"})
    assert "Q_CRIT_05" in asked  # a volunteered negative does not skip the Level 2 pain question
    assert session.triage_result["triage_level"] == 3
    catch_ups = [p for p in llm.extract_calls if p["message"] == "pain 6/10"]
    assert catch_ups
    checked = [c["id"] for p in catch_ups for c in p["open_conditions"]]
    assert len(checked) == len(set(checked))  # each condition is checked against the facts only once
    # Only taps ruled things out: every absent condition belongs to a question that was asked.
    engine = get_triage_rules_engine()
    asked_ids = {i for q in asked if q for p in engine.questions_by_id[q]["maps_to"]
                 for i in p["condition_ids"] + p.get("covers", [])}
    assert set(session.findings["absent_condition_ids"]) <= asked_ids


def test_a_bare_no_with_no_question_rules_nothing_out():
    # Reproduces an under-triage: after the self-harm content filter, "No, none of that." was read as ruling
    # out every condition, and a "denies all symptoms" fact then wiped every later tier.
    def extract(payload):
        if "hurt myself" in payload["message"]:
            raise RuntimeError("{'code': 'content_filter', 'self_harm': {'filtered': True, 'severity': 'medium'}}")
        offered = [c["id"] for c in payload["open_conditions"]]
        return {"absent": offered, "present": [], "facts": ["denies all listed symptoms"], "age_years": 24}
    controller = controller_with(FakeLLM(extract))
    controller.run_session("I keep thinking about hurting myself, I'm 24", session_id="s")
    session = controller.run_session("No, none of that.", session_id="s")
    assert session.findings["absent_condition_ids"] == []
    assert session.triage_result["status"] == "insufficient_information"


def test_catch_up_never_raises_urgency_to_level_1_or_2():
    # "wheezing" typed up front must not become Level 2 "abnormal sounds": the KB checklist decides that.
    def extract(payload):
        if payload["question"] is None and payload["categories"]:
            return {"categories": ["Shortness of Breath & Respiratory Complaints"], "age_years": 22,
                    "facts": ["wheezing", "has asthma"]}
        return {"present": [c["id"] for c in payload["open_conditions"]]}  # an over-eager extractor
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("I'm wheezing, I have asthma. 22", session_id="s")
    levels = {get_triage_rules_engine().conditions[i].level for i in session.findings["present_condition_ids"]}
    assert not levels & {1, 2}


def test_yes_no_prefixed_options_map_to_their_kb_part():
    controller = controller_with(FakeLLM())
    step = {"kind": "question", "question_id": "Q_PAED_06"}
    found = controller._match_parts(step, ["No - active and comfortable"])
    assert found["present_condition_ids"] == ["RULE_PAED_L4_01.C1"]
    assert "RULE_PAED_L1_01.C14" in found["absent_condition_ids"]
    assert controller._match_parts(step, ["Yes - crying more than 2 hours, or inconsolable on arrival"]) is None


def test_not_sure_asks_yes_no_follow_ups():
    engine = get_triage_rules_engine()
    controller = controller_with(FakeLLM(opening([TRAUMA], 30)))
    session = controller.run_session("hurt my arm", session_id="s")
    assert session.last_output["question_id"] == "Q_CRIT_01"
    session = controller.run_session(NOT_SURE, session_id="s", selected_options=[NOT_SURE])
    assert session.pending["kind"] == "confirm" and session.last_output["response"] == ["Yes", "No"]
    first = session.pending["items"][0]
    session = controller.run_session("No", session_id="s", selected_options=["No"])
    assert set(first["condition_ids"]) <= set(session.findings["absent_condition_ids"])
    assert "Q_CRIT_01" in session.findings["answered_question_ids"]
    assert engine.questions_by_id["Q_CRIT_01"]  # sanity


def test_yes_to_a_two_part_question_asks_which():
    controller = controller_with(FakeLLM())
    session = controller.get_session("s")
    controller._apply_picked(session, {"kind": "question", "question_id": "Q_HA_02"}, ["Yes"])
    assert session.queue == [{"kind": "which", "question_id": "Q_HA_02"}]


def test_a_yes_no_question_naming_several_things_is_one_tick_list():
    engine = get_triage_rules_engine()
    controller = controller_with(FakeLLM(opening([FEVER], 30)))
    session = controller.run_session("I have a fever", session_id="s")
    while session.last_output.get("question_id") != "Q_FEVER_02":
        picked = default_tap(engine, session.last_output)
        session = controller.run_session(picked[0], session_id="s", selected_options=picked)
    out = session.last_output
    assert session.pending["kind"] == "parts" and out["multi_select"]
    assert SEVERE_FEVER_HEADACHE in out["response"] and "Yes" not in out["response"]
    # "None of these" records exactly what "No" did.
    none = controller._items_findings(session.pending["items"], {NONE_ANSWERS[0]})
    assert set(none["absent_condition_ids"]) == set(engine.apply_answers("Q_FEVER_02", ["No"])["absent_condition_ids"])
    session = controller.run_session(SEVERE_FEVER_HEADACHE, session_id="s", selected_options=[SEVERE_FEVER_HEADACHE])
    assert "RULE_FEVER_L3_01.C2" in session.findings["present_condition_ids"]
    assert "RULE_FEVER_L3_01.C1" in session.findings["absent_condition_ids"]
    assert "Q_FEVER_02" in session.findings["answered_question_ids"]


@pytest.mark.parametrize("age, headache, level", [
    (30, MILD_FEVER_HEADACHE, 4),     # Headache 'Associated fever' (adult)
    (30, SEVERE_FEVER_HEADACHE, 3),   # Fever 'Headache with pain score > 4' (adult)
    (9, MILD_FEVER_HEADACHE, 3),      # Headache 'Associated fever' (paediatric)
    (9, SEVERE_FEVER_HEADACHE, 2),    # Fever 'Headache with pain score > 4' (paediatric)
])
def test_fever_with_headache_is_graded_by_pain(age, headache, level):
    controller = controller_with(FakeLLM(opening([FEVER], age)))
    session, asked = drive(controller, "I have a fever and a headache", {
        "Q_CRIT_05": "Can still do normal activities", "Q_FEVER_02": headache,
        "Q_PAED_06": "No - active and comfortable"})
    result = session.triage_result
    assert result["status"] == "classified" and result["triage_level"] == level
    if headache == MILD_FEVER_HEADACHE:
        assert "Headache" in session.findings["categories"]
        assert any(q.startswith("Q_HA_") for q in asked)  # the Headache red flags are still asked


def test_not_choosing_the_mild_headache_rules_nothing_out_under_headache():
    engine = get_triage_rules_engine()
    found = engine.apply_answers("Q_FEVER_02", ["No"])
    assert "RULE_HA_L4_01.C4" not in found["absent_condition_ids"]
    assert "RULE_FEVER_L3_01.C2" in found["absent_condition_ids"]
    assert "categories" not in found
    controller = controller_with(FakeLLM())
    items = controller._items({"kind": "question", "question_id": "Q_FEVER_02"})
    assert controller._items_findings(items, {MILD_FEVER_HEADACHE})["categories"] == ["Headache"]
    assert "RULE_HA_L4_01.C4" not in controller._items_findings(items, {SEVERE_FEVER_HEADACHE})["absent_condition_ids"]


def test_questions_say_you_when_the_screening_is_for_the_user():
    assert for_you("Is the person pregnant?") == "Are you pregnant?"
    assert for_you("Does the person have kidney disease?") == "Do you have kidney disease?"
    assert for_you("Where or how was the person hurt?") == "Where or how were you hurt?"
    assert for_you("After fainting, is the person's level of consciousness altered?") == \
        "After fainting, is your level of consciousness altered?"
    # A phrasing that still says "the person" is replaced by the template, already in the second person.
    llm = FakeLLM(opening([TRAUMA]), present=lambda p: {"text": "How old is the person?"})
    session = controller_with(llm).run_session("I twisted my ankle", session_id="s")
    assert session.subject == "self" and llm.present_calls[-1]["subject"] == "self"
    assert session.last_output["response"] == "How old are you?"


def test_questions_keep_the_person_when_it_is_for_someone_else():
    def extract(payload):
        return {"categories": [TRAUMA], "subject": "other"} if payload["categories"] else {}
    session = controller_with(FakeLLM(extract)).run_session("my mother fell", session_id="s")
    assert session.last_output["response"] == SAY["age"]


def test_bad_phrasing_falls_back_to_the_template():
    llm = FakeLLM(opening([TRAUMA]), present=lambda p: {"text": "Call 911, this is Level 1!"})
    session = controller_with(llm).run_session("ankle", session_id="s")
    assert session.last_output["response"] == for_you(SAY["age"])


def test_malay_translation_must_keep_every_number():
    def present(payload):
        return {"text": "Ayah anda perlu bantuan segera, sila hubungi?",
                "fixed": [line.replace("999", "") for line in payload["fixed"]]}
    llm = FakeLLM(lambda p: {"categories": [], "present": ["RULE_CRIT_L1_01.C2"], "language": "ms"}, present)
    session = controller_with(llm).run_session("Ayah saya tidak bernafas", session_id="s")
    assert session.last_output["response"].startswith(CALL_999)  # translation dropped 999: English kept


def test_content_filter_gets_urgent_advice_and_screens_psychiatric():
    def extract(payload):
        raise RuntimeError("Error code: 400 - {'error': {'code': 'content_filter', 'innererror': "
                           "{'content_filter_result': {'self_harm': {'filtered': True, 'severity': 'medium'}}}}}")
    session = controller_with(FakeLLM(extract)).run_session("I want to hurt myself", session_id="s")
    assert session.last_output["response"] == _FILTERED_REPLY
    assert session.findings["categories"] == ["Psychiatric & Behavioural"]


def test_route_uses_the_hybrid_controller_when_configured(monkeypatch):
    from app.api.routes import triage as route
    from app.core.config import get_settings
    monkeypatch.setattr(get_settings(), "TRIAGE_MODE", "hybrid")
    assert route.get_triage_agent() is route._hybrid_controller
    monkeypatch.setattr(get_settings(), "TRIAGE_MODE", "agent")
    assert route.get_triage_agent() is route._triage_agent


# ------------------------------------------------------------------ patient profile

PROFILE = {"age": 70, "sex_at_birth": "male", "current_medications": ["Warfarin"]}


def test_profile_is_applied_when_the_screening_is_for_the_user():
    def extract(payload):
        return {"categories": [TRAUMA], "subject": "self"} if payload["categories"] else {}
    llm = FakeLLM(extract)
    controller = controller_with(llm)
    session = controller.run_session("I fell and hit my head", context={"profile": PROFILE}, session_id="s")
    assert session.findings["age_years"] == 70 and session.pending["kind"] != "age"  # age not asked
    assert "RULE_TRAUMA_L4_01.C3" in session.findings["history_condition_ids"]
    assert "RULE_ABD_L3_01.C5" in session.findings["absent_condition_ids"]
    assert "Warfarin" in llm.present_calls[-1]["patient_note"]
    picked = default_tap(get_triage_rules_engine(), session.last_output)
    controller.run_session(picked[0], session_id="s", selected_options=picked)
    assert "patient_note" not in llm.present_calls[-1]  # mentioned once


def test_profile_is_not_applied_to_someone_else():
    def extract(payload):
        return {"categories": [FEVER], "subject": "other"} if payload["categories"] else {}
    session = controller_with(FakeLLM(extract)).run_session(
        "My son has a fever", context={"profile": PROFILE}, session_id="s")
    assert session.findings["age_years"] is None and session.pending["kind"] == "age"
    assert session.findings["history_condition_ids"] == []


def test_unclear_subject_defaults_to_the_account_owner():
    controller = controller_with(FakeLLM(opening([FEVER])))
    session = controller.run_session("fever since yesterday", context={"profile": PROFILE}, session_id="s")
    assert session.subject == "self" and session.findings["age_years"] == 70
    assert session.pending["kind"] != "age"


def test_saying_it_is_for_someone_else_later_undoes_the_profile():
    def extract(payload):
        if payload["categories"] and "fell" in payload["message"]:
            return {"categories": [TRAUMA]}
        if "my mother" in payload["message"]:
            return {"subject": "other"}
        return {}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("fell and hit the head", context={"profile": PROFILE}, session_id="s")
    assert session.findings["age_years"] == 70 and session.findings["history_condition_ids"]
    session = controller.run_session("sorry, this is for my mother", session_id="s")
    assert session.subject == "other"
    assert session.findings["age_years"] is None and session.findings["history_condition_ids"] == []
    assert "RULE_ABD_L3_01.C5" not in session.findings["absent_condition_ids"]  # pregnancy no longer ruled out
    assert session.pending["kind"] == "age"  # her real age is asked


def test_a_stated_age_wins_over_the_profile():
    def extract(payload):
        return {"categories": [TRAUMA], "subject": "self", "age_years": 45} if payload["categories"] else {}
    session = controller_with(FakeLLM(extract)).run_session(
        "I'm 45 and hurt my arm", context={"profile": PROFILE}, session_id="s")
    assert session.findings["age_years"] == 45


def test_danger_reported_after_an_earlier_all_clear_still_counts():
    # Reproduces a live failure: "conscious and responding" was tapped, then "he just fainted and is not
    # responding". The earlier answer had ruled "Unresponsive" out, so it was no longer offered to the extractor.
    def extract(payload):
        if payload["categories"] and "stomach" in payload["message"]:
            return {"categories": ["Abdominal Pain"], "age_years": 60, "subject": "other"}
        offered = {d["id"] for d in payload["danger_conditions"]} | {c["id"] for c in payload["open_conditions"]}
        if "not responding" in payload["message"] and "RULE_CRIT_L1_01.C10" in offered:
            return {"present": ["RULE_CRIT_L1_01.C10"]}
        return {}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("my dad has a stomach ache, he is 60", session_id="s")
    first = session.last_output
    assert first["question_id"] == "Q_CRIT_01"
    picked = [first["response"][0]]  # "Yes - conscious, breathing normally and responding"
    session = controller.run_session(picked[0], session_id="s", selected_options=picked)
    assert "RULE_CRIT_L1_01.C10" in session.findings["absent_condition_ids"]
    session = controller.run_session("he just fainted and is not responding to me now", session_id="s")
    assert session.triage_result["triage_level"] == 1
    assert session.last_output["response"].startswith(CALL_999)


# ------------------------------------------------------------------ note alongside a tap

def _tap_first(controller, session):
    picked = default_tap(get_triage_rules_engine(), session.last_output)
    return picked


def test_a_note_with_a_tap_can_report_danger():
    def extract(payload):
        if payload["categories"] and "ankle" in payload["message"]:
            return {"categories": [TRAUMA], "age_years": 30}
        if "bleeding" in payload["message"]:
            return {"present": ["RULE_CRIT_L1_01.C12"]}  # bleeding that will not stop
        return {}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("hurt my ankle", session_id="s")
    picked = _tap_first(controller, session)
    session = controller.run_session(picked[0], session_id="s", selected_options=picked,
                                     note="also the cut on my leg is bleeding and won't stop")
    assert session.triage_result["triage_level"] == 1
    assert session.last_output["response"].startswith(CALL_999)


def test_a_note_never_rules_anything_out():
    def extract(payload):
        if payload["categories"] and "ankle" in payload["message"]:
            return {"categories": [TRAUMA], "age_years": 30}
        return {"absent": [c["id"] for c in payload["open_conditions"] + payload["danger_conditions"]]}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("hurt my ankle", session_id="s")
    picked = _tap_first(controller, session)
    before = set(controller.engine.apply_answers(session.last_output["question_id"], picked)["absent_condition_ids"])
    session = controller.run_session(picked[0], session_id="s", selected_options=picked, note="nothing else")
    assert set(session.findings["absent_condition_ids"]) == before  # only what the tap itself ruled out


def test_something_mentioned_earlier_is_pre_selected_when_its_question_comes():
    # A typed detail that matches a later Level 2 item is never recorded from that alone (catch-up), but its
    # option is pre-selected when the question comes, so the person confirms with one tap.
    noisy = "RULE_RESP_L2_01.C6"  # Q_RESP_10: abnormal breathing sound

    def extract(payload):
        if payload["categories"] and "breath" in payload["message"]:
            return {"categories": ["Shortness of Breath & Respiratory Complaints"], "age_years": 30,
                    "facts": ["noisy breathing"]}
        if payload["message"] == "noisy breathing":  # catch-up
            return {"present": [c["id"] for c in payload["open_conditions"] if c["id"] == noisy]}
        return {}
    llm = FakeLLM(extract)
    controller = controller_with(llm)
    session = controller.run_session("I'm short of breath with noisy breathing, I'm 30", session_id="s")
    for _ in range(15):
        out = session.last_output
        if out.get("question_id") == "Q_RESP_10":
            break
        picked = [o for o in out["response"] if o.startswith("Trouble breathing")] or default_tap(
            get_triage_rules_engine(), out)
        session = controller.run_session(picked[0], session_id="s", selected_options=picked)
    assert out["question_id"] == "Q_RESP_10" and out["suggested_options"] == ["Yes"]
    assert llm.present_calls[-1]["user_mentioned"] == "noisy breathing"
    assert noisy not in session.findings["present_condition_ids"]  # still needs the person's tap
    session = controller.run_session("Yes", session_id="s", selected_options=["Yes"])
    assert noisy in session.findings["present_condition_ids"]


def test_chief_complaint_is_the_message_that_described_the_problem_not_a_greeting():
    def extract(payload):
        return {"categories": [TRAUMA]} if "ankle" in payload["message"] else {}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("hi", session_id="s")
    assert session.chief_complaint is None and session.pending["kind"] == "complaint"
    session = controller.run_session("I twisted my ankle playing futsal", session_id="s")
    assert session.chief_complaint == "I twisted my ankle playing futsal"
    session = controller.run_session("30", session_id="s")  # later messages never replace it
    assert session.chief_complaint == "I twisted my ankle playing futsal"


def test_a_typed_answer_on_its_own_answers_the_question_on_screen():
    def extract(payload):
        if payload["question"] is None and payload["categories"]:
            return {"categories": [TRAUMA], "age_years": 30}
        if payload["message"] == "nope, I'm awake and talking fine":
            return {"picked_options": [payload["question"]["options"][0]]}  # "Yes - conscious, ..."
        return {}
    controller = controller_with(FakeLLM(extract))
    session = controller.run_session("hurt my arm", session_id="s")
    assert session.last_output["question_id"] == "Q_CRIT_01"
    session = controller.run_session("nope, I'm awake and talking fine", session_id="s")
    assert "Q_CRIT_01" in session.findings["answered_question_ids"]
    assert session.last_output.get("question_id") != "Q_CRIT_01"


# ------------------------------------------------------------------ progress (step bar)

def test_progress_counts_steps_and_estimates_the_rest_without_the_llm():
    engine = get_triage_rules_engine()
    llm = FakeLLM(opening(["Palpitations"], 30))
    controller = controller_with(llm)
    session = controller.run_session("my heart is racing", session_id="s")
    first = session.progress
    assert first["step"] == 2 and not first["done"]  # step 1 is the app's opening question
    steps, typed = [first], 0
    while not session.finished:
        out = session.last_output
        if out["type"] == "selection":
            picked = default_tap(engine, out)
            session = controller.run_session(picked[0], session_id="s", selected_options=picked)
        else:  # "any other symptoms?"
            session = controller.run_session("no", session_id="s")
            typed += 1
        steps.append(session.progress)
    assert [p["step"] for p in steps[:-1]] == list(range(2, len(steps) + 1))
    # Answering "none" all the way, the first estimate is exact and never changes.
    assert {p["total"] for p in steps[:-1]} == {steps[-2]["step"]}
    assert steps[-1]["done"] and steps[-1]["step"] == steps[-1]["total"]
    # The estimate is engine-only: the only extractions are the opening message and the typed replies.
    assert len(llm.extract_calls) == 1 + typed


def test_progress_total_is_unknown_until_there_is_a_complaint():
    session = controller_with(FakeLLM()).run_session("hi", session_id="s")
    assert session.progress == {"step": 1, "total": None, "done": False}
