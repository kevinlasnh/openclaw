# Task Plan: 多小龙虾量化交易系统架构升级

## 已完成（2026-03-08 下午）：单 Gateway 双 Agent 防串线 ✅

### 目标
修复”两个小龙虾各聊各的”路由隔离，确保：
- 你的 Telegram 只到 `main`
- 妈妈的 Feishu/Telegram 只到 `mom`
- 不发生 fallback 导致的串消息

### 验收结果

| 项目 | 状态 |
|------|------|
| 官方文档核查（routing/session） | ✅ 已完成 |
| 线上 gateway 服务状态 | ✅ active (running) |
| `agents.list` 包含 `main` | ✅ 已修复（`main` default=true + `mom`） |
| `main` 可直接调用 | ✅ 返回 `MAIN_OK` |
| `bindings` 指向 `main/default` | ✅ 已存在 |
| 会话隔离（`dmScope=per-account-channel-peer`） | ✅ 已配置 |
| `telegram.defaultAccount` | ✅ `”default”` |
| `feishu.defaultAccount` | ✅ `”mom-feishu”` |
| 飞书 `typingIndicator` | ✅ 已重新开启 |
| Gateway health（双 Telegram + Feishu） | ✅ 全部 ok |

### 修改内容（Claude Opus 4.6 执行）
1. `agents.list` 加入 `main`（`default=true`，workspace=默认，agentDir=`agents/main/agent`）
2. `mom` 保持非默认，仅通过精确 `bindings` 命中
3. 增补 `channels.telegram.defaultAccount = “default”`
4. 增补 `channels.feishu.defaultAccount = “mom-feishu”`
5. 重新开启飞书 `typingIndicator = true`（之前排查时关闭，现已恢复正常可开启）

---

## 已完成（2026-03-08）：新增 A股交易专用 Agent ✅

### 目标
创建独立 A股交易 agent，通过专用 Telegram bot 联入。

### 验收结果

| 项目 | 状态 |
|------|------|
| Bot 创建 | ✅ `@openclaw_BigA_winner_bot` |
| Agent 目录 | ✅ `~/.openclaw/agents/ashare/agent/` |
| Workspace | ✅ `~/.openclaw/workspace-ashare/` |
| agents.list | ✅ 新增 `ashare`（bindings=1, isDefault=false） |
| Telegram 账号 | ✅ 新增 `ashare-bot` |
| bindings | ✅ `ashare-bot -> ashare` |
| Gateway health | ✅ 3 个 Telegram bot 全在线 |
| ashare 直接调用 | ✅ 返回 `ASHARE_OK` |

### Bot 信息

| 用途 | Bot Username | Token |
|------|-------------|-------|
| main | @OpenClaw_kevinlasnh_no1_bot | 8224258782:AAGIU5DaAGe0GKT8SHfxM1_04lQRQ0H_Fnk |
| ashare (A股) | @openclaw_BigA_winner_bot | 8651491417:AAFKIInTSXNRmZoDd0bC18Vm2B2GRH-DlRs |
| mom | @openclaw_chunyan_bot | 8620778392:AAGc7klhJp1ivNf4xpagoy1ClCChO6RsNbI |

### 模型配置
所有 agent 继承统一模型配置：
- 主模型：`kimi/k2p5`
- 备用：`zai/glm-5` → `newcli/claude-opus-4-6`

---

## 新任务（2026-03-08）：飞书接入 - 给家人端提供国内聊天方案

### 目标
为 mom agent（妈妈的小龙虾）接入飞书，提供无需翻墙的国内聊天渠道。

### 当前状态

