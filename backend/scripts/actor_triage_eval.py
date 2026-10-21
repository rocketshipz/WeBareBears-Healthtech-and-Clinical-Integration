"""Low-acuity triage evaluation with an LLM ACTOR patient (hybrid mode).

scripted_triage_eval.py taps fixed answers per KB question. This one lets a second LLM play the patient from a
short persona (hidden facts, in everyday words), so it tests how a layperson reads the questions and options:
e.g. whether an ordinary headache gets rated "moderate" or a sore throat ticks "difficulty swallowing".
Cases are the clinic-type complaints that should end at Level 4-5 (one known PDF exception is marked).

Run from backend/ (needs OPENAI_* in .env):
    python scripts/actor_triage_eval.py                    # all cases, 2 runs each
    python scripts/actor_triage_eval.py --only 1,3 --runs 3 -v
    python scripts/actor_triage_eval.py --kb old_kb.json   # baseline: same cases against another KB file
Results: printed summary + JSON in scripts/sim_results/actor_<timestamp>.json
"""
import argparse
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor
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

from app.services import triage_rules_engine  # noqa: E402

# (id, name, opening message, persona facts, expected levels, note)
CASES = [
    (1, "Sore throat", "I have a sore throat",
     "You are 28. Sore throat for 2 days. It hurts when you swallow, but you are eating and drinking normally "
     "and can swallow your saliva fine. No fever, no cough, breathing is fine. You feel a bit tired but are "
     "still going to work.", {5}, ""),
    (2, "Mild headache", "I've had a headache since this morning",
     "You are 35. Dull headache since this morning, both sides, came on slowly. It is annoying; if forced to give "
     "a number you would say around 5 out of 10, but you are still working at your desk. No fever, no vomiting, "
     "vision and speech normal, no neck stiffness. You get headaches like this now and then.", {4, 5}, ""),
    (3, "Fever + sore throat + headache", "I have fever, sore throat and headache",
     "You are 25. Fever since yesterday (felt hot, 38.2 on a home thermometer). Sore throat, hurts to swallow but "
     "you can eat and drink. Mild headache that came with the fever. No rash, no vomiting, walking around fine.",
     {4}, "fever + mild headache = Headache 'Associated fever' (KB product decision, Oct 2026)"),
    (4, "Fever + sore throat", "I have a fever and sore throat",
     "You are 30. Fever since yesterday (37.9 at home). Sore throat, hurts to swallow, but eating and drinking "
     "fine. No headache, no rash, no vomiting, no breathing trouble. Walking around normally.", {4, 5}, ""),
    (5, "Common cold", "I have a cough and runny nose",
     "You are 30. Runny nose and cough for 3 days, like a usual cold. Not breathless, no wheeze, talking "
     "normally. No fever now. Eating and drinking fine.", {4, 5}, ""),
    (6, "Twisted ankle", "I twisted my ankle playing futsal",
     "You are 22. Twisted your right ankle 2 hours ago playing futsal. A little swollen, sore when you walk "
     "but you can walk on it with a slight limp. It does not look bent or broken. No other injury, did not hit "
     "your head.", {4, 5}, ""),
    (7, "Low back pain", "My lower back hurts",
     "You are 45. Lower back ache for 3 days after lifting boxes. You have had back aches before. You can walk "
     "normally. No numbness or weakness in the legs, no problems peeing or pooing, no fever, no injury.",
     {4, 5}, ""),
    (8, "Mild diarrhoea", "I have diarrhoea",
     "You are 30. Loose stools 3 times since this morning after eating out. Mild tummy cramps that come and go. "
     "No blood, not black. Vomited once this morning, none since. Drinking fine, peeing normally.", {4, 5}, ""),
    (9, "Earache", "My ear hurts",
     "You are 30. Left earache for 2 days, mild. Hearing a bit muffled. No discharge, no injury, nothing stuck "
     "in the ear. No fever, no dizziness.", {4, 5}, ""),
    (10, "Itchy rash", "I have an itchy rash on my arm",
     "You are 27. Itchy red rash on your forearm since yesterday, after using a new soap. No swelling of face, "
     "lips or tongue, breathing fine, no fever, rash is only on that arm.", {4, 5}, ""),
    (11, "Red itchy eye", "My eye is red and itchy",
     "You are 33. Right eye red, itchy and watery since yesterday. Vision is normal, no injury, nothing "
     "splashed into the eye, mild discomfort only. You do not wear contact lenses.", {4, 5}, ""),
    (12, "Burning urination", "It burns when I pee",
     "You are 26, female. Burning when you pee and needing to pee often for 2 days. No fever, no back pain, "
     "no blood in urine you can see. Not pregnant. Otherwise well.", {4, 5}, ""),
    (13, "Fever only", "I have a fever",
     "You are 30. Fever since yesterday (38.0 at home), mild body aches. No headache, no sore throat, no rash, "
     "no vomiting. Eating and drinking ok, walking around normally.", {5}, ""),
    (14, "Small cut", "I cut my finger while cooking",
     "You are 40. Small cut on your left index finger from a kitchen knife 30 minutes ago. Bleeding stopped "
     "after pressing it. You can move the finger normally, feeling is normal. Up to date with tetanus.",
     {4, 5}, ""),
]

