import json
import logging
import re
import uuid
from dataclasses import dataclass, field
from typing import List, Optional, Any, Dict
from langchain_core.messages import AIMessage, SystemMessage, HumanMessage, ToolMessage, BaseMessage
from app.core.llm import get_llm
from app.agents.prompts import TRIAGE_SYSTEM_PROMPT
from app.services.triage_rules_engine import NONE_ANSWERS, get_triage_rules_engine
from app.tools.triage_tool import evaluate_triage_rules
from app.tools.patient_history_tool import get_patient_history
from app.tools.hospital_data_tool import query_hospital_facilities
from app.tools.hospital_routing_tool import route_to_recommended_hospital
from app.tools.embedding_tool import search_medical_embeddings

logger = logging.getLogger(__name__)

# Tool-call rounds allowed per user message before the agent must reply.
MAX_TOOL_ROUNDS = 6

_SUPERSEDED = '{"superseded":"see the latest evaluate_triage_rules result"}'

# Reply when the LLM provider's content filter refuses the user's message (most often self-harm wording).
_FILTERED_REPLY = (
    "I'm sorry you're going through this, and I'm glad you reached out. If you are thinking about hurting "
    "yourself or are in danger, please call 999 now (112 from a mobile phone) or go to the nearest Emergency "
    "Department. If you can, stay with someone you trust until you get help. You are not alone."
)
_FILTERED_PLACEHOLDER = (
    "[The user's previous message could not be processed. It may have described a mental health crisis. "
    "Urgent advice to call 999 or go to the nearest Emergency Department has already been given. "
    "Continue the screening: ask for anything you still need, such as age.]"
)
PSYCHIATRIC_CATEGORY = "Psychiatric & Behavioural"
_SELF_HARM_FILTERED = re.compile(r"""['"]self_harm['"]\s*:\s*\{\s*['"]filtered['"]\s*:\s*True""")

# After this many turns with nothing left to ask and nothing matched, the agent must stop fishing for symptoms.
STALL_LIMIT = 2
_STALL_NOTE = (
    "App note: nothing in the screened categories matched and the user has already been asked about other "
    "symptoms. Do NOT ask about other symptoms again. If the user's latest message reports a new symptom, add "
    "its category and re-evaluate. Otherwise stop now: say the screening could not assign a level, and advise "
    "prompt in-person medical assessment (call 999 if any danger sign appears)."
)

_FINDING_LISTS = ("categories", "present_condition_ids", "absent_condition_ids",
                  "history_condition_ids", "answered_question_ids")


def _extract_text(content: Any) -> str:
    """Helper to safely extract string text from various LLM response content types."""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        extracted_parts = []
        for item in content:
            if isinstance(item, str):
                extracted_parts.append(item)
            elif isinstance(item, dict):
                if "text" in item and item["text"]:
                    extracted_parts.append(str(item["text"]))
                elif "content" in item and item["content"]:
                    extracted_parts.append(str(item["content"]))
        return "\n".join(extracted_parts).strip()
    return str(content) if content is not None else ""


def _strip_code_fence(text: str) -> str:
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else ""
        text = text.rsplit("```", 1)[0]
    return text.strip()


