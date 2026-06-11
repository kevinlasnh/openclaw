#!/usr/bin/env bash
set -euo pipefail

ENVF="$HOME/.openclaw/.env"

if [[ ! -f "$ENVF" ]]; then
  echo "missing_env_file=$ENVF" >&2
  exit 1
fi

set -a
. "$ENVF"
set +a

if [[ -z "${MOONSHOT_API_KEY:-}" ]]; then
  echo "missing_MOONSHOT_API_KEY" >&2
  exit 1
fi

python3 - <<'PY'
import json
import os
import urllib.error
import urllib.request

key = os.environ["MOONSHOT_API_KEY"]
base = "https://api.moonshot.cn/v1"

def fetch_models():
    req = urllib.request.Request(
        base + "/models",
        headers={"Authorization": f"Bearer {key}"},
        method="GET",
    )
    with urllib.request.urlopen(req, timeout=40) as resp:
        data = json.loads(resp.read().decode())
        ids = [item.get("id") for item in data.get("data", []) if isinstance(item, dict)]
        print("models_http=200")
        print("model_count=" + str(len(ids)))
        print("has_128k=" + str("moonshot-v1-128k" in ids))
        print("has_auto=" + str("moonshot-v1-auto" in ids))
        print("has_k2_5=" + str("kimi-k2.5" in ids))

def chat(model: str, temperature: int):
    body = json.dumps(
        {
            "model": model,
            "messages": [{"role": "user", "content": f"Reply with exactly {model}_OK"}],
            "temperature": temperature,
        }
    ).encode()
    req = urllib.request.Request(
        base + "/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=40) as resp:
            data = json.loads(resp.read().decode())
            reply = data["choices"][0]["message"]["content"].replace("\n", " ")
            print(f"{model}_http=200")
            print(f"{model}_reply={reply[:120]}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="ignore")[:500]
        print(f"{model}_http={exc.code}")
        print(f"{model}_body={body}")

fetch_models()
chat("moonshot-v1-128k", 0)
chat("moonshot-v1-auto", 0)
chat("kimi-k2.5", 1)
PY
