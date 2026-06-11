#!/usr/bin/env bash
set -euo pipefail

MODEL_TAG="${OLLAMA_MODEL_TAG:-qwen3:8b}"
OLLAMA_ROOT="${OLLAMA_ROOT:-$HOME/.local/ollama-root}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
SERVICE_PATH="$HOME/.config/systemd/user/ollama-user.service"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$OLLAMA_ROOT" "$BIN_DIR" "$HOME/.config/systemd/user" "$HOME/.ollama/models"

if [ ! -x "$OLLAMA_ROOT/bin/ollama" ]; then
  curl -fsSL "https://ollama.com/download/ollama-linux-arm64.tar.zst" -o "$TMP_DIR/ollama-linux-arm64.tar.zst"
  tar --zstd -xf "$TMP_DIR/ollama-linux-arm64.tar.zst" -C "$OLLAMA_ROOT"
fi

ln -snf "$OLLAMA_ROOT/bin/ollama" "$BIN_DIR/ollama"
export PATH="$BIN_DIR:$PATH"

cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Ollama User Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$OLLAMA_ROOT/bin/ollama serve
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_MODELS=%h/.ollama/models
WorkingDirectory=%h
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now ollama-user.service
sleep 5

ollama list || true
ollama pull "$MODEL_TAG"
ollama list
