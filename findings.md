# Findings: 2026-03-08 飞书 + Ubuntu 网络通知

## E. 单 Gateway 双 Agent 路由隔离修复（已完成 ✅）

### 问题根因
- `agents.list` 中缺少 `main` agent，仅 `mom` 存在（且为默认）
- 但 `bindings` 中写了 `main <- telegram/default`，形成"绑定目标不存在"的不一致状态
- 导致未命中的消息回落到默认 agent（`mom`），存在串线风险

### 已落地修复（2026-03-08 14:50 CST）
- `agents.list` 增加 `main` 配置：
  ```json
  {
    "id": "main",
    "default": true,
    "workspace": "/home/kevinlasnh/.openclaw/workspace",
    "agentDir": "/home/kevinlasnh/.openclaw/agents/main/agent",
    "subagents": { "allowAgents": ["main"] }
  }
  ```
- `mom` 保持非默认（无 `default: true`，仅通过 bindings 精确命中）
- 增补 `channels.telegram.defaultAccount = "default"`
- 增补 `channels.feishu.defaultAccount = "mom-feishu"`
- 重新开启飞书 `typingIndicator = true`（排查问题时曾关闭）

### 最终路由配置
| 入站来源 | 匹配规则 | 目标 Agent |
|---------|----------|-----------|
| 你的 Telegram（default 账号） | `channel=telegram, accountId=default` | `main` |
| 妈妈的 Telegram（chunyan-bot） | `channel=telegram, accountId=chunyan-bot` | `mom` |
| 妈妈的飞书（mom-feishu） | `channel=feishu, accountId=mom-feishu` | `mom` |

### 验收结果
- `openclaw agents list --json` 显示 `main`（isDefault=true, bindings=1）+ `mom`（isDefault=false, bindings=2）
- `openclaw gateway health` 全 OK
- `openclaw agent --agent main --message "Reply with: MAIN_OK"` 成功返回 `MAIN_OK`

## F. A股交易专用 Agent 创建（已完成 ✅）

### 需求
- 创建独立 agent 专门用于 A股交易
- 通过专用 Telegram bot 联入
- 与 main、mom 隔离，独立 workspace

### 已落地配置（2026-03-08 15:05 CST）
- 创建 agent 目录：`~/.openclaw/agents/ashare/agent/`
- 创建 workspace：`~/.openclaw/workspace-ashare/`
- `agents.list` 新增 `ashare` 配置：
  ```json
  {
    "id": "ashare",
    "name": "ashare",
    "workspace": "/home/kevinlasnh/.openclaw/workspace-ashare",
    "agentDir": "/home/kevinlasnh/.openclaw/agents/ashare/agent",
    "model": "kimi/k2p5"
  }
  ```
- `channels.telegram.accounts` 新增 `ashare-bot`：
  ```json
  {
    "dmPolicy": "allowlist",
    "botToken": "8651491417:AAFKIInTSXNRmZoDd0bC18Vm2B2GRH-DlRs",
    "groupPolicy": "allowlist",
    "streaming": "partial",
    "allowFrom": [8226087994]
  }
  ```
- `bindings` 新增 `ashare-bot -> ashare`

### Bot 汇总

| Agent | Bot Username | 用途 |
|--------|-------------|------|
| main | @OpenClaw_kevinlasnh_no1_bot | kevinlasnh 日常聊天 |
| ashare | @openclaw_BigA_winner_bot | kevinlasnh A股交易 |
| mom | @openclaw_chunyan_bot | 妈妈聊天（Telegram + 飞书） |

### 模型配置策略
- 所有 agent 共享同一套 model providers（kimi、zai、newcli）
- 未单独指定模型的 agent 继承 `agents.defaults.model.primary = "kimi/k2p5"`
- 备用顺序：`kimi` → `zai` → `newcli`

### 验收结果
- `openclaw agents list --json` 显示 3 个 agent
- `openclaw gateway health` 显示 3 个 Telegram bot 全 OK
- `openclaw agent --agent ashare --message ...` 返回 `ASHARE_OK`

## A. 飞书“显示打字但不回消息”排查结论

### 现象
- 飞书入站消息可达（日志可见 `received message` / `DM from ...`）。
- 网关会进入分发（日志可见 `dispatching to agent`），但结束时出现 `dispatch complete ... replies=0`。
- 同时存在间歇性权限报错：`Access denied ... code=99991672`，提示缺少 contact 相关 scope。

### 关键发现
- `mom` agent 本身可正常出字（`openclaw agent --agent mom --message ... --json` 返回正常文本），模型链路不是根因。
- 飞书通道此前为 `dmPolicy=pairing` 且启用 `resolveSenderNames=true`，会触发 contact API 名称解析；在 scope 未完全放开时，容易叠加噪声与不稳定行为。
- 本机曾存在 Feishu 扩展插件残留目录（`~/.openclaw/extensions/feishu*`），会触发 duplicate plugin 告警。

### 已落地修复
- `channels.feishu.dmPolicy`：`pairing` -> `allowlist`
- `channels.feishu.allowFrom`：加入 `ou_e4c865918d1b26e9ff11a09034e08970`
- `channels.feishu.resolveSenderNames`：`false`
- `channels.feishu.streaming`：`false`
- `channels.feishu.blockStreaming`：`false`（新增，避免 block-only 回包被通道层丢弃）
- `channels.feishu.typingIndicator`：`false`
- `agents.list[mom].tools.exec.security`：强制修正为 `full`
- 备份并清理全局 Feishu 扩展目录到 `~/.openclaw/plugin-backups/`

### 官方文档对齐（2026-03-08 14:20 CST）

根据 OpenClaw 官方文档与飞书官方文章，本项目飞书配置已对齐为“稳态”：

- 使用 OpenClaw 内置 Feishu channel（`plugins.entries.feishu.enabled=true`），账号放在 `channels.feishu.accounts.<accountId>`
- 连接模式使用 `connectionMode=websocket`（长连接）
- 飞书应用必须具备：
  - 机器人能力开启
  - 事件订阅开启（至少 `im.message.receive_v1`）
  - 机器人消息权限（`im:message:send_as_bot`、`im:message:readonly`）
  - 应用发布到企业内可用范围
- 对“打字但不回”场景，按官方建议关闭流式：
  - `streaming=false`
  - 本次同时落地 `blockStreaming=false`，确保返回 final 消息，不依赖 block 流

### 已验证

- 网关重启后健康检查：`openclaw gateway health => Feishu: ok`
- 主动消息下发测试成功（`openclaw message send --channel feishu --account mom-feishu ...` 返回 messageId）

### 当前状态
- `openclaw-gateway`：`active (running)`
- `openclaw gateway health`：`Feishu: ok`
- 待最终确认：用户侧“妈妈手机 -> 机器人”入站回包（观察是否消除 `replies=0`）

## B. Ubuntu 反复弹“Connection failed / activation failed”

### 根因
- `NetworkManager` 在后台持续尝试 Wi-Fi 配置（`guess who I am_5G` / `P40` / `Pixel_9102`），日志出现 `supplicant-timeout`、`ssid-not-found`，触发桌面通知。
- 同时有线网 `enp59s0` 正常，因此体感是“有网但一直弹错”。

### 已落地修复（按“只用有线网”要求）
- 关闭 Wi-Fi 射频：`nmcli radio wifi off`（sudo）
- 禁用 3 个 Wi-Fi 连接自动连接：`connection.autoconnect no`
- 验证：`wlp0s20f3` 状态为 `wifi:unavailable`，仅保留 `Wired connection 1` 在线

## C. 关键命令参考

```bash
# 网关与飞书日志
systemctl --user status openclaw-gateway
journalctl --user -u openclaw-gateway -n 300 --no-pager

# 网络通知根因
nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status
journalctl -u NetworkManager --since "2026-03-08 00:00:00" --no-pager

# 本地 agent 自检
openclaw agent --agent mom --message "Reply with: TEST_OK" --json
```

## D. 多 Agent 不串消息（官方规则 + 当前冲突）

### 官方规则（2026-03-08 联网核查）
- `bindings` 采用 **first-match-wins**：从上到下首个匹配生效。
- 多账号场景必须在 `match` 里明确 `accountId`；同账号多人可再加 `peer` 做精细路由。
- 未命中 `bindings` 时会回落 default agent。
- default agent 的判定顺序：
  - `agents.list` 中显式 `default=true`
  - 否则 `agents.list` 第一项
- 会话隔离官方建议使用：
  - `session.dmScope = per-account-channel-peer`
  - 可叠加 `session.scope = per-sender`

### 当前线上冲突（需优先修）
- 线上 `openclaw agents list --json` 仅有 `mom` 且 `isDefault=true`。
- `openclaw agent --agent main` 报错：`Unknown agent id "main"`。
- 但 `openclaw.json` 的 `bindings` 仍写了 `main <- telegram/default`。
- 这会形成“绑定目标不存在 + 默认回落到 mom”的高风险结构，可能导致串线/错投递。

### 建议修复顺序
1. 在 `agents.list` 显式恢复 `main`，并设 `default=true`。
2. 将 `mom` 保持 `default=false`，仅通过精确 `bindings` 命中。
3. 明确账号默认值：
   - `channels.telegram.defaultAccount = default`
   - `channels.feishu.defaultAccount = mom-feishu`
4. 重启后做 3 项验收：
   - `openclaw agents list --json` 显示 `main + mom`
   - `openclaw agent --agent main` 成功
   - 交叉消息压测（你 Telegram / 妈妈飞书）不串线

---

## G. 飞书机器人完全失效 - 配置丢失（2026-03-08 晚）

### 现象
- 两个飞书机器人（mom 和 ashare）完全不工作
- 用户的反馈："你现两个飞猪全死了"

### 根因
**配置文件严重丢失：**检查 `~/.openclaw/openclaw.json` 发现：
- `agents.list` 只有 `main`，缺少 `mom` 和 `ashare`
- `channels` 只有 `telegram`，飞书通道配置完全不存在
- `bindings` 完全为空
- 所有飞书相关配置（dmPolicy、allowFrom、typingIndicator 等）全部丢失

### 现有资源状态
| 资源 | 状态 | 路径 |
|-------|------|------|
| main agent | ✅ 存在 | `~/.openclaw/agents/main/` |
| family agent (mom) | ✅ 存在 | `~/.openclaw/agents/family/` |
| ashare agent | ✅ 已创建 | `~/.openclaw/agents/ashare/` |
| main workspace | ✅ 存在 | `~/.openclaw/workspace/` |
| family workspace | ✅ 存在 | `~/.openclaw/workspace-family/` |
| ashare workspace | ✅ 已创建 | `~/.openclaw/workspace-ashare/` |

