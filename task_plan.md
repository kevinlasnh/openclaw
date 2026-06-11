# Task Plan: 多小龙虾量化交易系统架构升级

## 新任务（2026-06-08 16:12 +08:00）：升级 OpenClaw 到 2026.6.1 并确认四 Gateway 上线

### 目标
- 将远端 OpenClaw 从 `2026.5.22` 升级到 npm latest（用户提示 latest 为 `2026.6.1`，执行前以 npm registry 实测为准）。
- 升级后确认四个 Gateway 全部重新上线：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 验收不仅看 service active，还要确认 config、gateway health、Telegram / Feishu 通道、session lock、近期红旗日志和所有 configured agents 不投递 smoke。

### Phase 1: 上下文恢复与只读巡检
- **Status:** complete
- 已读取 PWF 近期记录和 `openclaw-server-health` Skill。
- 已查 ByteRover，本主题未找到已沉淀长期记忆；以 PWF 历史记录和远端 live 状态为准。
- 已识别上次 2026.5.22 升级风险：
  - 非交互 SSH 需设置 `PNPM_HOME=$HOME/.local/share/pnpm`。
  - pnpm global shim 可能卡住或丢失。
  - 外部 Feishu / Brave 插件 runtime 可能在升级后漂移。
- 已运行升级前标准只读巡检：
  - 当前 OpenClaw：`2026.5.22 (a374c3a)`
  - npm latest：`2026.6.1`
  - 四个 Gateway 均 `active/running`
  - 四套配置均 valid，health 基线均 `ok=true`
  - Mihomo `127.0.0.1:7897` 到 `generate_204` 返回 `204`

### Phase 2: 备份与升级前确认
- **Status:** complete
- 已备份四个实例关键配置、env、插件 registry 和当前 CLI/shim 状态到：
  - `/home/kevinlasnh/.openclaw-backups/pre-openclaw-20260601-upgrade-20260608-161549`

### Phase 3: 执行 OpenClaw latest 升级
- **Status:** complete
- 已执行：
  - `openclaw update --tag latest --yes --no-restart`
- 升级结果：
  - Before: `2026.5.22`
  - After: `2026.6.1`
  - 当前 CLI: `OpenClaw 2026.6.1 (2e08f0f)`
- 本轮未复发 pnpm global shim 卡住：
  - `~/.local/share/pnpm/openclaw` 存在
  - `~/.local/share/pnpm/global/5/node_modules/openclaw -> ../.pnpm/openclaw@2026.6.1/node_modules/openclaw`
- `openclaw update` 自动更新 main 的 `@openclaw/brave-plugin`。

### Phase 4: 四 Gateway 重启与健康验收
- **Status:** complete
- 已重启四个 Gateway：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 四个服务均 `active/running`，`NRestarts=0`。
- 四套配置均 `Config valid`。
- 四个 `gateway health` 均 `ok=true`：
  - main: Telegram `running=true / lastError=null`
  - dayong: Feishu `running=true / lastError=null`
  - chunyan: Feishu `running=true / lastError=null`
  - zenglan: Feishu `running=true / lastError=null`
- 四个实例 session lock 均为 `0`。
- 重启后红旗日志为空。
- 代理回归：`curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` 返回 `204`。
- 备注：重启瞬间旧 2026.5.22 进程记录了 shutdown error（旧安装树模块已被替换），新 2026.6.1 进程启动后 health 正常，不作为阻断。

### Phase 5: 全 Agent smoke test 与 PWF 收尾
- **Status:** complete
- 全部 configured agents 不投递 smoke test 通过：
  - `main/main` -> `MAIN_20260601_OK`，`deepseek/deepseek-v4-pro`
  - `dayong/market` -> `DAYONG_MARKET_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/sector` -> `DAYONG_SECTOR_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/stock` -> `DAYONG_STOCK_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/strategy` -> `DAYONG_STRATEGY_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/breakboard` -> `DAYONG_BREAKBOARD_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/douzhuan` -> `DAYONG_DOUZHUAN_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/volume15` -> `DAYONG_VOLUME15_20260601_OK`，`zzedu/gpt-5.5`
  - `dayong/volume35` -> `DAYONG_VOLUME35_20260601_OK`，`zzedu/gpt-5.5`
  - `chunyan/chunyan` -> `CHUNYAN_20260601_OK`，`zzedu/gpt-5.5`
  - `chunyan/dzxy` -> `CHUNYAN_DZXY_20260601_OK`，`zzedu/gpt-5.5`
  - `zenglan/zenglan` -> `ZENGLAN_20260601_OK`，`zzedu/gpt-5.5`
  - `zenglan/gre-tutor` -> `GRE_TUTOR_20260601_OK`，`zzedu/gpt-5.5`

## 新任务（2026-06-08 15:53 +08:00）：chunyan / zenglan 对齐 dayong GPT 5.5Base

### 目标
- 只修改 `chunyan` 与 `zenglan` 两个 Gateway。
- 不修改 `main` / 自己的小龙虾 Gateway。
- 将两个 Gateway 的文本 primary model、provider URL、模型代号对齐 `dayong` 当前 live 配置：
  - `zzedu/gpt-5.5`
  - `https://api.zzedu.org/v1`
- 将默认参数设置为：
  - `thinkingDefault = xhigh`（extra high）
  - `reasoningDefault = off`
  - `verboseDefault = on`

### Phase 1: 上下文恢复与只读盘点
- **Status:** complete
- 已加载 `planning-with-files` 与 `openclaw-server-health`。
- ByteRover 未找到本主题长期记忆，后续以远端 live 配置为准。
- 标准只读巡检显示 OpenClaw `2026.5.22`，四个 Gateway 均在线。
- 已确认 `dayong` 当前 live 配置：
  - provider: `zzedu`
  - primary: `zzedu/gpt-5.5`
  - baseUrl: `https://api.zzedu.org/v1`
  - `thinkingDefault = xhigh`
  - `reasoningDefault = off`
  - `verboseDefault = on`

### Phase 2: 备份并修改 chunyan / zenglan 配置
- **Status:** complete
- 已备份两个目标实例到：
  - `/home/kevinlasnh/.openclaw-backups/chunyan-zenglan-zzedu-gpt55-20260608-155454`
- 已从 `dayong` 复制：
  - `models.providers.zzedu`
  - `.env` 中的 `ZZEDU_API_KEY`
- 已修改：
  - `~/.openclaw-chunyan/openclaw.json`
  - `~/.openclaw-chunyan/.env`
  - `~/.openclaw-zenglan/openclaw.json`
  - `~/.openclaw-zenglan/.env`
- 两个目标当前 defaults 均为：
  - primary: `zzedu/gpt-5.5`
  - fallback: none
  - `thinkingDefault = xhigh`
  - `reasoningDefault = off`
  - `verboseDefault = on`

### Phase 3: 校验、重启与验收
- **Status:** complete
- 两套 `openclaw config validate` 均通过。
- 已只重启：
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 未重启 / 未修改：
  - `openclaw-gateway`（main）
  - `openclaw-gateway-dayong`
- 两个目标服务均 `active/running`，`NRestarts=0`。
- 两个目标 `gateway health ok=true`，Feishu `running=true / lastError=null`。
- 两个目标 session lock 均为空。
- 不投递 smoke test：
  - `chunyan/chunyan` -> `CHUNYAN_GPT55_XHIGH_OK`，`provider=zzedu`，`model=gpt-5.5`
  - `chunyan/dzxy` -> `CHUNYAN_DZXY_GPT55_XHIGH_OK`，`provider=zzedu`，`model=gpt-5.5`
  - `zenglan/zenglan` -> `ZENGLAN_GPT55_XHIGH_OK`，`provider=zzedu`，`model=gpt-5.5`
  - `zenglan/gre-tutor` -> `GRE_TUTOR_GPT55_XHIGH_OK`，`provider=zzedu`，`model=gpt-5.5`
- 说明：配置层 `thinkingDefault=xhigh` 与 dayong 一致；OpenClaw 2026.5.22 对 `zzedu/gpt-5.5` 的 runtime `requestShaping.thinking` 报告为 `high`，dayong 对照 smoke 也是同样表现。

## 新任务（2026-05-24 20:08 +08:00）：main 切 DeepSeek V4 Pro 并升级 OpenClaw latest

### 目标
- 将 main / 自己的小龙虾默认文本模型切换为 `deepseek/deepseek-v4-pro`。
- 将 Xiaomi MiMo V2.5 Pro 保留为 default fallback / 备用模型入口。
- 保持 `thinkingDefault = high`、`reasoningDefault = off`、`verboseDefault = on`，其他配置尽量不动。
- 升级远端 OpenClaw 到 npm 当前最新版本。
- 升级后确认四个 Gateway 全部上线，且所有 configured agents 可活动。

### Phase 1: 上下文恢复与现场盘点
- **Status:** complete
- 已读取 PWF 三件套、本仓规则、`openclaw-server-health` Skill 与 runbook。
- 已运行标准只读巡检。
- 当前远端版本：`OpenClaw 2026.5.3 (06d46f7)`。
- npm 当前 latest：`2026.5.22`。
- main 当前配置为 `xiaomi-mimo/mimo-v2.5-pro -> deepseek/deepseek-v4-pro`，thinking 默认 high。

### Phase 2: main 模型默认顺序切换
- **Status:** complete
- 已备份并修改 main `~/.openclaw/openclaw.json`。
- 当前文本模型顺序：
  - primary: `deepseek/deepseek-v4-pro`
  - fallback: `xiaomi-mimo/mimo-v2.5-pro`
- 保持：
  - imageModel: `xiaomi-mimo/mimo-v2.5`
  - `thinkingDefault = high`
  - `reasoningDefault = off`
  - `verboseDefault = on`
- `openclaw config validate` 与 `models status` 均通过。

### Phase 3: OpenClaw 升级到 latest
- **Status:** complete
- npm latest 确认为 `2026.5.22`。
- 已将远端 CLI 从 `OpenClaw 2026.5.3 (06d46f7)` 升级到 `OpenClaw 2026.5.22 (a374c3a)`。
- 升级过程遇到 pnpm global shim 卡住，已终止卡住进程并修复：
  - `~/.local/share/pnpm/openclaw`
  - `~/.local/share/pnpm/global/5/node_modules/openclaw -> ../.pnpm/openclaw@2026.5.22/node_modules/openclaw`
- 升级后四套 `openclaw config validate` 均通过。

### Phase 4: 四 Gateway 重启与活动性验收
- **Status:** complete
- 已重启：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 首轮发现 dayong 启动为 `0 plugins`；根因是 `@openclaw/feishu` 与 `@openclaw/brave-plugin` 仍为 `2026.5.2`，缺 compiled runtime。
- 已只修 dayong：
  - 安装并 pin `@openclaw/feishu@2026.5.3`
  - 安装并 pin `@openclaw/brave-plugin@2026.5.3`
  - 刷新插件 registry
  - 重启 `openclaw-gateway-dayong`
- 最终四个 Gateway：
  - services 均 `active/running`
  - configs 均 valid
  - gateway health 均 `ok=true`
  - main Telegram running/connected
  - dayong/chunyan/zenglan Feishu running/probe ok
  - 近期红旗日志为空
  - session lock 为空
- 全部 configured agents 不投递 smoke test 通过：
  - main/main: `MAIN_DEEPSEEK_20260524_OK`，`provider=deepseek`，`model=deepseek-v4-pro`
  - dayong 8 个 agents: `provider=zzedu`，`model=gpt-5.5`
  - chunyan/chunyan: `provider=zai`，`model=glm-5`
  - zenglan/zenglan 与 zenglan/gre-tutor: `provider=zai`，`model=glm-5`

### Phase 5: 记录进度与收尾
- **Status:** complete
- 已更新 `progress.md` 与 `findings.md`。

## 新任务（2026-05-06 11:37 +08:00）：GTD 09:00 Telegram 投递失败深查

### 目标
- 恢复此前中断的 Telegram 09:00 GTD Inbox reminder 失败排查。
- 判断今天 2026-05-06 09:00 失败到底发生在 cron、模型、OpenClaw delivery、Telegram API 还是 Mihomo 代理层。
- 给出为什么 09:00 容易失败、13:00 / 19:00 正常的证据化解释。

### Phase 1: 恢复上下文与标准巡检
- **Status:** complete
- 已读取 PWF 三件套、本仓规则与 `openclaw-server-health` Skill。
- 已运行标准只读巡检：
  - 当前 Tailscale / Funnel / Mihomo / main Gateway 在线。
  - 当前 Telegram health 正常。

### Phase 2: 09:00 cron 与模型执行核查
- **Status:** complete
- 已确认 `gtd-inbox-reminder-0900` 在 2026-05-06 09:00 准点触发。
- 已确认 session `bbbf8726-aa78-4e50-83c2-65eb3b21a3c5` 中模型成功生成正确提醒文本。
- 已确认 cron 状态为 `lastRunStatus=ok`，但 `lastDelivered=false / lastDeliveryStatus=not-delivered`。

### Phase 3: Gateway delivery 与 Mihomo 代理核查
- **Status:** complete
- Gateway 09:00:17 记录 Telegram `sendMessage` 失败。
- Mihomo 同一窗口记录 `telegram-jp-tw-stable[专线2.5x-台湾1-GPT]` 到 `api.telegram.org:443` 建连失败：
  - `dial tcp 112.90.88.2:30021: i/o timeout`
- 2026-05-04 09:00 也有同节点同类 timeout；13:00 / 19:00 正常窗口无同类失败。

### Phase 4: 结论与建议
- **Status:** complete
- 结论：今天失败不在 GTD cron / prompt / 模型，而在 Telegram delivery 经 Mihomo 代理的出站链路。
- 建议：关键提醒增加延迟补偿 job，或调整 `telegram-jp-tw-stable` 节点顺序/策略，或取消 `bestEffort` 并配置失败告警。
- 本轮只读排查远端，未修改远端配置，未重启 Gateway。

## 新任务（2026-05-06 09:32 +08:00）：main 新 session Thinking 默认值排查

### 目标
- 暂停 9 点 Telegram 投递失败排查。
- 查明为什么 main Telegram 会话新一天第一句后 new session 的 `Thinking` 回到 `off`。
- 确认可否设置默认 `thinking high`、`reasoning off`、`verbose on`。

### Phase 1: 配置、session store 与源码核查
- **Status:** complete
- 已确认 live main 当前：
  - `agents.defaults.thinkingDefault = "off"`
  - `agents.defaults.verboseDefault = "on"`
  - `agents.defaults.reasoningDefault` 未显式设置
- 已确认 OpenClaw daily reset 默认 04:00 后的第一条真实消息会创建新 `sessionId`。
- 已确认 2026-05-06 07:33 的 Telegram DM 新 session 初始记录 `thinking_level_change = off`。
- 已确认当前 Telegram DM store 后来被用户调成 `thinkingLevel = "high"`、`reasoningLevel = "off"`。
- 已确认拟议配置 `thinkingDefault=high / reasoningDefault=off / verboseDefault=on` 在同目录临时配置中 `openclaw config validate` 通过。
- 本轮未修改 live 配置，未重启 Gateway。

### Phase 2: 上线默认参数并验证
- **Status:** complete
- 已备份：
  - `/home/kevinlasnh/.openclaw-backups/main-thinking-defaults-20260506-093447/openclaw.json`
- 已写入 main live：
  - `agents.defaults.thinkingDefault = "high"`
  - `agents.defaults.reasoningDefault = "off"`
  - `agents.defaults.verboseDefault = "on"`
- 已重启 main Gateway：
  - PID `2215560`
- 已验收：
  - `openclaw config validate` 通过。
  - `gateway health ok=true`，Telegram `running=true / connected=true / lastError=null`。
  - 新 session smoke 返回 `THINKING_DEFAULT_HIGH_OK`。
  - `requestShaping.thinking = "high"`，`requestShaping.verbose = "on"`。
  - transcript 记录 `thinking_level_change = "high"`。

## 新任务（2026-05-06 09:47 +08:00）：另外三个 Gateway 默认 thinking/reasoning/verbose 上线

### 目标
- 将 dayong、chunyan、zenglan 三个 Gateway 下所有 Agent 的默认设置统一为：
  - `thinkingDefault = high`
  - `reasoningDefault = off`
  - `verboseDefault = on`
- 重启三个 Gateway 并验证所有 Agent。

### Phase 1: 修改三套默认值并重启
- **Status:** complete
- 已备份：
  - `/home/kevinlasnh/.openclaw-backups/other-gateways-thinking-defaults-20260506-093739`
- 已修改：
  - `~/.openclaw-dayong/openclaw.json`
  - `~/.openclaw-chunyan/openclaw.json`
  - `~/.openclaw-zenglan/openclaw.json`
- 三套 defaults 均为：
  - `thinkingDefault = "high"`
  - `reasoningDefault = "off"`
  - `verboseDefault = "on"`
- 三套 `openclaw config validate` 均通过。
- 已重启：
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`

### Phase 2: 全 Agent 实呼验证
- **Status:** complete
- 10 个 configured agents 全部不投递 smoke test 通过：
  - `dayong/market`
  - `dayong/sector`
  - `dayong/stock`
  - `dayong/strategy`
  - `dayong/breakboard`
  - `dayong/douzhuan`
  - `dayong/volume15`
  - `dayong/volume35`
  - `chunyan/chunyan`
  - `zenglan/zenglan`
- 每个新 session 均显示：
  - `requestShaping.thinking = "high"`
  - `requestShaping.verbose = "on"`
  - `fallbackUsed = false`

### Phase 3: zenglan Feishu/Brave 插件漂移修复
- **Status:** complete
- 额外发现 zenglan Agent 可跑通，但初始 `channels status --probe` 返回 `channels={}`。
- 根因：
  - Feishu plugin install/runtime record 缺失。
  - 旧 Brave plugin 2026.5.2 runtime 缺失/入口为 TypeScript，导致 `tools.web.search.provider=brave` 校验阻断插件安装。
- 已备份：
  - `/home/kevinlasnh/.openclaw-backups/zenglan-feishu-plugin-fix-20260506-094302`
  - `/home/kevinlasnh/.openclaw-backups/zenglan-brave-feishu-repair-20260506-094513`
- 已修复：
  - 临时移除 zenglan `tools.web.search.provider`。
  - 安装并 pin `@openclaw/brave-plugin@2026.5.3`。
  - 恢复 `tools.web.search.provider = "brave"`。
  - 确认 `@openclaw/feishu@2026.5.3` loaded。
  - 重启 `openclaw-gateway-zenglan`。
- 最终 zenglan 验收：
  - service `active/running`，PID `2217681`。
  - `gateway health ok=true`。
  - `channels.feishu.running=true / lastError=null`。
  - `channels status --probe` 返回 `botName=zenglan`。
  - final smoke 返回 `ZENGLAN_FINAL_THINKING_DEFAULT_OK`。

## 新任务（2026-05-05 13:59 +08:00）：修复两个上游 OpenClaw PR 冲突

### 目标
- 检查昨天提交的两个上游 PR 是否仍有 conflict。
- 将两个 PR 分支 rebase 到最新 `upstream/main`，解决冲突并推送。
- 确认 GitHub 端 PR 进入可合并状态。

### Phase 1: Telegram PR rebase、测试与推送
- **Status:** complete
- PR：`openclaw/openclaw#77211`
- 分支：`fix/telegram-default-tool-progress`
- 已先 rebase 到 `b4ff3aa73b` 并解决 `extensions/telegram/src/bot-message-dispatch.ts` 冲突；随后上游继续前进，又 rebase 到最新 `upstream/main` `a17d4371d1`。
- 冲突处理保留：
  - 上游 `deleteIfUnused: !answerLaneHasAssistantContent`
  - 本 PR 的 `visibleSinceMs` 与 `wasPreviewPushedUpByVisibleDelivery()` 防护
- 最终 head：`60a4996d618b802e64e18d2ca8607759a54f808d`
- 已推送：`git push --force-with-lease origin fix/telegram-default-tool-progress`
- GitHub 最终状态：`mergeable=MERGEABLE`，`mergeStateStatus=CLEAN`

### Phase 2: Brave PR rebase、测试与推送
- **Status:** complete
- PR：`openclaw/openclaw#77219`
- 分支：`fix/brave-configured-plugin-runtime-repair`
- 已 rebase 到最新 `upstream/main` `a17d4371d1`，本轮无新增冲突。
- 保留昨天合并后的 doctor repair 逻辑：
  - 兼容上游 current bundled plugin index
  - 识别 broken runtime entry diagnostics
  - configured plugin 且 persisted install record 存在但 runtime entry broken 时触发 `updateNpmInstalledPlugins`
  - `isInstalledRecordMissingOnDisk` 同时支持 `installPath` 与 `sourcePath`
- 最终 head：`ff12c3e9f064aa595028f3bf015328b8d9240fd0`
- 已推送：`git push --force-with-lease origin fix/brave-configured-plugin-runtime-repair`
- GitHub 最终状态：`mergeable=MERGEABLE`，`mergeStateStatus=CLEAN`

### Phase 3: GitHub proof gate 与最终复查
- **Status:** complete
- 两个 PR 均补充 `Real behavior proof` section。
- `Real behavior proof` 新一轮检查均已通过。
- 两个 PR 当前无 conflict，GitHub 端均为 CLEAN。

## 新任务（2026-05-05 13:27 +08:00）：春燕 Feishu 通道死亡排查与修复

### 目标
- 检查春燕反馈“小龙虾还是死的”的真实故障层。
- 若是春燕实例自身问题，优先只修 `openclaw-gateway-chunyan`，不改 main/dayong/zenglan。

### Phase 1: 定位、修复与验收
- **Status:** complete
- 根因定位：`openclaw-gateway-chunyan` 进程和 `chunyan/chunyan` agent 模型链路正常，但 Feishu 插件没有被 registry 发现，导致 `gateway health` / `channels status --probe` 均显示 `channels={}`。
- 关键证据：`plugins.entries.feishu: plugin not found: feishu`，且 `~/.openclaw-chunyan/plugins/installs.json` 只有 `brave` install record，没有 `feishu` install record。
- 已备份：
  - `/home/kevinlasnh/.openclaw-backups/chunyan-feishu-plugin-fix-20260505-133115`
  - `/home/kevinlasnh/.openclaw-backups/chunyan-plugin-policy-cleanup-20260505-133514`
- 已修复：
  - 通过 `openclaw plugins install --force --pin --dangerously-force-unsafe-install @openclaw/feishu@2026.5.3` 重建 Feishu install record。
  - 将春燕 `plugins.allow` 收敛为 `["feishu","zai","minimax"]`。
  - 移除 disabled 且 stale 的 `plugins.entries.brave`。
  - 只重启 `openclaw-gateway-chunyan`。
- 最终验收：
  - service `active/running`，PID `2207101`，`NRestarts=0`。
  - `openclaw config validate` 通过。
  - `gateway health ok=true`，`channels.feishu.running=true`，`lastError=null`。
  - `channels status --probe` 返回 `botName=chunyan`、`botOpenId=ou_313199180caa7b890a9ccd668293c0e8`。
  - 日志出现 `WebSocket client started` 与 `ws client ready`。
  - 不投递 smoke test 返回 `CHUNYAN_FINAL_OK`，provider/model 为 `zai/glm-5`。
  - session locks 为 `0`。

## 新任务（2026-05-05 10:45 +08:00）：GTD AGENTS.md 与 Skill 分工确认

### 目标
- 确认小龙虾 workspace `AGENTS.md` 是否只保留 GTD 核心执行逻辑。
- 确认具体 GTD 流程是否已经封装到 Skill，且不存在有害冗余。

### Phase 1: 分工判断与记录
- **Status:** complete
- 已确认 `AGENTS.md` 保留 GTD 核心合同、路由、权限和安全边界。
- 已确认具体流程已封装到 `gtd-inbox-triage`、`gtd-daily-review`、`gtd-weekly-review`、`gtd-natural-planning`。
- 已确认少量重复安全规则是必要 guardrail，不属于有害冗余。
- 本轮没有修改远端配置，没有重启 Gateway。

## 新任务（2026-05-05 10:40 +08:00）：另外三个 Gateway 活性复查

### 目标
- 检查除 main 外的 `dayong`、`chunyan`、`zenglan` 三个 Gateway 下的小龙虾是否都还活着。
- 只读优先，不修改配置、不重启服务。

### Phase 1: 巡检与不投递实呼
- **Status:** complete
- 已运行标准 `openclaw-server-health` 只读巡检。
- 三个 Gateway focused 检查均通过：
  - service `active/running`
  - `NRestarts=0`
  - `openclaw config validate` 通过
  - `gateway health ok=True`
  - `plugin_errors=0`
  - session locks：`0`
- 全部 configured agents 不投递 smoke test 通过：
  - dayong 8 个 agents
  - chunyan 1 个 agent
  - zenglan 1 个 agent
- 本轮未修改远端配置，未重启服务。

## 新任务（2026-05-05 10:34 +08:00）：再次使用 `openclaw-gtd-health` 复查 GTD 闭环

### 目标
- 再次使用 `openclaw-gtd-health` Skill 检查 main 小龙虾 GTD Agent 核心系统、核心逻辑和脚手架。
- 如发现 GTD 逻辑谬误或闭环缺口，直接修复并验证。

### Phase 1: 巡检、语义复核与记录
- **Status:** complete
- 默认 GTD health 巡检：`STATUS=clean`、`issue_count=0`。
- `-IncludeTodoistScaffold` 巡检：`STATUS=clean`、`issue_count=0`，只检查 project / label / filter scaffold。
- 人工复核 live `AGENTS.md` 与四个 GTD Skill 后，未发现新的 GTD 逻辑问题。
- Natural Planning 触发式 smoke test 通过：`status=ok`、`natural_skill_visible=True`、`tools=read`。
- 本轮无需修改远端文件，无需重启 Gateway。

## 新任务（2026-05-05 10:18 +08:00）：使用 `openclaw-gtd-health` 再次复查 GTD 闭环

### 目标
- 使用 `openclaw-gtd-health` Skill 再次检查 main 小龙虾 GTD Agent 核心系统、核心逻辑和脚手架。
- 如发现 GTD 逻辑谬误或闭环缺口，直接修复并验证。

### Phase 1: 巡检、语义复核与记录
- **Status:** complete
- 默认 GTD health 巡检：`STATUS=clean`、`issue_count=0`。
- `-IncludeTodoistScaffold` 巡检：`STATUS=clean`、`issue_count=0`，只检查 project / label / filter scaffold。
- 人工复核 live `AGENTS.md` 与四个 GTD Skill 后，未发现新的 GTD 逻辑问题。
- 主 Agent 普通 smoke 返回 `GTD_HEALTH_RECHECK_OK`。
- 新 session + `开始自然规划` 触发词确认 `gtd-natural-planning` 会进入 prompt 并读取 `SKILL.md`。
- 本轮无需修改远端文件，无需重启 Gateway。

## 新任务（2026-05-05）：使用 `openclaw-gtd-health` 复查并闭环 GTD 核心逻辑

### 目标
- 使用新建的 `openclaw-gtd-health` Skill 检查 main 小龙虾 GTD Agent 核心系统、核心逻辑和脚手架。
- 如果发现 GTD 闭环逻辑缺口，直接修复并重新上线验证。

### Phase 1: 巡检、修复与验收
- **Status:** complete
- 已运行：
  - 默认 GTD harness 巡检：`STATUS=clean`
  - `-IncludeTodoistScaffold` scaffold 巡检：`STATUS=clean`
