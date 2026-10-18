"""End-to-end screening scenarios driven through the KB questions, as a patient tapping options would.

Guards against over-triage from ambiguous answers (e.g. a cough read as "abnormal breathing sounds")
without weakening real Level 1 findings. No LLM involved: answers go through `apply_answers`.
"""
import json
import pytest
from app.agents.triage_agent import TriageSession, parse_structured_reply, selection_findings
from app.services.triage_rules_engine import CRITICAL_CATEGORY, get_triage_rules_engine

RESP = "Shortness of Breath & Respiratory Complaints"
CHECKLIST = "Q_CRIT_02A"
BREATHING = ("Trouble breathing - breathless, wheezing or noisy breathing "
             "(a cough or blocked nose alone does not count)")
BLEEDING = ("Bleeding or injury - including vomiting or coughing up blood, heavy periods, nosebleeds or a known "
            "bleeding disorder")
SKIN = "Pale or bluish skin with cold hands and feet"
STRIDOR_LIKE = ("Harsh, high-pitched, gurgling or snoring noise with every breath "
                "(not just a cough, phlegm or blocked nose)")


@pytest.fixture(scope="module")
def engine():
    return get_triage_rules_engine()


def _default_answer(q):
    """What a person with none of the listed problems would tap."""
    if q.get("none_answers"):
        return q["none_answers"][0]
    if "No" in q["answers"]:
        return "No"
    if "None of these" in q["answers"] or len(q["answers"]) > 2:
        return "None of these"  # the app adds it to long lists
    raise AssertionError(f"scenario needs an explicit answer for {q['question_id']}: {q['answers']}")


def screen(engine, categories, age, answers):
    """Answer the engine's questions (most urgent tier first) until it classifies.

    Returns (result, question_ids asked in order).
    """
    session = TriageSession(session_id="scenario")
    session.merge_findings({"categories": categories, "age_years": age})
    asked = []
    for _ in range(60):
        res = engine.evaluate(**session.findings)
        if res["status"] == "classified":
            return res, asked
        assert res["suggested_questions"] or res["missing_information"], res
        if not res["suggested_questions"]:
            # Conditions with no KB question: the agent asks in free text; this person has none of them.
            session.merge_findings({"absent_condition_ids": [
                m["condition_id"] for m in res["missing_information"] if "condition_id" in m]})
            continue
        q = engine.questions_by_id[res["suggested_questions"][0]["question_id"]]
        asked.append(q["question_id"])
        answer = answers.get(q["question_id"]) or _default_answer(q)
        picked = answer if isinstance(answer, list) else [answer]
        found = engine.apply_answers(q["question_id"], picked)
        if found is None:
            # Not mappable without interpretation: a "No - ..." answer rules out what the question still asks.
            assert picked[0].startswith("No"), (q["question_id"], answer)
            tier = {m["condition_id"] for m in res["missing_information"] if "condition_id" in m}
            found = {"answered_question_ids": [q["question_id"]],
                     "absent_condition_ids": [i for p in q["maps_to"] for i in p["condition_ids"] if i in tier]}
        session.merge_findings(found)
    raise AssertionError("screening did not finish")


# ------------------------------------------------------------------ scenarios

def test_adult_cough_with_comfortable_breathing_is_level_4_in_few_questions(engine):
    res, asked = screen(engine, [RESP], 30, {"Q_RESP_05": "Yes"})
    assert res["triage_level"] == 4
    assert res["call_999"] is False
    # "No trouble breathing" settles the breathing lists of the respiratory category too.
    assert "Q_RESP_01" not in asked and "Q_RESP_10" not in asked and "Q_RESP_11" not in asked
    assert len(asked) <= 7, asked


def test_reported_repro_cough_and_conscious_never_reaches_level_1_or_2(engine):
    res, _ = screen(engine, [RESP], 25, {CHECKLIST: "None of these", "Q_RESP_05": "Yes"})
    assert res["triage_level"] >= 3