### 待重建配置（根据历史记录）
**飞书账号配置：**
```json5
channels: {
  feishu: {
    enabled: true,
    defaultAccount: "mom-feishu",
    accounts: {
      "mom-feishu": {
        appId: "cli_a92651d8d7f81bc0",
        // appSecret: 需要用户提供或查找
        botName: "mom openclaw",
        dmPolicy: "allowlist",
        allowFrom: ["ou_e4c865918d1b26e9ff11a09034e08970"],
        typingIndicator: true,
        blockStreaming: false,
        streaming: false,
        resolveSenderNames: false
      },
      "ashare-feishu": {
        appId: "cli_a927e3cb67389cb1",
        appSecret: "88FboR8ZYqOxY5NOCALdvdP4mHdAbYpB",
        botName: "ashare openclaw",
        dmPolicy: "any",
        typingIndicator: true,
        blockStreaming: false,
        streaming: false
      }
    }
  }
}
```

**Telegram 多账号配置：**
```json5
channels: {
  telegram: {
    enabled: true,
    defaultAccount: "default",
    accounts: {
      "default": {
        botToken: "8224258782:AAGIU5DaAGe0GKT8SHfxM1_04lQRQ0H_Fnk",
        dmPolicy: "allowlist",
        allowFrom: [8226087994],
        groupPolicy: "allowlist",
        textChunkLimit: 4096,
        blockStreaming: true,
        streaming: "partial",
        proxy: "http://127.0.0.1:7890",
        mediaMaxMb: 50
      },
      "chunyan-bot": {
        botToken: "8620778392:AAGc7klhJp1ivNf4xpagoy1ClCChO6RsNbI",
        dmPolicy: "allowlist",
        groupPolicy: "allowlist",
        streaming: "partial"
      },
      "ashare-bot": {
        botToken: "8651491417:AAFKIInTSXNRmZoDd0bC18Vm2B2GRH-DlRs",
        dmPolicy: "allowlist",
        allowFrom: [8226087994],
        groupPolicy: "allowlist",
        streaming: "partial"
      }
    }
  }
}
```

**Bindings 路由配置：**
```json
{
  "bindings": [
    {"agentId": "main", "match": {"channel": "telegram", "accountId": "default"}},
    {"agentId": "family", "match": {"channel": "telegram", "accountId": "chunyan-bot"}},
    {"agentId": "family", "match": {"channel": "feishu", "accountId": "mom-feishu"}},
    {"agentId": "ashare", "match": {"channel": "telegram", "accountId": "ashare-bot"}},
    {"agentId": "ashare", "match": {"channel": "feishu", "accountId": "ashare-feishu"}}
  ]
}
```

**Agents 列表配置：**
```json
{
  "agents": {
    "list": [
      {
        "id": "main",
        "default": true,
        "workspace": "/home/kevinlasnh/.openclaw/workspace",
        "agentDir": "/home/kevinlasnh/.openclaw/agents/main/agent",
        "subagents": {"allowAgents": ["main"]}
      },
      {
        "id": "family",
        "name": "mom",
        "workspace": "/home/kevinlasnh/.openclaw/workspace-family",
        "agentDir": "/home/kevinlasnh/.openclaw/agents/family/agent"
      },
      {
        "id": "ashare",
        "name": "ashare",
        "workspace": "/home/kevinlasnh/.openclaw/workspace-ashare",
        "agentDir": "/home/kevinlasnh/.openclaw/agents/ashare/agent"
      }
    ]
  }
}
```

### 下一步
~~1. 用户需要提供 mom-feishu 的 appSecret~~ ✅ 已有
~~2. 重新构建完整的 `openclaw.json`~~ ✅ 已完成
~~3. 重启 gateway 并验证~~ ✅ 已通过

---

## H. 飞书 dmPolicy 值 `"any"` 无效（已修复 ✅）

### 现象
- ashare-feishu 配置 `dmPolicy: "any"`，但所有消息仍被拦截
- 日志：`blocked unauthorized sender ou_xxx (dmPolicy=any)`

### 根因
- OpenClaw 不识别 `"any"` 作为 dmPolicy 的合法值
- 合法值为：`"allowlist"` / `"pairing"` / `"open"`（待确认）
- `"any"` 被当作未知值，默认拒绝所有消息

### 修复
- 改为 `dmPolicy: "allowlist"` + 显式添加 `allowFrom` 列表
- 教训：**永远不要用 `dmPolicy: "any"`，用 `"allowlist"` + 明确的 allowFrom 列表**

## I. ashare-feishu allowFrom 完整列表（2026-03-08）

| # | 飞书 open_id | 身份 |
|---|-------------|------|
| 1 | `ou_d73c015003d3e69979f59312904a6caf` | kevinlasnh |
| 2 | `ou_e4c865918d1b26e9ff11a09034e08970` | 妈妈 |
| 3 | `ou_13a524974b2ecd4311f615542645de87` | 新用户 |
| 4 | `ou_8fb492ae6eaaecf97f14ec880ba29c9f` | 新用户 |

**添加新用户流程**：让新用户给机器人发消息 → 日志抓 `blocked unauthorized sender ou_xxx` → 加入 allowFrom → 重启 gateway

## J. Kimi API Rate Limit 机制（2026-03-08 调研）

### 限速维度（4 种同时生效）
| 维度 | 含义 |
|------|------|
| 并发 | 同时进行的请求数 |
| RPM | 每分钟请求数 |
| TPM | 每分钟 Token 数 |
| TPD | 每天 Token 数 |

### 已知等级限制
| 等级 | RPM | 备注 |
|------|-----|------|
| 免费 (Tier 0) | 3 | 并发=1, TPM=32000, TPD=1500000 |
| 标准 | 60 | 当前账户等级（`service_tier: "standard"`） |
| 专业 | 300 | 需更高充值 |

### 当前账户
- 套餐：Kimi Coding Plan 199 元/月（Allegretto 档）
- API 端点：`api.kimi.com/coding`（非 Moonshot 开发者平台）
- service_tier：`standard`
- API 本身响应正常（TTFB ≈ 0.65s）

### 已知问题
- 4 人并发 + gateway 重启初始化 → 短时间请求爆发 → 触发 rate limit
- OpenClaw fallback 链（kimi → zai → newcli）在 rate limit 时**未自动降级**，所有请求直接失败
- Rate limit 通常 5-15 分钟自动解除

### 可选优化方案（暂未实施）
1. **多 API Key 分流**：不同 agent 用不同 Kimi 账号的 API Key，分散配额
2. **换主模型**：ashare 用 zai/glm-5 做主力，减少 kimi 压力
3. **充值升级**：提升到专业等级（RPM=300）

---

## K. Telegram `getUpdates` 语义澄清 + 与 Feishu 并存结论（2026-03-08 深夜）

### 语义澄清（避免误会）
- `getUpdates` 是 **Telegram Bot API** 的长轮询接口。
- 它与 Git 无关，不是 `git update`、`git pull` 或任何 Git 命令。
- 日志里的 `409 Conflict: terminated by other getUpdates request` 含义是：
  同一 bot token 在同一时刻有两个轮询方竞争（同进程重叠窗口、重复实例、或外部轮询）。

### 并存结论
- Telegram 与 Feishu 同时启用本身**不冲突**。
- 冲突触发条件是“同 Telegram token 多轮询方”，不是“多 channel 同时开启”。
- Feishu 使用 WebSocket，不会直接占用 Telegram 的 `getUpdates`。

### 实测证据（主机 `100.64.65.65`）
- 近 2 小时仅捕获 1 条 409（`2026-03-08 23:39:29 CST`），非持续爆发。
- 三个 Telegram bot `getWebhookInfo` 均为：
  - `url=""`
  - `pending_update_count=0`
- 重启后健康检查：
  - `Gateway Health: OK`
  - `Telegram: ok`
  - `Feishu: ok`

### 操作规范（后续防复发）
1. 保持单 gateway 实例持有 Telegram token（避免重复进程/重复部署）。
2. 调试时不要并行手工 `getUpdates` 持续轮询。
3. 配置变更尽量批量一次提交，减少高频 reload/restart 窗口。
4. `bindings` 必须精确到 `channel + accountId`，避免误路由造成“看似不回复”。

---

## L. Telegram 单条约 1 分钟延迟：证据与定位（2026-03-09 凌晨）

### 复现样本
- 用户体感：`00:19` 发消息，`00:20` 才收到回复。
- 对应样本：`message_id=4197`（文本“还在吗”）。

### 时间线对齐（同一条消息）
- Telegram 消息元数据时间：`Mon 2026-03-09 00:19 GMT+8`
- 进入 OpenClaw 会话文件：`2026-03-08T16:20:45Z`（即 `00:20:45 CST`）
- assistant 生成时间：`00:20:47`
- 网关日志 `sendMessage ok`：`00:20:48`

### 关键判断
- 模型阶段仅数秒（2-3 秒级），不是慢点主因。
- 慢点发生在“Telegram 入站 -> 网关拿到更新”之前，更像轮询/链路抖动。
- 同时段未见持续性 `409 conflict` 风暴；仅有历史偶发 409。

### 环境侧证据
- `openclaw-gateway`: `active (running)`，运行稳定。
- `openclaw channels status --probe`：Telegram 三账号均 `works`，Feishu `works`。
- 代理 `mihomo-standalone` 稳定，`NRestarts=0`。
- 代理配置仍是：
  - `自动选择`：`interval=30`, `lazy=false`
  - `故障转移`：`interval=30`, `lazy=false`
- Telegram `getWebhookInfo`（经代理）：
  - 三账号 `url=""`（无 webhook 残留）
  - 默认账号观测到 `pending_update_count=1`（瞬时排队）

### 实操结论
- 这是”健康系统内的链路抖动”问题，不是配置损坏问题。
- 在不改架构前提下，优先做节点 A/B 验证（固定单节点 10-15 分钟）比盲目改配置更有效。

---

## M. 慢回复真正根因：代理节点池过窄（2026-03-09 已修复 ✅）

### 根因
- `自动选择` 和 `故障转移` 仅包含 12 个节点（台湾 4 + 日本 8），全是 GPT 标记节点
- 台湾和日本节点当时延迟高/不稳定，导致 Telegram `getUpdates` 长轮询走了慢节点
- 因为节点池里没有香港、新加坡、美国等低延迟选项，mihomo 无法自动切到更快节点

### 修复
- 扩容节点池到 54 个（全部地区：香港、新加坡、台湾、日本、美国、英国、澳洲、马来西亚、土耳其、阿根廷）
- `悠兔` 默认选择改为 `自动选择`（url-test，30s 探测）
- 扩容后 mihomo 自动选到 `专线2.5x-香港1`，用户确认**瞬间变流畅**

### 教训
- 代理节点池不应只选特定地区，应包含全部可用节点，让 url-test 自动择优
- 之前限制在台湾+日本是为了 GPT 解锁，但 OpenClaw 的 Telegram 流量不需要 GPT 解锁
- 香港节点物理距离最近，延迟自然最低

---

## N. 全面审计发现的配置问题清单（2026-03-09 已全部修复 ✅）

