"""Hybrid triage: the screening runs in code; the LLM only reads free text and phrases replies.

Enabled with TRIAGE_MODE=hybrid. Same surface as MedicalTriageAgent (`run_session` returns a session whose
`last_output` / `triage_result` the /triage/chat route reads), so the API and the frontend do not change.

Per turn:
1. Record the input. Tapped options go through `engine.apply_answers` (or the step's own option mapping) with no
   LLM. Free text goes to one small EXTRACT call that may only pick option texts, condition IDs and category names
   it was given. It never sees the chat history.
2. Evaluate with the rules engine. When a new tier of conditions opens, the symptom details the person typed
   earlier (`facts`) are checked against it once (catch-up), so nothing they already said is asked again.
3. Code picks the next step from the engine result: result, a KB question (engine order), age, a checklist for
   conditions with no KB question, "Not sure" yes/no follow-ups, "which of these" after a multi-part "Yes", one
   "other symptoms?" ask, or stop with in-person advice.
4. A PRESENT call phrases that step conversationally. Options, the level, the advice and the 999 line are set by
   code; the phrasing is checked and replaced by the plain template if it breaks a rule.
"""
import copy
import json
import logging
import re
import uuid
from dataclasses import dataclass, field, replace
from typing import Any, Dict, List, Optional

from langchain_core.messages import AIMessage, HumanMessage, SystemMessage

from app.agents.hybrid_prompts import EXTRACT_PROMPT, PRESENT_PROMPT
from app.agents.triage_agent import (
    _FILTERED_REPLY, _SELF_HARM_FILTERED, NOT_SURE, PSYCHIATRIC_CATEGORY, TriageSession, _extract_text,
    _strip_code_fence, kb_selection,
)
from app.core.llm import get_llm
from app.services import plain_language
from app.services.patient_context import profile_findings
from app.services.triage_rules_engine import COMPOUND_NOTE, CRITICAL_CATEGORY, NONE_ANSWERS, get_triage_rules_engine

logger = logging.getLogger(__name__)

YES, NO = "Yes", "No"
NONE_OPTION = NONE_ANSWERS[0]
CALL_999 = "Call 999 now (112 from a mobile phone)."
DISCLAIMER = ("This is a preliminary screening, not a medical diagnosis. It does not replace assessment by a "
              "healthcare professional. If symptoms worsen, call 999.")
STOP_TEXT = ("I could not assign an urgency level from this screening. Please get a prompt in-person medical "
             "assessment, and call 999 (112 from a mobile phone) if any danger sign appears.")
ERROR_REPLY = ("Sorry, the screening assistant is temporarily unavailable. Please try again in a moment. If you "
               "have any life-threatening symptoms, call 999 (or 112 from mobile) or go to the nearest Emergency "
               "Department now.")

# What each step asks, when it is not a KB question (also the fallback when the phrasing is rejected).
SAY = {
    "complaint": "What is the main problem you would like help with today?",
    "age": "How old is the patient?",
    "which": "Which of these is it? Tick all that apply.",
    "conditions": "Do any of these apply right now? Tick all that apply.",
    "parts": "Do any of these apply? Tick all that apply.",
    "other_symptoms": "Are there any other symptoms you have not mentioned yet?",
    "result": "Thank you for answering. Here is the result of the screening.",
    "stop": STOP_TEXT,
}
QUESTION_STEPS = {"question", "which", "parts", "confirm", "conditions", "complaint", "age", "other_symptoms"}
CHECKLIST_STEPS = ("which", "parts", "conditions")

CHECKLIST_SIZE = 6  # conditions with no KB question are asked in checklists of this many
PARTS_CHECKLIST_MIN = 3  # a yes/no KB question naming at least this many things is shown as a tick list
MAX_REPEATS = 3     # the same step shown this many times in a row: stop with in-person advice
MAX_ITERATIONS = 25  # evaluate / catch-up rounds per turn
MAX_LEAD_CHARS = 400
MAX_ESTIMATE = 30  # questions-left simulation stops here
ESTIMATE_AGE = 30.0  # age assumed by the simulation when it is not known yet (only the count matters)

