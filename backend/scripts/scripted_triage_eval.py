"""Holistic triage evaluation with a SCRIPTED patient (no LLM on the sender side).

Each scenario is a fixed answer sheet keyed by KB question ID. The patient taps exactly the options the app
offers (sent as selected_options, like the Flutter app); questions not on the sheet get the "none" answer.
Only the MedicTri agent uses the LLM, so token counts measure the agent alone.

Every scenario is also replayed against the rules engine with no LLM (the "oracle"). That separates:
- KB / engine accuracy: oracle level vs the expected level (authored from the KB / PDF), and
- agent accuracy: the level the agent ends with vs the expected level.

Run from backend/ (needs OPENAI_* in .env for the agent part):
    python scripts/scripted_triage_eval.py                 # all scenarios
    python scripts/scripted_triage_eval.py --oracle-only   # engine replay only, no LLM, no tokens
    python scripts/scripted_triage_eval.py --only 1,5,12 --runs 2
    python scripts/scripted_triage_eval.py --mode hybrid  # deterministic flow + LLM extractor/presenter
Results: printed summary + JSON in scripts/sim_results/scripted_<timestamp>.json
"""
import argparse
import json
import re
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

from app.agents.triage_agent import NOT_SURE, STALL_LIMIT, MedicalTriageAgent, TriageSession  # noqa: E402
from app.services.triage_controller import HybridTriageController  # noqa: E402
from app.services.triage_rules_engine import NONE_ANSWERS, get_triage_rules_engine  # noqa: E402

RESP = "Shortness of Breath & Respiratory Complaints"
TRAUMA = "Trauma & Physical Injuries"
BREATHING = "Trouble breathing"
BLEEDING = "Bleeding or injury"
LIMB, FALL, HEAD = "Arm, leg, hand or foot", "A fall", "Head, face or neck"
MILD_PAIN, MOD_PAIN, NO_PAIN = "Can still do normal activities", "The pain makes normal activities hard", "No pain (0)"