| # | 问题 | 严重度 | 处理 |
|---|------|--------|------|
| 1 | minimax 全局 apiKey 为空 | 中 | 改为 `${MINIMAX_API_KEY}` |
| 2 | minimax 全局缺少 authHeader | 中 | 添加 `authHeader: true` |
| 3 | 飞书 accounts.default 孤儿（dmPolicy: “any” 无效） | 中 | 删除 |
| 4 | WhatsApp 配置残留（已禁用但占位） | 低 | 整段删除 |
| 5 | systemd 版本号过时（v2026.2.26 ≠ v2026.3.2） | 低 | 已更新 |
| 6 | 4 个孤儿 agent 目录 | 低 | 已删除 |
| 7 | 3 个孤儿 workspace | 低 | 已删除 |
| 8 | 3 个 agent 级 models.json 与全局重复/不一致 | 低 | 已删除，统一用全局 |
| 9 | ~20 个备份文件 + 杂项 | 低 | 已清理 |
| 10 | 代理节点池仅 12 个（台湾+日本） | **高** | 扩容到 54 个全地区节点 |

---

## O. Telegram 账号名 "default" 导致轮询初始化失败（2026-03-09 已修复 ✅）

### 现象
- 3 个 Telegram bot 间歇性不拉消息，轮流失效（重启后随机某几个 bot 正常，其余卡住）
- 日志出现：`Polling stall detected (no getUpdates for 118.91s); forcing restart.`
- 卡死后自动重启也无法恢复，循环往复

### 根因
1. **账号名 "default" 碰撞 sentinel 逻辑**（GitHub #15082, #8496）：当 Telegram 账号名为 `"default"` 时，与 `resolveDefaultTelegramAccountId` 内部哨兵值冲突，导致轮询循环无法正确初始化。发送消息不受影响（走不同代码路径），但接收消息完全失效。
2. **`env.TELEGRAM_BOT_TOKEN` 触发 Doctor 自动迁移**：Doctor 启动时检测到此环境变量，自动创建 `accounts.default` 条目，即使手动删除也会在每次重启时重新创建。
3. **缺少 retry 配置**：代理节点切换导致 TCP 连接 reset 时，grammY 轮询库没有自动重试机制，连接断开后静默卡住 90+ 秒。

### 修复
1. **重命名账号**：`accounts.default` → `accounts.main-bot`，同步更新 `defaultAccount` 和 `bindings`
2. **删除 `env.TELEGRAM_BOT_TOKEN`**：防止 Doctor 每次启动自动重建 `accounts.default`
3. **清理所有顶层单账号字段**：移除 `channels.telegram` 下的 `dmPolicy`、`allowFrom`、`proxy` 等字段（已移入各账号独立配置），防止 Doctor 迁移触发
4. **添加 retry 配置**（GitHub Issue #7526 社区验证方案）：
   ```json
   {
     "channels": {
       "telegram": {
         "retry": {
           "attempts": 5,
           "minDelayMs": 1000,
           "maxDelayMs": 10000,
           "jitter": 0.3
         },
         "timeoutSeconds": 30
       }
     }
   }
   ```

### 验证
- 修复后 5 分钟内 **零 stall**（修复前当天累计 18 次）
- 3 个 bot 全部同时拉取和回复消息
- 所有 bot `pending_update_count=0`

### 教训
- **永远不要把 Telegram 账号命名为 `"default"`**，会与 OpenClaw 内部逻辑冲突
- **`env.TELEGRAM_BOT_TOKEN` 不应存在**，token 应只放在 `accounts.X.botToken` 中
- **必须配置 `retry`**，否则代理节点切换会导致轮询静默卡死
- **Doctor 的 "Moved single-account values" 消息**并非真正修改了配置，只是建议信息

## P. Telegram 轮询源码分析（2026-03-09）

### 轮询机制（grammY runner）
- `fetch.timeout: 30` - 每次 `getUpdates` 等待 30 秒
- `maxRetryTime: 3600 * 1000` - runner 最大重试 1 小时
- `retryInterval: "exponential"` - 指数退避重试
- 看门狗：每 30 秒检查，超过 90 秒无 `getUpdates` 调用则判定 stall

### 重启策略
```
TELEGRAM_POLL_RESTART_POLICY:
  initialMs: 2000    # 首次重启等 2 秒
  maxMs: 30000       # 最长等 30 秒
  factor: 1.8        # 退避因子
  jitter: 0.25       # 抖动
```

### 全局 Dispatcher 风险
- OpenClaw 使用 `EnvHttpProxyAgent` 作为全局 undici dispatcher
- 模型 API 调用时会调用 `ensureGlobalUndiciStreamTimeouts()` 重置 dispatcher
- 如果 timeout 参数变化，会创建新 dispatcher 并替换旧的，可能中断现有长轮询连接
- `retry` 配置可缓解此问题（断连后自动重连）

### 硬编码常量（不可通过配置调整）
| 常量 | 值 | 含义 |
|------|-----|------|
| `POLL_STALL_THRESHOLD_MS` | 90,000ms | 超时判定阈值 |
| `POLL_WATCHDOG_INTERVAL_MS` | 30,000ms | 看门狗检查间隔 |
| `maxRetryTime` | 3,600,000ms | grammY runner 最大重试时间 |
| `fetch.timeout` | 30s | 单次 getUpdates 超时 |

## Q. 模型分流配置（2026-03-09 已完成 ✅）

### 需求
- 3 个 agent 共用 MiniMax API 导致并发竞争，只有一个 bot 能及时回复

### 修复
| Agent | 主模型 | 说明 |
|-------|--------|------|
| main | minimax/MiniMax-M2.5 | 继承全局默认 |
| mom | kimi/k2p5 | 独立指定 |
| ashare | kimi/k2p5 | 独立指定 |

### Fallback 链（全局默认）
`minimax/MiniMax-M2.5` → `kimi/k2p5` → `zai/glm-5` → `newcli/claude-opus-4-6`

## R. OpenClaw 升级 v2026.3.2 → v2026.3.7（2026-03-09 已完成 ✅）

### 升级过程
- `npm install -g openclaw@latest` 中途被用户中断
- 导致 `/usr/bin/openclaw` 软链接丢失
- 修复：`sudo ln -sf /usr/lib/node_modules/openclaw/dist/index.js /usr/bin/openclaw`
- systemd Description 同步更新为 `v2026.3.7`

### 注意事项
- 升级未修复轮询卡死问题（需要 retry 配置才能根治）
- `npm install -g` 中途中断可能导致命令丢失，需手动重建软链接

## S. dmPolicy 合法值完整参考（2026-03-09 确认）

| 值 | 含义 | 需要 allowFrom |
|------|------|---------------|
| `"allowlist"` | 仅允许列表中的用户 | 是，必须显式列出 |
| `"pairing"` | 配对模式 | 否 |
| `"open"` | 开放，但需 `allowFrom: ["*"]` | 是，必须含 `"*"` |
| ~~`"any"`~~ | **无效值** | N/A |

- `"open"` 不配 `allowFrom: ["*"]` 会导致 gateway 崩溃
- `"any"` 完全不被识别，所有消息被静默拦截

## T. systemd TELEGRAM_BOT_TOKEN 残留导致 Stall 循环（2026-03-09 已修复 ✅）

### 现象
- 今日（03-09）累计 **44 次 Polling Stall**，轮询循环每 ~9 分钟一轮卡死（每轮 3 次 stall）
- 第一次 stall 距启动已 8.5 小时无 getUpdates 调用
- 日志：`Polling stall detected (no getUpdates for 107.0Xs); forcing restart.`

### 根因
**systemd 服务文件中残留 `Environment=TELEGRAM_BOT_TOKEN=...`**

之前的修复（Session 2026-03-09 凌晨）只从 `openclaw.json` 的 `env` 字段和配置文件中删除了 `TELEGRAM_BOT_TOKEN`，但忘了清理 `~/.config/systemd/user/openclaw-gateway.service` 里的 `Environment=` 行。

**触发链路（源码级确认）：**
1. systemd 启动 gateway 进程时注入 `TELEGRAM_BOT_TOKEN` 环境变量
2. OpenClaw 源码 `plugins-BkoiCBu-.js:801`：`accountId === "default"` 时读取 `process.env.TELEGRAM_BOT_TOKEN`
3. 创建幽灵 `accounts.default` 账号
4. `"default"` 与 `resolveDefaultTelegramAccountId` 内部 sentinel 值冲突
5. 轮询初始化异常 → 看门狗 90s 超时 → 强制重启 → 循环

### Polling Stall 机制说明（白话）
- **长轮询**：Bot 主动去 Telegram 服务器"拉消息"，每次等 30 秒，没消息返回空结果，立刻再拉
- **看门狗**：每 30 秒检查一次，最近 90 秒内有没有发起过 `getUpdates` 请求
- **Stall 判定**：90 秒内一次 `getUpdates` 都没有 → 判定轮询卡死 → 强制重启
- 所有阈值均为硬编码，用户无法配置

### 硬编码常量
| 常量 | 值 | 含义 |
|------|-----|------|
| `POLL_STALL_THRESHOLD_MS` | 90,000ms | stall 判定阈值 |
| `POLL_WATCHDOG_INTERVAL_MS` | 30,000ms | 看门狗检查间隔 |
| `fetch.timeout` | 30s | 单次 getUpdates 超时 |
| `POLL_RESTART_POLICY.initialMs` | 2,000ms | 首次重启延迟 |
| `POLL_RESTART_POLICY.maxMs` | 30,000ms | 最大重启延迟 |
| `POLL_RESTART_POLICY.factor` | 1.8 | 退避因子 |

### 修复（实际生效的只有一步）
1. **删除 systemd 残留**：`sed -i '/^Environment=TELEGRAM_BOT_TOKEN=/d' ~/.config/systemd/user/openclaw-gateway.service`
2. `daemon-reload` + `restart`

### 踩坑记录：retry/timeoutSeconds 不可移到 account 级别
- 曾尝试将 `channels.telegram` 顶层的 `retry` 和 `timeoutSeconds` 移到各 account 内部，意图消除 Doctor 的 "Moved single-account" 消息
- **结果：小龙虾完全不回消息**。这两个字段只在 channel 级别有效，account 级别不识别
- **已回滚**：`retry` 和 `timeoutSeconds` 必须保留在 `channels.telegram` 顶层
- Doctor 的 "Moved single-account" 消息是误报，**不应为消除此消息而移动字段**

### 验证
- 回滚后重启 10+ 分钟 **零 stall**（修复前同时段累计 44 次）
- 14 条消息成功发送（3 个 Bot 都有活动）
- Gateway Health OK，3 bot 全在线

### 教训
- **systemd `Environment=` 和 `openclaw.json` 的 `env` 是两个独立的环境变量来源**，修复时必须两处都清理
- **`retry` 和 `timeoutSeconds` 是 channel 级别字段**，不是 account 级别字段。移到 account 后 OpenClaw 不识别，轮询直接不工作
- **`retry` 配置主要影响消息发送，不直接控制轮询重连**。轮询由 grammY runner 内置机制控制
- **Doctor 的 "Moved single-account" 消息是纯建议/误报**，不会实际修改运行时配置（除非执行 `--fix`），不应因此消息改动配置结构

## U. 多 Bot 扩展限制调研（2026-03-09）