def test_stridor_like_noise_is_still_level_1(engine):
    res, _ = screen(engine, [RESP], 40, {CHECKLIST: [BREATHING], "Q_CRIT_02": STRIDOR_LIKE})
    assert res["triage_level"] == 1 and res["call_999"] is True


def test_wheezy_asthmatic_who_can_talk_is_level_3(engine):
    res, _ = screen(engine, [RESP], 22, {
        CHECKLIST: [BREATHING],
        "Q_CRIT_02": "Whistling or wheezy breathing, but can still talk normally",
        "Q_RESP_01": "Wheezing in a known asthmatic",
    })
    assert res["triage_level"] == 3


def test_child_with_a_cold_is_not_level_1(engine):
    res, _ = screen(engine, [RESP], 5, {"Q_RESP_08": "Yes", "Q_PAED_06": "No - active and comfortable"})
    assert res["triage_level"] == 3


def test_ticking_several_problems_opens_each_list(engine):
    res, asked = screen(engine, [RESP], 50, {
        CHECKLIST: [BREATHING, BLEEDING],
        "Q_CRIT_02": ["Difficulty breathing, but can speak in sentences",
                      "Agitated or anxious because of breathing difficulty"],
        "Q_CRIT_03": ["Actively vomiting or coughing up blood"],
    })
    assert {"Q_CRIT_02", "Q_CRIT_03"} <= set(asked)
    assert res["triage_level"] == 2
    assert set(res["key_findings"]) >= {"Difficulty to breathe", "Agitation, anxious (breathing difficulty)",
                                        "Active vomiting or coughing of blood"}


# ------------------------------------------------------------------ trauma: asked per injury area (PDF rows)
TRAUMA = "Trauma & Physical Injuries"
LIMB = "Arm, leg, hand or foot"
OTHER_AREA_QUESTIONS = {"Q_TRAUMA_01", "Q_TRAUMA_03", "Q_TRAUMA_04", "Q_TRAUMA_05", "Q_TRAUMA_06",
                        "Q_TRAUMA_11", "Q_TRAUMA_12", "Q_TRAUMA_14"}


def test_sprained_ankle_is_level_5_without_other_injury_areas(engine):
    res, asked = screen(engine, [TRAUMA], 21, {
        "Q_TRAUMA_00": [LIMB],
        "Q_TRAUMA_07": "Mild - can still use it or put weight on it, and it does not look broken",
    })
    assert res["triage_level"] == 5
    # No pregnancy, blood thinners, head, chest, wound or fall questions for an ankle.
    assert not OTHER_AREA_QUESTIONS & set(asked), asked
    assert len(asked) <= 7, asked


@pytest.mark.parametrize("fall_answer,level", [
    (["Pain is the main problem"], 4),
    (["Walking normally with only mild symptoms"], 5),
])
def test_sprained_ankle_after_a_minor_fall_is_level_4_or_5(engine, fall_answer, level):
    res, asked = screen(engine, [TRAUMA], 21, {
        "Q_TRAUMA_00": [LIMB, "A fall"],
        "Q_TRAUMA_03": fall_answer,
        "Q_TRAUMA_07": "Mild - can still use it or put weight on it, and it does not look broken",
    })
    assert res["triage_level"] == level
    assert "Q_TRAUMA_03" in asked and not (OTHER_AREA_QUESTIONS - {"Q_TRAUMA_03"}) & set(asked), asked


def test_ankle_with_a_possible_small_fracture_is_level_4(engine):
    res, _ = screen(engine, [TRAUMA], 21, {
        "Q_TRAUMA_00": [LIMB],
        "Q_TRAUMA_07": "Painful and might be a small broken bone (e.g. a finger or toe), but can still move "
                       "the fingers / toes",
    })
    assert res["triage_level"] == 4


def test_dislocated_joint_is_level_3(engine):
    res, _ = screen(engine, [TRAUMA], 21, {
        "Q_TRAUMA_00": [LIMB], "Q_TRAUMA_02": ["A joint looks out of place (dislocated)"]})
    assert res["triage_level"] == 3


