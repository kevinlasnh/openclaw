# OpenClaw Server Health Checks

## Scope

This runbook covers the live OpenClaw Ubuntu host:

- Host: `kevinlasnh@100.64.65.65`
- Tailnet name: `openclaw-24x7`
- OS baseline on 2026-04-27: Ubuntu 24.04.4 LTS, kernel `6.17.0-19-generic`
- OpenClaw baseline on 2026-04-27: `OpenClaw 2026.4.24`
- Main transport: Telegram webhook through Tailscale Funnel
- Current production proxy: Mihomo on `127.0.0.1:7897`

Default command prefix from this repository:

```bash
ssh kevinlasnh@100.64.65.65 '<command>'
```

Run every check as read-only first. Do not restart, disable, delete locks, or edit OpenClaw config until the failing layer is identified.

## Quick Triage

Use this when the user says "小龙虾卡死了", "Telegram 不回", "代理坏了", or "连不上服务器".

```bash
ssh kevinlasnh@100.64.65.65 'date -Is; uptime; free -h; df -hT / /home'
ssh kevinlasnh@100.64.65.65 'systemctl --failed --no-pager; systemctl --user --failed --no-pager'
ssh kevinlasnh@100.64.65.65 'systemctl is-active tailscaled ssh openclaw-sshd-2222 cron; systemctl --user is-active mihomo-standalone openclaw-gateway openclaw-gateway-dayong openclaw-gateway-chunyan openclaw-gateway-zenglan'
ssh kevinlasnh@100.64.65.65 "ss -ltnup | grep -E ':(22|2222|443|8443|8787|8788|18790|18792|19001|19003|19021|19023|19041|19043|7897|5334|3310)\\b' || true"
ssh kevinlasnh@100.64.65.65 "journalctl --user -u openclaw-gateway --since '30 minutes ago' --no-pager | grep -Ei 'stuck session|webhook advertised|sendMessage failed|PluginLoadFailure|rate limit|Vulkan|failed|error|ready' | tail -80 || true"
```

Healthy quick triage means:

- System and user failed units are empty.
- `tailscaled`, `ssh`, `openclaw-sshd-2222`, `cron`, `mihomo-standalone`, and all four OpenClaw gateways are active.
- `127.0.0.1:7897`, `127.0.0.1:8787`, OpenClaw gateway ports, and `100.64.65.65:2222` are listening.
- Recent main logs show `ready`, `webhook advertised`, and `sendMessage ok`.
- Recent main logs do not continue to emit `stuck session`, plugin load errors, or repeated model/provider errors.

## Check Matrix