- 人工语义审计发现一个脚本原先未覆盖的闭环缺口：
  - 系统要求 Inbox 清空、单步 Next Action 可存在，但 scaffold 没有给“不属于任何多步 Project 的单步行动”定义明确归位处。
  - `AGENTS.md` 捕获入口使用 `td task quickadd`，存在自动解析日期/标签/项目的风险，和“先 Capture，再 Clarify/Organize”原则有轻微冲突。
- 已备份远端：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-single-actions-fix-20260505-100533`
- 已修复远端 main：
  - 新增 Todoist 支撑项目 `⚡ single-actions`
  - `AGENTS.md` 捕获入口改为 `td task add "X"` 原样捕获到 Inbox
  - `AGENTS.md` Clarify 决策树补入单步独立行动归位到 `⚡ single-actions`
  - `AGENTS.md` Horizons 段修正为多步 Project 必须有 Next Action；单步行动不强行创建 Project
  - `gtd-inbox-triage` / `gtd-daily-review` / `gtd-weekly-review` / `gtd-natural-planning` 均补入 `⚡ single-actions` 归位规则
  - 本仓 `openclaw-gtd-health` Skill 也补强为默认检查 `⚡ single-actions`
- 已重启 main Gateway：
  - PID `2198643`
- 已验收：
  - `openclaw config validate` 通过
  - `gateway health ok=true`
  - Telegram `running=true / lastError=null`
  - `openclaw-gtd-health` 默认巡检 `STATUS=clean`
  - `openclaw-gtd-health -IncludeTodoistScaffold` 巡检 `STATUS=clean`
  - 主 Agent 不投递 smoke test 返回 `GTD_SINGLE_ACTIONS_OK`

## 新任务（2026-05-05）：openclaw-gtd-health Skill 调研

### 目标
- 参考 G 盘 Second Brain 的健康检查类 Skill 和本仓 `openclaw-server-health` Skill。
- 设计一个仓库级 `openclaw-gtd-health` Skill，用于只读检查 main 小龙虾 GTD 核心 Agent Markdown、GTD Skills、cron reminder-only 脚手架和上线状态。
- 本阶段只做调研和方案，不创建新 Skill 文件。

### Phase 1: 参考 Skill 与当前 GTD harness 调研
- **Status:** complete
- 已定位 G 盘 Second Brain 中的健康检查类 Skill：
  - `second-brain-vault-audit`
  - `second-brain-lint`
- 已拆解本仓现有 `openclaw-server-health` 的 Skill + wrapper + probe script 模式。
- 已只读抽样远端 main workspace：
  - `~/.openclaw/workspace/AGENTS.md`
  - 四个 `~/.openclaw/workspace/skills/gtd-*/SKILL.md`
  - `openclaw skills list --agent main --json`
  - `openclaw cron list --json`
- 已形成 `openclaw-gtd-health` 的路径、资源、检查层级、clean 标准和落地步骤建议。

### Phase 2: 创建 `openclaw-gtd-health` Skill
- **Status:** complete
- 已使用 skill-creator 初始化：
  - `.agents/skills/openclaw-gtd-health/`
- 已新增：
  - `.agents/skills/openclaw-gtd-health/SKILL.md`
  - `.agents/skills/openclaw-gtd-health/agents/openai.yaml`
  - `.agents/skills/openclaw-gtd-health/scripts/gtd_health_check.sh`
  - `.agents/skills/openclaw-gtd-health/scripts/run-openclaw-gtd-health.ps1`
- 已验收：
  - PowerShell wrapper parser OK
  - 远端 bash `bash -n` OK
  - `quick_validate.py` 通过
  - 默认只读巡检 `STATUS=clean`
  - 可选 Todoist scaffold 只读巡检 `STATUS=clean`

## 新任务（2026-05-05）：GTD 核心 Markdown / Skill 逻辑修复

### 目标
- 修复 main 小龙虾 GTD 核心 Agent Markdown、Todoist scaffold 说明和 GTD Skill 的逻辑漂移。
- 新增 `gtd-natural-planning` Skill。
- 重启 main Gateway 让新 workspace 生效。

### Phase 1: 修复与上线
- **Status:** complete
- 已备份远端 main workspace 待修改文件到：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-skill-logic-fix-20260505-092939`
- 已修改：
  - `~/.openclaw/workspace/AGENTS.md`
  - `~/.openclaw/workspace/skills/gtd-inbox-triage/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-daily-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-weekly-review/SKILL.md`
- 已新增：
  - `~/.openclaw/workspace/skills/gtd-natural-planning/SKILL.md`
- 已重启 main：
  - `systemctl --user restart openclaw-gateway`
- 已验收：
  - `openclaw config validate` 通过
  - main service `active/running`，PID `2195060`
  - `gateway health ok=true`
  - Telegram `running=true / lastError=null`
  - 四个 GTD Skill 均 `eligible=true / modelVisible=true / commandVisible=true`
  - 不投递 smoke test 返回 `GTD_NATURAL_PLANNING_READY_OK`

### Phase 2: GTD harness 全量逻辑补强
- **Status:** complete
- 已再次按 GTD 五步、Weekly Review、Natural Planning、Engage 执行选择逻辑审计 `AGENTS.md` 与四个 GTD Skill。
- 已备份远端文件到：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-harness-audit-fix-20260505-094154`
- 已补强：
  - `AGENTS.md` 的 Clarify 决策树
  - `AGENTS.md` 的 Engage 执行选择规则
  - `gtd-inbox-triage` 的 do/delegate/defer/reference/project 分流
  - `gtd-daily-review` 的软日期治理和 Engage 收尾
  - `gtd-weekly-review` 的 Next Actions / context list 回顾
  - `gtd-natural-planning` 的 label merge 安全规则与 Waiting For 上下文要求
- 已重启 main Gateway：
  - PID `2196131`
- 已验收：
  - `openclaw config validate` 通过
  - 四个 GTD Skill ready
  - 五个 GTD cron 仍为 reminder-only
  - `gateway health ok=true`
  - Telegram `running=true / lastError=null`
  - 无 session lock 输出
  - 不投递 smoke test 返回 `GTD_HARNESS_AUDIT_OK`

## 新任务（2026-05-04）：纯提醒 cron 输出推理文本问题调研

### 目标
- 调研 OpenClaw cron 里纯提醒任务应如何设定，避免 Telegram 收到模型解释/推理式前缀。
- 先给出配置结论，后续再按用户确认执行修复。

### Phase 1: 官方文档与现场核对
- **Status:** complete
- 已完成官方 cron 文档、当前 2026.5.3 CLI 帮助、本地 5.3 源码类型、远端现有 8 个 cron job 的核对。
- 结论写入 `findings.md`；本阶段不直接改远端 cron。

### Phase 2: 保留 agentTurn 的纯提醒 cron 优化
- **Status:** complete
- 按用户要求继续保留：
  - `agentTurn`
  - `isolated`
  - `announce`
- 已修改 7 个纯提醒 job 的 wrapper 和运行参数，不改 `<reminder>` 内真正发送的提醒文本。
- 已重启 main Gateway，让主 Agent 重新上线。
- 已通过：
  - `openclaw config validate`
  - `openclaw gateway health --json`
  - `openclaw agent --agent main` 最小实呼 `MAIN_CRON_OPT_OK`

### Phase 3: openclaw-update-check 单独复核
- **Status:** complete
- `openclaw-update-check` 是开放式检查任务，不按纯提醒严格一行规则处理。
- 已确认：
  - job 可手动运行成功
  - `lastRunStatus=ok`
  - `lastDelivered=true`
  - `lastDeliveryStatus=delivered`
  - 最终输出没有泄露推理
- 误收紧的 prompt 已恢复为开放式花园多惠检查 prompt，并显式 `thinking=medium`。

## 新任务（2026-05-04）：main 小龙虾 Telegram 会话卡死恢复

### 目标
- 处理用户反馈的“龙虾卡住”问题。
- 优先恢复 main Telegram 直接会话，不影响 dayong / chunyan / zenglan。

### Phase 1: 定位卡点
- **Status:** complete
- 标准巡检显示服务器、Tailscale、Funnel、Mihomo、四个 Gateway 服务均在线。
- main 日志确认卡点：
  - `stalled session`
  - `sessionKey=agent:main:telegram:main-bot:direct:8226087994`
  - `state=processing`
  - `queueDepth=1`
  - `reason=active_work_without_progress`
  - `activeWorkKind=model_call`
- lock 文件存在：
  - `~/.openclaw/agents/main/sessions/428b8d2a-8ad3-42f1-9fa7-e4c636491d66.jsonl.lock`
  - lock pid 为当前 main Gateway 进程，不是旧 PID 残留。

### Phase 2: 恢复 main Gateway
- **Status:** complete
- 已只重启：
  - `openclaw-gateway`
- 未重启另外三个 Gateway。
- 重启后 lock 已消失。
- `openclaw config validate` 通过。
- `openclaw gateway health --json`：
  - `ok=true`
  - Telegram `running=true`
  - Telegram `connected=true`
  - Telegram `lastError=null`
  - event loop `degraded=false`
- main 最小实呼：
  - session `recovery-smoke-20260504-1752`
  - 返回 `MAIN_RECOVERED_OK`
  - provider/model：`xiaomi-mimo/mimo-v2.5-pro`
  - duration：约 6.3 秒

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `openclaw cron status` 首次远程执行误把本地 PowerShell `$HOME` 展开成 Windows 路径，导致连接 `ws://127.0.0.1:18789` 失败 | 在双引号 SSH 命令里写 `$HOME` | 后续改用单引号包裹远程命令，让 `$HOME` 在远端 Ubuntu 展开 |
| main Telegram 会话活锁，active model_call 无进展 | 只读巡检 + lock 文件检查 | 只重启 `openclaw-gateway` 主实例，释放 stuck model call 和 lock，随后健康检查与最小实呼通过 |

## 新任务（2026-05-04）：OpenClaw 上游 fork 工作区与两个修复 PR

### 目标
- 删除旧的本地上游源码副本 `C:\Zero\Doc\Cloud\GitHub\openclaw-src`
- 将新的 OpenClaw fork clone 到当前运维仓库下：
  - `upstream/openclaw/`
- 父仓库忽略该嵌套源码 repo，避免把上游源码作为普通目录提交
- 向 OpenClaw 上游分别提交两个 PR：
  - Telegram verbose 工具进度修复
  - Brave Search runtime provider fallback 修复

### Phase 1: 工作区整理
- **Status:** complete

### Phase 2: Telegram verbose 修复 PR
- **Status:** complete

### Phase 3: Brave Search 修复 PR
- **Status:** complete

### 追加复核（2026-05-04 17:48 +08:00）
- Telegram PR `https://github.com/openclaw/openclaw/pull/77211` 已重新推送到 head `86dd83d2c24e562eaf73d29f07d06c408d05a0dd`。
  - 本地补修：避免 Telegram visible tool payload 介入后，旧 answer preview 被后续 final 错误消费。
  - GitHub 最终状态：`mergeStateStatus=CLEAN`，`Pending=0`，`Failed=0`。
- Brave PR `https://github.com/openclaw/openclaw/pull/77219` 已 rebase 到最新 `upstream/main` 并重新推送到 head `cf0be8a303967d3f0ff5fa612ba0f28af1b7e9c5`。
  - 本地补修：合并上游 current bundled plugin index 逻辑与本 PR 的 broken runtime entry repair 逻辑。
  - 本地验证：doctor 定向测试 38 passed，`oxfmt --check` 通过，`git diff --check` 通过。
  - GitHub 最终状态：`mergeStateStatus=CLEAN`，`Pending=0`，`Failed=0`。

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Brave doctor 新增用例初始没有触发 `updateNpmInstalledPlugins` | 测试只写 `tools.web.search.provider=brave`，但 fixture 未提供官方 web search catalog 映射 | 改为覆盖现场真实形态：`plugins.entries.brave.enabled=true` + `tools.web.search.provider=brave`，测试通过 |
| Telegram PR rebase 后暴露 `bot-message-dispatch.test.ts` 中 preview/final timing 失败 | 旧逻辑在 visible tool payload 介入后仍可能 finalize stale archived preview | 增加单调 `visibleMessageOrder` 判定，确保 final 只消费未被后续 visible payload 超越的 preview；Telegram 定向测试通过 |
| Brave PR rebase 与上游 `missing-configured-plugin-install.ts` 冲突 | 上游新增 current bundled plugin index，本 PR 新增 broken runtime entry repair | 手工合并两边逻辑，保留 `loadInstalledPluginIndex` + `BundledPluginPackageDescriptor`，并在 stale/broken 诊断前加载 install records |
| PR 状态汇总 PowerShell 命令出现 `An empty pipe element is not allowed` | 初次把 `foreach` 结果直接接管道，脚本块边界错误 | 改为 `& { foreach (...) { ... } } | Format-List` 后正常汇总 |

## 新任务（2026-05-04）：Brave 内置 Web Search 修复（已完成 ✅）

### 目标
- 修复 main 小龙虾内置 `web_search` 报 `web_search is disabled or no provider is available`
- 保持 Brave Search 为内置 Web Search provider
- 优先恢复 main Gateway，再重启另外三个 Gateway

### 当前进展
- ✅ 已将全局 OpenClaw 从半安装状态补完整到：
  - `OpenClaw 2026.5.3 (06d46f7)`
- ✅ 已更新 main 的 Brave 插件：
  - `@openclaw/brave-plugin 2026.5.3`
  - 插件入口已从旧 `index.ts` 变为编译后的 `dist/index.js`
- ✅ 已保留 main Web Search 配置：
  - `tools.web.search.enabled = true`
  - `tools.web.search.provider = "brave"`
  - `plugins.entries.brave.config.webSearch.apiKey = env:BRAVE_API_KEY`
- ✅ 已打 2026.5.3 安装树热修：
  - `web-provider-runtime-shared-*.js`：当活动 runtime registry 没有 web provider 时，继续 fallback 到已安装插件 discovery
  - `bot-Blf2Bm9e.js`：重打 Telegram verbose 工具进度 hot patch
- ✅ 已重启四个 Gateway：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- ✅ 最终验收：
  - `openclaw-gateway` active/running，Telegram connected
  - 另外三个 Gateway active/running，`NRestarts=0`
  - main Brave-only smoke test 返回 `MAIN_BRAVE_ONLY_OK`
  - `toolSummary.tools = ["web_search"]`
  - `toolSummary.failures = 0`

### Phase 1: 修复安装与插件
- **Status:** complete

### Phase 2: 重启与验收
- **Status:** complete

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `openclaw update` 被中断后 CLI 入口断裂，`/usr/bin/openclaw` 找不到 `~/.local/share/pnpm/openclaw` | `openclaw update --tag latest` 中途停止 | 显式设置 `PNPM_HOME` 和代理后运行 `pnpm add -g openclaw@latest`，恢复到 `2026.5.3` |
| Brave 插件旧包只有 TypeScript entry，5.3 Gateway 报需要 compiled runtime output | `@openclaw/brave-plugin 2026.5.2` | 更新到 `@openclaw/brave-plugin 2026.5.3` |
| 5.3 活动 runtime registry 存在但不含 Brave web provider，`web_search` 仍 no provider | 更新核心和插件后复测 | 热修 `web-provider-runtime-shared-*.js`，runtime provider 为空时 fallback 到已安装插件 discovery |
| OpenClaw 升级覆盖 Telegram verbose 工具进度 hot patch | 复查 `suppressDefaultToolProgressMessages` | 已在 `bot-Blf2Bm9e.js` 重打热修 |

## 新任务（2026-05-04）：main Tavily Search fallback Skill 安装（已完成 ✅）

### 目标
- 给 main 小龙虾安装 `tavily-search` workspace Skill
- 在内置 `web_search` 不可用时，用 Tavily CLI 作为联网搜索 fallback
- 将工具路径和 fallback 规则写入远端 workspace `TOOLS.md`

### 当前进展
- ✅ 已安装远端 Tavily CLI：
  - `/home/kevinlasnh/.local/bin/tvly`
  - `tavily-cli 0.1.2`
- ✅ 已将 `TAVILY_API_KEY` 写入：
  - `~/.openclaw/.env`
- ✅ 已部署 workspace Skill：
  - `~/.openclaw/workspace/skills/tavily-search/SKILL.md`
- ✅ 已纠正文档位置：
  - 已从 `~/.openclaw/workspace/AGENTS.md` 移除联网搜索 fallback 工具细节
  - 已写入 `~/.openclaw/workspace/TOOLS.md`
- ✅ 已重启 main Gateway，让 `TAVILY_API_KEY` 进入进程环境。
- ✅ 已验收：
  - Gateway health `ok=true`
  - Telegram connected
  - `tvly search` smoke test 返回结果
  - `openclaw skills list --agent main --json` 显示 `tavily-search`：`eligible=true`、`modelVisible=true`、`commandVisible=true`
  - 主 Agent smoke test 返回 `TAVILY_SKILL_OK`

### Phase 1: 安装与配置
- **Status:** complete

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Tavily 官方 installer 在非登录 SSH shell 中退回 pip，触发 Ubuntu PEP 668 `externally-managed-environment` | `curl -fsSL https://cli.tavily.com/install.sh \| bash` | 改用远端已有 `/home/kevinlasnh/.local/bin/uv tool install tavily-cli` |
| `tavily-search` Skill metadata 中 `bins` 写绝对路径时被 OpenClaw 判为 missing | `bins: [/home/kevinlasnh/.local/bin/tvly]` | 改为 `bins: [tvly]`，正文仍要求用完整路径调用 |
| 联网搜索 fallback 工具细节误写入 `AGENTS.md` | 初次写入位置错误 | 已删除该段并迁移到 `TOOLS.md` |

## 新任务（2026-05-03）：GTD 待办管理系统设计与部署

### 目标
- 为小龙虾搭建基于 GTD 方法论的 Todoist 待办管理系统
- 用户通过 Telegram 语音/文字操控，小龙虾执行所有 Todoist 操作
- 完成后与 L2 知识库形成"知识 + 待办"闭环

### Phase 1: 系统设计讨论
- **Status:** complete
- ✅ GTD 方法论学习完成（用户与 Grok 讨论）
- ✅ OpenClaw 架构调研完成（workspace files / skills / cron / heartbeat）
- ✅ 架构方向确定（AGENTS.md + workspace skills + cron）
- ✅ 已确定：日常节奏（9/13/19 Inbox + 22:00 Review）
- ✅ 已确定：Inbox 沉淀 Skill（半自动 + 确认门 + 批量提案→审批→执行）
- ✅ 已确定：纯语音操控模式（用户只看 GUI，小龙虾执行所有操作）
- ✅ 已确定：Daily Review skill 设计（今日成就 + 未完成处理 + 系统状态 + 明日预览）
- ✅ 已确定：Weekly Review skill 设计（8 步：成就→日历补漏→Horizons 对齐→Project 体检→Someday/Waiting 清理→创造性发散→下周规划→仪表盘）
- ✅ 已确定：Horizons 并入 Weekly Review Step 3
- ✅ 已确定：cron 架构（5 个 job：3×Inbox + 1×DailyReview + 1×WeeklyReview 提醒，全部 isolated+announce）
- ✅ 已确定：AGENTS.md GTD 框架段（角色定义 + 日常节奏 + Skill 栈 + 触发词路由 + 操作权限 + GTD 术语表 + 核心原则）
- ✅ 已调整：Todoist GTD 初始化由本轮部署执行，后续 Clarify 在主 session 中与用户讨论
- ✅ GTD 官方对照审查通过（3 个小补丁已纳入：日历补漏 + 创造性发散 + @next 标签）

### Phase 2: 编写部署方案
- **Status:** complete
- ✅ 已将部署方案改成最终版：
  - cron 只发提醒
  - 主 session 执行 Inbox triage / Daily Review / Weekly Review
  - Todoist scaffold 先行初始化
  - mutating command 必须使用 `id:<task_id>` 或 URL
  - 周日 Weekly Review 提醒改为 13:15

### Phase 3: 实施部署
- **Status:** complete
- ✅ Todoist 已备份：
  - `/home/kevinlasnh/.openclaw-backups/todoist-gtd-before-20260503-215522`
- ✅ Todoist GTD scaffold 已创建：
  - 2 个 Project：`🗂 Someday / Maybe`、`🌅 Horizons`
  - 8 个 label：`next`、`waiting`、`电脑`、`家`、`外出`、`电话`、`深度工作`、`2min`
  - 9 个 GTD filter
- ✅ 已删除旧失效 filter：
  - `1`（旧 query 指向不存在的 `#Next Actions`）
- ✅ Inbox 已保守初始归位：
  - 8 条 → 0 条
- ✅ 已部署 3 个 workspace skill：
  - `gtd-inbox-triage`
  - `gtd-daily-review`
  - `gtd-weekly-review`
- ✅ 已更新远端 workspace `AGENTS.md`，追加 GTD 执行模式
- ✅ 已添加 5 个 reminder-only cron：
  - 9:00 / 13:00 / 19:00 Inbox 提醒
  - 22:00 Daily Review 提醒
  - 周日 13:15 Weekly Review 提醒
- ✅ 已完成验收：
  - 3 个 GTD skill ready
  - `openclaw config validate` 通过
  - `gateway health ok=true`
  - 主 Agent 返回 `GTD_SKILLS_READY_OK`
  - cron `jobs=8`、无 running、无 consecutive errors
  - Inbox 当前 0 条

---

## 历史任务（2026-05-03）：main Gateway 干净状态复查（已完成 ✅）

### 目标
- 只读复查用户自己的 `main` Gateway 是否正常、是否干净
- 不修改配置、不重启服务
- 核对 Agent、cron、状态目录、服务健康、Telegram、日志和 session lock

### 当前进展
- ✅ 已确认 `openclaw-gateway`：
  - `active/running`
  - `NRestarts = 0`
  - `MemoryCurrent ≈ 322MB`
- ✅ 已确认监听端口：
  - `127.0.0.1:18790`
  - `127.0.0.1:18792`
  - `127.0.0.1:8787`
- ✅ 已确认：
  - `openclaw config validate` 通过
  - `gateway health ok = true`
  - Telegram `running=true`
  - Telegram `connected=true`
  - Telegram webhook 模式正常
- ✅ 已确认 Agent 层干净：
  - CLI agents list 只剩 `main`
  - `openclaw.json` 的 `agents.list` 只剩 `main`
  - `~/.openclaw/agents/` 只剩 `main`
- ✅ 已确认 cron 层干净：
  - `jobs = 2`
  - 仅有 `drink-water-half`
  - 仅有 `drink-water-hourly`
  - `runningAtMs = null`
  - `consecutiveErrors = 0`
- ✅ 已确认配置和 cron 文件中没有旧名称残留：
  - `dayong`
  - `market`
  - `sector`
  - `stock`
  - `morning-briefing`
  - `market-reflection`
  - `sector-reflection`
  - `closing-report`
  - `sector-daily-push`
- ✅ 已确认无 session lock。
- ✅ 已确认最终 main 重启后无新错误日志：
  - 无 `Invalid config`
  - 无 `PluginLoadFailure`
  - 无 `stuck session`
  - 无 `sendMessage failed`
  - 无 `429`
  - 无 `Vulkan` / `OutOfDeviceMemory`
- ✅ 已确认 Telegram 近期有连续 `sendMessage ok`。
- ✅ 已确认代理和 Funnel 正常：
  - `127.0.0.1:7897` 访问 `generate_204` 返回 `204`
  - Tailscale Funnel `443 -> 8787`

### Phase 1: 只读复查 main Gateway 干净状态
- **Status:** complete

## 新任务（2026-05-03）：升级到 OpenClaw 2026.5.2 并重新上线四个 Gateway（已完成 ✅）

### 目标
- 检查远端 OpenClaw 是否有更新，有则升级到 npm latest
- 重新上线四个 Gateway：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 确认每个 Gateway 内所有 configured Agent 可完成最小不投递实呼
- 不改 dayong / chunyan / zenglan 的业务模型和 Agent 配置，只做升级兼容修复

### 当前进展
- ✅ 已确认 npm latest 与本机安装均为：
  - `OpenClaw 2026.5.2 (8b2a6e5)`
- ✅ 升级前备份已存在：
  - `/home/kevinlasnh/.openclaw-backups/global-upgrade-20260502-20260503-145154`
- ✅ 已修复 2026.5.2 下 `tools.web.search.provider=brave` 的外部插件兼容问题：
  - `main`
  - `chunyan`
  - `zenglan`
- ✅ 已逐 state 安装并启用：
  - `@openclaw/brave-plugin`
  - `plugins.entries.brave.enabled = true`
- ✅ 已重打 Telegram verbose 工具进度热修：
  - `suppressDefaultToolProgressMessages: previewToolProgressEnabled ? true : void 0`
- ✅ 四套配置均通过：
  - `openclaw config validate`
- ✅ 四个 Gateway 均已重启并为：
  - `active/running`
  - `NRestarts = 0`
- ✅ 11 个 configured Agent 的不投递 smoke test 全部通过：
  - `main/main`
  - `dayong/market`
  - `dayong/sector`
  - `dayong/stock`
  - `dayong/strategy`
  - `dayong/breakboard`
  - `dayong/douzhuan`
  - `dayong/volume15`
  - `dayong/volume35`
  - `chunyan/chunyan`
  - `zenglan/zenglan`
- ✅ main 当前仍保持：
  - 1 个 Agent：`main`
  - 2 条喝水 cron：`drink-water-half`、`drink-water-hourly`
  - 文本主模型：`xiaomi-mimo/mimo-v2.5-pro`
  - fallback：`deepseek/deepseek-v4-pro`
  - 图片模型：`xiaomi-mimo/mimo-v2.5`

### Phase 1: 更新检查与升级
- **Status:** complete

### Phase 2: Brave 插件兼容修复
- **Status:** complete

### Phase 3: 重启四个 Gateway 与健康验收
- **Status:** complete

### Phase 4: 全 Agent smoke test 与 main 基线复核
- **Status:** complete

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `tools.web.search.provider: web_search provider is not available: brave` | 2026.5.2 升级后 main / chunyan / zenglan 配置校验失败 | 对每个 state 临时移除 `provider=brave`，运行 `openclaw plugins install @openclaw/brave-plugin --force` + `openclaw plugins enable brave` + registry refresh，再恢复 provider |
| Telegram verbose 工具进度热修被升级覆盖 | 复查 2026.5.2 安装树 | 已备份并将 Telegram bundle 中的 suppress 条件改回只在 preview tool progress 可用时抑制默认工具进度 |

## 新任务（2026-05-03）：main Gateway 清理旧 cron 和旧 agent 残留（已完成 ✅）

### 目标
- main Gateway 只保留个人 `main` Agent
- cron 只保留用户刚创建的两条喝水提醒
- 删除/移出旧 `market` / `sector` / `stock` 等 agent 残留和历史重复 cron
- 重启 `openclaw-gateway` 并完成健康验收

### 当前进展
- ✅ 已备份远端 main Gateway 状态：
  - `/home/kevinlasnh/.openclaw-backups/main-clean-cron-agents-20260503-143130`
- ✅ 已通过 `openclaw cron rm` 删除 15 条非喝水 cron：
  - 3 条 `morning-briefing`
  - 3 条 `market-reflection`
  - 3 条 `sector-reflection`
  - 3 条已禁用 `closing-report`
  - 3 条已禁用 `sector-daily-push`
- ✅ 已将旧 agent 状态目录移入备份：
  - `dayong`
  - `default`
  - `market`
  - `sector`
  - `stock`
- ✅ 当前 `~/.openclaw/agents/` 只剩：
  - `main`