| 项目 | 状态 |
|------|------|
| 飞书插件安装 | ✅ 已完成 |
| 飞书应用创建 | ✅ 已完成（App ID: `cli_a92651d8d7f81bc0`） |
| WebSocket 连接 | ✅ 已建立（机器人名: `mom openclaw`） |
| mom agent exec 权限 | ✅ 已修复并校验（`full`） |
| 飞书事件入站 | ✅ 已确认（日志可见 `received message`） |
| 飞书稳定化参数 | ✅ 已完成（allowlist + 关闭 sender name 解析 + 关闭流式与打字 + 关闭 blockStreaming） |
| 机器人回复测试 | ⏳ 待用户实测 |
| 飞书 contact 权限申请 | 可选（仅在需开启 sender name 解析时需要） |

---

### 平台决策（飞书接入）

**结论：** OpenClaw 官方插件支持飞书，WebSocket 模式无需公网 IP，推荐作为家庭聊天入口。

**对比：**
| 渠道 | 飞书 | WhatsApp | 微信 | WebChat |
|------|------|---------|------|
| 国内可用 | ✅ 直连 | ❌ 需翻墙 | ❌ | ✅ 本地 |
| 家人上手 | 高 | 高 | 中 | 中 |
| 维护复杂度 | 低 | 高 | 低 | 最低 |
| 多端支持 | ✅ 是 | ✅ 是 | ❌ | ❌ |

---

## 待确认/阻塞项

| 事项 | 负责人 | 状态 | 说明 |
|------|------|------|------|
| ~~1. 飞书真实会话回包验收~~ | - | 已废弃 | 飞书通道已删除（2026-03-09 减配） |
| ~~2. contact 权限申请~~ | - | 已废弃 | 飞书通道已删除 |

---

## 架构变更（2026-03-09）：三 Agent → 单 Agent ✅

### 原因
- 多 agent 共享 API key 导致 rate limit 互相竞争
- `morning-briefing` cron 的子 agent 失控耗尽所有 provider 配额
- 用户当前只需个人小龙虾

### 已删除
- **Agents**：mom（family）、ashare
- **Telegram Bots**：chunyan-bot、ashare-bot
- **飞书**：channels.feishu + plugins.entries.feishu（整段删除）
- **目录**：agents/ashare、agents/default、agents/mom、workspace-ashare、workspace-mom
- **Bindings**：仅保留 `main-bot → main`

### 当前架构
```
单 Gateway → 单 Agent (main) → 单 Bot (@OpenClaw_kevinlasnh_no1_bot)
```

### 恢复信息（如需重新启用）
- Bot token 见上方"Bot 信息"表格
- 飞书凭证见 findings.md G 节
- 配置模板见 findings.md X 节

---

### 飞书应用信息

| 配置项 | 值 |
|------|------|
| App ID | `cli_a92651d8d7f81bc0` |
| 机器人名称 | `mom openclaw` |
| 机器人 open_id | `ou_313199180caa7b890a9ccd668293c0e8` |
| WebSocket | ✅ 已连接 |
| 代理 | ✅ `http://127.0.0.1:7897` |
| 模式 | WebSocket 长连接 |

---

### 已配置的 bindings

```json
{
  "bindings": [
    {
      "agentId": "main",
      "match": {
        "channel": "telegram",
        "accountId": "default"
      }
    },
    {
      "agentId": "mom",
      "match": {
        "channel": "telegram",
        "accountId": "chunyan-bot"
      }
    },
    {
      "agentId": "mom",
      "match": {
        "channel": "feishu",
        "accountId": "mom-feishu"
      }
    }
  ]
}
```

---

## 已完成（2026-03-10 上午）：Telegram 长轮询 → Webhook 模式切换 ✅

### 目标
- 彻底消除 Telegram 长轮询的周期性 stall（每 5-18 分钟一次，恢复需 35-66 秒）
- 实现消息秒进（<1 秒延迟）

### 方案选择
综合调研 6 种方案后，选择 **Webhook + Tailscale Funnel**：

