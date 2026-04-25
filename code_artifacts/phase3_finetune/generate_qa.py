import anthropic, json, pathlib

client = anthropic.Anthropic()          # uses ANTHROPIC_API_KEY env var

def generate_qa(chunk_text: str, object_name: str) -> list[dict]:
    msg = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        messages=[{"role": "user", "content":
            f"You are an ABAP expert. Given this code from {object_name}, "
            f"write 4 developer questions whose answer is in this code.\n\n"
            f"CODE:\n{chunk_text}\n\nReturn JSON list of strings."}])
    questions = json.loads(msg.content[0].text)
    return [{"prompt": q, "completion": chunk_text} for q in questions]

with open("training_data.jsonl", "w") as f:
    for path in pathlib.Path("./abap_files").glob("*.abap"):
        chunk = path.read_text(encoding="utf-8")[:2000]   # first 2000 chars
        for pair in generate_qa(chunk, path.stem):
            f.write(json.dumps(pair) + "\n")