_AGE = re.compile(r"(\d+(?:\.\d+)?)\s*(month|mo\b|bulan|week|minggu)?", re.IGNORECASE)
_BANNED = re.compile(r"\b911\b|\blevel\s*[1-5]\b|\btahap\s*[1-5]\b", re.IGNORECASE)
_DIGITS = re.compile(r"\d+")
_YES_NO_PREFIX = re.compile(r"^(yes|no)\s*-\s*", re.IGNORECASE)
_THE_PERSON = r"the (?:person|patient)"
# KB questions say "the person"; when the screening is for the user, ask them directly. (pattern, replacement)
_FOR_YOU = [
    (re.compile(rf"\b{_THE_PERSON}'s\b", re.IGNORECASE), "your"),
    (re.compile(rf"\b([IiDdHhWw])(?:s|oes|as) {_THE_PERSON}\b"), None),  # Is / Does / Has / Was the person
    (re.compile(rf", {_THE_PERSON} (\w+ing)\b", re.IGNORECASE), r", are you \1"),
    (re.compile(rf"\b{_THE_PERSON}\b", re.IGNORECASE), "you"),
]
_VERB_FOR_YOU = {"i": "are", "d": "do", "h": "have", "w": "were"}


def parse_age(message: str) -> Optional[float]:
    """Age in years from a short reply such as "30", "30 years old" or "6 months"."""
    match = _AGE.search(message)
    if not match:
        return None
    value, unit = float(match.group(1)), (match.group(2) or "").lower()
    if unit.startswith(("month", "mo", "bulan")):
        value /= 12
    elif unit.startswith(("week", "minggu")):
        value /= 52
    return round(value, 2) if 0 <= value <= 120 else None


def for_you(text: str) -> str:
    """`text` addressed to the patient themselves ("Is the person pregnant?" -> "Are you pregnant?")."""
    def verb(match):
        word = _VERB_FOR_YOU[match.group(1).lower()]
        return (word.capitalize() if match.group(1).isupper() else word) + " you"
    for pattern, replacement in _FOR_YOU:
        text = pattern.sub(replacement or verb, text)
    return text


def _label(when: str) -> str:
    """Option text for a question part (without the compound-condition note)."""
    return when.split(COMPOUND_NOTE)[0].strip()


@dataclass
class HybridSession(TriageSession):
    pending: Optional[Dict[str, Any]] = None  # the step last shown, waiting for an answer
    queue: List[Dict[str, Any]] = field(default_factory=list)  # follow-up steps to show before the engine's next
    facts: List[str] = field(default_factory=list)  # symptom details the person typed, for catch-up
    language: str = "en"
    checked_ids: List[str] = field(default_factory=list)  # condition IDs already checked against `facts`
    interim_level: Optional[int] = None  # interim advice already given for this level
    asked_other: bool = False
    last_signature: Optional[str] = None
    repeats: int = 0
    finished: bool = False
    # The logged-in user's health profile; applied only once the screening is known to be for them.
    profile: Dict[str, Any] = field(default_factory=dict)
    # Who the screening is for: "self" (the default: the app tells the user it assumes them) or "other".
    subject: Optional[str] = None
    profile_note: Optional[str] = None  # what was taken from the profile, mentioned once by the presenter
    profile_applied: Dict[str, Any] = field(default_factory=dict)  # what the profile pre-filled, to undo
    # Quality counters (read by the eval script): replies sent as the plain template because the phrasing failed
    # or was rejected, and free-text messages from which nothing at all could be recorded.
    template_fallbacks: int = 0
    empty_extractions: int = 0
    # Level 1-2 conditions the person seems to have described earlier (catch-up). Never recorded from that alone:
    # when their question comes up, the matching option is pre-selected and the person confirms it.
    mentioned: List[str] = field(default_factory=list)
    option_map: Dict[str, str] = field(default_factory=dict)  # options as shown -> KB labels (plain wording)
    # Progress for the app's step bar. Step 1 is the app's own opening "what is the main problem?" question.
    steps_shown: int = 1
    progress: Optional[Dict[str, Any]] = None


