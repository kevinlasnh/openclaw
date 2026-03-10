#!/bin/bash
SRC="/home/kevinlasnh/.openclaw/agents/main/sessions/backup-2026-02-18"
DST="/home/kevinlasnh/.openclaw/agents/main/sessions"
cp "$SRC/sessions.json" "$DST/sessions.json"
cp "$SRC"/*.jsonl "$DST/"
echo "Restored: $(ls "$DST"/*.jsonl 2>/dev/null | wc -l) jsonl files"