### Telegram 硬限制
- 每个 bot token 只能有 **1 个** getUpdates 连接（硬限制）
- 不同 token 之间完全独立，不干扰
- BotFather 创建上限：普通账号 20 个，Premium 40 个

### OpenClaw 扩展瓶颈

| Bot 数量 | 风险等级 | 主要瓶颈 |
|----------|---------|----------|
| 3-5 个 | 低 | 当前长轮询方案够用 |
| 5-10 个 | 中 | 全局 dispatcher 重置影响加倍；LLM rate limit 竞争 |
| 10-20 个 | **高** | GitHub #33154：9 个 bot 产生 60K 次 conflict 错误（未修复） |
| 20+ 个 | 极高 | 需要多 Gateway 实例或切 Webhook 模式 |

### 最大风险：全局 undici dispatcher 重置
- OpenClaw 用一个全局 HTTP 客户端处理所有请求
- 调用 LLM API 时如果 timeout 参数变化，会创建新 dispatcher 并替换旧的
- **同时中断所有 Bot 的长轮询连接**
- Bot 越多，影响越大（N 个 Bot 同时断连 → retry 风暴）

### 扩展建议
- **3-5 个**：当前长轮询 + retry 够用
- **10+ 个**：评估切 Webhook 模式（需公网 HTTPS，可用 Tailscale Funnel 或 Cloudflare Tunnel）
- **LLM 分流**：不同 agent 用不同 provider，避免 rate limit 竞争

---

## V. 子 Agent 失控导致全 Provider 配额耗尽（2026-03-09 已缓解）

### 现象
- 3 个小龙虾全部变慢，mom 的请求等待 187 秒后失败
- 日志出现 `FailoverError`：minimax → kimi → zai → newcli 全部 rate limited
- 所有 provider 在短时间内同时被限速

### 根因
- `morning-briefing` cron 任务（每天 7:30）通过 `sessions_spawn` 工具同时生成 5 个子 agent
- 子 agent 各自独立调用 LLM API，短时间产生大量请求
- 一个失控子 agent（runId=ad463b45）进入重试循环，持续消耗配额
- `subagents.maxConcurrent` 默认为 30，无有效限制

### 修复
- `subagents.maxConcurrent`：30 → 3（限制并发子 agent 数）
- 后续用户决定减配至单 agent，进一步降低资源竞争

### 教训
- **子 agent 是隐藏的配额消耗大户**：一个 cron 任务就能通过 sessions_spawn 产生 N 个子 agent，每个都独立消耗 API 配额
- **FailoverError 是级联失败**：一个 provider 被限速后，请求涌向下一个 fallback，逐级击穿
- **maxConcurrent 必须合理设置**：默认 30 对于共享 API key 的场景过高

---

## W. API Key 安全存储最佳实践（2026-03-09 已落地 ✅）

### 问题
- 6 个 API Key 明文存储在 `openclaw.json` 的 `env` 块和 systemd `Environment=` 中
- `openclaw.json` 可能被版本控制、备份工具等暴露

### 官方推荐方案
- 使用 `~/.openclaw/.env` 文件存储敏感凭证
- 文件权限设为 `600`（仅所有者可读写）
- systemd 通过 `EnvironmentFile=` 指令加载

### 已落地配置
```
# ~/.openclaw/.env (chmod 600)
ANTHROPIC_API_KEY=sk-ant-...
ZAI_API_KEY=...
KIMI_API_KEY=...
BRAVE_API_KEY=...
GOOGLE_API_KEY=...
MINIMAX_API_KEY=sk-cp-...
```

```ini
# systemd service
EnvironmentFile=/home/kevinlasnh/.openclaw/.env
# openclaw.json env 块仅保留非敏感变量
# env: { HTTPS_PROXY, HTTP_PROXY }
```

### 注意
- `openclaw.json` 的 `env` 块中使用 `${VAR_NAME}` 引用环境变量（如 provider 的 apiKey 字段）
- systemd `Environment=` 和 `EnvironmentFile=` 都会注入到进程环境中
- 两者同时存在时，`Environment=` 的值优先

---

## X. 架构变更记录：三 Agent → 单 Agent（2026-03-09）

### 变更原因
- 多 agent 共享 API key 导致 rate limit 互相竞争
- 子 agent 失控可级联击穿所有 fallback provider
- 用户当前只需个人小龙虾，mom 和 ashare 暂不使用

### 删除清单

| 类型 | 删除项 |
|------|--------|
| Agent | mom（id=family）、ashare |
| Telegram Bot | chunyan-bot、ashare-bot |
| 飞书账号 | mom-feishu、ashare-feishu |
| 飞书通道 | channels.feishu（整段）、plugins.entries.feishu |
| Binding | 4 条（chunyan→family, feishu→family, ashare-bot→ashare, ashare-feishu→ashare） |
| 目录 | agents/ashare、agents/default、agents/mom、workspace-ashare、workspace-mom |

### 保留配置
```json
{
  "agents": {
    "list": [{"id": "main", "default": true, "workspace": "...", "agentDir": "...", "subagents": {"allowAgents": ["main"]}}]
  },
  "bindings": [{"agentId": "main", "match": {"channel": "telegram", "accountId": "main-bot"}}],
  "channels": {
    "telegram": {
      "accounts": {"main-bot": {"botToken": "...", "dmPolicy": "allowlist", "allowFrom": [8226087994], ...}},
      "retry": {"attempts": 5, "minDelayMs": 1000, "maxDelayMs": 10000, "jitter": 0.3},
      "timeoutSeconds": 30
    }
  }
}
```

### 恢复指南（如需重新启用多 agent）
- Bot token 已记录在 task_plan.md（main、ashare、chunyan-bot 三个 token）
- 飞书 App ID/Secret 已记录在 findings.md G 节
- 需重新创建 agent 目录、workspace、bindings
- 注意不要用 `"default"` 作为 Telegram 账号名（见 findings.md O 节）

---

## Y. Telegram 流量配置优化（2026-03-09 已完成 ✅）

### 问题现象
- 用户反馈"两条消息一条消失"
- 先出现一条消息，然后出现第二条，最后第一条消息消失

### 根因分析
- `streaming: "partial"` 使用预览机制：
  1. 发送预览消息
  2. 持续编辑预览内容
  3. 发送最终消息
  4. 删除预览消息
- 用户看到的是步骤 1 的预览和步骤 3 的最终消息，然后步骤 4 执行导致预览消失

### 解决方案
- **关闭 channel 级别流式**：`streaming: "off"`
- **启用 agent 级别块流式**：`blockStreamingDefault: "on"`
- 块流式机制：Agent 生成完整的内容块后直接发送，无预览编辑过程

### 已应用配置
```json
{
  "agents": {
    "defaults": {
      "blockStreamingDefault": "on",
      "blockStreamingCoalesce": {"idleMs": 5000},
      "blockStreamingChunk": {
        "minChars": 500,
        "maxChars": 4000,
        "breakPreference": "paragraph"
      }
    }
  },
  "channels": {
    "telegram": {
      "accounts": {
        "main-bot": {
          "streaming": "off"
        }
      }
    }
  }
}
```

### Telegram Streaming 模式对比
| 模式 | 行为 | 用户体验 |
|------|------|----------|
| `"off"` | 无流式，等待完整回复后一次发送 | ✅ 单条消息，无预览 |
| `"partial"` | 预览 + 编辑 + 删除（默认） | ❌ 双消息现象 |
| `"block"` | 遗留分块预览，可能仍显示多条 | ⚠️ 仍有双消息风险 |

### 验证结果
- ✅ 配置已应用到远程 Ubuntu 机器（100.64.65.65）
- ✅ Gateway 重启成功，Health OK (1545ms)
- ✅ 只显示一条完整消息，无预览编辑过程

---

## Z. 多 Gateway 部署方案（2026-03-09 已验证 ✅）

### 架构目标
同一台 Ubuntu 机器上运行多个独立 Gateway，每个 Gateway 承载一个独立小龙虾，连接不同的 Telegram Bot。

### 隔离方案：环境变量（推荐）

**`--profile` 不可靠！** `openclaw --profile dayong config file` 仍返回 `~/.openclaw/openclaw.json`，与 GitHub Discussion #39668 报告一致。社区建议放弃 `--profile`，改用环境变量。

**正确方式：** 在 systemd 服务中设置：
```ini
Environment=OPENCLAW_STATE_DIR=/home/kevinlasnh/.openclaw-<name>
Environment=OPENCLAW_CONFIG_PATH=/home/kevinlasnh/.openclaw-<name>/openclaw.json
```

ExecStart 中**不要**使用 `--profile`：
```ini
ExecStart=/usr/bin/openclaw gateway run --port <port>
```

### 隔离清单（官方要求）

| # | 隔离项 | 方式 |
|---|--------|------|
| 1 | 配置文件 | `OPENCLAW_CONFIG_PATH` 指向独立 `openclaw.json` |
| 2 | 状态目录 | `OPENCLAW_STATE_DIR` 指向独立 `~/.openclaw-<name>/` |
| 3 | 端口 | `gateway.port` 或 `--port`，间距 ≥ 20 |
| 4 | Bot Token | 每个 Gateway 使用不同的 Telegram Bot |
| 5 | 工作区 | 各 agent 的 `workspace` 指向独立目录 |

### 自动隔离的资源（无需额外配置）
- Sessions：各在各自 `STATE_DIR/agents/*/sessions/`
- Canvas：各在各自 `STATE_DIR/canvas/`
- Cron：各在各自 `STATE_DIR/cron/`
- Browser/CDP：base port + 2 / + 9~108
- systemd 日志：按 service unit 自动分隔

### 端口分配规则

| 资源 | 偏移量 |
|------|--------|
| Gateway WebSocket | base + 0 |
| Browser control | base + 2 |
| Canvas | 同 base |
| CDP range | base + 9 ~ base + 108 |

官方最低间距：20。我们的间距：231（18790 → 19021），安全。

### 共享 .env 文件

通过 symlink 共享：`~/.openclaw-dayong/.env` → `~/.openclaw/.env`

- 功能安全：只读操作，无并发问题
- 安全安全：同一用户同一信任边界
- 注意：共用 API Key 时高并发可能叠加 rate limit

### 当前 Gateway 布局

| Gateway | 目录 | 端口 | Bot | 模型 | 状态 |
|---------|------|------|-----|------|------|
| main | `~/.openclaw/` | 18790 | @OpenClaw_kevinlasnh_no1_bot | minimax/MiniMax-M2.5 | ✅ 在线 |
| dayong | `~/.openclaw-dayong/` | 19021 | @openclaw_BigA_winner_bot | kimi/k2p5 | ✅ 在线 |
| chunyan | `~/.openclaw-chunyan/` | 19001 | 待配 | 待配 | ⏳ 未部署 |
| zenglan | `~/.openclaw-zenglan/` | 19041 | 待配 | 待配 | ⏳ 未部署 |

### 新 Gateway 部署步骤模板