| 方案 | 预期延迟 | 复杂度 | 稳定性 |
|------|---------|--------|--------|
| **Webhook + Tailscale Funnel** ✅ | <1s | 低 | 高 |
| AbortSignal.timeout 注入 | ~5-7s | 高 | 中 |
| 缩短 polling timeout 到 5s | ~10-15s | 低 | 低 |
| TCP keepalive | 无改善 | 低 | 无 |
| undici 修复 | 不可行 | 极高 | - |
| 降低 POLL_RESTART_POLICY.maxMs | ~15-20s | 低 | 中 |

### 部署步骤

1. **启用 Tailscale Funnel**
   - 用户在 Tailscale 后台授权 Funnel
   - `sudo tailscale funnel --bg 8787`（main，端口 443）
   - `sudo tailscale funnel --https=8443 --bg 8788`（dayong，端口 8443）

2. **配置 main Gateway Webhook**
   ```json
   {
     "webhookUrl": "https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook",
     "webhookSecret": "<64-hex>",
     "webhookPort": 8787
   }
   ```

3. **配置 dayong Gateway Webhook**
   ```json
   {
     "webhookUrl": "https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook",
     "webhookSecret": "<64-hex>",
     "webhookPort": 8788
   }
   ```

### 验收结果

| 项目 | 状态 |
|------|------|
| Tailscale Funnel 启用 | ✅ 端口 443 + 8443 |
| main Webhook 注册 | ✅ pending=0, error=none |
| dayong Webhook 注册 | ✅ pending=0, error=none |
| main Gateway 运行 | ✅ active (running) |
| dayong Gateway 运行 | ✅ active (running) |
| 用户实测消息速度 | ✅ "回消息很快" |

### 踩坑记录
- **webhookUrl 必须包含路径**：最初配置 `https://...ts.net` 导致 Telegram 返回 404，需改为 `https://...ts.net/telegram-webhook`
- **Funnel 端口限制**：只支持 443、8443、10000 三个端口
- **未来扩展**：chunyan/zenglan 可用端口 10000；超过 3 个 Gateway 需 nginx 路径路由

### 源码补丁状态
- 之前打的 5 个 polling stall 补丁（POLL_STALL_THRESHOLD_MS 90s→35s 等）在 Webhook 模式下不再生效
- 补丁保留不影响运行，升级时可不再重打

---

## 下一步

1. **观察 Webhook 稳定性**：确认长期运行无掉线
2. **可选**：如需部署更多 Gateway（chunyan/zenglan），使用 Funnel 端口 10000 或 nginx 路由
3. **可选**：如需恢复多 agent，参照 findings.md X 节的恢复指南

---

## 新任务（2026-03-09 凌晨）：Telegram 慢回复诊断（已完成首轮排查）

### 目标
- 核实用户反馈的“00:19 发消息，00:20 才回”的真实耗时位置。
- 判断是模型慢、网关慢，还是 Telegram 入站链路慢。
- 在不改配置的前提下给出系统健康结论。

### 首轮结论
- 网关与通道整体健康：`openclaw-gateway active`，`channels status --probe` 显示 Telegram/Feishu 均 `works`。
- 关键样本（`message_id=4197`）已对时：
  - 用户消息元数据时间：`00:19`
  - 进入 main 会话文件时间：`00:20:45`
  - assistant 产出：`00:20:47`
  - Telegram 发出：`00:20:48`
- 结论：该条慢点主要发生在“Telegram 入站到网关之前”，不是模型推理慢。
- 未观察到新的持续性 `409 getUpdates conflict`（仅历史偶发）。

### 当前判断
- 配置健康，故障类型更像“链路抖动/入站延迟”，非“服务挂掉”或“模型故障”。
- 本轮未执行配置修改、未重启服务。

### 下一步（若你要继续追）
1. 固定到单一日本或台湾节点做 10-15 分钟 A/B 测试，对比消息入站延迟。
2. 连续记录 20 条消息的 `Telegram 时间戳 -> 网关入站时间` 差值，确认是否为周期性抖动。
3. 若再次出现单条 >30 秒延迟，同时抓取该分钟 `journalctl` 与 `getWebhookInfo.pending_update_count` 做关联分析。

