#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
[ -d "$DESKTOP_DIR" ] && [ -w "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME"
OUT="$DESKTOP_DIR/spark_f153_enable_local_llama_openclaw_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee "$OUT") 2>&1

run() {
  echo
  echo "===== $1 ====="
  shift
  echo "+ $*"
  bash -lc "$*" || true
}

BASE_MODEL_TAG="${OLLAMA_BASE_MODEL_TAG:-llama3.1:8b}"
TUNED_MODEL_TAG="${OLLAMA_TUNED_MODEL_TAG:-llama3.1-openclaw:8b}"
CONTEXT_SIZE="${OLLAMA_CONTEXT_SIZE:-65536}"
PROVIDER_ID="${OPENCLAW_PROVIDER_ID:-ollama}"
MODEL_ALIAS="${OPENCLAW_MODEL_ALIAS:-Local Model (64K)}"
CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
OLLAMA_ROOT="${OLLAMA_ROOT:-$HOME/.local/ollama-root}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
MODELS_DIR="${OLLAMA_MODELS_DIR:-$HOME/.ollama/models}"
SERVICE_PATH="$HOME/.config/systemd/user/ollama-user.service"
PROXY_ENV_FILE="${PROXY_ENV_FILE:-$HOME/.config/openclaw/proxy.env}"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/openclaw-downloads}"
OLLAMA_GITHUB_ASSET_URL="${OLLAMA_GITHUB_ASSET_URL:-https://github.com/ollama/ollama/releases/download/v0.18.0/ollama-linux-arm64.tar.zst}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname)"
echo "current_user=$(id -un)"
echo "base_model_tag=$BASE_MODEL_TAG"
echo "tuned_model_tag=$TUNED_MODEL_TAG"
echo "context_size=$CONTEXT_SIZE"
echo "provider_id=$PROVIDER_ID"
echo "config_path=$CONFIG_PATH"

export BASE_MODEL_TAG
export TUNED_MODEL_TAG
export CONTEXT_SIZE
export PROVIDER_ID
export MODEL_ALIAS

run precheck "id; echo; uname -a; echo; python3 - <<'PY'
import platform
print(platform.machine())
PY
echo; command -v curl; command -v tar; command -v systemctl; command -v node; command -v openclaw"

if [ -f "$PROXY_ENV_FILE" ]; then
  set -a
  source "$PROXY_ENV_FILE"
  set +a
fi

run proxy_env "env | grep -i 'proxy' | sort || true; echo; [ -f \"$PROXY_ENV_FILE\" ] && { echo proxy_env_file=$PROXY_ENV_FILE; cat \"$PROXY_ENV_FILE\"; } || echo proxy_env_file=missing"

mkdir -p "$OLLAMA_ROOT" "$BIN_DIR" "$MODELS_DIR" "$HOME/.config/systemd/user"
mkdir -p "$CACHE_DIR"

download_and_extract_ollama() {
  local url="$1"
  local archive="$2"
  echo "+ curl -fL -C - --retry 20 --retry-delay 2 --retry-all-errors --connect-timeout 10 --speed-time 60 --speed-limit 1024 $url -o $archive"
  if ! curl -fL -C - --retry 20 --retry-delay 2 --retry-all-errors --connect-timeout 10 --speed-time 60 --speed-limit 1024 "$url" -o "$archive"; then
    return 1
  fi

  case "$archive" in
    *.tar.zst)
      echo "+ tar --zstd -xf $archive -C $OLLAMA_ROOT"
      tar --zstd -xf "$archive" -C "$OLLAMA_ROOT"
      ;;
    *.tgz)
      echo "+ tar -xzf $archive -C $OLLAMA_ROOT"
      tar -xzf "$archive" -C "$OLLAMA_ROOT"
      ;;
    *)
      echo "unsupported_archive=$archive" >&2
      return 1
      ;;
  esac
}

echo
echo "===== install_ollama ====="
if [ ! -x "$OLLAMA_ROOT/bin/ollama" ]; then
  echo "github_asset_url=$OLLAMA_GITHUB_ASSET_URL"
  OLLAMA_ARCHIVE="$CACHE_DIR/ollama-linux-arm64.tar.zst"
  echo "ollama_archive=$OLLAMA_ARCHIVE"
  if download_and_extract_ollama "https://ollama.com/download/ollama-linux-arm64.tar.zst" "$OLLAMA_ARCHIVE"; then
    echo "ollama_install=downloaded_from_ollama"
  elif download_and_extract_ollama "$OLLAMA_GITHUB_ASSET_URL" "$OLLAMA_ARCHIVE"; then
    echo "ollama_install=downloaded_from_github"
  else
    echo "ollama_install=failed" >&2
    exit 1
  fi
else
  echo "ollama_install=already_present"
fi
ln -snf "$OLLAMA_ROOT/bin/ollama" "$BIN_DIR/ollama"
export PATH="$BIN_DIR:$PATH"
echo "ollama_binary=$(command -v ollama)"
ollama --version || true

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Ollama User Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$OLLAMA_ROOT/bin/ollama serve
EnvironmentFile=-%h/.config/openclaw/proxy.env
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_MODELS=%h/.ollama/models
Environment=OLLAMA_NUM_PARALLEL=1
Environment=OLLAMA_MAX_LOADED_MODELS=1
WorkingDirectory=%h
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

run start_ollama "systemctl --user daemon-reload; systemctl --user enable --now ollama-user.service; systemctl --user status ollama-user.service --no-pager -l | sed -n '1,80p'"

echo
echo "===== wait_for_api ====="
for i in $(seq 1 40); do
  if curl -fsS "http://127.0.0.1:11434/api/version" >/dev/null 2>&1; then
    echo "ollama_api_ready=1"
    break
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:11434/api/version" || true