1. 重命名配置文件：`<name>.json` → `openclaw.json`
2. 补全配置（参考主 Gateway，注意不含顶层 `dmPolicy`/`groupPolicy`/`streaming`）
3. 创建 `.env` symlink → `~/.openclaw/.env`
4. 创建 systemd 服务（含 `OPENCLAW_STATE_DIR` + `OPENCLAW_CONFIG_PATH`）
5. `daemon-reload` + `enable` + `start`
6. Health check + 观察日志

### Doctor 行为警告

- Doctor 每次启动单账号 Gateway 时，会自动将 account 级字段（`dmPolicy`、`groupPolicy`、`streaming`）复制到 `channels.telegram` 顶层
- **不要执行 `openclaw doctor --fix`**，否则可能创建 `accounts.default` 幽灵账号
- 顶层字段不影响运行时功能，可忽略或手动清理

### 教训
- **永远不要用 `--profile` 做多 Gateway 隔离**，使用 `OPENCLAW_STATE_DIR` + `OPENCLAW_CONFIG_PATH`
- **永远不要把 Telegram 账号命名为 `"default"`**（findings.md O 节）
- **`retry` 和 `timeoutSeconds` 必须在 `channels.telegram` 顶层**，不能放到 account 级别（findings.md T 节）
- **不要在配置中放 `TELEGRAM_BOT_TOKEN` 环境变量**（findings.md T 节）

---

## AA. 24/7 常驻内存稳定性判断方法（2026-03-10）

### 结论先说
- **Linux 上“已使用内存”高，不等于内存泄漏。**
- 更关键的指标是：
  - `available` 是否持续充足
  - `swap` 是否持续增长
  - 单个进程 RSS / `MemoryCurrent` 是否长期单向上升

### 本次实测（主机 `100.64.65.65`）
- `uptime`: `2 days, 10 hours, 59 minutes`
- `free -h`：
  - `Mem total=15GiB`
  - `used=4.6GiB`
  - `buff/cache=8.8GiB`
  - `available=10GiB`
  - `Swap used=0B`
- `systemctl --user show`：
  - `openclaw-gateway.service`: `MemoryCurrent=533098496`（约 `533MB`）
  - `openclaw-gateway-dayong.service`: `MemoryCurrent=381374464`（约 `381MB`）
  - `mihomo-standalone.service`: `MemoryCurrent=28700672`（约 `28MB`）
- `ps` 实测 RSS：
  - 主 Gateway：约 `574MB`
  - Dayong Gateway：约 `425MB`
  - `mihomo`：约 `54MB`
- `NRestarts`：
  - 主 Gateway：`0`
  - Dayong Gateway：`0`
- 内核日志中未见实际 `OOM kill` / `Out of memory` 事件

### 如何判断是不是“会越开越卡”

**正常状态：**
- `used` 变高，但 `available` 仍很多
- `buff/cache` 很大
- `swap` 基本不用
- OpenClaw 进程内存大致在一个区间波动，而不是每天只涨不回落

**异常状态（才值得担心）：**
- `available` 持续下降，几天后接近 `0`
- `swap` 从 `0` 开始不断上涨
- 某个 `openclaw-gateway` 从几百 MB 一路涨到几 GB，且闲时也不回落
- 日志出现 `OOM`, `Killed process`, `Out of memory`
- 伴随明显症状：回复延迟越来越长、系统整体卡顿、进程被 systemd 拉起重启

### 对本项目的判断
- 目前这台机器的 `4.6GiB / 15GiB` 不危险，反而 `available=10GiB` 说明余量很大。
- 现阶段更像是：
  - Ubuntu 桌面环境占一部分
  - Linux 文件缓存占很大一部分
  - 两个 Gateway 各占几百 MB
- **按当前数据看，不像“100 天后一定暴涨”的内存泄漏型风险。**

### 已知更真实的风险源
- 历史上导致“小龙虾不回消息”的主要问题并不是内存，而是：
  - Telegram 轮询 stall（见 O / T / P 节）
  - 代理节点抖动（见 L / M 节）
  - provider rate limit / 子 agent 抢配额（见 J / V 节）

### 运维建议
- 日常先看 3 个指标：`available`、`swap used`、`openclaw-gateway MemoryCurrent`
- 如果后续想做预防性加固，优先级建议：
  1. 先观察 7-14 天内存曲线，再决定是否需要定时重启
  2. 如需硬保险，可给 systemd 加 `MemoryMax=`
  3. 如需更稳，可在低峰时段做每周一次自动重启

---

## AB. 联网调研：长时间运行时内存会不会一直涨（2026-03-10）

### 结论
- **不会因为机器开了 100 天、200 天，Linux 就必然把内存“越开越涨到爆”。**
- 长期运行后看到内存占用变高，首先要区分 3 种东西：
  1. **正常缓存**：Linux 把空闲内存拿去做 page cache / slab，提高 I/O 性能；需要时会回收。
  2. **真实泄漏**：某个进程 RSS、`MemoryCurrent` 长期单向上升，闲时也不回落。
  3. **碎片化 / 分配器行为**：Node 官方明确提示，在 glibc 上即使 V8 堆稳定，进程 RSS 仍可能增长，不一定是 JS 堆泄漏。

### 官方资料要点

#### 1. Linux 的 `used` 不是风险判定核心
- Ubuntu `free(1)` 手册说明：
  - `available` 才是“可供启动新应用而无需交换”的估算值
  - `buff/cache` 包含 page cache、slab 等可回收内存
- 这意味着：
  - `used` 高，不自动等于危险
  - `available` 高、swap 不增长，通常就是健康状态

#### 2. 文件缓存本身就是设计目标
- Linux 内核内存管理文档将内存分为匿名页和 **file-backed pages**
- file-backed pages 的典型例子就是 page cache；在有内存压力时，这类内存可以被回收
- 所以“缓存越用越多”多数是正常现象，不是泄漏证据

#### 3. Node 进程的 RSS 可能增长，但不一定是泄漏
- Node 官方 `process` 文档明确写到：
  - 在 glibc 上，由于 `malloc` 的碎片化，**即使堆使用稳定，RSS 仍可能持续增长**
- 对 OpenClaw 这种 Node 常驻服务，这一点很关键：
  - 看到 RSS 增长，不能直接下结论说“JS 内存泄漏”
  - 需要同时对比 `heapUsed`、`heapTotal`、业务负载、空闲期回落情况

#### 4. 真要追 Node 泄漏，官方建议抓 heap snapshot
- Node 官方提供了通过信号生成 heap snapshot 的方法
- 如果未来某个 Gateway 真出现“几百 MB 涨到几 GB 且不回落”，应该走 heap snapshot 诊断，而不是靠猜

#### 5. systemd 可以做软限制和硬限制
- `MemoryHigh=`：systemd 官方说明这是首选的节流/回收控制，超出后会进入强烈的内存回收，但不会立刻杀进程
- `MemoryMax=`：硬上限；达到后 cgroup 不再允许继续增长
- 对 24/7 服务的意义：
  - `MemoryHigh` 适合做“预警线”
  - `MemoryMax` 适合做“保险丝”

#### 6. systemd-oomd 适合长驻服务主机，但最好保留 swap
- `systemd-oomd` 官方文档说明：
  - 它依赖 PSI（pressure stall information）做决策
  - **强烈建议启用 swap**，否则系统在内存紧张时反应窗口会更短
- 这与当前主机状态一致：
  - 你的机器有 `4GiB` swap，且当前 `0` 使用，是健康状态

### 对当前 OpenClaw 主机的套用判断

#### 当前能力
- systemd：`255`
- cgroup：`cgroup v2`（`default-hierarchy=unified`）
- `systemd-oomd.service`：`active`
- 两个 Gateway 都有 `MemoryAccounting=yes`

#### 当前观测
- `MemAvailable ≈ 11.3GiB`
- `SwapUsed = 0`
- 主 Gateway：
  - `MemoryCurrent ≈ 533MB`
  - `MemoryPeak ≈ 1.04GB`
- Dayong Gateway：
  - `MemoryCurrent ≈ 383MB`
  - `MemoryPeak ≈ 549MB`
- 当前全机更大的单进程占用，反而是桌面侧的 `gnome-system-monitor`

#### 判断
- 这台机子**现在没有“长时间运行导致内存失控”的证据**。
- 如果以后真的出现卡顿，更值得优先怀疑的是：
  - 桌面 GUI / 浏览器 / 系统监控工具常驻
  - 某个 Gateway 进程长期单向膨胀
  - provider/代理/轮询问题引起的“像卡顿”，但根因并不在内存

### 维护建议

#### A. 日常监控
- 建议固定看 4 个指标：
  - `MemAvailable`
  - `SwapFree/SwapUsed`
  - `MemoryCurrent` / RSS（每个 Gateway）
  - `MemoryPeak`
- 当前最适合本项目的结论标准：
  - `MemAvailable` 长期 > 2GiB：安全
  - `swap` 长期接近 0：安全
  - 单个 Gateway 若长期 > 1.5-2GiB 且继续涨：需要介入

#### B. 低风险维护
- 不建议为了“怕内存涨”而每天重启。
- 更合理的是：
  - 先观察 7-14 天趋势
  - 内核 / systemd / OpenClaw 升级后正常重启
  - 只有在发现单向增长时才考虑定时重启

#### C. 中风险加固
- 可给 Gateway 加：
  - `MemoryHigh=900M`
  - `MemoryMax=1400M`
- 这是**基于当前实测值推导的建议区间**：
  - 主 Gateway 当前约 `533MB`，峰值约 `1.04GB`
  - Dayong Gateway 当前约 `383MB`，峰值约 `549MB`
- 如果使用当前 `Restart=always`，达到硬限制导致退出后，systemd 会自动拉起服务

#### D. 专用机优化
- 这台机器如果长期只做小龙虾，最好减少桌面进程常驻：
  - 不常开 `gnome-system-monitor`
  - 尽量少开浏览器页面
  - 如后续完全专用，可考虑走更轻的运行环境
- 这类优化对长期稳定性往往比“担心 Linux 缓存”更有价值

### 官方来源
- Ubuntu `free(1)` man page:
  - https://manpages.ubuntu.com/manpages/noble/man1/free.1.html
- Linux kernel memory management concepts:
  - https://docs.kernel.org/6.15/mm/concepts.html
- Node.js `process` API:
  - https://nodejs.org/api/process.html
- Node.js heap snapshot guide:
  - https://nodejs.org/en/learn/diagnostics/memory/using-heap-snapshot
- Node.js CLI `--max-old-space-size`:
  - https://nodejs.org/api/cli.html#--max-old-space-sizesize-in-mib
- systemd resource control:
  - https://www.freedesktop.org/software/systemd/man/latest/systemd.resource-control.html
- systemd-oomd:
  - https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.html

---

## AC. 重启后 SSH 救援链路审计（2026-03-10）

### 目标
- 确保这台专用小龙虾主机在意外重启后，仍能自动恢复到“可通过 Tailscale IP SSH 回来”的状态。

### 实测结果（主机 `100.64.65.65`）
- `tailscaled`：
  - `systemctl is-enabled tailscaled` → `enabled`
  - `systemctl is-active tailscaled` → `active`
