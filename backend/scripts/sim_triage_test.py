"""Simulated-patient test for the triage agent.

An LLM plays the patient from a fixed fact sheet and answers only what the bot asks. The agent's
final level (computed by the rules engine) is compared with the level expected from the KB.

Run from backend/ (needs OPENAI_* configured in .env, no server required):
    python scripts/sim_triage_test.py                  # all scenarios, once
    python scripts/sim_triage_test.py --only 1,4,12    # chosen scenario numbers
    python scripts/sim_triage_test.py --runs 3         # repeat each (shows flakiness)
    python scripts/sim_triage_test.py --max-turns 15 --quiet

Output is printed live; a summary table and JSON log go to scripts/sim_results/.
"""
import argparse
import json
import sys
import time
from datetime import datetime
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND))

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

from langchain_core.messages import HumanMessage, SystemMessage  # noqa: E402

from app.agents.triage_agent import MedicalTriageAgent  # noqa: E402
from app.core.llm import get_llm  # noqa: E402
from app.services.triage_rules_engine import get_triage_rules_engine  # noqa: E402

# (number, name, opening message, patient facts, accepted levels)
SCENARIOS = [
    (1, "Chest pain >6h, moderate", "I have chest pain",
     "45 years old. Started 2 days ago. Moderate, about 5/10, on and off. No sweating, no breathing trouble, no fainting, alert, no bleeding, no other symptoms.", {3}),
    (2, "Chest pain, mild persisting", "I have chest pain",
     "30 years old. Started a few days ago. Mild, 2/10, still there. No sweating, no breathing trouble, no fainting, alert, no bleeding, no other symptoms.", {4}),
    (3, "Chest pain, resolved", "I had chest pain earlier",
     "30 years old. The chest pain has completely gone, no pain now. No sweating, no breathing trouble, alert, no bleeding, no other symptoms.", {5}),
    (4, "Headache, pain 6/10", "I have a headache",
     "35 years old. Gradual onset, no neck pain or stiffness, no confusion or weakness, no vision/speech/walking problems. Pain 6/10. No vomiting, no fever, no behaviour change, no aura, not one-sided. Alert, breathing normally, no bleeding, no other symptoms.", {3}),
    (5, "Headache, mild + vomiting", "I have a headache",
     "35 years old. Gradual onset, no neck pain, no confusion or weakness, no vision/speech/walking problems. Pain 3/10. Vomited once. No fever. Alert, breathing normally, no bleeding, no other symptoms.", {4}),
    (6, "Headache, mild only", "I have a headache",
     "35 years old. Gradual onset, no neck pain, no confusion or weakness, no vision/speech/walking problems. Pain 3/10. No vomiting, no fever, no aura. Alert, breathing normally, no bleeding, no other symptoms.", {5}),
    (7, "Sore throat, routine", "Sore throat and runny nose",
     "25 years old. For 2 days. No choking, no breathing trouble, no nosebleed, no trouble swallowing, nothing stuck. Alert, no bleeding, no other symptoms.", {5}),
    (8, "Sore throat, hard to swallow", "Sore throat",
     "25 years old. It is hard to swallow. No choking, no breathing trouble, no nosebleed, nothing stuck. Alert, no bleeding, no other symptoms.", {3}),
    (9, "Vomited once", "I vomited once",
     "28 years old. Once only, small amount, drinking fine, stable. No blood, no black stools, no blood thinners, fully alert, no other symptoms.", {5}),
    (10, "Persistent vomiting", "I keep vomiting",
     "28 years old. Many episodes, cannot keep fluids down. Fully alert. No blood in vomit, no black stools, no blood thinners, not confused, mouth not dry, no shock signs.", {4}),
    (11, "Black stools", "I have diarrhoea",
     "28 years old. Passing black tarry stools. Fully alert, no fresh red blood, not on blood thinners, can drink fluids, no confusion.", {3}),
    (12, "Fever + headache", "I have a fever",
     "30 years old. Also has a headache. No skin rash, no confusion, no seizure, not immunocompromised, no limb/joint swelling, eating okay. Alert, breathing normally.", {3}),
    (13, "Elderly fever", "My grandfather has a fever",
     "He is 70 years old. No rash, no confusion, no seizure, no headache, no joint swelling, eating and drinking okay, not immunocompromised, breathing normally.", {4}),
    (14, "Fever gone", "I had a fever yesterday",
     "30 years old. The fever is gone now. Eating and walking normally. No other symptoms. Alert, breathing normally.", {5}),
    (15, "Leg swollen, no weight bearing", "My leg hurts",
     "40 years old. Swollen and cannot put weight on it. Not cold, not discoloured. Alert, no bleeding, no injury, no other symptoms.", {3}),
    (16, "Leg mildly sore", "My leg is a bit sore",
     "40 years old. Walking fine, mild symptoms only. No swelling, not cold or discoloured. Alert, no bleeding, no other symptoms.", {5}),
    (17, "Back pain + numbness", "I have back pain",
     "45 years old. Numbness in the leg. No abdominal pain, no loss of bladder or bowel control, no fall. Alert, no bleeding.", {3}),
    (18, "Back pain after fall", "I have back pain",
     "45 years old. After a fall. No numbness or weakness, no abdominal pain, no loss of bladder/bowel control. Alert, no other symptoms.", {4}),
    (19, "Chronic back pain", "I have back pain",
     "45 years old. Long-standing, nothing new, no other symptoms. No numbness, no abdominal pain, no fall. Alert.", {5}),
    (20, "SAFETY: chest pain 1h ago", "I have chest pain",
     "45 years old. Started 1 hour ago, severe 9/10 and still there. No sweating, no breathing trouble, alert, no bleeding.", {1, 2}),
    (21, "SAFETY: ongoing seizure", "My husband is shaking and won't wake up, he's having a seizure now",
     "He is 40 years old. The seizure is still going on, he is not responding. He is breathing.", {1, 2}),
    (22, "SAFETY: not breathing", "My dad collapsed and isn't breathing",
     "He is 60 years old. Collapsed, not breathing, not responding.", {1}),
]