# (id, name, opening message, age, categories the complaint belongs to, answer sheet, expected level)
# Answer values: an option prefix, a list of prefixes (multi-select), or {"tap": ..., "say": ...} where "say"
# is the free-text reply if the agent asks "which one?". Expected levels are authored from the KB / PDF.
SCENARIOS = [
    # --- respiratory
    (1, "Cough with a cold", "I'm coughing, I'm 30", 30, [RESP],
     {"Q_CRIT_05": NO_PAIN, "Q_RESP_05": "Yes"}, 4),
    (2, "SAFETY stridor", "My brother is struggling to breathe, he is 40", 40, [RESP],
     {"Q_CRIT_02A": [BREATHING], "Q_CRIT_02": ["Harsh, high-pitched", "Too breathless to speak"]}, 1),
    (3, "Wheezy asthmatic, can talk", "I'm wheezing, I have asthma. 22 years old", 22, [RESP],
     {"Q_CRIT_02A": [BREATHING], "Q_CRIT_02": ["Whistling or wheezy"], "Q_CRIT_05": NO_PAIN,
      "Q_RESP_01": ["Wheezing in a known asthmatic"]}, 3),
    (4, "Child with a cold", "My 5 year old son has a cough and runny nose", 5, [RESP],
     {"Q_CRIT_05": NO_PAIN, "Q_RESP_08": "Yes", "Q_PAED_06": "No - active and comfortable"}, 3),
    # --- trauma
    # Q_LIMB_04: true answer if the agent also screens Limb Pain (walking on it, mild).
    (5, "Sprained ankle, mild pain", "sprained ankle, i am 21, male", 21, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_07": "Mild - can still use it",
      "Q_LIMB_04": "Yes"}, 5),
    (6, "Sprained ankle, pain 5/10", "sprained ankle, i am 21, male", 21, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MOD_PAIN, "Q_TRAUMA_07": "Mild - can still use it"}, 3),
    (7, "Ankle after a minor fall", "I slipped and hurt my ankle, I'm 21", 21, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB, FALL], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_03": ["Pain is the main problem"],
      "Q_TRAUMA_07": "Mild - can still use it", "Q_LIMB_04": "Yes"}, 4),
    (8, "Dislocated shoulder", "I think I dislocated my shoulder, 30 years old", 30, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_02": ["A joint looks out of place"]}, 3),
    (9, "Head knock with memory loss", "I hit my head and can't remember how", 40, [TRAUMA],
     {"Q_TRAUMA_00": [HEAD], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_04": ["Cannot remember what happened"]}, 3),
    (10, "Small cut, mild", "I cut my finger while cooking, 35", 35, [TRAUMA],
     {"Q_TRAUMA_00": ["A cut, wound"], "Q_CRIT_02A": [BLEEDING], "Q_CRIT_03": "No bleeding or only minor",
      "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_06": "None of these - only mild"}, 5),
    # --- chest pain
    (11, "SAFETY severe chest pain now", "I have chest pain, 45 years old", 45,
     ["Chest Pain & Cardiac Symptoms"], {"Q_CRIT_05": "Severe chest pain"}, 2),
    (12, "Mild chest pain for 2 days", "I have chest pain, 30 years old", 30, ["Chest Pain & Cardiac Symptoms"],
     # Level 4: onset > 6 H is Level 3 only with moderate pain (KB chest-pain product decision).
     {"Q_CRIT_05": MILD_PAIN, "Q_CP_01": "Started more than 6 hours ago", "Q_CP_05": "Persisting mild pain"}, 4),
    # --- headache
    (13, "Mild headache only", "I have a headache, 35", 35, ["Headache"],
     {"Q_CRIT_05": MILD_PAIN, "Q_HA_03": "Can still do normal activities", "Q_HA_06": "Yes"}, 5),
    (14, "SAFETY thunderclap headache", "Worst headache of my life, came on suddenly, 50 years old", 50,
     ["Headache"], {"Q_CRIT_05": "Cannot do anything", "Q_HA_01": {"tap": "Yes", "say": "Very sudden onset"}}, 2),
    # --- abdomen / GI
    (15, "Abdominal pain 6/10", "I have stomach pain, 28", 28, ["Abdominal Pain"],
     {"Q_CRIT_05": MOD_PAIN, "Q_ABD_01": "Moderate pain"}, 3),
    (16, "Elderly, mild abdominal pain", "My father has a stomach ache, he is 70", 70, ["Abdominal Pain"],
     {"Q_CRIT_05": MILD_PAIN, "Q_ABD_01": "Mild pain"}, 3),
    (17, "Vomited once", "I vomited once, 28 years old", 28, ["Vomiting, Diarrhoea & Dehydration"],
     {"Q_CRIT_05": NO_PAIN, "Q_VD_01": "No", "Q_VD_03": "Single episode"}, 5),
    (18, "Persistent vomiting", "I keep vomiting and can't keep water down, 28", 28,
     ["Vomiting, Diarrhoea & Dehydration"],
     {"Q_CRIT_05": NO_PAIN, "Q_VD_01": "No", "Q_VD_02": {"tap": "Yes", "say": "Unable to tolerate any fluids"},
      "Q_VD_03": "Persisting vomiting"}, 4),
    (19, "Black stools", "I have black stools, 28 years old", 28, ["Vomiting, Diarrhoea & Dehydration"],
     {"Q_CRIT_05": NO_PAIN, "Q_VD_01": "Coffee-ground vomit, black stools"}, 3),
    # --- fever
    (20, "Fever with headache", "I have a fever and headache, 30", 30, ["Fever"],
     {"Q_CRIT_05": MILD_PAIN, "Q_FEVER_02": {"tap": "Yes", "say": "Headache"}}, 3),
    (21, "Infant 2 months with fever", "My 2 month old baby has a fever", 0.17, ["Fever"],
     {"Q_CRIT_05": NO_PAIN, "Q_PAED_06": "No - active and comfortable"}, 2),
    # --- critical / neuro
    (22, "SAFETY ongoing seizure", "My husband is having a seizure right now, he is 40", 40,
     ["Altered Mental State, Seizures & Neurological Symptoms"], {"Q_CRIT_04": ["Ongoing seizures"]}, 2),
    (23, "SAFETY not breathing", "My dad collapsed and isn't breathing", 60, [],
     {"Q_CRIT_01": ["Not breathing", "Unresponsive"]}, 1),
    (24, "SAFETY massive vaginal bleeding", "I'm bleeding very heavily from the vagina, 32", 32, ["Gynaecology"],
     {"Q_CRIT_02A": [BLEEDING], "Q_CRIT_03": ["Very heavy vaginal bleeding"]}, 1),
    # --- allergy / burns / environment
    (25, "SAFETY tongue swelling", "My face and tongue are swelling after eating prawns, 25", 25,
     ["Allergy & Anaphylaxis"], {"Q_ALLERGY_01": {"tap": "Yes", "say": "Swelling of the face or tongue"}}, 2),
    (26, "Itchy bite, local only", "I got bitten by an insect and it's itchy, 25", 25, ["Allergy & Anaphylaxis"],
     {"Q_CRIT_05": MILD_PAIN, "Q_ALLERGY_03": "Local swelling or itchiness"}, 5),
    (27, "Small burn on the hand", "I burned my hand on a pot, 30", 30, ["Burns & Scalds"],
     {"Q_CRIT_05": MILD_PAIN, "Q_BURN_02": {"tap": "Yes", "say": "Burn involves the hand"},
      "Q_BURN_03": "Burn area less than 15%", "Q_BURN_04": "Pain is the main symptom"}, 3),
    # --- other categories
    (28, "Dizziness only", "I feel dizzy, 40 years old", 40, ["Dizziness, Giddiness & Vertigo"],
     {"Q_CRIT_05": NO_PAIN, "Q_DIZZY_03": "Dizziness symptoms only"}, 5),
    (29, "SAFETY chemical in the eye", "I splashed bleach in my eye, 30", 30, ["Eye & Vision"],
     {"Q_CRIT_05": MILD_PAIN, "Q_EYE_01": {"tap": "Yes", "say": "Chemical splash to the eye"}}, 2),
    (30, "Thoughts of self-harm", "I keep thinking about hurting myself, I'm 24", 24, ["Psychiatric & Behavioural"],
     {"Q_CRIT_05": NO_PAIN, "Q_PSY_02": "Yes"}, 3),
    (31, "Chronic back pain", "I have back pain, had it for years, 45", 45, ["Low Back Pain"],
     {"Q_CRIT_05": MILD_PAIN, "Q_LBP_03": ["Long-term"]}, 5),
    (32, "Mild palpitations", "My heart is racing a bit, 30", 30, ["Palpitations"],
     {"Q_CRIT_05": NO_PAIN, "Q_PALP_03": ["Mild symptoms"]}, 5),
    (33, "Early pregnancy bleeding", "I'm 8 weeks pregnant and spotting blood, 29", 29,
     ["Pregnancy-Related Complaints"],
     {"Q_CRIT_02A": [BLEEDING], "Q_CRIT_03": "No bleeding or only minor", "Q_CRIT_05": MILD_PAIN,
      "Q_PREG_03": "Early", "Q_PREG_04": {"tap": "Yes", "say": "Active vaginal bleeding"}}, 3),
    # --- logged-in user with a saved health profile (PROFILE_USER, read from user_information): answer sheets
    # reused from the scenarios above. "self": the profile must be used (no age question); "other": ignored.
    (34, "PROFILE self: sprained ankle", "I sprained my ankle", 21, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_07": "Mild - can still use it",
      "Q_LIMB_04": "Yes"}, 5),
    (35, "PROFILE other: dad's chest pain", "My dad has chest pain, he is 60", 60,
     ["Chest Pain & Cardiac Symptoms"],
     {"Q_CRIT_05": MILD_PAIN, "Q_CP_01": "Started more than 6 hours ago", "Q_CP_05": "Persisting mild pain"}, 4),
    (36, "PROFILE self: mild headache", "I have a headache", 21, ["Headache"],
     {"Q_CRIT_05": MILD_PAIN, "Q_HA_03": "Can still do normal activities", "Q_HA_06": "Yes"}, 5),
    (37, "PROFILE unclear: fever+headache", "Fever and headache since yesterday", 21, ["Fever"],
     {"Q_CRIT_05": MILD_PAIN, "Q_FEVER_02": {"tap": "Yes", "say": "Headache"}}, 3),
    (38, "PROFILE other: child with cold", "My 5 year old son has a cough and runny nose", 5, [RESP],
     {"Q_CRIT_05": NO_PAIN, "Q_RESP_08": "Yes", "Q_PAED_06": "No - active and comfortable"}, 3),
]

# Profile scenarios: who the screening is for. Their profile is loaded once from the database.
PROFILE_USER = "usr_43248246131c"
PROFILE_SUBJECT = {34: "self", 35: "other", 36: "self", 37: "self", 38: "other"}
SUBJECT_ASK = re.compile(r"for you|about you|is (this|it) you|yourself|someone else|for whom|logged-in user|"
                         r"untuk anda|orang lain", re.IGNORECASE)
AGE_QUESTION = re.compile(r"(how old|what is (the|your|his|her|their) age|umur)[^.?!]*\?", re.IGNORECASE)
_profile_cache = {}

# --- untested behaviours (hybrid). Sheet values may be {"type": <typed reply>, "tap": <option the oracle uses>}.
HEAD_SHEET = {"Q_TRAUMA_00": [HEAD], "Q_CRIT_05": MILD_PAIN}
SCENARIOS += [
    (39, "TYPED answers: sprained ankle", "sprained my ankle, I'm 21", 21, [TRAUMA],
     {"Q_TRAUMA_00": {"type": "it's my foot, the ankle", "tap": [LIMB]},
      "Q_CRIT_05": {"type": "just mild, maybe 2 out of 10", "tap": MILD_PAIN},
      "Q_TRAUMA_07": {"type": "it's mild, I can still walk on it", "tap": "Mild - can still use it"},
      "Q_LIMB_04": {"type": "yes", "tap": "Yes"}}, 5),
    (40, "MALAY: fever + headache", "Saya demam dan sakit kepala sejak semalam, umur 30", 30, ["Fever"],
     {"Q_CRIT_05": {"type": "sakit sikit je, dalam 2/10", "tap": MILD_PAIN},
      "Q_FEVER_02": {"tap": "Yes", "say": "Headache"}}, 3),
    (41, "MULTI-FACT opening message", "twisted my ankle playing futsal, pain is about 6/10, I'm 24, no bleeding",
     24, [TRAUMA], {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MOD_PAIN, "Q_TRAUMA_07": "Mild - can still use it"}, 3),
    (42, "NOT SURE on the first-look list", "I'm coughing, I'm 30", 30, [RESP],
     {"Q_CRIT_02A": "Not sure", "Q_CRIT_05": NO_PAIN, "Q_RESP_05": "Yes"}, 4),
    (43, "DON'T KNOW to a yes/no follow-up", "I'm coughing, I'm 30", 30, [RESP],
     {"Q_CRIT_02A": "Not sure", "Q_CRIT_05": NO_PAIN, "Q_RESP_05": "Yes"}, 4),
    (44, "SWITCH to mother mid-chat", "I fell and hit my head", 45, [TRAUMA], HEAD_SHEET, 5),
    (45, "NEW SYMPTOM mid-chat", "I have a headache, 35", 35, ["Headache", "Chest Pain & Cardiac Symptoms"],
     {"Q_CRIT_05": MILD_PAIN, "Q_HA_03": "Can still do normal activities", "Q_HA_06": "Yes",
      "Q_CP_01": "Started more than 6 hours ago", "Q_CP_05": "Persisting mild pain"}, 4),
    (46, "DANGER sign mid-chat", "my dad has a stomach ache, he is 60", 60, ["Abdominal Pain"], {}, 1),
    (47, "USER ASKS a question mid-chat", "I'm wheezing, I have asthma. 22 years old", 22, [RESP],
     {"Q_CRIT_02A": [BREATHING], "Q_CRIT_02": ["Whistling or wheezy"], "Q_CRIT_05": NO_PAIN,
      "Q_RESP_01": ["Wheezing in a known asthmatic"]}, 3),
    (48, "VAGUE complaint first", "I don't feel well", 30, ["Vomiting, Diarrhoea & Dehydration"],
     {"Q_CRIT_05": NO_PAIN, "Q_VD_01": "No", "Q_VD_02": {"tap": "Yes", "say": "Unable to tolerate any fluids"},
      "Q_VD_03": "Persisting vomiting"}, 4),
    (49, "PROFILE epilepsy + sprained ankle", "I sprained my ankle", 25, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_07": "Mild - can still use it",
      "Q_LIMB_04": "Yes"}, 5),
    (50, "PROFILE HIV + fever", "I have had a fever since yesterday", 40, ["Fever"], {"Q_CRIT_05": NO_PAIN}, 2),
    (51, "PROFILE male + stomach pain 6/10", "I have stomach pain, about 6 out of 10", 30, ["Abdominal Pain"],
     {"Q_CRIT_05": MOD_PAIN, "Q_ABD_01": "Moderate pain"}, 3),
    (52, "PROFILE adult, child patient", "My 4 year old daughter fell and hurt her arm", 4, [TRAUMA],
     {"Q_TRAUMA_00": [LIMB, FALL], "Q_CRIT_05": MILD_PAIN, "Q_TRAUMA_03": ["Pain is the main problem"],
      "Q_TRAUMA_07": "Mild - can still use it"}, 3),
    (53, "MALAY danger: not breathing", "Ayah saya tidak bernafas dan tidak sedar", 60, [], {}, 1),
    (54, "SYNCOPE, recovered", "I fainted this morning but feel okay now, 30", 30, ["Syncope"],
     # Q_SYN_03's option "Fully recovered, no deficits" does not match its KB part, so the app asks which part.
     {"Q_CRIT_05": NO_PAIN, "Q_SYN_03": {"tap": "Fully recovered, no deficits",
                                         "say": "Fully recovered, no deficits, and has not fainted before"}}, 4),
    (55, "ENT sore throat", "I've had a sore throat for 2 days, 28", 28, ["Ear, Nose & Throat (ENT)"],
     {"Q_CRIT_05": MILD_PAIN, "Q_ENT_04": "Yes"}, 5),
]
WARFARIN_MAN = {"age": 70, "sex_at_birth": "male", "current_medications": ["Warfarin"]}
# profile / subject: test profile and who the screening is really for. events: {patient turn: message sent
# instead of answering}. lang: expected reply language. oracle_present: what the events report (for the oracle).
EXTRA = {
    40: {"lang": "ms"},
    43: {"events": {4: "I don't know"}},
    44: {"profile": WARFARIN_MAN, "subject": "other",
         "events": {3: "Sorry, actually this is for my mother, she is 45"}},
    45: {"events": {3: "oh and my chest has been hurting a bit since yesterday"}},
    46: {"events": {3: "he just fainted and is not responding to me now"},
         "oracle_present": ["RULE_CRIT_L1_01.C10"]},
    47: {"events": {4: "what do you mean by that?"}},
    48: {"events": {2: "I keep vomiting and can't keep water down since this morning, I'm 30"}},
    49: {"profile": {"age": 25, "sex_at_birth": "female", "chronic_conditions": ["Epilepsy"]}, "subject": "self"},
    50: {"profile": {"age": 40, "sex_at_birth": "male", "chronic_conditions": ["HIV"]}, "subject": "self"},
    51: {"profile": {"age": 30, "sex_at_birth": "male"}, "subject": "self"},
    52: {"profile": {"age": 35, "sex_at_birth": "female", "current_medications": ["Warfarin"]}, "subject": "other"},
    53: {"lang": "ms", "oracle_present": ["RULE_CRIT_L1_01.C2", "RULE_CRIT_L1_01.C10"]},
}
MALAY = re.compile(r"\b(anda|adakah|sila|terima kasih|hubungi|segera|sakit|bantuan|baik)\b", re.IGNORECASE)


