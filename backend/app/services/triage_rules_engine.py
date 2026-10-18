"""Deterministic MTS 2019 triage rules engine.

The triage level is computed here, and only here, from `app/tools/mts_screening_kb.json`.
The LLM agent supplies facts (which KB conditions are present / absent); it never supplies a level.

Classification policy (from the KB `decision_policy` / `agent_contract`):
- A rule matches when ANY of its conditions is present.
- Higher urgency wins (Level 1 is the most urgent).
- A level is final only once every condition at a MORE urgent level, in the categories under
  screening, has been ruled out. Until then the engine returns `insufficient_information`
  with the next tier of conditions/questions to resolve, most urgent first.
"""
import json
import re
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Optional

KB_PATH = Path(__file__).resolve().parent.parent / "tools" / "mts_screening_kb.json"

CRITICAL_CATEGORY = "Critical First Look & General Emergency Indicators"
PAEDIATRIC_CATEGORY = "Paediatric Screening Protocols (Under 12 Years)"
PAEDIATRIC_MAX_AGE = 12
AGE_RESTRICT_RULE_ID = "RULE_PAED_AGE_RESTRICT_01"
AGE_RESTRICT_MAX_AGE = 8  # KB limitation: children under 8 are never Level 5

# Codes used by the existing `TriageLevel` schema / routing tool.
TRIAGE_CODES = {
    1: "LEVEL_1_RESUSCITATION",
    2: "LEVEL_2_EMERGENT",
    3: "LEVEL_3_URGENT",
    4: "LEVEL_4_LESS_URGENT",
    5: "LEVEL_5_NON_URGENT",
}

_LEVEL_PATTERN = re.compile(r"^Level ([1-5])$")

# Answers that rule out every option of a question. "None of these" is also offered on every selection.
NONE_ANSWERS = ("None of these", "Neither")
# Marks an option that is only one half of a compound condition (its `when` is "<answer> (this condition ...").
COMPOUND_NOTE = "(this condition also needs"


@dataclass(frozen=True)
class Condition:
    condition_id: str
    rule_id: str
    text: str
    level: int
    category: str
    population: str = "all"  # "all" | "adult" | "paediatric"


