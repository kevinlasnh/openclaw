#!/usr/bin/env bash

set -u

DESKTOP_DIR=""
if command -v xdg-user-dir >/dev/null 2>&1; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
fi
if [ -z "$DESKTOP_DIR" ]; then
  DESKTOP_DIR="$HOME/Desktop"
fi
mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
if [ ! -d "$DESKTOP_DIR" ] || [ ! -w "$DESKTOP_DIR" ]; then
  DESKTOP_DIR="$HOME"
fi

OUT="$DESKTOP_DIR/spark_f153_tailscale_diagnose_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

run() {
  local title="$1"
  shift
  echo
  echo "===== $title ====="
  echo "+ $*"
  bash -lc "$*" || true
}

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"

run "sudo_check" "sudo -v && echo sudo_ok=yes"
run "tailscale_binary" "command -v tailscale || echo tailscale_missing"
run "tailscaled_service" "systemctl status tailscaled --no-pager -l || true"
run "tailscale_version" "tailscale version || true"
run "tailscale_status" "tailscale status || true"
run "tailscale_ip" "tailscale ip -4 || true; echo; tailscale ip -6 || true"
run "tailscale_netcheck" "tailscale netcheck || true"
run "tailscale_prefs" "sudo tailscale debug prefs 2>/dev/null || true"
run "tailscale_state_files" "sudo ls -lah /var/lib/tailscale 2>/dev/null || true"
run "tailscaled_journal" "sudo journalctl -u tailscaled -n 200 --no-pager || true"
run "ssh_status" "ss -lnt | grep -E '(^State|:22 )' || true; echo; systemctl status ssh.socket ssh.service --no-pager -l || true"

echo
echo "===== done ====="
echo "saved_to=$OUT"