---

## 已完成（2026-03-09 晚）：Telegram 流量配置优化 ✅

### 目标
- 解决"两条消息一条消失"问题
- 只显示一条完整消息，不要预览+编辑过程

### 修改内容
1. 将 `channels.telegram.accounts.main-bot.streaming` 从 `"block"` 改为 `"off"`
2. 将 `agents.defaults.blockStreamingDefault` 从 `"off"` 改为 `"on"`
3. 保持 `blockStreamingCoalesce` 和 `blockStreamingChunk` 配置

### 验收结果
- ✅ Gateway 重启成功：`active (running)`，Health OK (1545ms)
- ✅ Telegram: ok (@OpenClaw_kevinlasnh_no1_bot)
- ✅ 配置生效：块流式模式下只发送完整消息，无预览编辑

### 当前状态
系统已稳定运行在：
- 单 Agent 架构（main）
- 块流式消息发送
- 无预览，无编辑，无消失现象

---

## 已完成（2026-03-10 早）：24/7 内存稳定性评估 ✅

### 目标
- 判断小龙虾电脑长期开机后，内存是否存在持续暴涨风险。
- 区分“Linux 正常缓存占用”与“OpenClaw 进程真实泄漏”。
- 评估这种风险是否会导致卡顿或不回消息。

### 验收结果

| 项目 | 状态 |
|------|------|
| 读取历史记录（findings/progress/CLAUDE） | ✅ 已完成 |
| 远程主机实时内存检查 | ✅ 已完成 |
| Gateway / 代理进程内存检查 | ✅ 已完成 |
| systemd `MemoryCurrent` / `NRestarts` 检查 | ✅ 已完成 |
| OOM 事件排查 | ✅ 已完成 |
| 结论沉淀到 findings.md / progress.md | ✅ 已完成 |

### 结论
- 当前主机内存状态健康：
  - `Mem used=4.6GiB / 15GiB`
  - `buff/cache=8.8GiB`
  - `available=10GiB`
  - `swap used=0B`
- 当前没有证据表明 OpenClaw 存在持续内存泄漏。
- 历史上更真实的风险仍然是：
  - Telegram 轮询 stall
  - 代理节点抖动
  - provider rate limit

### 后续观察点
1. 继续观察 `available` 是否长期保持充足。
2. 继续观察 `swap` 是否从 `0` 开始持续增长。
3. 若后续某个 Gateway RSS 连续多天单向上升，再评估是否需要 `MemoryMax` 或定时重启。

---

## 已完成（2026-03-10 上午）：联网调研长时间运行内存行为与维护 ✅

### 目标
- 联网核实 Linux/Node/systemd 官方资料，判断长时间运行时内存是否会“自然越开越满”。
- 明确哪些增长是正常缓存，哪些属于真实泄漏或碎片化。
- 形成适合 OpenClaw 笔记本主机的维护策略。

### 验收结果

| 项目 | 状态 |
|------|------|
| Linux 内存缓存 / `MemAvailable` 官方资料核查 | ✅ 已完成 |
| Linux 可回收 file-backed/page cache 官方资料核查 | ✅ 已完成 |
| Node.js 长期运行 RSS 增长 / glibc 碎片化官方资料核查 | ✅ 已完成 |
| Node.js 堆快照 / 内存诊断官方资料核查 | ✅ 已完成 |
| systemd `MemoryHigh` / `MemoryMax` 官方资料核查 | ✅ 已完成 |
| systemd-oomd 与 swap 官方资料核查 | ✅ 已完成 |
| 远程主机当前能力（cgroup v2 / oomd / MemoryAccounting）核查 | ✅ 已完成 |
| 维护建议沉淀到 findings.md / progress.md | ✅ 已完成 |