class HybridTriageController:
    """Deterministic triage flow over the rules engine, with an LLM extractor and presenter."""

    def __init__(self):
        self.engine = get_triage_rules_engine()
        self._llm = None
        self._effort_supported = True  # reasoning models (gpt-5 family); turned off if the deployment rejects it
        # In-memory only: sessions are lost on server restart (fine for the demo).
        self._sessions: Dict[str, HybridSession] = {}
        self._category_lookup = {c.lower(): c for c in self.engine.categories}
        # What each category asks about (its KB question wording), so a complaint can be placed by content, not
        # by name alone (e.g. black stools are under "Vomiting, Diarrhoea & Dehydration"). Sent only while the
        # complaint's category is still open, as it costs ~1.5k tokens.
        self._category_hints = [
            {"name": c, "asks_about": " ".join(q["text"] for q in self.engine.questions_by_category[c])[:220]}
            for c in self.engine.categories if c != CRITICAL_CATEGORY
        ]
        # Level 1-2 first-look items: free text is always checked against these, so danger is caught at once.
        self._danger = [
            {"id": c.condition_id, "text": self.engine.ask_as.get(c.condition_id, c.text)}
            for c in self.engine.conditions_in([CRITICAL_CATEGORY]) if c.level <= 2 and c.population == "all"
        ]

    # ------------------------------------------------------------------ LLM

    def _runnable(self):
        if self._llm is None:
            llm = get_llm()
            try:
                self._llm = llm.bind(response_format={"type": "json_object"})
            except Exception as e:
                logger.warning(f"Could not enable JSON mode (placeholder mode): {e}")
                self._llm = llm
        return self._llm

    def _invoke_llm(self, runnable, messages):
        """Single LLM call (separate so the eval script can meter tokens)."""
        return runnable.invoke(messages)

    def _ask_llm(self, prompt: str, payload: Dict[str, Any], effort: str) -> Dict[str, Any]:
        """One stateless JSON call. `effort`: reasoning effort for reasoning models (these calls are simple)."""
        messages = [SystemMessage(content=prompt), HumanMessage(content=json.dumps(payload, ensure_ascii=False))]
        runnable = self._runnable()
        if self._effort_supported:
            try:
                response = self._invoke_llm(runnable.bind(reasoning_effort=effort), messages)
            except Exception as e:
                if "reasoning" not in str(e).lower():
                    raise
                logger.info(f"Deployment does not take reasoning_effort, calling without it: {e}")
                self._effort_supported = False
        if not self._effort_supported:
            response = self._invoke_llm(runnable, messages)
        data = json.loads(_strip_code_fence(_extract_text(getattr(response, "content", ""))))
        if not isinstance(data, dict):
            raise ValueError(f"expected a JSON object, got {type(data).__name__}")
        return data

    # ------------------------------------------------------------------ sessions

    def has_session(self, session_id: Optional[str]) -> bool:
        return bool(session_id) and session_id in self._sessions

    def session_owner(self, session_id: Optional[str]) -> Optional[str]:
        session = self._sessions.get(session_id) if session_id else None
        return session.owner_id if session else None

    def get_session(self, session_id: Optional[str], context: Optional[Dict[str, Any]] = None) -> HybridSession:
        if session_id and session_id in self._sessions:
            return self._sessions[session_id]
        session = HybridSession(session_id=session_id or str(uuid.uuid4()),
                                owner_id=(context or {}).get("patient_id"),
                                profile=dict((context or {}).get("profile") or {}))
        self._sessions[session.session_id] = session
        return session

    def _set_subject(self, session: HybridSession, subject: str) -> None:
        """Record who the screening is for. For the user: pre-fill what their profile settles. For someone else
        (said at any point): undo that pre-fill, so the user's profile never describes another person."""
        previous, session.subject = session.subject, subject
        f = session.findings
        if subject == "self" and session.profile and previous is None:
            found = profile_findings(session.profile)
            age = found["age_years"] if f["age_years"] is None else None  # a stated age wins over the profile
            session.profile_applied = {"age_years": age, "history": found["history_condition_ids"],
                                       "absent": [i for i in found["absent_condition_ids"]
                                                  if i not in f["absent_condition_ids"]]}
            session.merge_findings({"age_years": age, "history_condition_ids": found["history_condition_ids"],
                                    "absent_condition_ids": found["absent_condition_ids"]})
            session.profile_note = found["note"]
        elif subject == "other" and previous == "self" and session.profile_applied:
            applied, session.profile_applied, session.profile_note = session.profile_applied, {}, None
            if applied["age_years"] is not None and f["age_years"] == applied["age_years"]:
                f["age_years"] = None
            f["history_condition_ids"] = [i for i in f["history_condition_ids"] if i not in applied["history"]]
            f["absent_condition_ids"] = [i for i in f["absent_condition_ids"] if i not in applied["absent"]]

    def run_session(
        self,
        message: str,
        context: Optional[Dict[str, Any]] = None,
        session_id: Optional[str] = None,
        selected_options: Optional[List[str]] = None,
        note: Optional[str] = None,
    ) -> HybridSession:
        """Run one turn. `selected_options`: the option(s) picked from the previous selection. `note`: optional
        extra details typed alongside them, read as new information after the pick is recorded."""
        session = self.get_session(session_id, context)
        note = (note or "").strip()
        session.messages.append(HumanMessage(content=f"{message}\n{note}" if note else message))
        try:
            self._record(session, message, selected_options)
            if note:
                # The pick already answered the question, so the note is extracted with no question on screen:
                # it can add findings (danger signs, new symptoms, "it's for my mother"), never rule anything out.
                session.triage_result = self.engine.evaluate(**session.findings)
                self._extract(session, note, None, [])
            step = self._next_step(session)
            output = self._render(session, step, f"{message}. {note}" if note else message)
            session.progress = self._progress(session)
        except Exception as e:
            logger.error(f"[HybridTriageController] Turn failed: {e}")
            if "content_filter" in str(e):
                # The provider refused the message (e.g. self-harm wording): give urgent advice, never an error.
                if _SELF_HARM_FILTERED.search(str(e)):
                    session.merge_findings({"categories": [PSYCHIATRIC_CATEGORY]})
                output = {"type": "text", "question": None, "response": _FILTERED_REPLY}
            else:
                output = {"type": "text", "question": None, "response": ERROR_REPLY}
        session.last_output = output
        session.messages.append(AIMessage(content=output["question"] or output["response"]))
        return session

    # ------------------------------------------------------------------ 1. record the input

    def _record(self, session: HybridSession, message: str, selected: Optional[List[str]]) -> None:
        pending, last = session.pending, session.last_output or {}
        options = last.get("response") if last.get("type") == "selection" else []
        picked = [s.strip() for s in selected] if selected else None
        if picked is None and message.strip() in options:
            picked = [message.strip()]
        if pending and picked and all(p in options for p in picked):
            self._apply_picked(session, pending, self._to_kb(session, picked))
            return
        if pending and pending["kind"] == "age" and len(message.split()) <= 4:
            age = parse_age(message)
            if age is not None:
                session.merge_findings({"age_years": age})
                return
        self._extract(session, message, pending, [o for o in options if o != NOT_SURE])

    @staticmethod
    def _to_kb(session: HybridSession, picked: List[str]) -> List[str]:
        """Options as shown (maybe in plain wording) -> the KB labels they stand for."""
        return [session.option_map.get(p, p) for p in picked]

    def _apply_picked(self, session: HybridSession, step: Dict[str, Any], picked: List[str]) -> None:
        """Record option(s) picked for `step`, decided by the KB mapping, never by the LLM."""
        if NOT_SURE in picked:
            if step.get("question_id"):
                session.merge_findings({"answered_question_ids": [step["question_id"]]})
            # One yes/no question per item; the person confirms each one.
            session.queue[:0] = [{"kind": "confirm", "items": [item]} for item in self._items(step)]
            return
        if step["kind"] == "question":
            found = self.engine.apply_answers(step["question_id"], picked) or self._match_parts(step, picked)
            if found is None:
                # e.g. "Yes" to a question with several parts: ask which.
                session.merge_findings({"answered_question_ids": [step["question_id"]]})
                session.queue.insert(0, {"kind": "which", "question_id": step["question_id"]})
                return
            session.merge_findings(found)
            return
        items = step["items"]
        if step["kind"] == "confirm":
            picked = [items[0]["label"]] if picked == [YES] else []
        found = self._items_findings(items, set(picked))
        if step["kind"] == "parts":
            found["answered_question_ids"] = [step["question_id"]]
        session.merge_findings(found)

    def _match_parts(self, step: Dict[str, Any], picked: List[str]) -> Optional[Dict[str, Any]]:
        """Options worded "Yes - <part>" / "No - <part>" that name exactly one KB part each (e.g. Q_PAED_06)."""
        items = self._items(step)
        labels = {it["label"].lower(): it["label"] for it in items}
        chosen = [labels.get(_YES_NO_PREFIX.sub("", p).strip().lower()) for p in picked]
        if not items or None in chosen:
            return None
        found = self._items_findings(items, set(chosen))
        found["answered_question_ids"] = [step["question_id"]]
        return found

    @staticmethod
    def _items_findings(items: List[Dict[str, Any]], chosen: set) -> Dict[str, Any]:
        """Chosen items present (except compound halves, decided by the engine), unchosen items ruled out."""
        present = [i for it in items if it["label"] in chosen and not it.get("compound") for i in it["condition_ids"]]
        absent = [i for it in items if it["label"] not in chosen
                  for i in it["condition_ids"] + it.get("covers", []) if i not in present]
        return {"present_condition_ids": present, "absent_condition_ids": absent}

    def _applicable(self, items: List[Dict[str, Any]], age_years: Optional[float]) -> List[Dict[str, Any]]:
        """Items that can apply at this age (e.g. no "hoarse voice (child)" for an adult). The engine ignores the
        others, so leaving them unanswered changes nothing."""
        def applies(i):
            c = self.engine.conditions.get(i)
            return c is None or self.engine.applies(c.population, age_years)
        return [it for it in items if any(applies(i) for i in it["condition_ids"] + it.get("covers", []))]

    def _items(self, step: Dict[str, Any]) -> List[Dict[str, Any]]:
        """The answerable items of a step: {label, condition_ids, covers?, compound?}."""
        if step.get("items"):
            return step["items"]
        q = self.engine.questions_by_id[step["question_id"]]
        items = []
        for part in q.get("maps_to", []):
            if not (part["condition_ids"] or part.get("covers")):
                continue
            item = {"label": _label(part["when"]), "condition_ids": list(part["condition_ids"])}
            if part.get("covers"):
                item["covers"] = part["covers"]
            if COMPOUND_NOTE in part["when"]:
                item["compound"] = True
            items.append(item)
        return items

    def _extract(self, session: HybridSession, message: str, pending: Optional[Dict[str, Any]],
                 options: List[str]) -> None:
        """Turn free text into findings with one LLM call, limited to the IDs and options offered."""
        result = session.triage_result or self.engine.evaluate(**session.findings)
        open_conditions = self._open_conditions(result)
        offered = {c["id"] for c in open_conditions}
        # Danger items are offered even when answered earlier: the person's state can change ("he just collapsed"
        # after "he is conscious"), and the latest answer wins. Only items already present are left out.
        present_now = set(session.findings["present_condition_ids"])
        danger = [d for d in self._danger if d["id"] not in present_now and d["id"] not in offered]
        question = None
        if pending and pending["kind"] in QUESTION_STEPS and options:
            question = {"text": (session.last_output or {}).get("question"), "options": options}
        said, had_complaint = message, session.has_complaint()
        placing = not session.findings["categories"] or (pending or {}).get("kind") == "other_symptoms"
        if placing and session.facts:
            message = f"{message} (Earlier they said: {'; '.join(session.facts)})"
        payload = {
            "message": message, "question": question, "open_conditions": open_conditions,
            "danger_conditions": danger, "categories": self._category_hints if placing else self.engine.categories,
            "known": {"categories": session.findings["categories"], "age_years": session.findings["age_years"]},
        }
        try:
            data = self._ask_llm(EXTRACT_PROMPT, payload, "low")
        except Exception as e:
            if "content_filter" in str(e):
                raise
            logger.warning(f"[HybridTriageController] Extraction failed, nothing recorded: {e}")
            session.empty_extractions += 1
            return

        allowed = offered | {d["id"] for d in danger}
        picked = [o for o in data.get("picked_options") or [] if o in options]
        if pending and picked:
            if pending["kind"] == "question" and not self.engine.questions_by_id[pending["question_id"]].get(
                    "multi_select"):
                picked = picked[:1]
            self._apply_picked(session, pending, self._to_kb(session, picked))
        present = [i for i in data.get("present") or [] if i in allowed]
        # Ruling out needs a question on screen: a bare "no" cannot rule out things nobody asked about.
        absent = [i for i in data.get("absent") or [] if i in allowed and i not in present] if question else []
        age = data.get("age_years")
        session.merge_findings({
            "categories": [self._category_lookup[c.lower()] for c in data.get("categories") or []
                           if isinstance(c, str) and c.lower() in self._category_lookup],
            "age_years": age if isinstance(age, (int, float)) and 0 <= age <= 120 else None,
            "present_condition_ids": present,
            "absent_condition_ids": absent,
        })
        if session.chief_complaint is None and not had_complaint and session.has_complaint():
            session.chief_complaint = said  # their own words, not a greeting like "hi"
        facts = [str(f)[:80] for f in data.get("facts") or [] if str(f).strip()]
        session.facts = list(dict.fromkeys(session.facts + facts))[-12:]
        session.checked_ids = list(dict.fromkeys(session.checked_ids + sorted(allowed)))
        if data.get("language") in ("en", "ms"):
            session.language = data["language"]
        if not (picked or present or absent or age is not None or data.get("categories")
                or data.get("subject") == "other"):
            session.empty_extractions += 1
        # "It's for my mother": switches away from the default (the account owner) at any point, never back.
        if data.get("subject") == "other" and session.subject != "other":
            self._set_subject(session, "other")

    def _catch_up(self, session: HybridSession, result: Dict[str, Any]) -> bool:
        """Check what the person already typed against a newly opened tier. True if anything was recorded."""
        checked = set(session.checked_ids)
        open_conditions = [c for c in self._open_conditions(result) if c["id"] not in checked]
        tier = {c["id"] for c in open_conditions}
        if not session.facts or not tier:
            return False
        session.checked_ids += sorted(tier)
        payload = {"message": "; ".join(session.facts), "question": None, "open_conditions": open_conditions,
                   "danger_conditions": [], "categories": [], "known": {}}
        try:
            data = self._ask_llm(EXTRACT_PROMPT, payload, "low")
        except Exception as e:
            logger.warning(f"[HybridTriageController] Catch-up failed: {e}")
            return False
        # Earlier free text only fills in what the person reported, at Level 3+. It never rules anything out (only
        # an answer to a question on screen does), and never raises the urgency to Level 1-2: those need the KB
        # question, whose options tell look-alikes apart (e.g. "wheezing" is not "abnormal breathing sounds").
        reported = [i for i in data.get("present") or [] if i in tier]
        session.mentioned += [i for i in reported if self.engine.conditions[i].level <= 2]
        present = [i for i in reported if self.engine.conditions[i].level > 2]
        if not present:
            return False
        session.merge_findings({"present_condition_ids": present})
        return True

    def _open_conditions(self, result: Dict[str, Any]) -> List[Dict[str, str]]:
        return [{"id": m["condition_id"], "text": m.get("ask_as") or m["condition"]}
                for m in result.get("missing_information", []) if "condition_id" in m and "from_age" not in m]

    # ------------------------------------------------------------------ 2-3. choose the next step

    def _next_step(self, session: HybridSession, catch_up: bool = True) -> Dict[str, Any]:
        """`catch_up=False`: no LLM call (the questions-left simulation)."""
        f = session.findings
        for _ in range(MAX_ITERATIONS):
            result = self.engine.evaluate(**f)
            session.triage_result = result
            if catch_up and self._catch_up(session, result):
                continue
            if result["status"] == "classified":
                session.queue.clear()
                return {"kind": "result"}
            known = set(f["present_condition_ids"]) | set(f["absent_condition_ids"])
            while session.queue:
                step = session.queue.pop(0)
                if step["kind"] == "confirm" and set(step["items"][0]["condition_ids"]) <= known \
                        and not step["items"][0].get("covers"):
                    continue  # already settled
                if step["kind"] == "which":
                    step["items"] = self._applicable(self._items(step), f["age_years"])
                    if not step["items"]:
                        continue
                return step
            if session.subject is None and (f["categories"] or f["present_condition_ids"]):
                # Default: the account owner (the app's opening note asks others to say who it is for).
                self._set_subject(session, "self")
                continue
            if not f["categories"] and not f["present_condition_ids"]:
                return {"kind": "complaint"}
            missing = result["missing_information"]
            if any(m.get("field") == "age_years" for m in missing):
                return {"kind": "age"}
            if result["suggested_questions"]:
                step = {"kind": "question", "question_id": result["suggested_questions"][0]["question_id"]}
                items = self._applicable(self._items(step), f["age_years"])
                if self.engine.questions_by_id[step["question_id"]]["answers"] == [YES, NO]                         and len(items) >= PARTS_CHECKLIST_MIN:
                    # A yes/no question naming several things: a tick list of short items, answered once,
                    # instead of a long sentence and then "which of these" after a "Yes".
                    step = {"kind": "parts", "question_id": step["question_id"], "items": items}
                return step
            unasked = [m for m in missing if "condition_id" in m]
            if unasked:
                # Conditions with no KB question: ask them as a checklist in the KB's own wording.
                return {"kind": "conditions", "items": [
                    {"label": m.get("ask_as") or m["condition"], "condition_ids": [m["condition_id"]]}
                    for m in unasked[:CHECKLIST_SIZE]]}
            if result["unexplored_categories"] and not session.asked_other:
                session.asked_other = True
                return {"kind": "other_symptoms"}
            return {"kind": "stop"}
        return {"kind": "stop"}

    # ------------------------------------------------------------------ 4. present

    def _render(self, session: HybridSession, step: Dict[str, Any], message: str) -> Dict[str, Any]:
        signature = json.dumps(step, sort_keys=True)
        session.repeats = session.repeats + 1 if signature == session.last_signature else 0
        session.last_signature = signature
        if session.repeats >= MAX_REPEATS - 1 and step["kind"] != "result":
            step = {"kind": "stop"}  # no progress: never loop on the same question

        kind, result = step["kind"], session.triage_result or {}
        if kind in QUESTION_STEPS and kind != "complaint" and session.repeats == 0:
            session.steps_shown += 1  # a new question (not the same one shown again)
        session.pending = step if kind in QUESTION_STEPS else None
        session.finished = kind in ("result", "stop")
        output: Dict[str, Any] = {"type": "text", "question": None}
        say = SAY.get(kind, "")
        if kind == "question":
            q = self.engine.questions_by_id[step["question_id"]]
            output.update(type="selection", **kb_selection(q))
            say = plain_language.question(q["question_id"], q["text"])
        elif kind in CHECKLIST_STEPS:
            options = [it["label"] for it in step["items"]] + [NONE_OPTION]
            output.update(type="selection", response=options + [NOT_SURE], multi_select=True,
                          exclusive_options=[NONE_OPTION, NOT_SURE])
            if step.get("question_id"):
                output["question_id"] = step["question_id"]
            if kind == "parts":
                say = plain_language.question(step["question_id"], say)
        elif kind == "confirm":
            output.update(type="selection", response=[YES, NO])
            say = f"Is this happening: {plain_language.label(step['items'][0]['label'])}?"
        if session.subject == "self":
            say = for_you(say)

        suggested = self._suggested(session, step) if output["type"] == "selection" else []
        if suggested:
            output["suggested_options"] = suggested
        if output["type"] == "selection":
            # Shown in plain wording when enabled; a tap is mapped back to the KB label in _record.
            session.option_map = plain_language.options(output["response"])
            shown = {kb: text for text, kb in session.option_map.items()}
            for key in ("response", "exclusive_options", "suggested_options"):
                if key in output:
                    output[key] = [shown.get(o, o) for o in output[key]]
        before, after = self._fixed_lines(session, kind, result)
        lead, fixed = self._phrase(session, kind, say, message, output.get("response") or [], before + after,
                                   mentioned="; ".join(session.facts)[:200] if suggested else None)
        text = "\n\n".join(fixed[:len(before)] + [lead] + fixed[len(before):])
        if output["type"] == "selection":
            output["question"] = text
        else:
            output["response"] = text
        return output

    # ------------------------------------------------------------------ progress

    def _progress(self, session: HybridSession) -> Dict[str, Any]:
        """{step, total, done} for the app's step bar. `total` is an estimate (None until the complaint is known)."""
        step = session.steps_shown
        if session.finished:
            return {"step": step, "total": step, "done": True}
        left = self._questions_left(session)
        return {"step": step, "total": None if left is None else step + left, "done": False}

    def _questions_left(self, session: HybridSession) -> Optional[int]:
        """Questions after the one on screen if every remaining answer is the "none" answer, worked out by the
        engine alone on a copy of the session (no LLM call). Roughly an upper bound: a positive answer usually
        settles the level sooner, though a follow-up ("which", "Not sure", a new complaint) can add a few. It is
        recomputed every turn, so it corrects itself. None while the complaint is not known yet."""
        step = session.pending
        if not step or step["kind"] == "complaint":
            return None
        sim = copy.deepcopy(replace(session, messages=[]))
        left, seen = -1, set()
        while step and step["kind"] in QUESTION_STEPS and left < MAX_ESTIMATE:
            signature = json.dumps(step, sort_keys=True)
            if step["kind"] == "complaint" or signature in seen:
                break
            seen.add(signature)
            left += 1
            self._answer_none(sim, step)
            step = self._next_step(sim, catch_up=False)
        return max(left, 0)

    def _answer_none(self, sim: HybridSession, step: Dict[str, Any]) -> None:
        """Record the "none" answer to `step` (simulation only)."""
        kind = step["kind"]
        if kind == "age":
            sim.merge_findings({"age_years": ESTIMATE_AGE})
        elif kind == "confirm":
            self._apply_picked(sim, step, [NO])
        elif kind in CHECKLIST_STEPS:
            self._apply_picked(sim, step, [NONE_OPTION])
        elif kind == "question":
            q = self.engine.questions_by_id[step["question_id"]]
            options = [o for o in kb_selection(q)["response"] if o != NOT_SURE]
            nones = [o for o in options if o in q.get("none_answers", []) or o == NO or o in NONE_ANSWERS]
            # No none answer (e.g. only severity bands): the last option, usually the least urgent.
            self._apply_picked(sim, step, nones[:1] or options[-1:])
        # other_symptoms: asked once; with nothing new the screening goes on

    def _suggested(self, session: HybridSession, step: Dict[str, Any]) -> List[str]:
        """Options covering what the person already mentioned (session.mentioned), to show pre-selected."""
        mentioned = set(session.mentioned)
        if not mentioned:
            return []
        if step["kind"] == "confirm":
            return [YES] if mentioned & set(step["items"][0]["condition_ids"]) else []
        if step["kind"] in CHECKLIST_STEPS:
            return [it["label"] for it in step["items"] if mentioned & set(it["condition_ids"])]
        if step["kind"] != "question":
            return []
        q = self.engine.questions_by_id[step["question_id"]]
        suggested = []
        for part in q.get("maps_to", []):
            if not mentioned & set(part["condition_ids"]):
                continue
            label = _label(part["when"]).lower()
            match = [a for a in q["answers"]
                     if a.lower().startswith(label) or _YES_NO_PREFIX.sub("", a).lower().startswith(label)]
            suggested += match or ([YES] if YES in q["answers"] else [])
        suggested = list(dict.fromkeys(suggested))
        return suggested if q.get("multi_select") else suggested[:1]

    def _fixed_lines(self, session: HybridSession, kind: str, result: Dict[str, Any]) -> tuple:
        """Lines set by code (never phrased by the LLM): (before the reply, after the reply)."""
        # While the findings call for 999, every reply starts with it, before anything the LLM phrased.
        before = [CALL_999] if result.get("call_999") else []
        after = []
        if kind == "result":
            after.append(result.get("level_advice"))
            after.extend(result.get("emergency_advice", []))
            if result.get("key_findings"):
                after.append("What you reported: " + "; ".join(result["key_findings"]) + ".")
            after.append(DISCLAIMER)
        elif result.get("interim_advice") and session.interim_level != result.get("at_least_level"):
            # Level 1-2 people usually head straight to hospital: advise now, before screening finishes.
            session.interim_level = result["at_least_level"]
            before.append("So far this is at least " + result["interim_advice"])
            before.extend(result.get("emergency_advice", []))
        return [line for line in before if line], [line for line in after if line]

    def _phrase(self, session: HybridSession, kind: str, say: str, message: str, options: List[str],
                fixed: List[str], mentioned: Optional[str] = None) -> tuple:
        """Conversational wording for `say` (+ fixed lines translated for Malay). Falls back to the template."""
        translate = session.language != "en"
        payload = {"language": session.language, "user_said": message[:300], "step": kind, "say": say,
                   "options": options[:10], "fixed": fixed if translate else [],
                   "subject": session.subject or "unknown"}
        if session.profile_note:
            payload["patient_note"], session.profile_note = session.profile_note, None  # mentioned once
        if mentioned:
            payload["user_mentioned"] = mentioned
        try:
            data = self._ask_llm(PRESENT_PROMPT, payload, "minimal")
        except Exception as e:
            logger.warning(f"[HybridTriageController] Phrasing failed, using the template: {e}")
            session.template_fallbacks += 1
            return say, fixed
        lead = data.get("text")
        if not self._lead_ok(lead, "?" in say, session.subject == "self"):
            logger.warning(f"[HybridTriageController] Phrasing rejected, using the template: {lead!r}")
            session.template_fallbacks += 1
            lead = say
        translated = data.get("fixed")
        if translate and isinstance(translated, list) and len(translated) == len(fixed) and all(
                isinstance(t, str) and t.strip() and _DIGITS.findall(t) == _DIGITS.findall(o) and "911" not in t
                for t, o in zip(translated, fixed)):
            fixed = [t.strip() for t in translated]
        return lead.strip(), fixed

    @staticmethod
    def _lead_ok(lead: Any, must_ask: bool, for_self: bool = False) -> bool:
        if not isinstance(lead, str) or not lead.strip() or len(lead) > MAX_LEAD_CHARS:
            return False
        if _BANNED.search(lead):
            return False
        if for_self and re.search(rf"\b{_THE_PERSON}\b", lead, re.IGNORECASE):
            return False  # the user is the patient: they are "you"
        return "?" in lead or not must_ask  # a question must still be asked
