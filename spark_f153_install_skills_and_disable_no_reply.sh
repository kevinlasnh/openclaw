#!/usr/bin/env bash
set -euo pipefail

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
HOME_DIR="${HOME:-/home/admin}"
STATE_DIR="$HOME_DIR/.openclaw"
SKILLS_DIR="$STATE_DIR/skills/skills"
SELECTED_DIR="$STATE_DIR/skills/selected/skills"
WORKSPACE_DIR="$STATE_DIR/workspace"
SESSIONS_DIR="$STATE_DIR/agents/main/sessions"
SESSION_KEY="agent:main:feishu:direct:ou_0923ec76f919f2d07d1d5b6c0e5988d0"
TMP_ROOT="/tmp/openclaw_skill_refresh_$STAMP"
OUT="$HOME_DIR/Desktop/spark_f153_install_skills_and_disable_no_reply_$STAMP.txt"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1

echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "tmp_root=$TMP_ROOT"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT" "$SKILLS_DIR" "$SELECTED_DIR"

if [ ! -f /tmp/skills-bundle.zip ] || [ ! -f /tmp/feishu-file-uploader.zip ]; then
  echo "missing_zip=true"
  echo "expected=/tmp/skills-bundle.zip,/tmp/feishu-file-uploader.zip"
  exit 1
fi

echo
echo "===== unpack ====="
unzip -oq /tmp/skills-bundle.zip -d "$TMP_ROOT/bundle"
unzip -oq /tmp/feishu-file-uploader.zip -d "$TMP_ROOT/uploader"
rm -rf "$TMP_ROOT/uploader/__MACOSX"
find "$TMP_ROOT/uploader" -name '.DS_Store' -delete
find "$TMP_ROOT" -maxdepth 3 -type d | sort

echo
echo "===== backup_skills ====="
SKILLS_BACKUP="$STATE_DIR/skills/skills.pre-install-$STAMP"
SELECTED_BACKUP="$STATE_DIR/skills/selected/skills.pre-install-$STAMP"
cp -a "$SKILLS_DIR" "$SKILLS_BACKUP"
cp -a "$SELECTED_DIR" "$SELECTED_BACKUP"
echo "skills_backup=$SKILLS_BACKUP"
echo "selected_backup=$SELECTED_BACKUP"

echo
echo "===== install_bundle ====="
cp -a "$TMP_ROOT/bundle/skills/." "$SKILLS_DIR/"
cp -a "$TMP_ROOT/bundle/skills/." "$SELECTED_DIR/"

echo
echo "===== install_uploader ====="
rm -rf "$SKILLS_DIR/feishu-file-uploader" "$SELECTED_DIR/feishu-file-uploader"
mkdir -p "$SKILLS_DIR/feishu-file-uploader" "$SELECTED_DIR/feishu-file-uploader"
cp -a "$TMP_ROOT/uploader/feishu-file-uploader/." "$SKILLS_DIR/feishu-file-uploader/"
cp -a "$TMP_ROOT/uploader/feishu-file-uploader/." "$SELECTED_DIR/feishu-file-uploader/"
cat > "$SKILLS_DIR/feishu-file-uploader/_meta.json" <<EOF
{"ownerId":"local","slug":"feishu-file-uploader","version":"local-$STAMP","publishedAt":$(date +%s)000}
EOF
cp "$SKILLS_DIR/feishu-file-uploader/_meta.json" "$SELECTED_DIR/feishu-file-uploader/_meta.json"
find "$SKILLS_DIR/feishu-file-uploader" -maxdepth 2 -type f | sort

echo
echo "===== patch_workspace ====="
python3 - <<'PY'
from pathlib import Path
import shutil
import os

stamp = os.environ["STAMP"] if "STAMP" in os.environ else ""
workspace = Path(os.path.expanduser("~/.openclaw/workspace"))