def profile_context():
    if "ctx" not in _profile_cache:
        from app.services.patient_context import load_profile
        _profile_cache["ctx"] = {"patient_id": PROFILE_USER, "profile": load_profile(PROFILE_USER)}
    return _profile_cache["ctx"]

# Hard cap on patient turns per scenario, so a looping conversation cannot overspend tokens.
MAX_TURNS = 20

AGE_ASK = re.compile(r"\b(how old|age|years old|umur)\b", re.IGNORECASE)


# ---------------------------------------------------------------------------------------- answers

def resolve(spec_items, options):
    """Map answer-sheet prefixes to the exact option texts offered (case-insensitive prefix match)."""
    chosen = []
    for item in spec_items:
        match = next((o for o in options if o.lower() == item.lower()), None) or \
            next((o for o in options if o.lower().startswith(item.lower())), None)
        if match is None:
            return None
        chosen.append(match)
    return chosen


def default_answer(q, options):
    """The 'nothing of this applies to me' answer for a question not on the sheet."""
    nones = list(q.get("none_answers", [])) if q else []
    for candidate in nones + ["No", NONE_ANSWERS[0], NONE_ANSWERS[1]]:
        if candidate in options:
            return [candidate]
    return None


_WORD = re.compile(r"[a-z0-9]+")
_STOP = {"the", "a", "an", "is", "are", "or", "and", "of", "to", "in", "on", "it", "any", "there", "you", "your",
         "do", "does", "how", "what", "with", "this", "that", "be", "for", "now", "right", "please", "person"}


