#!/usr/bin/env bash

set -u

KEY_TAG='openclaw-spark-f153-2026-03-16'
REMOTE_IP_PATTERNS='100\.97\.45\.87|desktop-jrvidlh|openclaw-spark-f153-2026-03-16|1114087661\.kevin@'
PURGE_TAILSCALE_STATE="${PURGE_TAILSCALE_STATE:-true}"
UNINSTALL_TAILSCALE="${UNINSTALL_TAILSCALE:-true}"
REMOVE_REPORTS="${REMOVE_REPORTS:-true}"
CLEAN_BASH_HISTORY="${CLEAN_BASH_HISTORY:-true}"
REMOVE_SCRIPTS="${REMOVE_SCRIPTS:-true}"

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

OUT="$DESKTOP_DIR/spark_f153_security_cleanup_hard_$(date +%Y%m%d_%H%M%S).txt"
exec > >(tee -a "$OUT") 2>&1

section() {
  echo
  echo "===== $1 ====="
}

run() {
  section "$1"
  shift
  echo "+ $*"
  bash -lc "$*" || true
}

echo "===== summary ====="
echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "hostname=$(hostname 2>/dev/null || true)"
echo "current_user=$(id -un 2>/dev/null || true)"
echo "purge_tailscale_state=$PURGE_TAILSCALE_STATE"
echo "uninstall_tailscale=$UNINSTALL_TAILSCALE"
echo "remove_reports=$REMOVE_REPORTS"
echo "clean_bash_history=$CLEAN_BASH_HISTORY"
echo "remove_scripts=$REMOVE_SCRIPTS"

run "sudo_check" "sudo -v && echo sudo_ok=yes"

section "remove_pubkey"
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

section "leave_tailnet"
TS_BIN=""
if command -v tailscale >/dev/null 2>&1; then
  TS_BIN="$(command -v tailscale)"
elif [ -x /snap/bin/tailscale ]; then
  TS_BIN="/snap/bin/tailscale"
fi
if [ -n "$TS_BIN" ]; then
  sudo "$TS_BIN" logout || true
  echo "tailscale_logout=done"
else
  echo "tailscale_logout=skipped_no_binary"
fi

section "stop_disable_tailscale"
if systemctl list-unit-files 2>/dev/null | grep -q '^tailscaled\.service'; then
  sudo systemctl disable --now tailscaled || true
  echo "tailscaled_service=disabled"
fi
if command -v snap >/dev/null 2>&1 && snap list tailscale >/dev/null 2>&1; then
  sudo snap stop tailscale.tailscaled || true
  echo "tailscale_snap_service=stopped"
fi

section "purge_tailscale_state"
if [ "$PURGE_TAILSCALE_STATE" = "true" ]; then
  sudo rm -rf /var/lib/tailscale 2>/dev/null || true
  sudo rm -rf /var/snap/tailscale/common 2>/dev/null || true
  sudo rm -rf /var/snap/tailscale/current 2>/dev/null || true
  echo "tailscale_state=purged"
else
  echo "tailscale_state=kept"
fi

section "uninstall_tailscale"
if [ "$UNINSTALL_TAILSCALE" = "true" ]; then
  if command -v snap >/dev/null 2>&1 && snap list tailscale >/dev/null 2>&1; then
    sudo snap remove --purge tailscale || true
    echo "tailscale_snap=removed_if_present"
  elif command -v dpkg >/dev/null 2>&1 && dpkg -l tailscale 2>/dev/null | grep -q '^ii'; then
    sudo apt-get remove --purge -y tailscale || true
    echo "tailscale_deb=removed_if_present"
  else
    echo "tailscale_package=not_installed"
  fi
else
  echo "tailscale_package=kept"
fi

section "remove_remote_reports"
if [ "$REMOVE_REPORTS" = "true" ]; then
  rm -f "$HOME"/Desktop/spark_f153_* "$HOME"/Desktop/openclaw_host_probe_* 2>/dev/null || true
  rm -f "$HOME"/spark_f153_* "$HOME"/openclaw_host_probe_* 2>/dev/null || true
  rm -f /tmp/spark_f153_* /tmp/openclaw_host_probe_* 2>/dev/null || true
  echo "report_files=removed_if_present"
else
  echo "report_files=kept"
fi

section "remove_remote_scripts"
if [ "$REMOVE_SCRIPTS" = "true" ]; then
  rm -f "$HOME"/Desktop/spark_f153_*.sh "$HOME"/Desktop/openclaw_probe.sh 2>/dev/null || true
  rm -f "$HOME"/spark_f153_*.sh "$HOME"/openclaw_probe.sh 2>/dev/null || true
  rm -f /tmp/spark_f153_*.sh /tmp/openclaw_probe.sh 2>/dev/null || true
  echo "script_files=removed_if_present"
else
  echo "script_files=kept"
fi

section "clean_known_hosts"
if [ -f "$HOME/.ssh/known_hosts" ]; then
  ssh-keygen -R 100.97.45.87 -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 || true
  ssh-keygen -R desktop-jrvidlh -f "$HOME/.ssh/known_hosts" >/dev/null 2>&1 || true
  TMP_FILE="$(mktemp)"
  if grep -Ev "$REMOTE_IP_PATTERNS" "$HOME/.ssh/known_hosts" > "$TMP_FILE"; then
    cat "$TMP_FILE" > "$HOME/.ssh/known_hosts"
  else
    : > "$HOME/.ssh/known_hosts"
  fi
  rm -f "$TMP_FILE"
  chmod 600 "$HOME/.ssh/known_hosts" 2>/dev/null || true
  echo "known_hosts=cleaned"
else
  echo "known_hosts=no_file"
fi

section "clean_bash_history"
if [ "$CLEAN_BASH_HISTORY" = "true" ] && [ -f "$HOME/.bash_history" ]; then
  TMP_FILE="$(mktemp)"
  if grep -Ev 'spark_f153_|openclaw_host_probe_|openclaw-spark-f153-2026-03-16|tailscale up|tskey-auth' "$HOME/.bash_history" > "$TMP_FILE"; then
    cat "$TMP_FILE" > "$HOME/.bash_history"
  else
    : > "$HOME/.bash_history"
  fi
  rm -f "$TMP_FILE"
  chmod 600 "$HOME/.bash_history" 2>/dev/null || true
  echo "bash_history=cleaned"
else
  echo "bash_history=kept_or_missing"
fi

run "postcheck_auth" "grep -n '$KEY_TAG' ~/.ssh/authorized_keys ~/.ssh/known_hosts ~/.bash_history 2>/dev/null || true"
run "postcheck_tailscale" "command -v tailscale || true; [ -x /snap/bin/tailscale ] && echo /snap/bin/tailscale || true; systemctl status tailscaled --no-pager -l || true; snap list tailscale || true"
run "postcheck_reports" "ls -1 ~/Desktop/spark_f153_* ~/Desktop/openclaw_host_probe_* ~/spark_f153_* ~/openclaw_host_probe_* /tmp/spark_f153_* /tmp/openclaw_host_probe_* 2>/dev/null || true"

echo
echo "===== done ====="
echo "saved_to=$OUT"