- ✅ 当前 `openclaw cron status --json` 显示：
  - `jobs = 2`
- ✅ 当前仅保留两条启用 cron：
  - `drink-water-hourly`
  - `drink-water-half`
- ✅ 已重启 `openclaw-gateway`
- ✅ 已验收：
  - `openclaw config validate` 通过
  - `gateway health ok = true`
  - Telegram webhook probe ok
  - 日志显示 `gateway ready` 和 `webhook advertised`

### Phase 1: 只读核对 main Agent 与 cron 现状
- **Status:** complete

### Phase 2: 清理非喝水 cron 和旧 agent 残留
- **Status:** complete

### Phase 3: 重启与验收
- **Status:** complete

## 新任务（2026-04-27）：长期记忆沉淀尝试（ByteRover curate 首条超时，未清理 PWF）

### 目标
- 将本仓库 PWF 中可复用的长期知识沉淀到 ByteRover `.brv/context-tree/`
- 只沉淀可复用决策、非显然故障根因、技术选型 why
- 全部 curate 成功后再清理 `findings.md` 和已完成 phase

### 当前进展
- ✅ 已盘点三件套规模和章节索引：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- ✅ 已确认 ByteRover CLI 可用：
  - `byterover-cli/3.7.0`
  - 项目 context tree 由 `.brv/context-tree/` 管理
- ✅ 已查询长期知识库，当前未召回同主题历史
- ✅ 已筛选第一批候选沉淀主题：
  - `openclaw-server-health` 巡检 Skill
  - `AGENTS.md` 替代项目级 `CLAUDE.md`
  - main DeepSeek V4 Pro 唯一模型与直连
  - dayong GLM 5.1 直连与 429 风险
  - OpenClaw 2026.4.24 升级坑
  - Telegram verbose 工具进度热修
  - main 卡死 cron / stuck session 根因
  - pnpm 全局安装 / wrapper 坑
  - Kimi 工具链回归
  - Mihomo / Tailscale Funnel / Webhook 稳态
  - Memory Search / Vulkan OOM 处理
- ❌ 第一条 `brv curate` 超时：
  - `cur-1777298706998`
  - `Task timed out after 600s`
  - `brv review pending` 返回 `No pending reviews`
- ✅ 已按仓库规则停止后续沉淀
- ✅ 未清空 `findings.md`
- ✅ 未删除已完成 `task_plan.md` phase
- ✅ 未写入 Sedimentation Checkpoint

### 下一步
- 下次重试时不要给 `brv curate` 附带 5 个大文件引用。
- 应改为更小主题、更短 content、零文件或 1 个小文件引用逐条沉淀。

### Phase 1: 读取和筛选
- **Status:** complete

### Phase 2: ByteRover curate
- **Status:** pending

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `Task timed out after 600s` | 首条沉淀 `openclaw-server-health`，同时附带 Skill、wrapper、runbook、脚本、AGENTS 五个文件 | 已停止后续沉淀和 PWF 清理；下次缩小主题粒度并减少文件引用 |

## 新任务（2026-04-27）：删除仓库根目录 `CLAUDE.md`（已完成 ✅）

### 目标
- 删除仓库根目录下不再需要的 Claude Markdown 项目文件
- 保留 Codex / Agent 入口 `AGENTS.md` 作为当前项目规则文件
- 修正 `AGENTS.md` 中对 `CLAUDE.md` 的前置读取引用

### 当前进展
- ✅ 已删除：
  - `CLAUDE.md`
- ✅ 已更新：
  - `AGENTS.md`
- ✅ 当前前置检查规则改为读取：
  - `findings.md`
  - `progress.md`
  - `AGENTS.md`
- ✅ 未修改全局：
  - `~/.claude/CLAUDE.md`

### Phase 1: 删除项目级 Claude Markdown
- **Status:** complete

## 新任务（2026-04-27）：封装 OpenClaw 服务器标准巡检 Skill（已完成 ✅）

### 目标
- 将现有服务器巡检标准封装为仓库内项目级 Skill
- 让后续“检查服务器 / 检查小龙虾 / 检查代理 5 秒轮询”等任务有统一入口
- 复用既有 `SERVER_HEALTH_CHECKS.md` 和 `server_health_check.sh`，避免两份巡检标准漂移

### 当前进展
- ✅ 已使用 `skill-creator` 规范初始化：
  - `.agents/skills/openclaw-server-health/`
- ✅ 已删除初始化模板示例文件，只保留实际需要的 Skill 内容
- ✅ 已写入 Skill 主文件：
  - `.agents/skills/openclaw-server-health/SKILL.md`
- ✅ 已新增 Windows PowerShell wrapper：
  - `.agents/skills/openclaw-server-health/scripts/run-openclaw-server-health.ps1`
- ✅ wrapper 当前行为：
  - 向上查找仓库根目录的 `server_health_check.sh`
  - 按字节读取并剥离 UTF-8 BOM
  - base64 传输到远端，避免 Windows PowerShell 管道编码破坏 bash shebang
  - 通过 SSH 在 `kevinlasnh@100.64.65.65` 上执行只读巡检
- ✅ 已通过 Skill 结构校验：
  - `Skill is valid!`
- ✅ 已完成 wrapper smoke test：
  - 成功输出 `summary`
  - 成功读取远端 `hostnamectl` / `uptime` / `memory` 等巡检段
- ✅ 已更新 `AGENTS.md` 和 `CLAUDE.md`，把 `openclaw-server-health` 设为后续服务器巡检优先入口

### Phase 1: Skill 初始化
- **Status:** complete

### Phase 2: Skill 内容和 wrapper 落地
- **Status:** complete

### Phase 3: 校验、smoke test 与文档同步
- **Status:** complete

## 新任务（2026-04-27）：dayong 8 个 Agent 切到 GLM 5.1 并配置 ZAI 直连（配置与上线已完成，实呼受 429 限制）

### 目标
- 将 `dayong` 的 8 个 agent 全部显式切到 `zai/glm-5.1`
- 不设置任何 fallback
- 保留全局代理给其他外部服务，但让 ZAI / BigModel endpoint 通过 `NO_PROXY` 直连
- 重启 `openclaw-gateway-dayong` 并完成上线验收

### 当前进展
- ✅ 已备份 dayong 配置：
  - `/home/kevinlasnh/.openclaw-backups/dayong-glm51-direct-20260427-164752`
- ✅ 已修改远端 `~/.openclaw-dayong/openclaw.json`：
  - `agents.defaults.model.primary = zai/glm-5.1`
  - `agents.defaults.model.fallbacks = []`
  - `agents.defaults.models = {"zai/glm-5.1": {}}`
  - `models.providers.zai.models` 只注册 `glm-5.1`
  - 8 个 `agents.list[].model` 全部显式为 `zai/glm-5.1`
- ✅ 已新增 dayong systemd user drop-in：
  - `~/.config/systemd/user/openclaw-gateway-dayong.service.d/10-zai-no-proxy.conf`
  - `NO_PROXY=open.bigmodel.cn,.bigmodel.cn,localhost,127.0.0.1,::1`
  - `no_proxy=open.bigmodel.cn,.bigmodel.cn,localhost,127.0.0.1,::1`
- ✅ 已执行：
  - `systemctl --user daemon-reload`
  - `systemctl --user restart openclaw-gateway-dayong`
- ✅ 已确认配置和运行态：
  - `OpenClaw 2026.4.24`
  - `openclaw config validate` 通过
  - `openclaw models status --json` 显示 `defaultModel/resolvedDefault = zai/glm-5.1`
  - `fallbacks = []`
  - `allowed = [zai/glm-5.1]`
  - `openclaw-gateway-dayong = active/running`
  - `NRestarts = 0`
  - `127.0.0.1:19021` / `127.0.0.1:19023` 正常监听
  - 父进程与 gateway 子进程均继承 `NO_PROXY/no_proxy`
- ⚠️ 已停止继续密集实呼：
  - 8 个 agent 的真实调用均已打到 `provider=zai`、`model=glm-5.1`
  - 当前智谱服务侧返回 `429 该模型当前访问量过大，请您稍后再试`
  - 因 `fallbacks=[]`，429 会直接暴露，不会自动切其他模型

### Phase 1: dayong 模型配置迁移
- **Status:** complete

### Phase 2: ZAI endpoint 直连 drop-in
- **Status:** complete

### Phase 3: 重启上线与运行态验收
- **Status:** complete

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `ENOTEMPTY ... plugin-runtime-deps/.../plugin-sdk` | dayong 重启后首次 health / 插件加载 | 将旧插件缓存目录改名备份后重启，让 OpenClaw 重新生成缓存；当前核心 Gateway 与 Feishu WebSocket 已上线 |
| `429 该模型当前访问量过大，请您稍后再试` | 8 个 agent 的 GLM 5.1 live 实呼 | 判定为智谱服务侧限流；停止继续密集重试，避免放大 429；配置和直连策略不回滚 |

## 新任务（2026-04-27）：main DeepSeek 直连与 dayong GLM 直连测试（已完成 ✅）

### 目标
- 将 main 小龙虾的 DeepSeek API 改为直连
- 保留 Telegram / Brave 等外部服务仍可使用 `127.0.0.1:7897` 代理
- 测试 dayong 8 个 agent 的 ZAI / GLM API 直连能力

### 当前进展
- ✅ 已确认 main 与 dayong 原先都继承 `HTTP_PROXY/HTTPS_PROXY=http://127.0.0.1:7897`
- ✅ 已确认 dayong 8 个 agent 当前真实配置都是 `zai/glm-5`，不是显式 `zai/glm-5.1`
- ✅ 已给 main 新增 systemd user drop-in：
  - `~/.config/systemd/user/openclaw-gateway.service.d/10-deepseek-no-proxy.conf`
  - `NO_PROXY=api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
  - `no_proxy=api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
- ✅ 已 `daemon-reload` 并重启 `openclaw-gateway`
- ✅ 已确认 main 父进程与 gateway 子进程均继承 `NO_PROXY/no_proxy`
- ✅ 已确认 main 仍为：
  - `deepseek/deepseek-v4-pro`
  - `fallbacks = []`
- ✅ 已完成 main 最小实呼：
  - `MAIN_DEEPSEEK_DIRECT_OK`
  - provider/model 为 `deepseek/deepseek-v4-pro`
- ✅ 已确认 Telegram webhook probe ok，代理 `7897` 访问 `generate_204` 仍返回 `204`
- ✅ 已测试 dayong 8 个 agent 直连 ZAI endpoint：
  - `market`
  - `sector`
  - `stock`
  - `strategy`
  - `breakboard`
  - `douzhuan`
  - `volume15`
  - `volume35`
- ✅ dayong 8 个 agent 按当前 `glm-5` 请求全部 HTTP 200，API 实际返回 `glm-5.1`
- ✅ 显式请求 `glm-5.1` 也 HTTP 200

### Phase 1: 现场配置核对
- **Status:** complete

### Phase 2: main DeepSeek 直连配置
- **Status:** complete

### Phase 3: main 与 Telegram 验收
- **Status:** complete

### Phase 4: dayong 8 agent ZAI 直连测试
- **Status:** complete

## 新任务（2026-04-27）：建立远程 Ubuntu 服务器标准巡检惯例（已完成 ✅）

### 目标
- 全面收集当前 Linux 服务器的日常维护 / 健康检查项
- 覆盖 Tailscale、Funnel、SSH、Mihomo 代理、5 秒代理健康轮询、OpenClaw 四 Gateway、cron、会话锁、日志、资源压力和安全暴露面
- 将检查项沉淀为仓库标准 runbook 与只读巡检脚本

### 当前进展
- ✅ 已补读 `planning-with-files` 规范和本仓库 `task_plan.md` / `findings.md` / `progress.md` / `CLAUDE.md`
- ✅ 已查询 L1-3 长期记忆，未召回同主题历史
- ✅ 已复核现有 `collect_ubuntu_host_probe.sh` 与仓库中已有 Tailscale / Mihomo / Gateway / cron 记录
- ✅ 已对远程 Ubuntu `100.64.65.65` 做只读现场复核
- ✅ 已新增标准巡检文档：
  - `SERVER_HEALTH_CHECKS.md`
- ✅ 已新增只读巡检脚本：
  - `server_health_check.sh`
- ✅ 已用 PowerShell + SSH 方式跑通脚本：
  - `Get-Content -Raw -Encoding UTF8 server_health_check.sh | ssh ... "tr -d '\r' | bash -s >/dev/null"`
  - 结果：`REMOTE_HEALTH_SCRIPT_OK`

### 本轮现场基线
- `tailscaled` / `ssh` / `openclaw-sshd-2222` / `cron` 均为 active
- Tailscale Funnel 当前保持：
  - `443 -> 127.0.0.1:8787`
  - `8443 -> 127.0.0.1:8788`
- Mihomo 当前真实代理端口为：
  - `127.0.0.1:7897`
  - `127.0.0.1:7890` 不存在
- `telegram-jp-tw-stable` 保持 `interval: 5`
- 四个 OpenClaw Gateway 均为 active/enabled，四套配置均通过 `openclaw config validate`
- `main` Telegram webhook 已 advertised，近期日志有连续 `sendMessage ok`

### 当前仍需关注的红旗
- `main` 近期日志仍保留本轮卡死前的 `stuck session` 记录，后续巡检要看是否继续增长
- `main` 近期出现过 Vulkan / local memory OOM：
  - `failed to allocate buffer for kv cache`
- `chunyan` 与 `zenglan` 有历史 `NRestarts`，后续巡检要看是否继续增加
- `main` cron 仍有重复任务、旧模型字段和 Telegram delivery target 错误，当前先记录为巡检红旗，不在本任务中修改

### Phase 1: 远程只读调研
- **Status:** complete

### Phase 2: 巡检 runbook 落库
- **Status:** complete

### Phase 3: 只读巡检脚本落库与验证
- **Status:** complete

## 新任务（2026-04-27）：main 小龙虾卡死恢复与异常 cron 暂停（已完成 ✅）

### 目标
- 恢复 `main` 小龙虾对 Telegram / CLI 的响应
- 定位卡死来源
- 避免同一批异常 cron 在恢复后继续拖死 Gateway

### 当前进展
- ✅ 已确认 `openclaw-gateway` systemd 仍为 `active/running`，但日志连续出现 `stuck session`
- ✅ 已定位卡住来源：
  - `closing-report`
  - `sector-daily-push`
  - 以及 `closing-report` 拉起的 `subagent`
- ✅ 已确认旧进程在停止时的资源峰值：
  - CPU time 约 `9min 59s`
  - memory peak 约 `5.1G`
  - swap peak 约 `236.3M`
- ✅ 已禁用 6 条重复/异常 cron：
  - 3 条 `closing-report`
  - 3 条 `sector-daily-push`
- ✅ 已重启 `openclaw-gateway`
- ✅ 已清理插件运行时缓存卡住问题：
  - 将 `~/.openclaw/plugin-runtime-deps/openclaw-unknown-6f2f8ee616b5` 改名备份
  - 让 OpenClaw 重新生成缓存
- ✅ 最终验收：
  - `openclaw config validate` 通过
  - Telegram webhook 已重新 advertised
  - `MAIN_RECOVERED_OK` 实呼成功
  - 无新的 `stuck session`
  - 无残留 `*.jsonl.lock`

### Phase 1: 现场诊断
- **Status:** complete

### Phase 2: 暂停异常 cron 并重启 main
- **Status:** complete

### Phase 3: CLI / Telegram / 资源验收
- **Status:** complete

## 新任务（2026-04-27）：恢复 Telegram verbose 工具调用详情显示（已完成 ✅）

### 目标
- 复核为什么 Telegram 里不再显示旧式 `Exec: ...` 工具调用详情
- 保持 `main` 的 Telegram streaming 继续为 `off`
- 恢复 verbose 开启时的独立工具进度 / 摘要消息

### 当前进展
- ✅ 已确认 `main` 当前仍为 `OpenClaw 2026.4.24`
- ✅ 已确认 `verboseDefault = "on"`，Telegram direct session 的 verbose 也为 `on`
- ✅ 已确认 `main-bot` 的 Telegram streaming 为 `mode = "off"`
- ✅ 已定位根因：
  - Telegram 扩展强制传入 `suppressDefaultToolProgressMessages: true`
  - 但新版 preview 工具进度只在 `answerLane.stream` 存在时启用
  - streaming 关闭时，preview 不工作，同时默认工具进度又被抑制
- ✅ 已热修远端安装树：
  - `dist/extensions/telegram/bot-gUR32RLX.js`
  - 将 `suppressDefaultToolProgressMessages: true` 改为 `previewToolProgressEnabled ? true : void 0`
- ✅ 已重启 `openclaw-gateway`
- ✅ 已验证：
  - `openclaw config validate` 通过
  - Gateway `active/running`
  - Telegram webhook 已重新 advertised
  - Telegram 入口模拟测试触发 `exec`，并产生工具进度消息 + 最终回复两条 `sendMessage`

### Phase 1: 现场复核
- **Status:** complete

### Phase 2: 安装树热修
- **Status:** complete

### Phase 3: 重启与 Telegram 入口验收
- **Status:** complete

## 新任务（2026-04-27）：将 main 小龙虾切到唯一模型 DeepSeek V4 Pro（已完成 ✅）

### 目标
- 只修改 kevinlasnh 自己的 `main` 小龙虾
- 配置 `DEEPSEEK_API_KEY`
- 将唯一文本模型切到 `deepseek/deepseek-v4-pro`
- 不设置任何 fallback
- 重启后完成配置校验、模型状态确认和最小实呼

### 当前进展
- ✅ 已核对 DeepSeek 官方文档与本机 OpenClaw catalog
- ✅ 已备份远端主配置和 `.env`
- ✅ 已在 `~/.openclaw/.env` 配置 `DEEPSEEK_API_KEY`（不在仓库记录明文）
- ✅ 已将 `~/.openclaw/openclaw.json` 中：
  - `agents.defaults.model.primary = deepseek/deepseek-v4-pro`
  - `agents.defaults.model.fallbacks = []`
  - `agents.defaults.models` 收敛为只允许 `deepseek/deepseek-v4-pro`
- ✅ 已确认 `openclaw config validate` 通过
- ✅ 已确认 `openclaw models status --json` 显示：
  - `defaultModel = deepseek/deepseek-v4-pro`
  - `fallbacks = []`
  - `allowed = [deepseek/deepseek-v4-pro]`
  - `imageModel = null`
- ✅ 已重启 `openclaw-gateway`
- ✅ 启动日志显示：
  - `agent model: deepseek/deepseek-v4-pro`
  - `ready`
- ✅ 最小实呼返回：
  - `MAIN_DEEPSEEK_V4_PRO_OK`
  - `provider = deepseek`
  - `model = deepseek-v4-pro`
  - `fallbackUsed = false`

### Phase 1: 文档与本机 catalog 核查
- **Status:** complete

### Phase 2: 写入 DeepSeek key 与 main 模型配置
- **Status:** complete

### Phase 3: 重启与实呼验收
- **Status:** complete

## 新任务（2026-04-27）：检查远程 OpenClaw、升级到 latest、核查 Deepseek V4 Pro 支持（已完成 ✅）

### 目标
- 检查远程 Ubuntu `100.64.65.65` 上当前小龙虾运行状态
- 将当前 live OpenClaw 更新到最新版本
- 升级稳定后完成最小实呼、通道、日志复核
- 核查最新版本是否支持 Deepseek V4 Pro 的模型配置

### 当前进展
- ✅ 已加载 `planning-with-files` 规范
- ✅ 已读取本仓库 `task_plan.md` / `progress.md` / `findings.md` / `CLAUDE.md`
- ✅ 已确认本轮 live 运维入口仍按项目规则走远程 Ubuntu SSH
- ✅ 已查询 L1-3 长期记忆，未召回相关历史
- ✅ 已通过 SSH 检查远程 Ubuntu 当前服务、版本、安装方式、日志和配置
- ✅ 已确认当前 CLI 为 `OpenClaw 2026.4.7`，npm latest 为 `2026.4.24`
- ✅ 已确认四个 Gateway 均为 `active/running`
- ✅ 已确认主实例升级前 `config validate`、`gateway health`、最小实呼均通过
- ⚠️ 第一次 `pnpm add -g openclaw@latest` 失败：
  - 错误：`ERR_PNPM_NO_GLOBAL_BIN_DIR`
  - 原因：非登录 SSH 环境未带 `PNPM_HOME`
  - 处理：错误 trap 已重启 `openclaw-gateway`，下一次显式设置 `PNPM_HOME=$HOME/.local/share/pnpm`
- ⚠️ 第二次 `pnpm add -g openclaw@latest` 失败：
  - 错误：`ERR_PNPM_UNEXPECTED_VIRTUAL_STORE`
  - 原因：全局目录同时残留 `global/5/.pnpm` 与 `global/5/node_modules/.pnpm` 两套 virtual store 结构
  - 处理：错误 trap 已再次重启 `openclaw-gateway`，下一步只读检查 pnpm 全局目录后选择兼容配置或重建全局安装目录
- ⚠️ 第三次尝试使用 `virtual-store-dir=node_modules/.pnpm` 兼容旧结构失败：
  - 错误：`Configuration conflict. "virtual-store-dir" may not be used with "global"`
  - 处理：错误 trap 已再次重启 `openclaw-gateway`
  - 下一步：在 `global/5` 内执行 `pnpm install` 使 `node_modules` 重新对齐当前默认 `.pnpm` store，再执行全局升级
- ⚠️ 第四次先 `pnpm install --force` 再 `pnpm add -g` 仍失败：
  - `pnpm install --force` 作为普通项目安装仍重建到 `node_modules/.pnpm`
  - `pnpm add -g` 仍要求使用全局规则的 `global/5/.pnpm`
  - 错误 trap 已重启四个 Gateway
  - 下一步：将旧 `global/5/node_modules` 原地改名备份，让 `pnpm add -g` 按全局规则重新生成
- ✅ 已通过“改名旧 `node_modules` + 让 `pnpm add -g` 重新生成”的方式升级成功：
  - 当前 CLI：`OpenClaw 2026.4.24 (cbcfdf6)`
- ✅ 已修复 `zenglan` 在新版 schema 下的飞书旧字段：
  - 删除 `channels.feishu.accounts.zenglan-feishu.botName`
  - 删除 `channels.feishu.accounts.zenglan-feishu.blockStreaming`
- ✅ 已修复 `dayong` 升级后循环重启：
  - 新增 `discovery.mdns.mode = "off"`
  - 避免 Bonjour/mDNS advertise 取消时的 `CIAO ANNOUNCEMENT CANCELLED` 未处理 rejection 杀掉进程
- ✅ 四个 Gateway 当前均为 `active/running`
- ✅ 四套配置均通过 `openclaw config validate`
- ✅ 最小实呼验收：
  - `main` → `MAIN_2026424_OK`
  - `dayong/market` → `DAYONG_MARKET_2026424_OK`
  - `chunyan` → `CHUNYAN_2026424_OK`
  - `zenglan` → `ZENGLAN_2026424_OK`
- ✅ 已确认 `OpenClaw 2026.4.24` 内置支持：
  - `deepseek/deepseek-v4-pro`
  - `deepseek/deepseek-v4-flash`
- ⚠️ 仍需注意：
  - 当前多次实呼触发 `zai/glm-5` / `zai/glm-5.1` rate limit 429，这是模型额度/访问量问题，不是 Gateway 服务未启动

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `ERR_PNPM_NO_GLOBAL_BIN_DIR` | 非登录 SSH 环境直接执行 `pnpm add -g openclaw@latest` | 显式设置 `PNPM_HOME=$HOME/.local/share/pnpm` 并把它加入 `PATH` 后重试 |
| `ERR_PNPM_UNEXPECTED_VIRTUAL_STORE` | 设置 `PNPM_HOME` 后执行 `pnpm add -g openclaw@latest` | 先检查 pnpm 全局目录结构，避免把真实运行入口切到错误 virtual store |
| `"virtual-store-dir" may not be used with "global"` | 尝试给 `pnpm add -g` 临时指定旧 virtual store | 放弃该路径，改为先修 pnpm 全局目录结构 |
| `ERR_PNPM_UNEXPECTED_VIRTUAL_STORE` 复发 | 在 `global/5` 内执行 `pnpm install --force` 后再全局升级 | 普通 install 仍按 `node_modules/.pnpm` relink；改为备份旧 `node_modules`，让全局 add 重新生成 |
| `zenglan` 新版配置校验失败 | `2026.4.24` 下验证 `~/.openclaw-zenglan/openclaw.json` | 删除飞书账号旧字段 `botName` / `blockStreaming` |
| `dayong` 循环重启 | 升级后启动 dayong，多飞书账号启动期间 Feishu ping timeout + Bonjour cancellation | 只给 dayong 设置 `discovery.mdns.mode = "off"`，重启后稳定 |

### Phase 1: 现场状态检查
- **Status:** complete

### Phase 2: 升级到 latest
- **Status:** complete

### Phase 3: 升级后稳定性验收
- **Status:** complete

### Phase 4: Deepseek V4 Pro 配置支持核查
- **Status:** complete

## 新任务（2026-04-12）：复活 `chunyan` 飞书小龙虾（已完成 ✅）

### 目标
- 让：
  - `openclaw-gateway-chunyan`
  在：
  - `OpenClaw 2026.4.7`
  下重新可校验、可重启、可实呼
- 恢复：
  - `chunyan-feishu`
  的 WebSocket 通道
- 避免：
  - `zai/glm-5`
  在命中：
  - `429`
  时直接把整轮请求打成无回复

### 当前进展
- ✅ 已复核历史记录，确认：
  - `chunyan`
  在：
  - `2026-04-07`
  曾成功切到：
  - `zai/glm-5`
- ✅ 已坐实当前 `2026.4.7` CLI 读：
  - `~/.openclaw-chunyan/openclaw.json`
  时会直接报：
  - `Cannot find module '@larksuiteoapi/node-sdk'`
- ✅ 已坐实真实运行树：
  - `/home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.7_@napi-rs+canvas@0.1.97/node_modules/openclaw`
  当前整棵目录都是：
  - `root:root`
  因此首次热修会先卡：
  - `EACCES rename`
- ✅ 已通过：
  - `sudo chown -R kevinlasnh:kevinlasnh`
  收回该运行树所有权
- ✅ 已统一向共享运行树补回：
  - `grammy`
  - `@grammyjs/runner`
  - `@grammyjs/transformer-throttler`
  - `@larksuiteoapi/node-sdk`
- ✅ 已备份：
  - `/home/kevinlasnh/.openclaw-chunyan/openclaw.json.pre-revive-20260412-213645`
- ✅ 已修正：
  - `models.providers.zai.apiKey = ${ZAI_API_KEY}`
  - `agents.defaults.model.fallbacks = [minimax/MiniMax-M2.5]`
  - `agents.defaults.models` 补入：
    - `minimax/MiniMax-M2.5`
- ✅ 已删除 `2026.4.7` schema 不再接受的两个飞书账号字段：
  - `channels.feishu.accounts.chunyan-feishu.botName`
  - `channels.feishu.accounts.chunyan-feishu.blockStreaming`
- ✅ 当前：
  - `openclaw config validate`
  已恢复通过
- ✅ 已重启：
  - `openclaw-gateway-chunyan`
- ✅ 最小实呼当前已返回：
  - `CHUNYAN_REVIVED_OK`
  且返回元数据确认本次实际走了：
  - `provider = minimax`
  - `model = MiniMax-M2.5`

### 当前状态
- `chunyan` 当前已重新进入：
  - `active`
  - `ready`