patches = {
    "AGENTS.md": """

## Direct Chat Rules

- 飞书一对一私聊里，永远不要对真人用户输出 `NO_REPLY`。
- 飞书一对一私聊里，永远不要把 `HEARTBEAT_OK` 当作用户可见回复。
- 用户只发 `hi`、`hello`、`在吗`、`测试`、`1111` 这类短消息时，也要给一句短确认。
- 默认短确认风格：
  - `在。直接说票、持仓或问题。📈`
- 除非消息明显是重复回环或系统噪声，否则不要静默。
""".strip("\n"),
    "HEARTBEAT.md": """

## Human Chat Override

- 上面的 heartbeat 规则只用于后台 heartbeat / 自检 / 主动巡检。
- 只要是飞书真人私聊，就不要把 `HEARTBEAT_OK` 或 `NO_REPLY` 发给用户。
- 如果用户只是短 ping，也回复一句短确认：
  - `在。直接说票、持仓或问题。📈`
""".strip("\n"),
}

for name, block in patches.items():
    path = workspace / name
    text = path.read_text(encoding="utf-8")
    if "## Direct Chat Rules" in text or "## Human Chat Override" in text:
        print(f"already_patched={path}")
        continue
    backup = path.with_name(path.name + f".pre-no-reply-{stamp}")
    shutil.copy2(path, backup)
    path.write_text(text.rstrip() + "\n\n" + block + "\n", encoding="utf-8")
    print(f"patched={path}")
    print(f"backup={backup}")
PY

echo
echo "===== reset_feishu_session ====="
python3 - <<'PY'
import json
import os
from pathlib import Path

stamp = os.environ["STAMP"] if "STAMP" in os.environ else ""
session_key = "agent:main:feishu:direct:ou_0923ec76f919f2d07d1d5b6c0e5988d0"
sessions_json = Path(os.path.expanduser("~/.openclaw/agents/main/sessions/sessions.json"))
data = json.loads(sessions_json.read_text(encoding="utf-8"))
entry = data.pop(session_key, None)
session_file = None
if entry:
    session_id = entry.get("sessionId")
    if session_id:
      session_file = sessions_json.parent / f"{session_id}.jsonl"
      if session_file.exists():
          backup = session_file.with_name(session_file.name + f".reset-{stamp}")
          session_file.rename(backup)
          print(f"session_file_backup={backup}")
sessions_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"session_key_removed={bool(entry)}")
print(f"sessions_json={sessions_json}")
PY

echo
echo "===== dependency_check ====="
python3 - <<'PY'
try:
    import requests  # noqa: F401
    print("python_requests=ok")
except Exception:
    print("python_requests=missing")
PY

echo
echo "===== restart_gateway ====="
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 5
systemctl --user show openclaw-gateway -p ActiveState -p SubState -p ExecMainStartTimestamp

echo
echo "===== postcheck_probe ====="
timeout 25s openclaw channels status --probe || true

echo
echo "===== postcheck_skills ====="
JSON_OUT="$TMP_ROOT/postcheck.json"
timeout 45s openclaw agent --agent main --message '只回复 SKILL_REFRESH_OK' --json > "$JSON_OUT" || true
python3 - <<'PY'
import json
from pathlib import Path
import re

path = Path("/tmp").glob("openclaw_skill_refresh_*/postcheck.json")
path = sorted(path)
if not path:
    print("postcheck_json=missing")
    raise SystemExit(0)
raw = path[-1].read_text(encoding="utf-8", errors="ignore")
match = re.search(r'(\{\s*"runId".*)', raw, re.S)
if not match:
    print("postcheck_json=parse_failed")
    print(raw[:1000])
    raise SystemExit(0)
obj = json.loads(match.group(1))
payloads = (((obj.get("result") or {}).get("payloads")) or [])
skills = ((((obj.get("result") or {}).get("meta") or {}).get("systemPromptReport") or {}).get("skills") or {}).get("entries") or []
print("payload_texts=" + " | ".join(p.get("text", "") for p in payloads))
print("skills=" + ",".join(s.get("name", "") for s in skills))
print("has_feishu_file_uploader=" + str(any(s.get("name") == "feishu-file-uploader" for s in skills)))
PY

echo
echo "===== done ====="
echo "saved_to=$OUT"
