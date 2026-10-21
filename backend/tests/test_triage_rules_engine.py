import json
import re
import pytest
from app.agents.triage_agent import TriageSession
from app.services.triage_rules_engine import (
    CRITICAL_CATEGORY,
    PAEDIATRIC_CATEGORY,
    get_triage_rules_engine,
)
from app.tools.triage_tool import evaluate_triage_rules

CHEST = "Chest Pain & Cardiac Symptoms"
NEURO = "Altered Mental State, Seizures & Neurological Symptoms"


@pytest.fixture(scope="module")
def engine():
    return get_triage_rules_engine()


def cid(engine, rule_id, text):
    """Condition ID of the condition with exactly this text in this rule."""
    matches = [c.condition_id for c in engine.conditions.values() if c.rule_id == rule_id and c.text == text]
    assert len(matches) == 1, f"{rule_id!r} / {text!r}: {matches}"
    return matches[0]


def _ids_more_urgent_than(engine, categories, level):
    return [c.condition_id for c in engine.conditions_in(categories) if c.level < level]


# ------------------------------------------------------------------ KB structure / PDF alignment

def test_kb_levels_follow_the_pdf_column_structure(engine):
    for c in engine.conditions.values():
        if c.category == CRITICAL_CATEGORY:
            assert c.level in (1, 2, 3) and c.population == "all"
        elif c.population == "adult":
            # Adult complaints list columns are Level 2-5; Level 1 comes only from primary triage.
            assert c.level in (2, 3, 4, 5), c
        elif c.population == "paediatric":
            # Paediatric complaints list columns are Level 1-4.
            assert c.level in (1, 2, 3, 4), c


def test_every_category_has_questions_and_rules(engine):
    assert len(engine.categories) == 27
    for category in engine.categories:
        assert engine.questions_by_category[category], category
        assert engine.conditions_in([category]), category


def test_question_maps_point_at_real_conditions_of_the_same_category_and_population(engine):
    for category in engine.categories:
        for q in engine.questions_by_category[category]:
            for part in q.get("maps_to", []):
                # A checklist option may only open / rule out other items (`opens`, `covers`, any category).
                assert part["when"] and (part["condition_ids"] or part.get("covers")), (q["question_id"], part)
                for condition_id in part["condition_ids"]:
                    c = engine.conditions[condition_id]
                    assert c.category == category, (q["question_id"], condition_id)
                    if q["population"] != "all":
                        assert c.population in ("all", q["population"]), (q["question_id"], condition_id)


def test_age_derived_conditions_are_pure_age_thresholds_and_exist(engine):
    assert engine.age_derived
    for condition_id, spec in engine.age_derived.items():
        assert condition_id in engine.conditions
        assert spec["field"] == "age_years" and spec["op"] in ("<", ">")


def test_missing_information_and_questions_tell_the_agent_what_each_answer_sets(engine):
    screened = [CRITICAL_CATEGORY, "Abdominal Pain"]
    res = engine.evaluate(categories=["Abdominal Pain"], age_years=30, absent_condition_ids=_ids_more_urgent_than(engine, screened, 2))
    q = next(q for q in res["suggested_questions"] if q["question_id"] == "Q_ABD_02")
    asked = {part["when"]: part["condition_ids"] for part in q["maps_to"]}
    assert asked["Bleeding from the rectum or mouth"] == [cid(engine, "RULE_ABD_L2_01", "Bleeding PR or PO")]
    assert all(set(ids) <= {m["condition_id"] for m in res["missing_information"]} for ids in asked.values())
    # Answer options that set nothing needed at this tier are still listed, with no conditions.
    pain = next(q for q in res["suggested_questions"] if q["question_id"] == "Q_CRIT_05")
    by_when = {part["when"]: part["condition_ids"] for part in pain["maps_to"]}
    assert by_when["Cannot do anything or sleep because of the pain - the worst pain (8-10)"]
    assert by_when["The pain makes normal activities hard (4-7)"] == []
    bleeding = next(m for m in res["missing_information"] if m["condition"] == "Bleeding PR or PO")
    assert bleeding["ask_as"]


def test_age_decided_conditions_are_applied_from_the_age(engine):
    elderly = cid(engine, "RULE_ABD_L3_01", "Elderly > 65")
    screened = [CRITICAL_CATEGORY, "Abdominal Pain"]
    absent = _ids_more_urgent_than(engine, screened, 3)
    young = engine.evaluate(categories=["Abdominal Pain"], age_years=30, absent_condition_ids=absent)
    assert elderly not in {m.get("condition_id") for m in young["missing_information"]}  # never asked
    old = engine.evaluate(categories=["Abdominal Pain"], age_years=70, absent_condition_ids=absent)
    assert old["status"] == "classified" and old["triage_level"] == 3
    assert "Elderly > 65" in old["key_findings"]
    # Only within the screened categories: age alone does not pull in another complaint's rule.
    other = engine.evaluate(categories=["Headache"], age_years=70)
    assert other["at_least_level"] is None


