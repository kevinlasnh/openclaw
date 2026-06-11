#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage:
  bash spark_f153_run_kronos_forecast.sh /path/to/ohlcv.csv [pred_len] [lookback] [model]

Example:
  bash spark_f153_run_kronos_forecast.sh ~/Desktop/btc_1h.csv 24 400 NeoQuasar/Kronos-small

Notes:
  - CSV required columns: timestamps, open, high, low, close
  - Optional columns: volume, amount
  - Output JSON will be written to ~/Desktop/kronos_forecast_<timestamp>.json
EOF
  exit 0
fi

CSV_PATH="$1"
PRED_LEN="${2:-24}"
LOOKBACK="${3:-400}"
MODEL_ID="${4:-NeoQuasar/Kronos-small}"
TOKENIZER_ID="${KRONOS_TOKENIZER_ID:-NeoQuasar/Kronos-Tokenizer-base}"
DEVICE="${KRONOS_DEVICE:-auto}"
SAMPLE_COUNT="${KRONOS_SAMPLE_COUNT:-1}"
MAX_CONTEXT="${KRONOS_MAX_CONTEXT:-512}"

HOME_DIR="${HOME:-/home/admin}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR/Desktop"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR"

SKILL_DIR="${OPENCLAW_KRONOS_SKILL_DIR:-$HOME_DIR/.openclaw/skills/selected/skills/kronos-skill}"
VENV_PY="${OPENCLAW_KRONOS_VENV_PY:-$HOME_DIR/.openclaw/vendor/kronos/.venv/bin/python}"
PREDICT_PY="$SKILL_DIR/scripts/predict_kronos.py"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_JSON="$DESKTOP_DIR/kronos_forecast_$STAMP.json"

if [ ! -f "$PREDICT_PY" ]; then
  echo "missing_predict_script=$PREDICT_PY" >&2
  exit 1
fi

if [ ! -x "$VENV_PY" ]; then
  echo "missing_venv_python=$VENV_PY" >&2
  exit 1
fi

if [ ! -f "$CSV_PATH" ]; then
  echo "missing_csv=$CSV_PATH" >&2
  exit 1
fi

echo "csv_path=$CSV_PATH"
echo "model_id=$MODEL_ID"
echo "pred_len=$PRED_LEN"
echo "lookback=$LOOKBACK"
echo "device=$DEVICE"
echo "sample_count=$SAMPLE_COUNT"
echo "output_json=$OUT_JSON"

"$VENV_PY" "$PREDICT_PY" \
  --csv "$CSV_PATH" \
  --model "$MODEL_ID" \
  --tokenizer "$TOKENIZER_ID" \
  --lookback "$LOOKBACK" \
  --pred-len "$PRED_LEN" \
  --sample-count "$SAMPLE_COUNT" \
  --device "$DEVICE" \
  --max-context "$MAX_CONTEXT" \
  --output "$OUT_JSON"

echo "saved_to=$OUT_JSON"