- 飞书日志已恢复到：
  - `client ready`
  - `feishu[chunyan-feishu]: WebSocket client started`
  - `ws client ready`
- 当前模型链路为：
  - 主模型：
    - `zai/glm-5`
  - fallback：
    - `minimax/MiniMax-M2.5`

## 新任务（2026-04-07）：将 `main` 从 npm 全局安装迁到 pnpm 全局安装，并恢复主 Gateway（已完成 ✅）

### 目标
- 将主实例 `main` 的 OpenClaw 安装方式从：
  - `npm -g`
  切到：
  - `pnpm -g`
- 保留：
  - `~/.openclaw/`
  下所有配置与 workspace 数据
- 保留安装目录中的 Markdown 文档
- 让：
  - `openclaw-gateway`
  恢复正常启动

### 当前进展
- ✅ 已确认今天用户触发的自更新失败根因是：
  - `npm i -g openclaw@latest`
  在替换全局目录时命中：
  - `ENOTEMPTY: rename '/usr/lib/node_modules/openclaw'`
- ✅ 已确认失败后现场一度进入：
  - 旧 gateway 进程仍活着
  - 但磁盘上的：
    - `/usr/bin/openclaw`
    - `/usr/lib/node_modules/openclaw`
    已消失
- ✅ 已先用 npm 把 CLI 临时装回到：
  - `OpenClaw 2026.4.5`
- ✅ 已备份：
  - `~/.openclaw/openclaw.json`
  - `~/.config/systemd/user/openclaw-gateway.service`
  - 旧 npm 安装里的全部 Markdown 文件清单与压缩包
- ✅ 备份目录：
  - `~/.openclaw-backups/pnpm-migration-20260407-172924`
- ✅ 旧 npm 安装中统计到 Markdown：
  - 总数 `2552`
  - 其中 `node_modules` 子树为 `1476`
- ✅ 已启用：
  - `pnpm 10.33.0`
- ✅ 已完成：
  - `pnpm add -g openclaw@latest`
  - `pnpm approve-builds -g --all`
- ✅ 当前 pnpm 版 OpenClaw 可执行入口为：
  - `/home/kevinlasnh/.local/share/pnpm/openclaw`
- ✅ 已恢复：
  - `/usr/bin/openclaw`
  为稳定 wrapper，转发到 pnpm 入口
- ✅ 已将主实例 systemd 收敛为：
  - `EnvironmentFile=/home/kevinlasnh/.openclaw/.env`
  - `ExecStart=/usr/bin/openclaw gateway run --port 18790`
- ✅ 已重启并实测主实例：
  - `MAIN_LIVE_OK`

### 当前状态
- `main` 当前已改为：
  - pnpm 全局安装
- `openclaw-gateway.service` 当前为：
  - `active`
- 另外三个实例继续运行，且由于：
  - `/usr/bin/openclaw`
  已恢复
  不再处于“下次重启必炸”的状态

## 新任务（2026-04-06）：清理 `main` 的错误 `Image model` 配置，并停用图片模型（已完成 ✅）

### 目标
- 清掉主实例 `main` 里错误的图片 provider / model 配置
- 不再给 `main` 配置任何：
  - `Image model`
- 保持文本主链路继续是：
  - `zai/glm-5.1`
  - `minimax/MiniMax-M2.7`

### 当前进展
- ✅ 已确认上轮中断后：
  - `openclaw-gateway = inactive`
  - 但 live 仍残留错误图片配置：
    - `imageModel = zvision/glm-5v-turbo`
    - `imageFallbacks = [minimax/MiniMax-M2.7]`
- ✅ 已备份：
  - `~/.openclaw/openclaw.json.pre-image-clean-20260406-133724`
  - `~/.openclaw/agents/main/agent/models.json.pre-image-clean-20260406-133724`
- ✅ 已删除：
  - `agents.defaults.imageModel`
  - `models.providers.zvision`
  - 以及历史脏别名：
    - `zaivision`
    - `zai-vision`
- ✅ 已将：
  - `agents.defaults.models`
  收敛为：
  - `zai/glm-5.1`
  - `minimax/MiniMax-M2.7`
- ✅ 已删除 agent 侧：
  - `models.json`
  让其按新配置重建
- ✅ 已重启：
  - `openclaw-gateway`
- ✅ 已通过文本最小实呼：
  - `MAIN_IMAGE_CLEARED_OK`

### 当前状态
- `main` 当前：
  - `imageModel = null`
- 后续如果还要做图片识别：
  - 改走单独 GLM MCP
  - 不在这次任务里继续处理

## 新任务（2026-04-05）：`main` 切到 `MiniMax-M2.7` 单模型 + 收敛本机 SSH config + 审计 workspace Markdown 职责

### 目标
- 主实例 `main` 切到：
  - `minimax/MiniMax-M2.7`
- 强约束：
  - 只保留一个主模型
  - `fallbacks = []`
- 同时：
  - 清理本机 `~/.ssh/config` 中混乱的 OpenClaw host alias
  - 按 OpenClaw 官方模板核对 `workspace` Markdown 文件职责

### 当前进展
- ✅ 已确认远端当时 live 配置仍是：
  - `openai-codex/gpt-5.4`
  - `fallbacks = []`
- ✅ 已确认：
  - `MINIMAX_API_KEY` 仍在主实例 `.env`
- ✅ 已改写：
  - `~/.openclaw/openclaw.json`
  为：
  - `primary = minimax/MiniMax-M2.7`
  - `fallbacks = []`
- ✅ 已通过：
  - `openclaw config validate`
- ✅ 已重启主 Gateway，并实呼返回：
  - `MAIN_M27_OK`
- ✅ 已重写本机：
  - `C:\Users\kevinlasnh\.ssh\config`
  只保留：
  - `100.97.227.24`
  - `openclaw`
  - `openclaw-fallback`
- ✅ 已完成第一轮 `workspace` 职责审计
- ✅ 已按用户最新决定，先清空：
  - `~/.openclaw/workspace/memory/`
  下全部非日记 Markdown
- ✅ 当前 `memory/` 已只剩：
  - `YYYY-MM-DD.md`
  - `episodic/*.json`
  - `last-boot.txt`
- ✅ 已重写：
  - `~/.openclaw/workspace/TOOLS.md`
  为短版 live 工具约定
- ✅ 已统一：
  - `~/.openclaw/workspace/IDENTITY.md`
  - `~/.openclaw/workspace/SOUL.md`
  的主身份口径
- ✅ `IDENTITY.md` 当前已收敛为：
  - 花园多惠身份卡
- ✅ `SOUL.md` 当前已收敛为：
  - 花园多惠人格文件
  - 并保留用户明确要求的聊天语气与性格
- ✅ 已停用：
  - `~/.openclaw/workspace/BOOT.md`
  对应的启动职责
- ✅ 当前状态是：
  - `BOOT.md` 文件已清空
  - `hooks.internal.entries.boot-md.enabled = false`
- ✅ 已重写：
  - `~/.openclaw/workspace/USER.md`
  为标准用户画像文件
- ✅ 当前 `USER.md` 已只保留：
  - 用户身份
  - 称呼方式
  - 时区
  - 长期偏好与背景
- ✅ 已重写：
  - `~/.openclaw/workspace/AGENTS.md`
  为瘦身后的工作规则文件
- ✅ 当前 `AGENTS.md` 已只保留：
  - startup
  - memory 使用规则
  - 安全边界
  - 文件职责
  - 说话规则
  - tools 原则
  - 简短 heartbeat 规则
- ✅ 已重写：
  - `~/.openclaw/workspace/MEMORY.md`
  为长期记忆文件
- ✅ 已完成 dated 内容下沉：
  - 从旧 `MEMORY.md` 迁回 5 个对应的 daily memory 文件
- ✅ 当前 `MEMORY.md` 已只保留：
  - 长期偏好
  - 长期事实与约定
  - 长期项目与决定
- ⚠️ 当前尚未落地的整理动作：
  1. 继续按用户节奏逐个复核其余 workspace Markdown

## 新任务（2026-04-03）：评估将 `main` 切到 `api.nih.cc` 的 `anthropic/claude-sonnet-4.6-thinking`（暂缓，未落地）

### 目标
- 将主实例 `main` 当前聊天模型从：
  - `openai-codex/gpt-5.4`
  切到：
  - `https://api.nih.cc`
  - `anthropic/claude-sonnet-4.6-thinking`
- 只保留一个模型：
  - 无 fallback
- 不改动：
  - `dayong`
  - `chunyan`
  - `zenglan`

### 当前进展
- ✅ 已确认用户指定的是：
  - **Anthropic 模型**
  - 但接入方式是：
    - `api.nih.cc` 提供的 OpenAI 兼容 API
- ✅ 已确认 `main` 当前 live 仍是：
  - `openai-codex/gpt-5.4`
  - `fallbacks = []`
- ✅ 已确认 OpenClaw `2026.4.1` 当前仍支持：
  - `models.providers.<provider>`
  的自定义 provider 写法
- ✅ 已确认 `https://api.nih.cc/v1/models` 可访问
  - 且确实列出：
    - `anthropic/claude-sonnet-4.6-thinking`
- ✅ 已对目标模型做最小实呼探测：
  - `POST https://api.nih.cc/v1/chat/completions`
  - `model = anthropic/claude-sonnet-4.6-thinking`
- ✅ 已坐实当前失败表现：
  - HTTP 返回：
    - `500`
  - 响应体包含上游错误：
    - `Cursor API 错误: HTTP 403`
- ✅ 已交叉验证同站其他 Anthropic 变体：
  - `anthropic/claude-sonnet-4`
  - `anthropic/claude-sonnet-4.6`
  - 当前也同样失败
- ✅ 已交叉验证该站并非整体不可用
  - 以下模型在同一把 key / 同一 base URL 下可正常返回：
    - `z-ai/glm5`
    - `deepseek-ai/deepseek-v3.2`
    - `moonshotai/kimi-k2.5`
- ✅ 用户本轮最终决定：
  - 先不切生产模型
  - 仅记录进度

### 当前结论
- 截至 `2026-04-03` 本轮实测：
  - **不能仅凭 `v1/models` 列出模型，就判定该模型可用**
- `api.nih.cc` 当前这条：
  - `anthropic/claude-sonnet-4.6-thinking`
  对本项目这次使用的 key / 路由，尚不能稳定实呼
- 因此本轮不应贸然把 `main` 切过去
- `main` 当前继续保持：
  - `openai-codex/gpt-5.4`
  - `fallbacks = []`

### 可选下一步
1. 若继续使用 `api.nih.cc`：
   - 优先改试已验证可用的单模型：
     - `z-ai/glm5`
     - `deepseek-ai/deepseek-v3.2`
     - `moonshotai/kimi-k2.5`
2. 若仍坚持：
   - `anthropic/claude-sonnet-4.6-thinking`
   则需等该站上游权限或路由恢复后，再重新最小实呼验证

## 新任务（2026-04-02）：仅为 `main` 接入 OpenAI Codex / GPT-5.4（已完成 ✅）

### 目标
- 只给主实例 `main` 接入：
  - `openai-codex/gpt-5.4`
- 不改动：
  - `dayong`
  - `chunyan`
  - `zenglan`
- 优先复用本机现成的 Codex / ChatGPT 登录态，避免额外手工 OAuth

### 当前进展
- ✅ 已确认：
  - `ChatGPT Plus` 不能直接当作 `OpenAI Platform API` 配额使用
  - 如果要“直接用订阅”，应走 OpenClaw 的：
    - `openai-codex`
- ✅ 已确认：
  - `main` 当前 live 主模型为：
    - `minimax/MiniMax-M2.7`
  - `main` 的：
    - `~/.openclaw/agents/main/agent/auth-profiles.json`
    当前为空
- ✅ 已确认本机存在：
  - `C:\Users\kevinlasnh\.codex\auth.json`
  - 且 `auth_mode = chatgpt`
- ✅ 已确认远端当前缺失：
  - `~/.codex/auth.json`
- ✅ 用户已明确：
  - 这次**只改 `main`**
- ✅ 已将本机现成登录态复制到远端：
  - `~/.codex/auth.json`
- ✅ 已向 `main` 的认证存储写入：
  - `openai-codex:codex-cli`
- ✅ 已将 `main` 的模型配置收敛为：
  - `primary = openai-codex/gpt-5.4`
  - `fallbacks = []`
- ✅ 已将 `agents.defaults.models` 收敛为仅保留：
  - `openai-codex/gpt-5.4`
- ✅ 已清空旧的 provider 留存：
  - `models.providers = {}`
- ✅ 最小实呼验收通过：
  - `MAIN_GPT54_OK`
- ✅ 本轮顺手修复了 `doctor --fix` 带来的 Telegram webhook 错位：
  - `127.0.0.1:8787` 已恢复监听
  - Telegram 官方 webhook 已恢复注册

### 可选下一步
1. 若用户要启用语义记忆搜索的远程 embedding：
   - 选择 `local` / `gemini` / `openai`
2. 若选 `openai`：
   - 需要单独配置真实 `OPENAI_API_KEY`
   - 不能复用 ChatGPT Plus / Codex OAuth
3. 若不想新增 API 费用：
   - 优先评估 `memorySearch.provider = local`

## 新任务（2026-04-02）：为 `main` 配本地 Memory Search，并避免长期占满 GPU（已完成 ✅）

### 目标
- 只给 `main` 配本地语义搜索
- 不增加 OpenAI / Gemini API 成本
- 模型直接在远端电脑下载
- 让语义搜索恢复可用，同时不要长期压满 `RTX 3060 6GB`

### 当前进展
- ✅ 已完成远端本地模型下载：
  - `/home/kevinlasnh/.cache/openclaw/models/v5-small-retrieval-Q8_0.gguf`
- ✅ 已将 `main` 的 `memorySearch` 切到：
  - `provider = local`
  - `fallback = none`
  - `local.modelPath = /home/kevinlasnh/.cache/openclaw/models/v5-small-retrieval-Q8_0.gguf`
- ✅ 已确认 Jina 小模型在 OpenClaw 默认实现下仍会自动吃 GPU，不能仅靠“换小模型”解决显存占用
- ✅ 已在 OpenClaw 本地 embedding provider 上打 CPU-only 最小补丁：
  - `getLlama({ gpu: false, ... })`
- ✅ 已重启 `openclaw-gateway`
- ✅ 已通过最小语义搜索验收：
  - `MEMORY_JINA_OK_1`
  - `MEMORY_JINA_OK_2`
  - `MEMORY_JINA_CPU_OK_1`
- ✅ 已确认补丁后 GPU 显存回落：
  - `12MiB / 6144MiB`

### 当前结论
- `main` 当前本地语义搜索已经可用
- 且不再像之前那样长期吃掉约 `5.5GB` 显存
- 当前方案比 `Qwen 4B` 更适合这台机器长期常驻

## 新任务（2026-04-01）：更新 `openclaw-24x7` 机场订阅为 AnyTLS 并恢复 Telegram 主链路（已完成 ✅）

### 目标
- 将 `openclaw-24x7 (100.64.65.65)` 上已失效的旧机场订阅替换为用户提供的新链接
- 恢复 `127.0.0.1:7897` 代理出站
- 验证主小龙虾的 Telegram / OpenClaw 主链路恢复

### 执行结果
- ✅ 确认新链接 `/dy/38573b1cc7d2f79b9c61e3f7d0847f0d` 可访问，返回的是 base64 编码的 `anytls://` 节点列表，不再是旧的 Clash YAML / SS 节点
- ✅ 已备份并更新：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles.yaml`
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles/RvqAWZAlhNcf.yaml`
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml`
- ✅ 已将 54 个可用节点从旧 `ss` 转为新 `anytls` 配置写回运行配置
- ✅ 已通过：
  - `verge-mihomo -t -f .../clash-verge.yaml`
  配置校验，并已重启 `mihomo-standalone`
- ✅ 代理链路验收：
  - Telegram = `200`
  - Google = `204`
  - Brave = `200`
- ✅ OpenClaw 主链路验收：
  - `openclaw agent --agent main` 返回 `TG_PROXY_REFRESH_OK`
  - `openclaw message send --channel telegram ...` 成功，`messageId=14120`

### 当前结论
- `openclaw-24x7` 当前已经切到新的 AnyTLS 订阅，主 Telegram 小龙虾恢复正常出站
- `openclaw gateway health --json` 本轮仍可能出现本地 loopback websocket `gateway closed (1000)` 的诊断噪声，但不影响实际消息发送与 agent 调用

## 新任务（2026-03-17）：`spark-f153` 收工断链与安全收尾（部分完成）

### 目标
- 终止对 `spark-f153` 的继续维护
- 优先保证客户不能再通过原有 Tailscale 路径回连本机
- 如条件允许，再清掉远端维护痕迹

### 当前进展
- ✅ 本机应急阻断已完成：
  - 管理员 PowerShell 已执行：
    - `spark_f153_emergency_local_block.ps1`
  - Windows 防火墙当前已存在：
    - `Block spark-f153 Tailscale Inbound`
    - `Block spark-f153 Tailscale Outbound`
- ✅ Tailnet 侧断链已完成：
  - 用户已在 Tailscale `Machines` 页面删除：
    - `spark-f153`
  - 本机 `tailscale status` 复核时已不再显示该设备

### 剩余未完成项
- ⚠️ 远端硬清理仍待执行：
  - `spark_f153_security_cleanup_hard.sh`
- 阻塞原因：
  - `spark-f153` 当前不可达
  - 无法远端登录执行删除操作

### 当前结论
- 就“防止客户再通过当前这条内网穿透路径回连本机”这一目标看，已经完成。
- 就“把客户机上的维护痕迹彻底抹掉”这一目标看，仍需等待该机器未来再次上线后补跑远端清理。

## 新任务（2026-03-17）：`spark-f153` 切回 Kimi 并打通 Kimi Web Search（已完成 ✅）

### 目标
- 把 `spark-f153` 当前生产主模型从本地 `ollama/qwen3-openclaw:30b` 切回：
  - `moonshot/kimi-k2.5`
- 不只是切模型。
- 还要验证：
  - 小龙虾在 `Kimi provider` 下能够实际执行一次 `web_search`

### 执行结果
- ✅ 新增并执行：
  - `spark_f153_switch_to_kimi_and_verify_web_search.sh`
- ✅ 已将远端主模型切回：
  - `primary = moonshot/kimi-k2.5`
  - `fallbacks = [moonshot/kimi-k2-turbo-preview, moonshot/moonshot-v1-auto]`
- ✅ 已显式配置：
  - `tools.web.search.provider = kimi`
  - `tools.web.search.kimi.apiKey = ${MOONSHOT_API_KEY}`
  - `tools.web.search.kimi.baseUrl = https://api.moonshot.cn/v1`
  - `tools.web.search.kimi.model = moonshot-v1-128k`
- ✅ 已重启：
  - `openclaw-gateway`

### 验收结果
- ✅ Provider 探测：
  - 返回 `KIMI_PROVIDER_OK`
  - 元数据确认：
    - `provider = moonshot`
    - `model = kimi-k2.5`
- ✅ 第一轮 `web_search` 从原先的：
  - `401 Invalid Authentication`
  修到：
  - 工具实际执行成功
- ✅ 第二轮最终验收：
  - 查询：`Python official website`
  - 小龙虾返回：
    - `KIMI_WEB_SEARCH_OK`
    - `python.org`

### 当前意义
- `spark-f153` 现在已经回到：
  - **Kimi 主链路**
- 并且不是纸面可用，而是已经通过：
  - **小龙虾 -> Kimi provider -> web_search -> 返回来源域名**
  的真实验收。

## 新任务（2026-03-17）：为 `spark-f153` 注入 `Kronos` 强提示词到灵魂文档（已完成 ✅）

### 目标
- 不只是“装上 `kronos-skill`”。
- 还要让 `spark-f153` 的交易人格在遇到：
  - 未来几根 K 线预测
  - 方向概率
  - 波动区间
  - 路径分叉
  这类问题时，**默认优先想到 `kronos-skill`**。

### 执行结果
- ✅ 新增并执行：
  - `spark_f153_inject_kronos_soul_prompt.sh`
- ✅ 已把 `Kronos` 强提示词注入远端：
  - `~/.openclaw/workspace/SOUL.md`
  - `~/.openclaw/workspace/AGENTS.md`
  - `~/.openclaw/workspace/TOOLS.md`
- ✅ 注入内容覆盖：
  - `Kronos Instinct`
  - `Kronos Discipline`
  - `Kronos Priority`
  - `Kronos Skill Priority`
- ✅ 已重启：
  - `openclaw-gateway`
- ✅ 验收结果：
  - 对“预测未来 24 根 K 线该怎么做”的最小探测回复已经直接指向：
    - `kronos-skill`

### 当前意义
- `spark-f153` 现在不只是“有一个 Kronos skill 可用”。
- 它的交易人格已经被显式拉向：
  - **预测类请求先想 Kronos**
  - **没跑 skill 就别装作跑过**
  - **把 Kronos 结果翻译成交易语言**

## 新任务（2026-03-17）：为 `spark-f153` 直接交付 `qwen3:30b` 本地生产模型（已完成 ✅）

### 目标
- 不再停留在“推荐模型”
- 直接把：
  - `qwen3:30b`
  下载到客户机
- 创建适配 OpenClaw 的：
  - `qwen3-openclaw:30b`
- 接回小龙虾主链路
- 做真实验收，确认不是“模型在机器上，但小龙虾还没用上”

### 执行结果
- ✅ 已修正通用部署脚本并新增：
  - `spark_f153_enable_local_qwen3_30b_openclaw.sh`
- ✅ 远端实际完成：
  - `ollama pull qwen3:30b`
  - `ollama create qwen3-openclaw:30b`
  - OpenClaw 配置切主模型
  - Gateway 重启
- ✅ 当前 live 配置：
  - `primary = ollama/qwen3-openclaw:30b`
  - `fallbacks = [moonshot/kimi-k2.5, moonshot/kimi-k2-turbo-preview, moonshot/moonshot-v1-auto]`
- ✅ 当前实呼验收：
  - 普通输入正常
  - 飞书式输入仿真正常
  - 元数据均显示：
    - `provider = ollama`
    - `model = qwen3-openclaw:30b`

### 当前意义
- `spark-f153` 现在已经不再依赖纯云模型主链路。
- 当前这台客户机已经具备：
  - **本地 `qwen3:30b` 生产可用**
  - **Kimi 保留为 fallback**
  的双保险结构。

## 新任务（2026-03-17）：处理 `spark-f153` 本地 LLaMA 导致的 `NO_REPLY`（已完成 ✅）

### 目标
- 用户反馈：
  - 飞书上现在发任何消息都只回 `NO_REPLY`
- 需要判断是不是本地 LLaMA 上线后引入的新故障
- 若确认是生产主模型问题，则优先恢复客户可用性

### 执行结果
- ✅ 已确认：
  - 飞书入站正常
  - Gateway 正常
  - `Ollama` 本体正常
- ✅ 已确认真正根因：
  - `ollama/llama3.1-openclaw:8b`
    在当前工作区 + skills + tools 生产环境里，会误走：
    - `sessions_send`
    - `NO_REPLY`
    - JSON 结构化假回复
- ✅ 已将生产主模型切回：
  - `moonshot/kimi-k2.5`
- ✅ 已恢复 fallback：
  - `moonshot/kimi-k2-turbo-preview`
  - `moonshot/moonshot-v1-auto`
- ✅ 已把被污染的 Feishu 直聊 session 文件移走备份
- ✅ 已重启 Gateway 并完成两轮验收：
  - 普通最小实呼恢复正常
  - 飞书式输入仿真恢复正常

### 当前意义
- `spark-f153` 现在的生产链路已经重新可用。
- 本地 LLaMA 基础设施保留，但**不再作为当前生产主模型**。
- 后续若继续推进本地模型，需要先走：
  - 更强模型
  - 或更轻 prompt / skills / tools 面
  的新方案。

## 新任务（2026-03-17）：修复 `spark-f153` 的代理环境，供 Ollama / 模型下载使用（已完成 ✅）

### 目标
- 让客户机桌面上已开启的代理，不只对 GUI 生效。
- 进一步打通：
  - shell 下载
  - user systemd 服务下载
  - 后续 `Ollama` / `ollama pull`

### 执行结果
- ✅ 已定位本地代理入口：
  - `127.0.0.1:7897`
  - 进程：
    - `clash-verge`
    - `verge-mihomo`
- ✅ 已确认 GNOME 当前桌面代理也是：
  - `manual -> 127.0.0.1:7897`
- ✅ 已新增并执行：
  - `spark_f153_fix_proxy_env.sh`
- ✅ 已写入：
  - `~/.config/environment.d/90-proxy.conf`
  - `~/.config/openclaw/proxy.env`
  - `~/.proxy.env`
- ✅ 已把代理变量导入当前：
  - shell
  - `systemd --user`
- ✅ 连通性验证通过：
  - `ollama.com` 下载地址经代理返回 `200`
  - GitHub release 资产地址经代理返回 `200`
  - 证据是：
    - `remote_ip = 127.0.0.1`
- ✅ 本地 Llama 安装脚本也已同步改为：
  - 自动加载 `proxy.env`
  - 让 `ollama-user.service` 也继承该代理环境

### 当前意义
- 现在的阻断点已经从“机器不会用代理下载”转移为：
  - 只剩实际下载耗时与会话稳定性
- 换句话说：
  - **代理环境这一层已经收口完成**

## 新任务（2026-03-17）：三套非主 Gateway 切到 `MiniMax-M2.5`（已完成 ✅）

### 目标
- 不动主实例
- 先核实另外三个小龙虾当前 live 模型
- 再把：
  - `dayong`
  - `chunyan`
  - `zenglan`
  统一切到：
  - `minimax/MiniMax-M2.5`
- 完成后重启并验收

### 执行结果
- ✅ 切换前 live 状态确认：
  - 三套非主实例都在跑：
    - `newcli/claude-sonnet-4-6`
- ✅ 三套切换时并不是“只改 primary 就行”：
  - 各自 `.env` 里缺 `MINIMAX_API_KEY`
  - `chunyan / zenglan` 的 agent `models.json` 缺 `minimax`
- ✅ 已从主实例提取当前 live `minimax` provider 与 `MINIMAX_API_KEY`
- ✅ 已写入三套非主实例：
  - `openclaw.json`
  - `.env`
  - `agents/*/agent/models.json`
- ✅ 三套静态校验全部通过
- ✅ 三套 Gateway 已重启成功
- ✅ 三套实呼元数据全部确认：
  - `provider = minimax`
  - `model = MiniMax-M2.5`
- ✅ 主实例保持不变：
  - `primary = newcli/claude-sonnet-4-6`
  - `openclaw-gateway.service` 未重启

### 备份记录
- 统一备份后缀：
  - `.pre-minimax-m25-20260317-120429`

## 新任务（2026-03-16）：`spark-f153` 远端接入、修复与安全收工

### 目标
- 通过 Tailscale + SSH 打通到第三方 Ubuntu 主机 `spark-f153`
- 修复该主机上的 OpenClaw Gateway 故障
- 在维护结束后，提供一套“尽量不留痕迹”的安全收工流程

### 当前状态