- `ssh`：
  - `systemctl is-enabled ssh` → `enabled`
  - `systemctl is-active ssh` → `active`
- `loginctl show-user kevinlasnh -p Linger` → `Linger=yes`
- Tailscale 状态文件：
  - `/var/lib/tailscale/tailscaled.state` 存在
- `tailscale status --json` 关键信息：
  - `BackendState=Running`
  - `TailscaleIPs` 含 `100.64.65.65`
  - `HostName=openclaw-24x7`
  - `Online=true`
- 用户级服务：
  - `openclaw-gateway.service` → `enabled + active`
  - `openclaw-gateway-dayong.service` → `enabled + active`
  - `mihomo-standalone.service` → `enabled + active`

### 结论
- 当前配置已经满足：
  1. 系统开机后自动启动 Tailscale
  2. 恢复同一 Tailnet 身份（基于持久化 state）
  3. 自动启动 SSH 服务
  4. 即使用户未登录，也能启动用户级 OpenClaw / mihomo 服务（因为 `Linger=yes`）
- 所以对“万一机器突然重启，我还能不能 SSH 回来救它”这个问题，**当前答案是能**。

### 关键配置含义
- `tailscaled.service` 是系统级服务，`WantedBy=multi-user.target`
- `ssh.service` 是系统级服务，`WantedBy=multi-user.target`
- `tailscaled` 使用持久化 state 文件：
  - `/var/lib/tailscale/tailscaled.state`
- `loginctl enable-linger` 的效果已经存在：
  - `Linger=yes`
  - 这保证了用户级 systemd 服务无需交互登录也能在开机后拉起

### Key Expiry 后续处理结果
- 初次审计时，`openclaw-24x7` 的 `tailscale status --json` 曾显示：
  - `KeyExpiry=2026-09-03T14:38:18Z`
- 用户已于 `2026-03-10` 在 Tailscale 后台对该设备执行 `Disable key expiry`
- 再次复核结果：
  - `tailscale status --json` 中，`Self` 节点**已不再返回 `KeyExpiry` 字段**
  - 说明这台长期无人值守的专用机已经切到“不自动过期”状态
- 因此，这一项已从“潜在风险”转为“已处理完成”

### 官方来源
- Tailscale Linux install docs:
  - https://tailscale.com/kb/1031/install-linux

---

## AD. Dayong 小龙虾在 Kimi 下的工具执行异常（2026-03-10）

### 结论
- `dayong` 的问题**不是**工具权限没开。
- 根因更像是：
  - 当前 `dayong` 使用的是自定义 provider 路径 `kimi/k2p5`
  - 在这条链路下，Kimi 经常把“工具调用”输出成**普通文本**
  - OpenClaw 没收到结构化 `toolCall`，所以实际工具不会执行

### 实测证据

#### 1. 配置层面对比：权限没有差异
- `main` 与 `dayong` 的 `openclaw.json` 中均有：
  - `tools.exec.security = "full"`
  - `commands.native = "auto"`
  - `commands.nativeSkills = "auto"`
  - `sandbox.mode = "off"`
- 因此不是“某个 bot 没开 exec 权限”。

#### 2. 会话层面对比：`main` 有真实 toolCall，`dayong` 没有
- `main` 典型会话统计：
  - `content:toolCall = 187`
- `dayong` 同类会话统计：
  - `content:toolCall = 0`
- 说明 `main` 会真实触发工具调用，而 `dayong` 当前会话里根本没发出结构化工具调用。

#### 3. 同样的 CLI 测试，结果完全不同
- `main` 测试指令：
  - `Use the exec tool to run: pwd. Return only the exact output of the command.`
- `main` 结果：
  - 真正发起 `toolCall`
  - 真正执行 `pwd`
  - 返回 `/home/kevinlasnh/.openclaw/workspace`

- `dayong` 同类测试：
  - 有一次直接遇到 `429 engine overloaded`
  - 再次强制测试时，返回的是纯文本：
    - `/exec({"command": "pwd"})`
- 这不是工具执行结果，而是模型把“想调用工具”说成了文字。

#### 4. 用户真实对话中也有“假装已执行”的行为
- `dayong` 在会话里会说：
  - “我已经读取了 SOUL.md”
  - “我已经将内容写入 SOUL.md”
- 但对应会话记录里没有实际 `toolCall` / `toolResult`
- 这是典型的“口头宣称已执行，实际没调用工具”

### 推断
- **这是一个 Kimi 当前接入链路的兼容性问题，而不是权限问题。**
- 更准确地说，是当前 `kimi/k2p5` 在这套 OpenClaw 路径下：
  - 有时直接不发工具调用
  - 有时把工具调用写成伪指令文本
  - 有时还会碰到 `429 overloaded`

### 与官方 `kimi-coding` provider 的关系
- 这次排查再次证明：
  - 当前运行中的 `dayong` 不是官方 `kimi-coding/k2p5` 路径
  - 而是自定义 `kimi/k2p5` provider
- 之前 findings 中记录的“Kimi Coding Provider 两难困境”依然 relevant：
  - 想用官方路径，会遇到 auth / model id / user-agent 问题
  - 想用自定义路径，聊天可用，但工具调用兼容性差

### 已做的低风险缓解
- 已在 `~/.openclaw-dayong/workspace/AGENTS.md` 补充规则：
  - 没拿到 `toolResult` 不得声称已执行成功
  - 禁止输出 `/exec(...)` / `/read(...)` / `/write(...)` 这类伪指令文本
  - 工具未成功执行时必须如实说明
- 该缓解更偏向“防止假装执行”，**还不能视为根治**。

### 新发现：旧 session 可能还没吃到新护栏
- 在补充 `AGENTS.md` 规则后，再次跑 `dayong` 测试：
  - 真实文件长度约 `379 chars`
  - 但运行报告里 `AGENTS.md` 的注入长度仍显示约 `164 chars`
- 这说明当前 `agent:dayong:main` 这个旧 session **很可能仍在沿用旧的 workspace 提示快照**
- 因此：
  - 新加的“禁止假装执行工具”规则，未必已对当前旧会话生效
  - 若要让这类规则更可靠地生效，应优先开启新会话（如 `/new` / `/reset`）

### 后续可行方向
1. **保留 Kimi，不切模型，先防伪执行**
   - 让新 session 明确读取新的 AGENTS 规则
   - 目标：至少先不再“嘴上说执行了”
2. **保留 Kimi，研究真正修法**
   - 重新打通官方 `kimi-coding` provider
   - 或在 OpenClaw 层加兼容，把 `/exec({...})` 文本解析成真实工具调用
3. **不推荐的误判**
   - 不要把问题归因到 `tools.exec.security`
   - 当前证据不支持这一点

---

## AD. Telegram Polling Stall 深度分析与源码补丁（2026-03-10）

### 问题现象
- main Gateway 从凌晨 04:11 到上午持续每 ~9.5 分钟 stall 一次
- 日志：`Polling stall detected (no getUpdates for ~107s); forcing restart.`
- stall 后轮询重启，运行 6-7 分钟后再次卡死，循环往复

### 根因链路
```
小龙虾发 getUpdates 长轮询（timeout=30s）
  → HTTP 请求通过 Clash/mihomo 代理（127.0.0.1:7897）
  → 代理连接到远端节点服务器（SS/VMess/Trojan）
  → 远端节点连接 api.telegram.org

某个时刻：
  → 代理节点服务端空闲超时（~5min）或 NAT 表项过期
  → TCP 连接被静默断开（不发 RST/FIN）
  → mihomo 本地不一定感知（TCP keep-alive 默认可能不够频繁）
  → Node.js undici ProxyAgent 有已知 bug（GitHub #3944），忽略 connect 超时
  → getUpdates 请求卡在死连接上，无法返回
  → OpenClaw 看门狗 90 秒后才检测到 stall
  → 强制重启轮询 → 2-30 秒后恢复 → 运行几分钟 → 再次触发
```

### 关键发现

#### 1. `timeoutSeconds` 配置无效
- `channels.telegram.timeoutSeconds` 只是传给 Telegram API 的 `getUpdates?timeout=N` 参数
- 它告诉 Telegram "等 N 秒再返回"，不是客户端 HTTP 超时
- 连接死了后这个参数不起作用——Telegram 根本收不到
- `createTelegramRunnerOptions` 中 `fetch.timeout: 30` 是**硬编码**，不读配置

#### 2. undici ProxyAgent 超时 bug
- GitHub Issue `nodejs/undici#3944`：ProxyAgent 会忽略 `connect` 超时选项
- 通过代理的 HTTP 连接没有有效的连接级超时保护
- 只有应用层的 AbortSignal 超时才能打破卡死

#### 3. mihomo keep-alive 部分有效
- 默认配置中无 `keep-alive-interval` 设置
- 添加 `keep-alive-interval: 15` 后，重启等待从 30s 降到 2s（退避策略恢复）
- 但 stall 本身仍发生——TCP keep-alive 在 HTTP 隧道场景下可能不完全生效

#### 4. url-test 切换不断开已有连接
- Clash Verge 文档确认：`url-test` 切换节点时，已建立的 TCP 连接不会自动断开
- 旧连接仍走旧节点，旧节点不可用时连接静默卡死

### OpenClaw 源码关键常量

| 常量 | 原始值 | 补丁后 | 含义 |
|------|--------|--------|------|
| `POLL_STALL_THRESHOLD_MS` | 90,000ms | **35,000ms** | stall 判定阈值 |
| `POLL_WATCHDOG_INTERVAL_MS` | 30,000ms | **5,000ms** | 看门狗检查间隔 |
| `fetch.timeout` | 30s | 未改 | 单次 getUpdates 超时（硬编码） |
| `POLL_RESTART_POLICY.initialMs` | 2,000ms | 未改 | 首次重启延迟 |
| `POLL_RESTART_POLICY.maxMs` | 30,000ms | 未改 | 最大重启延迟 |

**阈值约束**：`POLL_STALL_THRESHOLD_MS` 必须 > `fetch.timeout`（30s），否则正常的 30 秒长轮询等待会被误判为 stall。

### 补丁文件列表
```
/usr/lib/node_modules/openclaw/dist/reply-C5LKjXcC.js
/usr/lib/node_modules/openclaw/dist/pi-embedded-DoQsYfIY.js
/usr/lib/node_modules/openclaw/dist/pi-embedded-C6ITuRXf.js
/usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-BP0viZiL.js
/usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-Cndjtt0g.js
```

### 补丁命令
```bash
for f in reply-C5LKjXcC.js pi-embedded-DoQsYfIY.js pi-embedded-C6ITuRXf.js; do
  sudo sed -i 's/const POLL_STALL_THRESHOLD_MS = 9e4/const POLL_STALL_THRESHOLD_MS = 35000/' /usr/lib/node_modules/openclaw/dist/$f
  sudo sed -i 's/const POLL_WATCHDOG_INTERVAL_MS = 3e4/const POLL_WATCHDOG_INTERVAL_MS = 5000/' /usr/lib/node_modules/openclaw/dist/$f
done
for f in dispatch-BP0viZiL.js dispatch-Cndjtt0g.js; do
  sudo sed -i 's/const POLL_STALL_THRESHOLD_MS = 9e4/const POLL_STALL_THRESHOLD_MS = 35000/' /usr/lib/node_modules/openclaw/dist/plugin-sdk/$f
  sudo sed -i 's/const POLL_WATCHDOG_INTERVAL_MS = 3e4/const POLL_WATCHDOG_INTERVAL_MS = 5000/' /usr/lib/node_modules/openclaw/dist/plugin-sdk/$f
done
```