def test_secondary_triage_pass_criteria_are_not_conditions(engine):
    texts = {c.text.lower() for c in engine.conditions.values()}
    for passed in ("walking", "talking", "not distressed", "not aggressive"):
        assert passed not in texts
    assert "walking" in [i.lower() for i in engine.kb["primary_triage_pass_criteria"]["items"]]


def test_ongoing_seizures_is_level_2_for_adults_and_level_1_for_children(engine):
    adult = cid(engine, "RULE_CRIT_L2_01", "Ongoing seizures")
    child = cid(engine, "RULE_NEURO_PAED_L1_01", "Ongoing seizures")
    assert engine.conditions[adult].level == 2
    assert engine.conditions[child].level == 1


def test_unresponsive_is_level_1_but_not_responding_to_call_is_level_2(engine):
    assert engine.conditions[cid(engine, "RULE_CRIT_L1_01", "Unresponsive")].level == 1
    assert engine.conditions[cid(engine, "RULE_CRIT_L2_01", "Not responding to call")].level == 2


def test_adult_chest_pain_has_no_level_1_rule(engine):
    levels = {c.level for c in engine.conditions.values() if c.category == CHEST and c.population == "adult"}
    assert levels == {2, 3, 4, 5}


def test_measured_criteria_are_excluded_not_screened(engine):
    for c in engine.conditions.values():
        assert not re.search(
            r"spo2|\bcrt\b|\becg\b|\bbp\b|glucose|mmol|\bsbp\b|\bhct\b|\bfbc\b|qsofa|sirs|\btemp\b|pefr",
            c.text, re.IGNORECASE), c
    excluded = {i["criterion"] for i in engine.kb["excluded_from_active_screening"]["items"] if "criterion" in i}
    assert {"SpO2 < 90% room air", "CRT > 2 secs", "ECG normal"} <= excluded


def test_every_condition_has_a_stable_id(engine):
    assert engine.conditions[cid(engine, "RULE_CP_L2_01", "Profuse sweating")].level == 2
    # The age restriction is a constraint, not a screenable condition.
    assert not any(c.rule_id == "RULE_PAED_AGE_RESTRICT_01" for c in engine.conditions.values())


# ------------------------------------------------------------------ evaluation

def test_level_1_condition_classifies_immediately_without_age(engine):
    res = engine.evaluate(categories=[], present_condition_ids=[cid(engine, "RULE_CRIT_L1_01", "Not breathing")])
    assert res["status"] == "classified"
    assert res["triage_level"] == 1
    assert res["triage_name"] == "Resuscitation"
    assert res["call_999"] is True
    assert res["matched_rule_ids"] == ["RULE_CRIT_L1_01"]


def test_lower_level_finding_waits_for_more_urgent_tiers_to_be_ruled_out(engine):
    res = engine.evaluate(
        categories=[CHEST], present_condition_ids=[cid(engine, "RULE_CP_L4_01", "Persisting mild pain")], age_years=40
    )
    assert res["status"] == "insufficient_information"
    assert res["triage_level"] is None
    assert res["at_least_level"] == 4
    # Asks about the most urgent unresolved tier first (Level 1, Critical First Look).
    assert {m["category"] for m in res["missing_information"]} == {CRITICAL_CATEGORY}
    # Only questions that can settle a Level 1 item; the breathing / bleeding lists wait behind the checklist.
    assert {q["question_id"] for q in res["suggested_questions"]} == {"Q_CRIT_01", "Q_CRIT_02A"}


def test_mild_chest_pain_classifies_once_higher_tiers_are_ruled_out(engine):
    screened = [CRITICAL_CATEGORY, CHEST]
    res = engine.evaluate(
        categories=[CHEST],
        present_condition_ids=[cid(engine, "RULE_CP_L4_01", "Persisting mild pain")],
        absent_condition_ids=_ids_more_urgent_than(engine, screened, 4),
        age_years=40,
    )
    assert res["status"] == "classified"
    assert res["triage_level"] == 4
    assert res["triage_code"] == "LEVEL_4_LESS_URGENT"
    assert res["routing_required"] is True
    assert res["source_references"][0]["rule_id"] == "RULE_CP_L4_01"
    assert res["source_references"][0]["source"] == "malaysiantriagescalenewrevised2019.pdf"