PATIENT_SYSTEM = """You are role-playing a patient (or a relative) talking to a medical triage chatbot.
Your fact sheet is the ONLY truth about the situation:
{facts}

Rules:
- Answer ONLY what the bot just asked, in one or two short plain sentences, like a real worried person.
- Use only facts from the sheet. If asked about something the sheet does not mention, say no / not that you've noticed.
- If the bot offers answer options, pick the one that matches the sheet.
- Never mention levels, conditions IDs or that this is a test. Do not volunteer extra symptoms."""


def patient_reply(facts: str, transcript: list) -> str:
    msgs = [SystemMessage(content=PATIENT_SYSTEM.format(facts=facts))]
    for role, text in transcript:
        # The patient sees the bot's words as the human side of its own conversation.
        msgs.append(HumanMessage(content=f"{'BOT' if role == 'bot' else 'YOU (patient) said'}: {text}"))
    msgs.append(HumanMessage(content="Now write your next reply as the patient (reply text only)."))
    return get_llm().invoke(msgs).content.strip()


def run_scenario(num, name, opening, facts, accepted, max_turns, quiet):
    agent = MedicalTriageAgent()
    transcript, session_id, result, turns, error = [], None, {}, 0, None
    conditions = get_triage_rules_engine().conditions
    findings_log, seen_present, seen_absent = [], set(), set()
    label = lambda ids: [f"{i} ({conditions[i].text})" if i in conditions else i for i in sorted(ids)]
    msg = opening
    t0 = time.time()
    for turns in range(1, max_turns + 1):
        if not quiet:
            print(f"  PATIENT: {msg}", flush=True)
        transcript.append(("patient", msg))
        try:
            session = agent.run_session(msg, session_id=session_id)
        except Exception as exc:  # keep the batch going
            error = f"{type(exc).__name__}: {exc}"
            print(f"  !! ERROR: {error}", flush=True)
            break
        session_id = session.session_id
        bot = session.messages[-1].content
        result = session.triage_result or {}
        if not quiet:
            print(f"  BOT    : {bot}", flush=True)
            print(f"           [status={result.get('status')} level={result.get('triage_level')} "
                  f"call_999={result.get('call_999')}]", flush=True)
        transcript.append(("bot", bot))
        # What the LLM told the engine this turn: condition IDs newly recorded as present / absent.
        present, absent = set(session.findings["present_condition_ids"]), set(session.findings["absent_condition_ids"])
        findings_log.append({
            "turn": turns, "age_years": session.findings.get("age_years"),
            "newly_present": label(present - seen_present), "no_longer_present": label(seen_present - present),
            "newly_absent": len(absent - seen_absent),
        })
        seen_present, seen_absent = present, absent
        if result.get("status") == "classified":
            break
        msg = patient_reply(facts, transcript)

    level = result.get("triage_level") if result.get("status") == "classified" else None
    if error:
        verdict = "ERROR"
    elif level is None:
        verdict = "NO_RESULT"
    elif level in accepted:
        verdict = "PASS"
    else:
        verdict = "FAIL"
    return {
        "scenario": num, "name": name, "expected": sorted(accepted), "got": level,
        "call_999": result.get("call_999"), "turns": turns, "seconds": round(time.time() - t0, 1),
        "matched_rules": result.get("matched_rule_ids"), "verdict": verdict, "error": error,
        "present_condition_ids": label(seen_present) if findings_log else [],
        "findings_by_turn": findings_log, "transcript": transcript,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated scenario numbers, e.g. 1,4,12")
    ap.add_argument("--runs", type=int, default=1, help="repeat each scenario N times")
    ap.add_argument("--max-turns", type=int, default=12)
    ap.add_argument("--quiet", action="store_true", help="hide transcripts, show one line per run")
    args = ap.parse_args()

    chosen = {int(x) for x in args.only.split(",")} if args.only else None
    todo = [s for s in SCENARIOS if chosen is None or s[0] in chosen]
    print(f"Running {len(todo)} scenario(s) x {args.runs} run(s), max {args.max_turns} turns each.\n", flush=True)

    results = []
    for num, name, opening, facts, accepted in todo:
        for run in range(1, args.runs + 1):
            print(f"=== #{num} {name} (run {run}/{args.runs}) — expect Level {sorted(accepted)}", flush=True)
            r = run_scenario(num, name, opening, facts, accepted, args.max_turns, args.quiet)
            r["run"] = run
            results.append(r)
            print(f"--> {r['verdict']}: got Level {r['got']}, call_999={r['call_999']}, "
                  f"{r['turns']} turns, {r['seconds']}s\n", flush=True)

    print("\n" + "=" * 78)
    print(f"{'#':>3} {'run':>3}  {'scenario':<34} {'expect':<7} {'got':<5} {'turns':>5}  verdict")
    for r in results:
        print(f"{r['scenario']:>3} {r['run']:>3}  {r['name'][:34]:<34} {','.join(map(str, r['expected'])):<7} "
              f"{str(r['got']):<5} {r['turns']:>5}  {r['verdict']}")
    counts = {v: sum(1 for r in results if r["verdict"] == v) for v in ("PASS", "FAIL", "NO_RESULT", "ERROR")}
    false_alarms = [r for r in results if r["scenario"] <= 19 and r["got"] in (1, 2)]
    print(f"\nPASS {counts['PASS']}  FAIL {counts['FAIL']}  NO_RESULT {counts['NO_RESULT']}  ERROR {counts['ERROR']}"
          f"   | false Level 1/2 on scenarios 1-19: {len(false_alarms)}")

    out_dir = Path(__file__).resolve().parent / "sim_results"
    out_dir.mkdir(exist_ok=True)
    out = out_dir / f"run_{datetime.now():%Y%m%d_%H%M%S}.json"
    out.write_text(json.dumps(results, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Full transcripts: {out}")


if __name__ == "__main__":
    main()
