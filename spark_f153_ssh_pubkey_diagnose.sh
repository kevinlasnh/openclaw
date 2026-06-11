#!/usr/bin/env bash

set -u

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

OUT="$DESKTOP_DIR/spark_f153_ssh_pubkey_diagnose_$(date +%Y%m%d_%H%M%S).txt"
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
run "identity" "id"
run "home_permissions" "ls -ld ~ ~/.ssh ~/.ssh/authorized_keys 2>/dev/null || true; echo; stat ~ ~/.ssh ~/.ssh/authorized_keys 2>/dev/null || true"
run "authorized_key_match" "grep -n '$KEY_TAG' ~/.ssh/authorized_keys || true"
run "authorized_keys_tail" "tail -n 20 ~/.ssh/authorized_keys 2>/dev/null || true"
run "sshd_effective_config" "sudo sshd -T 2>/dev/null | egrep '^(authorizedkeysfile|pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|usepam|permitrootlogin|allowusers|denyusers|pubkeyacceptedalgorithms|strictmodes|maxauthtries) ' || true"
run "sshd_status" "systemctl status ssh.socket ssh.service --no-pager -l || true"
run "auth_log_recent" "sudo journalctl -u ssh -n 200 --no-pager || true"
run "sshd_log_recent" "sudo journalctl -t sshd -n 200 --no-pager || true"

echo
echo "===== done ====="
echo "saved_to=$OUT"