| Layer | Check | Healthy Baseline | Red Flags | First Action |
|---|---|---|---|---|
| P0 access | SSH over public/LAN | `ssh.service active`, port `22` listening | Cannot SSH at all | Try Tailscale IP and port `2222`; check local network before touching OpenClaw |
| P0 rescue | SSH over Tailscale | `openclaw-sshd-2222 active`, `100.64.65.65:2222` listening | Port `2222` missing or service failed | Inspect `systemctl status openclaw-sshd-2222`; do not assume gateway failure |
| P0 tailnet | Tailscale daemon | `tailscaled active`, self IP `100.64.65.65` | Node offline, key expired, no DERP/connectivity | Run `tailscale status`, `tailscale netcheck` |
| P1 ingress | Tailscale Funnel | `443 -> 127.0.0.1:8787`, `8443 -> 127.0.0.1:8788` | Funnel missing while local webhook exists | Check `tailscale serve status` and `tailscale funnel status` |
| P1 proxy service | Mihomo | `mihomo-standalone active`, port `7897` | `7897` closed, service inactive | Inspect user service and Mihomo logs |
| P1 proxy health | Outbound probe | `curl -x 127.0.0.1:7897 ...generate_204` returns `204` | Timeout, `000`, high latency | Check Mihomo config and selected node group |
| P1 proxy polling | Mihomo group checks | `telegram-jp-tw-stable interval: 5`, `自动选择 interval: 30` | 5s group missing, Telegram rules not routed | Inspect `clash-verge.yaml` |
| P1 OpenClaw services | Four gateways | All active/enabled | `active` but repeated restarts, high memory, missing ports | Use `systemctl --user show` plus logs, not only `is-active` |
| P1 OpenClaw ports | Local listeners | `18790/18792`, `19001/19003`, `19021/19023`, `19041/19043`, `8787` | Missing `8787` or gateway port | Gateway/channel layer is broken |
| P1 OpenClaw health | Config and channel probe | `config validate` passes, `gateway health ok=true` | Config invalid, channel probe fails | Fix config before restart loops |
| P1 sessions | Locks and stuck work | No persistent `.lock`; no continuing `stuck session` | `*.lock` persists, recurring `stuck session` | Identify session key before deleting anything |
| P1 cron | OpenClaw cron | Enabled jobs are unique and deliverable | Duplicate jobs, `runningAtMs`, `consecutiveErrors > 0`, old model names | Disable or fix only after reading `cron list --json` |
| P2 resources | Host pressure | Disk `/` below 80%, enough memory, swap not rising fast | Memory pressure, swap climbing, disk full | Identify process before restarting services |
| P2 local memory | Vulkan / embedding | No recent Vulkan OOM | `ggml_vulkan ... OutOfDeviceMemory` | Treat as local memory-search/GPU pressure, not Telegram failure |
| P2 tools | MCP/data daemons | `dayong-stock-mcp` on `127.0.0.1:3310` when needed | MCP port missing for stock jobs | Check data service before blaming agent model |
| P2 exposure | Public surfaces | OpenClaw bound to loopback, Funnel intentionally exposes only 443/8443 | OpenClaw gateway bound to public interface | Tighten bind/firewall before expanding services |

## Current Baseline Snapshot

Last verified: `2026-04-27 16:17 CST`.

Host:

- Uptime: about 42 days.
- Memory: 15 GiB total, about 8.3 GiB available.
- Swap: 4 GiB total, about 3 GiB used. This is not an immediate failure, but swap trend should be watched.
- Disk `/`: 468 GiB total, 53 GiB used, 12%.

Tailscale and ingress:

- Tailscale version: `1.96.4`.
- Self node: `openclaw-24x7`, IPs `100.64.65.65` and `fd7a:115c:a1e0::8f3b:4141`.
- Funnel enabled:
  - `https://openclaw-24x7.tailda6e28.ts.net` -> `http://127.0.0.1:8787`
  - `https://openclaw-24x7.tailda6e28.ts.net:8443` -> `http://127.0.0.1:8788`
- `tailscale netcheck`: UDP true, IPv4 yes, nearest DERP observed as Singapore in the latest check.

Proxy:

- `mihomo-standalone.service`: enabled and active.
- Current proxy port: `127.0.0.1:7897` TCP/UDP.
- DNS/listener: `127.0.0.1:5334`.
- `127.0.0.1:7890` is not active and should not be used as the OpenClaw proxy.
- Probe baseline: `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` returns HTTP `204`.
- Current config contains:
  - `mixed-port: 7897`
  - `mode: rule`
  - `keep-alive-interval: 15`
  - `keep-alive-idle: 15`
  - `tcp-concurrent: true`
  - `telegram-jp-tw-stable` fallback group with `interval: 5`, `lazy: true`, URL `https://www.gstatic.com/generate_204`
  - `自动选择` url-test group with `interval: 30`, `lazy: false`, URL `http://www.gstatic.com/generate_204`

OpenClaw services:

| Service | State Dir | Ports | Baseline |
|---|---|---|---|
| `openclaw-gateway.service` | `~/.openclaw` | `18790`, `18792`, `8787` | main, Telegram webhook, DeepSeek V4 Pro only |
| `openclaw-gateway-dayong.service` | `~/.openclaw-dayong` | `19021`, `19023`, `8788` | Feishu/market instance |
| `openclaw-gateway-chunyan.service` | `~/.openclaw-chunyan` | `19001`, `19003` | Feishu instance; watch memory and restart count |
| `openclaw-gateway-zenglan.service` | `~/.openclaw-zenglan` | `19041`, `19043` | Feishu instance; health JSON may show `running=false` despite probe ok |