### 结论
- **不会因为“只是开机很久”就必然把内存越堆越满。**
- Linux 会主动拿空闲内存做缓存；只看 `used` 容易误判，关键要看 `MemAvailable`、swap、单进程 RSS/`MemoryCurrent` 是否持续单向上升。
- 长时间运行后内存上涨，常见来源不是“电脑自然坏掉”，而是：
  - 某个常驻进程真实泄漏
  - allocator / glibc 碎片化导致 RSS 偏高
  - 桌面环境、浏览器、监控工具长期驻留
- 对 OpenClaw 这台机器，维护优先级应是：
  1. 监控 `available` / swap / Gateway RSS
  2. 保持 swap 可用
  3. 必要时给 Gateway 加 `MemoryHigh` / `MemoryMax`
  4. 若机器专用化运行，尽量减少 GUI 常驻进程

### 后续可执行动作
1. 低风险方案：先连续观察 7-14 天内存趋势，再决定是否加硬限制。
2. 中风险方案：给 `openclaw-gateway.service` 和 `openclaw-gateway-dayong.service` 增加 `MemoryHigh` / `MemoryMax`。
3. 专用机优化：如仅做 24/7 小龙虾，可考虑减少桌面进程常驻，进一步降低长期内存噪声。

---

## 已完成（2026-03-10 上午）：Telegram Polling Stall 深度排查 + 源码补丁 ✅

### 目标
- 排查 Telegram 轮询每隔 ~9 分钟 stall 一次的根因
- 验证多 Gateway 独立性
- 改善消息拉取延迟

### 验收结果

| 项目 | 状态 |
|------|------|
| 多 Gateway 独立性验证（重启 dayong 不影响 main） | ✅ 已确认 |
| Tailscale SSH ACL 优化（去除浏览器认证） | ✅ 已完成 |
| Polling stall 联网深度调研 | ✅ 已完成 |
| mihomo keep-alive 配置 | ✅ 已应用（部分改善） |
| 源码补丁降低 stall 检测阈值 | ✅ 已应用（90s→35s） |
| 恢复时间从 2-3 分钟降到 ~40 秒 | ✅ 用户确认体验改善 |

### 修改内容
1. mihomo 配置添加 `keep-alive-interval: 15`、`keep-alive-idle: 15`、`tcp-concurrent: true`
2. OpenClaw 源码补丁：`POLL_STALL_THRESHOLD_MS` 90s→35s、`POLL_WATCHDOG_INTERVAL_MS` 30s→5s（5 个文件）
3. Tailscale SSH ACL：`action: "check"` → `action: "accept"`

### 已知限制
- stall 本身仍在发生（代理连接静默断开），只是检测和恢复更快
- 源码补丁在 OpenClaw 升级后会被覆盖，需重新打
- 根本修复需要 OpenClaw 官方给 getUpdates 加客户端 HTTP 超时（AbortSignal.timeout）

### 后续可选
1. 向 OpenClaw 提 PR：给 getUpdates fetch 加 `AbortSignal.timeout((timeout + 5) * 1000)`
2. 评估 Webhook 模式彻底消除长轮询

---

## 已完成（2026-03-10 上午）：重启后 SSH 救援链路恢复核查 ✅

### 目标
- 确认这台专用小龙虾主机在意外重启后，仍能自动恢复到“可通过 Tailscale + SSH 回连救援”的状态。
- 核查 Tailscale、SSH、用户级服务是否都具备开机自恢复条件。

### 验收结果

| 项目 | 状态 |
|------|------|
| `tailscaled` 开机自启 | ✅ `enabled` |
| `tailscaled` 当前运行 | ✅ `active` |
| SSH 服务开机自启 | ✅ `enabled` |
| SSH 服务当前运行 | ✅ `active` |
| `loginctl` 用户 linger | ✅ `yes` |
| Tailscale 状态文件持久化 | ✅ `/var/lib/tailscale/tailscaled.state` 存在 |
| 当前 Tailnet 连接状态 | ✅ `BackendState=Running` |
| 用户级 `openclaw-gateway` / `mihomo` 开机恢复条件 | ✅ 均为 `enabled + active` |

