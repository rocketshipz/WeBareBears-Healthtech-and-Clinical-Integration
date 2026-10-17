import json
import logging
from typing import Optional, List
from langchain_core.tools import tool
from app.services.triage_rules_engine import get_triage_rules_engine

logger = logging.getLogger(__name__)


@tool
def evaluate_triage_rules(
    categories: List[str],
    present_condition_ids: Optional[List[str]] = None,
    absent_condition_ids: Optional[List[str]] = None,
    history_condition_ids: Optional[List[str]] = None,
    answered_question_ids: Optional[List[str]] = None,
    age_years: Optional[float] = None,
) -> str:
    """Compute the MTS 2019 triage level deterministically from the knowledge base.

    This is the ONLY source of a triage level. Report facts, not conclusions.

    Args:
        categories: KB screening category names relevant to the complaint (exact names from the
            condition catalogue). Critical First Look is always included automatically.
        present_condition_ids: Condition IDs (e.g. "RULE_CP_L2_01.C3") the user has reported as present.
        absent_condition_ids: Condition IDs the user's answers have ruled out.
        history_condition_ids: Condition IDs present because of the patient's documented history.
            Only for conditions whose text itself refers to history.
        answered_question_ids: KB question IDs (e.g. "Q_CP_01") already asked and answered.
        age_years: Patient age in years. Required unless a Level 1 condition is present.

    Returns:
        JSON with `status` ("classified" | "insufficient_information"), `triage_level`,
        `triage_name`, `triage_code`, `matched_rule_ids`, `missing_information`,
        `suggested_questions`, `unexplored_categories`, `call_999` and `source_references`.
    """
    result = get_triage_rules_engine().evaluate(
        categories=categories,
        present_condition_ids=present_condition_ids,
        absent_condition_ids=absent_condition_ids,
        history_condition_ids=history_condition_ids,
        answered_question_ids=answered_question_ids,
        age_years=age_years,
    )
    logger.info(
        f"[TriageTool] status={result['status']} level={result['triage_level']} "
        f"matched={result['matched_rule_ids']} missing={len(result['missing_information'])}"
    )
    # Drop empty fields to keep the agent's context (and token usage) small.
    compact = {k: v for k, v in result.items() if v not in (None, [], "")}
    compact["status"] = result["status"]
    compact["call_999"] = result["call_999"]
    return json.dumps(compact, ensure_ascii=False, separators=(",", ":"))