### mihomo keep-alive 配置
已添加到 `/home/kevinlasnh/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml` 顶部：
```yaml
keep-alive-interval: 15
keep-alive-idle: 15
tcp-concurrent: true
```
通过 unix socket 热重载生效：
```bash
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/configs -X PUT \
  -d '{"path":"/home/kevinlasnh/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml"}' \
  -H "Content-Type: application/json"
```

### 方案效果对比

| 方案 | 效果 | 状态 |
|------|------|------|
| 降低 timeoutSeconds 15→30 | ❌ 无效（不是客户端超时） | 已回滚 |
| mihomo keep-alive | ⚠️ 部分有效（重启延迟降低） | 已应用 |
| 源码补丁（降低检测阈值） | ✅ 有效（恢复从 2-3min 降到 40s） | 已应用 |
| 给 fetch 加 AbortSignal.timeout | 🔜 最佳方案（PR 方向） | 未实施 |

### PR 建议（官方修复方向）
**不应直接改硬编码数值**，而应：
- 给 `getUpdates` 的 fetch 请求加客户端 `AbortSignal.timeout((pollingTimeout + 5) * 1000)`
- 这样连接卡死 35 秒后 HTTP 请求自动中止，不需要依赖看门狗
- 这是"HTTP 请求没有客户端超时"的真实 bug 修复

### Tailscale SSH ACL 优化
- 原配置：`"action": "check"`（每次 SSH 都弹浏览器认证）
- 改为：`"action": "accept"`（直接连接无需认证）
- 位置：https://login.tailscale.com/admin/acls 的 `ssh` 部分

---

## AE. 多 Gateway 独立性验证（2026-03-10 已确认 ✅）

### 验证方式
- 重启 dayong Gateway（`systemctl --user restart openclaw-gateway-dayong`）
- 观察 main Gateway 状态

### 验证结果
- main Gateway 完全不受影响：uptime 从 `Mon 2026-03-09 20:17:39` 持续，未中断
- dayong 重启后新 PID 和启动时间均正确
- 两个 Gateway 之间没有任何依赖关系

### 结论
- 每个 Gateway 是独立的 systemd 服务、独立进程、独立端口、独立 Bot Token
- 停止/重启/崩溃任何一个 Gateway 不影响其他 Gateway

---

## AG. Tool 执行消息可见性：verboseDefault 配置（2026-03-10 已完成 ✅）

### 需求
用户希望小龙虾在执行工具时也发消息，而不是只显示"正在输入"。

### 源码分析结论

OpenClaw **内置了**完整的 tool 执行公告机制，通过 `verboseDefault` 控制：

**配置方式：**
```json
{
  "agents": {
    "defaults": {
      "verboseDefault": "on"
    }
  }
}
```

**三个级别：**

| 级别 | 行为 | 发送内容 |
|------|------|----------|
| `"off"` | **默认**。不发 tool 消息 | 仅 typing 指示器 |
| `"on"` | 发送 tool 调用摘要 | 如 "🔎 Web Search: query=xxx" |
| `"full"` | 发送摘要 + tool 完整输出 | 除摘要外，还发送 tool 的完整输出文本 |

**内置 Tool 显示映射（TOOL_MAP）：**

| Tool 名 | Emoji | Label |
|---------|-------|-------|
| `web_search` | 🔎 | Web Search |
| `exec` | 🛠 | Exec |
| `read` | 📖 | Read |
| `write` | ✍ | Write |
| `edit` | 📝 | Edit |
| `web_fetch` | 📄 | Web Fetch |
| `browser` | 🌐 | Browser |
| `memory_search` | 🧠 | Memory Search |
| `sessions_spawn` | 🧑‍🔧 | Sub-agent |
| 其他 | 🧩 | (工具名) |

**发送链路（源码级确认）：**
```
LLM 发起 tool_use → handleToolExecutionStart()
  → 检查 shouldEmitToolEvents（由 verboseLevel 控制）
  → ctx.emitToolSummary(toolName, meta)
  → emitToolResultMessage()
  → params.onToolResult({text: "🔎 Web Search: query=...", ...})
  → dispatchReplyWithBufferedBlockDispatcher
  → Telegram sendMessage()
```

**判定函数：**
```js
const shouldEmitToolResult = () =>
  params.verboseLevel === "on" || params.verboseLevel === "full";
```

**resolvedVerboseLevel 优先级：**
```js
directives.verboseLevel          // 1. 用户指令（/verbose on）
  ?? sessionEntry?.verboseLevel  // 2. 会话级存储
  ?? agentCfg?.verboseDefault;   // 3. 配置文件默认值
```

### 用户按会话切换
- 在 Telegram 中发送 `/verbose on` / `/verbose off` / `/verbose full` 即可切换
- 也支持内联用法：`/verbose on 帮我搜索今天的天气`
- 重启 gateway 或新会话后回退到 `verboseDefault` 配置值

### 与其他机制的关系
- `ANNOUNCE_SKIP` / `ANNOUNCE_QUEUES`：与 tool 公告**无关**，是子代理间通信机制
- `blockStreaming`：与 tool 公告**独立**，tool 消息走 `sendToolResult()` 而非 `sendBlockReply()`
- `typingIndicator`：typing 和 tool 公告是**独立的两套机制**，typing 始终会发送

### 社区动态
- GitHub Issue #17351：有用户请求 `"natural"` 模式，用自然语言替代原始技术信息（如 "正在搜索网页..." 代替 "🔎 Web Search: query=xxx"），尚未实现

### 已落地配置
- `~/.openclaw/openclaw.json` → `agents.defaults.verboseDefault = "on"`
- Gateway 已重启生效

---

## AF. Main vs Dayong 实时差异矩阵（2026-03-10 11:25 CST）

### 1. 当前 live 配置层差异

| 项目 | `main` | `dayong` | 备注 |
|------|--------|----------|------|
| Gateway 服务 | `openclaw-gateway.service` | `openclaw-gateway-dayong.service` | 两边都在运行 |
| `OPENCLAW_STATE_DIR` | 默认 `~/.openclaw` | `~/.openclaw-dayong` | 多 Gateway 隔离正常 |
| `tools.exec.security` | `full` | `full` | 不是权限问题 |
| `commands.native` | `auto` | `auto` | 无差异 |
| `commands.nativeSkills` | `auto` | `auto` | 无差异 |
| sandbox | `off` | `off` | 不是沙箱拦截 |
| 默认模型 | `minimax/MiniMax-M2.5` | `kimi/k2p5` | 当前 live 模型本来就不同 |
| tools 数量 | 25 | 25 | 不是“dayong 没工具” |

### 2. 运行时 prompt / 上下文差异

实时 `openclaw agent --json` 的 `systemPromptReport` 显示：

| 指标 | `main` | `dayong` | 影响 |
|------|--------|----------|------|
| `systemPrompt.chars` | `48966` | `15555` | `dayong` 总 prompt 明显更薄 |
| `projectContextChars` | `29299` | `2879` | `dayong` 项目上下文只有约 1/10 |
| skills 注入数 | 21 | 4 | `dayong` 缺少大量工作脚手架 |
| skills prompt chars | `8297` | `1970` | 差距显著 |
| 注入文件 | `AGENTS/SOUL/TOOLS/IDENTITY/USER/HEARTBEAT/BOOTSTRAP/MEMORY` | `AGENTS/SOUL/TOOLS/IDENTITY/USER/HEARTBEAT/BOOTSTRAP` | `dayong` 少了 `MEMORY.md` |

### 3. 当前 workspace 实体文件也明显不对等

`main` 当前 workspace 比 `dayong` 丰富很多，不只是“字数多一点”：

- `main`：
  - `AGENTS.md` 约 `16 KB`
  - `MEMORY.md` 约 `15 KB`
  - `SOUL.md` 约 `3.6 KB`
  - `TOOLS.md` 约 `3.3 KB`
  - 还有 `BOOT.md`、脚本、测试文件、运行文档等
- `dayong`：
  - `AGENTS.md` 约 `795 B`
  - `SOUL.md` 约 `398 B`
  - `TOOLS.md` 约 `860 B`
  - 只有少量基础身份文件

这意味着：即便把“模型名字”设成一样，两边也不是在同一个知识地基上工作。

### 4. 旧 session 提示快照滞后，且两边都存在

实时扫描发现，两边当前 session 注入的 workspace 文件长度都**落后于磁盘实际文件**：

- `main`
  - 实际 `AGENTS.md` 约 `16102 chars`
  - 但当前 session 注入仍约 `12587 chars`
- `dayong`
  - 实际 `AGENTS.md` 约 `795 chars`
  - 但当前 session 注入仍约 `164 chars`

这说明当前 `agent:main:main` 和 `agent:dayong:main` 都在沿用较早的 prompt 快照；区别在于：

- `main` 的旧快照本身已经很丰富，所以还能稳定工作
- `dayong` 的旧快照本身就很薄，而且没吃到后补的“禁止伪工具调用”规则

### 5. 行为差异：`pwd` 有假阳性，随机 UUID 才能验证真工具调用

#### 为什么 `pwd` 不够严格
- `workspaceDir` 已经出现在 prompt / systemPromptReport 里
- 模型可能**不调用工具，直接猜**出 `/home/kevinlasnh/.openclaw-dayong/workspace`
- 所以 `pwd` 返回对了，不等于工具真的执行了

#### 更严格的实时对照
- `main`：
  - 指令：`cat /proc/sys/kernel/random/uuid`
  - 结果：真实 `toolCall` + `toolResult`
  - 返回了不可预测 UUID
- `dayong`：
  - 同样指令
  - 结果：返回纯文本 `/exec({"command": "cat /proc/sys/kernel/random/uuid"})`
  - **没有真实工具调用**

因此，`dayong` 当前“会不会调用工具”的答案仍然是：
- 工具列表存在
- 但在 `kimi/k2p5` 这条当前链路下，**不会稳定地产生 OpenClaw 需要的结构化 `toolCall`**

### 6. “主小龙虾以前也是 Kimi，为什么能干活”已经被坐实

历史 session 复核结果：

- `main` 历史上确实存在多条 `provider=kimi, model=k2p5` 的 session
- 且这些 session 中真实 `toolCall` / `toolResult` 不为 0，例如：
  - `578a6643-c5d0-4879-a85b-fa894f3624c3.jsonl`：20 次 `toolCall`
  - `71c96c58-3430-4a54-b3f1-c98f11dd0ad5.jsonl`：11 次 `toolCall`
  - `d697f9ae-6378-444c-a664-69bc4379d99b.jsonl`：11 次 `toolCall`