def test_chest_injury_still_asks_pregnancy_and_uses_age(engine):
    res, asked = screen(engine, [TRAUMA], 30, {"Q_TRAUMA_00": ["Chest, abdomen or pelvis (hips)"],
                                               "Q_TRAUMA_12": "Yes"})
    assert "Q_TRAUMA_12" in asked and res["triage_level"] == 4
    # Elderly is decided from the age, not asked.
    old, _ = screen(engine, [TRAUMA], 70, {"Q_TRAUMA_00": ["Chest, abdomen or pelvis (hips)"]})
    assert old["triage_level"] == 4 and "Elderly" in old["key_findings"]


def test_head_injury_with_memory_loss_is_level_3(engine):
    res, asked = screen(engine, [TRAUMA], 40, {
        "Q_TRAUMA_00": ["Head, face or neck"], "Q_TRAUMA_04": ["Cannot remember what happened (memory loss)"]})
    assert res["triage_level"] == 3 and "Q_TRAUMA_02" not in asked


def test_mild_head_injury_reaches_an_end_state(engine):
    res, _ = screen(engine, [TRAUMA], 40, {"Q_TRAUMA_00": ["Head, face or neck"],
                                           "Q_TRAUMA_04": "None of these - only mild symptoms"})
    assert res["triage_level"] == 5


# ------------------------------------------------------------------ checklist and answer mapping

def test_checklist_is_asked_before_the_detailed_lists(engine):
    res = engine.evaluate(categories=[RESP], age_years=30)
    ids = [q["question_id"] for q in res["suggested_questions"]]
    assert CHECKLIST in ids
    assert "Q_CRIT_02" not in ids and "Q_CRIT_03" not in ids
    checklist = next(q for q in res["suggested_questions"] if q["question_id"] == CHECKLIST)
    assert checklist["multi_select"] is True
    assert any(p.get("covers") for p in checklist["maps_to"])

    after = engine.evaluate(categories=[RESP], age_years=30, answered_question_ids=[CHECKLIST])
    assert "Q_CRIT_02" in [q["question_id"] for q in after["suggested_questions"]]


def test_unticked_checklist_options_rule_out_what_they_cover(engine):
    found = engine.apply_answers(CHECKLIST, [SKIN])
    assert found["present_condition_ids"] == ["RULE_CRIT_L1_01.C9"]
    bleeding = {i for p in engine.questions_by_id["Q_CRIT_03"]["maps_to"] for i in p["condition_ids"]}
    assert bleeding <= set(found["absent_condition_ids"])
    assert {"RULE_CRIT_L1_01.C5", "RULE_RESP_L2_01.C6", "RULE_RESP_PAED_L1_01.C1"} <= set(found["absent_condition_ids"])

    breathing_only = engine.apply_answers(CHECKLIST, [BREATHING])
    assert "RULE_CRIT_L1_01.C5" not in breathing_only["absent_condition_ids"]  # still to be asked
    assert "RULE_CRIT_L1_01.C9" in breathing_only["absent_condition_ids"]


def test_none_of_these_rules_out_the_whole_checklist(engine):
    found = engine.apply_answers(CHECKLIST, ["None of these"])
    assert found["present_condition_ids"] == []
    assert {"RULE_CRIT_L1_01.C5", "RULE_CRIT_L1_01.C9", "RULE_CRIT_L1_01.C11"} <= set(found["absent_condition_ids"])


def test_picking_an_option_sets_it_and_rules_out_the_others(engine):
    found = engine.apply_answer("Q_CRIT_02", "Difficulty breathing, but can speak in sentences")
    assert found["present_condition_ids"] == ["RULE_CRIT_L2_01.C5"]
    assert "RULE_CRIT_L1_01.C5" in found["absent_condition_ids"]


