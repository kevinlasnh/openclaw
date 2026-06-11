#!/usr/bin/env bash

set -u

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICUIun8h5d8/QIg9jWmJap6WUla1cwe6NjWvRYKB515 openclaw-spark-f153-2026-03-16'
KEY_TAG='openclaw-spark-f153-2026-03-16'
TS_HOSTNAME="${TS_HOSTNAME:-spark-f153}"
TS_ACCEPT_DNS="${TS_ACCEPT_DNS:-false}"
TS_ACCEPT_ROUTES="${TS_ACCEPT_ROUTES:-false}"
TS_AUTHKEY="${TS_AUTHKEY:-}"
TS_ADVERTISE_TAGS="${TS_ADVERTISE_TAGS:-}"

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

OUT="$DESKTOP_DIR/spark_f153_maintenance_mode_enable_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "ts_hostname=$TS_HOSTNAME"
echo "ts_accept_dns=$TS_ACCEPT_DNS"
echo "ts_accept_routes=$TS_ACCEPT_ROUTES"
if [ -n "$TS_ADVERTISE_TAGS" ]; then
  echo "ts_advertise_tags=$TS_ADVERTISE_TAGS"
else
  echo "ts_advertise_tags=<none>"
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
echo "===== install_pubkey ====="
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if grep -Fq "$KEY_TAG" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
  echo "pubkey_status=already_present"
else
  printf '%s\n' "$PUBKEY" >> "$HOME/.ssh/authorized_keys"
  echo "pubkey_status=added"
fi
chmod 600 "$HOME/.ssh/authorized_keys"
echo "authorized_keys_lines=$(wc -l < "$HOME/.ssh/authorized_keys")"

echo
echo "===== tailscale_authkey ====="
if [ -z "$TS_AUTHKEY" ]; then
  echo "Paste the reusable Tailscale auth key for Kevin's tailnet. Input is hidden."
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

TS_BIN=""
if command -v tailscale >/dev/null 2>&1; then
  TS_BIN="$(command -v tailscale)"
elif [ -x /snap/bin/tailscale ]; then
  TS_BIN="/snap/bin/tailscale"
fi

echo
echo "===== install_tailscale ====="
if command -v tailscale >/dev/null 2>&1; then
  echo "tailscale_install=already_present"
else
  INSTALL_OK="false"

  if command -v curl >/dev/null 2>&1; then
    if curl -fsSL https://tailscale.com/install.sh | sudo sh; then
      INSTALL_OK="true"
      echo "tailscale_install_method=official_script"
    else
      echo "tailscale_install_method=official_script_failed"
    fi
  fi

  if [ "$INSTALL_OK" != "true" ] && command -v snap >/dev/null 2>&1; then
    if sudo snap install tailscale; then
      INSTALL_OK="true"
      echo "tailscale_install_method=snap"
    else
      echo "tailscale_install_method=snap_failed"
    fi
  fi

  if [ "$INSTALL_OK" != "true" ]; then
    echo "tailscale_install=failed"
    echo
    echo "===== done ====="
    echo "saved_to=$OUT"
    exit 1
  fi
fi

if [ -z "$TS_BIN" ]; then
  if command -v tailscale >/dev/null 2>&1; then
    TS_BIN="$(command -v tailscale)"
  elif [ -x /snap/bin/tailscale ]; then
    TS_BIN="/snap/bin/tailscale"
  fi
fi

if [ -z "$TS_BIN" ]; then
  echo "tailscale_binary=not_found_after_install"
  echo
  echo "===== done ====="
  echo "saved_to=$OUT"
  exit 1
fi
echo "tailscale_binary=$TS_BIN"

echo
echo "===== enable_tailscaled ====="
if systemctl list-unit-files 2>/dev/null | grep -q '^tailscaled\.service'; then
  sudo systemctl enable --now tailscaled
  sudo systemctl --no-pager --full status tailscaled || true
elif command -v snap >/dev/null 2>&1 && snap list tailscale >/dev/null 2>&1; then
  sudo snap start tailscale.tailscaled || true
  sudo snap services tailscale || true
else
  echo "tailscaled_service=not_found_after_install"
  echo
  echo "===== done ====="
  echo "saved_to=$OUT"
  exit 1
fi

echo
echo "===== join_tailnet ====="
UP_ARGS=(
  --auth-key "$TS_AUTHKEY"
  --hostname "$TS_HOSTNAME"
  --ssh=false
  --accept-dns="$TS_ACCEPT_DNS"
  --accept-routes="$TS_ACCEPT_ROUTES"
)
if [ -n "$TS_ADVERTISE_TAGS" ]; then
  UP_ARGS+=(--advertise-tags "$TS_ADVERTISE_TAGS")
fi
sudo "$TS_BIN" logout >/dev/null 2>&1 || true
sudo "$TS_BIN" up "${UP_ARGS[@]}"

echo
echo "===== tailscale_info ====="
"$TS_BIN" version || true
echo
echo "tailscale_ipv4=$("$TS_BIN" ip -4 2>/dev/null | head -n 1)"
echo "tailscale_ipv6=$("$TS_BIN" ip -6 2>/dev/null | head -n 1)"
echo
"$TS_BIN" status || true

echo
echo "===== ssh_status ====="
ss -lnt 2>/dev/null | grep -E '(^State|:22 )' || true
echo
systemctl --no-pager --full status ssh.socket ssh.service 2>/dev/null || true

echo
echo "===== openclaw_status ====="
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
  systemctl --user show openclaw-gateway -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp --no-pager 2>/dev/null || true
fi

echo
echo "===== done ====="
echo "saved_to=$OUT"
