"""Coding answers with thinking on (the model's default effort and sampling), one request per task, each with a unique tag.
    ds-code.py URL OUT.jsonl LABEL"""
import json, sys, time, urllib.request, uuid

url, out, label = sys.argv[1], sys.argv[2], sys.argv[3]
TASKS = [
    "Write a Python function that merges overlapping intervals in a list of [start, end] pairs, with a short docstring and "
    "two tests. Keep it compact.",
    "Implement an LRU cache class in Python with get and put in O(1) time, without collections.OrderedDict or functools. "
    "Include three short tests.",
    "Write a POSIX shell script that prints the 10 largest files under a directory given as the first argument, handles file "
    "names with spaces, and prints a usage line when the argument is missing.",
]
with open(out, "a") as f:
    for i, task in enumerate(TASKS, 1):
        tag = f"[{label} task {i} {uuid.uuid4().hex[:8]}]"
        body = {"model": "deepseek", "messages": [{"role": "user", "content": tag + "\n" + task}], "max_tokens": 2048}
        req = urllib.request.Request(url + "/v1/chat/completions", json.dumps(body).encode(), {"Content-Type": "application/json"})
        t = time.perf_counter()
        with urllib.request.urlopen(req, timeout=3600) as r:
            d = json.load(r)
        el = time.perf_counter() - t
        msg = d["choices"][0]["message"]
        tm = d.get("timings") or {}
        row = {"label": label, "task": i, "elapsed_s": round(el, 1), "prompt_n": tm.get("prompt_n"),
               "prompt_tok_s": tm.get("prompt_per_second"), "gen_n": tm.get("predicted_n"),
               "decode_tok_s": tm.get("predicted_per_second"), "draft_n": tm.get("draft_n"),
               "draft_n_accepted": tm.get("draft_n_accepted"), "finish": d["choices"][0].get("finish_reason"),
               "thinking_chars": len(msg.get("reasoning_content") or ""), "answer_chars": len(msg.get("content") or ""),
               "reasoning": msg.get("reasoning_content"), "answer": msg.get("content")}
        f.write(json.dumps(row) + "\n"); f.flush()
        print(json.dumps({k: v for k, v in row.items() if k not in ("reasoning", "answer")}), flush=True)
