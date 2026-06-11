#!/usr/bin/env bash
set -euo pipefail

STATE_DIR="$HOME/.openclaw"
CFG="$STATE_DIR/openclaw.json"
ENVF="$STATE_DIR/.env"
UNIT="openclaw-gateway"

if [[ ! -f "$CFG" ]]; then
  echo "missing_config=$CFG" >&2
  exit 1
fi

if [[ ! -f "$ENVF" ]]; then
  install -m 600 /dev/null "$ENVF"
fi

if [[ -z "${MOONSHOT_API_KEY:-}" ]]; then
  read -r -s -p "Enter new MOONSHOT_API_KEY: " MOONSHOT_API_KEY
  echo
fi

if [[ -z "$MOONSHOT_API_KEY" ]]; then
  echo "empty_key" >&2
  exit 1
fi

python3 - "$CFG" <<'PY'
import json
import pathlib
import sys

cfg = pathlib.Path(sys.argv[1])
data = json.loads(cfg.read_text(encoding="utf-8"))
env_block = data.get("env") or {}
env_block.pop("MOONSHOT_API_KEY", None)
if "env" in data:
    if env_block:
        data["env"] = env_block
    else:
        data.pop("env", None)
providers = data.setdefault("models", {}).setdefault("providers", {})
moonshot = providers.setdefault("moonshot", {})
moonshot["apiKey"] = "${MOONSHOT_API_KEY}"
cfg.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

python3 - "$ENVF" "$MOONSHOT_API_KEY" <<'PY'
import os
import pathlib
import sys

envf = pathlib.Path(sys.argv[1])
key = sys.argv[2]

lines = envf.read_text(encoding="utf-8").splitlines() if envf.exists() else []
lines = [line for line in lines if not line.startswith("MOONSHOT_API_KEY=")]
lines.append(f"MOONSHOT_API_KEY={key}")
envf.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
os.chmod(envf, 0o600)
PY

echo "=== verify_key_with_official_api ==="
python3 - "$ENVF" <<'PY'
import json
import pathlib
import urllib.error
import urllib.request
import sys

envf = pathlib.Path(sys.argv[1])
key = ""
for line in envf.read_text(encoding="utf-8").splitlines():
    if line.startswith("MOONSHOT_API_KEY="):
        key = line.split("=", 1)[1]
        break

headers = {"Authorization": f"Bearer {key}"}
req = urllib.request.Request("https://api.moonshot.cn/v1/models", headers=headers, method="GET")

with urllib.request.urlopen(req, timeout=40) as resp:
    data = json.loads(resp.read().decode())
    ids = [item.get("id") for item in data.get("data", []) if isinstance(item, dict)]
    print("models_http=200")
    print("model_count=" + str(len(ids)))
    print("has_128k=" + str("moonshot-v1-128k" in ids))
    print("has_auto=" + str("moonshot-v1-auto" in ids))
PY

systemctl --user daemon-reload
systemctl --user restart "$UNIT"
sleep 3

echo
echo "=== verify_openclaw ==="
openclaw config validate
systemctl --user show "$UNIT" -p ActiveState -p SubState -p NRestarts
openclaw channels status --probe || true
