#!/usr/bin/env bash

set -u

PUBKEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICUIun8h5d8/QIg9jWmJap6WUla1cwe6NjWvRYKB515 openclaw-spark-f153-2026-03-16'
KEY_TAG='openclaw-spark-f153-2026-03-16'

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

OUT="$DESKTOP_DIR/spark_f153_stage1_prepare_ssh_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "pwd=$(pwd)"

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
echo "===== local_network ====="
ip -brief addr 2>/dev/null || true
echo
ip route 2>/dev/null || true

echo
echo "===== public_egress_ip ====="
PUBLIC_IP="$(
  curl --noproxy '*' -4 -fsSL https://api.ipify.org 2>/dev/null ||
  curl --noproxy '*' -4 -fsSL https://ipv4.icanhazip.com 2>/dev/null ||
  echo unknown
)"
echo "public_ip=$PUBLIC_IP"
echo "ssh_port=22"

echo
echo "===== ssh_status ====="
ss -lnt 2>/dev/null | grep -E '(^State|:22 )' || true
echo
systemctl --no-pager --full status ssh.socket ssh.service 2>/dev/null || true

echo
echo "===== sudo_check ====="
if sudo -v; then
  echo "sudo_ok=yes"
else
  echo "sudo_ok=no"
fi

echo
echo "===== openclaw_status ====="
if command -v openclaw >/dev/null 2>&1; then
  openclaw --version || true
  systemctl --user show openclaw-gateway -p ActiveState -p SubState -p NRestarts -p ExecMainStartTimestamp --no-pager 2>/dev/null || true
else
  echo "openclaw=missing"
fi

echo
echo "===== done ====="
echo "saved_to=$OUT"
