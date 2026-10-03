import logging
from typing import List, Optional, Any, Dict
from langchain_core.messages import SystemMessage, HumanMessage, ToolMessage, BaseMessage
from app.core.llm import get_llm
from app.agents.prompts import TRIAGE_SYSTEM_PROMPT
from app.tools.triage_tool import evaluate_triage_rules
from app.tools.patient_history_tool import get_patient_history
from app.tools.hospital_data_tool import query_hospital_facilities
from app.tools.hospital_routing_tool import route_to_recommended_hospital
from app.tools.embedding_tool import search_medical_embeddings

logger = logging.getLogger(__name__)


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

    def _get_runnable(self):
        """Initializes the LLM bound with tools."""
        if self._agent_runnable is None:
            llm = get_llm()
            # Bind tools to the Groq Chat model
            try:
                self._agent_runnable = llm.bind_tools(self.tools)
            except Exception as e:
                logger.warning(f"Could not bind tools to LLM (placeholder mode): {e}")
                self._agent_runnable = llm
        return self._agent_runnable

    def run(self, message: str, context: Optional[Dict[str, Any]] = None) -> str:
        """Run the agentic triage workflow for a patient message with tool execution."""
        logger.info(f"[MedicalTriageAgent] Processing query: '{message[:60]}...'")
        
        try:
            runnable = self._get_runnable()
            system_prompt = TRIAGE_SYSTEM_PROMPT
            if context:
                system_prompt += f"\n\nActive Patient Context: {context}"

            messages: List[BaseMessage] = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=message)
            ]

            # Execute agent reasoning and tool invocation loop (up to 3 turns)
            max_turns = 3
            final_reply = ""

            for turn in range(max_turns):
                response = runnable.invoke(messages)
                tool_calls = getattr(response, "tool_calls", None) or []

                # If the model requested tool calls, execute them and feedback results
                if tool_calls:
                    messages.append(response)
                    for tc in tool_calls:
                        tool_name = tc.get("name")
                        tool_args = tc.get("args", {})
                        tool_id = tc.get("id") or f"call_{turn}"
                        logger.info(f"[MedicalTriageAgent] Invoking tool '{tool_name}' with args: {tool_args}")
                        
                        tool_instance = self._tool_map.get(tool_name)
                        if tool_instance:
                            try:
                                tool_result = tool_instance.invoke(tool_args)
                            except Exception as tool_err:
                                logger.error(f"[MedicalTriageAgent] Tool execution error for {tool_name}: {tool_err}")
                                tool_result = f"Tool execution failed: {tool_err}"
                        else:
                            tool_result = f"Tool '{tool_name}' not found."

                        messages.append(ToolMessage(content=str(tool_result), tool_call_id=tool_id))
                    # Continue loop to allow model to synthesize final reply
                    continue

                # No more tool calls, extract response text
                text_content = _extract_text(getattr(response, "content", ""))
                if text_content:
                    final_reply = text_content
                    break

            if not final_reply:
                # If still empty after loop, provide safe triage advice
                final_reply = (
                    "Your symptoms have been analyzed. If you are experiencing sudden weakness, numbness, "
                    "severe pain, or life-threatening symptoms, please call emergency services (911/999) "
                    "or proceed immediately to the nearest Emergency Department."
                )

            return final_reply

        except Exception as e:
            logger.error(f"[MedicalTriageAgent] Agent invocation error: {e}")
            return (
                "MedicTri Triage Agent initialized. "
                f"(Placeholder mode: LLM not configured or offline. Query received: '{message}')"
            )
