from app.agents.triage_agent import parse_structured_reply

RESULT = {"suggested_questions": [{"answers": ["Yes", "No", "Not sure"]}]}


def test_text_reply():
    out = parse_structured_reply('{"type":"text","response":"How old are you?"}')
    assert out == {"type": "text", "question": None, "response": "How old are you?"}


def test_selection_reply_in_code_fence():
    raw = '```json\n{"type":"selection","question":"Is it ongoing?","response":["Yes","No"]}\n```'
    out = parse_structured_reply(raw, RESULT)
    assert out["type"] == "selection"
    assert out["question"] == "Is it ongoing?"
    assert out["response"] == ["Yes", "No", "Not sure"]


def test_invented_options_are_dropped():
    raw = '{"type":"selection","question":"Q?","response":["Yes","Maybe"]}'
    assert parse_structured_reply(raw, RESULT)["response"] == ["Yes", "Not sure"]


def test_selection_without_valid_options_becomes_text():
    raw = '{"type":"selection","question":"Q?","response":["Maybe"]}'
    out = parse_structured_reply(raw, RESULT)
    assert out["type"] == "text"
    assert out["response"] == "Q?"


def test_plain_text_falls_back():
    out = parse_structured_reply("Please call 999.")
    assert out == {"type": "text", "question": None, "response": "Please call 999."}