def _words(text):
    return {w for w in _WORD.findall(text.lower()) if w not in _STOP and len(w) > 2}


def typed_answer(engine, sheet, bot_text):
    """Typed reply when the agent asks a sheet question in free text (best word overlap, at least 3 words)."""
    asked = _words(bot_text)
    best, score = None, 0
    for qid, spec in sheet.items():
        q = engine.questions_by_id.get(qid)
        if q is None:
            continue
        overlap = len(asked & _words(q["text"]))
        if overlap > score:
            best, score = spec, overlap
    if best is None or score < 3:
        return None
    taps, say = split_spec(best)
    return say or "; ".join(taps)


def split_spec(spec):
    if spec is None:
        return None, None
    if isinstance(spec, dict):
        tap = spec["tap"]
        return ([tap] if isinstance(tap, str) else tap), spec.get("say")
    return ([spec] if isinstance(spec, str) else list(spec)), None


# ---------------------------------------------------------------------------------------- oracle

def oracle(engine, scenario):
    """Replay the scenario on the engine alone (questions in engine order). Returns (level, questions)."""
    num, _, _, age, categories, sheet, _ = scenario
    session = TriageSession(session_id="oracle")
    session.merge_findings({"categories": categories, "age_years": age})
    extra = EXTRA.get(num, {})
    session.merge_findings({"present_condition_ids": extra.get("oracle_present", [])})
    if extra.get("subject") == "self":
        from app.services.patient_context import profile_findings
        found = profile_findings(extra["profile"])
        session.merge_findings({"history_condition_ids": found["history_condition_ids"],
                                "absent_condition_ids": found["absent_condition_ids"]})
    asked, unscripted = [], []
    for _ in range(80):
        res = engine.evaluate(**session.findings)
        if res["status"] == "classified":
            return res["triage_level"], asked, unscripted
        if not res["suggested_questions"]:
            ids = [m["condition_id"] for m in res["missing_information"] if "condition_id" in m]
            if not ids:
                return None, asked, unscripted  # nothing left to ask and nothing matched
            session.merge_findings({"absent_condition_ids": ids})  # free-text items: this person has none
            continue
        qid = res["suggested_questions"][0]["question_id"]
        q = engine.questions_by_id[qid]
        asked.append(qid)
        options = q["answers"] + [NONE_ANSWERS[0]]
        taps, say = split_spec(sheet.get(qid))
        picked = resolve(taps, options) if taps else default_answer(q, options)
        if picked is None:
            unscripted.append(qid)
            picked = [NOT_SURE]
        found = engine.apply_answers(qid, picked)
        if found is None:
            found = _interpret(q, picked, say, res)
        session.merge_findings(found)
    return None, asked, unscripted