def test_higher_urgency_wins(engine):
    screened = [CRITICAL_CATEGORY, CHEST]
    res = engine.evaluate(
        categories=[CHEST],
        present_condition_ids=[
            cid(engine, "RULE_CP_L4_01", "Persisting mild pain"),
            cid(engine, "RULE_CP_L2_01", "On-going high (severe) chest pain"),
        ],
        absent_condition_ids=_ids_more_urgent_than(engine, screened, 2),
        age_years=55,
    )
    assert res["status"] == "classified"
    assert res["triage_level"] == 2
    assert res["matched_rule_ids"] == ["RULE_CP_L2_01"]


def test_age_is_required_before_classifying_below_level_1(engine):
    screened = [CRITICAL_CATEGORY, CHEST]
    res = engine.evaluate(
        categories=[CHEST],
        present_condition_ids=[cid(engine, "RULE_CP_L4_01", "Persisting mild pain")],
        absent_condition_ids=_ids_more_urgent_than(engine, screened, 4),
    )
    assert res["status"] == "insufficient_information"
    assert res["missing_information"] == [
        {"field": "age_years", "reason": "Age is required by the knowledge base before classification."}
    ]


def test_unknown_age_only_asks_population_neutral_conditions(engine):
    res = engine.evaluate(categories=[CHEST])
    assert {engine.conditions[m["condition_id"]].population for m in res["missing_information"] if "condition_id" in m} == {"all"}
    assert {"field": "age_years", "reason": "Age is required by the knowledge base before classification."} in res["missing_information"]


def test_adults_are_not_asked_paediatric_conditions_and_children_are_not_asked_adult_ones(engine):
    all_critical_absent = [c.condition_id for c in engine.conditions_in([CRITICAL_CATEGORY])]
    adult = engine.evaluate(categories=[CHEST], absent_condition_ids=all_critical_absent, age_years=40)
    assert {engine.conditions[m["condition_id"]].population for m in adult["missing_information"]} == {"adult"}
    assert {q["question_id"] for q in adult["suggested_questions"]} == {"Q_CP_01", "Q_CP_02", "Q_CP_05"}

    child = engine.evaluate(categories=[CHEST], absent_condition_ids=all_critical_absent, age_years=6)
    assert PAEDIATRIC_CATEGORY in child["screened_categories"]
    assert {engine.conditions[m["condition_id"]].population for m in child["missing_information"]} == {"paediatric"}
    assert child["at_least_level"] is None
    assert min(engine.conditions[m["condition_id"]].level for m in child["missing_information"]) == 1


def test_child_is_never_level_5_and_gets_paediatric_screening(engine):
    screened = [CRITICAL_CATEGORY, CHEST, PAEDIATRIC_CATEGORY]
    absent = _ids_more_urgent_than(engine, screened, 5)
    # An adult Level 5 item reported for a child does not count: children are screened on the paediatric list.
    res = engine.evaluate(categories=[CHEST], present_condition_ids=[cid(engine, "RULE_CP_L5_01", "No further pain")],
                          absent_condition_ids=absent, age_years=5)
    assert PAEDIATRIC_CATEGORY in res["screened_categories"]
    assert res["triage_level"] is None and res["at_least_level"] is None
    comfortable = engine.questions_by_id["Q_PAED_06"]["maps_to"][-1]["condition_ids"][0]  # active and comfortable
    assert engine.conditions[comfortable].level == 4 and engine.conditions[comfortable].population == "paediatric"
    res = engine.evaluate(categories=[CHEST], present_condition_ids=[comfortable], absent_condition_ids=absent,
                          age_years=5)
    assert res["status"] == "classified" and res["triage_level"] == 4


def test_adult_answers_never_use_the_more_urgent_paediatric_rule(engine):
    mangled_adult = cid(engine, "RULE_TRAUMA_L2_01", "Mangled limb")
    mangled_child = cid(engine, "RULE_TRAUMA_PAED_L1_01", "Mangled limb")
    res = engine.evaluate(categories=["Trauma & Physical Injuries"], age_years=30,
                          present_condition_ids=[mangled_adult, mangled_child])
    assert res["at_least_level"] == 2
    # Unknown age: neither counts yet (age is asked first), so no Level 1 from a child-only rule.
    assert engine.evaluate(categories=[], present_condition_ids=[mangled_child])["at_least_level"] is None