结论不是“Kimi 一定不行”，而是：

- `Kimi` 在 `main` 这套更厚的 prompt / workspace / skills 环境里，历史上确实能正常出工具调用
- `dayong` 当前这套更薄、更旧的上下文环境下，`Kimi` 兼容性明显更差

### 7. 当前最接近事实的根因判断

`dayong` 的工具异常不是单点原因，而是三层叠加：

1. **当前 live 模型不同**
   - `main` 现在跑的是 `MiniMax-M2.5`
   - `dayong` 跑的是 `kimi/k2p5`
2. **当前 prompt 地基差很多**
   - `dayong` 的 workspace / skills / project context 远弱于 `main`
3. **当前 session 还是旧快照**
   - 尤其 `dayong` 没吃到新护栏，导致伪工具调用更容易继续出现

所以用户感受到的“主小龙虾聪明，小姨爹的小龙虾蠢”，本质上不是“同一个模型平移过去怎么突然坏了”，而是：

- 模型不同
- 工作区不同
- 技能脚手架不同
- session 快照不同
- 最终导致工具调用质量完全不同

---

## AG. “灵魂不同”与“能力不同”不是一回事（2026-03-10 11:45 CST）

### 1. 源码层已经把两者分开了

本次直接核查了 OpenClaw 安装目录 `/usr/lib/node_modules/openclaw/dist/` 的相关实现，得到两个关键事实：

#### `SOUL.md` 的定位是 persona / tone
OpenClaw 在构造 `Project Context` 时写得很直白：

- `If SOUL.md is present, embody its persona and tone.`

这说明 `SOUL.md` 主要控制：
- 说话风格
- 人设气质
- 回答语气

它**不是**决定工具、技能、记忆检索、任务工作流的唯一核心。

#### `AGENTS.md` / `TOOLS.md` / `MEMORY.md` / `skills` 属于能力脚手架
同一段系统提示构造逻辑里，OpenClaw 会把这些内容纳入：

- `## Skills`
- `## Memory Recall`
- `# Project Context`

而且源码里明确写了：

- 回忆相关问题前，要 `memory_search` `MEMORY.md + memory/*.md`
- `TOOLS.md does not control tool availability; it is user guidance for how to use external tools.`
- 这些 workspace files 会作为 project context 被拼进 system prompt

结论：

- `SOUL.md` 可以不同
- 但 `AGENTS.md`、`TOOLS.md`、`MEMORY.md`、skills 不能当成“只是人设附件”
- 它们更接近“操作系统”和“能力插件”

### 2. `main` 真正强的，不是灵魂，而是整套能力地基

#### 技能面差距已经被定量化

实时 `openclaw skills` 结果：

- `main`: **22/70 ready**
- `dayong`: **6/54 ready**

`main` 比 `dayong` 多出的 ready skills，不是装饰，而是直接影响办事能力的组件，例如：

- `planning-with-files`
- `self-improvement`
- `capability-evolver`
- `gmail`
- `google-calendar`
- `openclaw-updater`
- `second-brain-intake`
- `self-learning`
- `trading-brain`
- `wechat-article-extractor`
- `x-tweet-fetcher`
- `youtube-transcript`
- `youtube-ultimate`

而 `dayong` 当前 ready 的只有：

- `healthcheck`
- `skill-creator`
- `weather`
- `csv-data-summarizer`
- `find-skills`
- `obsidian-markdown`

这不是“少一点功能”，而是**工作能力面本身窄很多**。

#### 技能来源层也不对等

根据 `skills` 加载逻辑和实时目录扫描：

| 技能来源 | `main` | `dayong` |
|---------|--------|----------|
| `~/.agents/skills`（全局个人） | 4 | 4 |
| `~/.openclaw*/skills`（managed） | 8 | 0 |
| `workspace/skills` | 18 | 0 |
| `workspace/.agents/skills` | 1 | 0 |

也就是说：

- `dayong` 现在基本只吃到了“全局那 4 个基础 skill”
- `main` 额外吃到了 managed + workspace 两层技能仓库

这已经足以解释为什么它“更像会办事”

### 3. 记忆层差距也会被用户感知成“聪明”

`main` 当前具备：

- `workspace/MEMORY.md`
- `workspace/memory/`
- state memory DB：`~/.openclaw/memory/main.sqlite`

而 `dayong` 当前没有：

- 没有 `MEMORY.md`
- 没有 `workspace/memory/`
- 没有 state memory DB

OpenClaw 源码又明确要求：涉及 prior work / decisions / dates / preferences / todos 时，优先搜索 `MEMORY.md + memory/*.md`。

因此从用户体验上看：

- `main` 更“记得住”
- `dayong` 更“没有上下文”

这会被直接感知为“没那么聪明”，即便它表面上还是同类模型。

### 4. `AGENTS.md` 在 OpenClaw 里不是“灵魂”，而是操作手册

`main` 的 `AGENTS.md` 里实际承载了：

- session startup 顺序
- 记忆写入规则
- 长期/短期记忆分层
- 安全边界
- 外部/内部动作边界
- 群聊行为约束

而 `dayong` 的 `AGENTS.md` 目前只是一份很薄的工作规范，重点还集中在“别假装执行工具”。

所以如果用户说：

- “我不要它的灵魂跟我一样”

这是完全可以的。

但如果把 `AGENTS.md` 也当成“只是灵魂的一部分”一起删薄，那么失去的其实是：

- startup 工作流
- 记忆规约
- 工具使用准则
- 环境协作习惯

这些都是能力层，不是人设层。

### 5. 对用户问题的直接结论

用户的直觉基本是对的：

- **不需要复制 `main` 的灵魂人格**
- 但如果希望 `dayong` 的“聪明程度”接近 `main`，就必须补齐**非人格能力层**

更准确地说，应该复制或重建的是：

1. **能力脚手架**
   - 丰富版 `AGENTS.md`
   - 环境化 `TOOLS.md`
   - 更完整 `USER.md`
2. **记忆层**
   - `MEMORY.md`
   - `workspace/memory/`
   - memory 检索使用习惯
3. **技能层**
   - managed skills
   - workspace skills
4. **模型稳定性层**
   - fallback
   - 会话重建验证

而不必复制的是：

- `SOUL.md` 的人格设定
- `IDENTITY.md` 的名字、emoji、风格
- 面向 kevinlasnh 的私人记忆内容

### 6. 当前最值得避免的误区

#### 误区 1：以为“同模型 = 同聪明”
错。当前 `main` live 模型本来就是 `MiniMax-M2.5`，不是 Kimi。

#### 误区 2：以为“SOUL 不同导致能力差”
不对。`SOUL` 更多是语气和人设；真正拉开能力差距的是 skills、memory、AGENTS、TOOLS、workspace 知识层。

#### 误区 3：以为”dayong 没工具”
不对。它有工具，但当前 prompt 地基太薄，加上 `Kimi` 这条链路的结构化调用兼容性也差，所以更容易输出伪工具文本。

---

## AH. Telegram Webhook + Tailscale Funnel 架构（2026-03-10 ✅）

### 1. 为什么从 Polling 切到 Webhook

| 维度 | Long Polling | Webhook |
|------|-------------|---------|
| 消息延迟 | 0-66 秒（含 stall） | <1 秒 |
| 连接方向 | Bot → Telegram（出站） | Telegram → Bot（入站） |
| 代理影响 | 代理 TCP 静默断开导致 stall | 无长连接，无 stall |
| 资源消耗 | 持续维护 TCP 连接 | 按需接收 HTTP POST |

**根因**：Long polling 通过 mihomo 代理维护到 Telegram 的 TCP 长连接，代理服务器每 5-18 分钟会静默关闭空闲连接，而 undici ProxyAgent 的 `connect.timeout` 不生效（bug #3944），导致 OpenClaw 检测不到断开，消息堆积在 Telegram 服务器。

### 2. Tailscale Funnel 配置

Tailscale Funnel 将本地端口暴露为公网 HTTPS 端点，无需公网 IP、无需域名、无需 SSL 证书。

**可用端口**：仅 443、8443、10000

**当前部署**：

| Gateway | Funnel 端口 | 本地端口 | 命令 |
|---------|------------|---------|------|
| main | 443 | 8787 | `sudo tailscale funnel --bg 8787` |
| dayong | 8443 | 8788 | `sudo tailscale funnel --https=8443 --bg 8788` |
| （预留） | 10000 | 待定 | `sudo tailscale funnel --https=10000 --bg <port>` |

**公网 URL**：
- main: `https://openclaw-24x7.tailda6e28.ts.net/`
- dayong: `https://openclaw-24x7.tailda6e28.ts.net:8443/`

**管理命令**：
```bash
# 查看当前 Funnel 状态
tailscale funnel status

# 重置所有 Funnel
sudo tailscale funnel reset

# 关闭单个端口
sudo tailscale funnel --https=8443 off
```

### 3. OpenClaw Webhook 配置

在 `openclaw.json` 的 `channels.telegram` 中添加：

```json
{
  “webhookUrl”: “https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook”,
  “webhookSecret”: “<openssl rand -hex 32 生成>”,
  “webhookPort”: 8787
}
```

**关键要点**：
- `webhookUrl` **必须包含 `/telegram-webhook` 路径**，否则 Telegram POST 到 `/` 会收到 404
- `webhookPort` 是 OpenClaw 本地监听端口，Funnel 会将公网流量转发到此端口
- `webhookSecret` 用于验证入站请求确实来自 Telegram
- 每个 Gateway 的 `webhookSecret` 应不同

### 4. Telegram Webhook 验证命令

```bash
# 查看 main bot webhook 状态
curl -s “https://api.telegram.org/bot<TOKEN>/getWebhookInfo” | python3 -m json.tool

# 期望输出
{
  “url”: “https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook”,
  “has_custom_certificate”: false,
  “pending_update_count”: 0,
  “last_error_date”: null,
  “last_error_message”: null
}
```

### 5. 超过 3 个 Gateway 的扩展方案

Tailscale Funnel 只支持 3 个端口（443、8443、10000），如需部署第 4+ 个 Gateway：

```
方案 A：nginx 路径路由（推荐）
Funnel 443 → nginx → /main → 127.0.0.1:8787
                    → /dayong → 127.0.0.1:8788
                    → /chunyan → 127.0.0.1:8789
                    → /zenglan → 127.0.0.1:8790

方案 B：Cloudflare Tunnel（替代 Funnel）
无端口数量限制，但需要域名和 Cloudflare 账号
```

### 6. 故障排查

| 现象 | 原因 | 解决 |
|------|------|------|
| Telegram 返回 404 | webhookUrl 缺少 `/telegram-webhook` 路径 | 补全路径 |
| `pending_update_count` 持续增长 | Webhook 监听未启动 | 检查 Gateway 服务状态 |
| `last_error_message: SSL` | Funnel 未启动或已断开 | `sudo tailscale funnel --bg <port>` |
| 消息延迟恢复到分钟级 | Funnel 意外关闭，回退到 polling | 检查 `tailscale funnel status` |
