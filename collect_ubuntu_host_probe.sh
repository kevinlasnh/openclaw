#!/usr/bin/env bash

set -u

HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"
STAMP="$(date +%Y%m%d_%H%M%S)"

DESKTOP_DIR=""
if have xdg-user-dir; then
  DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
fi
if [ -z "$DESKTOP_DIR" ]; then
  DESKTOP_DIR="$HOME/Desktop"
fi
mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
if [ ! -d "$DESKTOP_DIR" ] || [ ! -w "$DESKTOP_DIR" ]; then
  DESKTOP_DIR="$HOME"
fi

OUT="$DESKTOP_DIR/openclaw_host_probe_${HOSTNAME_SHORT}_${STAMP}.txt"

exec > >(tee -a "$OUT") 2>&1

have() {
  command -v "$1" >/dev/null 2>&1
}

section() {
  printf '\n===== %s =====\n' "$1"
}

run() {
  local title="$1"
  shift
  section "$title"
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@" || true
}

run_sh() {
  local title="$1"
  shift
  section "$title"
  printf '+ %s\n' "$*"
  bash -lc "$*" || true
}

SUDO_MODE="none"
if [ "$(id -u)" -eq 0 ]; then
  SUDO_CMD=""
  SUDO_MODE="root"
elif have sudo && sudo -n true 2>/dev/null; then
  SUDO_CMD="sudo -n"
  SUDO_MODE="passwordless-sudo"
else
  SUDO_CMD=""
fi

TIMEOUT_CMD=""
if have timeout; then
  TIMEOUT_CMD="timeout 12s"
fi

section "summary"
printf 'report_file=%s\n' "$OUT"
printf 'generated_at=%s\n' "$(date -Is)"
printf 'hostname=%s\n' "$(hostname 2>/dev/null || true)"
printf 'current_user=%s\n' "$(id -un 2>/dev/null || true)"
printf 'sudo_mode=%s\n' "$SUDO_MODE"
printf 'pwd=%s\n' "$(pwd)"

run "identity" id

if have hostnamectl; then
  run "hostnamectl" hostnamectl
fi

if [ -r /etc/os-release ]; then
  run "os_release" cat /etc/os-release
fi

run "kernel" uname -a

if have uptime; then
  run "uptime" uptime
fi

if have timedatectl; then
  run "timedatectl" timedatectl
fi

if have systemd-detect-virt; then
  run "virtualization" systemd-detect-virt
fi

if have lscpu; then
  run "cpu" lscpu
fi

if have free; then
  run "memory" free -h
fi

if have swapon; then
  run "swap" swapon --show
fi

if have lsblk; then
  run "block_devices" lsblk -e7 -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINTS
fi

if have df; then
  run "filesystems" df -hT
fi

if have findmnt; then
  run "mounts" findmnt
fi

if have ip; then
  run "network_addr" ip -brief addr
  run "network_route" ip route
fi

if have resolvectl; then
  run "dns" resolvectl status
elif [ -r /etc/resolv.conf ]; then
  run "dns" cat /etc/resolv.conf
fi

if have ss; then
  run "listeners" ss -lntup
fi

run_sh "proxy_env_masked" "env | grep -Ei '^(http|https|all|no)_proxy=' | sed -E 's#=(.*)\$#=<set>#I' || true"

run_sh "tool_paths" "for x in ssh sshd scp sftp curl wget git jq python3 pip3 node npm pnpm yarn docker podman tailscale ufw tmux screen openclaw; do printf '%-12s -> ' \"\$x\"; command -v \"\$x\" || echo missing; done"

if have dpkg; then
  run_sh "packages_interest" "dpkg -l openssh-server curl git jq python3 python3-pip nodejs npm tmux screen ufw tailscale 2>/dev/null || true"
fi

if have systemctl; then
  run_sh "system_services_interest" "systemctl list-unit-files --type=service | egrep '^(ssh|sshd|tailscaled|docker|openclaw)' || true"
  run_sh "user_services_interest" "systemctl --user list-unit-files --type=service | egrep '^openclaw' || true"
  run_sh "ssh_service_status" "systemctl status ssh --no-pager -l || systemctl status sshd --no-pager -l || true"
  run_sh "tailscaled_status" "systemctl status tailscaled --no-pager -l || true"
  run_sh "openclaw_user_status" "systemctl --user status openclaw-gateway --no-pager -l || true"
fi

if have sshd; then
  run_sh "sshd_effective_config" "sshd -T 2>/dev/null | egrep '^(port|listenaddress|permitrootlogin|passwordauthentication|pubkeyauthentication|kbdinteractiveauthentication|challengeresponseauthentication|usepam|allowusers|authorizedkeysfile|maxsessions|x11forwarding|permittty|banner) ' || true"
fi

run_sh "user_groups" "getent group sudo || true; getent group adm || true"
run_sh "home_ssh_permissions" "ls -ld ~ ~/.ssh 2>/dev/null || true; find ~/.ssh -maxdepth 1 -type f -printf '%M %u %g %TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort || true; [ -f ~/.ssh/authorized_keys ] && wc -l ~/.ssh/authorized_keys || true"

if have ufw; then
  if [ -n "$SUDO_CMD" ]; then
    run_sh "ufw_status" "$SUDO_CMD ufw status verbose || true"
  else
    run_sh "ufw_status" "ufw status verbose || true"
  fi
fi

if have tailscale; then
  run "tailscale_version" tailscale version
  if [ -n "$TIMEOUT_CMD" ]; then
    run_sh "tailscale_status" "$TIMEOUT_CMD tailscale status || true"
    run_sh "tailscale_netcheck" "$TIMEOUT_CMD tailscale netcheck || true"
  else
    run_sh "tailscale_status" "tailscale status || true"
    run_sh "tailscale_netcheck" "tailscale netcheck || true"
  fi
fi

if have openclaw; then
  run "openclaw_version" openclaw --version
  if have npm; then
    run_sh "openclaw_global_npm" "npm -g ls --depth=0 2>/dev/null | grep -i openclaw || true"
  fi
fi

section "done"
printf 'Saved to: %s\n' "$OUT"
