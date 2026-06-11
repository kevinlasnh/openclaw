#!/usr/bin/env bash
set -euo pipefail

CONFIG_PATH="${OPENCLAW_CONFIG_PATH:-$HOME/.openclaw/openclaw.json}"
KIMI_MODEL="${KIMI_MODEL:-moonshot-v1-128k}"
FEISHU_ACCOUNT_ID="${FEISHU_ACCOUNT_ID:-stock-desk}"
KIMI_API_KEY="${KIMI_API_KEY:-}"
FEISHU_APP_ID="${FEISHU_APP_ID:-}"
FEISHU_APP_SECRET="${FEISHU_APP_SECRET:-}"

if [ -z "$KIMI_API_KEY" ] || [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ]; then
  echo "KIMI_API_KEY, FEISHU_APP_ID and FEISHU_APP_SECRET are required." >&2
  exit 1
fi

mkdir -p "$(dirname "$CONFIG_PATH")"
cp -a "$CONFIG_PATH" "$CONFIG_PATH.pre-stock-$(date +%Y%m%d_%H%M%S)"

KIMI_MODEL="$KIMI_MODEL" \
KIMI_API_KEY="$KIMI_API_KEY" \
FEISHU_ACCOUNT_ID="$FEISHU_ACCOUNT_ID" \
FEISHU_APP_ID="$FEISHU_APP_ID" \
FEISHU_APP_SECRET="$FEISHU_APP_SECRET" \
CONFIG_PATH="$CONFIG_PATH" \
node <<'EOF'
const fs = require("fs");

const configPath = process.env.CONFIG_PATH;
const kimiModel = process.env.KIMI_MODEL;
const kimiApiKey = process.env.KIMI_API_KEY;
const feishuAccountId = process.env.FEISHU_ACCOUNT_ID;
const feishuAppId = process.env.FEISHU_APP_ID;
const feishuAppSecret = process.env.FEISHU_APP_SECRET;

const cfg = JSON.parse(fs.readFileSync(configPath, "utf8"));

cfg.env ??= {};
cfg.env.MOONSHOT_API_KEY = kimiApiKey;

cfg.models ??= {};
cfg.models.mode = "merge";
cfg.models.providers ??= {};
cfg.models.providers.moonshot = {
  baseUrl: "https://api.moonshot.cn/v1",
  apiKey: "${MOONSHOT_API_KEY}",
  api: "openai-completions",
  models: [
    {
      id: "moonshot-v1-auto",
      name: "Moonshot V1 Auto",
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0 },
      contextWindow: 131072,
      maxTokens: 16384,
    },
    {
      id: "moonshot-v1-128k",
      name: "Moonshot V1 128K",
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0 },
      contextWindow: 131072,
      maxTokens: 16384,
    },
    {
      id: "moonshot-v1-128k-vision-preview",
      name: "Moonshot V1 128K Vision",
      reasoning: false,
      input: ["text", "image"],
      cost: { input: 0, output: 0 },
      contextWindow: 131072,
      maxTokens: 16384,
    },
  ],
};

cfg.agents ??= {};
cfg.agents.defaults ??= {};
cfg.agents.defaults.workspace = "/home/admin/.openclaw/workspace";
cfg.agents.defaults.model = {
  primary: `moonshot/${kimiModel}`,
  fallbacks: [],
};
cfg.agents.defaults.models ??= {};
cfg.agents.defaults.models[`moonshot/${kimiModel}`] = { alias: "Moonshot 128K" };
cfg.agents.defaults.models["moonshot/moonshot-v1-auto"] = { alias: "Moonshot Auto" };
cfg.agents.defaults.imageModel = {
  primary: "moonshot/moonshot-v1-128k-vision-preview",
  fallbacks: [],
};
cfg.agents.defaults.models["moonshot/moonshot-v1-128k-vision-preview"] = {
  alias: "Moonshot Vision 128K",
};
cfg.agents.defaults.compaction = { mode: "safeguard" };
cfg.agents.defaults.memorySearch = { enabled: false };

cfg.hooks ??= {};
cfg.hooks.internal ??= {};
cfg.hooks.internal.enabled = true;
cfg.hooks.internal.entries ??= {};
cfg.hooks.internal.entries["boot-md"] = { enabled: true };
cfg.hooks.internal.entries["session-memory"] = { enabled: true };

cfg.messages ??= {};
cfg.messages.ackReactionScope = "group-mentions";

cfg.commands ??= {};
cfg.commands.restart = true;
cfg.commands.native = cfg.commands.native || "auto";
cfg.commands.nativeSkills = cfg.commands.nativeSkills || "auto";
cfg.commands.ownerDisplay = cfg.commands.ownerDisplay || "raw";

cfg.session ??= {};
cfg.session.dmScope = "per-channel-peer";

cfg.plugins ??= {};
cfg.plugins.entries ??= {};
cfg.plugins.entries.feishu = {
  ...(cfg.plugins.entries.feishu || {}),
  enabled: true,
};

cfg.channels ??= {};
cfg.channels.feishu = {
  enabled: true,
  defaultAccount: feishuAccountId,
  accounts: {
    ...(cfg.channels.feishu?.accounts || {}),
    [feishuAccountId]: {
      ...(cfg.channels.feishu?.accounts?.[feishuAccountId] || {}),
      enabled: true,
      name: "Spark Stock Desk",
      appId: feishuAppId,
      appSecret: feishuAppSecret,
      domain: "feishu",
      connectionMode: "websocket",
      dmPolicy: "open",
      allowFrom: ["*"],
      groupPolicy: "disabled",
      requireMention: false,
      streaming: false,
      typingIndicator: false,
      resolveSenderNames: false,
      renderMode: "auto",
      tools: {
        doc: true,
        chat: true,
        wiki: true,
        drive: true,
        scopes: true,
        perm: false,
      },
    },
  },
};

cfg.bindings = Array.isArray(cfg.bindings) ? cfg.bindings : [];
if (
  !cfg.bindings.some(
    (binding) =>
      binding &&
      binding.agentId === "main" &&
      binding.match &&
      binding.match.channel === "feishu" &&
      binding.match.accountId === feishuAccountId,
  )
) {
  cfg.bindings.push({
    agentId: "main",
    match: {
      channel: "feishu",
      accountId: feishuAccountId,
    },
  });
}

fs.writeFileSync(configPath, `${JSON.stringify(cfg, null, 2)}\n`);
EOF

openclaw config validate
openclaw plugins enable feishu >/dev/null 2>&1 || true
