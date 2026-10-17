import json
import logging
import uuid
from dataclasses import dataclass, field
from typing import List, Optional, Any, Dict
from langchain_core.messages import AIMessage, SystemMessage, HumanMessage, ToolMessage, BaseMessage
from app.core.llm import get_llm
from app.agents.prompts import TRIAGE_SYSTEM_PROMPT
from app.tools.triage_tool import evaluate_triage_rules
from app.tools.patient_history_tool import get_patient_history
from app.tools.hospital_data_tool import query_hospital_facilities
from app.tools.hospital_routing_tool import route_to_recommended_hospital
from app.tools.embedding_tool import search_medical_embeddings

logger = logging.getLogger(__name__)

# Tool-call rounds allowed per user message before the agent must reply.
MAX_TOOL_ROUNDS = 6

_SUPERSEDED = '{"superseded":"see the latest evaluate_triage_rules result"}'

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


@dataclass
class TriageSession:
    """Conversation memory and accumulated triage findings for one chat session."""
    session_id: str
    messages: List[BaseMessage] = field(default_factory=list)
    findings: Dict[str, Any] = field(default_factory=lambda: {k: [] for k in _FINDING_LISTS} | {"age_years": None})
    triage_result: Optional[Dict[str, Any]] = None

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

    def get_session(self, session_id: Optional[str], context: Optional[Dict[str, Any]] = None) -> TriageSession:
        """Return the existing session or start a new one with the system prompt."""
        if session_id and session_id in self._sessions:
            return self._sessions[session_id]
        session = TriageSession(session_id=session_id or str(uuid.uuid4()))
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
    ) -> TriageSession:
        """Run one turn and return the session (reply is the last message; triage_result is set if evaluated)."""
        logger.info(f"[MedicalTriageAgent] Processing query: '{message[:60]}...'")
        session = self.get_session(session_id, context)
        messages = session.messages
        messages.append(HumanMessage(content=message))

        try:
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

        except Exception as e:
            logger.error(f"[MedicalTriageAgent] Agent invocation error: {e}")
            messages.append(AIMessage(content=(
                "Sorry, the screening assistant is temporarily unavailable. Please try again in a moment. "
                "If you have any life-threatening symptoms, call 999 (or 112 from mobile) or go to the "
                "nearest Emergency Department now."
            )))

        return session