class TriageRulesEngine:
    """Loads the MTS knowledge base and evaluates findings against it."""

    def __init__(self, kb_path: Path = KB_PATH):
        with open(kb_path, encoding="utf-8") as f:
            self.kb = json.load(f)

        self.level_names: Dict[int, str] = {int(k): v for k, v in self.kb["triage_levels"].items()}
        self.level_advice: Dict[int, str] = {
            int(k): v for k, v in self.kb.get("level_advice", {}).get("levels", {}).items()
        }
        # condition text -> extra advice shown (with the level advice) whenever that condition is present
        self.emergency_advice_by_text: Dict[str, str] = {
            text: item["advice"]
            for item in self.kb.get("emergency_advice", {}).get("items", [])
            for text in item["conditions"]
        }
        self.categories: List[str] = []
        self.conditions: Dict[str, Condition] = {}
        self.rules: Dict[str, dict] = {}
        self.questions_by_category: Dict[str, List[dict]] = {}
        # condition_id -> plain-language wording of the question part that sets it (from question maps_to)
        self.ask_as: Dict[str, str] = {}
        # condition_id -> {field, op, value} for conditions decided by age alone
        self.age_derived: Dict[str, dict] = {}
        self.questions_by_id: Dict[str, dict] = {}
        # condition_id -> question_ids that each ask one half of a compound condition (e.g. onset > 6 H AND
        # moderate pain). Their options carry the COMPOUND_NOTE; the condition is present once all are answered
        # with that half (any other answer rules it out).
        self.compound: Dict[str, set] = {}
        # gated question_id -> gate question_id: the gated question is only asked after the gate is answered
        self.gated_by: Dict[str, str] = {}

        excluded_questions = {
            item["id"]
            for item in self.kb.get("excluded_from_active_screening", {}).get("items", [])
            if item.get("type") == "question"
        }

        for category in self.kb["screening_categories"]:
            name = category["category"]
            self.categories.append(name)
            self.questions_by_category[name] = [
                q for q in category.get("questions", []) if q["question_id"] not in excluded_questions
            ]
            for question in self.questions_by_category[name]:
                self.questions_by_id[question["question_id"]] = question
                for part in question.get("maps_to", []):
                    for gated in part.get("opens", []):
                        self.gated_by[gated] = question["question_id"]
                    if COMPOUND_NOTE in part["when"]:
                        for condition_id in part["condition_ids"]:
                            self.compound.setdefault(condition_id, set()).add(question["question_id"])
                    for condition_id in part["condition_ids"]:
                        self.ask_as.setdefault(condition_id, part["when"])
            for rule in category.get("rules", []):
                self.rules[rule["rule_id"]] = {**rule, "category": name}
                for suffix, spec in rule.get("age_derived", {}).items():
                    self.age_derived[f"{rule['rule_id']}.{suffix}"] = spec
                match = _LEVEL_PATTERN.match(rule["triage_level"].strip())
                if not match:
                    # Non-standard rules (e.g. the paediatric age restriction) are constraints,
                    # applied explicitly in evaluate(), not screened as conditions.
                    continue
                level = int(match.group(1))
                for index, text in enumerate(rule["conditions"], start=1):
                    condition_id = f"{rule['rule_id']}.C{index}"
                    self.conditions[condition_id] = Condition(
                        condition_id, rule["rule_id"], text, level, name, rule.get("population", "all")
                    )

    # ------------------------------------------------------------------ helpers

    @staticmethod
    def applies(population: str, age_years: Optional[float]) -> bool:
        """Whether a rule/question for `population` applies to a patient of this age.

        Unknown age only matches population-neutral ("all") items: age is asked first.
        """
        if population == "all":
            return True
        if age_years is None:
            return False
        return (age_years < PAEDIATRIC_MAX_AGE) == (population == "paediatric")

    def conditions_in(self, categories: Iterable[str], age_years: Optional[float] = None,
                      any_population: bool = True) -> List[Condition]:
        """Conditions in the given categories; with any_population=False only those applying to this age."""
        wanted = set(categories)
        return [
            c for c in self.conditions.values()
            if c.category in wanted and (any_population or self.applies(c.population, age_years))
        ]

    def resolve_categories(self, categories: Iterable[str], age_years: Optional[float]) -> tuple:
        """Normalise requested categories; always screen Critical First Look (and Paediatric for <12)."""
        lookup = {c.lower(): c for c in self.categories}
        resolved, unknown = [CRITICAL_CATEGORY], []
        for name in categories or []:
            canonical = lookup.get(name.strip().lower())
            if canonical is None:
                unknown.append(name)
            elif canonical not in resolved:
                resolved.append(canonical)
        if age_years is not None and age_years < PAEDIATRIC_MAX_AGE and PAEDIATRIC_CATEGORY not in resolved:
            resolved.append(PAEDIATRIC_CATEGORY)
        return resolved, unknown

    def apply_answer(self, question_id: str, answer: str) -> Optional[dict]:
        return self.apply_answers(question_id, [answer])

    def apply_answers(self, question_id: str, answers: List[str]) -> Optional[dict]:
        """Findings implied by picking `answers` (exact options) for a KB question, or None if not explicit.

        - Options naming parts of the question: those parts' conditions present; every part NOT chosen has its
          conditions and `covers` absent. Several options only for multi_select questions.
        - A none answer ("None of these", "Neither", a listed none_answers entry, "No" to a yes/no question),
          alone: every condition the question maps or covers absent.
        - "Yes" to a yes/no question with a single part: that part present.
        Anything else (e.g. "Yes" to a multi-part question) needs the person to say which, so returns None.
        """
        q = self.questions_by_id.get(question_id)
        answers = list(dict.fromkeys(answers))
        if q is None or not answers or any(a not in q["answers"] and a not in NONE_ANSWERS for a in answers):
            return None
        if len(answers) > 1 and not q.get("multi_select"):
            return None
        parts = q.get("maps_to", [])
        yes_no = sorted(q["answers"]) == ["No", "Yes"]
        found = {"present_condition_ids": [], "absent_condition_ids": [], "answered_question_ids": [question_id]}

        def ruled_out(unchosen):
            return list(dict.fromkeys(i for p in unchosen for i in p["condition_ids"] + p.get("covers", [])))

        is_none = [a in NONE_ANSWERS or a in q.get("none_answers", []) or (yes_no and a == "No") for a in answers]
        if any(is_none):
            if len(answers) > 1:
                return None  # "none" together with something else: contradictory
            # A none answer may set an end state of its own (e.g. "None of these - only mild symptoms").
            own = [p for p in parts if p["when"] == answers[0]]
            found["present_condition_ids"] = list(dict.fromkeys(i for p in own for i in p["condition_ids"]))
            found["absent_condition_ids"] = ruled_out([p for p in parts if p not in own])
            return found
        if yes_no:
            if len(parts) != 1:
                return None
            found["present_condition_ids"] = list(parts[0]["condition_ids"])
            return found

        def half_of_compound(p, a):
            return p["when"].lower().startswith(a.lower() + " " + COMPOUND_NOTE)

        chosen = []
        for a in answers:
            match = [p for p in parts if a.lower().startswith(p["when"].lower()) or half_of_compound(p, a)]
            if not match:
                return None
            chosen += [p for p in match if p not in chosen]
        # Half of a compound condition: stays open (decided in evaluate once its other half is answered).
        present = list(dict.fromkeys(i for p in chosen if COMPOUND_NOTE not in p["when"] for i in p["condition_ids"]))
        still_open = set(present) | {i for p in chosen for i in p.get("covers", [])}
        found["present_condition_ids"] = present
        found["absent_condition_ids"] = [i for i in ruled_out([p for p in parts if p not in chosen])
                                         if i not in still_open]
        return found

    def _source_reference(self, rule_id: str) -> dict:
        rule = self.rules[rule_id]
        return {"rule_id": rule_id, **rule.get("source_basis", {})}

    # ---------------------------------------------------------------- evaluate

    def evaluate(
        self,
        categories: Optional[List[str]] = None,
        present_condition_ids: Optional[List[str]] = None,
        absent_condition_ids: Optional[List[str]] = None,
        history_condition_ids: Optional[List[str]] = None,
        answered_question_ids: Optional[List[str]] = None,
        age_years: Optional[float] = None,
    ) -> dict:
        errors: List[str] = []
        screened, unknown_categories = self.resolve_categories(categories or [], age_years)
        if unknown_categories:
            errors.append(f"Unknown categories ignored: {unknown_categories}. Valid: {self.categories}")

        def _valid(ids: Optional[List[str]], label: str) -> set:
            ids = set(ids or [])
            bad = sorted(i for i in ids if i not in self.conditions)
            if bad:
                errors.append(f"Unknown {label} condition IDs ignored: {bad}")
            return ids - set(bad)

        # History only modifies the rules of the complaint being screened (KB patient_context.rule): epilepsy
        # history must not make a sprained ankle Level 4. Reported (present) conditions count everywhere.
        history = {i for i in _valid(history_condition_ids, "history") if self.conditions[i].category in screened}
        present = _valid(present_condition_ids, "present") | history
        # Safety: if a condition is both present and absent, present wins.
        absent = _valid(absent_condition_ids, "absent") - present
        # Age-only conditions in the screened categories are decided from the age, unless reported.
        if age_years is not None:
            for condition_id, spec in self.age_derived.items():
                if condition_id in present or condition_id in absent:
                    continue
                if self.conditions[condition_id].category not in screened:
                    continue
                holds = age_years > spec["value"] if spec["op"] == ">" else age_years < spec["value"]
                (present if holds else absent).add(condition_id)
        answered = set(answered_question_ids or [])
        # Compound conditions: every half answered and none ruled it out -> present.
        for condition_id, halves in self.compound.items():
            if condition_id not in present and condition_id not in absent and halves <= answered:
                present.add(condition_id)

        # Present conditions count even outside the screened categories (the user reported them), but only for
        # the patient's population: answers map to the adult and the paediatric version of a condition, and
        # the paediatric list is one level more urgent. With unknown age only population-neutral items count.
        present_conditions = [self.conditions[i] for i in present
                              if self.applies(self.conditions[i].population, age_years)]
        best_level = min((c.level for c in present_conditions), default=None)

        scope = self.conditions_in(screened, age_years, any_population=False)
        unknown = [c for c in scope if c.condition_id not in present and c.condition_id not in absent]
        blocking = [c for c in unknown if best_level is None or c.level < best_level]

        result = {
            "status": "insufficient_information",
            "triage_level": None,
            "triage_name": None,
            "triage_code": None,
            "at_least_level": best_level,
            "matched_rule_ids": [],
            "key_findings": [],
            "relevant_history_modifiers": [],
            "missing_information": [],
            "suggested_questions": [],
            "unexplored_categories": [],
            "screened_categories": screened,
            "routing_required": False,
            "level_advice": None,
            "interim_advice": None,
            "emergency_advice": self._emergency_advice(present_conditions),
            "call_999": best_level == 1,
            "source_references": [],
            "errors": errors,
        }

        result["call_999"] = best_level == 1 or bool(result["emergency_advice"])
        if best_level in (1, 2):
            # Levels 1-2 people usually head straight to a hospital: advise now, even before screening finishes.
            result["interim_advice"] = self.level_advice.get(best_level)

        needs_age = age_years is None and best_level != 1

        if best_level is not None and not blocking and not needs_age:
            return self._classified(result, best_level, present_conditions, history, age_years)

        if needs_age:
            result["missing_information"].append(
                {"field": "age_years", "reason": "Age is required by the knowledge base before classification."}
            )

        if blocking:
            # Ask about the most urgent unresolved tier only, so simple cases stay short.
            next_level = min(c.level for c in blocking)
            tier = [c for c in blocking if c.level == next_level]
            result["missing_information"].extend(self._missing_entry(c) for c in tier)
            tier_ids = {c.condition_id for c in tier}
            tier_categories = list(dict.fromkeys(c.category for c in tier))
            gates, others = [], []
            for cat in tier_categories:
                for q in self.questions_by_category.get(cat, []):
                    qid = q["question_id"]
                    if qid in answered or not self.applies(q.get("population", "all"), age_years):
                        continue
                    gate = self.gated_by.get(qid)
                    if gate and gate not in answered and self.applies(
                            self.questions_by_id[gate].get("population", "all"), age_years):
                        continue  # asked only after the checklist option that opens it
                    suggestion = {"question_id": qid, "text": q["text"], "answers": q["answers"], "category": cat}
                    if q.get("multi_select"):
                        suggestion["multi_select"] = True
                    # Every part is listed so any answer the person gives has an entry; parts that set none of
                    # the conditions still needed get an empty list (answering with one means those are absent).
                    # `covers`: conditions ruled out when that option is NOT chosen.
                    maps_to = []
                    for part in q.get("maps_to", []):
                        entry = {"when": part["when"], "condition_ids": [i for i in part["condition_ids"] if i in tier_ids]}
                        if part.get("covers"):
                            entry["covers"] = part["covers"]
                        maps_to.append(entry)
                    resolves = any(p["condition_ids"] or tier_ids & set(p.get("covers", [])) for p in maps_to)
                    if maps_to and not resolves:
                        continue  # nothing this question could still settle at this tier
                    if resolves:
                        suggestion["maps_to"] = maps_to
                    (gates if any("covers" in p for p in maps_to) else others).append(suggestion)
            result["suggested_questions"] = gates + others
        elif best_level is None:
            # Everything screened has been ruled out and nothing matched: look at other categories.
            result["unexplored_categories"] = [c for c in self.categories if c not in screened]

        return result

    def _missing_entry(self, c: Condition) -> dict:
        entry = {"condition_id": c.condition_id, "condition": c.text, "category": c.category}
        if c.condition_id in self.ask_as:
            entry["ask_as"] = self.ask_as[c.condition_id]
        spec = self.age_derived.get(c.condition_id)
        if spec:
            entry["from_age"] = (
                f"decided by {spec['field']} alone: present if {spec['field']} {spec['op']} {spec['value']}, "
                "otherwise absent. Do not ask."
            )
        return entry

    def _emergency_advice(self, present_conditions: List[Condition]) -> List[str]:
        advice = [self.emergency_advice_by_text[c.text] for c in present_conditions if c.text in self.emergency_advice_by_text]
        return list(dict.fromkeys(advice))

    def _classified(self, result, level, present_conditions, history, age_years) -> dict:
        matched = [c for c in present_conditions if c.level == level]
        matched_rule_ids = list(dict.fromkeys(c.rule_id for c in matched))

        if level == 5 and age_years is not None and age_years < AGE_RESTRICT_MAX_AGE:
            level = 4
            matched_rule_ids.append(AGE_RESTRICT_RULE_ID)

        result.update(
            status="classified",
            triage_level=level,
            triage_name=self.level_names[level],
            triage_code=TRIAGE_CODES[level],
            at_least_level=level,
            matched_rule_ids=matched_rule_ids,
            key_findings=[c.text for c in matched],
            relevant_history_modifiers=[c.text for c in present_conditions if c.condition_id in history],
            routing_required=True,
            level_advice=self.level_advice.get(level),
            interim_advice=None,
            call_999=level == 1 or bool(result["emergency_advice"]),
            source_references=[self._source_reference(r) for r in matched_rule_ids if r in self.rules],
        )
        return result

    # ---------------------------------------------------------------- catalogue

    def condition_catalogue(self) -> str:
        """Compact, level-free listing of categories and condition IDs for the agent prompt."""
        lines = []
        for category in self.categories:
            lines.append(f"[{category}]")
            for c in self.conditions_in([category]):
                lines.append(f"  {c.condition_id}: {c.text}")
        return "\n".join(lines)


@lru_cache()
def get_triage_rules_engine() -> TriageRulesEngine:
    return TriageRulesEngine()