def test_ambiguous_contradictory_or_unknown_answers_are_left_to_the_agent(engine):
    assert engine.apply_answer("Q_RESP_04", "Yes") is None  # multi-part yes: which one?
    assert engine.apply_answer("Q_CRIT_02", "Something else") is None
    assert engine.apply_answer("NOPE", "Yes") is None
    assert engine.apply_answers(CHECKLIST, [SKIN, "None of these"]) is None
    assert engine.apply_answers("Q_CRIT_05", ["Mild pain (1-3)", "No pain (0)"]) is None  # single choice


def test_kb_question_structure(engine):
    for q in engine.questions_by_id.values():
        for a in q.get("none_answers", []):
            assert a in q["answers"], (q["question_id"], a)
        if q.get("multi_select"):
            # Multi-select answers are recorded without interpretation, so every option must map.
            for a in q["answers"]:
                assert engine.apply_answer(q["question_id"], a) is not None, (q["question_id"], a)
        for part in q.get("maps_to", []):
            for i in part.get("covers", []):
                assert i in engine.conditions, (q["question_id"], i)
            for gated in part.get("opens", []):
                assert gated in engine.questions_by_id


# ------------------------------------------------------------------ compound condition (onset > 6 H AND moderate)
CHEST = "Chest Pain & Cardiac Symptoms"
OVER_6H = "Started more than 6 hours ago"


@pytest.mark.parametrize("pain_now,level", [
    ("Ongoing and moderate (4-7)", 3),   # both halves -> 'onset > 6 H with moderate pain'
    ("Persisting mild pain (1-3)", 4),
])
def test_chest_pain_onset_and_severity_combine_without_the_llm(engine, pain_now, level):
    assert engine.apply_answer("Q_CP_01", OVER_6H) is not None  # half of a compound: still mappable
    res, _ = screen(engine, [CHEST], 30, {"Q_CRIT_05": "Mild pain (1-3)", "Q_CP_01": OVER_6H, "Q_CP_05": pain_now})
    assert res["triage_level"] == level


def test_compound_condition_needs_both_halves(engine):
    compound = "RULE_CP_L3_01.C1"
    assert engine.compound[compound] == {"Q_CP_01", "Q_CP_05"}
    found = engine.apply_answer("Q_CP_01", OVER_6H)
    assert compound not in found["present_condition_ids"] + found["absent_condition_ids"]
    only_one = engine.evaluate(categories=[CHEST], age_years=30, answered_question_ids=["Q_CP_01"],
                               absent_condition_ids=found["absent_condition_ids"])
    assert compound not in only_one["key_findings"]


# ------------------------------------------------------------------ agent: provider content filter

def test_filtered_message_gets_urgent_advice_and_the_session_keeps_working():
    from langchain_core.messages import AIMessage, HumanMessage
    from app.agents.triage_agent import _FILTERED_REPLY, MedicalTriageAgent

    class FilteringLLM:
        def __init__(self):
            self.calls = 0

        def invoke(self, messages):
            self.calls += 1
            if any(isinstance(m, HumanMessage) and "hurt myself" in m.content for m in messages):
                raise RuntimeError("Error code: 400 - {'error': {'code': 'content_filter', 'innererror': "
                                   "{'content_filter_result': {'self_harm': {'filtered': True, 'severity': 'medium'}}}}}")
            return AIMessage(content='{"type":"text","response":"How old are you?"}')

    agent = MedicalTriageAgent()
    agent._agent_runnable = FilteringLLM()
    session = agent.run_session("I want to hurt myself", session_id="filtered")
    assert session.last_output["response"] == _FILTERED_REPLY and "999" in _FILTERED_REPLY
    assert not any("hurt myself" in str(m.content) for m in session.messages)  # not resent next turn
    assert session.findings["categories"] == ["Psychiatric & Behavioural"]  # screened; user confirms items
    session = agent.run_session("I'm 24", session_id="filtered")
    assert session.last_output["response"] == "How old are you?"


# ------------------------------------------------------------------ agent: stall guard

