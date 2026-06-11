#!/usr/bin/env bash

set -u

KEY_TAG='openclaw-spark-f153-2026-03-16'
PURGE_TAILSCALE_STATE="${PURGE_TAILSCALE_STATE:-false}"

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

OUT="$DESKTOP_DIR/spark_f153_maintenance_mode_disable_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "purge_tailscale_state=$PURGE_TAILSCALE_STATE"

echo
echo "===== sudo_check ====="
if ! sudo -v; then
  echo "sudo_ok=no"
  echo
  echo "===== done ====="
  echo "saved_to=$OUT"
  exit 1
fi
echo "sudo_ok=yes"

echo
echo "===== remove_pubkey ====="
if [ -f "$HOME/.ssh/authorized_keys" ]; then
  TMP_FILE="$(mktemp)"
  if grep -Fv "$KEY_TAG" "$HOME/.ssh/authorized_keys" > "$TMP_FILE"; then
    cat "$TMP_FILE" > "$HOME/.ssh/authorized_keys"
  else
    : > "$HOME/.ssh/authorized_keys"
  fi
  rm -f "$TMP_FILE"
  chmod 600 "$HOME/.ssh/authorized_keys"
  echo "pubkey_status=removed_if_present"
  echo "authorized_keys_lines=$(wc -l < "$HOME/.ssh/authorized_keys")"
else
  echo "pubkey_status=no_authorized_keys_file"
fi

echo
echo "===== leave_tailnet ====="
if command -v tailscale >/dev/null 2>&1; then
  TS_BIN="$(command -v tailscale)"
  sudo "$TS_BIN" logout || true
  sudo systemctl disable --now tailscaled || true
  echo "tailscale_status=logged_out_and_disabled"
elif [ -x /snap/bin/tailscale ]; then
  TS_BIN="/snap/bin/tailscale"
  sudo "$TS_BIN" logout || true
  sudo snap stop tailscale.tailscaled || true
  echo "tailscale_status=snap_logged_out_and_stopped"
else
  echo "tailscale_status=not_installed"
fi

echo
echo "===== optional_purge ====="
if [ "$PURGE_TAILSCALE_STATE" = "true" ]; then
  sudo rm -f /var/lib/tailscale/tailscaled.state || true
  echo "tailscale_state=removed"
else
  echo "tailscale_state=kept"
fi

echo
echo "===== postcheck ====="
ss -lnt 2>/dev/null | grep -E '(^State|:22 )' || true
echo
systemctl --no-pager --full status ssh.socket ssh.service 2>/dev/null || true
echo
if command -v tailscale >/dev/null 2>&1; then
  tailscale status || true
elif [ -x /snap/bin/tailscale ]; then
  /snap/bin/tailscale status || true
fi

echo
echo "===== done ====="
echo "saved_to=$OUT"