Latest verified service details:

- All four gateways were `active/running`.
- `main` memory was around 3.2 GiB.
- `chunyan` memory was around 2.7 GiB, with prior `NRestarts=6`; keep it on the watch list.
- `zenglan` had prior `NRestarts=13`; keep it on the watch list even if currently active.
- All four `openclaw config validate` checks passed.
- All four `openclaw gateway health --json` probes returned `ok: true` in the sampled output.
- Main Telegram logs after the 16:04 restart showed `webhook advertised` and repeated `sendMessage ok`.

Known current cron state:

- `openclaw cron status --json`: `enabled=true`, `jobs=15`, store path `~/.openclaw/cron/jobs.json`.
- Remaining enabled jobs include duplicated `morning-briefing`, `market-reflection`, and `sector-reflection`.
- Several enabled `morning-briefing` jobs still have old model fields such as `zai/glm-5` or `minimax/MiniMax-M2.7`.
- Some cron delivery state still reports `Delivering to Telegram requires target <chatId>`.
- Six previously problematic `closing-report` / `sector-daily-push` jobs were disabled after they caused stuck sessions.

Known red flags from the latest incident:

- `active/running` did not mean healthy: main had repeated `stuck session` diagnostics while systemd stayed active.
- A recent Vulkan local-memory failure appeared:
  - `ggml_vulkan: Device memory allocation ... failed`
  - `failed to allocate buffer for kv cache`
- This should be checked whenever main appears slow or stuck after memory search, local embedding, or heavy cron work.

## Detailed Commands

### 1. Host Baseline

```bash
ssh kevinlasnh@100.64.65.65 'date -Is; hostnamectl; uptime; free -h; swapon --show; df -hT / /home'
ssh kevinlasnh@100.64.65.65 'systemctl --failed --no-pager; systemctl --user --failed --no-pager'
```

Watch:

- Swap used rising quickly.
- Disk `/` or `/home` above 80%.
- Any failed unit.

### 2. Tailscale and SSH

```bash
ssh kevinlasnh@100.64.65.65 'systemctl status tailscaled ssh openclaw-sshd-2222 --no-pager -l'
ssh kevinlasnh@100.64.65.65 'tailscale version; tailscale status; tailscale netcheck'
ssh kevinlasnh@100.64.65.65 "ss -ltnp | grep -E '(:22|:2222)\\b' || true"
```

Healthy:

- `tailscaled.service`, `ssh.service`, and `openclaw-sshd-2222.service` are active/enabled.
- `0.0.0.0:22` is listening for normal SSH.
- `100.64.65.65:2222` is listening for the Tailscale OpenSSH rescue entry.

Known cleanup item:

- If `openclaw-sshd-2222.service` logs `Unknown key name 'StartLimitIntervalSec' in section 'Service'`, move that setting to the correct systemd section in a separate cleanup task. It is a warning, not the immediate root cause of OpenClaw failures.

### 3. Tailscale Funnel and Webhook Ingress

```bash
ssh kevinlasnh@100.64.65.65 'tailscale serve status; tailscale funnel status'
ssh kevinlasnh@100.64.65.65 "ss -ltnp | grep -E '(:443|:8443|:8787|:8788)\\b' || true"
```

Healthy:

- Funnel `443` maps to `127.0.0.1:8787`.
- Funnel `8443` maps to `127.0.0.1:8788`.
- Local `127.0.0.1:8787` exists for main Telegram webhook.

Interpretation:

- Funnel present but `8787` missing means OpenClaw main channel/gateway is not listening.
- `8787` present but Funnel missing means local gateway may be alive but public webhook ingress is broken.

### 4. Mihomo Proxy and Health Polling