| 项目 | 状态 |
|------|------|
| 远端 Ubuntu 环境采集 | ✅ 已完成 |
| 远端 Tailscale 安装 | ✅ 已完成（snap） |
| 远端加入用户 tailnet | ✅ 已完成 |
| 本机到远端 Tailscale ping | ✅ 已完成 |
| 本机到远端 SSH 直连 | ✅ 已完成 |
| `openclaw-gateway` 重启风暴根因定位 | ✅ 已完成 |
| 根因 | ✅ `~/.openclaw/openclaw.json` JSON5 语法损坏 |
| 客户机自有 Kimi API key 接入 | ✅ 已完成 |
| 股票人格 Markdown 全量重写 | ✅ 已完成 |
| Feishu 通道配置 | ✅ 已完成 |
| 主模型回归实呼 | ✅ 已完成 |
| 2026-03-17 早晨现状复核 | ✅ 已完成 |
| 当前服务稳定性复核 | ✅ `active/running`，`NRestarts=0` |
| 当前主阻断：OpenClaw 表面 `rate_limit` | ✅ 已确认 |
| 当前真正根因：Moonshot 余额不足 / 账号 suspend | ✅ 已确认 |
| Feishu 脏配置项复核 | ✅ 已处理：`default` 伪账号已移除 |
| 密钥注入方式复核 | ✅ 已处理：改为 `.env` + `EnvironmentFile` |
| 充值后恢复验证 | ✅ 已完成：`128k` / `auto` 已恢复 |
| 直连国内网复核 | ✅ 已完成：运行时代理变量已清空 |
| Kimi 主模型切换 | ✅ 已完成：`primary = moonshot/kimi-k2.5` |
| Kimi 直连 API 验收 | ✅ 已完成：`/v1/models` / `kimi-k2.5` 均 `200` |
| 安全收工脚本 | ✅ 已新增 |

### 当前结论
1. `spark-f153` 当前已经可从本机通过：
   - Tailscale IP `100.74.98.13`
   - SSH 用户 `admin`
   直接连接。
2. 远端 OpenClaw 已从“配置损坏 + 无模型凭据 + 无通道配置”恢复到：
   - 主模型：`moonshot/kimi-k2.5`
   - 图像模型：`moonshot/moonshot-v1-128k-vision-preview`
   - 通道：`Feishu stock-desk`
   - 工作区：已注入 A 股交易台人格与 `SKPARK` 框架
3. 本轮明确遵守了新的安全边界：
   - **没有**把用户自己机器上的 API key 搬到客户机
   - 使用的是客户机自己的 Kimi API 平台 key
4. 当前高优先级安全边界也已经收敛：
   - 收工后仅删远端 `authorized_keys` 不够
   - 还需退出/卸载 Tailscale，并在必要时撤销或轮换 reusable auth key
5. `spark-f153` 当前维护入口仍然存在：
   - 仍在用户 tailnet 中
   - 本机 SSH 公钥仍有效
   - 说明安全收工动作尚未执行
6. 当前新的第一优先级故障不是配置损坏，而是：
   - OpenClaw 表面看是：
     - `moonshot/moonshot-v1-128k`
     - `moonshot/moonshot-v1-auto`
     都返回 `rate_limit`
   - 但上游直测已经确认：
     - `/v1/models = 200`
     - 三个模型最小实呼都返回：
       - `429 exceeded_current_quota_error`
       - `suspended due to insufficient balance`
   - 因此现在“通道可达”不等于“客户发消息就能正常回复”
   - 真正要修的是**客户 Moonshot 余额/配额**，不是配置本体
7. 当前还确认了两个次级但真实存在的问题：
   - Feishu 残留 `default` 伪账号，持续产生 doctor warning
   - 模型密钥和主配置混在一起，后续维护与轮换不够干净
   - 这两项现在都已经收口完成
8. `2026-03-17 15:00` 后再次复核：
   - 官方 `/v1/models = 200`
   - `moonshot-v1-128k = 200`
   - `moonshot-v1-auto = 200`
   - `openclaw agent --agent main` 已成功返回 `RECHARGE_OK`
   - 当前状态已从“完全不可用”恢复到“基本可用”
9. `2026-03-17 15:17` 后再次切换与验收：
   - systemd drop-in 已显式清空所有代理变量
   - `openclaw-gateway.service` 当前运行时不继承代理环境
   - 官方 `kimi-k2.5` 在无代理环境下直测返回 `200`
   - Gateway 级最小实呼已返回：
     - `DIRECT_GATEWAY_KIMI_OK`
   - 当前主链路已经变成：
     - **直连国内网 + Kimi 主回复链路**

### 下一步
1. 当前直接做飞书真实对话验收。
2. 如果后续还要换 key，直接使用：
   - `spark_f153_set_moonshot_key.sh`
3. 若再次怀疑额度/引擎状态，先跑：
   - `spark_f153_probe_moonshot_api.sh`
4. 收工时远端运行：
   - `spark_f153_security_cleanup_hard.sh`
5. 若用户要求最高安全等级，再额外在：
   - `https://login.tailscale.com/admin/settings/keys`
   对 reusable auth key 做 `revoke` 或 `rotate`
6. 后续若用户要继续强化“炒股味”，可再细调：
   - `SOUL.md`
   - `AGENTS.md`
   - `SKPARK.md`
   - `WATCHLIST.md`
7. 已新增一个新的待办事实：
   - 飞书 `typingIndicator` 已开启
   - 当前 `hi/1111/11111` 这类低信息量消息会在 Feishu 会话里被模型主动输出 `NO_REPLY`
   - 若用户要求“连 Hi 都必须回”，下一步应修改工作区提示词或会话规则，去掉该静默行为
8. 上述待办现已完成：
   - 本地 zip 技能已安装到远端
   - `feishu-file-uploader` 已进入运行时技能列表
   - `AGENTS.md` / `HEARTBEAT.md` 已新增直接聊天覆盖规则
   - Feishu 私聊里的 `NO_REPLY` 静默行为已被压掉

## 新任务（2026-03-16）：定位四 Gateway 统一切到 `newcli/claude-sonnet-4-6` 所需配置

### 目标
- 找出用户此前已配置过的 `newcli` Sonnet 4.6 模型信息。
- 确认：
  - provider 定义在哪个实例、哪个文件
  - `baseUrl` 是什么
  - token 目前存放在 `.env`、`openclaw.json` 还是 `models.json`
- 判断四个 Gateway 是否已经都具备切到 `newcli/claude-sonnet-4-6` 的前提。

### 当前状态

| 项目 | 状态 |
|------|------|
| `CLAUDE.md` / `findings.md` / `progress.md` 预读 | ✅ 已完成 |
| `planning-with-files` session catchup | ✅ 已完成 |
| 远端四个 `openclaw.json` 模型段复核 | ✅ 已完成 |
| 远端四个 `agents/*/agent/models.json` 复核 | ✅ 已完成 |
| 远端四个 `.env` 键名复核 | ✅ 已完成 |
| 主实例历史 `openclaw.json*` 备份复核 | ✅ 已完成 |

### 当前结论
1. 四个 Gateway 已全部切到：
   - `newcli/claude-sonnet-4-6`
2. 四个 Gateway 当前都已显式配置：
   - `fallbacks = []`
3. `newcli` 的 `baseUrl` 统一为：
   - `https://code.newcli.com/claude`
4. 四套 `.env` 已全部补齐：
   - `NEWCLI_API_KEY`
5. 四个 Gateway 已全部重启并完成网关级验证。

### 关键发现
1. 本轮统一修改了 3 类文件：
   - 四套 `openclaw.json`
   - 四套 `.env`
   - 四个 agent 的 `models.json`
2. 统一动作包括：
   - 新增或规范 `models.providers.newcli`
   - 将 `agents.defaults.model.primary` 改为 `newcli/claude-sonnet-4-6`
   - 将 `agents.defaults.model.fallbacks` 显式清空
   - 将 agent 层 `models.json` 的 `newcli.apiKey` 统一改为环境变量名 `NEWCLI_API_KEY`
3. 备份后缀统一为：
   - `.pre-sonnet46-20260316-094510`
4. 切换前嵌入式实呼验证通过：
   - `MAIN_SONNET_PRECHECK`
   - `DAYONG_SONNET_PRECHECK`
   - `CHUNYAN_SONNET_PRECHECK`
   - `ZENGLAN_SONNET_PRECHECK`
5. 重启后网关级验证也通过：
   - `MAIN_SONNET_GATEWAY_OK`
   - `DAYONG_SONNET_GATEWAY_OK`
   - `CHUNYAN_SONNET_GATEWAY_OK`
   - `ZENGLAN_SONNET_GATEWAY_OK`
6. 四个 Gateway 重启时间已统一为：
   - `2026-03-16 09:47:48 CST`

### 下一步
1. 本轮用户目标已完成。
2. 会话层遗留的旧 `256K/262144` 状态缓存也已一并修复。
3. 后续若要回滚，可直接使用本轮备份文件恢复。
4. 后续若用户要改到别的统一模型，可复用这次的四套 provider 归位结构和 `sessions.json` 清理方法。
5. 2026-03-16 上午补充审计已确认：
   - Sonnet 4.6 参数已全部对齐
   - 四 Gateway 当前无阻断性故障

## 新任务（2026-03-15）：VS Code Remote SSH 到 `openclaw` 变慢 / 超时诊断

### 目标
- 定位为什么 VS Code 连接 `Host openclaw` 很慢。
- 区分：
  - SSH 本身慢
  - VS Code Remote SSH 自己慢
  - 还是 Tailscale peer 链路不稳

### 当前状态

| 项目 | 状态 |
|------|------|
| `CLAUDE.md` / `findings.md` / `progress.md` 预读 | ✅ 已完成 |
| 本机 `~/.ssh/config` 检查 | ✅ 已完成 |
| 本机 VS Code Remote SSH 日志检查 | ✅ 已完成 |
| 本机命令行 SSH 基准 | ✅ 已完成 |
| 本机 Tailscale 状态 / netcheck / ping | ✅ 已完成 |
| 远端 shell / VS Code Server 读取 | ⚠️ 未完成（排查中途 peer 已超时） |

### 当前结论
1. 纯命令行 SSH 认证不是主慢点。
2. VS Code 确实存在额外 bootstrap / exec server / reconnection 开销。
3. 但更大的问题是：
   - `openclaw-24x7` 这条 Tailscale peer 链路当前可复现超时。
4. 因此这不是单纯改一个 VS Code 设置就能根治的事。

### 下一步
1. 等 `openclaw-24x7` 恢复可达后，到远端补查：
   - `tailscale status`
   - `tailscale ping desktop-jrvidlh`
   - `tailscale netcheck`
   - `systemctl status tailscaled`
2. 若远端确认长期只能走 `DERP(hkg)`，优先排 direct path 问题。
3. 本地可做的低风险缓解：
   - `ServerAliveInterval 30`
   - `ServerAliveCountMax 3`
4. 若链路恢复后仍主要卡在 VS Code 侧，再测试：
   - `remote.SSH.useExecServer = false`

### 追加结论（综合调研后）
1. 这个问题已经从“为什么 VS Code 比 terminal SSH 慢”收敛为：
   - **底层长期走 `DERP(hkg)`**
   - **上层 `.vscode-server` 的 pty / exec server 又有脏状态**
2. 远端 shell 初始化不是主因。
3. 当前最可能产生明显收益的顺序已经确定：
   - 先争取 direct path
   - 再清远端 VS Code Server
   - 再减默认扩展
   - 最后再做 `useExecServer` 级别的实验

### 追加目标态（若要做“所有 SSH App 都快”的完全修复）
1. 传输层目标：
   - 不再长期走 `DERP(hkg)`
   - 优先 direct，次优 peer relay
2. SSH 服务层目标：
   - 面向全部客户端时，优先标准 `sshd`
   - 不把 Tailscale SSH 当唯一主入口
3. 客户端层目标：
   - VS Code 单独清理 server 脏状态
   - 终端 / SFTP 客户端只保留轻量配置
4. 这意味着完整修复是一个多阶段项目，不是单个 VS Code 设置项

### 追加可部署性判断（当前环境：不能换 Wi‑Fi）
1. **可直接落地**
   - 标准 `sshd` 统一入口
   - VS Code Server 清理与默认扩展减负
   - SSH keepalive
2. **可推进但要额外前提**
   - peer relay / self-relay
   - 需要 tailnet policy 与端口验证
3. **当前不能承诺闭环**
   - 恢复 direct path
4. 当前最现实的方向：
   - 先把“服务层正确 + 客户端兼容”做到位
   - 再尝试用 peer relay 取代 DERP
   - 暂不把“必须 direct”当成本轮可保证完成项

### 追加执行结果（2026-03-15 晚间）：可部署部分已实际落地

#### 已部署
1. **远端新增标准 `sshd over Tailscale` 入口**
   - 新监听地址：`100.64.65.65:2222`
   - 新配置文件：`/etc/ssh/sshd_config_openclaw_2222`
   - 新 systemd 服务：`openclaw-sshd-2222.service`
   - 保持旧入口不动：
     - `Host openclaw`
     - Tailscale SSH / `22`

2. **远端认证与持久化**
   - 将本机 `openclaw_newmachine` 的公钥写入远端 `~/.ssh/authorized_keys`
   - `openclaw-sshd-2222.service` 设为 `enabled`
   - 配置包含：
     - `PasswordAuthentication no`
     - `KbdInteractiveAuthentication no`
     - `AuthenticationMethods publickey`
     - `AllowUsers kevinlasnh`
     - `ClientAliveInterval 30`
     - `ClientAliveCountMax 3`

3. **本机持久配置**
   - `C:\Users\kevinlasnh\.ssh\config`
     - 给旧 `Host openclaw` 补：
       - `ConnectTimeout 5`
       - `ServerAliveInterval 30`
       - `ServerAliveCountMax 3`
       - `TCPKeepAlive yes`
     - 新增 `Host openclaw-sshd`
       - 指向 `100.64.65.65:2222`
       - 使用 `C:/Users/kevinlasnh/.ssh/openclaw_newmachine`
   - VS Code 用户设置新增：
     - `"remote.SSH.remotePlatform": { "openclaw-sshd": "linux" }`

4. **VS Code 会话层清理**
   - 远端旧 `.vscode-server` 进程已清理
   - 下一次 VS Code 连 `openclaw-sshd` 会从干净状态重新拉起

#### 已完成验证
1. **新入口命令行 SSH**
   - 连续 5 次 `ssh openclaw-sshd`
   - 单次耗时约：
     - `4.8s / 4.3s / 2.8s / 3.3s / 3.5s`

2. **旧入口仍可用**
   - 连续 3 次 `ssh openclaw`
   - 单次耗时约：
     - `2.9s / 3.0s / 3.6s`

3. **`scp` / SFTP 语义可用**
   - `scp openclaw-sshd:/etc/hostname ...` 成功

4. **Linux 真重启后的自动恢复**
   - 已执行远端 `sudo reboot`
   - 重启后自动恢复结果：
     - 旧入口恢复约 `32.5s`
     - 新入口恢复约 `34.8s`
   - 重启后复核：
     - `tailscaled = active`
     - `ssh.socket = active`
     - `openclaw-sshd-2222.service = active`
     - `openclaw-sshd-2222.service = enabled`

#### 当前边界
1. **Windows 真重启未在本轮直接执行**
   - 原因：当前会话运行在这台 Windows 机器上，直接重启会中断工作会话
   - 已验证的替代证据：
     - 本机 SSH 配置和 VS Code 配置均为持久文件写入
     - `Tailscale` 服务为 `StartType = Automatic`
2. **本机 `Tailscale` 服务重启未成功模拟**
   - 直接 `Restart-Service Tailscale` 因本地权限不足未完成
   - 但服务当前处于 `Running + Automatic`

### 追加复核（2026-03-15 夜间）：VS Code 现在的实际连接状态
1. 最新一条真正的 VS Code Remote SSH 日志，仍然连接的是旧入口 `openclaw`
2. 这次真实 VS Code 尝试在 `21:59` 发生了：
   - `Connection timed out during banner exchange`
3. 但随后用接近 VS Code 的命令级 bootstrap 复测：
   - `ssh -T -D <port> openclaw sh -lc ...` 连续 5 次成功
   - `ssh -T -D <port> openclaw-sshd sh -lc ...` 连续 5 次成功
4. 当前最合理结论：
   - `openclaw` 仍然有瞬时抖动风险
   - `openclaw-sshd` 是现在更推荐给 VS Code 使用的 Host

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

### 2026-03-10 16:50 即时状态补充

- 主小龙虾本轮用户反馈的“网络抖动后不回消息”，已完成只读复核。
- 当前结论：
  - `Webhook` 正常
  - `Funnel` 正常
  - `Gateway` 正常
  - 更像 `Tailscale / DERP` 瞬时抖动导致入站延后，而不是配置损坏
- 后续观察重点：
  1. 若再次复发，第一时间抓 `getWebhookInfo.pending_update_count`
  2. 同时抓 `journalctl -u tailscaled`
  3. 对比 Telegram 元数据时间和 session 写入时间，判断是否仍是入站延后

### 2026-03-10 17:05 安全面补充

- 已完成当前公网暴露面复核。
- 当前判断：
  - `openclaw-gateway` 本体没有直接绑公网，只绑 `loopback`
  - 但 `Tailscale Funnel` 的 `443/8443` 是有意公开到互联网的
  - 当前最该收紧的不是 OpenClaw 端口，而是 `SSH :22` 的 UFW 规则过宽
- 后续可执行动作：
  1. 若只需要主小龙虾，评估关闭 `8443` 的 dayong Funnel
  2. 将 `22/tcp ALLOW IN Anywhere` 收紧为仅 Tailscale / 局域网来源

### 2026-03-10 17:25 Webhook 安全收口路线补充

- 已完成“继续使用两个 Gateway 的 Webhook，同时收紧整机安全面”的联网调研。
- 当前最优先的实施顺序：
  1. 收紧 `SSH 22`
  2. 评估把两个公网 Funnel 收缩到一个 `443`
  3. 在 loopback 上增加极薄反向代理，只放精确 webhook path
  4. 继续保持 OpenClaw 业务端口全绑 `loopback`
  5. 继续保留 webhook secret
  6. 收窄 Telegram `allowed_updates`

### 2026-03-13 第一阶段已落地

- 已执行：
  - 删除 `22/tcp ALLOW IN Anywhere`
  - 删除 `22/tcp (v6) ALLOW IN Anywhere (v6)`
- 已验证：
  - Tailscale SSH 仍正常
  - Telegram Webhook 仍正常
- 下一步候选：
  1. 第二阶段再收紧 `sshd` 认证项（`PasswordAuthentication no` 等）
  2. 后续再考虑把两个公网 Funnel 收缩为一个 `443`

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

## 已完成（2026-03-10 晚）：Dayong 小龙虾工具执行异常排查 + Kimi 源码补丁 ✅

### 目标
- 查清为什么 `dayong` 小龙虾在 Kimi 模型下经常”说自己执行了工具”，但实际没有真正执行。
- 在**不切换出 Kimi** 的前提下，找出可行修法。

### 最终根因
**OpenClaw 2026.3.7 的已知 Bug**（GitHub Issue #41852，Reddit 确认）：
- `normalizeKimiCodingToolDefinition()` 把 Anthropic 风格工具定义强制转成 OpenAI function 格式
- Kimi API 完全无法识别 OpenAI function 格式的工具定义（`input_tokens` 从 62 降到 21，工具定义被丢弃）
- 导致 Kimi 返回伪工具文本或直接文本回答，OpenClaw 无法执行工具，session 锁文件卡死

### 修复方案
源码补丁：让 `isKimiCodingAnthropicEndpoint()` 直接 `return false`，跳过工具格式转换。

### 修改内容
1. **源码补丁**：10 个文件，每个文件 1 行改动
2. **dayong .env 精简**：删除 `ANTHROPIC_API_KEY`、`ZAI_API_KEY`、`MINIMAX_API_KEY`，只保留 `KIMI_API_KEY`
3. **Session 重置**：清除包含损坏工具调用记录的旧 session
4. **重启 dayong Gateway**（main 未动）

### 验收结果

| 项目 | 状态 |
|------|------|
| Kimi API 直测（Anthropic 格式） | ✅ 返回结构化 `tool_use` |
| 源码补丁（10 个文件） | ✅ 全部应用 |
| dayong 纯 Kimi 化 | ✅ 无其他模型 |
| dayong session 重置 | ✅ 干净启动 |
| 用户实测工具调用 | ✅ 确认正常 |
| main Gateway | ✅ 未受影响 |

### 已知限制
- OpenClaw 升级后补丁会被覆盖，需重打
- 当前共 15 个补丁文件（5 个 stall 检测 + 10 个 Kimi tool format）

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

### capability-only 对齐执行结果（2026-03-10 14:30 CST）

#### 本轮已落地
- **只修改了 `dayong` 这一套**：
  - `~/.openclaw-dayong/workspace/AGENTS.md`
  - `~/.openclaw-dayong/workspace/TOOLS.md`
  - `~/.openclaw-dayong/workspace/MEMORY.md`
  - `~/.openclaw-dayong/workspace/memory/2026-03-10.md`
  - `~/.openclaw-dayong/skills/*`
  - `~/.openclaw-dayong/workspace/skills/*`
- **没有修改 `main` Gateway 配置，也没有修改 `main` workspace。**

#### 本轮效果
| 项目 | 变更前 | 变更后 |
|------|--------|--------|
| `dayong` ready skills | `6/54` | `14/62` |
| `systemPrompt.chars`（旧 `agent:dayong:main`） | `15555` | `19673` |
| `projectContextChars` | `2879` | `6997` |
| 注入 `AGENTS.md` | `164 chars` | `2601 chars` |
| 注入 `TOOLS.md` | `850 chars` | `1814 chars` |
| `MEMORY.md` | 无 | `659 chars` 已注入 |

#### 当前阻塞
- 虽然能力层已经变厚，但 **`agent:dayong:main` 这个旧 session 依然没有把新增 ready skills 一起吃进去**：
  - `openclaw skills` 已显示 `14` 个 ready
  - 但 `systemPromptReport.skills.entries` 仍只有 `4`
- 随机 UUID 硬测试仍未通过：
  - 一次返回 `/exec({"command": "cat /proc/sys/kernel/random/uuid"})`
  - 一次返回明显伪造的固定 UUID：`a8b3c4d5-e6f7-8901-2345-6789abcdef01`

#### 新发现
- `dayong` state 里存在 `~/.openclaw-dayong/workspace-main` 和 `agents/main/`
- 在 **不显式传 `--agent dayong`** 的 CLI 测试里，OpenClaw 会落到 `sessionKey=agent:main:main`
- 这条路径不是我们要验证的 `dayong` 主会话，后续验证必须明确指定：
  - `--agent dayong`
  - 或直接在 Telegram 的 `dayong` 聊天里开启 `/new`

#### 下一步最合理动作
1. 让 `dayong` Telegram 对话先发一次 `/new`
2. 再用随机 UUID 指令复测
3. 如果新会话仍输出伪工具文本，再继续往 session/store 或 provider 兼容层深挖

### dayong 会话层刷新执行结果（2026-03-10 14:35 CST）

#### 本轮已落地
- **仍然只修改 `dayong`**：
  - 备份 `~/.openclaw-dayong/agents/dayong/sessions`
  - 备份目录：`~/.openclaw-dayong/agents/dayong/sessions.backup-20260310-143543`
  - 重建空的 `~/.openclaw-dayong/agents/dayong/sessions`
  - 重启 `openclaw-gateway-dayong`
- **没有修改 `main` Gateway，也没有重启 `main`**。

#### 本轮效果
| 项目 | 结果 |
|------|------|
| `dayong` session 目录 | ✅ 已从旧快照整套切换到新目录 |
| `dayong` 新 `agent:dayong:main` skillsSnapshot | ✅ 已变成 `14` 个 skills |
| `agent:dayong:telegram:dayong-bot:direct:8226087994` | ✅ 当前不存在，说明下一条真实 Telegram 消息会自动新建会话 |
| `main` 服务状态 | ✅ 未受影响，PID / uptime 保持不变 |

#### 关键结论更新
- 之前的主阻塞里，“旧 session 没刷新”这一层已经被切掉。
- 现在更准确的判断是：
  1. `dayong` 的**能力层和 skills 快照已经能进入新会话**
  2. 但 `kimi/k2p5` 在 fresh session 下的执行链仍不稳定，CLI 随机 UUID 硬测出现挂起

#### 下一步最合理动作（更新）
1. 直接给 `dayong` 发一条新的真实 Telegram 消息即可，不必再先 `/new`
2. 用随机 UUID 或 `pwd` 这类必须靠工具才能完成的指令复测
3. 如果 fresh Telegram 会话里仍没有真实 `toolCall`，就把主根因收敛到 `kimi/k2p5` provider/执行链兼容性

### 最新复核结果（2026-03-10 15:24 CST）

#### fresh Telegram 主会话表现
- 真实 Telegram 会话键：`agent:dayong:telegram:dayong-bot:direct:8226087994`
- 新 session id：`d6524ff6-2221-4cae-a421-aecf4143d51f`
- 当前这条真实会话已经不是旧缓存：
  - `systemPrompt.chars = 28973`
  - `projectContextChars = 6997`
  - `skills.entries = 28`
  - tools 列表仍完整包含 `read` / `write` / `edit` / `exec` / `web_search`

#### 用户真实测试结果
- 用户让 `dayong`：
  - “你现在查下今天最新的新闻能上网搜索吗？调用工具给我上网搜索”
- `dayong` 的真实回复只有一句：
  - “好的，小姨爹，我现在帮您搜索今天最新的新闻。让我调用工具来搜索。”
- 随后会话 transcript 中：
  - `toolCall = 0`
  - `toolResult = 0`
  - 没有第二条真正的搜索结果消息

#### 当前最准确结论
- 现在已经**不能再把问题归因于旧 session、旧 skills、或者上下文太薄**。
- 在 fresh Telegram 会话里，`dayong` 仍然只是**口头承诺要调用工具，但没有发出真实结构化 tool call**。
- 因此主根因已经进一步收敛到：
  - `kimi/k2p5` 当前这条 provider/执行链在 `dayong` 上不稳定，至少在工具调用落地这一步明显异常。

### Kimi API 直连探针结果（2026-03-10 15:30 CST）

#### 直接结论
- **Kimi API 本身会正确返回结构化 `tool_use`。**
- 因此现在可以排除：
  - “Kimi 模型/API 根本不会工具调用”
  - “`k2p5` 这个模型天然不支持 tool use”

#### 本轮探针
- 使用 `dayong` 当前 `.env` 中同一份 `KIMI_API_KEY`
- 直接请求：
  - `GET https://api.kimi.com/coding/v1/models`
  - `POST https://api.kimi.com/coding/v1/messages`
- 极简测试 payload：
  - model: `k2p5`
  - 单工具：`echo_tool`
  - 用户提示：必须调用该工具一次

#### 实测结果
- `/v1/models` 返回 `200`
- `/v1/messages` 返回 `200`
- 返回体中出现标准结构：
  - `content[0].type = "tool_use"`
  - `name = "echo_tool"`
  - `stop_reason = "tool_use"`
  - 返回模型名显示为 `kimi-for-coding`

#### 结论更新
- `dayong` 现在的问题，已经不能再归因到“Kimi API 不会调工具”。
- 主根因进一步收敛为：
  - **OpenClaw 这条 `dayong + kimi/k2p5` 运行链路，没有稳定把真实生产请求落成可执行 tool call**
  - 可能是运行时 prompt / session / OpenClaw 接入层与 Kimi 的交互问题，而不是 Kimi API 本身能力缺失

---

## 已完成（2026-03-10 14:05 CST）：仓库 Git 基线初始化 ✅

### 目标
- 让本仓库可以用 `git diff` 精确查看 `findings.md`、`progress.md`、`task_plan.md` 的后续改动。
- 避免继续依赖 `find -mtime 0` 这类只按时间戳筛文件的办法。

