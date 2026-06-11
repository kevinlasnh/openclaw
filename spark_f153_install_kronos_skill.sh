#!/usr/bin/env bash
set -euo pipefail

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
HOME_DIR="${HOME:-/home/admin}"
STATE_DIR="$HOME_DIR/.openclaw"
OUT="$HOME_DIR/Desktop/spark_f153_install_kronos_skill_$STAMP.txt"
SKILL_NAME="kronos-skill"
SKILLS_DIR="$STATE_DIR/skills/skills/$SKILL_NAME"
SELECTED_DIR="$STATE_DIR/skills/selected/skills/$SKILL_NAME"
TMP_ROOT="/tmp/$SKILL_NAME-install-$STAMP"

exec > >(tee "$OUT") 2>&1

echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "skill_name=$SKILL_NAME"

rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT" "$SKILLS_DIR" "$SELECTED_DIR"

if [ ! -d "/tmp/$SKILL_NAME" ]; then
  echo "missing_staged_skill_dir=/tmp/$SKILL_NAME"
  exit 1
fi

cp -a "/tmp/$SKILL_NAME/." "$SKILLS_DIR/"
cp -a "/tmp/$SKILL_NAME/." "$SELECTED_DIR/"

echo
echo "===== installed_files ====="
find "$SKILLS_DIR" -maxdepth 3 -type f | sort

echo
echo "===== bootstrap_runtime ====="
bash "$SKILLS_DIR/scripts/bootstrap_kronos.sh" "$SKILLS_DIR/requirements.txt"

echo
echo "===== restart_gateway ====="
systemctl --user restart openclaw-gateway
sleep 5
systemctl --user show openclaw-gateway -p ActiveState -p SubState -p ExecMainStartTimestamp

echo
echo "===== runtime_skill_check ====="
TMP_JSON="$TMP_ROOT/skill-check.json"
timeout 45s openclaw agent --agent main --message '只回复 KRONOS_SKILL_READY' --json > "$TMP_JSON" || true
python3 - <<'PY'
import json
from pathlib import Path

raw = Path("/tmp").glob("kronos-skill-install-*/skill-check.json")
raw = sorted(raw)
if not raw:
    print("skill_check=missing")
    raise SystemExit(0)
text = raw[-1].read_text(encoding="utf-8", errors="ignore")
idx = text.find("{")
if idx < 0:
    print("skill_check=parse_failed")
    print(text[:500])
    raise SystemExit(0)
obj = json.loads(text[idx:])
skills = (((((obj.get("result") or {}).get("meta") or {}).get("systemPromptReport") or {}).get("skills") or {}).get("entries") or [])
print("skills=" + ",".join(s.get("name", "") for s in skills))
print("has_kronos_skill=" + str(any(s.get("name") == "kronos-skill" for s in skills)))
PY

echo
echo "===== done ====="
echo "saved_to=$OUT"
