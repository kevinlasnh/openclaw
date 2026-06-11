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

OUT="$DESKTOP_DIR/spark_f153_tailscale_install_snap_$(date +%Y%m%d_%H%M%S).txt"
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
run "snap_binary" "command -v snap || echo snap_missing"
run "snapd_status_before" "systemctl status snapd --no-pager -l || true"
run "ensure_snapd" "sudo systemctl enable --now snapd || true; sudo systemctl enable --now snapd.socket || true; systemctl status snapd snapd.socket --no-pager -l || true"
run "snap_version" "snap version || true"
run "install_tailscale_snap" "sudo snap install tailscale || true"
run "snap_list" "snap list tailscale || true"
run "tailscale_binary_paths" "command -v tailscale || true; [ -x /snap/bin/tailscale ] && echo /snap/bin/tailscale || true"
run "start_tailscale_snap_service" "sudo snap start tailscale.tailscaled || true; sudo snap services tailscale || true"
run "tailscale_version" "/snap/bin/tailscale version || tailscale version || true"

echo
echo "===== done ====="
echo "saved_to=$OUT"
