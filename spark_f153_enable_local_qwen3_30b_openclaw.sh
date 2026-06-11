#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export OLLAMA_BASE_MODEL_TAG="qwen3:30b"
export OLLAMA_TUNED_MODEL_TAG="qwen3-openclaw:30b"
export OPENCLAW_MODEL_ALIAS="Local Qwen3 30B (64K)"
export OPENCLAW_PROVIDER_ID="ollama"
export OLLAMA_CONTEXT_SIZE="65536"

exec "$SCRIPT_DIR/spark_f153_enable_local_llama_openclaw.sh"