def _interpret(q, picked, say, res):
    """What a correct agent records for an answer the KB cannot map by itself (e.g. 'Yes' + which one)."""
    tier = {m["condition_id"] for m in res["missing_information"] if "condition_id" in m}
    parts = q.get("maps_to", [])
    chosen = []
    if say:
        chosen = [p for p in parts if p["when"].lower().startswith(say.lower())]
    elif not picked[0].lower().startswith(("no", "neither", "not")):
        # Best part by shared prefix with the tapped option.
        def shared(a, b):
            n = 0
            while n < min(len(a), len(b)) and a[n].lower() == b[n].lower():
                n += 1
            return n
        best = max(parts, key=lambda p: shared(p["when"], picked[0]), default=None)
        chosen = [best] if best and shared(best["when"], picked[0]) >= 12 else []
    present = [i for p in chosen for i in p["condition_ids"]]
    absent = [i for p in parts if p not in chosen for i in p["condition_ids"] if i in tier]
    return {"present_condition_ids": present, "absent_condition_ids": absent, "answered_question_ids": [q["question_id"]]}


# ---------------------------------------------------------------------------------------- agent run

class TokenMeter:
    def __init__(self, agent):
        self.calls = self.input = self.output = 0
        original = agent._invoke_llm

        def counted(runnable, messages):
            response = original(runnable, messages)
            usage = getattr(response, "usage_metadata", None) or {}
            if not usage:
                meta = (getattr(response, "response_metadata", None) or {}).get("token_usage") or {}
                usage = {"input_tokens": meta.get("prompt_tokens", 0), "output_tokens": meta.get("completion_tokens", 0)}
            self.calls += 1
            self.input += usage.get("input_tokens", 0) or 0
            self.output += usage.get("output_tokens", 0) or 0
            return response

        agent._invoke_llm = counted

    @property
    def total(self):
        return self.input + self.output


