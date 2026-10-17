# Handoff (delete once read)

Context from the previous session. CLAUDE.md has the rules; this has what happened and what is next.

## State
- Backend: 63 tests pass (`cd backend; venv\Scripts\python.exe -m pytest -q`). Nothing is committed.
- Triage engine: `backend/app/services/triage_rules_engine.py`. Agent: `backend/app/agents/triage_agent.py`. Prompt: `backend/app/agents/prompts.py`. Tool: `backend/app/tools/triage_tool.py`. Chat route: `backend/app/api/routes/triage.py`.
- KB `backend/app/tools/mts_screening_kb.json` (v3.0.0) was rebuilt from `malaysiantriagescalenewrevised2019.pdf`: 27 categories, 172 rules, 643 conditions. The user approved this KB edit. The throwaway build script is gone, so edit the JSON directly, and always check changes against the PDF.
- The LLM is now Azure OpenAI `gpt-4.1-mini` (the user changed config and CLAUDE.md). The earlier Groq rate-limit problems should no longer apply.

## Not verified live
Because Groq's daily quota ran out, these were only tested at engine level, not in a live conversation with the agent: ongoing high chest pain -> Level 2, and the ongoing-seizure case (Level 2 + "call 999" advice). Mild chest pain -> Level 4 was verified live. A first step in the new session is to run these conversations live with the new LLM.

## Open items
1. `/api/triage/assess` (`TriageService`) is still a placeholder that always returns URGENT. It is not wired to the engine.
2. Frontend does not call `/api/triage/*` yet (questionnaire -> `/assess`, then chat follow-up via `/chat`).
3. `route_to_recommended_hospital`, `get_patient_history`, `query_hospital_facilities`, `search_medical_embeddings` are placeholders.
4. The user was asked whether to also drop "likely / possible" impressions a person can describe (e.g. likely rib fractures). Kept for now, not yet answered.
5. The user was asked whether other conditions should add "call 999" besides ongoing seizure (`emergency_advice` in the KB). Not yet answered.
6. Untracked `AGENT_GUIDELINES.md` is probably an old duplicate of CLAUDE.md; ask before deleting.
7. `triage_question_training.json` is unused and not aligned with the PDF.
