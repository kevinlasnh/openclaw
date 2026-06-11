#!/usr/bin/env bash

set -u

TS_HOSTNAME="${TS_HOSTNAME:-spark-f153}"
TS_TAGS="${TS_TAGS:-tag:client-spark-f153}"
TS_ACCEPT_DNS="${TS_ACCEPT_DNS:-false}"
TS_ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-false}"
TS_AUTHKEY="${TS_AUTHKEY:-}"

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

OUT="$DESKTOP_DIR/spark_f153_stage3_join_kevin_tailnet_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "ts_hostname=$TS_HOSTNAME"
echo "ts_tags=$TS_TAGS"
echo "ts_accept_dns=$TS_ACCEPT_DNS"
echo "ts_accept_routes=$TS_ACCEPT_ROUTES"

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

if [ -z "$TS_AUTHKEY" ]; then
  echo
  echo "===== authkey_prompt ====="
  echo "Paste the Tailscale auth key for Kevin's tailnet. Input is hidden."
  IFS= read -r -s TS_AUTHKEY
  echo
fi

if [ -z "$TS_AUTHKEY" ]; then
  echo "authkey_status=empty"
  echo
  echo "===== done ====="
  echo "saved_to=$OUT"
  exit 1
fi
echo "authkey_status=provided"

echo
echo "===== install_tailscale ====="
if command -v tailscale >/dev/null 2>&1; then
  echo "tailscale_install=already_present"
else
  curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

echo
echo "===== enable_service ====="
sudo systemctl enable --now tailscaled
sudo systemctl --no-pager --full status tailscaled || true

echo
echo "===== join_tailnet ====="
sudo tailscale logout >/dev/null 2>&1 || true
sudo tailscale up \
  --auth-key "$TS_AUTHKEY" \
  --hostname "$TS_HOSTNAME" \
  --advertise-tags "$TS_TAGS" \
  --ssh=false \
  --accept-dns="$TS_ACCEPT_DNS" \
  --accept-routes="$TS_ACCEPT_ROUTES"

echo
echo "===== tailscale_info ====="
tailscale version || true
echo
echo "tailscale_ipv4=$(tailscale ip -4 2>/dev/null | head -n 1)"
echo "tailscale_ipv6=$(tailscale ip -6 2>/dev/null | head -n 1)"
echo
tailscale status || true
echo
tailscale netcheck || true

echo
echo "===== ssh_recheck ====="
ss -lnt 2>/dev/null | grep -E '(^State|:22 )' || true
echo
systemctl --no-pager --full status ssh.socket ssh.service 2>/dev/null || true

echo
echo "===== openclaw_recheck ====="
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
  systemctl --user show openclaw-gateway -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp --no-pager 2>/dev/null || true
fi

echo
echo "===== done ====="
echo "saved_to=$OUT"