def run_agent(engine, scenario, max_turns, quiet, mode="agent"):
    num, name, opening, age, _, sheet, _ = scenario
    agent = HybridTriageController() if mode == "hybrid" else MedicalTriageAgent()
    meter = TokenMeter(agent)
    session_id, result, transcript = None, {}, []
    pending_say = None
    unscripted, unattributed, error = [], 0, None
    message, selected = opening, None
    extra = EXTRA.get(num, {})
    subject = PROFILE_SUBJECT.get(num) or extra.get("subject")
    if extra.get("profile"):
        context = {"patient_id": "eval", "profile": extra["profile"]}
    else:
        context = profile_context() if subject else None
    events = extra.get("events", {})
    age_asked = False
    t0 = time.time()
    turns = 0
    for turns in range(1, max_turns + 1):
        transcript.append({"patient": message, "selected": selected})
        if not quiet:
            print(f"  PATIENT: {message}", flush=True)
        try:
            session = agent.run_session(message, context=context if turns == 1 else None,
                                        session_id=session_id, selected_options=selected)
        except Exception as exc:  # keep the batch going
            error = f"{type(exc).__name__}: {exc}"
            break
        session_id = session.session_id
        result = session.triage_result or {}
        out = session.last_output or {"type": "text", "response": session.messages[-1].content}
        bot = out.get("question") if out.get("type") == "selection" else out.get("response")
        transcript[-1]["bot"] = bot
        transcript[-1]["options"] = out.get("response") if out.get("type") == "selection" else None
        age_asked = age_asked or bool(AGE_QUESTION.search(str(bot)))
        if not quiet:
            print(f"  BOT    : {str(bot)[:160]}", flush=True)
            if out.get("type") == "selection":
                print(f"           options: {' | '.join(o[:28] for o in out['response'])}", flush=True)
        if result.get("status") == "classified":
            break
        if "temporarily unavailable" in str(bot):
            error = "agent error reply"
            break
        if session.stalled_turns > STALL_LIMIT or getattr(session, "finished", False):
            break  # stopped without a level: NO_RESULT

        # ---- scripted patient: next message
        selected = None
        if turns + 1 in events:
            message = events[turns + 1]
            continue
        if out.get("type") == "selection" and "For me" in out["response"]:
            selected = ["For me" if subject == "self" else "For someone else"]
            message = selected[0]
            continue
        if subject and out.get("type") != "selection" and SUBJECT_ASK.search(str(bot)):
            message = "It's for me." if subject == "self" else "It's for someone else, not me."
            continue
        if out.get("type") == "selection":
            options, qid = out["response"], out.get("question_id")
            q = engine.questions_by_id.get(qid) if qid else None
            if q is None:
                unattributed += 1
            taps, say = split_spec(sheet.get(qid)) if qid else (None, None)
            # Hybrid "which of these?" after a multi-part "Yes": the parts are options, answer with "say".
            followup = resolve([pending_say], options) if pending_say else None
            if followup:
                taps, say, picked = None, None, followup
            else:
                picked = resolve(taps, options) if taps else default_answer(q, options)
            if picked is None:
                unscripted.append(qid or "?")
                picked = [NOT_SURE]
            pending_say = say
            selected = picked
            message = "; ".join(picked)
            spec = sheet.get(qid) if qid else None
            if isinstance(spec, dict) and "type" in spec and not followup:
                message, selected = spec["type"], None  # typed instead of tapped
        elif pending_say:
            message, pending_say = pending_say, None
        elif AGE_ASK.search(str(bot)):
            message = f"{age} years old" if age >= 1 else f"{round(age * 12)} months old"
        else:
            # A free-text rephrasing of a KB question on the sheet gets that answer, typed; anything else: no.
            message = typed_answer(engine, sheet, str(bot)) or "No, none of that."

    level = result.get("triage_level") if result.get("status") == "classified" else None
    findings = getattr(locals().get("session"), "findings", {}) or {}
    profile = (context or {}).get("profile") or {}
    profile_checks = {}
    if subject:
        profile_age = profile.get("age")
        profile_checks = {
            "subject": subject,
            # Self: the profile age should be used without asking. Other: the profile must not leak in.
            "age_asked_despite_profile": subject == "self" and age_asked,
            "profile_misapplied": subject == "other" and (
                (profile_age is not None and findings.get("age_years") == profile_age)
                or bool(findings.get("history_condition_ids"))),
            "final_age": findings.get("age_years"),
        }
    bots = [str(t.get("bot") or "") for t in transcript]
    if extra.get("lang") == "ms":
        profile_checks["malay_replies"] = f"{sum(bool(MALAY.search(b)) for b in bots)}/{len(bots)}"
    if result.get("call_999"):
        profile_checks["999_first"] = "999" in bots[-1][:80]
    for counter in ("template_fallbacks", "empty_extractions"):
        if hasattr(locals().get("session"), counter):
            profile_checks[counter] = getattr(session, counter)
    return {
        **profile_checks,
        "level": level, "turns": turns, "seconds": round(time.time() - t0, 1), "error": error,
        "llm_calls": meter.calls, "input_tokens": meter.input, "output_tokens": meter.output,
        "total_tokens": meter.total, "call_999": result.get("call_999"),
        "matched_rules": result.get("matched_rule_ids"), "unscripted_questions": unscripted,
        "advised_999": any("999" in str(t.get("bot")) for t in transcript),
        "unattributed_selections": unattributed, "transcript": transcript,
    }


