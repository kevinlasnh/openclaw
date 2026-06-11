#!/usr/bin/env python3
import argparse
import json
import os
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(description="Run Kronos forecast on OHLCV CSV data.")
    parser.add_argument("--csv", required=True, help="Path to OHLCV CSV file.")
    parser.add_argument("--timestamp-col", default="timestamps", help="Timestamp column name.")
    parser.add_argument("--model", default="NeoQuasar/Kronos-small", help="HF model id.")
    parser.add_argument(
        "--tokenizer",
        default="NeoQuasar/Kronos-Tokenizer-base",
        help="HF tokenizer id.",
    )
    parser.add_argument("--lookback", type=int, default=400, help="Historical bars to use.")
    parser.add_argument("--pred-len", type=int, default=24, help="Bars to predict.")
    parser.add_argument("--temperature", type=float, default=1.0, help="Sampling temperature.")
    parser.add_argument("--top-p", type=float, default=0.9, help="Top-p sampling.")
    parser.add_argument("--top-k", type=int, default=0, help="Top-k sampling.")
    parser.add_argument("--sample-count", type=int, default=1, help="Forecast sample count.")
    parser.add_argument("--device", default="auto", help="cpu | cuda:0 | auto")
    parser.add_argument("--max-context", type=int, default=512, help="Max model context.")
    parser.add_argument("--output", default="", help="Optional JSON output path.")
    return parser.parse_args()


def resolve_runtime():
    root = Path(os.environ.get("OPENCLAW_KRONOS_ROOT", Path.home() / ".openclaw" / "vendor" / "kronos"))
    repo_dir = root / "Kronos"
    venv_python = root / ".venv" / "bin" / "python"
    if not repo_dir.exists():
        raise SystemExit(f"Kronos repo not found: {repo_dir}. Run bootstrap_kronos.sh first.")
    if not venv_python.exists():
        raise SystemExit(f"Kronos venv not found: {venv_python}. Run bootstrap_kronos.sh first.")
    return repo_dir


def choose_device(requested, torch_mod):
    if requested != "auto":
        return requested
    if torch_mod.cuda.is_available():
        return "cuda:0"
    if hasattr(torch_mod.backends, "mps") and torch_mod.backends.mps.is_available():
        return "mps"
    return "cpu"


def main():
    args = parse_args()
    repo_dir = resolve_runtime()
    sys.path.insert(0, str(repo_dir))

    import pandas as pd  # noqa: WPS433
    import torch  # noqa: WPS433
    from model import Kronos, KronosPredictor, KronosTokenizer  # noqa: WPS433

    csv_path = Path(args.csv).expanduser().resolve()
    if not csv_path.exists():
        raise SystemExit(f"CSV not found: {csv_path}")

    df = pd.read_csv(csv_path)
    if args.timestamp_col not in df.columns:
        raise SystemExit(f"Missing timestamp column: {args.timestamp_col}")

    required = ["open", "high", "low", "close"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise SystemExit(f"Missing OHLC columns: {', '.join(missing)}")

    df[args.timestamp_col] = pd.to_datetime(df[args.timestamp_col])
    if len(df) < args.lookback + args.pred_len:
        raise SystemExit(
            f"Not enough rows. Need at least lookback + pred_len = {args.lookback + args.pred_len}, got {len(df)}"
        )

    tokenizer = KronosTokenizer.from_pretrained(args.tokenizer)
    model = Kronos.from_pretrained(args.model)
    device = choose_device(args.device, torch)
    predictor = KronosPredictor(model, tokenizer, device=device, max_context=args.max_context)

    x_df = df.loc[: args.lookback - 1, [c for c in ["open", "high", "low", "close", "volume", "amount"] if c in df.columns]]
    x_timestamp = df.loc[: args.lookback - 1, args.timestamp_col]
    y_timestamp = df.loc[args.lookback : args.lookback + args.pred_len - 1, args.timestamp_col]

    pred_df = predictor.predict(
        df=x_df,
        x_timestamp=x_timestamp,
        y_timestamp=y_timestamp,
        pred_len=args.pred_len,
        T=args.temperature,
        top_k=args.top_k,
        top_p=args.top_p,
        sample_count=args.sample_count,
        verbose=False,
    )

    result = {
        "status": "ok",
        "model": args.model,
        "tokenizer": args.tokenizer,
        "device": device,
        "lookback": args.lookback,
        "pred_len": args.pred_len,
        "input_csv": str(csv_path),
        "last_input_close": float(x_df["close"].iloc[-1]),
        "predicted_last_close": float(pred_df["close"].iloc[-1]),
        "predicted_rows": json.loads(pred_df.reset_index().rename(columns={"index": args.timestamp_col}).to_json(orient="records", date_format="iso")),
    }

    text = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        Path(args.output).expanduser().write_text(text + "\n", encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
