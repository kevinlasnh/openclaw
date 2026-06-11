#!/usr/bin/env bash

set -u

TS_HOSTNAME="${TS_HOSTNAME:-spark-f153}"
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

OUT="$DESKTOP_DIR/spark_f153_stage2_install_tailscale_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "ts_hostname=$TS_HOSTNAME"
echo "ts_accept_dns=$TS_ACCEPT_DNS"
echo "ts_accept_routes=$TS_ACCEPT_ROUTES"
if [ -n "$TS_AUTHKEY" ]; then
  echo "ts_authkey=provided"
else
  echo "ts_authkey=not_provided"
fi

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
echo "===== install_tailscale ====="
if command -v tailscale >/dev/null 2>&1; then
  echo "tailscale_install=already_present"
else
  curl -fsSL https://tailscale.com/install.sh | sudo sh
fi

echo
echo "===== service_status ====="
sudo systemctl enable --now tailscaled
sudo systemctl --no-pager --full status tailscaled || true

echo
echo "===== tailscale_up ====="
if [ -n "$TS_AUTHKEY" ]; then
  sudo tailscale up \
    --auth-key "$TS_AUTHKEY" \
    --hostname "$TS_HOSTNAME" \
    --ssh=false \
    --accept-dns="$TS_ACCEPT_DNS" \
    --accept-routes="$TS_ACCEPT_ROUTES"
else
  echo "No TS_AUTHKEY provided."
  echo "The next command may print a login URL that must be opened in a browser:"
  sudo tailscale up \
    --hostname "$TS_HOSTNAME" \
    --ssh=false \
    --accept-dns="$TS_ACCEPT_DNS" \
    --accept-routes="$TS_ACCEPT_ROUTES" || true
fi

echo
echo "===== tailscale_info ====="
tailscale version || true
echo
tailscale ip -4 || true
echo
tailscale ip -6 || true
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
echo "===== done ====="
echo "saved_to=$OUT"