### 已完成
| 项目 | 状态 |
|------|------|
| 本地 Git 仓库初始化（`main` 分支） | ✅ 已完成 |
| 增加最小 `.gitignore` | ✅ 已完成 |
| 首次基线提交 | ✅ 已完成 |

### 基线策略
- 当前采用“先建基线，再看增量”的方式。
- 后续最直接的查看命令：
  - `git diff -- findings.md progress.md task_plan.md`

### 说明
- `git diff` 能精确看行级变化，但前提是仓库里已经有 baseline commit。
- 本次已经完成该前置条件，后续可以直接使用。

---

## 只读调研补充（2026-03-10 16:15 CST）：Kimi 工具链根因进一步收敛

### 当前 live 事实校正
- 这次实时扫描发现，**当前这台 WSL 机器的 live 环境与前面文档记录不一致**：
  - 实际存在的是 `~/.openclaw/`
  - 当前没有扫描到独立的 `~/.openclaw-dayong/`
  - `~/.openclaw/openclaw.json` 当前只有一个 `main` agent
  - `openclaw --version` 实时显示的是 `2026.2.26`
- 因此，前文所有 `~/.openclaw-dayong/*`、`openclaw-gateway-dayong.service` 的结论，**本轮不能再当作当前 live 事实**，只能视为历史记录。

### 本轮新增只读证据
1. 使用当前 live 存在的自定义 `kimi/k2p5` 配置，在隔离目录 `/home/kevinlasnh/.cache/oc-kimi-research` 做最小复现：
   - 独立 `OPENCLAW_STATE_DIR`
   - 独立 `OPENCLAW_CONFIG_PATH`
   - 不接 Telegram，不碰 `main`
2. `openclaw agent --local --agent test` 在该隔离环境下：
   - 60 秒超时
   - 但成功写出了 `anthropic-payload.jsonl`
3. payload 关键信息：
   - `provider = kimi`
   - `model = k2p5`
   - `stream = true`
   - `tools = 23`
   - 工具定义是 **Anthropic 风格**（`name + description + input_schema`），不是 OpenAI function wrapper
4. 用 **完全同一份 OpenClaw 真实 payload** 直接请求 `https://api.kimi.com/coding/v1/messages`：
   - `stream = false` 时，Kimi 返回标准 `tool_use(exec)`
   - `stream = true` 时，Kimi 返回标准 Anthropic SSE：
     - `event: content_block_start`
     - `content_block.type = tool_use`
     - `input_json_delta`
     - `message_delta.stop_reason = tool_use`
5. 再按 Anthropic 协议手动补第二轮：
   - 第一轮 assistant `tool_use(exec)`
   - 第二轮 user `tool_result = hello`
   - Kimi 正常返回最终文本 `"hello"`

### 当前最准确结论
- 问题已经可以进一步缩小为：
  - **不是 Kimi API 不支持工具**
  - **不是 OpenClaw 生成的基础 payload 形状完全错误**
  - **不是 Anthropic 风格的 Kimi SSE 流本身不兼容**
- 现在最可疑的是：
  - **OpenClaw 自己在收到 Kimi 的 `tool_use` 流式事件之后，没有把这轮 embedded/tool loop 正常走完**
  - 更像是 `streaming tool-call orchestration` 内部挂住，而不是 provider 请求发错了

### 最值得深挖的代码热点（只读定位）
- `reply-Deht_wOB.js`
  - `handleToolExecutionStart`：约 `69812`
  - `handleToolExecutionEnd`：约 `69894`
  - `createEmbeddedPiSessionEventHandler`：约 `70011`
  - `handleMessageEnd`：约 `69231`
- 这些函数已经在处理：
  - `message_start / message_end`
  - `tool_execution_start / tool_execution_end`
- 下一步修复时，应优先确认：
  1. Kimi `tool_use` SSE 是否被完整转成了 OpenClaw 内部的 `tool_execution_*` 事件
  2. 工具执行完成后，第二轮 `tool_result` 是否真的被重新送回模型
  3. 这条链路是否只有 `stream=true` 时会卡住

### 完整修复方案（先研究，不部署）
1. **先做回归测试基线**
   - 固定使用当前这份最小隔离配置和 `printf hello` 用例
   - 以 “60 秒内必须完成 `tool_use -> exec -> final text`” 作为验收条件
2. **优先查 streaming 路径，不先改 prompt**
   - 现有证据已经证明 prompt 厚度、session 缓存、工具列表都不是主根因
   - 主战场是 OpenClaw 内部 `embedded + stream + tool loop`
3. **第一候选修法**
   - 对 `kimi + anthropic-messages + tools-present` 这条路径增加非流式兜底
   - 理由：Kimi 对同一 payload 的非流式两轮工具协议已验证可通
4. **第二候选修法**
   - 修正 Kimi streaming `tool_use` 到 OpenClaw 内部 `tool_execution_*` 事件的桥接
   - 这是更正统的长期方案
5. **回归验证**
   - 最小 CLI 隔离复现通过
   - 再回到真实 Gateway/Telegram 场景验证
   - 全程不动 `main`，先在隔离/临时环境证实后再考虑部署

### 新增纠偏与方案更新（2026-03-10 16:40 CST）

- 用户已纠正：真正目标环境是远端外星人 Ubuntu 主机 `100.64.65.65`，不是本机 WSL。
- 本轮重新 SSH 到正确 live 主机后确认：
  - `main` 与 `dayong` 双 Gateway 都在
  - `dayong` 隔离目录与 service 确实存在
  - OpenClaw 版本是 `2026.3.7`

#### 最新关键判断

1. **配置层面**
   - `main` 的 `kimi` provider 确实声明为：
     - `api = "anthropic-messages"`
   - 所以“主配置把 Kimi 当 OpenAI API 配”这个判断不成立
2. **运行时层面**
   - OpenClaw 源码会对 Kimi tools 做 wrapper：
     - Anthropic 风格 `name + input_schema`
     - 被改写成 OpenAI function 风格 `type=function`
3. **远端实测层面**
   - Anthropic 风格工具定义 → Kimi 返回标准 `tool_use`
   - OpenAI function 风格工具定义 → Kimi 返回伪工具文本
   - `dayong` 的真实 payload 恰好就是后者

#### 因此，修复优先级更新为

1. **最高优先级**
   - 重新审查 / 绕过 `normalizeKimiCodingToolDefinition()` 这层 wrapper
   - 核验 Kimi 当前真实 API 是否已不再需要 OpenAI function 风格 tools
2. **次优先级**
   - 若 wrapper 不能直接去掉，再研究 streaming/tool loop 内部桥接
3. **暂不优先**
   - prompt 厚度
   - session 缓存
   - 人设/skills 差异

#### 完整修法草案（仍未部署）

- 方案 A：
  - 对 Kimi `anthropic-messages` 路径停止把 tools 改写成 OpenAI function 风格
- 方案 B：
  - 如果必须保留 wrapper，再为 Kimi 单独实现正确的 tool-use 解析与续跑
- 两个方案都必须先在：
  - 远端隔离目录
  - `printf hello`
  - `tool_use -> tool_result -> final text`
  这条最小链路上跑通后，才允许动生产 Gateway

### 新增可执行性判断（2026-03-10 16:55 CST）

- 用户提出的新目标是：
  - “把 `dayong` 的 Kimi 配成 Anthropic 风格”

#### 结论

- **仅靠 `dayong` 的 `openclaw.json` 配置做不到**

原因：

1. `dayong` 当前配置层本来就已经是：
   - `api = "anthropic-messages"`
2. 真正把 tools 改成 OpenAI function 风格的是：
   - 共享运行时代码 `/usr/lib/node_modules/openclaw/...`
3. 本轮未找到：
   - 能按 agent / provider 禁用这层 wrapper 的公开配置开关

#### 因此后续如果要落地，选择会变成

1. **dayong-only 代理方案**
   - 优先推荐
   - 只影响 `dayong`
   - 不碰 `main`
2. **dayong-only 独立 OpenClaw 安装**
   - 也能做到只影响 `dayong`
   - 但维护成本更高
3. **共享运行时 patch**
   - 技术上最省事
   - 但会影响 `main`
   - 与用户约束冲突，暂不做

### 新增版本回归判断（2026-03-10 17:20 CST）

- 用户追问的核心已经收敛为：
  - **为什么主 Agent 以前用 Kimi 看起来没问题，而 `dayong` 现在会持续工具调用失败**

#### 当前最准确结论

1. `main` 和 `dayong` **现在确实共享同一套 OpenClaw 安装**
   - 两个 systemd user service 都是：
     - `ExecStart=/usr/bin/openclaw gateway run ...`
   - `/usr/bin/openclaw` 指向：
     - `/usr/lib/node_modules/openclaw/dist/index.js`
   - 当前共享安装版本：
     - `2026.3.7`
2. 用户记忆“主 Agent 的 Kimi 以前能干活”是对的
   - 远端历史 session 里能查到多份：
     - `provider = kimi`
     - `model = k2p5`
     - 且真实包含 `toolCall / toolResult`
3. 这些成功样本的最新时间大多停在：
   - `2026-03-08`
4. 当前共享安装目录修改时间是：
   - `2026-03-09 02:22`
5. 所以现在最强的解释不再是“两个 Gateway 配置差太多”，而是：
   - **Kimi 工具链更像在 `2026.3.2 -> 2026.3.7` 这一轮升级后发生了回归**
6. 用户现在感觉主 Agent “没坏”，主要是因为：
   - `main` 当前 live 主模型实际是 `minimax/MiniMax-M2.5`
   - `kimi/k2p5` 只是 fallback
   - `2026-03-09` 之后最近的主 session，实测几乎都在跑 `MiniMax-M2.5`
   - 所以用户日常不会频繁撞到当前这条坏掉的 Kimi 路径

#### 本轮最关键证据链

1. 共享代码链
   - `openclaw-gateway.service` 与 `openclaw-gateway-dayong.service` 都调用同一个 `/usr/bin/openclaw`
2. 远端历史成功链
   - `~/.openclaw/agents/main/sessions/93fa...jsonl.reset...`
   - 明确显示：
     - `provider = kimi`
     - `model = k2p5`
     - `toolCall(web_search)` 与 `toolResult`
   - 同文件还出现：
     - `OpenClaw 2026.3.2 (85377a2)`
3. 当前 live 正常链
   - `~/.openclaw/agents/main/sessions/61e848...jsonl`
   - 明确显示：
     - `provider = minimax`
     - `model = MiniMax-M2.5`
     - `OpenClaw 2026.3.7 (42a1394)`
4. 当前 `dayong` 异常链
   - `~/.openclaw-dayong/.../1381a73b...jsonl`
   - 明确显示：
     - `provider = kimi`
     - `model = k2p5`
     - 回复的是伪工具文本 `/exec({...})`
     - 没有真实 `toolCall / toolResult`
5. 当前隔离复现链
   - 把主配置复制到临时目录并强制 primary = `kimi/k2p5`
   - `openclaw agent --local` 在 75 秒内挂住
   - 说明：
     - **当前坏掉的是共享代码里的 Kimi 执行路径**
     - 不只是 `dayong` 这个 Agent 特别蠢

#### 后续研究方向（仍然只读）

1. 继续深挖时，应优先回答：
   - `2026.3.2` 到 `2026.3.7` 之间，Kimi tool schema / stream bridge 哪段逻辑改了
2. 最值得比较的不是人格文件，而是：
   - Kimi wrapper
   - streaming tool loop
   - 版本差异
3. 在未验证隔离修复前：
   - **不动 `main`**
   - 不动共享生产 Gateway

### 新增主 Gateway 恢复动作（2026-03-10 17:38 CST）

- 用户要求：
  - 把主小龙虾切回 `MiniMax`
  - 并重启 **主** Gateway

#### 本轮执行结果

1. 先核对主配置：
   - `~/.openclaw/openclaw.json`
   - `agents.defaults.model.primary` **本来就已经是** `minimax/MiniMax-M2.5`
2. 再核对主会话：
   - `agent:main:main`
   - `agent:main:telegram:default:direct:8226087994`
   - 最近主 session 样本都显示：
     - `provider = minimax`
     - `model = MiniMax-M2.5`
3. 因此这次**不需要改主配置文件**
4. 按用户要求只执行：
   - `systemctl --user restart openclaw-gateway`
5. 重启后复核：
   - `openclaw-gateway.service = active (running)`
   - 新启动时间：
     - `2026-03-10 17:37:36 CST`
   - `openclaw gateway health = OK`
   - Telegram webhook 仍正常

#### 当前结论

- 主小龙虾这次不是“配置还挂在 Kimi”
- 更准确地说：
  - **主配置和当前主会话本来就已经回到了 MiniMax**
  - 这次做的是一次主 Gateway runtime 刷新
- 本轮只动了：
  - `main`
- 本轮没有动：
  - `dayong`

---

## 已完成（2026-03-11 凌晨）：主 Gateway .env 事故修复 ✅

### 现象
- 主 Gateway crash loop，日志：`missing env var "MINIMAX_API_KEY"`
- `.env` 在 `23:42` 被修改，`MINIMAX_API_KEY` 行丢失

### 根因
- 推测主小龙虾自己通过工具执行修改了 `.env`
- 2 个 session 文件涉及 `.env` 操作

### 修复
- 从 `openclaw.json.bak-rename-default` 找到原始 key
- 追加写入 `.env`，重启 Gateway
- 验收：active (running)，Health OK，Webhook pending=0

---

## 新任务（2026-03-11）：Chunyan（妈妈）Gateway 飞书 + Kimi 部署

### 目标
为妈妈的小龙虾（chunyan）配置飞书通道 + Kimi 模型，提供国内无翻墙聊天。

### 调研状态

| 项目 | 状态 |
|------|------|
| 飞书历史配置回顾 | ✅ 已提取（findings.md A/G/H/I 节） |
| 飞书凭证（appId/appSecret） | ✅ 已齐全 |
| 远端 chunyan 目录扫描 | ✅ 已完成 |
| 联网调研 v2026.3.7 飞书配置 | ✅ 已完成 |
| 完整 chunyan.json 草案 | ✅ 已写入 findings.md AO 节 |
| systemd service 模板 | ✅ 已写入 findings.md AO 节 |
| 部署执行 | ⏳ 待明早执行 |

### 部署计划

1. 创建 `.env`（Kimi + Brave + Google keys）
2. 重写 `chunyan.json`（Kimi 模型 + 飞书 WebSocket）
3. 创建 systemd service（参照 dayong 模板，端口 19001）
4. 启动 + 验证（Gateway health + 飞书 WebSocket 连接）
5. 飞书平台侧确认事件订阅

### 关键特性
- **飞书 WebSocket 模式**：无需 Tailscale Funnel，无需公网端口
- **Kimi k2p5**：与 dayong 一致，源码补丁已共享生效
- **飞书插件**：v2026.3.7 内置，只需 `plugins.entries.feishu.enabled = true`

### 详细配置
见 `findings.md` AO 节。

---

## 下一步（常规维护）

1. **可选**：执行 chunyan 飞书 + Kimi 部署
2. **可选**：给主小龙虾 AGENTS.md 加护栏，防止再次自删 `.env`
3. **观察**：主 Gateway + dayong Gateway 长期稳定性

---

## 新任务（2026-03-12）：Dayong A 股交易系统架构重构

### 目标

将 dayong 的 `trading-brain` 单体 Skill 拆解，嵌入 OpenClaw 原生架构，打造专业 A 股交易小龙虾。

### 约束

- 不动 SOUL.md（冰川纱夜人格不变）
- 不动 main Gateway
- 以 OpenClaw 官方配置能力为标准

### 调研状态

| 项目 | 状态 |
|------|------|
| dayong 现状完整探索 | ✅ 100+ 文件全景扫描完成 |
| OpenClaw 官方高级配置调研 | ✅ 10 大子系统已文档化 |
| trading-brain 架构分析 | ✅ 数据流 + 模块关系已梳理 |
| openclaw-complete-guide 遗漏补充 | ✅ 13 项遗漏已识别 |
| 七阶段重构方案设计 | ✅ 已写入 findings.md AQ 节 |
| 深度调研补充（AQ-11） | ✅ 安全风险 + 数据不一致 + 高级特性 |
| 用户决策收集 | ✅ 4 项决策已确认 |
| 最终方案确认 | ⏳ 待用户审核 |
| 执行 | ⏳ 方案确认后分阶段推进 |

### 用户决策（2026-03-12 确认）

| 决策项 | 选择 |
|--------|------|
| 向量记忆 Embedding | **暂不启用**，Phase 2 只做记忆结构标准化 |
| 市场范围 | **先只做 A 股**，港股/美股暂冻 |
| 旧模拟盘数据 | **直接删除** portfolio.json 等过期数据 |
| 执行节奏 | **先确认完整方案**，再从 Phase 0 开始执行 |

### 最终方案（根据用户决策修正 2026-03-12）

| 阶段 | 内容 | 影响范围 | 复杂度 | 状态 |
|------|------|---------|--------|------|
| **Phase 0** | 安全修复（.env 独立化 + API key 清理 + 旧数据**直接删除**） | dayong 配置 | 低 | ✅ 完成 |
| **Phase 1** | 上下文骨架重塑（AGENTS/TOOLS/HEARTBEAT/MEMORY/BOOT + Hook） | workspace .md + openclaw.json | 中 | ✅ 完成 |
| **Phase 2** | 记忆结构标准化（memory/trading/ 规范化，**向量记忆暂不启用**） | memory/ 目录 | 低 | ✅ 完成 |
| **Phase 3** | Cron 原生迁移（**仅 A 股** 6 个任务，通过 CLI 创建） | cron/jobs.json | 低 | ✅ 完成 |
| **Phase 4** | Skill 拆分（1 → 8 个 A 股聚焦 Skill，代码不动只建 SKILL.md） | workspace/skills/ | 中 | ✅ 完成 |
| **Phase 5** | 配置优化（subagent/pruning/compaction/commands/loopDetection） | openclaw.json | 低 | ✅ 完成 |
| **Phase 6** | Subagent **A 股**并行分析（多市场暂冻） | AGENTS.md + 运行时 | 中 | ✅ 完成 |
| **Phase 7** | 高级集成（self-improving-agent + capability-evolver） | skills + .learnings | 高 | ✅ 完成 |

#### Phase 0 详细步骤（安全修复）

1. SSH 到 `100.64.65.65`
2. 断开 `~/.openclaw-dayong/.env` 符号链接 → 复制为独立文件
3. 独立 .env 仅保留：`KIMI_API_KEY`, `BRAVE_API_KEY`, `GOOGLE_API_KEY`
4. 清理 `models.json` 硬编码的 Kimi API key → 改用 .env 引用
5. **直接删除**过期数据：`portfolio.json`, `screened_stocks.json`, `trade_history.json`, `cash_ledger.json` 等 shared/pipeline/ 和 shared/db/ 下的旧状态
6. 验证 dayong Gateway 重启正常

#### Phase 1 详细步骤（上下文骨架）

1. **AGENTS.md** 追加（~3000 chars）：交易决策框架 + 风控红线（6 条绝对规则）+ 数据纪律 + 记忆同步规则
2. **TOOLS.md** 追加（~1000 chars）：Python venv 路径 + CLI 入口 + 数据目录 + Pipeline 路径
3. **HEARTBEAT.md** 重写：开盘前/盘中/收盘后三段结构化执行清单
4. **MEMORY.md** 追加：策略精华 + 已验证因子 + 关键阈值 + 毕业进度
5. **新建 BOOT.md**：读市场状态 → 读持仓 → 读风控 → 判断交易日 → 通知用户
6. **openclaw.json** 启用 Hook：`bootstrap-extra-files` + `boot-md`
7. 验证：重启 Gateway，用 `/context` 检查注入内容

#### Phase 2 详细步骤（记忆标准化，不含向量记忆）

1. 新建 4 个 memory 文件：`risk_status.md`, `watchlist.md`, `strategy_params.md`, `weekly_summary.md`
2. 在 AGENTS.md 定义同步规则：每次交易后更新对应 memory 文件
3. 开启 compaction memoryFlush（`softThresholdTokens: 6000`）
4. 配置 `postCompactionSections`：`["当前持仓", "风控状态", "今日决策", "活跃信号"]`

#### Phase 3 详细步骤（仅 A 股 Cron）

迁移 3 个 A 股任务 + 新增 3 个：
| jobId | cron | 说明 | deliver |
|-------|------|------|---------|
| `cn-morning` | `0 9 * * 1-5` | 早盘扫描+选股+决策 | telegram/8226087994 |
| `cn-noon` | `30 13 * * 1-5` | 午盘扫描 | telegram/8226087994 |
| `cn-replay` | `0 23 * * 1-5` | 历史回放训练 | 不投递 |
| `cn-daily-report` | `30 15 * * 1-5` | 收盘日报 | telegram/8226087994 |
| `cn-weekly-review` | `0 16 * * 5` | 周五复盘 | telegram/8226087994 |
| `cn-risk-check` | `0 12 * * 1-5` | 午间风控快照 | telegram/8226087994 |

全部 `tz: "Asia/Shanghai"`, `maxConcurrentRuns: 2`, `timeoutSeconds: 300`

#### Phase 4 详细步骤（Skill 拆分）

新建 7 个 Skill（只创建 SKILL.md，不动 Python 代码）：
| 新 Skill | CLI 入口 | 触发词 |
|----------|---------|-------|
| `market-data/` | `cli.py data` | 行情、数据 |
| `stock-screener/` | `cli.py screener` | 选股、筛选 |
| `risk-control/` | `cli.py risk` | 风控、止损 |
| `trade-executor/` | `cli.py trade` | 买入、卖出 |
| `backtest/` | `cli.py backtest` | 回测 |
| `trading-reporter/` | `cli.py report` | 日报、周报 |
| `trading-learner/` | `cli.py learn` | 复盘、优化 |

前置：验证 `cli.py` 是否已实现所有子命令。

#### Phase 5-7 概要

- Phase 5：subagent 并发配置 + context pruning 30m + loop detection + Telegram 自定义命令
- Phase 6：A 股板块并行分析 + subagent 调度策略
- Phase 7：AI Bridge 迁移 + self-improving-agent 错误记录 + capability-evolver 策略优化

---

## 2026-03-12 下午: 夜间自动训练系统部署

### 新增任务

| # | 任务 | 关联项 | 状态 |
|---|------|-------|------|
| AT | 夜间自动训练系统 | AQ, AT-2, ..., AT-11 | ✅ 已部署 |

### 完成说明

**夜间训练系统**已完整部署到 dayong Gateway：
- 新增 4 个 Python 模块（unified_data, overnight_pipeline, overnight_consolidator, data_refresh）
- 修改 backtest_training.py 日期参数化
- 删除旧 cn-replay cron，新增 3 个夜间训练 cron
- 更新 HEARTBEAT.md 和 AGENTS.md
- 重启 Gateway 应用所有配置
- 调整 subagent 配置（maxConcurrent=30, timeoutSeconds=3600）
- 调整心跳间隔从 30m 到 15m

### Cron 任务总览

原有 5 个盘中任务（cn-morning, cn-noon, cn-daily-report, cn-weekly-review, cn-risk-check）
+ 新增 3 个夜间训练任务（overnight-pipeline, overnight-consolidate, morning-data-refresh）
= 8 个任务，全部配置正确并验证可用

---

## 2026-03-12 晚：主 Gateway Telegram 不回消息（已完成 ✅）

### 用户反馈
- 主 Gateway 的 Telegram Bot 看起来像 webhook 失效
- Gateway 本身似乎还在运行，但机器人不回消息

### 排查结果

| 项目 | 状态 |
|------|------|
| `openclaw-gateway.service` | ✅ active (running) |
| Telegram `getWebhookInfo` | ✅ URL 正常，`pending_update_count=0` |
| Tailscale Funnel `443 -> 8787` | ✅ 正常 |
| 本地 webhook listener | ✅ 正常 |
| 主机直连 Telegram | ❌ 超时 |
| 通过 `127.0.0.1:7897` 代理访问 Telegram | ✅ 正常 |
| 故障窗口日志 | ⚠️ `sendMessage failed` / `sendChatAction failed` |
| 复验发信 | ✅ Bot API + `openclaw message send` 均成功 |

### 结论
- **这次不是 webhook 挂了。**
- 更准确地说：
  - webhook / Funnel / listener 都正常
  - 失败点在 Telegram 出站发送
  - 主机本身不能直连 Telegram，必须依赖代理
  - 代理链路在 `2026-03-12 21:22~21:23 CST` 短时抖动，导致机器人看起来“不回消息”

### 后续维护要点
1. 若再复发，先看 `openclaw-gateway` 日志里是不是 `sendMessage failed`
2. 先测：
   - 直连 Telegram
   - 走 `127.0.0.1:7897` 代理的 Telegram
3. 若问题仍在：
   - 先重启 `mihomo-standalone`
   - 再重启 `openclaw-gateway`

---

## 2026-03-13：开机恢复拆分验收进度

### 已完成

| 项目 | 目标 | 状态 |
|------|------|------|
| Tailscale 救援通道 | 重启后保持 `100.64.65.65` 可 SSH 直连 | ✅ 已通过整机重启验收 |
| Mihomo 代理 | 重启后恢复 `127.0.0.1:7897` + `30s url-test` | ✅ 已通过整机重启验收 |
| 主 Gateway | 重启后恢复 `boot-md` + `443 -> 8787 webhook` | ✅ 已通过整机重启验收 |
| dayong Gateway | 重启后恢复 `8443 -> 8788 webhook` | ✅ 已修复并通过整机重启验收 |

### 结论

- 这台机器当前已经具备“重启后先通过 Tailscale 连回去，再远程修其他层”的稳定底座。
- dayong 此前无法恢复旧状态的根因不是 systemd，不是 Tailscale，而是 `openclaw.json` 中 webhook 字段位置错误。
- 当前 main/dayong 两套 Gateway 都已回到各自独立的 webhook 稳态。

### 下一步建议

| 优先级 | 任务 | 原因 |
|--------|------|------|
| P1 | 清理 dayong 多个 cron 对 `@heartbeat` 的错误投递目标 | 当前 cron 最近状态仍有 error |
| P1 | 观察主 Gateway `daily-self-improvement` 在 `2026-03-13 23:00 CST` 的自然执行结果 | 配置已修复，但仍需用自然运行覆盖旧 error 状态 |
| P1 | 在下一次主 Gateway 重启时复核 `BOOT.md` 防重修复是否恢复自动启动检查 | 修复已落盘，但尚未做重启验收 |
| P2 | 追踪 dayong `gateway health --json` 的 webhook 假阴性 | 诊断噪声，不阻断运行 |

### 同轮追加：主 Gateway `daily-self-improvement` Cron 修复

| 项目 | 目标 | 状态 |
|------|------|------|
| `daily-self-improvement` sessionKey 迁移 | `default` -> `main-bot` | ✅ 已完成 |
| 主 Gateway 无扰动修复 | 不重启 `openclaw-gateway.service` | ✅ 已完成 |
| 持久化落盘 | `~/.openclaw/cron/jobs.json` 更新 | ✅ 已完成 |
| 运行结果验收 | 等待下一次自然执行 | ⏳ 待 `2026-03-13 23:00 CST` |

### 变更说明

- 本次不再通过“补一个全局 `TELEGRAM_BOT_TOKEN`”绕过问题。
- 采用的正式修法是让这条 Cron 回到当前主账号语义：
  - `agent:main:telegram:main-bot:direct:8226087994`