def test_agent_is_told_to_stop_after_repeated_turns_with_nothing_left_to_ask():
    from langchain_core.messages import AIMessage, SystemMessage
    from app.agents.triage_agent import _STALL_NOTE, STALL_LIMIT, MedicalTriageAgent

    class FakeLLM:
        def invoke(self, messages):
            return AIMessage(content='{"type":"text","response":"Any other symptoms?"}')

    agent = MedicalTriageAgent()
    agent._agent_runnable = FakeLLM()
    session = agent.get_session("stall")
    session.triage_result = {"status": "insufficient_information", "missing_information": [],
                             "unexplored_categories": ["Headache"]}
    for _ in range(STALL_LIMIT):
        agent.run_session("No", session_id="stall")
    assert not any(isinstance(m, SystemMessage) and m.content == _STALL_NOTE for m in session.messages)
    agent.run_session("No", session_id="stall")
    assert any(isinstance(m, SystemMessage) and m.content == _STALL_NOTE for m in session.messages)


# ------------------------------------------------------------------ agent: selections

def test_tapped_options_are_recorded_from_the_kb(engine):
    res = engine.evaluate(categories=[RESP], age_years=30)
    reply = parse_structured_reply(json.dumps(
        {"type": "selection", "question": "Any of these?", "response": [BREATHING, "None of these"]}), res)
    assert reply["question_id"] == CHECKLIST
    # The full KB list is always offered (unticked options count as absent), plus "Not sure".
    assert reply["response"] == engine.questions_by_id[CHECKLIST]["answers"] + ["Not sure"]
    assert reply["multi_select"] is True
    assert reply["exclusive_options"] == ["None of these", "Not sure"]

    found = selection_findings(reply, "x", [BREATHING, SKIN])
    assert found["present_condition_ids"] == ["RULE_CRIT_L1_01.C9"]
    assert "RULE_CRIT_L1_01.C11" in found["absent_condition_ids"]
    assert selection_findings(reply, "None of these")["present_condition_ids"] == []
    assert selection_findings(reply, "Not sure") is None
    assert selection_findings(reply, "my chest feels tight") is None


def test_question_text_is_added_when_the_llm_sends_only_an_acknowledgement(engine):
    res = engine.evaluate(categories=[RESP], age_years=30)
    reply = parse_structured_reply(json.dumps(
        {"type": "selection", "question": "Thanks - you're coughing.", "response": ["None of these"]}), res)
    assert reply["question"].startswith("Thanks - you're coughing. ")
    kb_text = engine.questions_by_id[reply["question_id"]]["text"]
    assert reply["question"].endswith(kb_text)
    # Already there (in any case): not repeated.
    ack = "Thanks - " + kb_text[0].lower() + kb_text[1:]
    again = parse_structured_reply(json.dumps({"type": "selection", "question": ack, "response": ["None of these"]}), res)
    assert again["question"] == ack


def test_swollen_ankle_is_not_generalized_oedema(engine):
    found = engine.apply_answers("Q_LIMB_02", ["None of these"])
    assert "RULE_LIMB_L3_01.C1" in found["absent_condition_ids"]
    assert "all over the body" in engine.questions_by_id["Q_LIMB_02"]["answers"][0]


def test_long_option_lists_get_none_of_these(engine):
    absent = [c.condition_id for c in engine.conditions_in([CRITICAL_CATEGORY]) if c.level == 1]
    res = engine.evaluate(categories=[RESP], age_years=30, absent_condition_ids=absent,
                          answered_question_ids=[CHECKLIST])
    q = next(q for q in res["suggested_questions"] if q["question_id"] == "Q_CRIT_04")
    reply = parse_structured_reply(
        json.dumps({"type": "selection", "question": "Which?", "response": q["answers"][:2]}), res)
    assert reply["response"][-2:] == ["Alert, walking and talking normally", "Not sure"]
    assert len(reply["response"]) == len(q["answers"]) + 1
