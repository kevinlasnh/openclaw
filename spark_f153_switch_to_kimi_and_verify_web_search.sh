#!/usr/bin/env bash
set -euo pipefail

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
HOME_DIR="${HOME:-/home/admin}"
CONFIG_PATH="${CONFIG_PATH:-$HOME_DIR/.openclaw/openclaw.json}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR/Desktop"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR"
OUT="$DESKTOP_DIR/spark_f153_switch_to_kimi_and_verify_web_search_$STAMP.txt"
SESSION_ID="kimi-websearch-$STAMP"
SESSION_DIR="$HOME_DIR/.openclaw/agents/main/sessions"
SESSION_PATH="$SESSION_DIR/$SESSION_ID.jsonl"

exec > >(tee "$OUT") 2>&1

echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "config_path=$CONFIG_PATH"
echo "session_id=$SESSION_ID"

python3 - <<'PY'
import json
import os
import shutil
from pathlib import Path

stamp = os.environ.get("STAMP") or "manual"
config_path = Path(os.environ.get("CONFIG_PATH", "/home/admin/.openclaw/openclaw.json"))
backup_path = config_path.with_name(config_path.name + f".pre-kimi-switch-{stamp}")
shutil.copy2(config_path, backup_path)
print(f"backup={backup_path}")

obj = json.loads(config_path.read_text(encoding="utf-8"))

defaults = obj.setdefault("agents", {}).setdefault("defaults", {})
model_cfg = defaults.setdefault("model", {})
model_cfg["primary"] = "moonshot/kimi-k2.5"
model_cfg["fallbacks"] = [
    "moonshot/kimi-k2-turbo-preview",
    "moonshot/moonshot-v1-auto",
]

tools = obj.setdefault("tools", {})
web = tools.setdefault("web", {})
search = web.setdefault("search", {})
search["enabled"] = True
search["provider"] = "kimi"
kimi = search.setdefault("kimi", {})
kimi["apiKey"] = "${MOONSHOT_API_KEY}"
kimi["baseUrl"] = "https://api.moonshot.cn/v1"
kimi["model"] = "moonshot-v1-128k"

config_path.write_text(json.dumps(obj, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

print("new_primary=moonshot/kimi-k2.5")
print("new_fallbacks=moonshot/kimi-k2-turbo-preview,moonshot/moonshot-v1-auto")
print("web_search_provider=kimi")
print("web_search_baseUrl=https://api.moonshot.cn/v1")
PY

openclaw config validate

systemctl --user restart openclaw-gateway
systemctl --user is-active openclaw-gateway
systemctl --user show openclaw-gateway -p ActiveState -p SubState -p ExecMainStartTimestamp

echo
echo "===== provider_probe ====="
openclaw agent \
  --agent main \
  --session-id "$SESSION_ID-provider" \
  --message "只回答 KIMI_PROVIDER_OK。" \
  --json

echo
echo "===== web_search_probe ====="
openclaw agent \
  --agent main \
  --session-id "$SESSION_ID" \
  --thinking low \
  --timeout 180 \
  --message "你必须先调用一次 web_search 工具，搜索 Moonshot AI 官方网站或官方产品页。完成后只回复两行：第一行固定写 KIMI_WEB_SEARCH_OK；第二行写你实际用到的第一个来源域名。不要凭记忆回答，不允许跳过 web_search。" \
  --json || true

echo
echo "===== session_grep ====="
if [ -f "$SESSION_PATH" ]; then
  grep -n "web_search\\|Moonshot\\|KIMI_WEB_SEARCH_OK\\|tool" "$SESSION_PATH" || true
else
  echo "session_file_missing=$SESSION_PATH"
  ls -lt "$SESSION_DIR" | head -n 20 || true
fi

echo
echo "===== latest_logs ====="
journalctl --user -u openclaw-gateway -n 120 --no-pager | tail -n 80 || true

echo "done=true"
