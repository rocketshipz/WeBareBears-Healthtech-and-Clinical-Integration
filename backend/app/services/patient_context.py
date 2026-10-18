"""The logged-in user's health profile (user_information) as triage context.

- `load_profile`: the compact profile, queried before a triage session starts. Never raises.
- `profile_findings`: what the profile settles in the knowledge base, decided by code (used by the hybrid mode).
  The profile describes the logged-in user, so it applies only when the screening is for them.

Only what the profile LISTS is used: a condition or medicine missing from it is never taken as "no", because
profiles are often incomplete. Only standing history items are set (KB conditions that name a history, a
medicine or a state, per `patient_context.rule`: history only where the rule itself uses it). Compound items
that also need a current symptom ("Wheezing, known asthmatic", "No warning signs, immunocompromised") are not.
"""
import logging
import re
from typing import Any, Dict, List, Optional

from app.services.patient_service import PatientService
from app.services.triage_rules_engine import get_triage_rules_engine

logger = logging.getLogger(__name__)

PREGNANCY_CATEGORY = "Pregnancy-Related Complaints"

# Clinical mapping (code, not KB): profile wording -> the KB history conditions it settles.
# `conditions` / `medications`: regexes matched (case-insensitive, word start) against profile item names.
HISTORY_GROUPS: List[Dict[str, Any]] = [
    {
        "label": "takes a blood thinner",
        "medications": [r"warfarin", r"apixaban", r"rivaroxaban", r"dabigatran", r"edoxaban", r"heparin",
                        r"enoxaparin", r"clexane", r"eliquis", r"xarelto", r"pradaxa", r"blood thinner",
                        r"anticoagula"],
        "conditions": [r"anticoagula"],
        "condition_ids": ["RULE_TRAUMA_L4_01.C3", "RULE_NEURO_L3_01.C6", "RULE_NEURO_PAED_L2_01.C5",
                          "RULE_VD_L3_01.C5", "RULE_VD_PAED_L2_01.C5"],
    },
    {
        "label": "has a weakened immune system",
        "conditions": [r"hiv\b", r"aids\b", r"immunocompromis", r"immunodeficien", r"immunosuppress",
                       r"transplant", r"leuka?emia", r"lymphoma", r"chemotherapy"],
        "medications": [r"prednis", r"dexamethasone", r"methotrexate", r"tacrolimus", r"ciclosporin",
                        r"cyclosporin", r"azathioprine", r"mycophenol", r"immunosuppress", r"chemotherapy"],
        "condition_ids": ["RULE_FEVER_L2_01.C4", "RULE_FEVER_PAED_L1_01.C5", "RULE_FU_L3_01.C2",
                          "RULE_FU_PAED_L2_01.C2", "RULE_LETH_L3_01.C2"],
    },
    {
        "label": "is on chemotherapy",
        "conditions": [r"chemo"],
        "medications": [r"chemo"],
        "condition_ids": ["RULE_FU_L3_01.C3", "RULE_FU_PAED_L2_01.C3"],
    },
    {
        "label": "has a bleeding disorder",
        "conditions": [r"ha?emophilia", r"von willebrand", r"bleeding disorder", r"thrombocytopeni", r"itp\b"],
        "medications": [],
        "condition_ids": ["RULE_CRIT_L3_01.C12", "RULE_TRAUMA_PAED_L3_01.C2"],
    },
    {
        "label": "has epilepsy",
        "conditions": [r"epilep", r"seizure disorder"],
        "medications": [],
        "condition_ids": ["RULE_NEURO_L4_01.C4", "RULE_NEURO_PAED_L3_01.C4"],
    },
    {
        "label": "has a mental health condition",
        "conditions": [r"schizophren", r"bipolar", r"depress", r"psychos", r"psychiatric", r"mental illness"],
        "medications": [],
        "condition_ids": ["RULE_NEURO_L4_01.C2"],
    },
    {
        "label": "has a history of drug use",
        "conditions": [r"substance use", r"drug (use|abuse|addiction|dependence)", r"opioid use"],
        "medications": [],
        "condition_ids": ["RULE_NEURO_L4_01.C3"],
    },
    {
        "label": "has a neurological disorder",
        "conditions": [r"cerebral palsy", r"epilep", r"hydroceph", r"neurological disorder"],
        "medications": [],
        "condition_ids": ["RULE_NEURO_PAED_L3_01.C2"],
    },
]

# Pregnancy items, ruled out when the profile says male. ("Not pregnancy related symptoms", the pregnancy
# category's routine end state, is left alone.)
_PREGNANCY_EXTRA = ["RULE_ABD_L3_01.C5", "RULE_TRAUMA_L4_01.C4", "RULE_DENGUE_L4_01.C2"]


def load_profile(patient_id: Optional[str], service: Optional[PatientService] = None) -> Dict[str, Any]:
    """Compact user_information profile for triage, or {} (no id, no record, or the database failed)."""
    if not patient_id:
        return {}
    try:
        return (service or PatientService()).get_agent_context(patient_id)
    except Exception as e:
        logger.warning(f"[patient_context] Could not load the profile for {patient_id}: {e}")
        return {}


def pregnancy_condition_ids() -> List[str]:
    engine = get_triage_rules_engine()
    in_category = [c.condition_id for c in engine.conditions_in([PREGNANCY_CATEGORY])
                   if c.rule_id != "RULE_PREG_L5_01"]
    return in_category + _PREGNANCY_EXTRA


def _matches(patterns: List[str], items: List[str]) -> List[str]:
    return [item for item in items for p in patterns if re.search(r"\b" + p, item, re.IGNORECASE)]


def profile_findings(profile: Dict[str, Any]) -> Dict[str, Any]:
    """What the profile settles: {age_years, history_condition_ids, absent_condition_ids, note}."""
    conditions = [str(c) for c in profile.get("chronic_conditions") or []]
    medications = [str(m) for m in profile.get("current_medications") or []]
    history, notes = [], []
    for group in HISTORY_GROUPS:
        sources = _matches(group["conditions"], conditions) + _matches(group["medications"], medications)
        if sources:
            history += [i for i in group["condition_ids"] if i not in history]
            notes.append(f"{group['label']} ({', '.join(dict.fromkeys(sources))})")
    age = profile.get("age")
    sex = str(profile.get("sex_at_birth") or "").lower()
    absent = pregnancy_condition_ids() if sex == "male" else []
    note_parts = ([f"age {age}"] if age is not None else []) + ([sex] if sex in ("male", "female") else []) + notes
    return {
        "age_years": age,
        "history_condition_ids": history,
        "absent_condition_ids": absent,
        "note": "From the health profile: " + "; ".join(note_parts) if note_parts else None,
    }