ACTOR_PROMPT = """You are role-playing a patient in Malaysia who is using a triage chat app on their phone.
Your facts (the only truth about you):
{persona}

Rules:
- Answer as this ordinary person would: short, everyday words, no medical jargon.
- Only report what your facts say. If the app asks about something your facts do not mention, you do not have it.
- Read every option carefully and pick the one(s) that honestly fit your facts. Do not exaggerate or downplay.
- The screening is for yourself.

You receive the app's last message and its options (if any). Reply with JSON only:
{{"selected": [<exact option texts you tap, or empty list>], "message": "<what you type; if you tapped options, repeat them joined by '; '>"}}
If there are options, you MUST tap at least one of them, copied exactly."""


def actor_reply(llm, persona, bot_text, options, history):
    payload = {"app_message": bot_text, "options": options or [], "conversation_so_far": history[-6:]}
    messages = [SystemMessage(content=ACTOR_PROMPT.format(persona=persona)),
                HumanMessage(content=json.dumps(payload, ensure_ascii=False))]
    data = json.loads(llm.invoke(messages).content)
    selected = [s for s in (data.get("selected") or []) if s in (options or [])]
    message = data.get("message") or "; ".join(selected) or "I'm not sure"
    if options and not selected:
        selected = None  # typed instead of tapped: the app extracts it against the question on screen
    return selected or None, message


def run_case(case, actor_llm, max_turns, verbose):
    from app.services.triage_controller import HybridTriageController

    num, name, opening, persona, expected, _ = case
    agent = HybridTriageController()
    session_id, result, transcript = None, {}, []
    message, selected = opening, None
    t0, error = time.time(), None
    for _ in range(max_turns):
        try:
            session = agent.run_session(message, session_id=session_id, selected_options=selected)
        except Exception as exc:
            error = f"{type(exc).__name__}: {exc}"
            break
        session_id = session.session_id
        result = session.triage_result or {}
        out = session.last_output or {}
        options = out.get("response") if out.get("type") == "selection" else None
        bot = out.get("question") if options else out.get("response")
        transcript.append({"patient": message, "selected": selected, "qid": out.get("question_id"),
                           "bot": bot, "options": options})
        if verbose:
            print(f"  [{num}] PATIENT: {message}\n  [{num}] BOT    : {bot}"
                  + (f"\n  [{num}]   options: {' | '.join(options)}" if options else ""), flush=True)
        if result.get("status") == "classified" or getattr(session, "finished", False):
            break
        history = [{"app": t["bot"], "me": t["patient"]} for t in transcript]
        try:
            selected, message = actor_reply(actor_llm, persona, bot, options, history)
        except Exception as exc:
            error = f"actor: {type(exc).__name__}: {exc}"
            break
    level = result.get("triage_level") if result.get("status") == "classified" else None
    return {
        "id": num, "name": name, "expected": sorted(expected), "level": level,
        "ok": level in expected, "turns": len(transcript), "seconds": round(time.time() - t0, 1),
        "matched_rule_ids": result.get("matched_rule_ids", []),
        "key_findings": [f.get("condition") if isinstance(f, dict) else f for f in result.get("key_findings", [])],
        "error": error, "transcript": transcript,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated case ids")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--max-turns", type=int, default=25)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--kb", help="screen against this KB file instead of the current one (baseline)")
    ap.add_argument("--label", default="", help="tag stored with the results")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    if args.kb:
        # Must happen before the engine singleton is first built.
        triage_rules_engine.TriageRulesEngine.__init__.__defaults__ = (Path(args.kb).resolve(),)

    from app.core.llm import get_llm
    actor_llm = get_llm().bind(response_format={"type": "json_object"})

    cases = CASES
    if args.only:
        wanted = {int(x) for x in args.only.split(",")}
        cases = [c for c in CASES if c[0] in wanted]
    jobs = [c for c in cases for _ in range(args.runs)]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        results = list(pool.map(lambda c: run_case(c, actor_llm, args.max_turns, args.verbose), jobs))

    print(f"\n{'id':>3} {'case':32} {'exp':>5} {'levels':>10} {'turns':>6}  drivers of the highest level")
    for case in cases:
        rs = [r for r in results if r["id"] == case[0]]
        levels = ",".join(str(r["level"]) if r["level"] else "-" for r in rs)
        ok = all(r["ok"] for r in rs)
        drivers = sorted({d for r in rs for d in r["key_findings"]})
        print(f"{case[0]:>3} {case[1][:32]:32} {'/'.join(map(str, sorted(case[4]))):>5} {levels:>10} "
              f"{'/'.join(str(r['turns']) for r in rs):>6}  {'OK ' if ok else 'BAD'} {'; '.join(drivers)[:90]}"
              + (f"  ({case[5]})" if case[5] else ""))
        for r in rs:
            if r["error"]:
                print(f"      error: {r['error']}")
    passed = sum(r["ok"] for r in results)
    print(f"\nruns in expected range: {passed}/{len(results)}")

    out_dir = BACKEND / "scripts" / "sim_results"
    out_dir.mkdir(exist_ok=True)
    path = out_dir / f"actor_{datetime.now():%Y%m%d_%H%M%S}.json"
    path.write_text(json.dumps({"label": args.label, "kb": args.kb, "results": results}, ensure_ascii=False,
                               indent=1), encoding="utf-8")
    print(f"Full results: {path}")


if __name__ == "__main__":
    main()
