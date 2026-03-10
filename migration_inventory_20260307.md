# OpenClaw Migration Inventory (2026-03-07)

## Target (New Ubuntu 24/7 Host)
- Host (LAN): `192.168.43.250`
- Host (Tailscale): `100.64.65.65`
- User: `kevinlasnh`
- Node: `v22.22.1`
- npm: `10.9.4`
- OpenClaw: `2026.3.2` (`/usr/bin/openclaw`)
- Infra services:
  - `ssh`: `enabled + active`
  - `tailscaled`: `enabled + active`
  - `tailscale ssh`: enabled

## Source (Current Running OpenClaw)
- Runtime location: WSL Ubuntu
- State dir: `/home/kevinlasnh/.openclaw`
- Service:
  - `openclaw-gateway.service`: `active + enabled`
- Size snapshot:
  - total: `110M`
  - `agents`: `40M`
  - `workspace`: `40M`
  - `credentials`: `9.8M`
  - `cron`: `488K`
  - `memory`: `80K`
  - `telegram`: `8.0K`
  - `skills`: `124K`
  - `workspace-family`: `164K`

## Source Config Snapshot (Sanitized)
- Config file: `~/.openclaw/openclaw.json`
- Top keys:
  - `agents, auth, channels, commands, discovery, env, gateway, hooks, logging, meta, models, plugins, skills, tools, wizard`
- Agent IDs:
  - `main`
- Channels:
  - `telegram`
- Telegram keys (names only):
  - `allowFrom, blockStreaming, botToken, chunkMode, dmPolicy, enabled, groupPolicy, mediaMaxMb, proxy, streaming, textChunkLimit`
- Cron jobs:
  - `8` jobs in `~/.openclaw/cron/jobs.json`
- Workspace skills (source):
  - `bilibili-hot-monitor`
  - `clawfeed`
  - `gmail`
  - `google-calendar-api`
  - `memory`
  - `obsidian-direct`
  - `openclaw-github-assistant`
  - `openclaw-updater`
  - `second-brain-intake`
  - `self-learning`
  - `trading-brain`
  - `translate`
  - `wechat-article-extractor-skill`
  - `wsl-windows-control`
  - `youtube-transcript`
  - `youtube-ultimate`

## Integrity Markers
- `~/.openclaw/openclaw.json` sha256:
  - `a3744e9bcebb2490ca527c8e640a8c9800e8566ad48b3b5d6971d2573ce4c66d`
- `~/.openclaw/cron/jobs.json` sha256:
  - `f5c9b3e38c2e24fdf4dfcf365d01ecfbd21dc1e612603c41cb0ed0acc184cdee`

## One-Shot Migration Principle
- Copy the **entire** `~/.openclaw` directory from source to target.
- Do not cherry-pick subfolders, to avoid token/session/state mismatch.

## Ready-to-Run Migration Sequence (When You Confirm Cutover)
1. On source, stop gateway:
   - `openclaw gateway stop`
2. Create backup archive:
   - `tar -C ~ -czf /tmp/openclaw-state-$(date +%Y%m%d-%H%M%S).tar.gz .openclaw`
3. Transfer archive to target:
   - `scp /tmp/openclaw-state-*.tar.gz kevinlasnh@100.64.65.65:/home/kevinlasnh/`
4. On target, restore:
   - `mv ~/.openclaw ~/.openclaw.bak-$(date +%Y%m%d-%H%M%S) 2>/dev/null || true`
   - `tar -C ~ -xzf ~/openclaw-state-*.tar.gz`
5. On target, validate and start:
   - `openclaw doctor`
   - `openclaw gateway install`
   - `openclaw gateway restart`
   - `openclaw status`
