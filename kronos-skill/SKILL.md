---
name: kronos-skill
description: |
  Run Kronos financial K-line forecasts on local OHLCV CSV data. Use when the user wants
  to forecast candlestick sequences, compare likely next bars, or evaluate short-horizon
  market structure from historical OHLCV files. This skill bootstraps a dedicated Python
  runtime, loads an official Kronos model from Hugging Face, and runs the forecast script.
---

# Kronos Skill

Use this skill when the user wants Kronos-based forecasts on market OHLCV/K-line data.

## What It Does

- Sets up a dedicated Kronos runtime under `~/.openclaw/vendor/kronos`
- Clones the official Kronos repository
- Installs the required Python dependencies into an isolated venv
- Runs forecasts from CSV OHLCV files via `scripts/predict_kronos.py`

## Expected Input

The forecast script expects a CSV with:

- Required columns:
  - `timestamps`
  - `open`
  - `high`
  - `low`
  - `close`
- Optional columns:
  - `volume`
  - `amount`

`timestamps` should be parseable by pandas.

## First-Time Bootstrap

If the runtime has not been installed yet, run:

```bash
bash {baseDir}/scripts/bootstrap_kronos.sh
```

The bootstrap creates:

- repo: `~/.openclaw/vendor/kronos/Kronos`
- venv: `~/.openclaw/vendor/kronos/.venv`

## Run a Forecast

Example:

```bash
python3 {baseDir}/scripts/predict_kronos.py \
  --csv /path/to/ohlcv.csv \
  --model NeoQuasar/Kronos-small \
  --lookback 400 \
  --pred-len 24
```

## Model Choices

- `NeoQuasar/Kronos-mini`
- `NeoQuasar/Kronos-small`
- `NeoQuasar/Kronos-base`

Default:

- model: `NeoQuasar/Kronos-small`
- tokenizer: `NeoQuasar/Kronos-Tokenizer-base`

## Notes

- This skill is for forecasting and research support, not automatic order execution.
- Prefer `Kronos-small` first on a fresh machine. Move to `Kronos-base` only after verifying memory/runtime behavior.
- If the user wants uncertainty paths, increase `--sample-count`.
- If the input CSV is longer than the model context, the predictor truncates to the latest context window.