- 使用 `openclaw cron edit` 直接走 Gateway 运行态更新，因此不需要重启主 Gateway，也不影响现有 webhook。

### 同轮追加：`BOOT.md` 防重逻辑修复

| 项目 | 目标 | 状态 |
|------|------|------|
| 主 Boot 防重逻辑 | 不再依赖模型心算 Unix 时间 | ✅ 已完成 |
| Boot 检查项/文案保留 | 只改防重判断 | ✅ 已完成 |
| 备份原始 `BOOT.md` | 保留回滚点 | ✅ 已完成 |
| 下一次启动验收 | 看是否恢复自动发 Boot 消息 | ⏳ 待下次重启/重拉 Gateway |

---

## 新任务（2026-03-14）：远端 Linux 主机公网防护现状全面审计

### 目标

- 全面核查远端 Ubuntu 主机当前对公网暴露的实际入口，而不是只看历史配置。
- 明确现状分层：
  - 哪些入口仍然对公网可达
  - 哪些服务只在 `loopback` / Tailscale 内部可达
  - 哪些保护已经生效
  - 哪些风险点仍未收紧
- 给出“当前风险级别 + 下一步收口顺序”，避免泛泛而谈。

### 本轮验收项

| 项目 | 目标 | 状态 |
|------|------|------|
| Tailscale Funnel / Serve | 核对当前公网 HTTPS 入口、映射端口、是否仍持久存在 | ✅ 已完成 |
| 本机监听面 | 核对 `ss -ltnp`，确认 OpenClaw / Webhook / SSH 绑定地址 | ✅ 已完成 |
| SSH 暴露面 | 核对 `sshd` 生效配置、监听地址、密码认证与来源限制 | ✅ 已完成（认证项仍有残留不确定性，见 findings.md AZ） |
| 主机防火墙 | 核对 `ufw status numbered` / 规则命中，确认 22/443/8443 现状 | ✅ 已完成 |
| Tailscale 状态 | 核对 `WantRunning` / `RunSSH` / 节点在线与救援链路 | ✅ 已完成 |
| Webhook 鉴权面 | 核对 webhook URL / secret / 本地未授权访问响应 | ✅ 已完成（secret 已确认存在，最小 POST 返回 400） |
| 结论分级 | 输出“已收紧 / 仍暴露 / 建议下一步” | ✅ 已完成 |

### 本轮边界

- 以**只读审计**为主，不主动改线上配置。
- 若发现高风险项，会先汇报证据和影响，再决定是否执行收紧动作。

---

## 新任务（2026-03-14）：Windows 电脑侧 SSH / 公网防护现状审计

### 目标

- 核查本机 Windows 当前是否真正实现：
  - 允许小龙虾 Linux 通过 Tailscale / SSH 连入操作
  - 同时尽量不向其他来源开放 SSH 面
- 分清当前到底是：
  - `Tailscale SSH`
  - 还是 `OpenSSH + Tailscale 网络`
- 输出当前缺口，判断是否已经满足“只允许小龙虾 Linux 连接”的目标。

### 本轮验收项

| 项目 | 目标 | 状态 |
|------|------|------|
| Tailscale 当前模式 | 确认 `RunSSH`、节点 IP、peer 状态 | ✅ 已完成 |
| 本机 SSH 服务 | 确认是否监听 22、由谁监听、启动方式 | ✅ 已完成 |
| Windows 防火墙 | 确认 22 的入站规则、Profile、RemoteAddress 范围 | ✅ 已完成 |
| `sshd_config` | 确认 `Match Group administrators` 与 authorized_keys 路径 | ✅ 已完成 |
| 授权密钥面 | 确认实际使用的是哪个 authorized_keys 文件，以及可见的 key 范围 | ✅ 已完成（管理员 key 文件内容因未提权未读到） |
| 远端连通性 | 从小龙虾 Linux 实测是否能打到本机 `22` | ✅ 已完成 |
| 结论分级 | 判断是否已做到“仅允许小龙虾 Linux 连入” | ✅ 已完成 |

### 本轮边界

- 先做**只读审计**，不先改 Windows 防火墙或 SSH 配置。
- 若确认当前未达到目标，再给出最小改动的收紧方案。

---

## 新任务（2026-03-14）：Windows SSH 精确收口方案调研（仅手机 + Linux）

### 目标

- 在不破坏现有运维链路的前提下，把 Windows 电脑的 SSH 面收口到：
  - 小龙虾 Linux
  - 你的手机
- 同时确认“公网侧仍安全”，避免为了放行两台设备而把其它来源也带进来。

### 本轮验收项

| 项目 | 目标 | 状态 |
|------|------|------|
| 手机当前 tailnet 身份 | 确认手机在线节点名、当前 Tailscale IP、是否稳定 | ✅ 已完成 |
| Linux 当前 tailnet 身份 | 确认小龙虾 Linux 节点名、当前 Tailscale IP | ✅ 已完成 |
| 官方文档调研 | 核对 Tailscale SSH / Windows OpenSSH / 防火墙精确放行的能力边界 | ✅ 已完成 |
| 方案对比 | 判断“按 Tailscale IP 放行”与“Tailscale SSH ACL”哪种更稳 | ✅ 已完成 |
| 最终建议 | 输出推荐实施顺序，兼顾安全性与可维护性 | ✅ 已完成 |

### 本轮边界

- 先完成**完整调研与方案论证**，暂不直接修改规则。

---

## 已完成（2026-03-14）：四 Gateway 全面激活 + 飞书接入 ✅

### 目标
- 激活 chunyan、zenglan 两个未部署的 Gateway
- 三个 Gateway（dayong/chunyan/zenglan）接入飞书
- 不动主 Gateway 配置

### 验收结果

| 项目 | 状态 |
|------|------|
| `~/.openclaw-parents/` 清理 | ✅ 已删除 |
| chunyan Gateway 部署 + 启动 | ✅ active (running) |
| zenglan Gateway 部署 + 启动 | ✅ active (running) |
| chunyan 飞书 WebSocket | ✅ connected |
| zenglan 飞书 WebSocket | ✅ connected |
| dayong 飞书 WebSocket（新增通道） | ✅ connected |
| 三个飞书 typingIndicator | ✅ 全部开启 |
| 三个飞书 allowFrom | ✅ 全部已配 |
| chunyan 用户实测回复 | ✅ 正常 |
| dayong Telegram webhook | ✅ 未受影响 |
| 主 Gateway | ✅ 全程未动 |

### 当前四 Gateway 架构

| Gateway | 端口 | 模型 | Telegram | 飞书 App | systemd |
|---------|------|------|----------|----------|---------|
| main | 18790 | minimax/MiniMax-M2.5 | webhook 443 | 无 | enabled + active |
| dayong | 19021 | kimi/k2p5 | webhook 8443 | cli_a927e3cb67389cb1 | enabled + active |
| chunyan | 19001 | kimi/k2p5 | 关 | cli_a92651d8d7f81bc0 | enabled + active |
| zenglan | 19041 | kimi/k2p5 | 关 | cli_a93e7c91beb89cd3 | enabled + active |
- 若需要落地改造，再单独执行并做双设备回归验证。

### 本轮结论摘要

- 当前手机实时在线节点已确认：
  - `pixel-5-3.tailda6e28.ts.net`
  - `100.100.237.12`
- 小龙虾 Linux 当前节点已确认：
  - `openclaw-24x7.tailda6e28.ts.net`
  - `100.64.65.65`
- Windows 刚刚记录到了手机的实时成功 SSH 登录：
  - 时间：`2026-03-14 10:13:02`
  - 来源：`100.100.237.12`
  - 指纹：`SHA256:uno89lhmAtTHU//qrt306NZkx4Jiqk0t0DtVh22pbZY`
- 官方文档边界已经确认：
  - Windows **不能**作为 `Tailscale SSH` 服务端目标
  - `Tailscale` 默认允许 tailnet 内设备互通
  - `shields up` 只能“一刀切阻断所有入站”，不适合“只放两台设备”这种目标
- 推荐目标态已经明确：
  1. Windows 本机继续使用 **OpenSSH**
  2. 设备级精确授权放到 **Tailscale tailnet policy / grants**
  3. Windows 防火墙只允许 **Tailscale 网段**访问 `22/tcp`，并禁用过宽的默认 SSH 规则
  4. 若要再加一层本机兜底，可额外只放行当前两台设备的 Tailscale IP，但要接受手机节点重建后的维护成本

---

## 新任务（2026-03-14）：Windows SSH 收口部署（手机 + Linux）

### 目标

- 按已确认方案，把本机 Windows 的 SSH 实际收口到：
  - 小龙虾 Linux
  - 手机
- 并同时关闭：
  - 局域网直打 `22`
  - 公网直打 `22`
- 若当前环境无法直接修改 tailnet policy，则至少先把 **Windows 本机侧**落到严格状态。

### 本轮验收项

| 项目 | 目标 | 状态 |
|------|------|------|
| `sshd_config` 收紧 | 改为仅允许公钥登录，关闭密码认证，只允许 `kevinlasnh` | ✅ 已完成 |
| 管理员授权 key 收口 | 仅保留当前 Linux key + 手机 key，移除坏掉的旧 key | ✅ 已完成 |
| Windows SSH 防火墙收紧 | 禁用默认宽规则，新建仅允许手机 + Linux 通过 Tailscale 进 `22` 的规则 | ✅ 已完成 |
| Linux 回归验证 | 远端 Linux 重新 SSH 到本机成功 | ✅ 已完成 |
| LAN / 公网 22 验证 | 局域网 IP / 公网 IP 直打 `22` 失败 | ✅ 已完成 |
| Tailscale policy 后台落地 | 在 tailnet admin console 中同步补齐 grants / ACL | ⚠️ 当前环境无直连入口，待后台执行 |

### 本轮实施摘要

- 本机 `sshd_config` 已改成：
  - `PubkeyAuthentication yes`
  - `PasswordAuthentication no`
  - `PermitEmptyPasswords no`
  - `KbdInteractiveAuthentication no`
  - `AllowUsers kevinlasnh`
- `C:\ProgramData\ssh\administrators_authorized_keys` 已收成 2 把 key：
  - Linux：`SHA256:oM6lVLD19Ac0tZFO0YkHdjjWCqdyW/pBlM/55MdvB9M`
  - 手机：`SHA256:uno89lhmAtTHU//qrt306NZkx4Jiqk0t0DtVh22pbZY`
- Windows 防火墙已禁用原有宽规则，并新建：
  - `SSH-Approved-Tailscale-Devices`
  - 仅放行：
    - `100.64.65.65`
    - `fd7a:115c:a1e0::8f3b:4141`
    - `100.100.237.12`
    - `fd7a:115c:a1e0::63b:ed0c`
  - 仅接口：
    - `Tailscale`
  - 仅程序：
    - `C:\Windows\System32\OpenSSH\sshd.exe`

### 本轮边界

- 本机侧部署已完成。
- Tailscale 管理后台的 `grants / ACL` 这一步，本轮没有本地 CLI / API 入口可直接推送。
- 若手机节点未来重建并获得新名字 / 新 IP，需要同步更新本机防火墙规则，除非后续把设备级授权迁回 tailnet policy。

---

## 新任务（2026-03-14）：Windows 非 SSH 暴露面全面调研（tailnet / 私网）

### 目标

- 识别 Windows 在 **SSH 之外**，当前仍可从：
  - `Tailscale 私网`
  - `局域网`
  访问到的端口与服务
- 区分：
  - 系统关键、不要乱碰
  - 明显可以关闭
  - 需要结合使用场景决定
- 给出后续“全面收口”应按什么顺序做。

### 本轮验收项

| 项目 | 目标 | 状态 |
|------|------|------|
| 监听面复核 | 列出所有非回环 TCP/UDP 监听口及其进程/服务 | ✅ 已完成 |
| 外部可达性复核 | 从 Linux 对 Tailscale IP / LAN IP 做 TCP 实测 | ✅ 已完成 |
| 规则来源定位 | 找到主要开放面的防火墙规则和 Profile | ✅ 已完成 |
| 服务分类 | 区分 Hyper-V / RPC / SMB / CDP / Delivery / app 自定义等来源 | ✅ 已完成 |
| 风险排序 | 给出“优先收口名单”和“谨慎处理名单” | ✅ 已完成 |

### 本轮核心结论

- 现在 Windows 的 **SSH 面已经收住**，但 **非 SSH 的 tailnet / 私网暴露面仍明显偏宽**。
- 远端 Linux 对 Windows `100.97.45.87` 实测仍可达的 TCP 端口包括：
  - `135`
  - `445`
  - `2179`
  - `2222`
  - `5040`
  - `5357`
  - `7680`
  - `9527`
  - `18789`
  - `49664`
  - `49665`
  - `49666`
  - `49667`
  - `49668`
  - `50412`
  - `59069`
- 对局域网地址 `192.168.50.113` 实测仍可达：
  - `135`
  - `2179`
  - `7680`
  - `9527`
- 按重要性看，后续收口优先级最高的是：
  1. `445` / SMB
  2. `135 + 49664-49668 + 50412` / RPC 动态管理口
  3. `2179` / Hyper-V 远程控制
  4. `5040` / Connected Devices Platform
  5. `7680` / Delivery Optimization
  6. `9527` / `voicing` 应用自定义入站
- `2222 / 18789 / 59069` 属于 `tailscaled` 自身监听，**不要在不了解作用前直接关**。

### 本轮边界

- 本轮只做了**全面调研与分级**，还没有开始收非 SSH 规则。
- 若要继续落地，下一步应按“先高风险、后低风险”的顺序逐项收口，并每收一组就做回归。

### 当前停点（2026-03-14）

- 用户当前决定**先不继续第二阶段非 SSH 收口**。
- 当前认可的阶段性判断是：
  - Windows 的 **SSH 面已经安全**
  - 对公网直连面，当前**没有证据**显示陌生人可直接打进来
  - 非 SSH 的 tailnet / 私网暴露面已完成调研，但**暂不继续处理**

---

## 已完成（2026-03-14 下午）：主 Gateway 再次“不回消息”复核 ✅

### 目标
- 核查主 Gateway 当前“不回消息”到底是：
  - service 崩溃
  - webhook 失效
  - 模型故障
  - 还是 Telegram 出站链路抖动
- 只在有必要时才重启，避免把“短时抖动”误处理成“配置故障”。

### 验收结果

| 项目 | 状态 |
|------|------|
| `openclaw-gateway.service` 在线状态 | ✅ active (running) |
| `mihomo-standalone.service` 在线状态 | ✅ active (running) |
| 本地监听 (`18790/8787/7897`) | ✅ 正常 |
| `openclaw gateway health --json` | ✅ OK |
| Telegram `getWebhookInfo` | ✅ webhook 正常，`pending_update_count=0` |
| `openclaw agent --agent main` 自检 | ✅ 返回 `MAIN_DIAG_OK` |
| Telegram Bot API 出站测试 | ✅ 成功，`message_id=10890` |
| 是否发现持久性故障 | ❌ 未发现 |

### 结论
- 这次**不是主 Gateway 挂了**。
- 也**不是 webhook 失效**。
- 主模型 `minimax/MiniMax-M2.5` 在检查时可正常返回。
- 日志显示的是几段**短时 Telegram 出站失败**，随后又恢复连续 `sendMessage ok`。
- 因此本轮最准确判断是：
  - **主 Gateway 本体健康**
  - **故障形态仍更像 Telegram 出站 / 代理链路的瞬时抖动**

### 日志锚点
- 失败窗口：
  - `2026-03-14 13:51:54 CST`
  - `2026-03-14 13:52:04 CST`
  - `2026-03-14 13:56:19 CST`
  - `2026-03-14 14:05:48` 到 `14:07:05 CST`
- 恢复窗口：
  - `2026-03-14 14:07:06 CST` 起重新出现 `sendMessage ok`
  - `2026-03-14 14:54:51` 到 `14:55:05 CST` 连续正常回包
  - `2026-03-14 14:58 CST` Bot API 诊断消息成功送达

### 本轮处理策略
1. 不重启主 Gateway。
2. 不改线上配置。
3. 记录本轮证据，作为下一次复发时的快速判别模板。
4. 若下次异常持续超过 1-2 分钟，再优先重启 `mihomo-standalone`，而不是先动 `openclaw-gateway`。

### 本轮额外记录
- `openclaw message send` 本轮首次尝试时参数写法不对，CLI 提示缺少 `--target`。
- 为避免继续在 CLI 语法上耗时，本轮改用 Telegram Bot API 直接做出站验收。

---

## 已完成（2026-03-14 晚）：Telegram 日本/台湾专用 fallback 组部署 ✅

### 目标
- 为 Telegram 单独创建一个稳定优先的代理组
- 只使用当前订阅里的台湾 + 日本节点
- 节点稳定时不切换
- 检查频率改为 `5` 秒
- 保证重启后仍走新组，而不是回到 `悠兔`

### 验收结果

| 项目 | 状态 |
|------|------|
| 台湾/日本节点全集复核 | ✅ 共 12 个，配置与运行态一致 |
| 新组 `telegram-jp-tw-stable` 写入 YAML | ✅ 已完成 |
| Telegram 规则改向新组 | ✅ 已完成 |
| 远端临时文件语法校验 | ✅ `test is successful` |
| 正式覆盖持久化 YAML | ✅ 已完成 |
| 远端备份文件 | ✅ 已创建 |
| 当前是否已生效 | ⚠️ 待用户重启后生效 |

### 已部署配置
- 新组参数：
  - `type: fallback`
  - `interval: 5`
  - `lazy: true`
  - `timeout: 3000`
  - `max-failed-times: 1`
  - `expected-status: 204`
  - `url: https://www.gstatic.com/generate_204`
- 节点范围：
  - 仅台湾 + 日本
  - 共 12 个节点，全部已放入组内

### 为什么重启后不会回 `悠兔`
- 这次不是运行时临时切组。
- Telegram 相关规则已直接写入持久化 YAML：
  - `telegram.org -> telegram-jp-tw-stable`
- 因此 `mihomo-standalone` 或整机重启后，启动时会继续读取这份新规则。

### 本轮边界
- 按用户要求，本轮只完成部署，不主动重启机器。
- 当前运行态是否已切到新组，要等用户重启后再做复核。

### 下轮验收项
1. 用户重启机器后，检查 `telegram-jp-tw-stable` 是否进入运行时 `/proxies`
2. 检查 `api.telegram.org:443` 是否不再走 `悠兔`
3. 检查主 Gateway Telegram 出站是否正常

### 重启后验收结果

| 项目 | 状态 |
|------|------|
| 整机重启执行 | ✅ 已完成 |
| SSH 恢复 | ✅ `15:49:59 CST` 恢复 |
| `mihomo-standalone.service` 自恢复 | ✅ active |
| `openclaw-gateway.service` 自恢复 | ✅ active |
| `telegram-jp-tw-stable` 进入运行时 `/proxies` | ✅ 已确认 |
| Telegram 是否仍走 `悠兔` | ❌ 否 |
| Telegram 实际路由到新组 | ✅ `telegram-jp-tw-stable[专线2.5x-台湾1-GPT]` |
| 实际发信成功 | ✅ `message_id=10892` |

### 最终结论
- 本轮 Telegram 专用 fallback 组部署已经闭环完成。
- 当前状态是：
  - Telegram 出站已经稳定改由 `telegram-jp-tw-stable` 接管
  - 重启后自动恢复正常
  - 不再回到 `悠兔 -> 自动选择`

### 追加在线复核结果

| 项目 | 状态 |
|------|------|
| `telegram-jp-tw-stable` 连续抽样稳定 | ✅ 4 次抽样都为 `专线2.5x-台湾1-GPT` |
| 运行逻辑是否符合“稳定时不切” | ✅ 符合 |
| 四个 Gateway 是否全部拉起 | ✅ 全部 active |
| main Telegram webhook | ✅ 已接上，`pending=0` |
| dayong Telegram webhook | ✅ 已接上，`pending=0` |

---

## 已完成（2026-03-14 晚）：主 `悠兔 / UTO` 全局稳定优先改造 ✅

### 目标
- 将主 `悠兔` 的默认逻辑从：
  - `悠兔 -> 自动选择(url-test, 30s)`
- 调整为更接近：
  - `5` 秒检查
  - 当前节点稳定时保持不变
  - 当前节点失败时才切到下一节点

### 已完成的调研
- ✅ 已确认当前运行时仍是：
  - `悠兔.now = 自动选择`
- ✅ 已确认：
  - `自动选择 = URLTest`
  - `故障转移 = Fallback`
- ✅ 已确认 `悠兔` 的 concrete node 数量：
  - `54`
- ✅ 已确认规则影响面：
  - 明确 `310` 条规则指向 `悠兔`
  - 另有 `MATCH,悠兔`
- ✅ 已读取全部 54 节点的运行态延迟历史，并形成排序草案

### 当前关键结论
1. 只改 `故障转移` 还不够。
2. 若 `悠兔` 仍选中 `自动选择`，全局流量不会切到新逻辑。
3. `profiles.yaml` 的选中缓存与当前运行态存在不一致，不能只依赖 `store-selected` 文本判断是否生效。
4. 若上线，必须把以下动作打包：
   - 重排 `故障转移` 的 54 节点顺序
   - 将其参数改为 `interval: 5` 的稳定优先配置
   - 让 `悠兔` 真实切到 `故障转移`
   - 重启或重载后做运行态复核

### 实际完成情况
1. 已输出并确认最终节点顺序。
2. 已修改持久化 YAML。
3. 已将 `悠兔` 的运行时实际切到 `故障转移`。
4. 已重启 `mihomo-standalone`。
5. 已做整机重启验证。

### 最终验收结果
- `悠兔.now = 故障转移`
- `故障转移.now = 专线2.5x-香港6`
- `telegram-jp-tw-stable.now = 专线2.5x-台湾1-GPT`
- `tailscaled`、`mihomo-standalone`、四个 Gateway 服务均 `active`
- Google 实际流量日志已验证命中新主组
- Telegram 专用组未受影响

### 追加总验收（2026-03-14 17:05 CST）
- `telegram-jp-tw-stable` 已重点复核：
  - 配置仍为 `fallback + interval: 5`
  - 节点范围仍仅台湾 + 日本 `12` 节点
  - 连续 `4` 次抽样保持 `专线2.5x-台湾1-GPT`
- `mihomo` 日志已确认：
  - Telegram 实际仍命中 `telegram-jp-tw-stable`
  - Google 实际仍命中主 `悠兔`
- `tailscale funnel status` 正常：
  - `443 -> 8787`
  - `8443 -> 8788`
- 两个 Telegram webhook 当前均：
  - URL 正确
  - `pending_update_count = 0`
- 当前可下最终结论：
  - 整体状态正常，无新增故障

### 追加变更（2026-03-14 17:37 CST）
- 主 `故障转移` 已进一步收缩为与 `telegram-jp-tw-stable` 相同的日本/台湾 `12` 节点池。
- 保持不变的部分：
  - `fallback`
  - `interval: 5`
  - 稳定时不切、失败时切换
- 当前验收结果：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
  - Google 实际流量已命中新主池

### 追加重启验收（2026-03-14 17:41 CST）
- 已对“主 `故障转移` = 日本/台湾 `12` 节点池”的新状态做整机重启验证。
- 重启后仍保持：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- `tailscaled`、`mihomo-standalone`、四个 Gateway、两个 webhook 均正常。
- 结论：
  - 当前配置已通过“重启后自动恢复到目标状态”的验收。

### 追加复核（2026-03-14 17:46 CST）
- 已再次单独检查：
  - 主 `故障转移`
  - `telegram-jp-tw-stable`
- 当前两组都保持：
  - `fallback`
  - `interval: 5`
  - 相同的日本/台湾 `12` 节点池
- 当前命中状态：
  - `悠兔 -> 故障转移 -> 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable -> 专线2.5x-台湾1-GPT`
- 结论：
  - 两组当前状态正确，无需进一步修正

---

## 已完成（2026-03-14 夜）：四 Gateway 实时健康复核 ⚠️ 未达“全面健康”

### 目标
- 复核当前四个 Gateway 是否都处于“通道、服务、代理、控制面都健康”的状态。
- 避免只看 `active (running)` 就误判为“全面健康”。

### 本轮验收项

| 项目 | 状态 |
|------|------|
| 补读 `findings.md` / `progress.md` / `CLAUDE.md` | ✅ 已完成 |
| `planning-with-files` session catchup | ✅ 已完成 |
| 四个 Gateway `gateway health --json` | ✅ 已完成 |
| 四个 Gateway 本地 agent 自检 | ✅ 已完成 |
| systemd / proxy / tailscale / funnel 复核 | ✅ 已完成 |
| Telegram 官方 `getWebhookInfo` 复核 | ✅ 已完成 |
| 最近日志异常扫描 | ✅ 已完成 |

### 本轮结论
- **结论不是“全面健康”。**
- 当前更准确的判断是：
  - **代理、Tailscale、dayong 主链路基本健康**
  - **main 已退化成 Telegram 长轮询，且持续出现 polling stall**
  - **chunyan 存在工具运行时模块缺失，简单对话可用但工具链不健康**
  - **zenglan 存在 Gateway 控制面握手超时，用户通道未证实故障，但运维面不算健康**

### 关键证据摘要
1. `main`
   - 配置文件仍保留 `webhookUrl` / `webhookSecret`
   - `tailscale funnel status` 仍保留 `443 -> 127.0.0.1:8787`
   - 但 Telegram 官方 `getWebhookInfo` 返回 `url=""`
   - `openclaw gateway health --json` 也显示 `webhook.url=""`
   - `ss -ltn` 没有 `127.0.0.1:8787` 监听
   - 日志连续出现 `Polling stall detected`
   - `openclaw-gateway.service` 当前 `UnitFileState=disabled`
2. `dayong`
   - `gateway health` 正常
   - Telegram webhook 正常
   - 本地自检返回 `DAYONG_HEALTH_OK`
   - 仅见一次 `sendChatAction failed` 和一次飞书卡片内容超限 400，属于瞬时或内容级问题
3. `chunyan`
   - Feishu probe 正常
   - 本地自检返回 `CHUNYAN_HEALTH_OK`
   - 但日志多次报 `Cannot find module ... pi-tools.before-tool-call.runtime...`
   - 说明工具调用链不健康
4. `zenglan`
   - Feishu probe 正常
   - 本地简单自检能返回 `ZENGLAN_HEALTH_OK`
   - 但 CLI 连接本地 Gateway 时出现 `connect challenge timeout`
   - 说明 Gateway 控制面至少存在不稳定

### 当前判断
- 如果问“还能不能继续用”，答案是：**能用一部分**。
- 如果问“是不是全面健康”，答案是：**不是**。
- 当前优先级建议：
  1. 先修 `main` 的 webhook 回归问题
  2. 再修 `chunyan` 的工具运行时缺模块问题
  3. 最后复查 `zenglan` 的 Gateway 握手超时是否持续复现

---

## 已完成（2026-03-14 夜）：四 Gateway 健康缺口修复 ✅

### 目标
- 修复上一轮复核中发现的 3 个主要缺口：
  - `main` webhook 退化为 polling
  - `chunyan` 工具运行时缺模块
  - `zenglan` ws `connect challenge timeout`