def test_present_wins_over_absent_and_unknown_ids_are_reported(engine):
    breathing = cid(engine, "RULE_CRIT_L1_01", "Not breathing")
    res = engine.evaluate(
        categories=["Not A Category"],
        present_condition_ids=[breathing, "FAKE.C1"],
        absent_condition_ids=[breathing],
    )
    assert res["triage_level"] == 1
    assert len(res["errors"]) == 2


def test_nothing_matched_points_to_unexplored_categories(engine):
    res = engine.evaluate(
        categories=[CHEST],
        absent_condition_ids=[c.condition_id for c in engine.conditions_in([CRITICAL_CATEGORY, CHEST])],
        age_years=30,
    )
    assert res["status"] == "insufficient_information"
    assert res["missing_information"] == []
    assert "Headache" in res["unexplored_categories"]


def test_history_conditions_are_reported_as_modifiers(engine):
    screened = [CRITICAL_CATEGORY, NEURO]
    epilepsy = cid(engine, "RULE_NEURO_L4_01", "Epilepsy history")
    res = engine.evaluate(
        categories=[NEURO],
        history_condition_ids=[epilepsy],
        absent_condition_ids=_ids_more_urgent_than(engine, screened, 4),
        age_years=25,
    )
    assert res["triage_level"] == 4
    assert res["relevant_history_modifiers"] == ["Epilepsy history"]


def test_tool_returns_engine_json(engine):
    res = json.loads(evaluate_triage_rules.invoke({
        "categories": [], "present_condition_ids": [cid(engine, "RULE_CRIT_L1_01", "Cardiac arrest")],
    }))
    assert res["status"] == "classified" and res["triage_level"] == 1


def test_session_accumulates_and_corrects_findings():
    session = TriageSession(session_id="s1")
    session.merge_findings({"categories": [CHEST], "present_condition_ids": ["RULE_CP_L2_01.C2"], "age_years": 50})
    merged = session.merge_findings({"absent_condition_ids": ["RULE_CP_L2_01.C2", "RULE_CRIT_L1_01.C1"]})
    assert merged["categories"] == [CHEST]
    assert merged["age_years"] == 50
    assert merged["present_condition_ids"] == []
    assert set(merged["absent_condition_ids"]) == {"RULE_CP_L2_01.C2", "RULE_CRIT_L1_01.C1"}


# ------------------------------------------------------------------ chest pain: ongoing high vs mild
def _chest_screened(engine):
    return [CRITICAL_CATEGORY, CHEST]


def test_ongoing_high_chest_pain_is_level_2(engine):
    res = engine.evaluate(
        categories=[CHEST],
        present_condition_ids=[cid(engine, "RULE_CP_L2_01", "On-going high (severe) chest pain")],
        absent_condition_ids=_ids_more_urgent_than(engine, _chest_screened(engine), 2),
        age_years=50,
    )
    assert res["status"] == "classified" and res["triage_level"] == 2


def test_ongoing_mild_chest_pain_is_level_4_not_2(engine):
    res = engine.evaluate(
        categories=[CHEST],
        present_condition_ids=[cid(engine, "RULE_CP_L4_01", "Persisting mild pain")],
        absent_condition_ids=[
            c.condition_id for c in engine.conditions_in(_chest_screened(engine))
            if c.level < 4
        ],
        age_years=50,
    )
    assert res["status"] == "classified" and res["triage_level"] == 4


def test_chest_pain_severity_is_asked_before_level_2_is_ruled_out(engine):
    crit_absent = [c.condition_id for c in engine.conditions_in([CRITICAL_CATEGORY])]
    res = engine.evaluate(categories=[CHEST], absent_condition_ids=crit_absent, age_years=50)
    assert res["status"] == "insufficient_information"
    texts = {m["condition"] for m in res["missing_information"]}
    assert "On-going high (severe) chest pain" in texts
    assert "Q_CP_05" in {q["question_id"] for q in res["suggested_questions"]}


# ------------------------------------------------------------------ level-native advice + extra 999 advice
def test_ongoing_seizure_at_level_2_gets_level_advice_and_999(engine):
    seizure = cid(engine, "RULE_CRIT_L2_01", "Ongoing seizures")
    res = engine.evaluate(
        categories=[],
        present_condition_ids=[seizure],
        absent_condition_ids=_ids_more_urgent_than(engine, [CRITICAL_CATEGORY], 2),
        age_years=30,
    )
    assert res["status"] == "classified" and res["triage_level"] == 2
    assert res["call_999"] is True
    assert "Emergency Department immediately" in res["level_advice"]
    assert any("999" in a and "seizure" in a for a in res["emergency_advice"])