def parse_structured_reply(text: str, triage_result: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Turn the LLM's final reply into {type, question, response}.

    type is "text" (response is a string) or "selection" (response is a list of options, question is the prompt).
    Selection options must come from the KB answers of the latest triage result; anything else is dropped.
    Falls back to plain text when the reply is not valid structured JSON.
    """
    fallback = {"type": "text", "question": None, "response": text}
    try:
        data = json.loads(_strip_code_fence(text))
    except (ValueError, TypeError):
        return fallback
    if not isinstance(data, dict):
        return fallback

    reply_type, response = data.get("type"), data.get("response")
    if reply_type == "text" and isinstance(response, str) and response.strip():
        return {"type": "text", "question": None, "response": response.strip()}

    if reply_type == "selection" and isinstance(response, list):
        question = str(data.get("question") or "").strip()
        suggested = (triage_result or {}).get("suggested_questions", [])
        allowed = {a for q in suggested for a in q.get("answers", [])}
        options = [o for o in response if isinstance(o, str) and o in allowed and o != NOT_SURE]
        options = list(dict.fromkeys(options))
        if question and options:
            reply = {"type": "selection", "question": question, "response": options}
            # The KB question these options came from (the one offering the most of them).
            source = max(suggested, key=lambda q: len(set(options) & set(q.get("answers", []))))
            if source.get("question_id") and set(options) & set(source.get("answers", [])):
                # The KB question has none_answers / multi_select; fall back to the suggestion if unknown.
                source = get_triage_rules_engine().questions_by_id.get(source["question_id"], source)
                # The LLM sometimes sends only an acknowledgement: make sure the question itself is shown.
                if "?" not in question and source.get("text") and source["text"].lower() not in question.lower():
                    reply["question"] = f"{question} {source['text']}".strip()
                reply.update(kb_selection(source))
                return reply
            options.append(NOT_SURE)
            return reply
        if question:
            return {"type": "text", "question": None, "response": question}

    return fallback


NOT_SURE = "Not sure"


def kb_selection(question: Dict[str, Any]) -> Dict[str, Any]:
    """Options the app offers for a KB question: {response, question_id, multi_select?, exclusive_options?}."""
    answers = question.get("answers", [])
    # Options not picked are recorded as absent, so always offer the question's full KB list.
    options = list(answers)
    # Always offer a way to say "none": the question's own none answers, else "None of these".
    nones = question.get("none_answers") or [a for a in answers if a in NONE_ANSWERS or a == "No"]
    if not nones and len(answers) > 2:
        nones = [NONE_ANSWERS[0]]
    options.extend(a for a in nones if a not in options)
    reply = {"response": options, "question_id": question["question_id"]}
    if question.get("multi_select"):
        reply["multi_select"] = True
        # Ticking one of these clears the others (and vice versa).
        reply["exclusive_options"] = [a for a in options if a in nones] + [NOT_SURE]
    options.append(NOT_SURE)
    return reply


def selection_findings(last_output: Optional[Dict[str, Any]], message: str,
                       selected: Optional[List[str]] = None) -> Optional[Dict[str, Any]]:
    """Findings for the option(s) picked from the previous selection, decided by the KB, not by the LLM."""
    if not last_output or last_output.get("type") != "selection" or not last_output.get("question_id"):
        return None
    picked = [s.strip() for s in selected] if selected else [message.strip()]
    if not picked or any(p not in last_output["response"] for p in picked):
        return None
    return get_triage_rules_engine().apply_answers(last_output["question_id"], picked)


@dataclass
class TriageSession:
    """Conversation memory and accumulated triage findings for one chat session."""
    session_id: str
    messages: List[BaseMessage] = field(default_factory=list)
    findings: Dict[str, Any] = field(default_factory=lambda: {k: [] for k in _FINDING_LISTS} | {"age_years": None})
    triage_result: Optional[Dict[str, Any]] = None
    last_output: Optional[Dict[str, Any]] = None  # structured reply of the latest turn
    # Consecutive turns ending with nothing left to ask and nothing matched (the agent is fishing for symptoms).
    stalled_turns: int = 0
    # The logged-in user who started this screening (None if anonymous). Only they may continue it.
    owner_id: Optional[str] = None
    # The user's own words for their main problem: the message in which a complaint was first recorded
    # (a complaint category or a danger sign), so a greeting like "hi" never becomes the symptom.
    chief_complaint: Optional[str] = None
    # Short summary of the main symptom for the report, written once the screening is classified.
    main_symptom: Optional[str] = None

    def has_complaint(self) -> bool:
        return bool(self.findings["categories"] or self.findings["present_condition_ids"])

    def merge_findings(self, args: Dict[str, Any]) -> Dict[str, Any]:
        """Merge new tool-call findings into the session; later answers correct earlier ones."""
        f = self.findings
        new_present = set(args.get("present_condition_ids") or [])
        new_absent = set(args.get("absent_condition_ids") or []) - new_present

        f["present_condition_ids"] = sorted((set(f["present_condition_ids"]) - new_absent) | new_present)
        f["absent_condition_ids"] = sorted((set(f["absent_condition_ids"]) - new_present) | new_absent)
        for key in ("categories", "history_condition_ids", "answered_question_ids"):
            f[key] = list(dict.fromkeys(f[key] + list(args.get(key) or [])))
        if args.get("age_years") is not None:
            f["age_years"] = args["age_years"]
        return dict(f)


class MedicalTriageAgent:
    """Agentic AI orchestrator for medical emergency triage and hospital routing."""

    def __init__(self):
        self.tools = [
            evaluate_triage_rules,
            get_patient_history,
            query_hospital_facilities,
            route_to_recommended_hospital,
            search_medical_embeddings
        ]
        self._tool_map = {tool.name: tool for tool in self.tools}
        self._llm = None
        self._agent_runnable = None
        # In-memory only: sessions are lost on server restart (fine for the demo).
        self._sessions: Dict[str, TriageSession] = {}

    def _get_runnable(self):
        """Initializes the LLM bound with tools."""
        if self._agent_runnable is None:
            llm = get_llm()
            # Bind tools to the chat model
            try:
                self._agent_runnable = llm.bind_tools(self.tools)
            except Exception as e:
                logger.warning(f"Could not bind tools to LLM (placeholder mode): {e}")
                self._agent_runnable = llm
        return self._agent_runnable

    def has_session(self, session_id: Optional[str]) -> bool:
        return bool(session_id) and session_id in self._sessions

    def session_owner(self, session_id: Optional[str]) -> Optional[str]:
        session = self._sessions.get(session_id) if session_id else None
        return session.owner_id if session else None

    def get_session(self, session_id: Optional[str], context: Optional[Dict[str, Any]] = None) -> TriageSession:
        """Return the existing session or start a new one with the system prompt."""
        if session_id and session_id in self._sessions:
            return self._sessions[session_id]
        session = TriageSession(session_id=session_id or str(uuid.uuid4()),
                                owner_id=(context or {}).get("patient_id"))
        system_prompt = TRIAGE_SYSTEM_PROMPT
        if context:
            system_prompt += f"\n\nActive Patient Context: {context}"
        session.messages.append(SystemMessage(content=system_prompt))
        self._sessions[session.session_id] = session
        return session

    def _invoke_tool(self, session: TriageSession, tool_name: str, tool_args: Dict[str, Any]) -> str:
        tool_instance = self._tool_map.get(tool_name)
        if not tool_instance:
            return f"Tool '{tool_name}' not found."
        try:
            if tool_name == evaluate_triage_rules.name:
                # Evaluate against everything learned so far in this session, not just this call.
                tool_args = session.merge_findings(tool_args)
                result = tool_instance.invoke(tool_args)
                session.triage_result = json.loads(result)
                self._supersede_old_triage_results(session)
                return result
            return str(tool_instance.invoke(tool_args))
        except Exception as tool_err:
            logger.error(f"[MedicalTriageAgent] Tool execution error for {tool_name}: {tool_err}")
            return f"Tool execution failed: {tool_err}"

    def _supersede_old_triage_results(self, session: TriageSession) -> None:
        """Shrink earlier triage tool results; the session's merged findings make them redundant."""
        triage_call_ids = {
            tc.get("id")
            for m in session.messages
            for tc in (getattr(m, "tool_calls", None) or [])
            if tc.get("name") == evaluate_triage_rules.name
        }
        for m in session.messages:
            if isinstance(m, ToolMessage) and m.tool_call_id in triage_call_ids:
                m.content = _SUPERSEDED

    def _record_selection(self, session: TriageSession, message: str, selected: Optional[List[str]] = None) -> None:
        """If the user picked option(s) of the last selection, record them straight from the KB mapping.

        Shown to the LLM as an evaluate_triage_rules call it already made, so it continues from the fresh result.
        """
        findings = selection_findings(session.last_output, message, selected)
        if findings is None:
            return
        call_id = f"selection_{uuid.uuid4().hex[:8]}"
        session.messages.append(AIMessage(
            content="", tool_calls=[{"name": evaluate_triage_rules.name, "args": findings, "id": call_id}]
        ))
        result = self._invoke_tool(session, evaluate_triage_rules.name, findings)
        session.messages.append(ToolMessage(content=result, tool_call_id=call_id))

    @staticmethod
    def _drop_filtered_turn(session: TriageSession, message: str) -> None:
        """Remove this turn's messages, replacing the refused user message with a neutral placeholder."""
        messages = session.messages
        for i in range(len(messages) - 1, -1, -1):
            if isinstance(messages[i], HumanMessage) and messages[i].content == message:
                del messages[i:]
                break
        messages.append(HumanMessage(content=_FILTERED_PLACEHOLDER))

    def _invoke_llm(self, runnable, messages: List[BaseMessage]):
        """Invoke the LLM, retrying once if the provider rejects a malformed tool call (e.g. JSON with comments)."""
        try:
            return runnable.invoke(messages)
        except Exception as e:
            if "tool_use_failed" not in str(e):
                raise
            logger.warning(f"[MedicalTriageAgent] Malformed tool call, retrying once: {e}")
            return runnable.invoke(messages)

    def run(
        self,
        message: str,
        context: Optional[Dict[str, Any]] = None,
        session_id: Optional[str] = None,
    ) -> str:
        """Run one conversational turn of the agentic triage workflow."""
        return self.run_session(message, context, session_id).messages[-1].content

    def run_session(
        self,
        message: str,
        context: Optional[Dict[str, Any]] = None,
        session_id: Optional[str] = None,
        selected_options: Optional[List[str]] = None,
        note: Optional[str] = None,
    ) -> TriageSession:
        """Run one turn and return the session (reply is the last message; triage_result is set if evaluated).

        `selected_options`: the option(s) the user picked from the previous selection (several for multi_select).
        `note`: optional extra details typed alongside the pick.
        """
        logger.info(f"[MedicalTriageAgent] Processing query: '{message[:60]}...'")
        if note and note.strip():
            message = f"{message}\nMore details: {note.strip()}"
        session = self.get_session(session_id, context)
        messages = session.messages
        messages.append(HumanMessage(content=message))
        had_complaint = session.has_complaint()

        try:
            self._record_selection(session, message, selected_options)
            if session.stalled_turns >= STALL_LIMIT:
                messages.append(SystemMessage(content=_STALL_NOTE))
            runnable = self._get_runnable()
            final_reply = ""

            for turn in range(MAX_TOOL_ROUNDS + 1):
                response = self._invoke_llm(runnable, messages)
                tool_calls = getattr(response, "tool_calls", None) or []

                if tool_calls and turn < MAX_TOOL_ROUNDS:
                    messages.append(response)
                    for tc in tool_calls:
                        tool_name = tc.get("name")
                        tool_args = tc.get("args", {})
                        tool_id = tc.get("id") or f"call_{turn}"
                        logger.info(f"[MedicalTriageAgent] Invoking tool '{tool_name}' with args: {tool_args}")
                        tool_result = self._invoke_tool(session, tool_name, tool_args)
                        messages.append(ToolMessage(content=tool_result, tool_call_id=tool_id))
                    continue

                text_content = _extract_text(getattr(response, "content", ""))
                if text_content:
                    final_reply = text_content
                    messages.append(response)
                break

            if not final_reply:
                final_reply = (
                    "I could not complete the screening right now. If you are experiencing sudden weakness, "
                    "numbness, severe pain, or any life-threatening symptoms, please call 999 (or 112 from "
                    "mobile) or go to the nearest Emergency Department immediately."
                )
                messages.append(AIMessage(content=final_reply))
            session.last_output = parse_structured_reply(final_reply, session.triage_result)
            result = session.triage_result or {}
            nothing_left = result.get("status") == "insufficient_information" and not result.get("missing_information")
            session.stalled_turns = session.stalled_turns + 1 if nothing_left else 0
            if session.chief_complaint is None and not had_complaint and session.has_complaint():
                session.chief_complaint = message

        except Exception as e:
            logger.error(f"[MedicalTriageAgent] Agent invocation error: {e}")
            if "content_filter" in str(e):
                # The provider refused the user's message (e.g. self-harm wording). Never answer that with
                # "service unavailable": give the urgent advice, and drop the message so the session still works.
                self._drop_filtered_turn(session, message)
                if _SELF_HARM_FILTERED.search(str(e)):
                    # Screen the matching category; the person still confirms the KB items themselves.
                    session.merge_findings({"categories": [PSYCHIATRIC_CATEGORY]})
                messages.append(AIMessage(content=_FILTERED_REPLY))
                session.last_output = {"type": "text", "question": None, "response": _FILTERED_REPLY}
                return session
            error_reply = (
                "Sorry, the screening assistant is temporarily unavailable. Please try again in a moment. "
                "If you have any life-threatening symptoms, call 999 (or 112 from mobile) or go to the "
                "nearest Emergency Department now."
            )
            messages.append(AIMessage(content=error_reply))
            session.last_output = {"type": "text", "question": None, "response": error_reply}

        return session
