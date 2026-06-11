#!/usr/bin/env bash
set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
STATE_DIR="$HOME/.openclaw"
CFG="$STATE_DIR/openclaw.json"
ENVF="$STATE_DIR/.env"
UNIT="$HOME/.config/systemd/user/openclaw-gateway.service"
CFG_BAK="$CFG.pre-prekey-cleanup-$TS"
UNIT_BAK="$UNIT.pre-prekey-cleanup-$TS"

echo "=== spark_f153_prekey_cleanup_and_prep ==="
echo "timestamp=$TS"
echo "config=$CFG"
echo "env_file=$ENVF"
echo "unit=$UNIT"

cp -a "$CFG" "$CFG_BAK"
cp -a "$UNIT" "$UNIT_BAK"

python3 - "$CFG" "$ENVF" <<'PY'
import json
import os
import pathlib
import sys

cfg_path = pathlib.Path(sys.argv[1])
env_path = pathlib.Path(sys.argv[2])

data = json.loads(cfg_path.read_text(encoding="utf-8"))

env_block = data.get("env") or {}
old_key = env_block.pop("MOONSHOT_API_KEY", "")
if "env" in data:
    if env_block:
        data["env"] = env_block
    else:
        data.pop("env", None)

providers = data.setdefault("models", {}).setdefault("providers", {})
moonshot = providers.setdefault("moonshot", {})
moonshot["apiKey"] = "${MOONSHOT_API_KEY}"

channels = data.setdefault("channels", {})
feishu = channels.get("feishu") or {}
accounts = feishu.get("accounts") or {}
default_account = accounts.get("default")

removed_default = False
if isinstance(default_account, dict):
    if not default_account.get("appId") and not default_account.get("appSecret"):
        accounts.pop("default", None)
        removed_default = True

if removed_default:
    if feishu.get("defaultAccount") == "default":
        if "stock-desk" in accounts:
            feishu["defaultAccount"] = "stock-desk"
        elif accounts:
            feishu["defaultAccount"] = sorted(accounts)[0]
        else:
            feishu.pop("defaultAccount", None)
    feishu["accounts"] = accounts
    channels["feishu"] = feishu

cfg_path.write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)

lines: list[str] = []
if env_path.exists():
    lines = env_path.read_text(encoding="utf-8").splitlines()

lines = [line for line in lines if not line.startswith("MOONSHOT_API_KEY=")]
if old_key:
    lines.append(f"MOONSHOT_API_KEY={old_key}")

content = ""
if lines:
    content = "\n".join(lines).rstrip() + "\n"

env_path.write_text(content, encoding="utf-8")
os.chmod(env_path, 0o600)

print(f"moved_key_to_env={bool(old_key)}")
print(f"removed_blank_feishu_default={removed_default}")
PY

python3 - "$UNIT" <<'PY'
import pathlib
import sys

unit_path = pathlib.Path(sys.argv[1])
text = unit_path.read_text(encoding="utf-8")

if "EnvironmentFile=%h/.openclaw/.env" not in text:
    lines = text.splitlines()
    out: list[str] = []
    inserted = False
    for line in lines:
        out.append(line)
        if line.strip() == "[Service]" and not inserted:
            out.append("EnvironmentFile=%h/.openclaw/.env")
            inserted = True
    unit_path.write_text("\n".join(out) + "\n", encoding="utf-8")
    print("added_environment_file=true")
else:
    print("added_environment_file=false")
PY

systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
sleep 3

echo
echo "=== verify ==="
openclaw config validate
systemctl --user show openclaw-gateway -p ActiveState -p SubState -p UnitFileState -p NRestarts

python3 - "$CFG" "$ENVF" <<'PY'
import json
import pathlib
import sys

cfg = pathlib.Path(sys.argv[1])
envf = pathlib.Path(sys.argv[2])
data = json.loads(cfg.read_text(encoding="utf-8"))
feishu = ((data.get("channels") or {}).get("feishu") or {})
accounts = feishu.get("accounts") or {}

print("has_top_level_key=" + str("MOONSHOT_API_KEY" in data))
print("has_env_block=" + str("env" in data))
print("has_env_key=" + str("MOONSHOT_API_KEY" in ((data.get("env") or {}))))
print("provider_apiKey=" + str((((data.get("models") or {}).get("providers") or {}).get("moonshot") or {}).get("apiKey")))
print("env_file_exists=" + str(envf.exists()))
print("feishu_default_account=" + str(feishu.get("defaultAccount")))
print("feishu_accounts=" + "|".join(sorted(accounts.keys())))
PY

echo
echo "backups:"
echo "  $CFG_BAK"
echo "  $UNIT_BAK"