```bash
ssh kevinlasnh@100.64.65.65 'systemctl --user status mihomo-standalone --no-pager -l'
ssh kevinlasnh@100.64.65.65 "ss -ltnup | grep -E '(:7897|:7890|:5334)\\b' || true"
ssh kevinlasnh@100.64.65.65 "curl -x http://127.0.0.1:7897 -sS -o /dev/null -w 'http=%{http_code} time=%{time_total}\\n' https://www.gstatic.com/generate_204"
ssh kevinlasnh@100.64.65.65 "grep -nE '^(mixed-port|mode|keep-alive|tcp-concurrent)|telegram-jp-tw-stable|interval: 5|url: .*generate_204|自动选择|lazy:' ~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml | sed -n '1,120p'"
```

Healthy:

- `mihomo-standalone.service` is active/enabled.
- `127.0.0.1:7897` listens.
- HTTPS `generate_204` through `7897` returns `204`.
- Telegram rules route Telegram domains/IPs to `telegram-jp-tw-stable`.
- `telegram-jp-tw-stable` has 5-second health checks.

Do not use `127.0.0.1:7890` unless the current config explicitly changes back to that port.

### 5. OpenClaw Services and Ports

```bash
ssh kevinlasnh@100.64.65.65 'openclaw --version'
ssh kevinlasnh@100.64.65.65 'systemctl --user show openclaw-gateway openclaw-gateway-dayong openclaw-gateway-chunyan openclaw-gateway-zenglan -p Id -p ActiveState -p SubState -p UnitFileState -p ExecMainStartTimestamp -p NRestarts -p MemoryCurrent --no-pager'
ssh kevinlasnh@100.64.65.65 "ss -ltnp | grep -E '(:18790|:18792|:19001|:19003|:19021|:19023|:19041|:19043|:8787|:8788)\\b' || true"
```

Healthy:

- All four services active/enabled.
- Expected local ports are listening on loopback.
- `NRestarts` is stable after startup.

### 6. OpenClaw Config and Channel Health

```bash
ssh kevinlasnh@100.64.65.65 'for d in .openclaw .openclaw-dayong .openclaw-chunyan .openclaw-zenglan; do cfg=$HOME/$d/openclaw.json; echo "STATE=$HOME/$d"; OPENCLAW_STATE_DIR=$HOME/$d OPENCLAW_CONFIG_PATH=$cfg openclaw config validate; OPENCLAW_STATE_DIR=$HOME/$d OPENCLAW_CONFIG_PATH=$cfg openclaw gateway health --json | head -40; done'
```

Healthy:

- `Config valid` for all four state dirs.
- `gateway health --json` returns `ok: true`.
- Telegram probe includes the expected webhook URL for main.
- Feishu probes return `ok: true` for the other instances.

Important nuance:

- Some Feishu health JSON fields may show `running=false` while probe is ok. Treat `probe.ok=true`, service logs, and actual websocket readiness together instead of reading that one field alone.

### 7. Main Sessions, Locks, and Stuck Work

```bash
ssh kevinlasnh@100.64.65.65 "find ~/.openclaw/agents/main/sessions -maxdepth 1 -name '*.lock' -printf '%TY-%Tm-%Td %TH:%TM %p\\n' | sort || true"
ssh kevinlasnh@100.64.65.65 "journalctl --user -u openclaw-gateway --since '45 minutes ago' --no-pager | grep -Ei 'stuck session|gateway closed|PluginLoadFailure|Vulkan|failed|error' | tail -100 || true"
```

Healthy:

- No persistent `.lock` files.
- No continuing `stuck session` every 30 seconds.

If a lock exists:

1. Identify the session key from logs or session metadata.
2. Decide whether it is active work or stale.
3. Only then consider a targeted session reset or gateway restart.

### 8. OpenClaw Cron

```bash
ssh kevinlasnh@100.64.65.65 'OPENCLAW_STATE_DIR=$HOME/.openclaw OPENCLAW_CONFIG_PATH=$HOME/.openclaw/openclaw.json openclaw cron status --json'
ssh kevinlasnh@100.64.65.65 'OPENCLAW_STATE_DIR=$HOME/.openclaw OPENCLAW_CONFIG_PATH=$HOME/.openclaw/openclaw.json openclaw cron list --json'
```