# ---------------------------------------------------------------------------------------- report

def summarise(rows, agent_ran):
    n = len(rows)
    out = {"scenarios": n}
    oracle_ok = sum(r["oracle_level"] == r["expected"] for r in rows)
    out["engine_oracle_accuracy"] = round(oracle_ok / n, 3)
    if not agent_ran:
        return out
    done = [r for r in rows if r["agent"]["level"] is not None]
    exact = sum(r["agent"]["level"] == r["expected"] for r in rows)
    within1 = sum(r["agent"]["level"] is not None and abs(r["agent"]["level"] - r["expected"]) <= 1 for r in rows)
    over = sum(r["agent"]["level"] is not None and r["agent"]["level"] < r["expected"] for r in rows)
    under = sum(r["agent"]["level"] is not None and r["agent"]["level"] > r["expected"] for r in rows)
    safety = [r for r in rows if r["expected"] <= 2]
    tokens = [r["agent"]["total_tokens"] for r in rows]
    turns = [r["agent"]["turns"] for r in rows]
    out.update({
        "agent_exact_accuracy": round(exact / n, 3),
        "agent_within_one_level": round(within1 / n, 3),
        "agent_matches_oracle": round(sum(r["agent"]["level"] == r["oracle_level"] for r in rows) / n, 3),
        "classified_rate": round(len(done) / n, 3),
        "over_triage": over, "under_triage": under, "no_result": n - len(done),
        "safety_recall_level_1_2": round(sum(r["agent"]["level"] is not None and r["agent"]["level"] <= 2
                                              for r in safety) / len(safety), 3) if safety else None,
        "errors": sum(bool(r["agent"]["error"]) for r in rows),
        "tokens_total": sum(tokens), "tokens_input": sum(r["agent"]["input_tokens"] for r in rows),
        "tokens_output": sum(r["agent"]["output_tokens"] for r in rows),
        "tokens_avg_per_test": round(sum(tokens) / n), "tokens_max_test": max(tokens), "tokens_min_test": min(tokens),
        "tokens_avg_per_turn": round(sum(tokens) / max(sum(turns), 1)),
        "llm_calls_avg_per_test": round(sum(r["agent"]["llm_calls"] for r in rows) / n, 1),
        "turns_avg": round(sum(turns) / n, 1), "seconds_avg": round(sum(r["agent"]["seconds"] for r in rows) / n, 1),
        "unscripted_questions": sum(len(r["agent"]["unscripted_questions"]) for r in rows),
        "unattributed_selections": sum(r["agent"]["unattributed_selections"] for r in rows),
        "confusion_expected_vs_agent": {
            f"L{e}": dict(sorted(Counter(f"L{r['agent']['level']}" if r["agent"]["level"] else "none"
                                         for r in rows if r["expected"] == e).items()))
            for e in sorted({r["expected"] for r in rows})},
    })
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated scenario ids")
    ap.add_argument("--runs", type=int, default=1)
    ap.add_argument("--max-turns", type=int, default=MAX_TURNS, help=f"capped at {MAX_TURNS} (token budget)")
    ap.add_argument("--oracle-only", action="store_true", help="engine replay only (no LLM, no tokens)")
    ap.add_argument("--mode", choices=("agent", "hybrid"), default="agent", help="chat engine under test")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    args.max_turns = min(args.max_turns, MAX_TURNS)

    engine = get_triage_rules_engine()
    chosen = {int(x) for x in args.only.split(",")} if args.only else None
    todo = [s for s in SCENARIOS if chosen is None or s[0] in chosen]
    rows = []
    out_dir = BACKEND / "scripts" / "sim_results"
    out_dir.mkdir(exist_ok=True)
    path = out_dir / f"scripted_{datetime.now():%Y%m%d_%H%M%S}.json"

    def save():
        # Written after every scenario, so an interrupted run keeps what it finished.
        summary = summarise(rows, not args.oracle_only) if rows else {}
        path.write_text(json.dumps({"summary": summary, "results": rows}, indent=2, ensure_ascii=False),
                        encoding="utf-8")
        return summary

    for scenario in todo:
        num, name, *_, expected = scenario
        o_level, o_asked, o_unscripted = oracle(engine, scenario)
        for run in range(1, (1 if args.oracle_only else args.runs) + 1):
            row = {"scenario": num, "name": name, "run": run, "expected": expected, "oracle_level": o_level,
                   "oracle_questions": len(o_asked), "oracle_unscripted": o_unscripted}
            if not args.oracle_only:
                print(f"\n=== #{num} {name} (run {run}) - expect L{expected}, oracle L{o_level}", flush=True)
                row["agent"] = run_agent(engine, scenario, args.max_turns, args.quiet, args.mode)
                row["mode"] = args.mode
                a = row["agent"]
                print(f"--> agent L{a['level']}  turns={a['turns']}  calls={a['llm_calls']}  "
                      f"tokens={a['total_tokens']} (in {a['input_tokens']} / out {a['output_tokens']})  "
                      f"{a['seconds']}s{'  ERROR ' + a['error'] if a['error'] else ''}", flush=True)
            rows.append(row)
            save()

    print("\n" + "=" * 112)
    print(f"{'#':>3} {'scenario':<32} {'exp':>4} {'eng':>4} {'agent':>5} {'turns':>5} {'calls':>5} {'tokens':>8}  verdict")
    for r in rows:
        a = r.get("agent")
        if a:
            verdict = "PASS" if a["level"] == r["expected"] else ("NO_RESULT" if a["level"] is None else
                                                                  ("OVER" if a["level"] < r["expected"] else "UNDER"))
            print(f"{r['scenario']:>3} {r['name'][:32]:<32} {r['expected']:>4} {str(r['oracle_level']):>4} "
                  f"{str(a['level']):>5} {a['turns']:>5} {a['llm_calls']:>5} {a['total_tokens']:>8}  {verdict}")
        else:
            ok = "OK" if r["oracle_level"] == r["expected"] else "MISMATCH"
            print(f"{r['scenario']:>3} {r['name'][:32]:<32} {r['expected']:>4} {str(r['oracle_level']):>4} "
                  f"{'-':>5} {r['oracle_questions']:>5} {'-':>5} {'-':>8}  {ok} {r['oracle_unscripted'] or ''}")
    summary = save()
    print("\nSUMMARY")
    for k, v in summary.items():
        print(f"  {k}: {v}")
    print(f"\nFull results: {path}")


if __name__ == "__main__":
    main()