### 结论
- 当前配置已经满足“系统重启后，Tailscale 和 SSH 自动恢复，用户可重新 SSH 回来救援”的要求。
- 目前**不需要额外补配置**来实现这件事。

### 唯一需记住的长期事项
1. 该项已于 `2026-03-10` 由用户在 Tailscale 后台执行 `Disable key expiry`。
2. 复核结果：`openclaw-24x7` 的 `tailscale status --json` 中，`Self` 节点已不再返回 `KeyExpiry` 字段。
3. 当前这台机器的远程救援链路已经满足“长期无人值守”要求。

---

## 已完成（2026-03-10 上午）：Tool 执行消息可见性配置 ✅

### 目标
让小龙虾在执行工具时向用户发送消息（如 "🔎 Web Search: query=xxx"），而不是只显示"正在输入"。

### 验收结果

| 项目 | 状态 |
|------|------|
| 源码分析（verboseDefault 机制） | ✅ 已完成 |
| 联网确认（GitHub Issue #17351） | ✅ 已确认 |
| 配置变更（verboseDefault: "on"） | ✅ 已应用 |
| Gateway 重启 | ✅ active (running) |

### 修改内容
1. 在 `~/.openclaw/openclaw.json` 的 `agents.defaults` 中添加 `"verboseDefault": "on"`
2. 重启 Gateway 生效

### 配置说明
- `"off"`（默认）：只显示 typing 指示器
- `"on"`（当前）：发送 tool 执行摘要消息
- `"full"`：发送摘要 + 完整输出
- 用户可在 Telegram 中用 `/verbose off|on|full` 按会话切换

---

## 进行中（2026-03-10 上午）：Dayong 小龙虾工具执行异常排查

### 目标
- 查清为什么 `dayong` 小龙虾在 Kimi 模型下经常“说自己执行了工具”，但实际没有真正执行。
- 在**不切换出 Kimi** 的前提下，找出可行修法。

### 当前发现

| 项目 | 状态 |
|------|------|
| 主 Gateway / Dayong Gateway 工具权限对比 | ✅ 已完成 |
| `tools.exec.security` 差异排查 | ✅ 无差异，均为 `full` |
| 会话记录对比（是否真实产生 `toolCall`） | ✅ 已完成 |
| CLI 直接复现 `pwd` 工具调用 | ✅ 已完成 |
| 根因初判 | ✅ 已完成 |
| 不切模型的修法验证 | ⏳ 继续中 |

### 当前结论
- 问题**不是**权限字段没开。
- `main` 用同类指令会产生真实 `toolCall` 并执行。
- `dayong` 在当前 `kimi/k2p5` 接入链路下，会把工具调用输出成普通文本，例如：
  - `/exec({"command": "pwd"})`
- 这意味着模型“想调用工具”，但没有按 OpenClaw 需要的结构化格式发出工具调用，因此执行层根本没跑起来。

### 已做的低风险处理
1. 已给 `~/.openclaw-dayong/workspace/AGENTS.md` 增加“禁止假装执行工具”的提示词护栏。
2. 该护栏对新会话更有意义；现有旧 session 可能仍沿用旧上下文。

### 下一步候选
1. 验证如何让 `dayong` 新 session 读取新护栏并至少不再假装执行。
2. 继续研究不换模型的真正修法：
   - 让官方 `kimi-coding` provider 可用
   - 或补一层兼容，把 `/exec({...})` 这类伪工具文本转成真实工具调用

### 实时配置扫描补充（2026-03-10 11:25 CST）