Inspect:

- `enabled`
- `jobs`
- `nextWakeAtMs`
- duplicate `name` + identical schedule
- `state.runningAtMs`
- `state.consecutiveErrors`
- `state.lastError`
- `payload.model`
- `delivery.target` or `delivery.channel`

Current red flags to keep on the checklist:

- Duplicate stock/market jobs are present.
- Some jobs still have old model fields.
- Some enabled jobs fail delivery because Telegram target is missing.
- The previously disabled `closing-report` / `sector-daily-push` jobs should remain disabled until rebuilt.

### 9. Logs and Resource Pressure

```bash
ssh kevinlasnh@100.64.65.65 "journalctl --user -u openclaw-gateway --since '2 hours ago' --no-pager | grep -Ei 'stuck session|sendMessage failed|PluginLoadFailure|rate limit|429|Vulkan|OutOfDeviceMemory|failed|error' | tail -120 || true"
ssh kevinlasnh@100.64.65.65 "ps -eo pid,ppid,stat,pcpu,pmem,rss,vsz,cmd --sort=-rss | head -30"
ssh kevinlasnh@100.64.65.65 "nvidia-smi 2>/dev/null || true"
```

Interpretation:

- `sendMessage ok` means Telegram outbound is working.
- `sendMessage failed` means Telegram/proxy/provider delivery needs inspection.
- `rate limit` or `429` is a provider/model issue, not a gateway port issue.
- Vulkan OOM points to local memory/GPU pressure.

## Incident Playbooks

### Telegram Does Not Reply

1. Check recent main logs for webhook and outbound messages.
2. Check `8787` listener and Tailscale Funnel `443 -> 8787`.
3. Check proxy `7897` with `generate_204`.
4. Check `openclaw gateway health --json` for Telegram webhook URL and bot probe.
5. Check session locks and `stuck session`.
6. Only after the failing layer is clear, restart the smallest affected service.

### Gateway Active but Looks Stuck

1. Do not trust `systemctl is-active` alone.
2. Search logs for `stuck session`, `gateway closed`, plugin errors, model errors, and Vulkan OOM.
3. Check `*.lock` in `~/.openclaw/agents/main/sessions`.
4. Check cron `runningAtMs` and `consecutiveErrors`.
5. If cron caused the load, disable only the offending jobs and document the IDs.

### Proxy Unreachable

1. Verify `mihomo-standalone` active.
2. Verify `127.0.0.1:7897` listener.
3. Probe `https://www.gstatic.com/generate_204` through `7897`.
4. Inspect `clash-verge.yaml` for `mixed-port: 7897`, health groups, and Telegram rules.
5. Restart Mihomo only if service/listener/probe proves bad.

### Tailscale or SSH Unreachable

1. Try normal SSH `22`.
2. Try Tailscale OpenSSH `100.64.65.65:2222`.
3. From any available shell, check `tailscaled`, `tailscale status`, `tailscale netcheck`.
4. If tailnet is down but public SSH works, fix Tailscale before OpenClaw.

### Cron Runaway

1. Read `cron status --json` and `cron list --json`.
2. Look for duplicate schedules, `runningAtMs`, and `consecutiveErrors`.
3. If a job is actively wedging main, disable that job ID first.
4. Rebuild the job later with explicit delivery target, current model, and bounded workload.

## Automation

The repository includes a read-only helper. From PowerShell on this Windows repo, use:

```powershell
Get-Content -Raw -Encoding UTF8 server_health_check.sh | ssh kevinlasnh@100.64.65.65 "tr -d '\r' | bash -s"
```

From a Unix shell with normal input redirection, use:

```bash
ssh kevinlasnh@100.64.65.65 'bash -s' < server_health_check.sh
```

It collects the same layers as this document and prints a timestamped report to stdout. It does not restart services, edit configs, disable cron jobs, or delete locks.