def test_999_advice_is_given_before_screening_finishes(engine):
    seizure = cid(engine, "RULE_CRIT_L2_01", "Ongoing seizures")
    res = engine.evaluate(categories=[], present_condition_ids=[seizure], age_years=30)
    assert res["status"] == "insufficient_information"
    assert res["call_999"] is True
    assert res["at_least_level"] == 2
    assert "Emergency Department" in res["interim_advice"]


def test_level_2_without_special_advice_does_not_say_999(engine):
    sweating = cid(engine, "RULE_CP_L2_01", "Profuse sweating")
    res = engine.evaluate(
        categories=[CHEST], present_condition_ids=[sweating],
        absent_condition_ids=_ids_more_urgent_than(engine, _chest_screened(engine), 2), age_years=60,
    )
    assert res["triage_level"] == 2
    assert res["call_999"] is False and res["emergency_advice"] == []
    assert "Emergency Department" in res["level_advice"]


def test_level_1_advice_says_call_999(engine):
    res = engine.evaluate(categories=[], present_condition_ids=[cid(engine, "RULE_CRIT_L1_01", "Not breathing")])
    assert res["call_999"] is True
    assert "999" in res["level_advice"]


def test_every_level_has_advice_and_every_advice_condition_exists(engine):
    assert set(engine.level_advice) == {1, 2, 3, 4, 5}
    texts = {c.text for c in engine.conditions.values()}
    assert set(engine.emergency_advice_by_text) <= texts


def test_tool_output_includes_advice(engine):
    seizure = cid(engine, "RULE_CRIT_L2_01", "Ongoing seizures")
    res = json.loads(evaluate_triage_rules.invoke({
        "categories": [], "present_condition_ids": [seizure], "age_years": 30,
        "absent_condition_ids": _ids_more_urgent_than(engine, [CRITICAL_CATEGORY], 2),
    }))
    assert res["call_999"] is True and res["level_advice"] and res["emergency_advice"]


# ------------------------------------------------------------------ only verbally answerable criteria are screened
def test_clinician_only_conditions_are_not_screened(engine):
    texts = {c.text for c in engine.conditions.values()}
    for clinician_only in (
        "Airway unprotected", "Requires assisted breathing", "Abnormal posturing", "Appears unwell", "Distracting pain",
        "Septic / Toxic", "Toxic appearance", "Compartment syndrome", "Need for sedation", "Need for restraint",
        "Inter-facility transfers", "Referred cases", "Airway threatened",
    ):
        assert clinician_only not in texts, clinician_only
    audited = {i["criterion"] for i in engine.kb["excluded_from_active_screening"]["items"] if "criterion" in i}
    for clinician_only in ("Airway unprotected", "Abnormal posturing", "Appears unwell", "Distracting pain", "Need for restraint"):
        assert clinician_only in audited, clinician_only


# ------------------------------------------------------------------ added PDF categories
@pytest.mark.parametrize("category,rule_id,text,level", [
    ("Fever", "RULE_FEVER_L2_01", "Altered mental state", 2),
    ("Dizziness, Giddiness & Vertigo", "RULE_DIZZY_L2_01", "Neurological deficit", 2),
    ("Eye & Vision", "RULE_EYE_L2_01", "Chemical exposure eye", 2),
    ("Syncope", "RULE_SYN_L2_01", "Skin purpura or rashes", 2),
    ("Palpitations", "RULE_PALP_L3_01", "Associated syncope, chest pain", 3),
    ("Low Back Pain", "RULE_LBP_L3_01", "Loss of urinary / bowel control", 3),
    ("Gynaecology", "RULE_GYN_L2_01", "Massive vaginal bleeding", 2),
    ("Psychiatric & Behavioural", "RULE_PSY_L3_01", "Risk of self-harm", 3),
    ("Genito-urinary & Scrotal Complaints", "RULE_GU_PAED_L1_01", "Severe scrotal pain, non traumatic (< 6 Hours)", 1),
])
def test_added_categories_follow_the_pdf(engine, category, rule_id, text, level):
    condition = engine.conditions[cid(engine, rule_id, text)]
    assert condition.category == category and condition.level == level


def test_added_category_classifies_end_to_end(engine):
    screened = [CRITICAL_CATEGORY, "Dizziness, Giddiness & Vertigo"]
    res = engine.evaluate(
        categories=["Dizziness, Giddiness & Vertigo"],
        present_condition_ids=[cid(engine, "RULE_DIZZY_L5_01", "Symptoms only")],
        absent_condition_ids=_ids_more_urgent_than(engine, screened, 5),
        age_years=33,
    )
    assert res["status"] == "classified" and res["triage_level"] == 5