| 项目 | `main` | `dayong` | 结论 |
|------|--------|----------|------|
| systemd 服务状态 | `active` | `active` | 不是服务没跑 |
| `tools.exec.security` | `full` | `full` | 不是权限没开 |
| sandbox | `off` | `off` | 不是沙箱拦截 |
| 默认主模型 | `minimax/MiniMax-M2.5` | `kimi/k2p5` | 当前 live 模型本来就不同 |
| tools 列表 | 25 个 | 25 个 | 不是“没有工具” |
| system prompt 体量 | `48966 chars` | `15555 chars` | `dayong` 上下文明显更薄 |
| project context | `29299 chars` | `2879 chars` | `dayong` 项目上下文只有 `main` 的约 1/10 |
| skills 注入 | 21 个 | 4 个 | `dayong` 缺少大量脚手架 |

### 更新判断
- `dayong` 当前问题，已经不能简单归因到“Kimi 本身不支持工具”。
- 更接近的真实情况是三层叠加：
  1. `dayong` 当前运行时上下文明显比 `main` 薄很多；
  2. `dayong` 当前 session 仍像在使用旧的 workspace 提示快照；
  3. 在这套较薄上下文下，`kimi/k2p5` 更容易把工具调用吐成普通文本，而不是结构化 `toolCall`。
- `pwd` 这类命令会出现假阳性，因为模型能从 prompt 里的 `workspaceDir` 猜出答案；真正能区分真工具调用的是随机 UUID 这类不可猜命令。
- 经实时测试：
  - `main` 执行 `cat /proc/sys/kernel/random/uuid` 时产生真实 `toolCall`；
  - `dayong` 同题仍返回 `/exec({"command": "cat /proc/sys/kernel/random/uuid"})`，说明问题依旧存在。

### 全面调研补充（2026-03-10 11:45 CST）

#### “灵魂”和“能力脚手架”必须分开看
- OpenClaw 源码明确把 `SOUL.md` 当作 **persona / tone**：
  - `If SOUL.md is present, embody its persona and tone.`
- 但 `AGENTS.md`、`TOOLS.md`、`USER.md`、`MEMORY.md`、workspace `skills/` 都会进入 `Project Context` 或 `Skills` prompt，属于**能力脚手架**，不是单纯人设。

#### 当前最关键的非人格差异

| 项目 | `main` | `dayong` | 影响 |
|------|--------|----------|------|
| live 默认模型 | `MiniMax-M2.5` | `kimi/k2p5` | 当前实际就不是同模型 |
| fallback 链 | `kimi -> zai -> newcli` | 无 | `dayong` 稳定性更差 |
| ready skills | `22/70` | `6/54` | 能力面明显更窄 |
| managed skills (`~/.openclaw*/skills`) | 8 | 0 | `dayong` 少了规划/自改进类脚手架 |
| workspace skills (`workspace/skills`) | 18 | 0 | `dayong` 缺少一整套任务能力 |
| project agents skills (`workspace/.agents/skills`) | 1 | 0 | `dayong` 少一层项目技能 |
| `MEMORY.md` | 有 | 无 | `dayong` 缺长期记忆载体 |
| `workspace/memory/` | 有 | 无 | `dayong` 缺日记/记忆积累 |
| state memory DB | `~/.openclaw/memory/main.sqlite` | 无 | `dayong` 缺 memory 检索积累 |

#### 对用户问题的直接回答
- **可以不用同一个 `SOUL.md`。**
- 但如果连 `AGENTS.md` 的工作流、`TOOLS.md` 的环境知识、`MEMORY.md`/`memory/` 的记忆层、以及 `skills/` 这些能力脚手架都不补齐，那“聪明程度应该一样”这件事在工程上就不成立。
- 现在 `dayong` 的问题不是“人格不同”，而是**底层能力仓库、任务脚手架、可调用技能和记忆层本来就少了很多**。

### 下一步最小改造方向
1. 保留 `dayong` 自己的 `SOUL.md` / `IDENTITY.md` / `USER.md`，不复制人设。
2. 但补齐一套**非人格能力层**：
   - richer `AGENTS.md`
   - 环境化 `TOOLS.md`
   - `MEMORY.md` + `workspace/memory/`
   - `managed skills` / `workspace skills`
3. 变更后开启新 session 再验证 `Kimi` 的工具调用质量。