echo
echo "===== pull_base_model ====="
echo "+ ollama pull $BASE_MODEL_TAG"
ollama pull "$BASE_MODEL_TAG"
echo "+ ollama list"
ollama list || true

cat >"$TMP_DIR/Modelfile" <<EOF
FROM $BASE_MODEL_TAG
PARAMETER num_ctx $CONTEXT_SIZE
EOF

echo
echo "===== create_tuned_model ====="
echo "+ ollama create $TUNED_MODEL_TAG -f $TMP_DIR/Modelfile"
ollama create "$TUNED_MODEL_TAG" -f "$TMP_DIR/Modelfile"
echo "+ ollama show $TUNED_MODEL_TAG"
ollama show "$TUNED_MODEL_TAG" || true

echo
echo "===== ollama_chat_probe ====="
python3 - <<'PY'
import json
import urllib.request
import os

payload = json.dumps({
    "model": os.environ["TUNED_MODEL_TAG"],
    "messages": [{"role": "user", "content": "Reply with exactly LOCAL_OLLAMA_API_OK"}],
    "stream": False,
}).encode()
req = urllib.request.Request(
    "http://127.0.0.1:11434/api/chat",
    data=payload,
    headers={"Content-Type": "application/json"},
)
with urllib.request.urlopen(req, timeout=180) as resp:
    body = json.loads(resp.read().decode())
print("chat_http=200")
print("chat_reply=" + body["message"]["content"])
PY

echo
echo "===== patch_openclaw_config ====="
cp -a "$CONFIG_PATH" "$CONFIG_PATH.pre-local-llama-$(date +%Y%m%d_%H%M%S)"
ENV_PATH="$HOME/.openclaw/.env"
touch "$ENV_PATH"
chmod 600 "$ENV_PATH"
python3 - "$ENV_PATH" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = []
if path.exists():
    lines = path.read_text(encoding="utf-8").splitlines()

found = False
out = []
for line in lines:
    if line.startswith("OLLAMA_API_KEY="):
        out.append("OLLAMA_API_KEY=ollama-local")
        found = True
    else:
        out.append(line)
if not found:
    out.append("OLLAMA_API_KEY=ollama-local")
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
CONFIG_PATH="$CONFIG_PATH" \
PROVIDER_ID="$PROVIDER_ID" \
TUNED_MODEL_TAG="$TUNED_MODEL_TAG" \
MODEL_ALIAS="$MODEL_ALIAS" \
CONTEXT_SIZE="$CONTEXT_SIZE" \
node <<'EOF'
const fs = require("fs");

const configPath = process.env.CONFIG_PATH;
const providerId = process.env.PROVIDER_ID;
const tunedModelTag = process.env.TUNED_MODEL_TAG;
const modelAlias = process.env.MODEL_ALIAS;
const contextSize = Number(process.env.CONTEXT_SIZE);

const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));
cfg.models ??= {};
cfg.models.mode = cfg.models.mode || "merge";
cfg.models.providers ??= {};
cfg.models.providers[providerId] = {
  baseUrl: "http://127.0.0.1:11434",
  apiKey: "${OLLAMA_API_KEY}",
  api: "ollama",
  models: [
    {
      id: tunedModelTag,
      name: modelAlias,
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0 },
      contextWindow: contextSize,
      maxTokens: 8192,
    },
  ],
};

cfg.agents ??= {};
cfg.agents.defaults ??= {};
cfg.agents.defaults.model ??= {};
const currentPrimary = cfg.agents.defaults.model.primary || "moonshot/kimi-k2.5";
const currentFallbacks = Array.isArray(cfg.agents.defaults.model.fallbacks)
  ? cfg.agents.defaults.model.fallbacks
  : [];
const localPrimary = `${providerId}/${tunedModelTag}`;
const fallbacks = [currentPrimary, ...currentFallbacks].filter(
  (value, index, array) => value && value !== localPrimary && array.indexOf(value) === index,
);
cfg.agents.defaults.model = {
  primary: localPrimary,
  fallbacks,
};

cfg.agents.defaults.models ??= {};
cfg.agents.defaults.models[localPrimary] = { alias: modelAlias };
fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);
console.log("new_primary=" + cfg.agents.defaults.model.primary);
console.log("new_fallbacks=" + JSON.stringify(cfg.agents.defaults.model.fallbacks));
EOF

run validate_config "openclaw config validate"
run restart_gateway "systemctl --user restart openclaw-gateway; systemctl --user status openclaw-gateway --no-pager -l | sed -n '1,80p'"

echo
echo "===== gateway_probe ====="
AGENT_JSON="$(mktemp)"
if OPENCLAW_NO_COLOR=1 openclaw agent --agent main --message 'Reply with exactly LOCAL_LLAMA_GATEWAY_OK' --json >"$AGENT_JSON" 2>/dev/null; then
  python3 - "$AGENT_JSON" <<'PY'
import json, sys

path = sys.argv[1]
data = json.load(open(path, "r", encoding="utf-8"))
payloads = (((data or {}).get("result") or {}).get("payloads") or [])
first_payload = payloads[0]["text"] if payloads else None
meta = (((data or {}).get("result") or {}).get("meta") or {}).get("agentMeta") or {}
print("gateway_payload=" + str(first_payload))
print("gateway_provider=" + str(meta.get("provider")))
print("gateway_model=" + str(meta.get("model")))
PY
else
  echo "gateway_probe=failed"
  cat "$AGENT_JSON" || true
fi
rm -f "$AGENT_JSON"

run final_checks "curl -fsS http://127.0.0.1:11434/api/tags; echo; openclaw channels status --probe || true"

echo
echo "===== done ====="
echo "saved_to=$OUT"
