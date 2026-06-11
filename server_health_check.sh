#!/usr/bin/env bash

set -uo pipefail

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
  "$@" 2>&1 || true
}

run_sh() {
  local title="$1"
  shift
  section "$title"
  printf '+ %s\n' "$*"
  bash -lc "$*" 2>&1 || true
}

timeout_prefix() {
  if command -v timeout >/dev/null 2>&1; then
    printf 'timeout %ss ' "${1:-20}"
  fi
}

section "summary"
printf 'generated_at=%s\n' "$(date -Is 2>/dev/null || date)"
printf 'host=%s\n' "$(hostname 2>/dev/null || true)"
printf 'user=%s\n' "$(id -un 2>/dev/null || true)"
printf 'pwd=%s\n' "$(pwd)"

run "host_identity" hostnamectl
run "uptime" uptime
run "memory" free -h
run "swap" swapon --show
run "filesystems" df -hT / /home

run_sh "failed_units" "systemctl --failed --no-pager || true; systemctl --user --failed --no-pager || true"

run_sh "system_services_core" "systemctl show tailscaled ssh cron openclaw-sshd-2222 docker containerd NetworkManager systemd-resolved ufw -p Id -p ActiveState -p SubState -p UnitFileState --no-pager 2>/dev/null || true"

run_sh "tailscale_status" "$(timeout_prefix 20)tailscale version 2>/dev/null || true; $(timeout_prefix 20)tailscale status 2>/dev/null || true; $(timeout_prefix 20)tailscale netcheck 2>/dev/null || true"
run_sh "tailscale_funnel" "$(timeout_prefix 20)tailscale serve status 2>/dev/null || true; $(timeout_prefix 20)tailscale funnel status 2>/dev/null || true"

run_sh "listeners_interest" "ss -ltnup 2>/dev/null | grep -E ':(22|2222|443|8443|8787|8788|18790|18792|19001|19003|19021|19023|19041|19043|7897|7890|5334|3310)\\b' || true"

run_sh "mihomo_service" "systemctl --user show mihomo-standalone -p Id -p ActiveState -p SubState -p UnitFileState -p ExecMainStartTimestamp -p NRestarts --no-pager 2>/dev/null || true"
run_sh "proxy_probe_7897" "$(timeout_prefix 12)curl -x http://127.0.0.1:7897 -sS -o /dev/null -w 'proxy7897_https_gstatic=%{http_code} time=%{time_total}\\n' https://www.gstatic.com/generate_204 || true"
run_sh "proxy_probe_7890" "$(timeout_prefix 5)curl -x http://127.0.0.1:7890 -sS -o /dev/null -w 'proxy7890_https_gstatic=%{http_code} time=%{time_total}\\n' https://www.gstatic.com/generate_204 || true"
run_sh "mihomo_health_groups" "grep -nE '^(mixed-port|mode|keep-alive|tcp-concurrent)|telegram-jp-tw-stable|interval: 5|url: .*generate_204|自动选择|lazy:' ~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml 2>/dev/null | sed -n '1,140p' || true"

run "openclaw_version" openclaw --version
run_sh "openclaw_services" "systemctl --user show openclaw-gateway openclaw-gateway-dayong openclaw-gateway-chunyan openclaw-gateway-zenglan -p Id -p ActiveState -p SubState -p UnitFileState -p ExecMainStartTimestamp -p NRestarts -p MemoryCurrent --no-pager 2>/dev/null || true"

section "openclaw_config_and_health"
for state_dir in "$HOME/.openclaw" "$HOME/.openclaw-dayong" "$HOME/.openclaw-chunyan" "$HOME/.openclaw-zenglan"; do
  cfg="$state_dir/openclaw.json"
  printf '\n--- %s ---\n' "$state_dir"
  if [ -f "$cfg" ]; then
    OPENCLAW_STATE_DIR="$state_dir" OPENCLAW_CONFIG_PATH="$cfg" $(timeout_prefix 20)openclaw config validate 2>&1 || true
    OPENCLAW_STATE_DIR="$state_dir" OPENCLAW_CONFIG_PATH="$cfg" $(timeout_prefix 25)openclaw gateway health --json 2>&1 | head -80 || true
  else
    printf 'missing_config=%s\n' "$cfg"
  fi
done

run_sh "main_cron_status" "OPENCLAW_STATE_DIR=\$HOME/.openclaw OPENCLAW_CONFIG_PATH=\$HOME/.openclaw/openclaw.json $(timeout_prefix 20)openclaw cron status --json 2>/dev/null || true"
run_sh "main_cron_list_head" "OPENCLAW_STATE_DIR=\$HOME/.openclaw OPENCLAW_CONFIG_PATH=\$HOME/.openclaw/openclaw.json $(timeout_prefix 20)openclaw cron list --json 2>/dev/null | head -180 || true"

run_sh "main_session_locks" "find ~/.openclaw/agents/main/sessions -maxdepth 1 -name '*.lock' -printf '%TY-%Tm-%Td %TH:%TM %p\\n' 2>/dev/null | sort || true"
run_sh "main_recent_errors" "journalctl --user -u openclaw-gateway --since '60 minutes ago' --no-pager 2>/dev/null | grep -Ei 'stuck session|webhook advertised|sendMessage ok|sendMessage failed|PluginLoadFailure|rate limit|429|Vulkan|OutOfDeviceMemory|failed|error|ready' | tail -140 || true"

run_sh "top_memory_processes" "ps -eo pid,ppid,stat,pcpu,pmem,rss,vsz,cmd --sort=-rss | head -30"
run_sh "gpu_status" "nvidia-smi 2>/dev/null || true"

section "done"