### 已执行修复
1. `main`
   - 将误写在 `channels.telegram.accounts.default` 下的 `webhookUrl/webhookSecret` 移回 `channels.telegram`
   - 删除多余的 `accounts.default`
   - 重写 `openclaw-gateway.service`，对齐为与其他 Gateway 一致的标准模板：
     - `ExecStart=/usr/bin/openclaw gateway run --port 18790`
     - `EnvironmentFile=~/.openclaw/.env`
     - 显式 `OPENCLAW_STATE_DIR` / `OPENCLAW_CONFIG_PATH`
   - 从旧 unit 补回 `NEWCLI_API_KEY`
   - `systemctl --user daemon-reload`
   - `systemctl --user enable openclaw-gateway`
2. `chunyan`
   - 重启到当前一致的 `OpenClaw 2026.3.13` 代码，清除旧进程持有的失效 dist chunk 引用
3. `zenglan`
   - 同样重启到当前一致代码
   - 进一步备份并清空：
     - `~/.openclaw-zenglan/devices/paired.json`
     - `~/.openclaw-zenglan/identity/device-auth.json`
   - 让 CLI 与 Gateway 重新配对
4. 统一动作
   - 重启四个 Gateway：
     - `openclaw-gateway`
     - `openclaw-gateway-dayong`
     - `openclaw-gateway-chunyan`
     - `openclaw-gateway-zenglan`

### 最终验收结果
- `systemctl --user show`：
  - 四个 Gateway 全部 `active`
  - 四个 Gateway 全部 `enabled`
  - 本轮修复后统一启动时间为 `2026-03-14 21:57:26 CST`
  - `zenglan` 二次修复后启动时间为 `2026-03-14 22:02:32 CST`
- `ss -ltn`：
  - `127.0.0.1:8787` 已恢复监听
  - `127.0.0.1:8788` 正常
  - `18790 / 19021 / 19001 / 19041` 全部监听
- Telegram 官方 `getWebhookInfo`
  - main：
    - `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
    - `pending_update_count = 0`
- `openclaw gateway health --json`
  - main：Telegram webhook 正常
  - dayong：Telegram + Feishu 正常
  - chunyan：Feishu 正常
  - zenglan：Feishu 正常
- 强制功能回归
  - `main`：`MAIN_FIXED_OK`
  - `dayong`：`DAYONG_FIXED_OK`
  - `chunyan`：`CHUNYAN_FIXED_OK`
  - `zenglan`：`ZENGLAN_FIXED_OK`
  - `chunyan` 强制 `read` 工具回归：`CHUNYAN_READ_TOOL_OK`
  - `zenglan` 控制面回归：`ZENGLAN_GATEWAY_OK`

### 结果判断
- 本轮发现的三类明确故障已闭环修复。
- 截至本轮收尾，当前四 Gateway 已恢复到可判定为**健康**的状态。

### 当前停点
- 用户确认：
  - 暂不继续清理两类非阻断启动噪声
    - `main` 的 skills path warning
    - `chunyan / zenglan` 的 doctor 级 Telegram 配置提示
- 处理策略：
  - 先保持现状
  - 仅作为已知噪声记录
  - 后续若用户要求“日志更干净”或“彻底零告警”，再单独处理

---

## 已完成（2026-04-02 夜）：main 升级到 2026.4.1，并将 GPU 本地语义检索稳定到 Qwen 4B ✅

### 目标
- 只处理 `main`
- 保持聊天主模型为：
  - `openai-codex/gpt-5.4`
- 将本地语义检索稳定到：
  - `Qwen3-Embedding-4B-Q4_K_M`
- 约束：
  - 本地 embedding 继续走 GPU
  - 源码仅允许修改一处 `context` 参数

### 已执行
1. 升级远端 OpenClaw 主包到：
   - `2026.4.1`
2. 修回 CLI 入口并重新接入 `node-llama-cpp` 运行时
3. 验证最新版本地 memorySearch 仍未暴露：
   - `gpu`
   - `gpuLayers`
   - `contextSize`
4. 按用户边界，仅修改：
   - `/usr/lib/node_modules/openclaw/dist/memory-core-host-engine-embeddings-CURmoLEe.js`
   - `createEmbeddingContext()` → `createEmbeddingContext({ contextSize: 2048 })`
5. 将 `main` 的 memory 配置切到：
   - `Qwen3-Embedding-4B-Q4_K_M.gguf`
6. 重启 `openclaw-gateway`
7. 强制重建 `main` memory 索引并完成搜索验收

### 最终验收
- `openclaw config validate`
  - 通过
- `openclaw memory index --agent main --force`
  - 成功
- `openclaw memory status --deep --json`
  - `embeddingProbe.ok = true`
  - `vector.dims = 2560`
- `openclaw memory search --agent main --json --query 'kevinlasnh' --max-results 5`
  - 成功返回结果
- GPU 实测：
  - 常驻约 `2.4GB`
  - 重建索引约 `3.0GB`
  - 未再爆显存

### 当前停点
- 用户当前可直接试用 `main` 的语义搜索效果
- 若后续再次 `openclaw update`，优先检查：
  - 单点补丁是否被覆盖
  - `memorySearch.local.modelPath` 是否仍指向 `Qwen3-Embedding-4B-Q4_K_M.gguf`

### 保留噪声
- `amazon-bedrock` 插件缺失依赖仍会在日志中报错
- 当前不影响：
  - `main` 的 Telegram
  - `openai-codex/gpt-5.4`
  - `Qwen3-Embedding-4B-Q4_K_M` 本地语义检索

### 后续待办
- 向 OpenClaw 上游提交一个 PR：
  - 为 `memorySearch.local` 暴露原生参数：
    - `contextSize`
    - `gpu`
    - `gpuLayers`
    - 可选 `flashAttention`
- 目标：
  - 让低显存机器不再需要手改 dist bundle
  - 保持默认行为不变，仅增加配置透传能力

## 新任务（2026-04-03 中午）：main 提升长任务超时并清理自定义 Skill / 杂物（已完成，范围后续收窄到只保 main）

### 目标
- 先把 `main` 的：
  - `agents.defaults.timeoutSeconds`
  提升到：
  - `3600`
- 清理主实例和 home 下明显的 Skill / 备份 / 缓存 / 工作流残留
- 明确保留：
  - `~/.openclaw/workspace/AGENTS.md`
  - `~/.openclaw/workspace/SOUL.md`
  - `~/.openclaw/workspace/TOOLS.md`
  - `~/.openclaw/workspace/IDENTITY.md`
  - `~/.openclaw/workspace/USER.md`
  - `~/.openclaw/workspace/HEARTBEAT.md`
  - `~/.openclaw/workspace/BOOT.md`
  - `~/.openclaw/workspace/MEMORY.md`
  - `~/.openclaw/workspace/memory/`

### 已执行
- 已将 `main` 的：
  - `agents.defaults.timeoutSeconds = 3600`
  写入：
  - `~/.openclaw/openclaw.json`
- 已删除主实例下以下典型残留：
  - `~/.openclaw/skills`
  - `~/.openclaw/workspace/skills`
  - `~/.openclaw/workspace/task_plan.md`
  - `~/.openclaw/workspace/findings.md`
  - `~/.openclaw/workspace/progress.md`
  - `~/.openclaw/workspace/.agents`
  - `~/.openclaw/workspace/.clawhub`
  - `~/.openclaw/workspace/.learnings`
  - `~/.openclaw/workspace/.openclaw`
  - `~/.openclaw/workspace/.ssh`
  - `~/.openclaw/browser`
  - `~/.openclaw/media`
  - `~/.openclaw/tasks`
  - `~/.openclaw/sandboxes`
  - `~/.openclaw/completions`
  - `~/.openclaw/logs`
  - `~/.openclaw/subagents`
  - `~/.openclaw` 根目录下的 `openclaw.json.bak*` / `openclaw.json.pre-*` / `.env.pre-*`
  - 异常文件名：
    - `~/.openclaw/openclaw.json\r`
- 已删除 home 下明显外溢残留：
  - `~/.agents`
  - `~/.pinchtab`
  - `~/migration-backup`
  - `~/.openclaw.pre-migration-20260308-074232`
  - `~/.cache/oc-dayong-kimi-research`
  - `~/.cache/oc-main-kimi-regression-check`
  - `~/.cache/oc-main-kimi-regression-check2`
  - `~/.cache/oc-main-kimi-research`
  - `~/.local/bin/pinchtab`
  - `~/.local/share/Trash/files/trading-brain`
- 已清理 `main` 的会话缓存：
  - `~/.openclaw/agents/main/sessions`
  以去掉旧的 Skill 清单缓存

### 边界修正
- 用户在执行中途明确收窄要求：
  - **后续只动 `main`**
- 在用户收窄范围前，本轮已经误触并删除了：
  - `~/.openclaw-dayong/skills`
  - `~/.openclaw-dayong/workspace/skills`
  - `~/.openclaw-chunyan/workspace/skills`
- 用户发出“别动另外三个 Gateway”后，本轮已停止继续改动其它实例文件。

### 最终结果
- `main` 当前静态配置：
  - `agents.defaults.timeoutSeconds = 3600`
- `main` 当前最小自检：
  - `MAIN_SESSION_PURGE_OK`
- 当前新的 `main` 会话已不再继承旧 Skill 缓存：
  - 运行时只剩 bundled：
    - `healthcheck`
    - `weather`
- `~/.openclaw` 与 `~/.openclaw/workspace` 下当前已无任何 `SKILL.md`
- 四个 Gateway 当前服务状态仍为：
  - `active`

### 追加复核（2026-04-03 下午）
- 已补做：
  - `main` 的 `/status` 上下文窗口现场复核
- 当前 live 结果为：
  - `📚 Context: 29k/272k (11%)`
- 已确认：
  - `~/.openclaw/openclaw.json` 没有把上下文固定到 `200000`
  - `main` 当前几个活动会话的 `contextTokens` 都是：
    - `272000`
- 当前停点更新为：
  - `main` 的 GPT-5.4 上下文展示已确认正确
  - 如果用户仍看到 `200k`，优先按旧消息 / 旧会话排查，不再先改 live 配置

## 追加任务（2026-04-06）：`main` 切智谱 `GLM-5.1` 并复核多模态路由

### 目标
- 只改：
  - `main`
- 将：
  - `zai/glm-5.1`
  设为主模型
- 将：
  - `minimax/MiniMax-M2.7`
  设为第一 fallback
- 同时回答：
  - 当前图片/PDF/图像生成等能力还缺什么显式配置

### 已完成
- ✅ 已核对智谱官方 `OpenClaw` 接入文档与 OpenClaw 官方 provider 文档
- ✅ 已备份远端：
  - `~/.openclaw/openclaw.json`
  - `~/.openclaw/.env`
- ✅ 已向 `main` 写入：
  - `models.providers.zai`
  - `agents.defaults.model.primary = zai/glm-5.1`
  - `agents.defaults.model.fallbacks = [minimax/MiniMax-M2.7]`
- ✅ 已补入：
  - `ZAI_API_KEY`
- ✅ 已修正 `minimax` provider 的 `input` 元数据为：
  - `["text","image"]`
- ✅ 已通过：
  - `openclaw config validate`
- ✅ 已重启：
  - `openclaw-gateway`
- ✅ 已完成最小实呼验收：
  - `MAIN_GLM51_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5.1`

### 当前状态
- `main` 文本主链路当前为：
  - `zai/glm-5.1 -> minimax/MiniMax-M2.7`
- `main` 当前图片输入链路仍为：
  - `imageModel = kimi/k2p5`
- 当前未显式配置：
  - `imageGenerationModel`
  - `pdfModel`
  - `audioTranscriptionModel`
  - `ttsModel`
- 但运行时工具当前已确认仍暴露：
  - `pdf`
  - `image_generate`

### 下一步待用户决策
- 方案 A：
  - 保持当前 `imageModel = kimi/k2p5`
  - 优点：
    - 不继续改 live
    - 当前图片路由可直接沿用
  - 缺点：
    - 模型栈不统一
- 方案 B：
  - 将 `imageModel` 切到：
    - `minimax/MiniMax-M2.7`
  - 优点：
    - 利用当前已验证的 `MiniMax` key
    - 与现有第一 fallback 统一
  - 缺点：
    - 不是智谱套餐内模型
- 方案 C：
  - 进一步显式补：
    - `zai/glm-5v-turbo`
    并将其设为 `imageModel`
  - 优点：
    - 图片理解链路也收敛到智谱套餐
  - 缺点：
    - 当前这台机器的 bundled catalog 没直接枚举出它，仍建议按手工 provider 配置方式补入后再验证

### 后续状态更新（2026-04-06 中午）
- ✅ 用户已确认采用原 `方案 C`
- ✅ 已完成：
  - `imageModel.primary = zai/glm-5v-turbo`
  - `imageModel.fallbacks = [minimax/MiniMax-M2.7]`
- ✅ 已做完：
  - 配置校验
  - 智谱带图最小请求验收
  - `main` Gateway 重启
  - 文本主链路回归自检
- 当前剩余的多模态待决项只剩：
  - 是否继续显式钉死：
    - `pdfModel`
    - `imageGenerationModel`
    - `audioTranscriptionModel`
    - `ttsModel`

### 当前停点（2026-04-06 中午）
- ✅ 用户已确认：
  - 先不继续配置以上 4 项
- 当前任务到此收束，后续如继续推进，多模态配置优先级仍建议按：
  - `imageGenerationModel`
  - `ttsModel`
  - `audioTranscriptionModel`
  - `pdfModel`

## Session: 2026-04-07（另外三个 Gateway 切到 `GLM-5` 并重启）

### 用户目标
- 将除 `main` 外的三个实例：
  - `dayong`
  - `chunyan`
  - `zenglan`
  的 Gateway 全部重启
- 并把三者文本主模型统一改为：
  - `zai/glm-5`

### 已完成
- ✅ 已确认三者原主模型分别为：
  - `dayong = minimax/MiniMax-M2.7`
  - `chunyan = minimax/MiniMax-M2.5`
  - `zenglan = minimax/MiniMax-M2.5`
- ✅ 已为三者补入：
  - `ZAI_API_KEY`
- ✅ 已分别备份：
  - `openclaw.json.pre-glm5-20260407-195846`
  - `.env.pre-glm5-20260407-195846`
- ✅ 已把三者配置统一改为：
  - `agents.defaults.model.primary = zai/glm-5`
  - `agents.defaults.model.fallbacks = []`
  - `agents.defaults.models = { "zai/glm-5": {} }`
- ✅ 已显式补入三者的：
  - `models.providers.zai`
  - `baseUrl = https://open.bigmodel.cn/api/coding/paas/v4`
  - `api = openai-completions`
  - `apiKey = ${ZAI_API_KEY}`
  - `glm-5` 模型目录
- ✅ 三者均已通过：
  - `openclaw config validate`
- ✅ 三者 Gateway 均已执行：
  - `systemctl --user restart`

### 已验收结果
- ✅ `chunyan` 最小实呼通过：
  - 返回：
    - `CHUNYAN_GLM5_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5`
- ✅ `zenglan` 最小实呼通过：
  - 返回：
    - `ZENGLAN_GLM5_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5`
- ⚠️ `dayong` 最小实呼文本本身返回：
  - `DAYONG_GLM5_OK`
  但同轮返回元数据仍显示：
  - `provider = minimax`
  - `model = MiniMax-M2.7`

### 后续复核与修正
- ✅ 已纠正运维入口判断：
  - 当前 live 小龙虾运行在远程 Ubuntu：
    - `100.64.65.65`
  - 不在本地 WSL
- ✅ 通过 SSH 复核发现：
  - `dayong` 的问题不是 Gateway 没重启
  - 而是 `~/.openclaw-dayong/openclaw.json` 里：
    - `agents.list[].model`
    仍显式写着：
    - `minimax/MiniMax-M2.7`
  - 覆盖了：
    - `agents.defaults.model.primary = zai/glm-5`
- ✅ 已对 `dayong` 生成新备份：
  - `/home/kevinlasnh/.openclaw-dayong/openclaw.json.pre-dayong-glm5-agentslist-20260407-204153`
- ✅ 已将以下 5 个 agent 的显式模型统一改成：
  - `zai/glm-5`
  - `dayong`
  - `sector`
  - `stock`
  - `market`
  - `strategy`
- ✅ 已再次执行：
  - `openclaw config validate`
  - `systemctl --user restart openclaw-gateway-dayong`

### 最终验收结果
- ✅ `dayong` 二次最小实呼通过：
  - 返回：
    - `DAYONG_GLM5_RECHECK2_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5`
- ✅ `chunyan` 复核通过：
  - 返回：
    - `CHUNYAN_GLM5_RECHECK2_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5`
- ✅ `zenglan` 复核通过：
  - 返回：
    - `ZENGLAN_GLM5_RECHECK2_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5`

### 当前状态
- 本轮任务已完成：
  - `dayong`
  - `chunyan`
  - `zenglan`
  三个远程 Gateway 均已重启，并确认 live 运行于：
  - `zai/glm-5`

## 任务：2026-04-08 将 `main` 升级到当前 npm latest（`2026.4.7`）并恢复可用

### 目标
- 保持：
  - `main`
  运行在当前最新：
  - `OpenClaw 2026.4.7`
- 同时恢复：
  - 主 Gateway
  - Telegram webhook
  - 最小实呼

### 已执行
- ✅ 已确认当前 npm latest 仍是：
  - `2026.4.7`
- ✅ 已定位并修复 `2026.4.7` 的 3 类上游缺口：
  1. 缺失：
     - `grammy`
  2. 多个 channel extension 缺失：
     - `dist/extensions/*/src/secret-contract.js`
     - `dist/extensions/telegram/src/channel.setup.js`
  3. Telegram runtime 继续缺失：
     - `@grammyjs/runner`
     - `@grammyjs/transformer-throttler`
- ✅ 已额外确认一个现场坑：
  - 真实 wrapper 使用的是：
    - `~/.local/share/pnpm/global/5/.pnpm`
  - 不是：
    - `~/.local/share/pnpm/global/5/node_modules/.pnpm`
- ✅ 已在真实运行树完成热修
- ✅ 已重新启动：
  - `openclaw-gateway`

### 已验收结果
- ✅ `openclaw config validate`
  - 通过
- ✅ `systemctl --user is-active openclaw-gateway`
  - 返回：
    - `active`
- ✅ Telegram 日志恢复：
  - `starting provider`
  - `webhook local listener`
  - `webhook advertised to telegram`
- ✅ 最小实呼通过：
  - `MAIN_202647_OK`
  - live 元数据：
    - `provider = zai`
    - `model = glm-5.1`

### 当前停点
- `main` 当前已运行在：
  - `OpenClaw 2026.4.7`
- 但本次属于：
  - **安装树内热修**
  不是：
  - 干净上游修复版
- 后续若再次升级或重装，
  - 默认应复查：
    - `grammy`
    - `@grammyjs/runner`
    - `@grammyjs/transformer-throttler`
    - `dist/extensions/*/src/*.js`
  是否又被覆盖

## 追加状态：2026-04-08 同日再次复发后，已按同一热修路径重新恢复

### 新情况
- 同日后续主实例再次跌回：
  - `Cannot find module 'grammy'`
- 说明前一轮对：
  - `2026.4.7`
  的安装树热修已被覆盖

### 已处理
- ✅ 已重新写回：
  - `dist/extensions/*/src/secret-contract.js`
  - `dist/extensions/telegram/src/channel.setup.js`
- ✅ 已重新补齐：
  - `grammy`
  - `@grammyjs/runner`
  - `@grammyjs/transformer-throttler`
- ✅ 已再次通过：
  - `openclaw config validate`
- ✅ 已再次验收：
  - `MAIN_RESTORED_OK`
  - `telegram sendMessage ok`

### 当前停点
- 当前 `main` 已恢复
- 但该问题的真正结论进一步收敛为：
  - **当前热修只要被安装树覆盖，就必须重打**

## 新任务（2026-04-28）：main 切到 Xiaomi MiMo V2.5 Pro，DeepSeek V4 Pro 作为 fallback（已完成 ✅）

### 目标
- 只修改 `main` 小龙虾
- 将文本主模型切到：
  - `xiaomi-mimo/mimo-v2.5-pro`
- 将 fallback 设置为：
  - `deepseek/deepseek-v4-pro`
- Xiaomi endpoint 能直连时通过 `NO_PROXY/no_proxy` 绕过 Mihomo
- 图片模型只有在 Xiaomi 入口实际支持图片输入时才配置

### 当前进展
- ✅ 已确认 Xiaomi Token Plan CN Anthropic 入口文本请求可用
- ✅ 已确认远端直连 Xiaomi endpoint 可用，且快于经 `127.0.0.1:7897` 代理
- ✅ 已确认带图请求虽然 HTTP 200，但模型未看到图片
- ✅ 因此未配置 `imageModel`
- ✅ 已备份远端 main 配置：
  - `/home/kevinlasnh/.openclaw-backups/main-xiaomi-mimo-v25-20260428-134959`
- ✅ 已写入 `XIAOMI_MIMO_API_KEY` 到远端 `~/.openclaw/.env`（不记录明文）
- ✅ 已新增 `models.providers.xiaomi-mimo`
- ✅ 已设置：
  - `agents.defaults.model.primary = xiaomi-mimo/mimo-v2.5-pro`
  - `agents.defaults.model.fallbacks = [deepseek/deepseek-v4-pro]`
  - `agents.defaults.models = {xiaomi-mimo/mimo-v2.5-pro, deepseek/deepseek-v4-pro}`
- ✅ 已更新 main 的 systemd drop-in：
  - `NO_PROXY/no_proxy` 包含 Xiaomi 与 DeepSeek 域名
- ✅ 已 `daemon-reload` 并重启 `openclaw-gateway`
- ✅ 已通过：
  - `openclaw config validate`
  - `openclaw models status --json`
  - `openclaw agent --agent main` 最小实呼
  - `openclaw gateway health --json`
  - Mihomo `generate_204` 代理回归

### Phase 1: 接口和直连验证
- **Status:** complete

### Phase 2: main 配置迁移
- **Status:** complete

### Phase 3: 重启与验收
- **Status:** complete

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Xiaomi Anthropic 入口带图请求 HTTP 200 但模型回复未看到图片 | 1x1 PNG 与 80x80 PNG 各测一次 | 判定该入口当前不适合配置为 OpenClaw `imageModel`；保持 `imageModel = null` |

## 新任务（2026-06-08 19:36 +08:00）：春艳 Feishu 小龙虾修复与旧 GLM session 清理

### 目标
- 修复春艳 Feishu 私聊不回复的问题。
- 清理用户侧仍显示 GLM 5 的旧 session 残留。
- 刷新春艳用户直聊 session，并确认真人 Feishu 聊天能正常入站、派发和回复。

### Phase 1: Feishu 插件升级与三套 Feishu Gateway 验收
- **Status:** complete
- 已备份三套 Feishu Gateway 到：
  - `/home/kevinlasnh/.openclaw-backups/feishu-2026061-plugin-session-fix-20260608-193610`
- 已将 `dayong` / `chunyan` / `zenglan` 的 `@openclaw/feishu` 升级到 `2026.6.1`。
- 已重启三个 Feishu Gateway。
- 已验证三者：
  - service `active/running`
  - `NRestarts=0`
  - `plugins inspect feishu` 为 `Version: 2026.6.1`
  - `gateway health ok=true`
  - `channels status --probe` 成功

### Phase 2: 春艳直聊 session 刷新
- **Status:** complete
- 已移除旧直聊 session entries 并备份旧 session 文件到：
  - `/home/kevinlasnh/.openclaw-backups/feishu-2026061-plugin-session-fix-20260608-193610/chunyan/session-refresh`
- 已创建并验证当前直聊 session：
  - key: `agent:chunyan:feishu:chunyan-feishu:direct:ou_e4c865918d1b26e9ff11a09034e08970`
  - sessionId: `59f6636c-6398-49ee-a661-d737d4479746`
  - provider/model: `zzedu/gpt-5.5`
- 已通过春艳真人 19:53 入站验证：
  - `received message`
  - `dispatching to agent`
  - `dispatch complete (queuedFinal=true, replies=1)`

### Phase 3: 清理旧 GLM / MiniMax 子会话残留
- **Status:** complete
- 已发现与同一个 Feishu 用户相关的历史 subagent sessions 仍残留 `zai/glm-5` / `MiniMax-M2.5` 字段。
- 已备份并归档 43 个旧子会话 entries 与 43 个 session jsonl 文件到：
  - `/home/kevinlasnh/.openclaw-backups/chunyan-stale-glm-session-purge-20260608-195630`
- 已重启 `openclaw-gateway-chunyan`。
- 清理后验证：
  - `relatedCount=1`
  - `staleRelatedCount=0`
  - 唯一剩余相关 session 为当前 `zzedu/gpt-5.5` direct session。

### Phase 4: 重启后真人聊天验收
- **Status:** complete
- 春艳当前 service：
  - `ActiveState=active`
  - `SubState=running`
  - `NRestarts=0`
- 春艳 Gateway：
  - `gateway health ok=true`
  - Feishu `running=true / lastError=null`
  - `eventLoop.degraded=false`
  - `channels status --probe` 成功
- 重启后真人入站验证：
  - 19:58:16 收到春艳 Feishu 入站。
  - 20:00:47 `dispatch complete (queuedFinal=true, replies=1)`。
  - 20:00:47 再次收到春艳 `OK`。
  - 20:00:53 再次 `dispatch complete (queuedFinal=true, replies=1)`。
- 最终 session lock 为空，未再出现 `failed to dispatch`、`SessionWriteLockTimeout`、`PluginLoadFailure`、`Cannot find module`、`429`。

### Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `openclaw agent --thinking xhigh` 被 CLI 拒绝 | 用 CLI 手动覆盖 thinking | 不再用 CLI 覆盖 `xhigh`；保留配置默认值，或验证时使用 `high` |
| Feishu 直接文本发送撞到当前 session jsonl lock | 真人入站正在处理同一 session | 未删锁；等待该轮入站完成，锁自动释放 |

## 新任务（2026-04-28）：main 配置 Xiaomi MiMo V2.5 为图片理解模型（已完成 ✅）

### 目标
- 从用户提供的小米模型列表中筛选真正支持图片输入的模型
- 只给 `main` 配置一个 Xiaomi 图片理解模型
- 保持文本主模型仍为 `xiaomi-mimo/mimo-v2.5-pro`
- 保持文本 fallback 仍为 `deepseek/deepseek-v4-pro`

### 当前进展
- ✅ 已用同一 Xiaomi Anthropic 入口测试图片块输入
- ✅ 已确认可看图：
  - `mimo-v2.5`
  - `mimo-v2-omni`
- ✅ 已确认不适合作为图片模型：
  - `mimo-v2-pro`
  - `mimo-v2.5-pro`
  - TTS 系列
- ✅ 已选择更偏新的 V2.5 系列模型：
  - `xiaomi-mimo/mimo-v2.5`
- ✅ 已备份远端配置：
  - `/home/kevinlasnh/.openclaw-backups/main-xiaomi-image-mimo-v25-20260428-140412`
- ✅ 已配置：
  - `agents.defaults.imageModel.primary = xiaomi-mimo/mimo-v2.5`
  - `agents.defaults.imageModel.fallbacks = []`
  - `models.providers.xiaomi-mimo.models[].id = mimo-v2.5`
  - `mimo-v2.5.input = ["text", "image"]`
- ✅ 已通过：
  - `openclaw config validate`
  - `openclaw models status --json`
  - `openclaw agent --agent main` 文本 smoke test
  - `openclaw gateway health --json`
  - Mihomo `generate_204` 代理回归

### Phase 1: 候选多模态模型实测
- **Status:** complete

### Phase 2: imageModel 配置
- **Status:** complete

### Phase 3: 重启与验收
- **Status:** complete
