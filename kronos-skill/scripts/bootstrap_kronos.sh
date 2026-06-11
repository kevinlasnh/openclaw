#!/usr/bin/env bash
set -euo pipefail

ROOT="${OPENCLAW_KRONOS_ROOT:-$HOME/.openclaw/vendor/kronos}"
REPO_DIR="$ROOT/Kronos"
VENV_DIR="$ROOT/.venv"
REQ_FILE="${1:-}"

if [ -z "$REQ_FILE" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REQ_FILE="$(cd "$SCRIPT_DIR/.." && pwd)/requirements.txt"
fi

mkdir -p "$ROOT"

if [ ! -d "$REPO_DIR/.git" ]; then
  git clone --depth 1 https://github.com/shiyu-coder/Kronos.git "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --ff-only
fi

if [ ! -d "$VENV_DIR" ]; then
  python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip setuptools wheel
"$VENV_DIR/bin/python" -m pip install -r "$REQ_FILE"

echo "repo_dir=$REPO_DIR"
echo "venv_dir=$VENV_DIR"
"$VENV_DIR/bin/python" - <<'PY'
import platform
print("python_ok=true")
print("arch=" + platform.machine())
PY
