# 新发现（2026-06-08）：OpenClaw 2026.6.1 升级过程与四 Gateway 验收

## 现场结论
- 远端 OpenClaw 已从：
  - `OpenClaw 2026.5.22 (a374c3a)`
  升级到：
  - `OpenClaw 2026.6.1 (2e08f0f)`
- npm registry 实测 `openclaw` latest 为 `2026.6.1`。
- 升级前备份目录：
  - `/home/kevinlasnh/.openclaw-backups/pre-openclaw-20260601-upgrade-20260608-161549`

## 升级执行要点
- 非交互 SSH 环境中仍建议显式设置：
  - `PNPM_HOME=$HOME/.local/share/pnpm`
  - `PATH=$PNPM_HOME:$PNPM_HOME/global/5/node_modules/.bin:$PATH`
- 本轮执行：
  - `openclaw update --tag latest --yes --no-restart`
- 本轮未复发 2026.5.22 升级时 pnpm global shim 卡住 / 丢失的问题。
- 升级后 shim 正常：
  - `~/.local/share/pnpm/openclaw`
  - `~/.local/share/pnpm/global/5/node_modules/openclaw -> ../.pnpm/openclaw@2026.6.1/node_modules/openclaw`

## 重启和验收
- 已重启四个 Gateway：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 最终四个 Gateway 均：
  - service `active/running`
  - `NRestarts=0`
  - config valid
  - `gateway health ok=true`
  - `pluginErrors=0`
  - session lock `0`
- 通道最终状态：
  - main Telegram `running=true / lastError=null`
  - dayong Feishu `running=true / lastError=null`
  - chunyan Feishu `running=true / lastError=null`
  - zenglan Feishu `running=true / lastError=null`
- 代理回归：
  - `127.0.0.1:7897` 到 `https://www.gstatic.com/generate_204` 返回 `204`

## 全 Agent smoke
- 13 个 configured agents 全部不投递 smoke test 通过：
  - main 1 个：`deepseek/deepseek-v4-pro`
  - dayong 8 个：`zzedu/gpt-5.5`
  - chunyan 2 个：`zzedu/gpt-5.5`
  - zenglan 2 个：`zzedu/gpt-5.5`

## 注意事项
- `openclaw update` 后、Gateway 重启前，旧 Gateway 进程仍可能持有旧安装树引用；`openclaw doctor` 的 Gateway health 在此窗口可能报旧版本模块找不到。
- 本轮重启瞬间四个旧 2026.5.22 进程均记录了 shutdown error：
  - 旧进程 import `openclaw@2026.5.22` 下已被替换的 `hook-runner-global.js` 失败。
- 新 2026.6.1 进程启动后，health、通道、smoke、最终红旗日志复查均正常；该 shutdown error 可判定为升级重启瞬间的旧进程退出噪声。
- 升级后出现 state migration 日志，将 task registry / delivery queue / flow sidecar 数据迁移到 shared SQLite state；迁移完成后 Gateway 正常。

# 新发现（2026-06-08）：chunyan / zenglan 可直接复用 dayong 的 zzedu GPT 5.5Base 配置

## 现场结论
- `dayong` 当前 live GPT 5.5Base 配置为：
  - provider: `zzedu`
  - model: `zzedu/gpt-5.5`
  - baseUrl: `https://api.zzedu.org/v1`
  - api: `openai-completions`
  - defaults: `thinkingDefault=xhigh`、`reasoningDefault=off`、`verboseDefault=on`
- `chunyan` / `zenglan` 原本只有 `ZAI_API_KEY` / `MINIMAX_API_KEY`，没有 `ZZEDU_API_KEY`。
- 将两个目标 Gateway 切到 GPT 5.5Base 时，需要同时复制：
  - `models.providers.zzedu`
  - `.env` 中的 `ZZEDU_API_KEY`

## 已落地
- 远端备份目录：
  - `/home/kevinlasnh/.openclaw-backups/chunyan-zenglan-zzedu-gpt55-20260608-155454`
- 已修改：
  - `~/.openclaw-chunyan/openclaw.json`
  - `~/.openclaw-chunyan/.env`
  - `~/.openclaw-zenglan/openclaw.json`
  - `~/.openclaw-zenglan/.env`
- 未修改 / 未重启 `main`。
- 未修改 / 未重启 `dayong`。

## 验收
- `chunyan` / `zenglan` 两套 `openclaw config validate` 均通过。
- 两个 Gateway health 均 `ok=true`，Feishu `running=true / lastError=null`。
- 全部目标 configured agents 不投递 smoke test 均走 `provider=zzedu`、`model=gpt-5.5`：
  - `chunyan/chunyan`
  - `chunyan/dzxy`
  - `zenglan/zenglan`
  - `zenglan/gre-tutor`

## xhigh 报告口径
- 配置层 `thinkingDefault=xhigh` 已写入 `chunyan` / `zenglan`，与 `dayong` 一致。
- OpenClaw 2026.5.22 对 `zzedu/gpt-5.5` 实呼的 `requestShaping.thinking` 报告为 `high`。
- `dayong/market` 在相同 `xhigh` 配置下的对照 smoke 也报告 `requestShaping.thinking=high`，因此该差异属于 runtime/provider 报告口径，不代表目标配置未写入 `xhigh`。

# 新发现（2026-05-24）：OpenClaw 2026.5.22 升级需要注意 pnpm global shim 和旧外部插件 runtime

## 现场结论
- 远端从 `OpenClaw 2026.5.3 (06d46f7)` 升级到 `OpenClaw 2026.5.22 (a374c3a)`。
- npm latest 当前为 `2026.5.22`。
- main 默认文本模型已切为：
  - primary: `deepseek/deepseek-v4-pro`
  - fallback: `xiaomi-mimo/mimo-v2.5-pro`
- main 仍保持：
  - `imageModel.primary = xiaomi-mimo/mimo-v2.5`
  - `thinkingDefault = high`
  - `reasoningDefault = off`
  - `verboseDefault = on`

## pnpm global 升级坑
- `openclaw update --tag latest --yes --no-restart` 在非交互 SSH 环境中第一次失败：
  - `ERR_PNPM_NO_GLOBAL_BIN_DIR`
  - 原因是 SSH 非交互环境没有 `PNPM_HOME`，而当前 `/usr/bin/openclaw` wrapper 指向 `~/.local/share/pnpm/openclaw`。
- 第二次带 `PNPM_HOME=$HOME/.local/share/pnpm` 后，pnpm 已把 `openclaw@2026.5.22` 包目录写入：
  - `~/.local/share/pnpm/global/5/.pnpm/openclaw@2026.5.22/node_modules/openclaw`
- 但 pnpm 卡在全局安装收尾阶段，`~/.local/share/pnpm/openclaw` shim 暂时缺失，导致 `/usr/bin/openclaw` 入口失败。
- 处理方式：
  - 确认 pnpm 进程长时间无文件进展后终止卡住的 `openclaw update` / `pnpm add -g openclaw@latest` 进程。
  - 重建：
    - `~/.local/share/pnpm/global/5/node_modules/openclaw -> ../.pnpm/openclaw@2026.5.22/node_modules/openclaw`
    - `~/.local/share/pnpm/openclaw` shim，执行 `node "$HOME/.local/share/pnpm/global/5/node_modules/openclaw/openclaw.mjs" "$@"`
  - 验证：
    - `/usr/bin/openclaw --version`
    - `~/.local/share/pnpm/openclaw --version`
    - `~/.local/share/pnpm/global/5/node_modules/.bin/openclaw --version`
  - 三者均返回 `OpenClaw 2026.5.22 (a374c3a)`。

## dayong 外部插件漂移
- 升级后首轮重启，`openclaw-gateway-dayong` 启动为 `0 plugins`，`gateway health` 中 `channels={}`。
- 根因：
  - dayong 的 `@openclaw/feishu` 和 `@openclaw/brave-plugin` 仍为 `2026.5.2`。
  - 这些包只有 TypeScript entry，缺 `dist/index.js` / `dist/setup-entry.js`，OpenClaw 2026.5.22 不把它们加载为 runtime plugin。
- 修复：
  - `OPENCLAW_STATE_DIR=$HOME/.openclaw-dayong OPENCLAW_CONFIG_PATH=$HOME/.openclaw-dayong/openclaw.json openclaw plugins install --force --pin --dangerously-force-unsafe-install @openclaw/feishu@2026.5.3`
  - `OPENCLAW_STATE_DIR=$HOME/.openclaw-dayong OPENCLAW_CONFIG_PATH=$HOME/.openclaw-dayong/openclaw.json openclaw plugins install --force --pin --dangerously-force-unsafe-install @openclaw/brave-plugin@2026.5.3`
  - `openclaw plugins registry --refresh`
  - `systemctl --user restart openclaw-gateway-dayong`
- 验收：
  - `openclaw plugins inspect feishu` 显示 `Status: loaded`、`Version: 2026.5.3`。
  - `openclaw plugins inspect brave` 显示 `Status: loaded`、`Version: 2026.5.3`。
  - dayong `gateway health ok=true`，Feishu 8 个账号 `running=true / lastError=null`。
  - `channels status --probe` 对 dayong 8 个 Feishu bot 均返回 probe ok。

## 最终验收
- 四个 Gateway 均 `active/running`，四套 `openclaw config validate` 均通过。
- 四个 `gateway health` 均 `ok=true`。
- 近期红旗日志为空：
  - `PluginLoadFailure`
  - `sendMessage failed`
  - `Cannot find module`
  - `stuck session`
  - `429`
- 四套 session lock 均为空。
- 全部 configured agents 不投递 smoke test 通过：
  - main: `deepseek/deepseek-v4-pro`
  - dayong 8 个 agents: `zzedu/gpt-5.5`
  - chunyan: `zai/glm-5`
  - zenglan / gre-tutor: `zai/glm-5`

# 新发现（2026-05-06）：GTD 09:00 Telegram 失败再次定位到 Mihomo Telegram 节点建连超时

## 已落地修复（2026-05-06 11:52 +08:00）
- 已重排 Mihomo `telegram-jp-tw-stable` fallback 组，避免历史准点失败节点继续作为首选。
- 备份：
  - `/home/kevinlasnh/.openclaw-backups/mihomo-telegram-order-20260506-115229/clash-verge.yaml`
- 新顺序：
  1. `专线2.5x-台湾2-GPT`
  2. `高速隧道1x-台湾2-GPT`
  3. `高速隧道1x-日本2-GPT`
  4. `高速隧道1x-日本1-GPT`
  5. `专线2.5x-日本4-GPT`
  6. `高速隧道1x-日本3-GPT`
  7. `专线2.5x-日本3-GPT`
  8. `专线2.5x-日本1-GPT`
  9. `专线2.5x-日本2-GPT`
  10. `高速隧道1x-台湾1-GPT`
  11. `专线2.5x-台湾1-GPT`
  12. `高速隧道1x-日本4-GPT`
- 排序理由：
  - `专线2.5x-台湾1-GPT` 当前测速快，但在 2026-05-04 / 05 / 06 的 09:00 窗口反复出现 `112.90.88.2:30021` 建连超时，因此降到倒数第二。
  - `高速隧道1x-日本4-GPT` 当前 Telegram API 延迟最高，且历史出现过 `140.233.191.150:34044` 失败，因此降到最后。
  - `专线2.5x-台湾2-GPT` 和 `高速隧道1x-台湾2-GPT` 当前对 `api.telegram.org` 延迟低，且未见 09:00 历史失败，放在前两位。
- 已 `verge-mihomo -t` 校验通过并重启 `mihomo-standalone`。
- 验收：
  - service `active/running`，PID `2220692`
  - controller：`telegram-jp-tw-stable.now = 专线2.5x-台湾2-GPT`
  - `https://api.telegram.org/` 经 `127.0.0.1:7897` 连续 5 次返回 `302`
  - Mihomo 日志显示实际命中新第一节点 `telegram-jp-tw-stable[专线2.5x-台湾2-GPT]`
  - main Telegram health 仍为 `running=true / connected=true / lastError=null`

## 今日现场证据
- 2026-05-06 09:00 的 `gtd-inbox-reminder-0900` 已触发，不是 cron 没跑：
  - job id：`46c6e47f-e759-450f-a9c8-b659a0661e2c`
  - session：`bbbf8726-aa78-4e50-83c2-65eb3b21a3c5`
  - session key：`agent:main:cron:46c6e47f-e759-450f-a9c8-b659a0661e2c:run:bbbf8726-aa78-4e50-83c2-65eb3b21a3c5`
- session JSONL 显示模型链路成功：
  - 09:00:01 启动。
  - 09:00:12 assistant 生成正确文本：`🐰 早上好！Inbox 在等你清理哦～回复「开始整理 Inbox」，我们一起来看看有什么待办，顺便挑今天最多 3 个 MIT 吧！`
  - trajectory `model.completed` 为成功，`timedOut=false`，`aborted=false`。
- cron 状态当前记录：
  - `lastRunAtMs=1778029200011`
  - `lastRunStatus=ok`
  - `lastDelivered=false`
  - `lastDeliveryStatus=not-delivered`
  - `consecutiveErrors=0`
- Gateway 投递失败点：
  - `2026-05-06T09:00:17.283+08:00 [telegram] message failed: Network request for 'sendMessage' failed!`
  - `[cron:46c6e47f-e759-450f-a9c8-b659a0661e2c] delivery payload failed (bestEffort)`
- Mihomo 同一窗口明确记录：
  - `2026-05-06T09:00:17.273+08:00`
  - `telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`
  - `127.0.0.1:54252 --> api.telegram.org:443`
  - `failed to create session: dial tcp 112.90.88.2:30021: i/o timeout`

## 跨天对比
- 2026-05-04 09:00 同类失败：
  - Gateway：`09:00:12.486 [telegram] message failed`
  - Mihomo：`telegram-jp-tw-stable[专线2.5x-台湾1-GPT]` 到 `112.90.88.2:30021` `i/o timeout`
  - 09:00:28 还出现一次 `context deadline exceeded`
- 2026-05-05 09:00 已记录同类失败：
  - `telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`
  - `api.telegram.org:443`
  - `i/o timeout` / `context deadline exceeded`
- 对比正常窗口：
  - 2026-05-05 13:00 和 19:00 同样走 `telegram-jp-tw-stable`，无 Telegram timeout，Gateway 出现 `sendMessage ok`。

## 判断
- GTD 09:00 reminder 的 cron、prompt、模型输出均正常。
- 失败点是 Telegram delivery 层的 `sendMessage` 网络请求。
- 更具体地说，是 Mihomo 对 `api.telegram.org` 命中 `telegram-jp-tw-stable` 后，当前选中的台湾专线节点在准点投递时建连超时。
- 当前外部/现场没有证据支持 Telegram Bot API 全局故障：
  - 当前代理访问 `https://api.telegram.org/` 连续 5 次返回 `302`，约 `0.63-0.73s`。
  - main Gateway 当前 Telegram health 为 `running=true / connected=true / lastError=null`。
- `bestEffort=true` 会导致：
  - agent turn 本身保持 `ok`。
  - delivery failure 只落为 `not-delivered`。
  - 不会增加 `consecutiveErrors`，也不会自动重试。

## 修复方向
- 不建议继续改 GTD prompt、thinking 或模型；这些不是失败层。
- 建议在可靠性层处理：
  1. 对关键 reminder 增加延迟补偿 job，例如 09:02 / 09:05 再发同一提醒或“如果刚才没收到，补发 Inbox 提醒”。
  2. 调整 `telegram-jp-tw-stable` 的节点顺序或策略，避免 `专线2.5x-台湾1-GPT` 成为准点首选，或移除连续 09:00 超时的节点。
  3. 若希望失败显性化，取消关键 reminder 的 `bestEffort` 并配置 failure alert。

# 新发现（2026-05-06）：main 新一天 new session 后 Thinking 回到 off 的根因是全局默认值

## 现场结论
- 用户反馈：Telegram 主会话在新的一天第一句聊天后会 `new session`，随后 `/status` 显示 `Thinking: off`、`Reasoning: off`。
- 这不是随机刷新，也不是模型不支持 thinking，而是 OpenClaw 的 session 生命周期和当前默认配置共同导致：
  - OpenClaw 默认有 daily reset；文档说明默认在网关主机本地时间 04:00 之后，下一条真实用户消息会为同一个 `sessionKey` 创建新的 `sessionId`。
  - 远端 live main 当前 `~/.openclaw/openclaw.json` 为：
    - `agents.defaults.thinkingDefault = "off"`
    - `agents.defaults.verboseDefault = "on"`
    - 未显式设置 `agents.defaults.reasoningDefault`
  - 当前 Telegram DM session store 已显示用户当天手动调回：
    - `agent:main:telegram:main-bot:direct:8226087994`
    - `thinkingLevel = "high"`
    - `reasoningLevel = "off"`
  - 但 2026-05-06 07:33 新 session 文件开头仍记录 `thinking_level_change = off`，说明 daily rollover 后先按当时全局默认进入 off，之后才被手动 session override 改回 high。

## 机制判断
- `thinking` 和 `reasoning` 是两条独立控制：
  - `thinking high`：请求模型使用更强推理/思考预算。
  - `reasoning off`：不把推理内容显示给用户；不等于不思考。
- 用户期望的组合是合理的：
  - `agents.defaults.thinkingDefault = "high"`
  - `agents.defaults.reasoningDefault = "off"`
  - `agents.defaults.verboseDefault = "on"`
- 源码和文档确认：
  - Thinking resolution order：inline directive → session override → per-agent default → global default → provider default。
  - Reasoning visibility resolution：inline directive → session override → per-agent default → fallback `off`。
  - `agents.defaults.reasoningDefault` 是 agent-tunable allow-list 路径。

## 验证
- live 配置当前通过：
  - `OPENCLAW_STATE_DIR=$HOME/.openclaw OPENCLAW_CONFIG_PATH=$HOME/.openclaw/openclaw.json openclaw config validate`
- 将拟议默认值写入同目录临时文件 `~/.openclaw/openclaw.json.thinking-default-check` 后验证通过：
  - `Config valid: ~/.openclaw/openclaw.json.thinking-default-check`
- 注意：把同一临时配置放到 `/tmp` 验证会因 Brave 插件相对定位变化报 `web_search provider is not available: brave`，该报错不是默认值非法。

## 建议修复
- 若要明天新 session 默认就是用户期望值，只需改 main live 配置：
  - 备份 `~/.openclaw/openclaw.json`
  - 写入 `agents.defaults.thinkingDefault = "high"`
  - 写入 `agents.defaults.reasoningDefault = "off"`
  - 保持 `agents.defaults.verboseDefault = "on"`
  - `openclaw config validate`
  - 重启 `openclaw-gateway`
  - 新 session smoke test 验证 `requestShaping.thinking = high`
- 不建议改 7 个纯提醒 cron 的 `payload.thinking = "off"`；这些提醒保持 off 是为了减少固定提醒输出解释/推理前缀。

## 已落地（2026-05-06 09:36 +08:00）
- 备份：
  - `/home/kevinlasnh/.openclaw-backups/main-thinking-defaults-20260506-093447/openclaw.json`
- 已写入 main live 配置：
  - `agents.defaults.thinkingDefault = "high"`
  - `agents.defaults.reasoningDefault = "off"`
  - `agents.defaults.verboseDefault = "on"`
- 已重启 main Gateway，PID `2215560`。
- 验收：
  - `openclaw config validate` 通过。
  - `gateway health ok=true`，Telegram `running=true / connected=true / lastError=null`。
  - 新 session `thinking-default-smoke-20260506-0935` 返回 `THINKING_DEFAULT_HIGH_OK`。
  - `requestShaping.thinking = "high"`，`requestShaping.verbose = "on"`。
  - transcript 记录 `thinking_level_change = "high"`。
- 纯提醒 cron 的 `payload.thinking = "off"` 未修改。

# 新发现（2026-05-06）：其他三个 Gateway 已统一默认 high/off/on，zenglan 同时修复 Feishu/Brave 插件漂移

## 默认值上线结论
- `dayong`、`chunyan`、`zenglan` 三套 Gateway 已统一设置：
  - `agents.defaults.thinkingDefault = "high"`
  - `agents.defaults.reasoningDefault = "off"`
  - `agents.defaults.verboseDefault = "on"`
- 备份目录：
  - `/home/kevinlasnh/.openclaw-backups/other-gateways-thinking-defaults-20260506-093739`
- 三套 `openclaw config validate` 均通过。
- 三个服务已重启：
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`

## 全 Agent 验收
- 10 个 configured agents 全部不投递实呼成功：
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

## zenglan 额外修复
- 发现 zenglan 在 Agent 层可跑通，但 `gateway health` / `channels status --probe` 初始显示 `channels={}`。
- 根因与春燕 Feishu 死亡问题同类：
  - `plugins.entries.feishu` 配置存在，但插件 registry 没有可加载 Feishu runtime。
  - 同时 zenglan 的旧 Brave 插件 install record 指向 2026.5.2，磁盘 runtime 缺失/入口为 TypeScript，导致 `tools.web.search.provider=brave` 校验失败，进而阻断 Feishu 插件 install record 正常提交。
- 修复备份：
  - `/home/kevinlasnh/.openclaw-backups/zenglan-feishu-plugin-fix-20260506-094302`
  - `/home/kevinlasnh/.openclaw-backups/zenglan-brave-feishu-repair-20260506-094513`
- 修复方式：
  - 临时移除 zenglan `tools.web.search.provider`，让配置先恢复可校验。
  - 安装并 pin `@openclaw/brave-plugin@2026.5.3`。
  - 恢复 `tools.web.search.provider = "brave"`。
  - 确认 `@openclaw/feishu@2026.5.3` loaded。
  - 重启 `openclaw-gateway-zenglan`。
- 最终 zenglan 验收：
  - `Config valid`
  - service `active/running`，PID `2217681`
  - `gateway health ok=true`
  - `channels.feishu.running=true / lastError=null`
  - `channels status --probe` 返回 `botName=zenglan`
  - final smoke 返回 `ZENGLAN_FINAL_THINKING_DEFAULT_OK`

## 注意
- 三套 Gateway 刚重启和连续实呼后，短窗口可能显示 `eventLoop.degraded=true`，常见原因是 CPU/ELU 短采样；只要 `ok=true`、无 plugin errors、真实实呼通过，不单独作为阻断。

# 新发现（2026-05-05）：两个 OpenClaw 上游 PR 的 conflict 已通过最新 rebase 清理

## 现场结论
- Telegram PR `openclaw/openclaw#77211` 已 rebase 到最新 `upstream/main` `a17d4371d1`，最终 head 为 `60a4996d618b802e64e18d2ca8607759a54f808d`。
- Brave PR `openclaw/openclaw#77219` 已 rebase 到最新 `upstream/main` `a17d4371d1`，最终 head 为 `ff12c3e9f064aa595028f3bf015328b8d9240fd0`。
- 两个 PR 的 GitHub 状态最终均为：
  - `mergeable=MERGEABLE`
  - `mergeStateStatus=CLEAN`
- 因为上游 `main` 在本轮中途从 `b4ff3aa73b` 又前进到 `a17d4371d1`，处理 PR conflict 时需要在最终 push 前重新 fetch 并确认当前最新 base。

## 处理要点
- Telegram PR 的冲突点在 archived answer preview finalization：
  - 保留上游 `deleteIfUnused: !answerLaneHasAssistantContent`
  - 保留本 PR 的 `visibleSinceMs` 与 `wasPreviewPushedUpByVisibleDelivery()` 防护
- Brave PR 本轮对最新 base rebase 无新增冲突；昨天已合并的关键 doctor repair 逻辑仍成立：
  - 支持 current bundled plugin index
  - 支持 broken runtime entry diagnostics 触发 configured npm plugin update
  - install record 路径检查同时支持 `installPath` 和 `sourcePath`

## GitHub proof gate
- 外部 PR 当前需要 `## Real behavior proof` section，并包含这些字段：
  - Behavior or issue addressed
  - Real environment tested
  - Exact steps or command run after this patch
  - Evidence after fix
  - Observed result after fix
  - What was not tested
- 仅写 unit test / lint / CI 不够；需要真实环境输出、日志、截图、录屏或 artifact 等 after-fix evidence。
- 本轮两个 PR 都补充了该 section，新一轮 `Real behavior proof` 检查均通过。

# 新发现（2026-05-05）：`gtd-natural-planning` 是触发式注入，普通 smoke 未列出不等于缺失

## 现场结论
- `openclaw-gtd-health` 默认巡检与 `-IncludeTodoistScaffold` 巡检均返回 `STATUS=clean`。
- `openclaw skills list --agent main --json` 显示 `gtd-natural-planning` 为：
  - `eligible=true`
  - `modelVisible=true`
  - `commandVisible=true`
  - `source=openclaw-workspace`
- 普通主 Agent smoke test 的 `systemPromptReport.skills.entries` 未列出 `gtd-natural-planning`，但这是因为该轮没有触发 Natural Planning Skill。
- 使用新的显式 session id 并输入触发词 `开始自然规划` 后，`systemPromptReport.skills.entries` 正常包含 `gtd-natural-planning`，并且该 turn 调用了 `read` 读取对应 `SKILL.md`。

## 判断
- `gtd-natural-planning` 当前不是上线缺失，也不是 Skill registry 漂移。
- 当前 GTD 逻辑闭环仍成立：复杂目标 / 新项目 / 模糊多步成果 / 卡住项目通过 AGENTS 路由进入 Natural Planning；单步独立行动进入 `⚡ single-actions`；cron 只提醒，不承担 GTD 决策。
- 本轮未发现需要修改远端 live main workspace 的 GTD 逻辑问题。

# 新发现（2026-05-05）：GTD `AGENTS.md` 与四个 Skill 的分工边界是合理的

## 判断
- `AGENTS.md` 现在承担 GTD 核心合同、路由、权限和安全边界，不承担完整执行流程。
- 四个 GTD Skill 承担具体工作流：
  - Inbox triage
  - Daily Review
  - Weekly Review
  - Natural Planning
- 当前重复出现的规则主要是安全 guardrail，不属于有害冗余：
  - 用户确认后才 mutation
  - mutation 使用 `id:<task_id>` 或 Todoist URL
  - 日期只用于 hard landscape
  - `td task update --labels` 前必须合并既有标签
- 因此当前结构可判定为：
  - `AGENTS.md` 保留核心闭环逻辑
  - Skill 封装操作流程
  - 没有发现逻辑冲突或需要抽离的明显冗余

# 新发现（2026-05-05）：GTD scaffold 需要 `⚡ single-actions` 才能闭合单步行动归位

## 现场结论
- `openclaw-gtd-health` 默认巡检和 scaffold 巡检均通过，但人工语义审计发现一个机械脚本原先未覆盖的闭环缺口：
  - GTD 要求 Inbox 只是捕获入口，Clarify 后应清空并归位。
  - 系统允许“单步 Next Action”存在。
  - 但当前 scaffold 只有 `🗂 someday-maybe` 和 `🌅 horizons` 两个特殊项目，没有明确承载“不属于任何多步 Project 的独立单步行动”的位置。
- 同时，`AGENTS.md` 的捕获入口使用 `td task quickadd "X"`，Todoist quickadd 可能自动解析自然语言日期、标签或项目；这会把 Capture 与 Clarify/Organize 混在一起，和“先捕获、后澄清”不完全一致。

## 修复结论
- 新增支撑项目：
  - `⚡ single-actions`
- 语义边界：
  - 多步 Project 必须至少有一个 Next Action。
  - 单步独立行动不应被强行升级为 Project；应归位到 `⚡ single-actions`，并用 `@Next Action` + context label 进入执行视图。
  - 捕获入口使用 `td task add "X"` 原样进入 Inbox，避免 quickadd 自动解析。
- 已修改远端：
  - `~/.openclaw/workspace/AGENTS.md`
  - `~/.openclaw/workspace/skills/gtd-inbox-triage/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-daily-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-weekly-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-natural-planning/SKILL.md`
- 已修改本仓 health Skill：
  - `.agents/skills/openclaw-gtd-health/SKILL.md`
  - `.agents/skills/openclaw-gtd-health/scripts/gtd_health_check.sh`
- 备份目录：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-single-actions-fix-20260505-100533`

## 验收
- `openclaw config validate` 通过。
- main Gateway 已重启，PID `2198643`。
- `gateway health ok=true`，Telegram `running=true / lastError=null`。
- `openclaw-gtd-health` 默认巡检：
  - `STATUS=clean`
- `openclaw-gtd-health -IncludeTodoistScaffold` 巡检：
  - `STATUS=clean`
  - scaffold 项目包含 `⚡ single-actions`、`🗂 someday-maybe`、`🌅 horizons`
- 主 Agent 不投递 smoke test：
  - 返回 `GTD_SINGLE_ACTIONS_OK`
  - provider/model：`xiaomi-mimo / mimo-v2.5-pro`

# 新发现（2026-05-05）：`openclaw-gtd-health` Skill 应按“外部总审计 + 确定性脚本 + 手工语义复核”三层设计

## 调研对象
- G 盘 Second Brain 参考 Skill：
  - `G:\我的云端硬盘\second-brain\.claude\skills\second-brain-vault-audit\SKILL.md`
  - `G:\我的云端硬盘\second-brain\.claude\skills\second-brain-lint\SKILL.md`
  - `G:\我的云端硬盘\second-brain\.claude\skills\second-brain-lint\scripts\deep_audit.ps1`
- 本仓现有健康检查 Skill：
  - `.agents/skills/openclaw-server-health/SKILL.md`
  - `.agents/skills/openclaw-server-health/scripts/run-openclaw-server-health.ps1`
  - `server_health_check.sh`
- 当前 live GTD harness 只读抽样：
  - `~/.openclaw/workspace/AGENTS.md`
  - `~/.openclaw/workspace/skills/gtd-inbox-triage/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-daily-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-weekly-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-natural-planning/SKILL.md`
  - `openclaw skills list --agent main --json`
  - `openclaw cron list --json`

## 参考 Skill 的可复用模式
- `second-brain-vault-audit` 是“外部维护者总审计协议”：先定义作用域、必读文件、必须运行的确定性命令、机械扫描、dry-run、手工语义复核、Fix Policy 和 Clean Standard。
- `second-brain-lint` 是更具体的 lint Skill：把检查项拆成固定顺序，要求确定性脚本作为证据，但明确脚本不能替代手工语义复核。
- `deep_audit.ps1` 的结构值得复用：
  - 先规范化路径和对象分类。
  - 再做机械扫描和规则检查。
  - 最后输出 JSON：`status`、`counts`、`issue_counts`、`informational_counts` 和各类 issue 明细。
- 本仓 `openclaw-server-health` 的结构也适合复用：
  - `SKILL.md` 只保留触发场景、只读边界、工作流、Required Checks、Safety 和 Resources。
  - 确定性检查放脚本。
  - Windows wrapper 从本地通过 SSH 投递只读脚本到远端执行。
  - 报告按层解释，不只看某个服务是否 active。

## 针对 GTD health 的设计结论
- 新 Skill 名建议：`openclaw-gtd-health`
- 新 Skill 路径建议：`.agents/skills/openclaw-gtd-health/`
- 建议资源：
  - `.agents/skills/openclaw-gtd-health/SKILL.md`
  - `.agents/skills/openclaw-gtd-health/scripts/run-openclaw-gtd-health.ps1`
  - `.agents/skills/openclaw-gtd-health/scripts/gtd_health_check.sh`
  - 可选 `.agents/skills/openclaw-gtd-health/agents/openai.yaml`
- 默认只读、只查 main：不读取 Todoist 真实任务内容，不运行 `td inbox`、`td today`、`td task list`。
- Todoist scaffold 可做可选检查，但必须单独开关，只允许读 project / label / filter scaffold，不读任务正文。
- Clean Standard 必须同时覆盖：
  - `openclaw config validate` 通过。
  - 四个 GTD workspace Skill 可见且 ready。
  - 五个 GTD cron 仍是 reminder-only。
  - `AGENTS.md` 覆盖 GTD 五步、Clarify 决策树、Engage 四因素、Hard Landscape、Reference、Horizons、Natural Planning。
  - 四个 GTD Skill 覆盖确认后 mutation、`id:<task_id>`/URL、标签合并、Hard Landscape、Waiting For who/what/follow-up。
  - 没有旧 scaffold 残留：旧项目名、旧 lowercase/中文标签、无效 `td` 用法、软日期误导示例。

## 当前 live 抽样结论
- 远端 main workspace 当前存在：
  - `AGENTS.md`：12086 bytes
  - `gtd-daily-review`：2786 bytes
  - `gtd-inbox-triage`：3952 bytes
  - `gtd-natural-planning`：3172 bytes
  - `gtd-weekly-review`：3886 bytes
- `openclaw skills list --agent main --json` 中四个 GTD Skill 均为：
  - `eligible=true`
  - `modelVisible=true`
  - `commandVisible=true`
  - `source=openclaw-workspace`
- 五个 GTD cron 当前摘要：
  - `gtd-inbox-reminder-0900`
  - `gtd-inbox-reminder-1300`
  - `gtd-inbox-reminder-1900`
  - `gtd-daily-review-reminder-2200`
  - `gtd-weekly-review-reminder-sun-1315`
  - 均为 `enabled=true`、`sessionTarget=isolated`、`thinking=off`、`lightContext=true`、`toolsAllow=read`、`timeoutSeconds=600`、`delivery.mode=announce`、`to=8226087994`、`accountId=main-bot`、`bestEffort=true`。

## GTD 官方对照基线
- GTD 官方核心流程以 Capture、Clarify、Organize、Reflect、Engage 五步为检查基线。
- Natural Planning Model 应覆盖 purpose/principles、outcome visioning、brainstorming、organizing、next action。
- Weekly Review 应按 Get Clear、Get Current、Get Creative 的框架做语义复核。

## 已落地（2026-05-05 10:00 +08:00）
- 已使用 skill-creator 在本仓创建：
  - `.agents/skills/openclaw-gtd-health/SKILL.md`
  - `.agents/skills/openclaw-gtd-health/agents/openai.yaml`
  - `.agents/skills/openclaw-gtd-health/scripts/gtd_health_check.sh`
  - `.agents/skills/openclaw-gtd-health/scripts/run-openclaw-gtd-health.ps1`
- `SKILL.md` 采用参考 Skill 的“外部总审计协议”结构：
  - Scope Guard
  - Workflow
  - Required Checks
  - Manual Semantic Review
  - Optional Todoist Scaffold Check
  - Clean Standard
  - Fix Policy
  - Resources
- `gtd_health_check.sh` 默认只查 main `~/.openclaw`，不读取真实 Todoist 任务内容。
- 默认检查项包括：
  - workspace GTD 文件存在性与 hash
  - `openclaw config validate`
  - `AGENTS.md` GTD 核心合同
  - 四个 GTD Skill 内容合同
  - 四个 GTD Skill runtime visibility
  - 五个 GTD cron reminder-only 配置
  - 旧 scaffold / 无效 `td` 命令残留
- 可选 `-IncludeTodoistScaffold` 只读检查 Todoist project / label / filter scaffold，不读取任务列表。
- 验收结果：
  - PowerShell wrapper parser OK
  - 远端 bash `bash -n` OK
  - `quick_validate.py` 通过
  - 默认巡检 `STATUS=clean`
  - 可选 scaffold 巡检首次遇到 Todoist API `HTTP 502: Bad Gateway`，重跑后 `STATUS=clean`

# Findings: 2026-03-08 飞书 + Ubuntu 网络通知

## 新发现（2026-05-04）：恢复 workspace `AGENTS.md` 时应优先补丁式合并而不是整文件覆盖

### 现场表现
- main 远端 `~/.openclaw/workspace/AGENTS.md` 曾被截断到 `Section 命名规范`，缺少上午新增的 `Skill 搜索`、`Skill 安装后审查`、`GTD 待办管理`、`Tools` 等内容。
- 截断文件本身仍包含一段较新的 `Todoist GTD Scaffold` 与命名规范。

### 处理结论
- 这种恢复不能简单用旧备份整文件覆盖，否则会把截断文件里仍然有效的较新内容回滚掉。
- 正确流程：
  1. 先备份当前 `AGENTS.md`
  2. 以当前/截断文件为底稿
  3. 从干净备份中抽取缺失段落补进去
  4. 验证 `AGENTS.md` 不包含联网搜索 fallback；该 fallback 只应保留在 `TOOLS.md`
- 本轮最终远端文件：
  - 底稿：`/home/kevinlasnh/.openclaw/workspace/AGENTS.md.pre-restore-20260504-212104`
  - 覆盖备份：`/home/kevinlasnh/.openclaw/workspace/AGENTS.md.pre-merge-correction-20260504-212242`
  - 最终大小：`7720 bytes`

## 新发现（2026-05-04）：纯固定文本提醒不应使用 cron 的 `agentTurn + announce`

### 现场表现
- 17:30 的 `drink-water-half` isolated cron session：
  - `83376b21-2a48-4bca-8e1b-dbe81443edef`
  - job id：`faf6dca9-13fd-430c-ab83-4e4646948158`
- session JSONL 显示，Telegram 收到的“用户请求输出一行特定的文本……”不是 Telegram verbose 层泄露，也不是 hidden reasoning 被错误展示。
- 它已经是 assistant 最终普通 text 内容的一部分：
  - provider/model：`xiaomi-mimo/mimo-v2.5-pro`
  - prompt 中写了 `Output exactly this line, nothing else`
  - assistant 仍把任务分析和提醒文本拼在普通文本里返回。

### 官方/源码核对
- OpenClaw 2026.5.3 CLI 当前 `cron add` 只暴露两类 payload：
  - `--message <text>`：agent message payload，对应 `payload.kind = agentTurn`
  - `--system-event <text>`：main session system event，对应 `payload.kind = systemEvent`
- `src/cron/types.ts` 当前类型也只允许：
  - `{ kind: "systemEvent"; text: string }`
  - `{ kind: "agentTurn"; message: string; ... }`
- `src/cron/delivery-plan.ts` 表明 isolated/current/session agentTurn 默认/显式 announce 只是配送最终输出，不改变“输出来自模型”的事实。
- `src/cron/delivery.ts` 中 `sendCronAnnouncePayloadStrict` 可以直接发送文本 payload，但当前它是内部函数，不是 `openclaw cron add` 暴露的一种 literal payload 类型。

### 配置结论
- 纯固定文本提醒（喝水、GTD 提醒）不应再走：
  - `payload.kind = agentTurn`
  - `sessionTarget = isolated`
  - `delivery.mode = announce`
- 原因：只要需要模型生成最终文本，就无法工程上保证“只输出固定一句话”；`thinking=off` 也只能影响模型/适配器的 thinking 形态，不能过滤模型自己写入普通 assistant text 的内容。
- 当前 OpenClaw 2026.5.3 没有一等公民的 `literalText` / `directMessage` cron payload。
- 最稳妥落地方式：
  1. 用 OS/systemd timer 或 OpenClaw `exec` cron 执行一个本地脚本。
  2. 脚本直接调用 Telegram Bot API `sendMessage`，发送固定文本。
  3. 不经过模型、不经过 agent final text，因此不会产生推理/解释前缀。
- 次优方案是继续 `agentTurn`，但改 prompt、`thinking=off`、`lightContext=true` 都只能降低概率，不能根治。

### 当前远端 cron 现状
- 7 个纯提醒类 job 现在全部是 `agentTurn + isolated + announce`：
  - `drink-water-half`
  - `drink-water-hourly`
  - `gtd-inbox-reminder-0900`
  - `gtd-inbox-reminder-1300`
  - `gtd-inbox-reminder-1900`
  - `gtd-daily-review-reminder-2200`
  - `gtd-weekly-review-reminder-sun-1315`
- `openclaw-update-check` 是真正需要执行检查和摘要的任务，可以暂时保留 agent/exec 形态，后续单独优化。

### 执行错误
- 读取坏 session JSONL 时，一次 PowerShell + SSH here-doc 引号没有完整闭合，远端已输出所需 JSONL 片段，但命令末尾报：
  - `NameError: name 'PY' is not defined`
- 后续如需再跑，应改用单行 Python `-c` 或远端临时脚本，避免嵌套 here-doc。

## 新发现（2026-05-04）：坚持使用 `agentTurn + isolated + announce` 时，提醒 cron 需要收紧外壳而不是改提醒文本

### 现场复盘
- 当前共有 8 个 main cron：
  - 7 个纯提醒：2 条喝水 + 5 条 GTD 提醒
  - 1 个 `openclaw-update-check`
- 用户明确要求：
  - 保留 `agentTurn + isolated + announce`
  - 不改真正要发送的提醒文本
  - 不改花园多惠语风
- 2026-05-04 的喝水提醒不是只有 17:30 一次不干净。至少存在：
  - 10:00：输出了“用户发来了一个定时任务提醒...”并重复提醒文本
  - 11:30：输出了“只输出一行文字，不要输出任何其他内容。”
  - 15:00：把 cron 自动追加的 `Current time` / message tool delivery guidance 也带进了 assistant text，并道歉
  - 17:30：输出了“用户请求输出一行特定的文本...”分析前缀
- 正常样本也存在，说明这是模型在当前 prompt 包装下的概率性失误，不是 Telegram 投递层泄露。

### 当前配置里的具体风险点
- 纯提醒 job 的 `thinking` 未显式写入；虽然轨迹显示本次运行 `thinkLevel=off`，但升级或模型变化后不应依赖默认值。
- `toolsAllow: []` 在当前 OpenClaw 2026.5.3 runner 中不是有效的“无工具最小 prompt”：
  - `applyEmbeddedAttemptToolsAllow` 对空数组按“不过滤工具”处理
  - `canPromptForMessageTool` 对空数组也会追加 message tool 指引
- 因此坏样本 prompt 都包含：
  - `Use the message tool if you need to notify the user directly...`
  - `If you do not send directly, your final plain-text reply will be delivered automatically.`
- 这段配送提示会诱发模型解释“我应该直接回复/不用 message 工具”，然后把解释写进普通 text。
- 喝水任务仍带旧 `sessionKey=agent:main:telegram:main-bot:direct:8226087994`；纯 isolated cron 有显式 `delivery.to/accountId` 时不需要把 job 绑到主 Telegram direct session。

### 在保留 agent turn 的前提下，推荐配置
- 只改 wrapper 和运行参数，不改最后提醒文本：
  1. 所有 7 个纯提醒统一 `lightContext=true`
  2. 所有 7 个纯提醒显式 `thinking=off`
  3. 所有 7 个纯提醒把 `toolsAllow` 改成一个非空且不含 `message` 的 allow-list，例如 `["read"]`
     - 目的不是让模型读文件，而是触发 OpenClaw minimal prompt，并避免追加 `Use the message tool...`
     - 源码测试确认 `toolsAllow` 排除 `message` 时，cron 会改用更简单的 `Return your response as plain text...` 指引
  4. 所有 7 个纯提醒清掉不必要的 `sessionKey`
  5. wrapper 使用中文、标签式、低解释诱导的模板：

     ```
     你正在执行 OpenClaw isolated cron 提醒。你的最终回复必须只包含 <reminder> 内的文本。
     不要输出标签，不要解释，不要复述规则，不要输出“用户请求”“根据指令”“我需要”等句子。
     <reminder>
     <这里放原提醒文本，逐字不改>
     </reminder>
     ```

- `openclaw-update-check` 不是纯固定提醒，仍需要 `exec` 和摘要判断；暂不按上述纯提醒规则处理。

### 本轮已落地
- 备份：
  - `/home/kevinlasnh/.openclaw-backups/main-cron-agentturn-reminders-20260504-180422`
- 已修改 7 个纯提醒 job：
  - `drink-water-half`
  - `drink-water-hourly`
  - `gtd-inbox-reminder-0900`
  - `gtd-inbox-reminder-1300`
  - `gtd-inbox-reminder-1900`
  - `gtd-daily-review-reminder-2200`
  - `gtd-weekly-review-reminder-sun-1315`
- 每个 job 当前均为：
  - `sessionKey = ""`
  - `payload.thinking = "off"`
  - `payload.lightContext = true`
  - `payload.toolsAllow = ["read"]`
  - `payload.message` 包含 `<reminder>...</reminder>`
  - `delivery = announce -> telegram:8226087994`
  - `accountId = main-bot`
- `<reminder>` 内的提醒文本已按当前 job 原文抽取并保留，未改花园多惠提醒语风。
- `openclaw-update-check` 未按纯提醒规则修改，仍保留：
  - 花园多惠提示
  - `toolsAllow = ["exec"]`
  - `lightContext = true`

## 新发现（2026-05-04）：`openclaw-update-check` 应作为开放式检查任务，不套纯提醒严格输出规则

### 用户确认
- 用户明确说明：
  - `openclaw-update-check` 可以 thinking
  - 不一定要严格只输出提醒句
  - 这是开放式检查任务，不是纯固定提醒

### 本轮修正
- 曾短暂把 `openclaw-update-check` 收紧为严格一行输出，并显式 `thinking=off`。
- 用户纠正后已撤回该方向，恢复为开放式花园多惠检查 prompt。
- 当前配置：
  - `payload.kind = agentTurn`
  - `sessionTarget = isolated`
  - `delivery.mode = announce`
  - `toolsAllow = ["exec"]`
  - `lightContext = true`
  - `thinking = "medium"`
  - `sessionKey = agent:main:telegram:main-bot:direct:8226087994`
- 备份：
  - 收紧前备份：`/home/kevinlasnh/.openclaw-backups/main-update-check-cron-tighten-20260504-181201`
  - 撤回前备份：`/home/kevinlasnh/.openclaw-backups/main-update-check-open-ended-restore-20260504-181325`

### 运行验证
- 手动触发 `openclaw-update-check` 成功：
  - `lastRunStatus = ok`
  - `lastDelivered = true`
  - `lastDeliveryStatus = delivered`
  - `consecutiveErrors = 0`
- 当前本机版本：
  - `OpenClaw 2026.5.3 (06d46f7)`
- GitHub latest release：
  - `v2026.5.3`
  - release 名称：`OpenClaw 2026.5.3`
  - published at：`2026-05-04T07:01:29Z`
- 实际最终输出：
  - `小龙虾已经是最新版本啦～🎸 当前：2026.5.3`
- 未看到推理文本泄露。

### 注意
- 被用户打断前触发的最后一次手动运行，实际使用的是短暂收紧版 prompt，但最终输出符合“已是最新版本”结论且无推理泄露。
- 现场配置已恢复为开放式检查 prompt；为避免 Telegram 继续收到测试消息，本轮没有再额外触发一次开放式版本。

### 追加修正
- 用户进一步确认：
  - `openclaw-update-check` 应允许全部工具，而不是只允许 `exec`
  - `thinking` 应设为 `high`
- 已按此修正：
  - `payload.toolsAllow` 字段已清除，表示全工具允许
  - `payload.thinking = "high"`
  - `payload.lightContext = true` 保留
  - `sessionKey = agent:main:telegram:main-bot:direct:8226087994` 保留
- 备份：
  - `/home/kevinlasnh/.openclaw-backups/main-update-check-tools-all-thinking-high-20260504-181610`
- 验收：
  - `openclaw config validate` 通过
  - `openclaw cron show` 确认 `toolsAllow_present=false`、`thinking=high`

### 追加统一超时
- 用户确认刚刚 `ok/delivered` 的 update-check 配置可用，并要求所有定时任务 timeout 统一为 10 分钟。
- 已将 main 的 8 个 cron 的 `payload.timeoutSeconds` 全部设置为 `600`：
  - `openclaw-update-check`
  - `drink-water-half`
  - `drink-water-hourly`
  - `gtd-inbox-reminder-0900`
  - `gtd-inbox-reminder-1300`
  - `gtd-inbox-reminder-1900`
  - `gtd-daily-review-reminder-2200`
  - `gtd-weekly-review-reminder-sun-1315`
- 备份：
  - `/home/kevinlasnh/.openclaw-backups/main-cron-timeout-600-20260504-182350`
- 验收：
  - `openclaw config validate` 通过
  - `openclaw cron list --json` 确认 8 个 job 均为 `timeoutSeconds=600`
  - `openclaw cron status --json` 显示 `jobs=8`，无 running/due/disabled/errors

## 新发现（2026-05-04）：Telegram answer preview finalize 需要防止被后续 visible tool payload 超越

### 现场表现
- Telegram PR `openclaw/openclaw#77211` rebase 到最新 `upstream/main` 后，本地/CI 暴露 `extensions/telegram/src/bot-message-dispatch.test.ts` timing 失败。
- 失败场景是：
  - answer preview 已被归档；
  - compaction 与下一条 assistant message 之间插入了 visible tool payload；
  - 后续 final 仍可能错误消费旧 archived preview。

### 修复结论
- 需要用单调递增的 visible message 顺序记录：
  - answer preview 最近更新时间；
  - 非 preview 可见消息投递顺序。
- final 只能消费没有被后续 visible payload 超越的 preview。
- 当前上游 PR head：
  - `86dd83d2c24e562eaf73d29f07d06c408d05a0dd`
- GitHub 最终状态：
  - `mergeStateStatus=CLEAN`
  - `Pending=0`
  - `Failed=0`

## 新发现（2026-05-04）：Brave Search 上游修复应拆成 runtime fallback 与 doctor repair 两层

### 上游状态
- 核心 runtime fallback 已由上游现有 PR 处理：
  - `openclaw/openclaw#77074`
  - 作用：活动 runtime registry 没有 provider-only 外部 web provider 时，继续回退到已安装插件 discovery。
- 本轮新 PR 不重复提交该 runtime fallback。

### 本轮新增 PR
- PR：
  - `https://github.com/openclaw/openclaw/pull/77219`
- 分支：
  - `fix/brave-configured-plugin-runtime-repair`
- commit：
  - 原始提交：`74c3c75d78 fix(plugins): repair configured plugins with broken runtime entries`
  - rebase 后当前 head：`cf0be8a303967d3f0ff5fa612ba0f28af1b7e9c5`

### 修复点
- `doctor` 的 `missing-configured-plugin-install` 现在会识别已配置插件的 metadata diagnostics：
  - `requires compiled runtime output`
  - `runtime extension entry not found`
  - `runtime setup entry not found`
- 如果插件已配置且 persisted install record 存在，但 runtime entry broken，会触发现有 `updateNpmInstalledPlugins` repair 路径。
- `isInstalledRecordMissingOnDisk` 同时支持 `installPath` 与 `sourcePath`，避免只看一个路径导致误判。

### 对现场 Brave 故障的意义
- 旧 `@openclaw/brave-plugin@2026.5.2` 可能存在 `package.json`，但只有 source runtime entry，5.3 需要 compiled runtime output。
- 这种状态不能按“安装正常”跳过；doctor 应主动更新到带 `dist/index.js` 的新插件包。
- 本轮 PR 覆盖的就是这个自动修复缺口。

### Rebase 结论
- 上游 `main` 额外新增了 current bundled plugin index 处理：
  - `loadInstalledPluginIndex(...)`
  - `BundledPluginPackageDescriptor`
  - snapshot bundled plugin 与当前 bundled plugin id/packageName 都要参与 stale install record 判断。
- Brave PR 的 broken runtime entry repair 必须与上述逻辑共存：
  - 先构建 `bundledPluginsById`
  - 再加载 persisted install records
  - 再分别计算 stale channel config descriptor 与 broken runtime entry 两类 configured plugin repair 集合。
- 当前 GitHub 最终状态：
  - `mergeStateStatus=CLEAN`
  - `Pending=0`
  - `Failed=0`

## 新发现（2026-05-04）：OpenClaw 2026.5.2/5.3 下 Brave 内置 Web Search 需要同时修核心、插件包和 runtime discovery

### 现场表现
- main 内置 `web_search` 报：
  - `web_search is disabled or no provider is available`
- 早期查询错误路径会出现：
  - `config schema path not found`
  - 错误路径包括 `agents.defaults.webSearch` / `webSearch`
- 正确配置路径是：
  - `tools.web.search.*`
  - `plugins.entries.brave.config.webSearch.*`

### 5.2 问题
- `OpenClaw 2026.5.2` 下，Brave 作为外部插件安装后，CLI 控制面能看到：
  - `webSearchProviderIds = ["brave"]`
- 但 agent / cron runtime 中仍可能取不到 provider，实际工具调用报：
  - `web_search is disabled or no provider is available`
- Tavily Skill 可以作为 fallback，但这不等于内置 Brave 已修好。

### 5.3 修复与本机额外热修
- 已将全局 OpenClaw 补完整到：
  - `OpenClaw 2026.5.3 (06d46f7)`
- 必须同步更新 Brave 插件：
  - `@openclaw/brave-plugin 2026.5.3`
  - 旧 `2026.5.2` 包只有 TypeScript entry `index.ts`
  - 5.3 Gateway 需要编译后的 runtime output，当前入口为 `dist/index.js`
- 本机还需要一个安装树热修：
  - 文件：`web-provider-runtime-shared-Be3P_2t9.js`
  - 原因：活动 runtime registry 存在但不含 Brave 这类 provider-only 外部插件时，`resolveRuntimeWebProviders` 会直接返回空 provider list
  - 修复：runtime provider list 为空时，继续 fallback 到已安装插件 discovery
- 升级还会覆盖 Telegram verbose 工具进度 hot patch，已在 2026.5.3 的：
  - `bot-Blf2Bm9e.js`
  重打：
  - `suppressDefaultToolProgressMessages: previewToolProgressEnabled ? true : void 0`

### 当前最终配置
- `tools.web.search.enabled = true`
- `tools.web.search.provider = "brave"`
- `plugins.entries.brave.enabled = true`
- `plugins.entries.brave.config.webSearch.apiKey = env:BRAVE_API_KEY`
- `plugins.entries.brave.config.webSearch.mode = "web"`
- `plugins.allow` 包含 `brave`

### 验收基线
- main Brave-only smoke test：
  - 禁止 `exec`
  - 禁止 Tavily
  - 只允许内置 `web_search`
  - 返回 `MAIN_BRAVE_ONLY_OK`
  - `toolSummary.tools = ["web_search"]`
  - `toolSummary.failures = 0`
- 四个 Gateway 已在 2026.5.3 下重启：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 四个 Gateway 均为 `active/running`、`NRestarts=0`。

### 后续注意
- 之后每次 `openclaw update` / `pnpm add -g openclaw@latest` 后都要复查：
  1. `@openclaw/brave-plugin` 是否与 OpenClaw 核心版本同步
  2. Brave 插件入口是否仍为编译后的 `dist/index.js`
  3. `web-provider-runtime-shared-*.js` 的 runtime-empty fallback 热修是否被覆盖
  4. Telegram verbose 工具进度 hot patch 是否被覆盖

## 新发现（2026-05-03）：cron 的 `lastStatus=skipped` / `lastError=disabled` 可能是历史状态，不等于当前 job 被禁用

### 现场表现
- `main` 当前只剩两条喝水 cron：
  - `drink-water-half`
  - `drink-water-hourly`
- 两条 job 当前字段均为：
  - `enabled = true`
  - `runningAtMs = null`
  - `consecutiveErrors = 0`
  - 已有后续 `nextRunAtMs`
- 但 state 中仍保留：
  - `lastStatus = skipped`
  - `lastError = disabled`

### 判断
- `lastStatus` / `lastError` 是上一轮触发留下的历史结果，不应单独用来判断当前 job 已禁用。
- 当前是否可运行应优先看：
  - `enabled`
  - `nextRunAtMs`
  - `runningAtMs`
  - `consecutiveErrors`
  - 下一次触发后的新 `lastStatus`

### 本轮结论
- 这两条喝水 cron 当前未被禁用。
- `main` 的 cron store 当前仍是干净状态：
  - jobs 总数为 2
  - 无旧 `morning-briefing` / `market-reflection` / `sector-reflection` / `closing-report` / `sector-daily-push` 残留

## 新发现（2026-05-03）：OpenClaw 2026.5.2 中 Brave Web Search 需要按 state 安装 `@openclaw/brave-plugin`

### 现场表现
- 升级到：
  - `OpenClaw 2026.5.2 (8b2a6e5)`
- `main` / `chunyan` / `zenglan` 在启动和 `config validate` 时失败：
  - `tools.web.search.provider: web_search provider is not available: brave`
- 仅复制：
  - `~/<state>/npm/node_modules/@openclaw/brave-plugin`
  或仅写入：
  - `plugins.entries.brave.enabled = true`
  不足以让配置通过。

### 根因
- 2026.5.2 下 `brave` 作为外部插件参与 registry。
- OpenClaw 需要在每个 state dir 的：
  - `plugins/installs.json`
  中有安装登记。
- 配置已写 `tools.web.search.provider = brave` 时，CLI 的部分插件命令会先被 config validate 拦住。

### 可复用修复流程
1. 备份对应 `openclaw.json`。
2. 临时移除该 state 的：
   - `tools.web.search.provider`
3. 在同一 state 环境下执行：
   - `openclaw config validate`
   - `openclaw plugins install @openclaw/brave-plugin --force`
   - `openclaw plugins enable brave`
   - `openclaw plugins registry --refresh --json`
4. 恢复：
   - `tools.web.search.provider = brave`
   - `plugins.entries.brave.enabled = true`
5. 再跑：
   - `openclaw config validate`

### 本轮修复范围
- 已修复：
  - `~/.openclaw`
  - `~/.openclaw-chunyan`
  - `~/.openclaw-zenglan`
- `~/.openclaw-dayong` 原本没有 `tools.web.search.provider = brave`，配置校验本来就通过。

## 新发现（2026-05-03）：OpenClaw 2026.5.2 仍需 Telegram verbose 工具进度热修

### 现场表现
- 2026.5.2 安装树中 Telegram bundle 当前逻辑为：
  - `suppressDefaultToolProgressMessages: !previewStreamingEnabled || Boolean(answerLane.stream)`
- 当 Telegram `streaming.mode = "off"` 时：
  - `previewStreamingEnabled = false`
  - `previewToolProgressEnabled = false`
  - 但默认工具进度仍会被 suppress
- 这会复发 2026.4.24 的同类问题：verbose 开启时 Telegram 看不到旧式独立工具进度消息。

### 本轮热修
- 文件：
  - `/home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/openclaw@2026.5.2_@types+express@5.0.6/node_modules/openclaw/dist/bot-CW5ZEQ0V.js`
- 备份：
  - `bot-CW5ZEQ0V.js.pre-tool-progress-fix-20260503-151315`
- 修改为：
  - `suppressDefaultToolProgressMessages: previewToolProgressEnabled ? true : void 0`
- 含义：
  - 只有 streaming preview 工具进度实际可用时才抑制默认工具进度
  - Telegram streaming 关闭时恢复默认离散工具进度消息

### 验收
- `main` config validate 通过。
- `openclaw-gateway` 已重启。
- Gateway health 返回：
  - `ok = true`
  - Telegram webhook probe ok
  - webhook 仍为 `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`

## 新发现（2026-04-27）：ByteRover curate 带多个大文件引用时会超时，沉淀应进一步缩小粒度

- 本轮尝试沉淀 `openclaw-server-health` 巡检 Skill。
- 首条 `brv curate` 附带了 5 个文件引用：
  - `.agents/skills/openclaw-server-health/SKILL.md`
  - `.agents/skills/openclaw-server-health/scripts/run-openclaw-server-health.ps1`
  - `SERVER_HEALTH_CHECKS.md`
  - `server_health_check.sh`
  - `AGENTS.md`
- 结果：
  - `cur-1777298706998`
  - `Task timed out after 600s`
  - `brv review pending` 返回 `No pending reviews`
- 按仓库规则，本轮已停止后续沉淀，未清空或重建 PWF 文件。
- 后续治理：
  - 不要把 runbook / 大脚本作为首条 curate 的文件上下文一起塞进去
  - 优先使用短的五字段摘要
  - 单次只围绕一个主题
  - 文件引用保持 0-1 个，必要时只引用小文件

## 新发现（2026-04-27）：仓库根目录 `CLAUDE.md` 已按用户要求删除，项目级规则入口收敛到 `AGENTS.md`

- 已删除项目级文件：
  - `CLAUDE.md`
- 未删除或修改全局文件：
  - `~/.claude/CLAUDE.md`
- `AGENTS.md` 的前置检查规则已更新：
  - 不再要求读取仓库根 `CLAUDE.md`
  - 改为读取 `AGENTS.md`
- 历史 `progress.md` / `task_plan.md` 中过去任务对 `CLAUDE.md` 的引用保留为历史记录，不批量改写。

## 新发现（2026-04-27）：服务器标准巡检已封装为项目级 `openclaw-server-health` Skill

### Skill 位置
- Skill 目录：
  - `.agents/skills/openclaw-server-health/`
- 主文件：
  - `.agents/skills/openclaw-server-health/SKILL.md`
- 执行 wrapper：
  - `.agents/skills/openclaw-server-health/scripts/run-openclaw-server-health.ps1`

### 触发场景
- 检查远程 Ubuntu 服务器
- 检查小龙虾 / OpenClaw 健康
- 检查 Telegram / Feishu 通道
- 检查 Tailscale / Funnel / SSH
- 检查 Mihomo / Clash 代理
- 检查 5 秒代理健康轮询
- 检查 cron / session lock / stuck session
- 检查 provider 429、插件错误、资源压力

### 设计决策
- Skill 不复制完整 runbook，避免双源漂移。
- 详细标准继续以仓库根目录为准：
  - `SERVER_HEALTH_CHECKS.md`
  - `server_health_check.sh`
- Skill 负责封装：
  - 何时触发
  - 先读哪些上下文
  - 如何运行只读检查
  - 如何按 P0/P1/P2 分层判读
  - 修复前不得直接重启 / 删除 / 禁用 / 改配置的安全边界

### Wrapper 实现细节
- PowerShell wrapper 会向上查找仓库根目录的：
  - `server_health_check.sh`
- 它按字节读取脚本，若存在 UTF-8 BOM 会先剥离。
- 然后用 base64 把脚本传到远端执行：
  - 避免 Windows PowerShell 管道编码让远端 bash 误读 shebang
  - 避免 CRLF 干扰远端 bash
- 默认远端：
  - `kevinlasnh@100.64.65.65`

### 验收
- `skill-creator` 的 `quick_validate.py` 已返回：
  - `Skill is valid!`
- wrapper smoke test 已成功输出远端巡检段：
  - `summary`
  - `host_identity`
  - `uptime`
  - `memory`
  - `swap`
  - `filesystems`

## 新发现（2026-04-27）：dayong 8 个 Agent 已正式切到 `zai/glm-5.1`，并通过 `NO_PROXY` 让 ZAI endpoint 直连

### dayong 当前最终配置
- 配置文件：
  - `~/.openclaw-dayong/openclaw.json`
- 备份目录：
  - `/home/kevinlasnh/.openclaw-backups/dayong-glm51-direct-20260427-164752`
- 8 个 agent：
  - `market`
  - `sector`
  - `stock`
  - `strategy`
  - `breakboard`
  - `douzhuan`
  - `volume15`
  - `volume35`
- 8 个 `agents.list[].model` 当前全部显式为：
  - `zai/glm-5.1`
- defaults 当前为：
  - `agents.defaults.model.primary = zai/glm-5.1`
  - `agents.defaults.model.fallbacks = []`
  - `agents.defaults.models = {"zai/glm-5.1": {}}`
- provider endpoint：
  - `https://open.bigmodel.cn/api/coding/paas/v4`
- provider 只注册：
  - `glm-5.1`
- 当前注册参数：
  - `contextWindow = 204800`
  - `maxTokens = 131072`
  - `reasoning = true`
  - `input = ["text"]`

### 直连策略
- `openclaw-gateway-dayong.service` 仍保留：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- 新增 drop-in：
  - `~/.config/systemd/user/openclaw-gateway-dayong.service.d/10-zai-no-proxy.conf`
- drop-in 内容：
  - `NO_PROXY=open.bigmodel.cn,.bigmodel.cn,localhost,127.0.0.1,::1`
  - `no_proxy=open.bigmodel.cn,.bigmodel.cn,localhost,127.0.0.1,::1`
- 工程含义：
  - ZAI / BigModel API 域名直连
  - 其他需要代理的外部服务仍可继续使用 `127.0.0.1:7897`

### 上线验收
- 已执行：
  - `systemctl --user daemon-reload`
  - `systemctl --user restart openclaw-gateway-dayong`
- 当前版本：
  - `OpenClaw 2026.4.24 (cbcfdf6)`
- `openclaw config validate` 通过。
- `openclaw models status --json` 显示：
  - `defaultModel = zai/glm-5.1`
  - `resolvedDefault = zai/glm-5.1`
  - `fallbacks = []`
  - `allowed = [zai/glm-5.1]`
- systemd 当前状态：
  - `openclaw-gateway-dayong = active/running`
  - `NRestarts = 0`
- 监听端口：
  - `127.0.0.1:19021`
  - `127.0.0.1:19023`
- 进程环境：
  - 父进程 `openclaw` 与子进程 `openclaw-gateway` 均继承 `NO_PROXY/no_proxy`
  - 同时仍保留 `HTTP_PROXY/HTTPS_PROXY`

### 当前限制
- 真实实呼已经打到：
  - `provider = zai`
  - `model = glm-5.1`
- 当前失败点是智谱服务侧返回：
  - `429 该模型当前访问量过大，请您稍后再试`
- 因为按用户要求没有 fallback，OpenClaw 会记录：
  - `model fallback decision: next=none`
  - `FailoverError: API rate limit reached`
- 结论：
  - dayong 模型配置、直连策略和 Gateway 上线已完成
  - 当前不可用风险来自 ZAI / GLM 5.1 服务侧限流，不是代理未绕过或模型没有切成功

## 新发现（2026-04-27）：main 已通过 `NO_PROXY` 让 DeepSeek 直连，dayong 的 8 个 `glm-5` agent 直连后实际返回 `glm-5.1`

### main DeepSeek 直连配置
- 新增 systemd user drop-in：
  - `~/.config/systemd/user/openclaw-gateway.service.d/10-deepseek-no-proxy.conf`
- 内容：
  - `NO_PROXY=api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
  - `no_proxy=api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
- 保留：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- 目的：
  - DeepSeek API 直连
  - Telegram / Brave / 其他外部流量仍可继续走 Mihomo 代理

### main 验收
- 已执行：
  - `systemctl --user daemon-reload`
  - `systemctl --user restart openclaw-gateway`
- 重启后：
  - `openclaw-gateway = active/running`
  - `NRestarts = 0`
  - 父进程 `openclaw` 和子进程 `openclaw-gateway` 都继承了 `NO_PROXY/no_proxy`
- `openclaw config validate` 通过。
- `openclaw models status --json` 仍显示：
  - `defaultModel = deepseek/deepseek-v4-pro`
  - `fallbacks = []`
  - `allowed = [deepseek/deepseek-v4-pro]`
- 最小实呼返回：
  - `MAIN_DEEPSEEK_DIRECT_OK`
  - provider/model 为 `deepseek/deepseek-v4-pro`
- Telegram probe：
  - `ok = true`
  - webhook 仍为 `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- Mihomo 代理探测：
  - `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204`
  - 返回 `204`

### dayong 直连测试
- `dayong` 当前 8 个 agent 都配置为：
  - `zai/glm-5`
- 8 个 agent：
  - `market`
  - `sector`
  - `stock`
  - `strategy`
  - `breakboard`
  - `douzhuan`
  - `volume15`
  - `volume35`
- provider endpoint：
  - `https://open.bigmodel.cn/api/coding/paas/v4`
- 本轮使用 `curl --noproxy '*'` 禁用代理，直接请求：
  - `/chat/completions`
- 结果：
  - 8 个 agent 按当前 `glm-5` 请求均 HTTP 200
  - 返回的实际模型名均为 `glm-5.1`
  - 显式请求 `glm-5.1` 也 HTTP 200
- 结论：
  - dayong 的 ZAI Coding endpoint 可直连
  - 当前 `zai/glm-5` 在 API 侧实际落到 `glm-5.1`
  - 本轮只测试直连能力，未修改 `openclaw-gateway-dayong.service` 的代理策略

## 新发现（2026-04-27）：main DeepSeek 当前处于代理环境中，但远端直连 DeepSeek 可用且更稳定

### 现场检查
- `openclaw-gateway.service` 的 systemd 环境包含：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- `main` 的当前进程环境也实际继承了：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- `openclaw models status --json` 确认 main 当前仍为：
  - `defaultModel = deepseek/deepseek-v4-pro`
  - `fallbacks = []`
  - `allowed = [deepseek/deepseek-v4-pro]`

### OpenClaw 网络层依据
- 远端 `OpenClaw 2026.4.24` 安装树中存在：
  - `EnvHttpProxyAgent`
  - `ProxyAgent`
  - `NO_PROXY`
  - `proxy-env`
- 相关类型声明也明确写到：
  - env proxy 会读取 `HTTPS_PROXY` / `HTTP_PROXY`
  - `NO_PROXY` / `no_proxy` 可用于绕过代理

### DeepSeek 连通性测速
- 目标：
  - `https://api.deepseek.com/models`
- 远端直连，禁用代理环境并使用 `curl --noproxy '*'`：
  - 3 次均 HTTP 200
  - 总耗时约 `0.136-0.169s`
- 通过 Mihomo `127.0.0.1:7897`：
  - 3 次均 HTTP 200
  - 总耗时约 `0.120-0.330s`

### 结论
- 当前 `main` 已按上述方案通过 `NO_PROXY/no_proxy` 让 DeepSeek 域名直连。
- 仍保留 `HTTP_PROXY` / `HTTPS_PROXY=http://127.0.0.1:7897` 给 Telegram / Brave / 其他外部访问。

### 已更新文档
- `AGENTS.md` 已补充：
  - 标准巡检惯例
  - 当前真实配置摘要
  - DeepSeek 与代理策略

## 新发现（2026-04-27）：远程 Ubuntu 日常巡检不能只看 `active/running`，需要按接入层、代理层、OpenClaw 层、cron 层和资源层分层判断

### 本轮产物
- 新增标准巡检文档：
  - `SERVER_HEALTH_CHECKS.md`
- 新增只读巡检脚本：
  - `server_health_check.sh`
- 脚本已通过 PowerShell + SSH 方式验证：
  - `Get-Content -Raw -Encoding UTF8 server_health_check.sh | ssh kevinlasnh@100.64.65.65 "tr -d '\r' | bash -s >/dev/null"`
  - 返回：`REMOTE_HEALTH_SCRIPT_OK`

### 巡检分层
- P0 接入 / 救援层：
  - `ssh.service`
  - `openclaw-sshd-2222.service`
  - `tailscaled.service`
  - `100.64.65.65:2222`
- P1 公网入口层：
  - Tailscale Funnel `443 -> 127.0.0.1:8787`
  - Tailscale Funnel `8443 -> 127.0.0.1:8788`
- P1 代理层：
  - `mihomo-standalone.service`
  - `127.0.0.1:7897`
  - `telegram-jp-tw-stable interval: 5`
  - `自动选择 interval: 30`
- P1 OpenClaw 层：
  - 四个 user service
  - 四套 `openclaw config validate`
  - 四套 `openclaw gateway health --json`
  - 本地监听端口
  - Telegram / Feishu probe
- P1 cron / 会话层：
  - `openclaw cron status --json`
  - `openclaw cron list --json`
  - `*.jsonl.lock`
  - `stuck session`
- P2 资源 / 数据层：
  - 内存、swap、磁盘、GPU
  - `dayong-stock-mcp` 的 `127.0.0.1:3310`
  - Chrome / browser 进程

### 当前健康基线
- 远程主机：
  - Ubuntu 24.04.4 LTS
  - kernel `6.17.0-19-generic`
  - uptime 约 42 天
  - `/` 使用率约 12%
- Tailscale：
  - version `1.96.4`
  - self node `openclaw-24x7`
  - IP `100.64.65.65`
  - Funnel 443 / 8443 均存在
- Mihomo：
  - `mihomo-standalone.service = active`
  - `mixed-port = 7897`
  - `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` 返回 `204`
  - `127.0.0.1:7890` 当前不可用，不能作为生产代理端口
- OpenClaw：
  - `OpenClaw 2026.4.24`
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
  四个服务均为 active/enabled
  - 四套配置均通过 `openclaw config validate`
  - 四套 `gateway health --json` 抽样返回 `ok: true`
  - main Telegram webhook 为：
    - `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`

### 关键判断规则
- `systemctl --user is-active openclaw-gateway` 只证明进程还在，不证明小龙虾可用。
- 真正的健康判断至少还要看：
  1. 本地监听端口是否存在
  2. webhook / Funnel 是否对齐
  3. Telegram 或 Feishu probe 是否 ok
  4. 最近是否持续出现 `stuck session`
  5. session 目录是否有持久 `.lock`
  6. cron 是否有正在运行、重复、连续错误、旧模型或缺 delivery target
  7. 是否出现 provider rate limit / local Vulkan OOM / 插件加载错误

### 当前红旗
- `main` 近期卡死期间出现连续 `stuck session`，根因与重复 `closing-report` / `sector-daily-push` cron 有关。
- 近期出现过本地 Vulkan / memorySearch 类显存失败：
  - `ggml_vulkan: Device memory allocation ... failed`
  - `failed to allocate buffer for kv cache`
- `main` cron 仍有重复任务、旧模型字段和 `Delivering to Telegram requires target <chatId>` 这类 delivery 错误。
- `chunyan` / `zenglan` 有历史 `NRestarts`，日常巡检要看是否继续增长。

### 后续使用规则
- 日常巡检优先读：
  - `SERVER_HEALTH_CHECKS.md`
- 需要一键采集时运行：
  - `server_health_check.sh`
- 从 Windows PowerShell 通过 SSH 运行脚本时要使用：
  - `tr -d '\r' | bash -s`
  以避免 PowerShell 管道把 CR 带到远端 Bash。

## 新发现（2026-04-27）：main 卡死不是服务崩溃，而是重复收盘/板块 cron 拉起长任务后卡住会话锁与插件缓存

### 现场表现
- 用户反馈：
  - 小龙虾卡死
- 远程现场检查显示：
  - `openclaw-gateway` 仍为 `active/running`
  - 18790 / 18792 / 8787 端口可监听
  - 但日志连续出现：
    - `stuck session`
- 主要卡住 session：
  - `agent:main:cron:*`
  - `agent:main:subagent:*`

### 根因
- `main` 上有多条重复的股票/板块 cron：
  - `closing-report` 3 条
  - `sector-daily-push` 3 条
- 这些 cron 仍配置了旧模型：
  - `zai/glm-5`
  - `minimax/MiniMax-M2.7`
- 但当前 `main` 已按用户要求收敛为唯一文本模型：
  - `deepseek/deepseek-v4-pro`
  - `fallbacks = []`
- 运行时会出现：
  - `payload.model ... not allowed, falling back to agent defaults`
- `closing-report` 会拉起子代理执行收盘选股流程，流程中涉及：
  - TDX live pools
  - 股票池摘要
  - 本机/远程数据桥
- 本轮现场还看到旧流程中有 OOM / 超时迹象，旧 Gateway 停止时资源峰值为：
  - `5.1G memory peak`
  - `236.3M memory swap peak`

### 本轮恢复动作
- 已通过 `openclaw cron disable <id>` 禁用 6 条问题 cron：
  - `da552909-ff91-42af-89d5-9215fdbb2b18` closing-report
  - `282378a9-f8c9-4c29-80bb-45051d867c36` closing-report
  - `11f76685-18d7-4695-95cb-b7c024d7eb36` closing-report
  - `64488ef0-2194-4c66-82e1-99c26290e7e5` sector-daily-push
  - `615a713f-c4ac-4e0d-878e-6868c225971d` sector-daily-push
  - `47c4cb25-c978-4a97-8107-006aed94a8ed` sector-daily-push
- 禁用后重启：
  - `systemctl --user restart openclaw-gateway`
- 重启后 CLI 首次最小实呼暴露插件缓存异常：
  - `PluginLoadFailureError`
  - `ENOTEMPTY ... plugin-runtime-deps/openclaw-unknown-6f2f8ee616b5/.../plugin-sdk`
- 已将该缓存目录改名备份：
  - `~/.openclaw/plugin-runtime-deps/openclaw-unknown-6f2f8ee616b5.pre-cache-reset-20260427-160633`
- 让 OpenClaw 重新生成插件运行时缓存后，CLI 恢复。

### 当前验收结论
- `openclaw config validate` 通过。
- `openclaw-gateway` 为 `active`。
- Telegram webhook 已重新 advertised：
  - `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- 最小实呼返回：
  - `MAIN_RECOVERED_OK`
  - provider/model 为 `deepseek/deepseek-v4-pro`
  - `fallbackUsed = false`
- 复核：
  - 无新的 `stuck session`
  - 无残留 `*.jsonl.lock`
  - 6 条问题 cron 均为 `enabled=false`

### 后续注意
- 这 6 条 cron 只是禁用，没有删除。
- 如果后续要恢复收盘报告和板块推送，应先重构：
  1. 去重，只保留每类 1 条
  2. 明确 delivery target，避免 `Delivering to Telegram requires target <chatId>`
  3. 更新模型字段，不能再写 `zai/glm-5` / `minimax/MiniMax-M2.7`
  4. 避免 cron 里直接执行重型 TDX 全量同步；应改成短超时、少量候选、失败即精简报告

## 新发现（2026-04-27）：Telegram verbose 工具调用详情消失的根因是 `2026.4.24` 同时关闭 streaming 与强制 suppress 默认工具进度

### 现场表现
- 用户在 Telegram 中开启 Verbose 后，仍看不到以前那种：
  - `Exec: todoist ...`
  - 工具调用详情 / 工具进度消息
- 但 session transcript 显示模型确实在调用工具：
  - `toolCall` 包含 `exec`
  - `toolResult` 正常返回
  - `toolSummary.calls` 也能统计到工具调用

### 已确认配置
- `main` 当前运行：
  - `OpenClaw 2026.4.24`
- `~/.openclaw/openclaw.json`：
  - `agents.defaults.verboseDefault = "on"`
  - `channels.telegram.accounts.main-bot.streaming.mode = "off"`
  - `channels.telegram.accounts.main-bot.streaming.chunkMode = "newline"`
  - `agents.defaults.model.primary = deepseek/deepseek-v4-pro`
  - `agents.defaults.model.fallbacks = []`
- Telegram direct session：
  - `verboseLevel = "on"`

### 根因
- 文件：
  - `/home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.24/node_modules/openclaw/dist/extensions/telegram/bot-gUR32RLX.js`
- 关键逻辑：
  - `previewToolProgressEnabled = Boolean(answerLane.stream) && resolveChannelStreamingPreviewToolProgress(telegramCfg)`
  - 原代码同时硬编码：
    - `suppressDefaultToolProgressMessages: true`
- 因此当 Telegram streaming 关闭时：
  1. `answerLane.stream` 不存在，preview 工具进度不会运行
  2. 默认离散工具进度消息又被 `suppressDefaultToolProgressMessages: true` 关闭
  3. 结果就是 verbose 已开，但 Telegram 看不到 `Exec: ...` 这类工具详情

### 本轮热修
- 已备份原文件：
  - `bot-gUR32RLX.js.pre-tool-progress-fix-20260427-152230`
- 已将 Telegram 扩展改为和 Discord / Slack 同类逻辑一致：
  - `suppressDefaultToolProgressMessages: previewToolProgressEnabled ? true : void 0`
- 含义：
  - streaming preview 可用时，继续抑制默认工具进度，避免重复
  - streaming preview 不可用时，不再抑制默认工具进度，恢复旧式独立 `Exec: ...` 消息

### 验收
- `openclaw config validate` 通过。
- `systemctl --user restart openclaw-gateway` 后：
  - 服务为 `active/running`
  - `NRestarts = 0`
  - 启动日志显示 `agent model: deepseek/deepseek-v4-pro`
  - Telegram webhook 已重新 advertised
- CLI 工具调用 smoke test：
  - `exec` 调用成功
  - 返回 `OPENCLAW_TOOL_PROGRESS_PATCH_OK`
  - `executionTrace.fallbackUsed = false`
- Telegram webhook 模拟入口测试：
  - 伪造用户消息触发 `exec`
  - session 记录到 `toolMetas = exec`
  - 日志中同一轮产生两条 `sendMessage`，对应工具进度 / 摘要消息与最终回复

### 后续注意
- 这是直接改安装树的 hot patch。
- 后续如果执行：
  - `pnpm add -g openclaw@latest`
  - `openclaw update`
  - 或重新安装 `openclaw`
  该补丁可能被覆盖。
- 下次升级后应检查：
  - `dist/extensions/telegram/*` 中 `suppressDefaultToolProgressMessages`
  - 如果上游还没修，重新套用本条热修。

## 新发现（2026-04-27）：main 已切到 `DeepSeek V4 Pro` 唯一文本模型，OpenClaw catalog 与实呼均确认无 fallback

### 官方文档与模型参数
- DeepSeek 官方 API 文档入口：
  - `https://api-docs.deepseek.com/zh-cn/`
- DeepSeek V4.0 发布文档：
  - `https://api-docs.deepseek.com/zh-cn/news/news260424`
- DeepSeek 价格 / 参数页：
  - `https://api-docs.deepseek.com/zh-cn/quick_start/pricing`
- 本轮按官方文档和 OpenClaw `2026.4.24` catalog 交叉确认：
  - OpenAI-compatible base URL：`https://api.deepseek.com`
  - OpenClaw provider：`deepseek`
  - 认证环境变量：`DEEPSEEK_API_KEY`
  - 模型 key：`deepseek/deepseek-v4-pro`
  - OpenClaw 内部 API 类型：`openai-completions`
  - 输入：text
  - contextWindow：`1000000`
  - maxTokens：`384000`
  - reasoning：`true`
  - supportsReasoningEffort：`true`

### main 的最终配置形态
- `~/.openclaw/.env`
  - 已配置 `DEEPSEEK_API_KEY`
  - 明文 key 不写入仓库文档
- `~/.openclaw/openclaw.json`
  - `agents.defaults.model.primary = deepseek/deepseek-v4-pro`
  - `agents.defaults.model.fallbacks = []`
  - `agents.defaults.models = {"deepseek/deepseek-v4-pro": {}}`
- `agents.list[0]` 的 `main` agent 没有单独覆盖 `model`，因此继承 defaults。
- `openclaw models status --json` 已确认：
  - `defaultModel = deepseek/deepseek-v4-pro`
  - `resolvedDefault = deepseek/deepseek-v4-pro`
  - `fallbacks = []`
  - `allowed = [deepseek/deepseek-v4-pro]`
  - `imageModel = null`

### 验收结果
- `openclaw config validate` 通过。
- `openclaw models list --all --provider deepseek --json` 中：
  - `deepseek/deepseek-v4-pro.available = true`
- 重启 `openclaw-gateway` 后日志显示：
  - `agent model: deepseek/deepseek-v4-pro`
  - `ready`
- 最小实呼返回：
  - `MAIN_DEEPSEEK_V4_PRO_OK`
  - `provider = deepseek`
  - `model = deepseek-v4-pro`
  - `fallbackUsed = false`

### 后续注意
- 因为当前按用户要求没有任何文本 fallback，如果 DeepSeek API、账户额度、网络或模型临时不可用，`main` 会直接失败，不会自动切到 MiniMax / ZAI / Kimi。
- 本轮只修改 `main`，没有修改：
  - `dayong`
  - `chunyan`
  - `zenglan`

## 新发现（2026-04-27）：OpenClaw `2026.4.24` 已原生支持 `DeepSeek V4 Pro`，但这次升级要先修 pnpm 全局目录、zenglan 旧字段和 dayong mDNS

### 本轮现场结论
- 远程 Ubuntu `100.64.65.65` 当前已升级到：
  - `OpenClaw 2026.4.24 (cbcfdf6)`
- npm latest 当前为：
  - `2026.4.24`
- 升级后四个 Gateway 均可运行：
  - `main`
  - `dayong`
  - `chunyan`
  - `zenglan`

### pnpm 全局目录的关键坑
- 本轮一开始当前 CLI 是：
  - `OpenClaw 2026.4.7`
- 远程全局 pnpm 目录存在两套 virtual store：
  - `~/.local/share/pnpm/global/5/.pnpm`
  - `~/.local/share/pnpm/global/5/node_modules/.pnpm`
- 直接执行：
  - `pnpm add -g openclaw@latest`
  会失败：
  - `ERR_PNPM_UNEXPECTED_VIRTUAL_STORE`
- 尝试：
  - `pnpm --config.virtual-store-dir=node_modules/.pnpm add -g ...`
  也不可行，因为 pnpm 禁止：
  - `"virtual-store-dir" may not be used with "global"`
- `cd global/5 && pnpm install --force` 也不是正确修法：
  - 它会按普通项目重建到 `node_modules/.pnpm`
  - 但 `pnpm add -g` 仍坚持全局规则 `global/5/.pnpm`

### 本轮实际可用的升级修法
1. 先停四个 Gateway，避免运行中进程读半更新安装树
2. 备份配置和 pnpm 全局文件
3. 将旧：
   - `~/.local/share/pnpm/global/5/node_modules`
   原地改名
4. 执行：
   - `pnpm add -g openclaw@latest`
5. 执行：
   - `pnpm approve-builds -g --all`
6. 确认新 `node_modules` 的 `.modules.yaml` 中：
   - `virtualStoreDir = ../.pnpm`
7. 再启动 Gateway 并验收

### `zenglan` 的新版 schema 变化
- `2026.4.24` 下，`~/.openclaw-zenglan/openclaw.json` 中以下飞书旧字段会导致校验失败：
  - `channels.feishu.accounts.zenglan-feishu.botName`
  - `channels.feishu.accounts.zenglan-feishu.blockStreaming`
- 本轮已删除这两个字段。
- 这与之前 `chunyan` 在 `2026.4.7` 上遇到的飞书 schema 收敛问题同源。

### `dayong` 的升级后循环重启根因
- `dayong` 有 8 个飞书 WebSocket 账号。
- 升级后启动时，某些飞书 ping 请求会超时：
  - `POST https://open.feishu.cn/open-apis/bot/v1/openclaw_bot/ping`
  - `timeout of 10000ms exceeded`
- 同时 Bonjour/mDNS advertiser 会出现：
  - `CIAO ANNOUNCEMENT CANCELLED`
- 该 rejection 未被处理，会杀掉 dayong 进程，导致 systemd 循环重启。

### `dayong` 的稳定修法
- 只对 `dayong` 写入：
  - `discovery.mdns.mode = "off"`
- 依据：
  - `OpenClaw 2026.4.24` 类型定义中 `DiscoveryConfig.mdns.mode` 支持：
    - `off`
    - `minimal`
    - `full`
- 效果：
  - dayong 重启后 `NRestarts = 0`
  - 8 个飞书 WebSocket 均恢复到 `ws client ready`
  - Gateway 保持 `active/running`

### DeepSeek V4 Pro 支持结论
- `OpenClaw 2026.4.24` 内置 `deepseek` provider 当前列出：
  - `deepseek/deepseek-v4-flash`
  - `deepseek/deepseek-v4-pro`
- 本机 catalog 中 `deepseek/deepseek-v4-pro` 的关键元数据：
  - `input = text`
  - `contextWindow = 1000000`
  - `maxTokens = 384000`
  - `reasoning = true`
  - `supportsReasoningEffort = true`
- provider 认证环境变量：
  - `DEEPSEEK_API_KEY`
- provider 默认 base URL：
  - `https://api.deepseek.com`
- 工程结论：
  - 最新版已原生支持 Deepseek V4 Pro 的模型配置
  - 当前 live 未启用它，只是因为没有配置 `DEEPSEEK_API_KEY` 和没有把默认模型切过去

### 后续注意
- 本轮验收过程中多次触发：
  - `zai/glm-5`
  - `zai/glm-5.1`
  的 `429` rate limit。
- 这属于模型额度 / 服务侧访问量限制，不是 Gateway 服务未启动。
- 如果后续要把某个实例切到 DeepSeek V4 Pro，优先补：
  - `DEEPSEEK_API_KEY`
  然后再将对应实例的：
  - `agents.defaults.model.primary`
  或指定 `agents.list[].model`
  切到：
  - `deepseek/deepseek-v4-pro`

## 新发现（2026-04-12 晚）：`chunyan` 在 `OpenClaw 2026.4.7` 上要真正“复活”，至少要同时过 4 层，缺一层都可能表现成“服务还活着，但一重启就死”

### 本轮现场证据
- `openclaw-gateway-chunyan`
  在本轮开始时虽然仍显示：
  - `active`
  但那是：
  - `2026-04-07 20:39:47 CST`
  启动的旧进程
- 当前共享 CLI 已是：
  - `OpenClaw 2026.4.7`
- 只要用当前 CLI 重新读取：
  - `~/.openclaw-chunyan/openclaw.json`
  第一时间就报：
  - `Cannot find module '@larksuiteoapi/node-sdk'`
- 继续检查真实运行树：
  - `/home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.7_@napi-rs+canvas@0.1.97/node_modules/openclaw`
  现场全树都是：
  - `root:root`
- 因此第一次尝试补：
  - `@larksuiteoapi/node-sdk`
  直接失败于：
  - `EACCES rename`
- 在先：
  - `sudo chown -R kevinlasnh:kevinlasnh`
  之后，单独再装：
  - `@larksuiteoapi/node-sdk`
  又触发共享运行树重算依赖，导致之前手补的：
  - `grammy`
  - `@grammyjs/runner`
  - `@grammyjs/transformer-throttler`
  被重新抹掉
- 于是同一棵树里，第二轮校验立刻变成：
  - `Cannot find module 'grammy'`
- 在依赖层全部补通后，配置校验又继续前进到 schema 层，最终坐实：
  - `channels.feishu.accounts.chunyan-feishu.botName`
  - `channels.feishu.accounts.chunyan-feishu.blockStreaming`
  这两个旧字段会被：
  - `2026.4.7`
  直接判为：
  - `must NOT have additional properties`
- 同时本轮旧日志还继续坐实另一个独立问题：
  - `zai/glm-5`
  在：
  - `2026-04-10`
  到：
  - `2026-04-11`
  期间多次返回：
  - `429 该模型当前访问量过大，请您稍后再试`
  而当时：
  - `fallbacks = []`

### 工程结论
- 对当前这台多实例主机上的：
  - `OpenClaw 2026.4.7`
  来说，
  `chunyan` 要能稳定重启，至少要同时满足：
  1. **共享运行树补齐依赖**
     - 至少包括：
       - `@larksuiteoapi/node-sdk`
       - `grammy`
       - `@grammyjs/runner`
       - `@grammyjs/transformer-throttler`
  2. **共享运行树所有权可写**
     - 否则手工热修会先死在：
       - `EACCES`
  3. **飞书账号配置收敛到 `2026.4.7` schema**
     - `botName`
     - `blockStreaming`
     不应再出现在：
     - `channels.feishu.accounts.<accountId>`
  4. **给 `zai/glm-5` 配置可用 fallback**
     - 否则一旦命中：
       - `429`
       就会直接 surface error

### 本轮最终稳定修法
- 先执行：
  - `sudo chown -R kevinlasnh:kevinlasnh /home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.7_@napi-rs+canvas@0.1.97`
- 然后**一次性**补齐共享运行树需要的额外依赖：
  - `grammy`
  - `@grammyjs/runner`
  - `@grammyjs/transformer-throttler`
  - `@larksuiteoapi/node-sdk`
- 再将：
  - `~/.openclaw-chunyan/openclaw.json`
  收敛为：
  - `models.providers.zai.apiKey = ${ZAI_API_KEY}`
  - `agents.defaults.model.primary = zai/glm-5`
  - `agents.defaults.model.fallbacks = [minimax/MiniMax-M2.5]`
  - 删除：
    - `channels.feishu.accounts.chunyan-feishu.botName`
    - `channels.feishu.accounts.chunyan-feishu.blockStreaming`
- 重启后再以最小实呼验收，不只看：
  - `service active`
  还要看：
  - Feishu WebSocket 已 ready
  - 最小实呼已返回

### 本轮验收结果
- `openclaw config validate`
  已恢复：
  - `valid`
- `openclaw-gateway-chunyan`
  重启后日志已恢复：
  - `agent model: zai/glm-5`
  - `ready`
  - `feishu[chunyan-feishu]: WebSocket client started`
  - `ws client ready`
- 最小实呼：
  - `CHUNYAN_REVIVED_OK`
  已返回
- 返回元数据确认本次实际通过：
  - `minimax/MiniMax-M2.5`
  完成兜底

### 一个后续仍要注意的坑
- 在这棵：
  - `2026.4.7`
  共享运行树里，
  **单独**安装某一个缺失依赖，
  很可能会把之前已经手补进去的其它额外依赖重新清掉。
- 因此对这台机子上的坏包热修，当前更稳的规则应是：
  - **按“整套额外依赖”一起补**
  - 不要再按“缺一个补一个”的顺序零碎打补丁。

## 新发现（2026-04-07 晚）：当 OpenClaw 通过 `npm -g` 自更新自己时，最容易炸的不是“下载失败”，而是“正在使用的全局目录无法原地 rename”

### 本轮现场证据
- 今日主实例实际触发过：
  - `update.run`
- gateway 日志随后明确出现多次：
  - `sudo npm i -g openclaw@latest`
- root npm debug log 第一轮失败根因已坐实为：
  - `ENOTEMPTY: directory not empty, rename '/usr/lib/node_modules/openclaw' -> '/usr/lib/node_modules/.openclaw-*'`
- 也就是说：
  - npm 在尝试“退休”旧全局目录时，
  - 因目录仍非空而失败，
  - 不是 registry 拉包失败

### 工程结论
- 对正在运行中的 OpenClaw 来说，
  - 如果更新路径仍是：
    - `npm -g`
  - 那么“旧全局目录重命名失败”是一个真实风险
- 失败后可能出现很坏的中间态：
  - 旧 gateway 进程还在内存里继续跑
  - 但磁盘上的：
    - `/usr/bin/openclaw`
    - `/usr/lib/node_modules/openclaw`
    已被删空或打残
- 这种状态下，运行中的旧进程一旦再懒加载新模块，
  - 就会报：
    - `ERR_MODULE_NOT_FOUND`

### 本轮验证出的更稳迁移法
- 若用户明确要把全局安装方式切到：
  - `pnpm -g`
  正确顺序应是：
  1. 先备份当前配置与安装内 Markdown
  2. 停主 gateway
  3. 完成：
     - `pnpm add -g openclaw@latest`
     - `pnpm approve-builds -g --all`
  4. 恢复一个稳定的全局入口
  5. 再启动 gateway

## 新发现（2026-04-07 晚）：pnpm 生成的全局 CLI wrapper 不能再被“二次符号链接”当作 systemd 入口，否则会按错误基准目录解析内部相对路径

### 本轮现场证据
- pnpm 生成的真实入口为：
  - `/home/kevinlasnh/.local/share/pnpm/openclaw`
- 将：
  - `/usr/local/bin/openclaw`
  直接软链到该文件后，
  现场执行：
  - `/usr/local/bin/openclaw --version`
  会报：
  - `Cannot find module '/usr/local/bin/global/5/.pnpm/.../openclaw.mjs'`
- 这说明 wrapper 内部是基于：
  - `$0`
  计算相对路径
- 一旦从别的目录名被再次软链调用，
  - 相对路径就会算错

### 工程结论
- 对 pnpm 全局安装的 OpenClaw：
  - **不要**把：
    - `~/.local/share/pnpm/openclaw`
    再做一层符号链接后交给 systemd
- 更稳的做法是：
  - 要么 systemd 直接执行它的绝对路径
  - 要么恢复一个真正的包装脚本，例如：
    - `/usr/bin/openclaw`
    由该脚本显式：
      - `exec /home/kevinlasnh/.local/share/pnpm/openclaw "$@"`

### 本轮最终落地
- 当前主机已恢复：
  - `/usr/bin/openclaw`
  为稳定 wrapper
- 这样既能让：
  - `main`
  正常启动，
  也能兼容另外三个仍写着：
  - `ExecStart=/usr/bin/openclaw ...`
  的 gateway service

## 新发现（2026-04-06 下午）：`GLM-5V-Turbo` 的正确接法应走 OpenClaw 原生 `zai` provider，但当前这把套餐 key 对图片模型会返回 `429`，因此不应继续挂在 `main.imageModel`

### 本轮现场依据
- 先在隔离目录里按 OpenClaw 官方方式执行：
  - `openclaw onboard --auth-choice zai-coding-cn`
- 该隔离环境生成出的标准 `zai` provider 里，确实已经带上：
  - `zai/glm-5.1`
  - `zai/glm-5v-turbo`
  - `zai/glm-4.6v`
- 隔离环境里执行：
  - `openclaw models list --all --provider zai`
  也明确列出了：
  - `zai/glm-5.1`
  - `zai/glm-5v-turbo`
- 继续用同一把：
  - `ZAI_API_KEY`
  对图片理解做直接实测，结果是：
  - `zai/glm-5v-turbo`
    - 返回：
      - `429 当前订阅套餐暂未开放GLM-5V-Turbo权限`
  - `zai/glm-4.6v`
    - 可正常返回：
      - `IMAGE_PROBE_OK`

### 工程结论
- 这次 `main` 的图片报错，根因其实有两层：
  1. 配置层：
     - 之前被错误地配出了：
       - `zvision`
       - `zaivision`
       - `zai-vision`
     - 这几套自造 provider 会让 OpenClaw image runtime 直接报：
       - `Unknown model`
  2. 套餐层：
     - 即使按 OpenClaw 官方 `zai-coding-cn` 预设把配置收敛正确，
       当前这把套餐 key 也仍然没有：
       - `GLM-5V-Turbo`
       的图片权限

### 直接落地建议
- 如果用户当前不打算继续在 OpenClaw 里做图片理解：
  - 最稳的处理不是继续保留一个坏掉的 `imageModel`
  - 而是：
    - **直接删除 `agents.defaults.imageModel`**
- 如果将来仍想走 OpenClaw 自带图片理解：
  - 正确 provider 应是：
    - `zai`
  - 不应再自造：
    - `zvision`
    - `zaivision`
    - `zai-vision`
- 另外：
  - `minimax/MiniMax-M2.7`
    不应再作为图片 fallback
  - 本轮 image runtime 现场已再次确认它会报：
    - `Model does not support images`

## 新发现（2026-04-05）：今天这次 SSH 抽风的根因是远端双网卡默认路由抖动，不是 `sshd` 崩了

### 现场证据
- 远端 `ssh.service` 当前仍显示：
  - 自 `2026-03-15 21:17:40 CST` 持续 `active`
- `journalctl -u ssh` 在本轮故障时间窗里：
  - **没有**对应的 crash / restart 记录
- 远端 `tailscaled` 日志在：
  - `2026-04-05 16:13:44 CST`
  - `2026-04-05 16:13:46 CST`
  明确出现两次：
  - `LinkChange: major`
  - 默认路由在：
    - `wlp0s20f3`
    - `enp59s0`
    之间来回切换
- 随后在：
  - `2026-04-05 16:22:39` 到 `16:24:28 CST`
  连续出现：
  - `CreateEndpoint error ... -> 100.64.65.65:22: operation timed out`
- 同一时间段 `tailscale ping` 仍可返回：
  - `pong ... via DERP(hkg)`
  说明：
  - 节点没有整体离线
  - 主要坏在数据面建链 / 路由重绑阶段

### 运维结论
- 这次坏的不是：
  - `openssh-server`
- 更接近事实的是：
  - **远端同时挂着有线 + Wi‑Fi，导致默认路由抖动**
  - **Tailscale 在重绑链路时，普通 SSH 建链短时超时**
- 本轮用户已切到：
  - **仅保留有线网**
  这是正确收敛方向

### 当前最稳的连接策略
1. VS Code / 日常主入口：
   - 优先走远端专门开的：
     - `2222`
2. 普通 OpenSSH 备用：
   - `22`
3. Tailscale SSH：
   - 作为兜底应急链路

### 额外提醒
- 本轮新增的 `2222` 监听是：
  - `100.64.65.65:2222`
  - 由独立 `sshd` 进程承载
- 若后续又出现“偶发能连、偶发 banner 超时”的形态，优先先看：
  - `journalctl -u tailscaled`
  - 是否再次出现：
    - `LinkChange: major`
    - `CreateEndpoint error`

## 新发现（2026-04-05）：按 OpenClaw 官方模板核对后，当前 `workspace` 的主要问题不是“缺文件”，而是 `IDENTITY / TOOLS / MEMORY / memory/` 职责混线

### 本轮对照的官方依据
- `Agent Runtime`
- `Agent Workspace`
- `Agent Bootstrapping`
- `BOOT.md Template`
- `BOOTSTRAP.md Template`
- `HEARTBEAT.md Template`
- `Memory Overview`

### 已坐实的健康项
- 根目录当前存在：
  - `AGENTS.md`
  - `SOUL.md`
  - `TOOLS.md`
  - `IDENTITY.md`
  - `USER.md`
  - `HEARTBEAT.md`
  - `BOOT.md`
  - `MEMORY.md`
- `BOOTSTRAP.md` 当前缺失：
  - **这是正常现象**
  - 官方文档明确写了：
    - 首轮 bootstrapping 完成后应删除
    - 后续不应反复留在工作区
- `HEARTBEAT.md` 当前几乎为空：
  - 这也**不是故障**
  - 官方模板明确允许：
    - 留空或只有注释
    - 以此跳过 heartbeat 任务内容

### 主要职责混线
1. `IDENTITY.md` 与 `SOUL.md` 的“你是谁”定义互相打架
   - `IDENTITY.md` 当前名字/物种是：
     - `小龙虾`
     - `有性格的小龙虾`
   - 但 `SOUL.md` 当前核心自我声明是：
     - `花园多惠`
   - 这会让“身份元数据”与“人格设定”出现双主身份

2. `TOOLS.md` 混入了大量**已过期**或**已删除路径**
   - 当前仍写着：
     - `~/.openclaw/skills/...`
     - `~/.agents/skills/...`
     - `~/.openclaw/workspace/skills/...`
   - 但这些目录在 `2026-04-03` 主实例清杂物时已经清掉或不再是当前 live 结构
   - 同时 `TOOLS.md` 还写着：
     - `Memory Search` 暂不可用
   - 这与当前 live 状态冲突：
     - 主实例本地 memory search 已恢复并实际可用

3. `MEMORY.md` 现在不只是“长期记忆”，还混进了：
   - 运维手册
   - 路径规范
   - Skill 工作流
   - 多 Gateway 架构说明
   - 历史模型状态
   - 量化交易项目设计
- 官方 Memory 文档定义的 `MEMORY.md` 更接近：
  - **durable facts / preferences / decisions**
  - 而不是大段 runbook / tool cookbook / 项目设计文档

4. `memory/` 目录里混放了大量“不是 daily memory 的文档”
   - 当前除了标准：
     - `memory/YYYY-MM-DD.md`
   - 还存在一批：
     - 研究报告
     - Prompt 草稿
     - 专题调研
     - 会话摘录
   - 例如：
     - `memory/daily-memory-save-prompt.md`
     - `memory/2026-03-15-telegram-markdown-research.md`
     - `memory/2025-top100-stock-patterns.md`
     - `memory/2026-top10-industries-100-stocks.md`
   - 这些文件能被 memory search 吃进去，但从“文件职责”看，更像：
     - 提示词 / 研究资料 / 专题文档
   - 而不是：
     - 日记式 recall
     - 或长期记忆本体

### 目前最准确的判断
- 当前 `workspace` **不是乱到不能用**
- 但按 OpenClaw 官方定义去看，已经形成了 3 类混线：
  1. **身份定义冲突**
  2. **工具说明过期**
  3. **记忆区混放项目文档**

### 直接整理方向
1. `IDENTITY.md`
   - 只保留元信息
   - 明确一个唯一主身份
2. `SOUL.md`
   - 只保留人格、边界、语气、价值观
   - 少放可机械检索的设定表
3. `TOOLS.md`
   - 只留当前真实可用的路径、命令、约束
   - 删除已清理 skill 路径和过期说明
4. `MEMORY.md`
   - 收敛为长期事实 / 偏好 / 重要决定
   - 把 runbook / 项目设计迁出
5. `memory/`
   - `YYYY-MM-DD.md` 保留为 daily memory
   - 非日记类文档按性质迁到：
     - `notes/`
     - `research/`
     - `prompts/`
     - 或仓库正式文档
   - 不再混在 `memory/`

## 新发现（2026-04-05）：`TOOLS.md` 一旦混入失效路径和旧状态，就会从“工具速查”变成误导源

### 本轮清理前的典型坏味道
- 旧的 `skills` 安装清单
- 已删除的 `~/.agents/skills/*` / `workspace/skills/*` 路径
- 已过时的状态描述，例如：
  - `Memory Search 暂不可用`

### 本轮收敛后的原则
- `TOOLS.md` 只保留：
  - 当前主机环境
  - 真实可连的目标主机
  - 稳定路径约定
  - 少量常用检查命令
  - 文档边界约束
- 不再保留：
  - 安装历史
  - 已删除路径
  - 临时项目 workflow
  - 临时排障结论

### 工程结论
- `TOOLS.md` 越像“live 工具速查”，越健康。
- 如果它开始像：
  - 路径坟场
  - 安装记录
  - 旧故障摘要
  就应该立刻瘦身。

## 新发现（2026-04-05）：`IDENTITY.md` 和 `SOUL.md` 不该争夺“主身份”，正确做法是“身份卡”和“人格文件”分工

### 本轮对照的官方方向
- `IDENTITY.md`
  - 更接近：
    - 名字
    - 气质标签
    - Emoji / Avatar
  - 也就是：
    - **元身份卡片**
- `SOUL.md`
  - 更接近：
    - 核心自我
    - 语气
    - 价值观
    - 边界
    - 连续性
  - 也就是：
    - **人格文件**

### 本轮修正前的真实问题
- `IDENTITY.md` 之前写的是：
  - `小龙虾`
  - `有性格的小龙虾`
- `SOUL.md` 之前写的是：
  - `花园多惠`
- 结果不是“风格参考”，而是：
  - **两个主身份同时存在**
- 这会导致运行时注入出现一种很别扭的状态：
  - UI / 元信息像一个人
  - 人格自述像另一个人

### 本轮最终分工
1. `IDENTITY.md`
   - 现在只保留：
     - `Name`
     - `Creature`
     - `Vibe`
     - `Emoji`
     - `Avatar`
   - 主身份已统一为：
     - `花园多惠`
   - 这份文件不再承担：
     - 人格展开
     - 工作规则
     - 角色百科

2. `SOUL.md`
   - 现在只保留：
     - `Core Truths`
     - `Vibe`
     - `Chat Style`
     - `Boundaries`
     - `With Kevin`
     - `Continuity`
   - 明确保留的不是“角色履历”，而是：
     - **花园多惠式的性格和聊天语气**
   - 删除或压缩掉的，是：
     - 生日
     - 身高
     - 成员名单
     - 关系表
     - 大段角色百科

### 本轮最关键的工程判断
- 如果用户真正想保留的是：
  - 花园多惠的说话感觉
  - 天然、安静、直接、偶尔跳脱的气质
  - 对 `kevinlasnh` 的相处方式
- 那就应该：
  - **保留人格信号**
  - **删除百科噪声**
- 这样做不会把人格“削没”，反而会让运行时注入更稳定。

### 本轮最终效果
- `IDENTITY.md`
  - 不再和 `SOUL.md` 抢“我是谁”
- `SOUL.md`
  - 仍完整保留：
    - 花园多惠的人格
    - 聊天语气
    - 价值观
    - 对 `kevinlasnh` 的默认态度
- 当前这两个文件已经从：
  - **双主身份冲突**
  收敛为：
  - **花园多惠身份卡 + 花园多惠人格文件**

### 工程结论
- `IDENTITY.md` 应该越短越好。
- `SOUL.md` 应该高密度地影响对话，而不是像角色 wiki。
- 对长期稳定聊天体验来说：
  - **人格保留**
  - **百科减重**
  是比“全量设定照抄”更健康的做法。

## 新发现（2026-04-05）：如果用户不需要 `BOOT.md` 的启动职责，最干净的做法不是只清空文件，而是把内部 `boot-md` hook 也禁用

### 本轮现场状态
- 远端 `~/.openclaw/workspace/BOOT.md` 已被清空：
  - 当前文件大小为：
    - `0 bytes`
- 但这还不等于“boot 机制已关闭”。

### 本轮额外核对结果
- OpenClaw 官方 runtime 文档明确把：
  - `BOOT.md`
  归在：
  - **bootstrap files (injected)**
- 同时远端 live 配置里实际还启用了内部 hook：
  - `hooks.internal.entries.boot-md.enabled = true`
- `openclaw hooks list` 本轮现场也直接显示：
  - `boot-md`
  原本是：
  - `ready`

### 本轮最终处理
1. 清空：
   - `~/.openclaw/workspace/BOOT.md`
2. 将远端 live 配置改为：
   - `hooks.internal.entries.boot-md.enabled = false`
3. 重启：
   - `openclaw-gateway`

### 验证结果
- `systemctl --user is-active openclaw-gateway`
  - 返回：
    - `active`
- 配置复核：
  - `boot-md = false`
- `openclaw hooks list`
  - 当前显示：
    - `boot-md = disabled`

### 工程结论
- 如果只是把 `BOOT.md` 清空：
  - hook 仍然存在，只是跑到空文件
- 如果用户明确不要这项职责：
  - **应同时清空文件 + 禁用 `boot-md` hook**
- 这样以后 Gateway 重启时，就不会再执行这条 boot 逻辑。

## 新发现（2026-04-05）：`USER.md` 应只保留“这个用户是谁、怎么称呼、长期偏好与背景”，不应混入 Bot / IP / 代理 / 身份验证规则

### 本轮对照的官方依据
- `USER.md` 模板强调的核心字段只有：
  - `Name`
  - `What to call them`
  - `Pronouns`
  - `Timezone`
  - `Notes`
- 下面的 `Context` 部分才用于逐步积累：
  - 他们关心什么
  - 在做什么
  - 讨厌什么
  - 喜欢什么

### 本轮修正前的典型混线
- 旧 `USER.md` 里混入了很多并不属于“用户画像”的内容：
  - Telegram User ID
  - Bot 用户名
  - Ubuntu / Windows 设备与 Tailscale IP
  - 代理地址
  - “其他号码先问你是谁”这类身份识别规则
- 这些内容更像：
  - 渠道配置
  - 网络环境
  - 行为规则
- 而不是：
  - `USER.md` 应承载的用户画像本身

### 本轮收敛后的正确边界
- `USER.md` 现在只保留：
  - 用户名与称呼
  - 时区
  - 语言与沟通偏好
  - 作息与兴趣
  - 长期协作偏好
- 已删除：
  - ID / Bot / IP / 代理
  - 设备拓扑
  - 身份验证规则

### 工程结论
- `USER.md` 越像“关于这个人的长期画像”，越符合官方定义。
- 渠道、网络、设备、验证规则如果需要保留，应分别回到：
  - `TOOLS.md`
  - `AGENTS.md`
  - 或运行配置
- 不应继续占用 `USER.md` 的上下文预算。

## 新发现（2026-04-05）：`AGENTS.md` 最适合承载“工作规则和上下文使用方式”，不适合继续堆成长篇教程

### 本轮对照的官方依据
- OpenClaw 官方模板中，`AGENTS.md` 的核心块是：
  - `Session Startup`
  - `Memory`
  - `Red Lines`
  - `External vs Internal`
  - `Know When to Speak`
  - `Tools`
  - `Heartbeats`
- 这说明它的定位更接近：
  - **操作规则**
  - **上下文使用方式**
  - **安全边界**
- 而不是：
  - 人格文件
  - 工具手册
  - 平台教程
  - 社交学长文

### 本轮修正前的坏味道
- 旧文件整体更像：
  - 官方默认模板原样堆叠
  - 外加长篇 heartbeat / cron 讲解
  - 平台差异说明
  - 社交行为教程
- 这些内容方向不一定错，但对当前主工作流来说：
  - **太长**
  - **太散**
  - **太像说明书**

### 本轮收敛后的结构
- 当前 `AGENTS.md` 只保留 6 块：
  - `Session Startup`
  - `Memory`
  - `边界`
  - `文件职责`
  - `说话规则`
  - `Tools`
  - 外加一个很短的 `Heartbeat`

### 本轮明确保留的内容
- 启动时该读哪些文件
- `MEMORY.md` 只在主私聊中使用
- 想记住的事情必须写进文件
- 不泄露隐私、不做未经确认的破坏性或对外动作
- 先结论后理由、直接讲事实
- 群聊里只在被需要时发言
- tool / skill 的最小使用原则

### 本轮明确删除或压缩的内容
- 长篇 `group chats` 社交说明
- `React Like a Human` 这类平台行为教程
- Discord / WhatsApp 格式细则
- `sag` 语音讲故事之类与当前主流程弱相关的建议
- 长篇 `heartbeat vs cron` 教程
- `heartbeat-state.json` 示例和大量轮询样例
- 过多的“为什么”解释文字

### 工程结论
- `AGENTS.md` 应该像：
  - 一份高密度操作规约
- 不应该像：
  - 新手入门课件
- 对当前这个 workspace 来说，越短、越清楚、越能直接影响行为，就越健康。

## 新发现（2026-04-05）：`MEMORY.md` 应只保留提炼后的长期事实、偏好和决定；带日期的阶段性内容应回到对应的 daily memory

### 本轮对照的官方依据
- 官方 `Memory` 文档把记忆分成两层：
  - `memory/YYYY-MM-DD.md`
    - 每日日志
    - 原始记录
  - `MEMORY.md`
    - 精心整理的长期记忆
    - 只在主私聊中加载
- 官方 `AGENTS.md Template` 也明确强调：
  - 决策、偏好、持久性事实写入 `MEMORY.md`
  - 日常笔记和运行上下文写入 `memory/YYYY-MM-DD.md`

### 本轮修正前的真实问题
- 旧 `MEMORY.md` 里混了 4 种东西：
  - 用户长期画像
  - 设备 / 网络 / 路径 / 工具说明
  - 带日期的历史事件
  - 项目阶段性状态
- 结果这份文件更像：
  - 总杂记
  - 而不是：
    - 长期记忆

### 本轮最终处理
1. 重写 `MEMORY.md`
   - 现在只保留：
     - 关于 `kevinlasnh` 的长期偏好
     - second-brain / `C:\Zero\` / `kebab-case` 这类长期事实与约定
     - 自动化炒股 / trading-brain 这类长期项目与决策

2. 将旧 `MEMORY.md` 里的带日期内容迁回 daily memory
   - `2026-02-22.md`
     - 迁入 trading-brain 重构决定补记
   - `2026-02-23.md`
     - 迁入 trading-brain 阶段性状态补记
   - `2026-03-08.md`
     - 迁入 G 盘与生活哲学文档补记
   - `2026-03-09.md`
     - 迁入多 Gateway 与环境补记
   - `2026-03-10.md`
     - 迁入 second-brain 流程与聊天偏好补记

### 本轮明确删除或不再保留在长期记忆中的内容
- 详细的 G 盘访问示例命令
- 目录树和 runbook
- 多 Gateway 端口 / Bot / 配置细节
- Telegram / 代理 / SSH / Edge 调试等环境说明
- Twitter 自动化探索细节
- 聚宽账号与试用信息
- 大量 dated 项目进展与回测状态

### 工程结论
- `MEMORY.md` 越像“蒸馏后的长期脑内设定”，越符合 OpenClaw 的标准。
- 带日期的内容哪怕很重要，只要它本质上是：
  - 当天发生了什么
  - 某次排障结论
  - 某个阶段的进展
  都应优先回到：
  - `memory/YYYY-MM-DD.md`
- 这样做的结果是：
  - 长期记忆更稳定
  - daily memory 更完整
  - memory search 的命中语义也更清楚

## 新发现（2026-04-03）：`api.nih.cc` 的 `v1/models` 列出 Anthropic 模型，不等于当前 key 可以实际调用

### 本轮现场探测
- `GET https://api.nih.cc/v1/models` 当前可正常返回模型列表。
- 返回中明确包含：
  - `anthropic/claude-sonnet-4`
  - `anthropic/claude-sonnet-4.5`
  - `anthropic/claude-sonnet-4.6`
  - `anthropic/claude-sonnet-4.6-thinking`
- 但对目标模型执行最小实呼：
  - `POST https://api.nih.cc/v1/chat/completions`
  - `model = anthropic/claude-sonnet-4.6-thinking`
  当前返回：
  - HTTP `500`
  - 响应体里的上游信息为：
    - `Cursor API 错误: HTTP 403`

### 同类模型交叉验证
- 同站同一把 key 下继续实测：
  - `anthropic/claude-sonnet-4`
  - `anthropic/claude-sonnet-4.6`
- 当前也都失败，表现同样是：
  - 站点外层返回 `500`
  - 内层上游报：
    - `Cursor API 错误: HTTP 403`

### 反向验证：不是整站不可用
- 同一把 key、同一个：
  - `https://api.nih.cc/v1/chat/completions`
  下，以下模型本轮已确认可以正常返回：
  - `z-ai/glm5`
  - `deepseek-ai/deepseek-v3.2`
  - `moonshotai/kimi-k2.5`
- 说明问题不是整站 API 全挂，而是：
  - **当前这组 Anthropic 路由或上游权限不可用**

### 运维结论
- 对这类聚合 / 中转站：
  - **不能只看 `v1/models` 列表**
- 在切生产前必须对目标模型做一次最小实呼。
- 截至 `2026-04-03`：
  - 本项目不应把 `main` 切到：
    - `anthropic/claude-sonnet-4.6-thinking`
  - 除非该站后续恢复，且重新实呼通过。

## 新发现（2026-04-03）：OpenClaw `2026.4.1` 仍支持通过 `models.providers` 配置自定义 OpenAI 兼容 provider

### 本轮 schema 结论
- `openclaw config schema` 当前仍包含：
  - `models.providers`
- `models.providers.<provider>` 的最小必需字段仍是：
  - `baseUrl`
  - `models`
- 可选字段仍包括：
  - `apiKey`
  - `auth`
  - `api`
  - `headers`
- 其中 `api` 当前允许：
  - `openai-completions`
  - `openai-responses`
  - `openai-codex-responses`
  - `anthropic-messages`
  - 以及其他内置类型
- `agents.defaults.model` 仍可写为：
  - `{"primary":"<provider>/<model>","fallbacks":[]}`

### 一个容易踩坑的点
- 在已有运行中的 Gateway 场景里，单独给 CLI 命令设置：
  - `OPENCLAW_CONFIG_PATH=/tmp/...`
  然后执行：
  - `openclaw agent --agent main ...`
  不能把**正在运行的 Gateway**强行切到这份临时配置。
- 本轮现场表现是：
  - `config validate` 会读取临时配置
  - 但 `openclaw agent --agent main --json` 返回的元数据仍显示 live：
    - `provider = openai-codex`
    - `model = gpt-5.4`

### 工程结论
- 临时配置适合做：
  - schema 校验
  - 结构验证
- 真正切换生产模型仍必须：
  - 改 live `openclaw.json`
  - 并让 Gateway 重新读取该配置

## 新发现（2026-04-02）：`main` 的本地 Memory Search 可以先手动预下载 `Qwen3-Embedding-4B-Q4_K_M.gguf`，再固定绝对路径启用

### 本轮最终可用配置
- 远端 `main` 当前语义搜索已落到：
  - `agents.defaults.memorySearch.enabled = true`
  - `agents.defaults.memorySearch.provider = "local"`
  - `agents.defaults.memorySearch.fallback = "none"`
  - `agents.defaults.memorySearch.local.modelPath = /home/kevinlasnh/.cache/openclaw/models/Qwen3-Embedding-4B-Q4_K_M.gguf`
  - `agents.defaults.memorySearch.local.modelCacheDir = /home/kevinlasnh/.cache/openclaw/models`
- 这次没有走：
  - `hf:` URI 自动下载
- 而是先手动下载模型文件，再把配置指到本地绝对路径。

### 本轮已坐实的模型文件状态
- 远端模型文件最终落地为：
  - `/home/kevinlasnh/.cache/openclaw/models/Qwen3-Embedding-4B-Q4_K_M.gguf`
- 实测文件大小：
  - `2496703776 bytes`
  - 约 `2.4G`

### 本轮踩到的关键坑
- OpenClaw 文档虽然写了本地模式可自动下载 GGUF，但这不是唯一方式。
- **只要本地文件已经存在，`memorySearch.local.modelPath` 直接指向绝对路径就可以。**
- 真正阻塞本轮的不是“是否自动下载”，而是：
  - 远端最初缺少：
    - `node-llama-cpp`

### 关于 `node-llama-cpp` 的工程结论
- 在当前 OpenClaw 安装形态下，`node-llama-cpp` 是可选 peer dependency，不一定随 OpenClaw 自动可用。
- 直接在：
  - `/usr/lib/node_modules/openclaw`
  里跑 `pnpm add`
  风险很高：
  - 会触发整棵依赖树重算
  - 本轮就实际撞到了 `@whiskeysockets/baileys` 的 git 依赖失败
  - 并一度把 OpenClaw 自身 CLI 搞坏
- 本轮最终稳定做法是：
  1. 单独建运行目录：
     - `/home/kevinlasnh/.cache/openclaw/node-llama-runtime`
  2. 在这个独立目录中安装：
     - `node-llama-cpp@3.16.2`
  3. 再把：
     - `/usr/lib/node_modules/openclaw/node_modules/node-llama-cpp`
     - `/usr/lib/node_modules/openclaw/node_modules/@node-llama-cpp`
     软链到该运行目录
- 这样可以避免再次破坏 OpenClaw 主安装目录。

### 这台机器上跑 `Qwen3-Embedding-4B-Q4_K_M` 的真实边界
- 机器配置：
  - `i7-12700H`
  - `16GB RAM`
  - `RTX 3060 Laptop 6GB`
- 本轮实测，模型初始化阶段会反复尝试走 Vulkan / GPU。
- 日志里明确出现过多次：
  - `ErrorOutOfDeviceMemory`
  - `failed to allocate buffer for kv cache`
  - `failed to allocate compute pp buffers`
- 说明这档模型对这台 `6GB` 显卡来说：
  - **不是宽松可用**
  - 而是：
    - **贴着上限跑**
- 二次快验时 `nvidia-smi` 实测：
  - `5490 MiB / 6144 MiB`
  - 空闲只剩：
    - `318 MiB`

### 但本轮最终仍然跑通了
- 日志最终出现：
  - `MEMORY_LOCAL_OK`
- 二次快验执行：
  - `openclaw agent --agent main ... call memory_search ...`
- 返回：
  - `MEMORY_LOCAL_OK_2`
- 二次快验耗时约：
  - `15118 ms`

### 对后续运维的直接结论
- `Qwen3-Embedding-4B-Q4_K_M` 在这台机器上：
  - **能跑**
  - **已被 `main` 实际用于 Memory Search**
- 但它属于：
  - **高占用、低余量**
- 如果后续出现：
  - 桌面程序抢显存
  - ToDesk / 浏览器 / 其他 GPU 任务增多
  - 首次索引变慢或偶发初始化失败
  优先回退思路应是：
  - 不改聊天主模型
  - 仅把本地 embedding 改小一档到：
    - `Qwen3-Embedding-0.6B`
  - 或改用远程 embedding API

## 新发现（2026-04-02）：`jina-embeddings-v5-text-small-retrieval-GGUF` 虽然文件只有约 `611MB`，但 OpenClaw 默认本地 provider 仍会把它整块自动挂到 GPU

### 本轮模型选择
- 用户最终没有保留：
  - `Qwen3-Embedding-4B-Q4_K_M`
- `main` 当前改为：
  - `jinaai/jina-embeddings-v5-text-small-retrieval-GGUF`
- 实际使用文件：
  - `/home/kevinlasnh/.cache/openclaw/models/v5-small-retrieval-Q8_0.gguf`
- 实测文件大小：
  - `639447424 bytes`
  - 约 `611MB`

### 一个容易误判的点
- 单看 GGUF 文件大小，很容易以为显存占用会同步大幅下降。
- 但本轮实测不是这样：
  - 即便换成 `v5-small-retrieval-Q8_0.gguf`
  - OpenClaw 默认本地 embedding provider 仍会通过 `node-llama-cpp` 自动选 GPU
  - 并把 embedding context 常驻到 `openclaw-gateway`
- 未打补丁前，Jina 小模型也会出现：
  - `openclaw-gateway` 占用约 `5591MiB` GPU 显存

### 根因
- OpenClaw 本地 memory provider 当前实现是：
  - `getLlama({ logLevel: LlamaLogLevel.error })`
  - `llama.loadModel({ modelPath })`
  - `embeddingModel.createEmbeddingContext()`
- 这里没有显式限制：
  - `gpu`
  - `gpuLayers`
  - `contextSize`
- 因此 `node-llama-cpp` 会按默认硬件自适应逻辑优先吃 GPU。

### 本轮稳定修法
- 只改本地 embedding provider，不动聊天主模型：
  - 把：
    - `getLlama({ logLevel: LlamaLogLevel.error })`
  - 改成：
    - `getLlama({ gpu: false, logLevel: LlamaLogLevel.error })`
- 这次已在远端 OpenClaw 安装目录中的以下 bundle 全量打补丁并留备份：
  - `/usr/lib/node_modules/openclaw/dist/discord-CcCLMjHw.js`
  - `/usr/lib/node_modules/openclaw/dist/reply-Bm8VrLQh.js`
  - `/usr/lib/node_modules/openclaw/dist/model-selection-CU2b7bN6.js`
  - `/usr/lib/node_modules/openclaw/dist/auth-profiles-DRjqKE3G.js`
  - `/usr/lib/node_modules/openclaw/dist/model-selection-46xMp11W.js`
  - `/usr/lib/node_modules/openclaw/dist/auth-profiles-DDVivXkv.js`
  - `/usr/lib/node_modules/openclaw/dist/plugin-sdk/thread-bindings-SYAnWHuW.js`
- 每个文件都留有：
  - `.pre-local-cpu-20260402-182740.bak`
  备份。

### 补丁后的实际效果
- 重启 `openclaw-gateway` 后，GPU 占用回落到：
  - `12MiB / 6144MiB`
- 本地语义搜索最小验收仍然通过：
  - `MEMORY_JINA_CPU_OK_1`
- 这说明：
  - `main` 的本地 `memory_search` 现在已经可用
  - 且不再长期吃掉 `5.5GB` 显存

### 对这个模型的适用结论
- 这个 Jina 模型是：
  - **文本 retrieval / embedding 模型**
- 对当前 OpenClaw 的：
  - `MEMORY.md`
  - `memory/**/*.md`
  这类文本语义检索是对口的
- 它不是：
  - 语音音频检索模型
- 但对于用户当前说的“小龙虾 Memory Search 正常语义搜索”这个目标，它是可用的。

## 新发现（2026-04-02）：如果用户只有 `ChatGPT Plus`，要让 OpenClaw “直接用订阅”，应走 `openai-codex`，不是 `openai` API

### 直接结论
- `ChatGPT Plus` / `chatgpt.com` 与 `OpenAI Platform API` / `platform.openai.com` 是两套独立计费体系。
- 所以：
  - **不能把 Plus 会员直接当成 `OPENAI_API_KEY` 的按量 API 配额来给小龙虾用**
- 如果用户目标是：
  - “小龙虾直接吃我现有 OpenAI 订阅”
  当前 OpenClaw 正确接法应是：
  - **`openai-codex/gpt-5.4`**
  - 而不是：
    - `openai/gpt-5.4`

### 对本项目的具体含义
- 这次如果只改主实例：
  - `main`
- 那么只需要处理：
  - `~/.openclaw/openclaw.json`
  - `~/.openclaw/agents/main/agent/auth-profiles.json`
  - 以及 `main` 可复用的 Codex 登录态
- 不会自动波及：
  - `dayong`
  - `chunyan`
  - `zenglan`

### 本轮已坐实的现场状态
- 远端主实例当前 live 主模型是：
  - `minimax/MiniMax-M2.7`
- 远端 `main` 的认证文件当前为空：
  - `~/.openclaw/agents/main/agent/auth-profiles.json`
- 本机 Windows 当前存在：
  - `C:\Users\kevinlasnh\.codex\auth.json`
  - 且其 `auth_mode = chatgpt`
  - 说明本机已经有可复用的 Codex / ChatGPT 登录态
- 远端当前缺失：
  - `~/.codex/auth.json`

### 工程判断
- 最优路径不是让用户再手工走一轮浏览器 OAuth。
- 更稳的路径是：
  1. 复用本机现成的：
     - `~/.codex/auth.json`
  2. 搬到远端主实例环境
  3. 只让 `main` 识别这份登录态
  4. 再把 `main` 切到：
     - `openai-codex/gpt-5.4`

### 本轮额外边界
- `openclaw models auth login --provider openai-codex`
  - 在当前非交互执行通道里会报：
    - `requires an interactive TTY`
- 因此如果不能复用现成 `~/.codex/auth.json`，就必须回到用户手工 OAuth 这条路。

## 新发现（2026-04-02）：`main` 已可仅使用 `openai-codex/gpt-5.4`，且无需任何 fallback

### 本轮实际落地
- 已将本机现成登录态：
  - `C:\Users\kevinlasnh\.codex\auth.json`
  复制到远端：
  - `~/.codex/auth.json`
- 已向：
  - `~/.openclaw/agents/main/agent/auth-profiles.json`
  写入：
  - `openai-codex:codex-cli`
  这份 OAuth 认证资料
- 已将 `main` 的默认模型配置收敛为：
  - `primary = openai-codex/gpt-5.4`
  - `fallbacks = []`
- 已将 `agents.defaults.models` 收敛为仅保留：
  - `openai-codex/gpt-5.4`
- 已清空旧的自定义 provider 留存：
  - `models.providers = {}`

### 当前已坐实的 live 状态
- `main` 当前静态配置为：
  - `agents.defaults.model = {"primary":"openai-codex/gpt-5.4","fallbacks":[]}`
- `main` 当前唯一登记模型为：
  - `openai-codex/gpt-5.4`
- 这次没有波及：
  - `dayong`
  - `chunyan`
  - `zenglan`

### 验收硬证据
- 远端执行：
  - `openclaw agent --agent main --message 'Reply with exactly MAIN_GPT54_OK' --json`
- 返回：
  - `MAIN_GPT54_OK`
- 元数据确认：
  - `provider = openai-codex`
  - `model = gpt-5.4`

### 工程结论
- 对“只给 `main` 接一个 GPT-5.4，其他模型和 fallback 全撤掉”这个目标，本轮已经完成。
- 这条链路吃的是：
  - ChatGPT / Codex 登录态
- 不是：
  - `OPENAI_API_KEY` 的按量 API 配额

## 新发现（2026-04-02）：`main` 的 Memory 语义搜索不能复用 ChatGPT Plus / Codex OAuth

### 文档结论
- OpenClaw `docs/zh-CN/concepts/memory.md` 明确写到：
  - 远程 embeddings 需要 embedding provider 的真实 API 密钥
  - `Codex OAuth` 只覆盖 chat / completions
  - **不满足 memorySearch 的 embeddings 需求**
- OpenClaw `docs/zh-CN/help/faq.md` 也明确写到：
  - 如果使用 `OpenAI embeddings`
  - 仍需要真实：
    - `OPENAI_API_KEY`
    - 或 `models.providers.openai.apiKey`

### 对本项目的直接含义
- 你现在给 `main` 接上的：
  - `openai-codex/gpt-5.4`
  只能用于对话主模型
- **不能**直接拿来当：
  - `memory_search` / `memorySearch` 的 embedding 模型

### 当前可行路线
1. 用本地 embedding：
   - `memorySearch.provider = local`
2. 用 Gemini embedding：
   - 需要 `GEMINI_API_KEY`
3. 用 OpenAI embedding：
   - 需要单独的 `OPENAI_API_KEY`
   - 与 ChatGPT Plus / Codex 登录态分开计费

## 新发现（2026-04-02）：`openclaw doctor --fix` 会直接改写 `main` 的 Telegram 配置结构

### 本轮实测
- 在远端 `main` 上执行：
  - `openclaw doctor --fix`
- Doctor 实际做了：
  - 将旧的 `channels.telegram` 单账号顶层字段迁到：
    - `channels.telegram.accounts.default`
- 并生成了备份：
  - `~/.openclaw/openclaw.json.bak`

### 当前状态
- 改写后：
  - `openclaw config validate` 通过
  - `openclaw-gateway.service` 仍在运行
- 日志可见：
  - Gateway 感知到了 config change
  - 但当前 `gateway.reload.mode = off`
  - 因此并没有自动热重载
- 实际坏态表现为：
  - `127.0.0.1:8787` 不再监听
  - Telegram 官方 `getWebhookInfo.url = ""`
  - `openclaw gateway health --json` 中 `webhook.url` 为空

### 本轮修复办法
- 将：
  - `channels.telegram.accounts.default.webhookUrl`
  - `channels.telegram.accounts.default.webhookSecret`
  移回：
  - `channels.telegram.webhookUrl`
  - `channels.telegram.webhookSecret`
- 保留 `accounts.default` 里其余默认字段不动
- 重启：
  - `openclaw-gateway.service`

### 修复后验收
- `127.0.0.1:8787` 已恢复监听
- Telegram 官方 `getWebhookInfo` 已恢复为：
  - `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- 日志重新出现：
  - `webhook local listener on http://127.0.0.1:8787/telegram-webhook`
  - `webhook advertised to telegram on https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`

### 工程提醒
- 对 `main` 跑 Doctor 时，不能把它当成只读体检。
- 它会真实改写：
  - `~/.openclaw/openclaw.json`
- 若当前任务不是为了解决 Doctor 提示本身，跑之前应先有备份意识。

## 新发现（2026-04-01 夜）：`openclaw-24x7` 的机场“上游更新”不是简单换 URL，而是订阅格式从旧 YAML/SS 切到 base64 AnyTLS

### 直接结论
- 用户给的新链接 `/dy/38573b1cc7d2f79b9c61e3f7d0847f0d` 返回的不是旧 `Clash YAML`
- 实际返回内容是：
  - base64 编码的多行 `anytls://...`
- 当前远端缓存与运行态却仍是旧的 `ss` 节点：
  - `profiles/RvqAWZAlhNcf.yaml`
  - `clash-verge.yaml`
- 所以现场会表现成：
  - `7897` 端口仍监听
  - HTTP `CONNECT` 能返回 `200`
  - 但后续 TLS `ClientHello` 之后立刻 `EOF / SSL_ERROR_SYSCALL`

### 识别方法
- 新链接响应头会带：
  - `content-type: text/plain`
  - `subscription-userinfo: upload=...; download=...; total=...; expire=...`
- 对响应体做 base64 解码后，前几行就是：
  - `anytls://...#官网youtunice.com`
  - `anytls://...#专线2.5x-香港1`
  - `anytls://...#专线2.5x-台湾1-GPT`
- 其中前 3 行只是元信息，不应纳入代理组：
  - `剩余流量...`
  - `距离下次重置剩余...`
  - `套餐到期...`
- 本轮实际可用节点数：
  - `54`

### 工程结论
- 这次不能只把 `profiles.yaml` 的 URL 改成新链接。
- 如果不同时重建运行态 YAML，`mihomo` 仍会继续吃旧的 `ss` 节点配置。
- 正确修法是：
  1. 备份 `profiles.yaml`、`profiles/RvqAWZAlhNcf.yaml`、`clash-verge.yaml`
  2. 将新订阅解码成 `anytls` 节点
  3. 用新 `anytls` 节点替换两个 YAML 的 `proxies:` 区块
  4. 保留既有：
     - `telegram-jp-tw-stable`
     - `悠兔`
     - `故障转移`
     这些路由策略不动
  5. 用 `verge-mihomo -t` 校验后再重启 `mihomo-standalone`

### AnyTLS 写法（本轮实测可用）
- `mihomo` 当前支持：
  - `type: anytls`
- 本轮写入后通过校验并恢复连通性的关键字段是：
  - `name`
  - `type: anytls`
  - `server`
  - `port`
  - `password`
  - `client-fingerprint: chrome`
  - `udp: true`
  - `sni`
  - `skip-cert-verify`

### 本轮验收结果
- 重载后经 `127.0.0.1:7897`：
  - `https://api.telegram.org` = `200`
  - `https://www.google.com/generate_204` = `204`
  - `https://api.search.brave.com` = `200`
- OpenClaw 主链路：
  - `openclaw agent --agent main` 正常返回 `TG_PROXY_REFRESH_OK`
  - Telegram `message send` 正常，`messageId=14120`

### 额外边界
- `openclaw gateway health --json` 本轮仍可能出现本地 loopback websocket `gateway closed (1000)`。
- 但只要：
  - 代理探测通过
  - `openclaw agent` 正常
  - Telegram 实发成功
  就不能把它判成“当前故障仍未修复”。

## 新发现（2026-03-17 夜）：`spark-f153` 收工断链已经在本机和 tailnet 两侧落下，但远端删文件仍未完成

### 当前已确认的安全状态
- 本机管理员 PowerShell 已成功创建两条 Windows 防火墙阻断规则：
  - `Block spark-f153 Tailscale Inbound`
  - `Block spark-f153 Tailscale Outbound`
- 规则当前都处于：
  - `Enabled = True`
  - `Action = Block`
- `tailscale status` 当前已不再列出：
  - `spark-f153`
- 用户确认已在 Tailscale `Machines` 页面删除该设备。

### 对“客户能不能再通过内网穿透回连我”的结论
- 以当前状态看，原来的这条回连路径已经被切断：
  1. 设备已从 tailnet 机器列表移除
  2. 本机防火墙已对原 `spark-f153` 的 Tailscale IP `100.74.98.13` 做入站/出站双向封禁
- 因此：
  - **该设备不能再沿用原来的 Tailscale 设备身份直接回连本机**

### 仍然存在的边界
- 当前还**不能**声称“客户机上关于你的痕迹已经全部删除”。
- 原因不是没准备清理脚本，而是：
  - `spark-f153` 当前不在线 / 不可达
  - 因此无法远端执行：
    - `spark_f153_security_cleanup_hard.sh`
- 也就是说：
  - **本机安全边界已收死**
  - **远端文件级清理仍处于待执行状态**

### 当前最准确的收尾结论
- 如果你的目标是：
  - “先保证他不能再通过原来的内网穿透路径连回我”
  当前已经做到。
- 如果你的目标还包括：
  - “把他电脑里这次维护留下的脚本、公钥、日志、Tailscale 状态也彻底抹掉”
  则必须等该机器未来再次上线、可 SSH 进入后再补跑远端硬清理。

## 新发现（2026-03-17 晚）：`spark-f153` 上“安装 Kronos”不够，必须把它抬进人格层

### 现象
- 仅仅把：
  - `kronos-skill`
  装进 `~/.openclaw/skills/...`
  并不能保证模型在预测类问题上优先想到它。
- 如果人格层没有明确偏置，模型更容易：
  - 继续只靠嘴做主观判断
  - 或把 `Kronos` 当成“知道有这么个 skill，但不主动用”

### 这次的有效做法
- 不只改 skill 可见性，还要同时改：
  - `SOUL.md`
  - `AGENTS.md`
  - `TOOLS.md`
- 最有效的提示方向不是泛泛写“你可以使用 Kronos”，而是明确写成：
  - **预测类问题优先想到 `kronos-skill`**
  - **给了 OHLCV CSV 时默认优先走 `kronos-skill`**
  - **没跑 skill 时绝不假装已经有预测结果**
  - **跑完后要把结果翻译成交易语言，而不是只丢 JSON**

### 远端已落地的关键提示块
- `SOUL.md`
  - `Kronos Instinct`
  - `Kronos Discipline`
- `AGENTS.md`
  - `Kronos Priority`
- `TOOLS.md`
  - `Kronos Skill Priority`

### 行为验收
- 注入并重启网关后，最小探测问题：
  - “预测未来 24 根 K 线该怎么做？只回答第一反应”
- 模型直接返回：
  - `kronos-skill`

### 工程结论
- 对于 `spark-f153` 这类重工作区人格的 OpenClaw：
  - **skill 安装层解决的是“能不能用”**
  - **SOUL / AGENTS / TOOLS 注入层解决的是“会不会优先想到去用”**
- 如果目标是让某个技能变成默认反射动作，就必须把它写进人格层，而不是只停留在技能层。

## 新发现（2026-03-17 晚）：`qwen3:30b` 在 `spark-f153` 上已通过 OpenClaw 实战验收

### 直接结论
- `spark-f153` 当前已经不再只是“机器上有本地模型”。
- 本轮已实际完成：
  - `qwen3:30b`
  - `qwen3-openclaw:30b`
  的下载、创建、接入和验收。
- 当前 `spark-f153` 的生产主模型已经切到：
  - `ollama/qwen3-openclaw:30b`
- fallback 保留：
  - `moonshot/kimi-k2.5`
  - `moonshot/kimi-k2-turbo-preview`
  - `moonshot/moonshot-v1-auto`

### 本轮为什么选 `qwen3:30b`
- 前一轮已经坐实：
  - `llama3.1:8b`
    在当前 OpenClaw 工作区 + 技能 + 工具环境里会误走：
    - `NO_REPLY`
    - `sessions_send`
    - JSON 结构化伪回复
- 本轮改用更强一档的：
  - `qwen3:30b`
- 实际落盘体积约：
  - `18.56 GB`
- 当前这台机子资源足够：
  - 可用内存约 `108 GiB`
  - 磁盘空闲约 `3.3 TiB`
  - GPU 为 `NVIDIA GB10`

### 本轮部署结果
- 已完成模型下载：
  - `qwen3:30b`
- 已完成 tuned 模型创建：
  - `qwen3-openclaw:30b`
- 已通过 `openclaw config validate`
- 已重启：
  - `openclaw-gateway.service`
- 当前 live 配置确认：
  - `primary = ollama/qwen3-openclaw:30b`
  - `fallbacks = [moonshot/kimi-k2.5, moonshot/kimi-k2-turbo-preview, moonshot/moonshot-v1-auto]`

### 实呼验收
- 普通最小实呼：
  - `你是谁，直接一句话回答`
  - 返回：
    - `我是 Spark 阿策，你的 A 股交易台参谋。📈`
  - 元数据：
    - `provider = ollama`
    - `model = qwen3-openclaw:30b`
- 飞书式 DM 仿真：
  - `who are you`
  - 同样返回：
    - `我是 Spark 阿策，你的 A 股交易台参谋。📈`
  - 元数据：
    - `provider = ollama`
    - `model = qwen3-openclaw:30b`

### 工程判断
- 到这里可以把结论说得很实：
  - `qwen3:30b` 这一档，已经跨过了“能跑”和“能正常给小龙虾回消息”之间的线。
- 它不是纸面可用，而是已经通过：
  - OpenClaw 主链路
  - 当前股票人格工作区
  - 当前技能集
  - 飞书式输入仿真
  的真实验收。

## 新发现（2026-03-17 傍晚）：`spark-f153` 上 `llama3.1:8b` 不适合直接挂当前 Feishu 生产链路

### 最终根因
- 本轮不是飞书断了，也不是 Gateway 挂了。
- 真正的问题是：
  - `spark-f153` 把主模型切到：
    - `ollama/llama3.1-openclaw:8b`
  - 在当前这套高强度工作区 + 多 skill + 全工具列表环境下，
    - `llama3.1:8b`
    会把正常对话误走成：
      - `sessions_send`
      - `NO_REPLY`
      - 或 JSON 结构化假回复

### 直接证据
- `Ollama` 本体和模型本身其实是好的：
  - `http://127.0.0.1:11434/api/tags` 可正常返回
  - 已安装模型：
    - `llama3.1:8b`
    - `llama3.1-openclaw:8b`
  - 直接打 `Ollama /api/chat`：
    - `Reply with exactly LOCAL_OLLAMA_OK`
    - 返回成功
- 问题出在 **OpenClaw 的生产提示环境** 里：
  - `openclaw agent --agent main --message 'Conversation info ... who are you' --json`
    在本地 LLaMA 主链路下会返回：
    - `{"name":"NO_REPLY","parameters":{}}`
- 飞书真实会话文件也抓到了更具体的坏行为：
  - 在 `who are you` / `what???? who are you` 这类正常私聊消息下
  - 模型先错误调用：
    - `sessions_send(sessionKey=<message_id>, ...)`
  - 工具返回：
    - `No session found: <message_id>`
  - 随后模型再落成：
    - `"NO_REPLY"`

### 工程判断
- 当前不是“本地模型完全不能用”。
- 更准确的说法是：
  - **`llama3.1:8b` 能直接回答简单请求**
  - **但扛不住当前这套生产 prompt / skills / tools 复杂度**
  - 因此不适合作为 `spark-f153` 这套飞书交易台的生产主模型

### 已执行回退
- 已将 `spark-f153` 的生产主模型切回：
  - `moonshot/kimi-k2.5`
- fallback 恢复为：
  - `moonshot/kimi-k2-turbo-preview`
  - `moonshot/moonshot-v1-auto`
- 本地 `Ollama` 与两份 LLaMA 模型保留，不卸载：
  - 作为后续换更强本地模型前的基础设施保留
- 同时已把被本地 LLaMA 污染的那条 Feishu 直聊 session 文件移走备份，避免继续沿用坏上下文

### 回退后的验收
- Gateway 当前主模型再次确认：
  - `provider = moonshot`
  - `model = kimi-k2.5`
- 普通最小实呼：
  - `你是谁，直接一句话回答`
  - 已正常返回文本
- 飞书式 DM 输入仿真：
  - `who are you`
  - 已正常返回文本
- 这说明：
  - 当前用户面 `NO_REPLY` 问题已经不是 live 状态
  - 生产链路已恢复到可正常答复

### 后续原则
- 后续如果继续走本地模型：
  1. 不要直接把 `llama3.1:8b` 挂到生产 Feishu 主链路
  2. 优先考虑：
     - 更强的本地模型
     - 或先缩 prompt / skills / tools 面
  3. 在没有再次通过飞书实聊验收前：
     - 本地模型只适合实验，不适合生产默认

## 新发现（2026-03-17 下午）：`spark-f153` 的桌面代理已打开，但命令行 / systemd 默认吃不到

### 直接结论
- `spark-f153` 上当前确实有本地代理在运行，不是用户错觉。
- 实测存在：
  - `clash-verge`
  - `verge-mihomo`
- 本地代理监听地址为：
  - `127.0.0.1:7897`
- GNOME 桌面代理当前也是：
  - `mode = manual`
  - `http/https/socks = 127.0.0.1:7897`

### 真正的问题
- 在本轮修复前，远端命令行会话里：
  - 没有任何 `HTTP_PROXY / HTTPS_PROXY / ALL_PROXY`
- `systemctl --user show-environment` 里也没有代理变量
- 所以表现会变成：
  - 桌面软件看起来“开了代理”
  - 但 CLI 下载、脚本下载、用户态 systemd 服务下载，依然直连或超时

### 额外发现：我之前给 Gateway 加的 no-proxy 仍然生效
- `openclaw-gateway.service` 当前仍保留：
  - `~/.config/systemd/user/openclaw-gateway.service.d/10-no-proxy.conf`
- 该 drop-in 会显式清空：
  - `HTTP_PROXY`
  - `HTTPS_PROXY`
  - `ALL_PROXY`
  - `NO_PROXY`
  - 以及小写版本
- 这意味着：
  - **OpenClaw Gateway 当前仍按“强制不走代理”运行**
  - 这和“让机器能通过代理下载 Ollama/Ollama 模型”并不冲突
  - 但不能误以为“桌面代理一开，Gateway 自己就会自动跟着走代理”

### 本轮已修复
- 新增脚本：
  - `spark_f153_fix_proxy_env.sh`
- 修复动作包括：
  1. 自动检测桌面代理设置
  2. 确认并采用：
     - `http://127.0.0.1:7897`
  3. 写入持久化代理环境文件：
     - `~/.config/environment.d/90-proxy.conf`
     - `~/.config/openclaw/proxy.env`
     - `~/.proxy.env`
  4. 将 `~/.bashrc` / `~/.profile` 挂到 `~/.proxy.env`
  5. 通过 `systemctl --user import-environment` 把代理变量导入 user manager

### 本轮验证结果
- 修复后当前 shell 环境已有：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
  - `ALL_PROXY=http://127.0.0.1:7897`
- 修复后当前 `systemd --user` 环境也已有同样变量
- 连通性测试结果：
  - `https://ollama.com/download/ollama-linux-arm64.tar.zst -> http=200`
  - `https://github.com/ollama/ollama/releases/download/v0.18.0/ollama-linux-arm64.tar.zst -> http=200`
  - 关键证据：
    - `remote_ip=127.0.0.1`
- 这说明：
  - 下载流量已经命中本地代理
  - 不再是直连外网

### 同轮追加：本地 Llama 安装脚本已改为“代理感知”
- `spark_f153_enable_local_llama_openclaw.sh` 本轮也已同步修正：
  - 启动时若存在：
    - `~/.config/openclaw/proxy.env`
    就自动 `source`
  - 新创建的 `ollama-user.service` 现在会加载：
    - `EnvironmentFile=-%h/.config/openclaw/proxy.env`
- 同时移除了之前那组会把代理变量强行清空的 `Environment=HTTP_PROXY=` 等配置
- 含义：
  - 后续 `Ollama` 本体下载模型时，也会走同一套代理

## 新发现（2026-03-17 下午）：`spark-f153` 已切到“直连国内网 + Kimi 主链路”

### 直接结论
- `spark-f153` 这台客户机当前已经不再依赖代理/节点来走模型回复。
- 本轮实际复核到：
  - `openclaw-gateway.service` 主 service 文件本身**没有**代理环境变量
  - `~/.openclaw/.env` 当前只保留：
    - `MOONSHOT_API_KEY`
- 为了把边界收死，本轮又额外加了 systemd drop-in：
  - `~/.config/systemd/user/openclaw-gateway.service.d/10-no-proxy.conf`
  - 用 `UnsetEnvironment=` + 空值 `Environment=` 明确清掉：
    - `HTTP_PROXY`
    - `HTTPS_PROXY`
    - `ALL_PROXY`
    - `NO_PROXY`
    - 及其小写版本

### 当前 live 模型配置
- 本轮前：
  - `primary = moonshot/moonshot-v1-128k`
  - `fallbacks = [moonshot/moonshot-v1-auto]`
- 本轮后：
  - `primary = moonshot/kimi-k2.5`
  - `fallbacks = [moonshot/kimi-k2-turbo-preview, moonshot/moonshot-v1-auto]`
- 图像模型保持不变：
  - `moonshot/moonshot-v1-128k-vision-preview`

### provider 层实际修改
- 继续沿用：
  - `provider = moonshot`
  - `baseUrl = https://api.moonshot.cn/v1`
  - `apiKey = ${MOONSHOT_API_KEY}`
- 本轮新增 provider 模型定义：
  - `kimi-k2.5`
  - `kimi-k2-turbo-preview`
- 这样做的含义是：
  - **不是切到“海外代理模型链”**
  - 而是继续用客户自己的 Kimi API 平台 key
  - 直接从客户机本机走国内网络访问官方 API

### 无代理直连验证
- 本轮专门在远端 Python 进程里显式清空：
  - `HTTP_PROXY`
  - `HTTPS_PROXY`
  - `ALL_PROXY`
  - `NO_PROXY`
  - 以及对应小写变量
- 在这个“无代理环境”下重新直打官方 API：
  - `GET /v1/models -> 200`
  - 返回列表包含：
    - `kimi-k2.5`
    - `moonshot-v1-auto`
- 继续直打：
  - `POST /v1/chat/completions`
  - `model = kimi-k2.5`
- 返回：
  - `chat_http=200`
  - `reply=DIRECT_KIMI_OK`

### Gateway 级验收
- 重启 `openclaw-gateway.service` 后当前状态：
  - `ActiveState=active`
  - `SubState=running`
  - `ExecMainStartTimestamp=2026-03-17 15:17:11 CST`
- `openclaw channels status --probe` 仍返回：
  - `Feishu stock-desk ... running, works`
- `openclaw agent --agent main --message '只回复 DIRECT_GATEWAY_KIMI_OK' --json`
  已成功返回：
  - `payload = DIRECT_GATEWAY_KIMI_OK`
  - `provider = moonshot`
  - `model = kimi-k2.5`

### 当前判断
- 现在 `spark-f153` 上的小龙虾已经满足：
  - **飞书入口保留**
  - **模型主链路改成 Kimi**
  - **运行时强制不走代理环境**
  - **本机直连 Kimi 官方 API 可用**
- 如果后续飞书仍偶发“不回消息”，优先怀疑：
  - Feishu 会话派发链路
  - 而不是模型余额、代理、或 Kimi 官方 API 连通性

### 同轮追加：飞书“不回消息”的更精确根因
- 本轮继续深挖后确认：
  - 不是飞书没收到
  - 不是飞书发不出去
  - 也不是 Kimi API 不可达
- 真实现象是：
  - 用户发 `hi`、`1111`、`11111` 这种低信息量测试消息时
  - Feishu 会话对应的 session 文件里，模型**真的返回了**：
    - `NO_REPLY`
- 对应证据：
  - session 文件：
    - `/home/admin/.openclaw/agents/main/sessions/a0b90a34-05df-4d72-9191-669d54cf63e3.jsonl`
  - `hi` / `11111` 的 assistant message 内容都是：
    - `NO_REPLY`
  - 日志对应表现为：
    - `dispatch complete (queuedFinal=false, replies=0)`
- 但当用户发正常问题时，例如：
  - `who are you`
  - `/status`
  日志会变成：
  - `dispatch complete (queuedFinal=true, replies=1)`
- 这说明：
  - 当前“不回消息”是**提示词/会话行为层**主动静默
  - 不是飞书连接层故障

### 同轮追加：飞书 typing indicator 已打开
- 已修改：
  - `channels.feishu.typingIndicator = true`
  - `channels.feishu.accounts.stock-desk.typingIndicator = true`
- 已重启 `openclaw-gateway.service`
- 当前网关状态：
  - `active/running`
  - Feishu probe：
    - `running, works`

### 同轮追加：本地 zip 技能已装入 `spark-f153`
- 用户提供的两个本地 zip：
  - `feishu-file-uploader.zip`
  - `skills-bundle.zip`
  已投递到远端并安装到：
  - `~/.openclaw/skills/skills/`
  - `~/.openclaw/skills/selected/skills/`
- 其中 `feishu-file-uploader` 当前已确认存在于：
  - `~/.openclaw/skills/skills/feishu-file-uploader`
  - `~/.openclaw/skills/selected/skills/feishu-file-uploader`
- 重置主会话缓存后再次实呼，当前 `systemPromptReport.skills.entries` 已明确包含：
  - `feishu-file-uploader`
- 结论：
  - 这次不是“文件落盘但运行时没吃到”
  - 技能已经进入 OpenClaw 的运行时技能列表

### 同轮追加：`NO_REPLY` 逻辑已被掰掉
- 本轮没有去追源码里的某个隐藏开关，而是直接从**工作区行为规则**入手收口：
  - `AGENTS.md` 新增 `Direct Chat Rules`
  - `HEARTBEAT.md` 新增 `Human Chat Override`
- 新规则明确要求：
  - 飞书一对一私聊里，不能对真人用户输出 `NO_REPLY`
  - 也不能把 `HEARTBEAT_OK` 当成用户可见回复
  - 对 `hi / hello / 在吗 / 测试 / 1111` 等短消息，也必须回一句短确认
- 同时已重置该 Feishu 直聊会话缓存，避免继续沿用旧的 session 行为。
- 重置后再做最小实呼，当前面对“用户只发 hi”的场景，模型给出的最终回复已经变成：
  - `在。直接说票、持仓或问题。📈`

## 新发现（2026-03-17 中午）：另外三个小龙虾已切到 `minimax/MiniMax-M2.5`，主实例未动

### 切换前的真实状态
- 当前四套实例在本轮操作前都不是“只有 main 在跑 Sonnet 4.6”。
- 实际读取远端 live 配置后确认：
  - `main = newcli/claude-sonnet-4-6`
  - `dayong = newcli/claude-sonnet-4-6`
  - `chunyan = newcli/claude-sonnet-4-6`
  - `zenglan = newcli/claude-sonnet-4-6`
- 所以用户这次判断是对的：
  - 另外三个当前**确实不是** `MiniMax-M2.5`

### 一个关键细节：三套非主实例不能只改 `primary`
- 本轮先查 live 配置后确认：
  - `dayong/chunyan/zenglan` 三套各自的 `.env` 里都**没有** `MINIMAX_API_KEY`
  - `dayong/chunyan/zenglan` 的 `openclaw.json` 默认主模型都还是：
    - `newcli/claude-sonnet-4-6`
  - agent 层 `models.json` 的 provider 状态并不一致：
    - `dayong` 已有 `minimax`，但不是当前主实例对齐版
    - `chunyan` / `zenglan` 还没有 `minimax`
- 结论：
  - 这次如果只改：
    - `agents.defaults.model.primary = minimax/MiniMax-M2.5`
  - 会得到“模型名改了，但 provider / token 不完整”的半成品配置

### 本轮实际修改面
- 本轮**只改**：
  - `~/.openclaw-dayong/*`
  - `~/.openclaw-chunyan/*`
  - `~/.openclaw-zenglan/*`
- 本轮**没有改**：
  - `~/.openclaw/*`
  - `openclaw-gateway.service`

#### 1. 三套 `openclaw.json`
- 都已补齐主实例同版 `models.providers.minimax`
- 都已改成：
  - `agents.defaults.model.primary = minimax/MiniMax-M2.5`
  - `agents.defaults.model.fallbacks = []`

#### 2. 三个 agent 的 `models.json`
- 都已补齐主实例同版 `providers.minimax`
- 统一使用：
  - `apiKey = MINIMAX_API_KEY`

#### 3. 三套 `.env`
- 都已补入：
  - `MINIMAX_API_KEY`
- 本轮做法是从主实例 `.env` 中读取现有 `MINIMAX_API_KEY`，再写入三套各自独立 `.env`

### 备份记录
- 三套 `openclaw.json`
- 三套 `.env`
- 三个 agent 的 `models.json`
- 统一备份后缀：
  - `.pre-minimax-m25-20260317-120429`

### 校验结果
- 三套静态校验全部通过：
  - `Config valid: ~/.openclaw-dayong/openclaw.json`
  - `Config valid: ~/.openclaw-chunyan/openclaw.json`
  - `Config valid: ~/.openclaw-zenglan/openclaw.json`

### 重启结果
- 本轮只重启了：
  - `openclaw-gateway-dayong.service`
  - `openclaw-gateway-chunyan.service`
  - `openclaw-gateway-zenglan.service`
- 三套当前统一启动时间：
  - `2026-03-17 12:05:04 CST`

### 实呼验收
- 三套 embedded / gateway 实呼都返回成功，且元数据明确显示：
  - `dayong`: `provider = minimax`, `model = MiniMax-M2.5`
  - `chunyan`: `provider = minimax`, `model = MiniMax-M2.5`
  - `zenglan`: `provider = minimax`, `model = MiniMax-M2.5`
- 返回文本分别为：
  - `DAYONG_MINIMAX_OK`
  - `CHUNYAN_MINIMAX_OK`
  - `ZENGLAN_MINIMAX_OK`

### 主实例未动的验证
- `main` 当前仍是：
  - `newcli/claude-sonnet-4-6`
- `openclaw-gateway.service` 当前启动时间仍是：
  - `Mon 2026-03-16 10:00:59 CST`
- 说明：
  - 本轮没有重启主实例
  - 本轮没有把主实例切到 MiniMax

### 一个附带发现：普通 SSH 当前超时，但 `tailscale ssh` 可用
- 本轮通过普通：
  - `ssh kevinlasnh@100.64.65.65`
  - `ping 100.64.65.65`
  - `tailscale ping 100.64.65.65`
  都超时
- 但：
  - `tailscale ssh kevinlasnh@openclaw-24x7`
  仍能正常进入
- 这说明当前又出现了典型的：
  - **控制面看着 active，但普通数据面不通**
- 本轮因此改用 `tailscale ssh` 完成全部变更和验收。

## 新发现（2026-03-17 中午第四轮）：`spark-f153` 模型链路的最终根因

### 结论纠偏
- 前三轮排查曾一度怀疑：
  - `MOONSHOT_API_KEY` 无效
- 但继续把密钥来源彻底理顺后，最终确认：
  - 客户机原先把 key 存在 `openclaw.json` 的 `env` 块里
  - 本轮已将其收口到：
    - `~/.openclaw/.env`
    - systemd `EnvironmentFile=%h/.openclaw/.env`
- 在这个干净结构下重新直打官方 API，结果是：
  - `GET /v1/models -> 200`
  - 说明 **key 本身是有效的**
- 继续直打三条最小聊天请求：
  - `moonshot-v1-128k`
  - `moonshot-v1-auto`
  - `kimi-k2.5`
  都返回：
  - `http=429`
  - `type=exceeded_current_quota_error`
  - `suspended due to insufficient balance`
- 因此当前最终根因已经可以定死：
  - **不是无效 key**
  - **也不是模型 ID 配错**
  - 而是客户 Moonshot 账号余额不足 / 配额耗尽，账号被 suspend**

### 关键证据
- 当前真实密钥来源已经确认是：
  - 原先：`~/.openclaw/openclaw.json -> env.MOONSHOT_API_KEY`
  - 现在：`~/.openclaw/.env -> MOONSHOT_API_KEY`
- provider 配置仍是：
  - `apiKey = ${MOONSHOT_API_KEY}`
- 当前上游直测结果：
  - `GET https://api.moonshot.cn/v1/models -> 200`
  - `POST /v1/chat/completions` 对 `moonshot-v1-128k` -> `429`
  - `POST /v1/chat/completions` 对 `moonshot-v1-auto` -> `429`
  - `POST /v1/chat/completions` 对 `kimi-k2.5` -> `429`
- 三个模型返回体核心文案一致：
  - `suspended due to insufficient balance`
- 所以：
  - 这不是 OpenClaw 选错模型导致的
  - 也不是 fallback 链顺序问题
  - 更不是“只有某一个模型不行”
  - 而是**整条 Moonshot/Kimi 账号余额链路已经被官方停用**

### 为什么 OpenClaw 里看到的是 `rate_limit`
- 当前现象是：
  - OpenClaw 运行时把这类失败表面归类成：
    - `rate_limit`
    - `All models failed (2)`
- 但上游直测已经证明：
  - 真实更接近：
    - `429 exceeded_current_quota_error`
    - `insufficient balance`
- 当前工程判断：
  - OpenClaw 在这条 provider 错误路径上的错误映射并不精确
  - 运维上应优先相信：
    - **上游 API 直测结果**
  - 不应只看 OpenClaw 表层文案

### 当前真正的修复方向
- 现在要修通模型链路，正确动作有两种：
  1. **最优**：客户直接给当前 Moonshot 账号充值 / 恢复余额
  2. **次优**：客户提供一把新的、已确认有余额可用的 key
- 无论走哪种，后续固定流程都应是：
  1. 先用官方 `/v1/models` 验 key 是否有效
  2. 再直测 `moonshot-v1-128k` / `moonshot-v1-auto`
  3. 通过后再回到 OpenClaw 实呼
- 在余额恢复之前，继续调 prompt、Feishu、人格都没有意义。

## 新发现（2026-03-17 上午）：`spark-f153` 现状复核

### 直接结论
- `spark-f153` 目前**还能继续维护**：
  - Tailscale IP 仍为 `100.74.98.13`
  - 本机经 Tailscale + SSH 仍可直连
- 当前阻断点已经**不再是**：
  - Tailscale 没装
  - SSH 公钥没写进去
  - `openclaw.json` 损坏
  - Feishu 插件没接好
- 当前新的主阻断点是：
  - **客户机自己的 Moonshot/Kimi API key 触发了 `rate_limit`**
  - 现在主模型和 fallback 模型都会一起失败

### 连通性与维护入口现状
- 本机 `tailscale ping 100.74.98.13` 当前可达。
- 本机 `ssh admin@100.74.98.13` 当前可成功登录。
- 这说明：
  - 远端仍在用户 tailnet 中
  - 远端 `authorized_keys` 里本机维护公钥仍然有效
  - **安全收工脚本尚未执行**
- 当前链路仍主要表现为：
  - `desktop-jrvidlh <-> spark-f153`
  - 通过 Tailscale relay `hkg`
- 结论：
  - 能维护
  - 但不是理想的 direct path，体感会比直连慢

### Gateway 运行态现状
- `openclaw-gateway` 当前：
  - `ActiveState=active`
  - `SubState=running`
  - `UnitFileState=enabled`
  - `ExecMainStartTimestamp=2026-03-16 23:34:49 CST`
  - `NRestarts=0`
- 说明：
  - 昨晚修完后的这段时间里，Gateway 没有再次进入“疯狂重启”状态
  - 当前不是 service 崩了，而是**服务活着，但模型层请求失败**

### 当前配置仍保持昨晚落地结果
- `~/.openclaw/openclaw.json` 当前关键摘要仍是：
  - `providers = moonshot`
  - `primary = moonshot/moonshot-v1-128k`
  - `fallbacks = [moonshot/moonshot-v1-auto]`
  - `image_primary = moonshot/moonshot-v1-128k-vision-preview`
  - `feishu.enabled = true`
  - `plugins.entries = feishu`
- 说明昨晚写进去的主配置没有被覆盖回退。
- 本轮已顺手把密钥存放方式收口：
  - 不再继续把 `MOONSHOT_API_KEY` 留在 `openclaw.json` 的 `env` 块里
  - 已改成：
    - `~/.openclaw/.env`
    - systemd `EnvironmentFile=%h/.openclaw/.env`

### 工作区人格文件仍在
- `~/.openclaw/workspace/` 里的股票人格文件当前都还在，时间戳保持在 `2026-03-16 22:14`：
  - `BOOTSTRAP.md`
  - `IDENTITY.md`
  - `USER.md`
  - `SOUL.md`
  - `AGENTS.md`
  - `TOOLS.md`
  - `HEARTBEAT.md`
  - `SKPARK.md`
  - `WATCHLIST.md`
  - `TRADING_JOURNAL.md`
- 同时保留了原始工作区备份目录：
  - `~/.openclaw/workspace/.stock-persona-backup-20260316_221436/`
- 结论：
  - “炒股味”的 Markdown 注入没有丢
  - 可继续在这套人格基础上迭代，而不是重做一遍

### Feishu 侧现状
- `openclaw channels status --probe` 当前结果仍显示：
  - `Feishu stock-desk (Spark Stock Desk): enabled, configured, running, works`
- 但 `openclaw gateway health --json` 同时仍显示：
  - `feishu.running = false`
  - `probe.ok = true`
- 这和上一轮观察一致：
  - 对飞书通道“能不能连上平台”的判断，`channels status --probe` 依然比 `gateway health` 更可信
- `2026-03-17 14:54:49 CST` 本轮又抓到了一次**真实飞书入站**：
  - `received message`
  - `DM ...: 111`
  - `dispatching to agent`
- 结论可以进一步收窄为：
  - **飞书连接正常**
  - **消息能进到小龙虾**
  - 当前卡住的是模型出站回复，不是飞书入站

### 当前真正的用户面故障
- 现在一旦实际跑 agent，请求会在模型层失败。
- OpenClaw 表面日志显示为：
  - `moonshot/moonshot-v1-128k -> rate_limit`
  - `moonshot/moonshot-v1-auto -> rate_limit`
- 但第四轮上游直测已经证明：
  - `/v1/models = 200`
  - 真正失败的是：
    - `429 exceeded_current_quota_error`
    - `suspended due to insufficient balance`
- 因此当前更准确的结论是：
  - 当前“飞书 probe 正常”不等于“客户发消息就一定能收到正常回复”
  - 通道是通的，但**客户 Moonshot 余额不足，导致业务回复卡死**

### 当前保留的非阻断噪声
- 日志里仍会出现：
  - `tools.profile (coding) allowlist contains unknown entries (apply_patch, memory_search, memory_get[, cron])`
- 当前判断：
  - 这是运行时能力集与 allowlist 描述不完全一致的警告
  - 不是这次客户机主故障的根因
  - 可记为次级清理项，不应抢在 `rate_limit` 前面处理

## 新发现（2026-03-17 上午第二轮）：`spark-f153` 当前问题分级

### P1 阻断：模型链路真实不可用
- 当前直接通过：
  - `openclaw agent --agent main ...`
  实测时，会稳定返回：
  - `All models failed (2)`
  - `moonshot/moonshot-v1-128k -> rate_limit`
  - `moonshot/moonshot-v1-auto -> rate_limit`
- `journalctl --user -u openclaw-gateway` 最近时间窗也连续记录相同错误。
- 这说明：
  - 现在不是“偶发一次失败”
  - 而是当前默认主链路处于**稳定不可回复**状态
- 但第三轮上游直测后，需要把这条再收窄：
  - **真正的上游根因是当前 Moonshot 账号余额不足**
  - OpenClaw 只是把它表面显示成了 `rate_limit`

### P2 问题：Feishu 配置里仍混有一个“default”伪账号
- 当前 `channels.feishu.accounts` 下有两个账号：
  - `stock-desk`
  - `default`
- 其中真实可用的是：
  - `stock-desk`
- `default` 当前特征：
  - `appId_present=False`
  - `appSecret_present=False`
  - `groupPolicy=allowlist`
  - `allowFrom_count=0`
  - `groupAllowFrom_count=0`
- 这会导致：
  - CLI / doctor 持续报 warning
  - 若未来错误命中 `default` 或误以为它能接群消息，相关消息会被静默丢弃
- 当前判断：
  - 对现有 `stock-desk` 直聊不是主阻断
  - 但它是一个明确的脏配置项，应该收掉

### P2 问题：当前密钥注入方式不透明，维护性偏差
- `~/.openclaw/openclaw.json` 当前 provider 写法是：
  - `apiKey = ${MOONSHOT_API_KEY}`
- 但远端当前：
  - 没有找到 `~/.openclaw/.env`
  - 当前实际密钥是直接保存在：
    - `~/.openclaw/openclaw.json` 顶层 `MOONSHOT_API_KEY`
  - provider 再通过 `${MOONSHOT_API_KEY}` 引用它
- 工程含义：
  - 运行时密钥并不是走一个干净的 `.env` 文件
  - 而是把密钥和主配置混在同一个 JSON 里
- 这不一定导致当前故障，但会带来：
  - 旋转密钥时不直观
  - 脚本化维护困难
  - 容易把敏感信息和业务配置一起误备份 / 误传播
- 本轮已处理：
  - `MOONSHOT_API_KEY` 已迁移到 `~/.openclaw/.env`
  - `openclaw-gateway.service` 已挂上 `EnvironmentFile=%h/.openclaw/.env`
  - 这个结构性脏点现已基本消除

### P3 噪声：Feishu 运行态在两套探针里不一致
- `openclaw channels status --probe`：
  - `stock-desk = works`
- `openclaw gateway health --json`：
  - `feishu.running = false`
  - `lastStartAt = null`
- 当前判断：
  - 这更像状态汇总口径问题，而不是链路真坏
  - 目前应优先相信 `channels status --probe`
  - 但这会影响后续运维判断，属于中低优先级清理项

### P3 噪声：coding tools allowlist 与运行时能力集不一致
- 当前日志里持续出现：
  - `apply_patch`
  - `memory_search`
  - `memory_get`
  - 有时还包括 `cron`
- 当前判断：
  - 不会单独导致主聊天失败
  - 但表明这台客户机上的 coding profile 有“声明的工具 > 当前 runtime 可提供工具”的偏差
  - 如果后续要把它继续往“能写代码 / 能做复杂操作”方向扩展，这块迟早要收拾

## 新发现（2026-03-16 夜）：`spark-f153` 客户版炒股小龙虾已落地

### 直接结论
- 本轮**没有**把用户自己机器上的模型 API key 搬到客户机。
- 客户机使用的是其**自己的** Kimi API 平台 key。
- 最终稳定接法不是本地 Ollama，也不是 `kimi-coding`，而是：
  - provider：`moonshot`
  - baseUrl：`https://api.moonshot.cn/v1`
  - api：`openai-completions`
  - 主模型：`moonshot-v1-128k`
  - 图像模型：`moonshot-v1-128k-vision-preview`
- Feishu 通道已经配通，工作区 Markdown 也已重写成 A 股交易台人格。

### 这把客户 key 的实际可用模型
- 直接调用官方：
  - `GET https://api.moonshot.cn/v1/models`
- 本轮实测列出的核心模型包括：
  - `moonshot-v1-8k`
  - `moonshot-v1-32k`
  - `moonshot-v1-128k`
  - `moonshot-v1-auto`
  - `kimi-k2.5`
  - `kimi-k2-thinking`
  - `kimi-k2-thinking-turbo`
  - 若干 `vision-preview`

### 一个关键坑：`kimi-latest` 对这把 key 不可用
- 直接调用：
  - `POST /v1/chat/completions`
  - `model = kimi-latest`
- 返回：
  - `Not found the model kimi-latest or Permission denied`
- 结论：
  - 不应假设“官方文档里提到的 `kimi-latest` 一定对所有 key 开放”
  - 对接时应优先以该 key 自己的 `/v1/models` 返回结果为准

### 为什么没有把默认主模型设成 `kimi-k2.5`
- 这把 key 对 `kimi-k2.5` 的直接请求能成功。
- 但实测当请求带：
  - `temperature = 0`
- Moonshot 会返回：
  - `invalid temperature: only 1 is allowed for this model`
- OpenClaw 内部存在若干会显式传 `temperature=0` 或 `0.3` 的路径（例如模型探测/部分内部调用）。
- 结论：
  - `kimi-k2.5` 适合手工直调
  - 但在当前 OpenClaw 这版里，不适合作为“默认稳定主模型”

### 为什么最终选 `moonshot-v1-128k`
- `moonshot-v1-auto` 直接实测是通的。
- 但短请求下它会落到：
  - `moonshot-v1-8k`
- 而这次注入后的工作区人格 prompt 已经接近：
  - `~8k prompt tokens`
- 如果继续把默认主模型放在 `auto`，后续真实聊天很容易贴着 8k 上限走，风险太高。
- `moonshot-v1-128k` 直接实测：
  - 支持常规 `temperature=0`
  - 上下文空间充足
  - 更适合这类“重人格 + 重工作区注入”的客户机配置

### 工作区人格改造结果
- 远端工作区已重写：
  - `BOOTSTRAP.md`
  - `IDENTITY.md`
  - `USER.md`
  - `SOUL.md`
  - `AGENTS.md`
  - `TOOLS.md`
  - `HEARTBEAT.md`
- 新增：
  - `SKPARK.md`
  - `WATCHLIST.md`
  - `TRADING_JOURNAL.md`
- 其中 `SKPARK` 被定义为一套内置投研框架，而不是外部真实插件：
  - `S = Structure`
  - `K = Kapital`
  - `P = Position`
  - `A = Action`
  - `R = Risk`
  - `K = Kill Switch`

### Feishu 侧验证
- 当前通道：
  - `stock-desk`
- `openclaw channels status --probe` 当前结果：
  - `enabled`
  - `configured`
  - `running`
  - `works`
- `gateway health --json` 虽然仍显示 `feishu.running=false`，但 probe 是 `ok=true`。
- 当前更可信的运行态判断应优先参考：
  - `openclaw channels status --probe`

### 实际人格实呼结果
- 远端 `openclaw agent --agent main` 已成功返回：
  - `STOCK_MAIN_OK`
  - `STOCK_128K_OK`
- 实际股票口吻抽样已经出现预期语气，例如：
  - “这不是不能做，是盈亏比不够漂亮。”
  - “强的是板块，不一定是你手里这只。”
- 当前可判定：
  - 人格注入已经生效
  - 模型链路已经恢复
  - 飞书通道已经可用

## 新发现（2026-03-16）：`newcli/claude-sonnet-4-6` 现有配置定位

### 直接结论
- 用户记忆中的 `newcli` Sonnet 4.6 配置**确实存在**。
- 但它目前不是“四个 Gateway 都已经能直接切换”的状态。
- 当前真实状态是：
  - **只有 `main` 拥有完整的 `newcli` provider**
  - **另外三个实例当前只有 Kimi provider，没有 `newcli`**

### 已定位到的关键信息
- provider 名：
  - `newcli`
- baseUrl：
  - `https://code.newcli.com/claude`
- 已登记模型：
  - `claude-sonnet-4-6`
  - `claude-opus-4-6`

### 当前生效面分布

#### 1. main
- `~/.openclaw/openclaw.json`
  - `models.providers.newcli` 已存在
  - `agents.defaults.imageModel.primary = newcli/claude-sonnet-4-6`
  - `agents.defaults.models` 已包含：
    - `newcli/claude-sonnet-4-6`
    - `newcli/claude-opus-4-6`
- `~/.openclaw/agents/main/agent/models.json`
  - 仍保留 `newcli` 的完整 provider 定义
  - 当前 `newcli` 的可用密钥实际留在这里

#### 2. dayong / chunyan / zenglan
- 当前三个实例的 `openclaw.json`
  - `models.providers` 只有 `kimi`
- 当前三个实例各自的 `agents/*/agent/models.json`
  - 也都没有 `newcli`
- 结论：
  - 这三个实例现在还不具备“只改主模型字符串就切到 `newcli/claude-sonnet-4-6`”的条件

### 密钥存放方式的现状
- `main` 当前 `.env` 键名里**没有** `NEWCLI_API_KEY`
- `main` 的 `openclaw.json` 使用的是：
  - `${NEWCLI_API_KEY}`
- 但当前能让 `newcli` provider 真正可用的凭据，实际仍滞留在：
  - `~/.openclaw/agents/main/agent/models.json`
- 这说明当前 `newcli` 配置存在“声明层想走 env、实际可用凭据却落在 agent 本地 models.json”的分裂状态。

### 历史配置结论
- 主实例历史 `openclaw.json*` 备份显示：
  - `newcli/claude-sonnet-4-6` 以前明确被配置过
  - 但本轮定位到的稳定证据是：
    - 它被用作 `imageModel.primary`
- 本轮未发现：
  - 四个 Gateway 曾统一把文本主模型长期切到 `newcli/claude-sonnet-4-6`

### 工程含义
- 如果用户下一步要把四个小龙虾统一切到 `newcli/claude-sonnet-4-6`，正确顺序应是：
  1. 先统一 `NEWCLI_API_KEY` 的存放方式
  2. 给 `dayong/chunyan/zenglan` 补齐 `newcli` provider
  3. 再改四套 `agents.defaults.model.primary`
- 不建议直接在三个缺 provider 的实例上只改：
  - `primary = newcli/claude-sonnet-4-6`
- 否则会得到“模型名存在于目标字符串里，但 provider 根本没定义”的不完整配置。

### 本轮实际落地结果（2026-03-16 上午）
- 上述方案已经按原顺序执行完毕。
- 现在四个 Gateway 的统一状态是：
  - `primary = newcli/claude-sonnet-4-6`
  - `fallbacks = []`
  - provider = `newcli`
  - baseUrl = `https://code.newcli.com/claude`

### 本轮实际修改面

#### 1. 四套 `.env`
- 都已补齐 `NEWCLI_API_KEY`
- 四套路径：
  - `~/.openclaw/.env`
  - `~/.openclaw-dayong/.env`
  - `~/.openclaw-chunyan/.env`
  - `~/.openclaw-zenglan/.env`

#### 2. 四套 `openclaw.json`
- 都已确保 `models.providers.newcli` 存在
- 都已将：
  - `agents.defaults.model.primary = newcli/claude-sonnet-4-6`
  - `agents.defaults.model.fallbacks = []`

#### 3. 四个 agent 的 `models.json`
- 都已补齐 `newcli` provider
- `apiKey` 统一改为环境变量名：
  - `NEWCLI_API_KEY`

### 验证结果

#### 切换前嵌入式实呼
- 四套都已通过，且返回元数据明确显示：
  - `provider = newcli`
  - `model = claude-sonnet-4-6`

#### 重启后 Gateway 级验证
- 四个 Gateway 的 `gateway health --json` 全部 `ok=true`
- 四个 Gateway 的实际 agent 请求也都返回：
  - `provider = newcli`
  - `model = claude-sonnet-4-6`
- 因此可以确认：
  - 不是只有本地 embedded 模式成功
  - Gateway 重启后也确实已经在跑 Sonnet 4.6

### 重启结果
- 四个 systemd 用户服务统一重启成功：
  - `openclaw-gateway`
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
- 当前统一启动时间：
  - `2026-03-16 09:47:48 CST`

### 备份记录
- 本轮所有配置备份统一使用后缀：
  - `.pre-sonnet46-20260316-094510`
- 覆盖范围包括：
  - 四套 `openclaw.json`
  - 四套 `.env`
  - 四个 agent 的 `models.json`

### 本轮一个小插曲
- 第一次远端写配置时，PowerShell here-doc 末尾引号处理不干净，导致脚本在已经打印 `UPDATED` 后又多执行了一段壳层垃圾，最终报：
  - `NameError: name 'PY' is not defined`
- 之后已立即做只读核对，确认文件改动本身已经落盘，没有发生半写入或 JSON 损坏。
- 后续验证步骤改用：
  - `tailscale ssh ... 'python3 -'`
  的管道方式，后续命令均正常。

## 新发现（2026-03-16 上午）：`/status` 仍显示 `256K/262144` 的真实根因

### 直接结论
- 如果用户在某些旧聊天会话里看到 `/status` 仍显示：
  - `256K`
  - `262144`
- 根因**不是**这次 Sonnet 4.6 的 provider 或 `contextWindow` 没改成功。
- 真正根因是：
  - **旧会话索引 `sessions.json` 里还残留了 Kimi 时代的会话元数据**
  - `/status` 会优先读这些残留字段

### 代码级证据
- OpenClaw 当前版本的 `/status` 实现里：
  - 会优先读取 `entry.contextTokens`
  - 同时也会读取 `entry.modelProvider` / `entry.model`
- 对应文件：
  - `/usr/lib/node_modules/openclaw/dist/discord-CcCLMjHw.js`
- 关键逻辑是：
  - `contextTokensOverride: entry?.contextTokens ?? args.agent?.contextTokens`
- 也就是说：
  - 只要旧会话条目里还保留 `contextTokens=256000/262144`
  - `/status` 就可能继续显示旧上下文窗口

### 实际残留位置
- 四套会话索引里都发现了旧字段：
  - `~/.openclaw/agents/main/sessions/sessions.json`
  - `~/.openclaw-dayong/agents/dayong/sessions/sessions.json`
  - `~/.openclaw-chunyan/agents/chunyan/sessions/sessions.json`
  - `~/.openclaw-zenglan/agents/zenglan/sessions/sessions.json`
- 典型残留字段：
  - `modelProvider = kimi`
  - `model = k2p5`
  - `contextTokens = 256000` 或 `262144`
- 其中主用户直聊会话也确实命中：
  - `agent:main:telegram:main-bot:direct:8226087994`

### 修复方式
- 本轮没有去改 inactive Kimi provider 的模型参数。
- 真正修的是：
  - 四套 `sessions.json` 里的旧会话元数据缓存
- 对所有残留旧值的会话条目，统一删除：
  - `contextTokens`
  - `modelProvider`
  - `model`
- 这样 `/status` 下一次就会回退到：
  - 当前选择的 `newcli/claude-sonnet-4-6`
  - 当前 provider 的 `contextWindow = 200000`

### 修复后结果
- 四套 `sessions.json` 当前都已确认：
  - `stale_count = 0`
- 四个 Gateway 再次重启后，重新复核 `/status`：
  - `main`：`44k/200k`
  - `dayong`：`29k/200k`
  - `chunyan`：`23k/200k`
  - `zenglan`：`21k/200k`
- 因此可以确认：
  - 这次用户看到的 `256K` 已经被清掉

### 备份记录
- 四套会话索引备份后缀统一为：
  - `.pre-status-sonnet-refresh-20260316-100041`

## 新发现（2026-03-16 上午）：Sonnet 4.6 参数全量审计 + 四 Gateway 全面复核

### Sonnet 4.6 参数审计结论
- 当前四个 Gateway 的 `newcli/claude-sonnet-4-6` 主模型配置已经全部对齐。
- 审计范围覆盖：
  - 四套 `openclaw.json`
  - 四套 `.env`
  - 四个 agent 的 `models.json`

### 当前统一参数
- `provider`: `newcli`
- `baseUrl`: `https://code.newcli.com/claude`
- `api`: `anthropic-messages`
- `apiKey`：
  - root 配置：`${NEWCLI_API_KEY}`
  - agent 配置：`NEWCLI_API_KEY`
- `primary`: `newcli/claude-sonnet-4-6`
- `fallbacks`: `[]`
- `claude-sonnet-4-6`：
  - `name`: `Claude Sonnet 4.6`
  - `reasoning`: `false`
  - `input`: `["text", "image"]`
  - `cost`: `{input: 0, output: 0}`
  - `contextWindow`: `200000`
  - `maxTokens`: `8192`
- `claude-opus-4-6`：
  - 同样已保持一致，作为已登记模型存在，但当前不参与 fallback

### 一处已修正的小差异
- `chunyan` 的 agent 级 `models.json` 里，最初 Sonnet/Opus 的 `cost` 多了两个零值字段：
  - `cacheRead`
  - `cacheWrite`
- 这不影响功能，但为保证四套参数完全对齐，本轮已归一化删除。
- 备份文件：
  - `~/.openclaw-chunyan/agents/chunyan/agent/models.json.pre-sonnet-audit-normalize-20260316-100800`
- `chunyan` 已在修正后单独重启并回归成功。

### 四 Gateway 当前健康结论
- 当前四个 Gateway 的模型链路、状态卡、服务状态都正常。
- 本轮全量复核后，可给出更准确的结论：
  - **没有发现新的阻断性故障**
  - **四个小龙虾当前都可判定为可正常使用**

### 本轮复核通过项
- systemd：
  - 四个服务均 `active/running`
- `gateway health --json`：
  - 四个实例全部 `ok=true`
- 实际 agent 回复：
  - `MAIN_FULL_AUDIT_OK`
  - `DAYONG_FULL_AUDIT_OK`
  - `CHUNYAN_FULL_AUDIT_OK`
  - `ZENGLAN_FULL_AUDIT_OK`
- `/status`：
  - 四个实例全部显示 `200k`，不再显示旧的 `256K/262144`
- 返回元数据：
  - 四个实例全部 `provider = newcli`
  - 四个实例全部 `model = claude-sonnet-4-6`

### 当前保留的非阻断项

#### 1. dayong / chunyan / zenglan 的 Doctor warnings 仍在
- 内容本质相同：
  - Telegram `groupPolicy=allowlist`
  - 但 `groupAllowFrom/allowFrom` 为空
  - 所以如果未来启用相关 Telegram 群消息，这些群消息会被静默丢弃
- 当前判断：
  - 这不是 Sonnet 4.6 配置问题
  - 也不是当前主链路故障
  - 属于已知提醒级警告

#### 2. chunyan 启动后出现过 3 条旧 delivery recovery 失败
- 具体错误：
  - 飞书卡片内容超限
  - `ErrCode: 11310`
  - `card table number over limit`
- 当前判断：
  - 这是旧失败投递队列恢复时再次失败
  - 不是当前模型或 Gateway 主链路故障
  - 不影响当前 Sonnet 4.6 已切换成功

### 当前结论
- 若问题是：
  - “Sonnet 4.6 的参数有没有全配对？”
  - 答案是：**现在已经全配对了。**
- 若问题是：
  - “四个小龙虾现在还有没有哪个有问题？”
  - 答案是：**没有发现阻断性问题。**
- 但仍保留两类非阻断项：
  - Telegram 群聊 allowlist 的 doctor warning
  - `chunyan` 旧飞书投递队列的卡片超限恢复失败记录

## BK. VS Code Remote SSH 到 `openclaw` 变慢 / 超时：根因分层（2026-03-15）

### 直接结论
- 这次不是单纯的 "VS Code 自己慢"。
- 现象分成两层：
  - **第一层：`openclaw-24x7` 这条 Tailscale 数据通道本身有抖动甚至会超时。**
  - **第二层：当链路勉强可用时，VS Code Remote SSH 的 exec server / 端口转发初始化会把体感延迟继续放大。**

### 证据 1：纯命令行 SSH 认证不是主瓶颈
- `2026-03-15 19:00 CST`，本机执行：
  - `ssh -vvv -o ConnectTimeout=10 openclaw exit`
- 总耗时约 `4.06s`。
- 关键日志显示：
  - `Connection established.`
  - `Authenticated to 100.64.65.65 ... using "none".`
  - 远端 banner 为 `Remote software version Tailscale`
- 说明：
  - 这里走的是 **Tailscale SSH**，不是传统公钥/密码认证慢。
  - TCP 建连和认证阶段本身并不慢，也没有出现反复试 key / 密码重试 / DNS 卡顿。

### 证据 2：VS Code 慢点主要发生在远端脚本启动与 exec server 阶段
- 本机 VS Code Remote SSH 日志：
  - `C:\Users\kevinlasnh\AppData\Roaming\Code\logs\20260315T185514\window1\exthost\output_logging_20260315T185520\1-Remote - SSH.log`
- 关键时间点：
  - 第 1 次连接：
    - `18:55:21` 开始跑 `ssh -T -D ... openclaw sh`
    - `18:55:27` 才出现 `running`
  - 第 2 次重连：
    - `18:57:08` 开始
    - `18:57:26` 才出现 `running`
  - 第 3 次重连：
    - `18:58:09` 开始
    - `18:58:19` 才出现 `running`
- 也就是 VS Code 在这一步额外空等了大约 `5s`、`17s`、`10s`。
- 同一个日志还出现：
  - `Existing exec server for ssh-remote+openclaw timed out`
  - 多次 `SSH Resolver called ... (Reconnection)`
  - 多次 `Could not find pty ... on pty host`
- 说明：
  - VS Code 不是只建一条 SSH 会话，它还要拉起 socks 转发、exec server、extension host。
  - 这类多路复用在不稳定链路上比 `ssh host exit` 更容易放大延迟和重连。

### 证据 3：当前问题已经升级成 peer 级可达性异常，不只是 "慢"
- 同一轮诊断后半段，本机对 `openclaw` 连续出现：
  - `ssh: connect to host 100.64.65.65 port 22: Connection timed out`
  - `ping 100.64.65.65` 超时
  - `tailscale ping -c 1 openclaw-24x7` 超时
- 但本机 Tailscale 自身是健康的：
  - `tailscale netcheck`：UDP / IPv4 / IPv6 都正常
  - `Tailscale` Windows 服务是 `Running`
  - 本机能成功 `tailscale ping` 到另一个在线节点 `desktop-qgtccdd`，且返回：
    - `pong ... via DERP(nue) in ~1.0s`
- `tailscale status` 同时显示：
  - `openclaw-24x7` 仍是 `active`
  - 但路径为 `relay "hkg"`，不是直连
- 说明：
  - **不是这台 Windows 电脑整体没有网，也不是本机 Tailscale 全挂。**
  - 更像是 `openclaw-24x7` 这个 peer 当前经由 `DERP(hkg)` 的数据通道不稳定，甚至出现控制面看着在线、数据面却不响应的情况。

### 当前最可靠判断
1. **根因主轴在 Tailscale peer 链路，而不是 VS Code UI。**
2. **当链路可用时，VS Code Remote SSH 的 exec server / reconnection 机制会继续放大体感慢。**
3. **因此用户看到的是：有时"能进但很慢"，有时直接"一直转圈/超时"。**

### 建议优先级
1. 先从远端主机复核 Tailscale 数据面：
   - `tailscale status`
   - `tailscale ping desktop-jrvidlh`
   - `tailscale netcheck`
   - `systemctl status tailscaled`
2. 若远端长期只能走 `DERP(hkg)`，优先排查为什么不能建立 direct path。
3. 对 VS Code 本地侧的低风险缓解：
   - 给 `Host openclaw` 加 `ServerAliveInterval 30`
   - 加 `ServerAliveCountMax 3`
4. 若后续仍是 "SSH 能连但 VS Code 老重连"，可单独试：
   - `remote.SSH.useExecServer = false`
5. 如果后面确认 Tailscale SSH 本身就是不稳点，可评估：
   - 继续走 Tailscale IP
   - 但改用普通 `sshd`，不要让 VS Code 走 Tailscale SSH 拦截层

### 这次诊断的重要边界
- 本轮**没有改动远端配置**。
- 本轮结论是基于：
  - 本机 SSH 实测
  - 本机 Tailscale 实测
  - 本机 VS Code Remote SSH 日志
- 由于在诊断过程中 `openclaw` 已经进入真实超时态，本轮无法继续从远端读取 shell / VS Code Server 文件。

## BL. VS Code Remote SSH 提速：综合调研后的优先级方案（2026-03-15）

### 官方文档与本地实测合并后的总判断
- **最主要瓶颈不是 SSH 认证，而是连接类型和 VS Code 的会话层。**
- VS Code Remote SSH 官方文档说明：
  - VS Code 会在远端安装并启动 `VS Code Server`
  - 大多数扩展都运行在远端 SSH 主机上
  - 打开一个远端窗口不只是建一个 shell，还包含 server、management connection、extension host、pty host 和端口转发
- VS Code troubleshooting 官方文档说明：
  - VS Code 为了打开远端窗口会建立两条 SSH 相关连接
  - 在 macOS/Linux 可用 `ControlMaster` 复用连接，但 Windows 客户端没有这条路
- Tailscale 官方文档说明：
  - Direct 连接通常延迟更低、吞吐更高
  - DERP relay 是 direct 不可达时的 fallback
  - 经常走 relay 是性能问题的常见根因之一

### 本机 + 远端现状（这次实际测到的）

#### 1. 当前 `desktop-jrvidlh <-> openclaw-24x7` 长期走 `DERP(hkg)`
- 本机：
  - `tailscale ping -c 5 openclaw-24x7`
  - 连续返回 `via DERP(hkg)`
  - 延迟样本：`120 / 121 / 606 / 381 / 120 ms`
  - 最终：`direct connection not established`
- 远端：
  - `tailscale ping -c 3 desktop-jrvidlh`
  - 同样全部 `via DERP(hkg)`
  - 最终：`direct connection not established`
- 说明：
  - 这不是偶发一次，而是当前两端之间**长期没有建立 direct path**
  - VS Code Remote SSH 的附加握手、转发、重连都建立在这条 relay 链路上

#### 2. 远端 shell 初始化几乎不是问题
- `~/.bashrc` 对非交互 shell 会立刻 `return`
- `~/.profile` 和 `~/.zshrc` 只额外 source 了 `~/.local/bin/env`
- `~/.local/bin/env` 只是一个 PATH 补充脚本
- 远端实测：
  - `bash -lc true` 约 `0.006s`
  - `source ~/.local/bin/env` 后约 `0.009s`
- 说明：
  - 不存在那种 `.bashrc` / `.profile` 本身拖慢几秒的情况

#### 3. VS Code 当前还有一个独立的会话层问题：ptyHost 脏状态
- 远端日志反复出现：
  - `Could not find pty 2 on pty host`
  - `Could not find pty 3 on pty host`
  - `Could not find pty 4 on pty host`
- 本地 `Remote - SSH.log` 同时出现：
  - `Existing exec server ... timed out`
  - 多次 `Reconnection`
- 这说明：
  - 即使底层链路恢复，当前这一版 `.vscode-server` 会话状态也不算干净
  - 它会额外制造“连上了但又掉、再连、终端异常”的体感

### 能让 VS Code 明显变快的动作，按优先级排序

#### P0. 先接受一个现实：如果继续长期走 `DERP(hkg)`，VS Code 不可能快到像 terminal SSH
- 纯 `ssh openclaw` 只做一层握手
- VS Code Remote SSH 还要做：
  - bootstrap script
  - socks / tunnel
  - server attach
  - management connection
  - extension host
  - pty host
- 所以只要底层仍是 relay，VS Code 注定比 terminal SSH 更慢，也更容易被抖动放大

#### P1. 最高收益：优先把 `desktop-jrvidlh <-> openclaw-24x7` 从 DERP 变成 direct
- 这是**唯一最可能带来数量级改善**的动作
- 当前推断：
  - 远端 `openclaw-24x7` 的 `tailscale netcheck` 有 `UPnP / NAT-PMP / PCP`
  - 本机 `desktop-jrvidlh` 没看到类似 port mapping 能力
  - 本机当前网络是校园网 `xjtlu.edu.cn`
- 推断：
  - 更可能是**本机所在网络**对 UDP / NAT 穿透不友好，导致直连建立不起来
- 可执行路线：
  1. 换本地网络做 A/B：手机热点 / 家里 Wi‑Fi / 其它宽带
  2. 每换一次网络后立即测：
     - `tailscale ping -c 5 openclaw-24x7`
     - 看是否从 `via DERP(hkg)` 变成 `via <public-ip:port>`
  3. 如果某个网络能建立 direct，VS Code 连接速度通常会立刻改善

#### P2. 次高收益：清理远端 `.vscode-server` 脏会话
- VS Code troubleshooting 官方文档推荐在 Remote SSH 异常时使用：
  - `Remote-SSH: Kill VS Code Server on Host`
  - 必要时 `Remote-SSH: Uninstall VS Code Server from Host`
- 结合本轮日志，这一步非常值得做，因为你已经有：
  - `Could not find pty ... on pty host`
  - `exec server timed out`
  - 多次 `reconnected`
- 预期收益：
  - 不能解决 DERP 导致的底层慢
  - 但能清掉当前远端 VS Code 会话层的脏状态，减少反复重连和终端异常

#### P3. 中收益：减少 `remote.SSH.defaultExtensions`
- 你本机当前配置里：
  - `remote.SSH.defaultExtensions = [python, jupyter-renderers, jupyter-keymap, jupyter]`
- 官方文档明确说明：
  - 大多数扩展都运行在远端 SSH 主机上
  - `remote.SSH.defaultExtensions` 会让这些扩展在任意 SSH 主机上都被安装/校验
- 本轮日志也显示每次连接都在做：
  - `--install-extension=ms-python.python`
  - `--install-extension=ms-toolsai.jupyter...`
- 预期收益：
  - 对“首次连接 / 清理后重连 / 版本升级后重装”帮助更明显
  - 对“已装好 server 的每次连接”是中等收益，不是最大头
- 适用前提：
  - 如果 `openclaw` 不是拿来写 Python / Notebook，就不该给它默认绑这 4 个扩展

#### P4. 中低收益：给 `Host openclaw` 单独加 SSH keepalive
- 推荐：
  - `ServerAliveInterval 30`
  - `ServerAliveCountMax 3`
- 作用：
  - 主要是减少空闲或轻微抖动时的假死感
  - 更偏向稳定性，不是纯提速

#### P5. 诊断型动作：试验 `remote.SSH.useExecServer = false`
- 本轮日志里直接出现了：
  - `Existing exec server ... timed out`
- 所以从症状看，确实有理由把 `useExecServer` 当成诊断变量试一次
- 但要注意：
  - 微软官方仓库在 2024 年有过 `useExecServer=false` 的 verified bug 记录
  - 因此它更适合作为**A/B 试验**，不是第一手永久方案

#### P6. 高成本备选：不用 Tailscale SSH，改走普通 `sshd` + Tailscale IP
- 当前连接走的是 Tailscale SSH：
  - `ssh -vvv` 里远端 banner 是 `Tailscale`
- 如果后续发现：
  - direct path 已解决
  - VS Code 仍只在 Tailscale SSH 上明显不稳
- 那么可以评估：
  - 让远端普通 `sshd` 监听一个只对 tailnet 放行的端口
  - VS Code 直接走这个端口
- 这属于结构性改造：
  - 复杂度更高
  - 当前不应作为第一选择

### 最终建议顺序
1. **先测不同本地网络，看能不能让 `tailscale ping openclaw-24x7` 建立 direct path**
2. **在当前网络下，先清一次远端 VS Code Server 会话**
3. **收紧 `remote.SSH.defaultExtensions`，不要给 `openclaw` 自动塞 Python/Jupyter**
4. **给 `Host openclaw` 补 `ServerAliveInterval/CountMax`**
5. **如果还慢，再做 `useExecServer=false` A/B**
6. **只有在前面都做了还不理想，才考虑切到普通 `sshd` 方案**

### 这轮调研后的明确结论
- **能把 VS Code SSH “明显提速”的关键，不在 shell，不在 CPU，不在 `.vscode-server` 目录大小**
- **最关键的是让当前 `desktop-jrvidlh <-> openclaw-24x7` 不再长期走 `DERP(hkg)`**
- 其它动作都重要，但更多是：
  - 减少附加开销
  - 清理脏状态
  - 降低重连概率
  - 而不是从根上改变链路质量

## BM. “让这台电脑上所有 SSH App 都快速连到 openclaw” 的完全修复目标态（2026-03-15）

### 先给一句总判断
- 如果目标是：
  - **PowerShell / Windows Terminal**
  - **VS Code Remote SSH**
  - **PuTTY / WinSCP / FileZilla SFTP**
  - 其它任何基于 SSH/SFTP 的客户端
  都要在这台 Windows 电脑上稳定、快速地连 `openclaw`
- 那么**只调 VS Code 是不够的**。
- 完全修复必须把工程目标拆成 3 层：
  1. **传输层修复**：这台电脑到 `openclaw-24x7` 不再长期走 `DERP(hkg)`
  2. **SSH 服务层收敛**：对所有客户端提供兼容性最好的 SSH 服务
  3. **客户端层收敛**：各客户端只做很薄的一层优化，不再承担“救火”角色

### 完全修复后应该长成什么样

#### 目标 A：底层链路
- `desktop-jrvidlh <-> openclaw-24x7` 能稳定建立 **direct** 连接
- `tailscale ping -c 10 openclaw-24x7`：
  - 最初 1-2 个包可经 DERP
  - 很快升级到 `via <public-ip:port>`
  - 不再长期停留在 `via DERP(hkg)`
- 连续 `20` 次 `ssh -o ConnectTimeout=5 host exit`：
  - `0` 次 timeout
  - 连接时间分布稳定，无大幅尖峰

#### 目标 B：SSH 服务层
- 对所有 SSH App 暴露的是**标准 OpenSSH 语义**
- 避免依赖 Tailscale SSH 的 `auth none` 行为作为主入口
- 原因：
  - Tailscale 官方文档明确写到：
    - 有些 SSH 客户端会因为 `no authentication` 连接方式而失败
  - 如果目标是“所有 SSH App 都兼容”，标准 `sshd` 更稳

#### 目标 C：客户端层
- VS Code Remote SSH：
  - 远端 `.vscode-server` 无脏状态
  - 不再反复 `Reconnection`
  - 不再报 `Could not find pty ... on pty host`
- 终端类客户端：
  - 仅需正常的 key auth / keepalive
- SFTP/同步类客户端：
  - 不需要为 Tailscale SSH 的兼容性额外绕路

### 从工程上看，完整修复项目应该包含哪些工作包

#### Work Package 1：先把这台 Windows 到远端的连接类型修对
- 这是整个项目的地基
- 你现在的实际状态是：
  - 本机到远端长期 `DERP(hkg)`
  - 远端回本机也长期 `DERP(hkg)`
- 所以完整修复至少要完成以下其中一种：

##### 路线 1A：直接建立 direct path（最佳）
- 做法：
  - 换本地网络 A/B（校园网、家宽、手机热点）
  - 检查本机所在网络是否阻断 UDP / NAT 打洞
  - 在可控网络上尽量启用 NAT-PMP / UPnP / PCP
  - 按 Tailscale 官方建议，必要时确保可用：
    - UDP `41641`
    - UDP `3478`
    - TCP `443`
- 目标：
  - 让 `tailscale ping` 最终变成 direct

##### 路线 1B：如果这台电脑所在网络注定不能 direct，就部署 Tailscale Peer Relay（次优）
- Tailscale 官方现在支持 peer relay
- 官方文档明确说：
  - 当 direct 不可达时，可以先走 peer relay，再 fallback 到 DERP
  - peer relay 的适用场景就是“strict NAT / firewall 下仍想拿更低延迟和更高吞吐”
- 适合你的场景：
  - 如果校园网/公司网的 NAT 太硬，导致这台电脑永远打不出 direct
  - 那就要在你可控的网络上放一台 peer relay 设备
- 这会让“所有 SSH App”都受益，因为它修的是底层 tailnet 路径，不是某个单独客户端

##### 路线 1C：如果 tailnet 直连和 peer relay 都不可行，就不要再把“快”寄托在这条 tailnet SSH 路径上
- 这时就进入架构替换问题：
  - 例如改成普通公网/IPv6/跳板机 SSH
  - 或者换成你能完全控制的一条 WireGuard / VPS 路径
- 这部分不是 Tailscale 官方文档直接给出的方案，而是基于网络架构推导出的保底路线
- 含义是：
  - **如果传输层做不到 direct 或更近的 relay，就不存在“所有 SSH App 都快”的彻底修复**

#### Work Package 2：把 SSH 服务入口统一成“最兼容”的方案
- 如果你的目标是“所有 SSH App 都快且兼容”，推荐目标态是：
  - **tailnet 负责网络**
  - **OpenSSH (`sshd`) 负责 SSH 协议服务**
  - **Tailscale SSH 不再作为主入口**
- 原因：
  - Tailscale 官方写明：
    - 它会接管 Tailscale IP 上的 `22`
    - 它使用 `auth none`
    - 有些 SSH 客户端可能会失败
  - 而你的目标不是“OpenSSH CLI 能连”，而是“所有 SSH App 都稳定兼容”
- 所以完整修复里，服务层理想动作是：
  1. 确认远端标准 `sshd` 配置健康
  2. 在 tailnet 场景下让客户端优先连接标准 `sshd`
  3. 只在明确需要 Tailscale SSH 的场景保留它

### 关于这一步的现实含义
- 如果继续保留 Tailscale SSH 为主入口：
  - OpenSSH CLI 大概率没问题
  - 但“所有 SSH App 完全兼容”这件事官方自己都没有给你保证
- 所以：
  - **想要所有 SSH App 都快且稳，标准 OpenSSH 是更合理的目标态**

#### Work Package 3：清掉 VS Code 这层特有噪声
- 这部分只影响 VS Code，不影响其它 SSH App
- 但如果你希望“所有 app 都表现好”，VS Code 也要被单独收尾
- 包括：
  - `Remote-SSH: Kill VS Code Server on Host`
  - 必要时 `Uninstall VS Code Server from Host`
  - 收紧 `remote.SSH.defaultExtensions`
  - 只给真正需要的主机装 Python/Jupyter 类远端扩展
  - 视情况做 `useExecServer=false` A/B

### 完整修复的推荐目标架构

#### 目标架构 S（最推荐）
- 传输层：
  - `desktop-jrvidlh <-> openclaw-24x7` 建立 direct
- SSH 服务层：
  - 远端使用标准 `sshd`
  - 客户端通过 Tailscale IP / MagicDNS 连接标准 `sshd`
- 客户端层：
  - VS Code 清理远端 server 脏状态
  - 默认扩展减负
- 这是最接近“所有 SSH App 都快”的理想状态

#### 目标架构 A（如果直连永远不成）
- 传输层：
  - 引入 Tailscale Peer Relay
- SSH 服务层：
  - 仍尽量使用标准 `sshd`
- 客户端层：
  - 同 S
- 这是“在受限网络里仍尽量快”的次优长期方案

#### 不推荐的伪修复
- 只改 VS Code 设置
- 只加 keepalive
- 只删 `.vscode-server`
- 只换 ssh config
- 这些都只能缓解，不能达成“所有 SSH App 都快”的完整目标

### 可以作为“完全修复完成”的验收标准
1. `tailscale ping -c 10 openclaw-24x7`
   - 绝大多数包为 direct 或 peer-relay
   - 不再长期 DERP
2. 连续 `20` 次 `ssh host exit`
   - `0` 超时
   - 耗时稳定
3. VS Code Remote SSH
   - 首次 attach 和重连都无明显卡顿
   - 不再出现 `Could not find pty ...`
   - 不再出现 `exec server timed out`
4. 其它 SSH 客户端
   - PuTTY / WinSCP / SFTP 客户端均无需特殊绕过即可连接
5. 若继续保留 Tailscale SSH：
   - 只能算“部分兼容”
   - 不能算“所有 SSH App 的完全兼容解”

### 这轮完整调研后的最终结论
- 想把“这个电脑上所有 SSH App 连那台机器都很快”做到位，项目必须是：
  - **先修传输层**
  - **再统一 SSH 服务层**
  - **最后才调各客户端**
- 如果不先解决“长期 `DERP(hkg)`”这个根问题，后面的所有优化都只是打补丁。
- 如果目标里包含“所有 SSH App 兼容”，那最终目标态应优先考虑：
  - **标准 OpenSSH over Tailscale**
  - 而不是继续把 Tailscale SSH 当唯一主入口

## BN. 当前环境下，“完整修复方案”能否完全部署（2026-03-15）

### 先给直接结论
- **能部署一大半，而且能把架构修到“正确方向”。**
- 但如果你把“完整修复”定义成：
  - 所有 SSH App 都快
  - 不再长期走 `DERP(hkg)`
  - 不依赖 Tailscale SSH 的兼容性边界
- 那么在你**当前不能换 Wi‑Fi**的前提下，结论是：
  - **可以把方案部署到“接近完整”的状态**
  - **但不能在当前时刻 100% 保证“完全修复闭环”一定成立**
- 主要卡点不在机器权限，而在：
  - 当前本机网络是否允许 direct
  - 以及 tailnet policy / peer relay 这层是否可顺利落地

### 当前环境中，已经确认具备的条件

#### 1. 远端标准 `sshd` 已经就绪
- `openclaw-24x7` 上：
  - `ssh.service = active`
  - 监听 `0.0.0.0:22` 和 `[::]:22`
- `sshd_config` 当前是默认型配置：
  - `PasswordAuthentication` 未禁用（默认仍可用）
  - `PubkeyAuthentication` 默认开启
  - `Subsystem sftp` 已启用
- 结论：
  - **标准 OpenSSH 服务层随时可接管**
  - 这对“所有 SSH App 兼容”是好消息

#### 2. 远端防火墙已经允许 tailnet 源
- `ufw status verbose` 显示：
  - `Default: deny (incoming)`
  - 但已明确：
    - `ALLOW IN 100.64.0.0/10`
- 结论：
  - 如果远端 `sshd` 改监听其它端口（例如 `2222`），
    **从 tailnet 过来的标准 SSH 流量在主机防火墙层不会被挡**

#### 3. 两端 Tailscale 版本足够新
- 本机和远端都在：
  - `Tailscale 1.94.2`
- 结论：
  - 功能层面不落后
  - 不存在“版本太旧，不能做下一步”的硬阻塞

#### 4. 远端网络条件比本机好，适合承担更多职责
- 远端 `tailscale netcheck` 明确显示：
  - `UPnP, NAT-PMP, PCP`
  - 说明远端在 NAT / 端口映射上是“相对好打通”的一侧
- 本机之前 `netcheck` 没有看到 port mapping 能力
- 结论：
  - 如果要部署 peer relay / 更稳定入口，
    **远端 openclaw 自己是最合适的候选**

#### 5. 本机主机防火墙没有看到明显阻断 Tailscale 的证据
- 本机防火墙里存在：
  - `Tailscale-Process`
  - `Tailscale-In`
- 本机 `netstat` 显示：
  - `UDP 0.0.0.0:41641`
- 结论：
  - 当前没有明显证据表明“只是 Windows 防火墙把 Tailscale 完全挡死了”
  - 问题更像网络环境 / NAT 条件，而不是本机服务没监听

### 当前环境中，已经确认存在的硬限制

#### 1. 当前这条链路仍长期 `DERP(hkg)`
- 本机与远端互相 `tailscale ping`
  都显示：
  - `direct connection not established`
  - 持续 `via DERP(hkg)`
- 这说明：
  - **“完全修复”的核心前提还没满足**
  - 任何客户端层优化都无法代替这一点

#### 2. 你现在不能换 Wi‑Fi
- 这直接导致：
  - 我们没法用最简单、最低成本的 A/B 测试来验证
    当前网络是不是 direct 的根阻塞
- 所以：
  - **不能通过“换网络”这条最直接路径来完成闭环**

### 基于当前环境，哪些部分“现在就能完整部署”

#### A. 标准 `sshd` 兼容层：可以
- 两种可部署方式：

##### 方式 A1：关闭 Tailscale SSH，让 tailnet 22 直接落到标准 `sshd`
- 这是最接近“所有 SSH App 统一入口”的方案
- 当前条件看：
  - 远端 `sshd` 已运行
  - 远端 UFW 已放行 tailnet
  - 只需要补好本机登录凭据（推荐新加一把 key）
- **技术上可部署**

##### 方式 A2：保留 Tailscale SSH，但让标准 `sshd` 额外监听一个备用端口
- 例如 `2222`
- 所有 SSH App 都可以改用：
  - `openclaw-24x7.tailda6e28.ts.net:2222`
- 当前条件看：
  - 远端主机和防火墙都支持
- **技术上可部署**

#### B. VS Code 会话层清理：可以
- 包括：
  - `Kill VS Code Server on Host`
  - 必要时 `Uninstall VS Code Server`
  - 减掉不必要的默认远端扩展
  - 给 `Host openclaw` 加 keepalive
- **这些都可以现在做**

### 基于当前环境，哪些部分“理论可部署，但要额外前提”

#### C. 用 Peer Relay 代替当前 DERP：大概率可做，但不是“此刻 100% 已确认”
- 当前条件对这条路是有利的：
  - 两端版本足够新
  - 远端 openclaw 网络更适合作 relay 侧
  - Tailscale 官方文档也明确支持：
    - 设备可以作为 peer relay
    - 甚至可以“self relay”
- 但这里还有两个未闭环前提：

1. **需要 tailnet policy / grants 落地**
   - 这一步通常要在 Tailscale 管理后台完成
   - 本机虽然是 owner/admin 节点，但当前会话里没有现成 API token 或控制台直写入口
   - 所以：
     - **从“系统能力”上可做**
     - **从“我现在纯本地自动一把梭”上不完全可做**

2. **需要开放并验证 relay 端口**
   - 远端主机侧需要为 peer relay 的 UDP 端口放行
   - 若要 self-relay，还要验证实际效果是否真的从 DERP 切换过去
   - 这一点在当前环境下是**可试验**的，但还没有现成证据证明“一上就一定成功”

### 基于当前环境，哪些部分“现在还不能宣称完全可部署成功”

#### D. “恢复 direct path” 这件事本身
- 在你不能换 Wi‑Fi 的前提下：
  - 我们无法用最直接的方法排除当前网络对打洞的限制
- 而且从当前证据看：
  - 这台电脑这条链路一直没能建立 direct
- 所以：
  - **“通过现有 Wi‑Fi 把 direct 修出来”不能承诺一定可部署成功**
  - 这部分当前仍是 blocked / uncertain

### 最终判断：当前环境下的可部署性结论

#### 可以现在落地的部分
1. 标准 `sshd` 兼容入口
2. VS Code Server 清理与减负
3. SSH keepalive 和主机级轻量优化

#### 可以推进、但还需要外部前提的部分
1. Peer Relay / self-relay
   - 需要 tailnet policy 落地
   - 需要端口与效果验证

#### 当前不能承诺闭环成功的部分
1. 不换 Wi‑Fi 的前提下恢复 direct

### 一句话结论
- **如果你的“完整修复”定义是“把架构修对，让所有 SSH App 都有统一、兼容、可优化的入口”，当前环境下可以部署到 80-90% 的完成度。**
- **如果你的“完整修复”定义是“今天就保证所有 SSH App 都快，而且不再走 DERP”，当前环境下还不能宣称 100% 可完整闭环。**

## BO. 已实际部署的“当前环境可落地修复”清单（2026-03-15）

### 1. 最终采用的是“新增入口，不替换旧入口”
- 这次没有替换 `Host openclaw`。
- 实际落地结构是：
  - 旧入口保留：Tailscale SSH，`100.64.65.65:22`
  - 新入口新增：标准 OpenSSH，`100.64.65.65:2222`
- 这样做的意义：
  - 先保证不失联
  - 让所有 SSH app 可以逐步切到标准 `sshd`
  - 旧入口始终作为回退通道

### 2. 远端 Linux 的新增持久配置
- 新增文件：
  - `/etc/ssh/sshd_config_openclaw_2222`
  - `/etc/systemd/system/openclaw-sshd-2222.service`
- `sshd_config_openclaw_2222` 的核心项：
  - `Port 2222`
  - `ListenAddress 100.64.65.65`
  - `PasswordAuthentication no`
  - `KbdInteractiveAuthentication no`
  - `AuthenticationMethods publickey`
  - `AllowUsers kevinlasnh`
  - `ClientAliveInterval 30`
  - `ClientAliveCountMax 3`
- `openclaw-sshd-2222.service` 的核心项：
  - `ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sshd_config_openclaw_2222`
  - `Restart=always`
  - `WantedBy=multi-user.target`
- 实测结果：
  - `systemctl is-enabled openclaw-sshd-2222.service = enabled`
  - `systemctl is-active openclaw-sshd-2222.service = active`
  - `ss -ltnp` 显示监听 `100.64.65.65:2222`

### 3. 远端认证已经切到标准公钥路径
- 本机 `C:\Users\kevinlasnh\.ssh\openclaw_newmachine` 的公钥已追加到远端 `~/.ssh/authorized_keys`
- 新入口 `openclaw-sshd` 已能直接使用该密钥登录
- 这意味着：
  - PowerShell / Windows Terminal
  - VS Code Remote SSH
  - `scp` / `sftp`
  - WinSCP / PuTTY
  都可以有一条统一的标准 SSH 入口

### 4. 本机持久配置已写入
- `C:\Users\kevinlasnh\.ssh\config`
  - 旧 `Host openclaw` 已补：
    - `ConnectTimeout 5`
    - `ServerAliveInterval 30`
    - `ServerAliveCountMax 3`
    - `TCPKeepAlive yes`
  - 新增 `Host openclaw-sshd`
    - `HostName 100.64.65.65`
    - `Port 2222`
    - `IdentityFile C:/Users/kevinlasnh/.ssh/openclaw_newmachine`
    - `IdentitiesOnly yes`
    - 同样的 keepalive / timeout
- `C:\Users\kevinlasnh\AppData\Roaming\Code\User\settings.json`
  - 已新增 `openclaw-sshd -> linux` 的 `remote.SSH.remotePlatform` 映射

### 5. 已完成的真机验收
- 新入口连续 5 次 SSH：
  - 约 `4.8s / 4.3s / 2.8s / 3.3s / 3.5s`
- 旧入口连续 3 次 SSH：
  - 约 `2.9s / 3.0s / 3.6s`
- `scp openclaw-sshd:/etc/hostname ...` 成功
- 远端 Linux 已真实重启一次，重启后：
  - 旧入口恢复约 `32.5s`
  - 新入口恢复约 `34.8s`
  - 并且以下服务自动恢复：
    - `tailscaled`
    - `ssh.socket`
    - `openclaw-sshd-2222.service`

### 6. 这次没有部署的项，以及原因
- **未恢复 direct path**
  - 当前本机网络环境不变，链路仍长期 `DERP(hkg)`
  - 这不是靠本地/远端 sshd 配置就能直接修好的
- **未切掉旧入口**
  - 保留 `openclaw` 作为保险绳更安全
- **未直接改全局 `remote.SSH.useExecServer`**
  - 这是实验项，不适合作为当前默认永久配置
- **未直接删除全局 `remote.SSH.defaultExtensions`**
  - 这是跨所有 SSH 主机的全局行为，副作用范围更大

### 7. Windows 侧“重启自动恢复”的证据边界
- 本轮没有真实重启 Windows：
  - 当前会话就在这台机器上，直接重启会中断工作
- 但持久化条件已经具备：
  - SSH 客户端配置写入 `~/.ssh/config`
  - VS Code 映射写入用户 `settings.json`
  - 本机 `Tailscale` 服务 `StartType = Automatic`
- 因此从配置层面，Windows 重启后应恢复到本轮部署后的状态；
  唯一没有实机跑过的是“重启动作本身”。

## BP. 部署后再次检查 VS Code Remote SSH 的当前状态（2026-03-15）

### 1. 最新一条 VS Code 真日志：它仍然在连旧入口 `openclaw`
- 最新 Remote SSH 日志：
  - `C:\Users\kevinlasnh\AppData\Roaming\Code\logs\20260315T215920\window1\exthost\output_logging_20260315T215922\1-Remote - SSH.log`
- 关键事实：
  - `21:59:22` 这次 VS Code Resolver 连接的是 `ssh-remote+openclaw`
  - 不是 `ssh-remote+openclaw-sshd`
  - 连接命令仍是：
    - `"C:\Program Files\OpenSSH\ssh.exe" -T -D ... openclaw sh`
- 结论：
  - **用户刚才如果点的是旧 Host，VS Code 仍然会走旧入口。**

### 2. 这条最新 VS Code 真日志显示：旧入口那一刻发生了 banner exchange timeout
- 同一日志明确记录：
  - `Connection timed out during banner exchange`
  - `Connection to 100.64.65.65 port 22 timed out`
- 这说明：
  - **截至 21:59，那次 VS Code 对旧入口的实际尝试没有成功。**
  - 问题点仍然是旧入口 `openclaw` 的瞬时链路/握手表现，不是配置文件语法错误。

### 3. 但在更接近“当前时刻”的命令级复测中，两条路都已经能稳定完成 VS Code 风格 bootstrap
- 用和 VS Code 很接近的模式复测：
  - `ssh -T -D <port> <host> sh -lc "echo ..."`
- 单次结果：
  - 旧入口 `openclaw`：成功，约 `676 ms`
  - 新入口 `openclaw-sshd`：成功，约 `900 ms`
- 连续 5 次结果：
  - `openclaw`：`917 / 1011 / 1013 / 1023 / 1021 ms`
  - `openclaw-sshd`：`1330 / 1390 / 1429 / 1424 / 1430 ms`
- 结论：
  - **从 SSH bootstrap 角度看，当前这两个入口都能跑通。**
  - **旧入口今天的失败更像瞬时抖动，而不是“现在一定还坏着”。**

### 4. 对“现在 VS Code 能不能正常连”的最准确表述
- **旧入口 `openclaw`：**
  - 最新一条真正的 VS Code 尝试是失败的
  - 但紧接着的多轮命令级 bootstrap 已经恢复成功
  - 因此它更像“可恢复但仍有抖动风险”
- **新入口 `openclaw-sshd`：**
  - 还没有看到真正的 VS Code GUI 连接日志
  - 但配置、密钥、端口、标准 `sshd`、VS Code host 映射、命令级 bootstrap 都已正常
  - 因此它是**当前更推荐的 VS Code 目标 Host**

### 5. 当前对 VS Code 配置的关键判断
- `remote.SSH.remotePlatform` 已同时包含：
  - `openclaw`
  - `openclaw-sshd`
- `remote.SSH.configFile =` 空：
  - 表示 VS Code 使用默认 `C:\Users\kevinlasnh\.ssh\config`
- `remote.SSH.useExecServer = true`
  - 仍保留默认 exec server 行为
- `remote.SSH.defaultExtensions` 仍包含 Python / Jupyter 4 件套
  - 这仍会给远端连接增加额外校验/安装开销

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
| 1 | `ou_d73c015003d3e69979f59312904a6caf` | 大勇 (dayong) |
| 2 | `ou_e4c865918d1b26e9ff11a09034e08970` | 春燕 (chunyan) |
| 3 | `ou_2a3a37b3d7fd1d209c89419e7fee2284` | 小姨 (zenglan) |

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

#### 误区 3：以为“dayong 没工具”
不对。它有工具，但当前 prompt 地基太薄，加上 `Kimi` 这条链路的结构化调用兼容性也差，所以更容易输出伪工具文本。

### 7. capability-only 对齐后，问题缩小了，但没彻底消失

本轮只对 `dayong` 做了能力层增强，**没有动 `main`**：

- 重写 `~/.openclaw-dayong/workspace/AGENTS.md`
- 重写 `~/.openclaw-dayong/workspace/TOOLS.md`
- 新增 `MEMORY.md` 和 `workspace/memory/2026-03-10.md`
- 复制 3 个 managed skills：
  - `planning-with-files`
  - `capability-evolver`
  - `self-improving-agent`
- 复制 5 个通用 workspace skills：
  - `translate`
  - `openclaw-updater`
  - `x-tweet-fetcher`
  - `youtube-transcript`
  - `youtube-ultimate`

#### 已确认改善

旧 `agent:dayong:main` session 的注入数据已经变厚：

| 指标 | 变更前 | 变更后 |
|------|--------|--------|
| `systemPrompt.chars` | `15555` | `19673` |
| `projectContextChars` | `2879` | `6997` |
| `AGENTS.md` injected | `164` | `2601` |
| `TOOLS.md` injected | `850` | `1814` |
| `MEMORY.md` | 无 | `659` |

同时，`openclaw skills` 的 ready 数量也从：

- `6/54`

提升到：

- `14/62`

#### 但仍未根治

随机 UUID 硬测试后，`dayong` 仍表现出两种错误形态：

1. 直接输出伪工具文本：
   - `/exec({"command": "cat /proc/sys/kernel/random/uuid"})`
2. 直接编造“看起来像 UUID”的假结果：
   - `a8b3c4d5-e6f7-8901-2345-6789abcdef01`

第二种特别说明：它不是实际系统返回值，而是模型编造的模式化字符串。

### 8. 旧 session 不只是旧文件快照，连 skills 快照也旧了

能力层增强后，`openclaw skills` 已经能看到 `14` 个 ready skills，但旧 `agent:dayong:main` session 的 `systemPromptReport.skills.entries` 仍然只有 `4` 个：

- `healthcheck`
- `skill-creator`
- `weather`
- `obsidian-markdown`

这说明当前阻塞已经更清晰了：

- workspace 文件快照已经刷新
- 但 **skills prompt 仍在沿用旧快照**

因此当前更接近事实的判断是：

- 旧 `dayong` 主 session 已经“半刷新”
- 文件层刷新了
- 但 skills 层没有完全刷新
- 所以继续在这个旧 session 上测，会混入缓存噪音

### 9. 新发现：dayong state 里还有 `workspace-main`，CLI 默认路径会跑偏

本次还发现一个容易误判的问题：

- `~/.openclaw-dayong/agents/main/` 存在
- `~/.openclaw-dayong/workspace-main/` 存在

在 **不显式传 `--agent dayong`** 的 CLI 测试里，OpenClaw 会进入：

- `sessionKey = agent:main:main`
- `workspaceDir = ~/.openclaw-dayong/workspace-main`

这不是 `dayong` 正常 Telegram 主会话使用的那条路径。

因此后续验证规则必须固定成：

1. CLI 验证时明确 `--agent dayong`
2. 或者直接在 Telegram 的 `dayong` 会话里发 `/new`

否则容易测到错误的 workspace / session。

### 10. 进一步确认：重置 `dayong` sessions 能切掉旧快照，但不能单独修好 Kimi 工具链

#### 10.1 只重置 `dayong` 会话层，`main` 不受影响

按 OpenClaw 文档建议，直接重置某个 agent 的 `agents/<agentId>/sessions/` 是合法操作。
本轮只对 `dayong` 执行了：

- 备份：`~/.openclaw-dayong/agents/dayong/sessions.backup-20260310-143543`
- 重建空目录：`~/.openclaw-dayong/agents/dayong/sessions`
- 重启：`openclaw-gateway-dayong`

同时核对到：

- `openclaw-gateway-dayong.service` 的 `ExecMainPID` 已变化，说明只重启了 `dayong`
- `openclaw-gateway.service` 的 `ExecMainPID` 和 `ActiveEnterTimestamp` 不变，说明 `main` 没被碰

#### 10.2 新会话 skillsSnapshot 已经吃到 14 个技能

会话重置后，重新生成的 `agent:dayong:main` 条目中：

- `skillsSnapshot.skills` 已从旧的 `4` 个，变成完整的 `14` 个
- 包括新增的：
  - `capability-evolver`
  - `planning-with-files`
  - `self-improvement`
  - `openclaw-updater`
  - `Translate`
  - `x-tweet-fetcher`
  - `youtube-transcript`
  - `youtube-ultimate`

这说明前一轮 capability-only 对齐**确实已经生效**；问题不再是“新技能根本进不了 session”。

#### 10.3 Telegram 真实主会话已经被切空

重置后，`~/.openclaw-dayong/agents/dayong/sessions/sessions.json` 里只剩：

- `agent:dayong:main`

而原来的真实聊天键：

- `agent:dayong:telegram:dayong-bot:direct:8226087994`

已经不存在。
这意味着：**下一条来自用户的真实 Telegram 消息，会天然创建一个 fresh session**，不再沿用旧快照，所以也不必再额外先发 `/new`。

#### 10.4 但 fresh session 下，`kimi/k2p5` 仍然不稳定

在新的 `agent:dayong:main` 会话里再次做随机 UUID 硬测试时：

- 会话锁文件被创建：`4f4f91e1-e53a-472f-ba0c-064f7d93c044.jsonl.lock`
- `skillsSnapshot` 已正确写入
- 但没有生成对应的 `toolCall` / `toolResult` transcript
- CLI 请求长时间挂起，需要手动清理遗留 ssh 进程并重启 `dayong`

这说明主问题已经进一步收敛：

- **旧 session / 旧 skills 快照**：已被切掉
- **Kimi 当前执行链在 fresh session 下仍不稳定**：仍存在

所以现在不能再把问题简单归因于“session 没刷新”；更像是：

1. `dayong` 旧快照问题已经修掉
2. 剩下的是 `kimi/k2p5` 在 OpenClaw 这条工具调用链上的兼容性/稳定性问题

#### 10.5 最新实锤：真实 fresh Telegram 会话里也没有 toolCall

这一步是最关键的排除法证据。

在真实 Telegram 会话：

- `sessionKey = agent:dayong:telegram:dayong-bot:direct:8226087994`
- `sessionId = d6524ff6-2221-4cae-a421-aecf4143d51f`

这条会话已经明确吃到了新的能力层：

- `systemPrompt.chars = 28973`
- `projectContextChars = 6997`
- `skills.entries = 28`
- tools schema 仍完整包含：
  - `read`
  - `edit`
  - `write`
  - `exec`
  - `web_search`

用户在 **2026-03-10 15:24 CST** 发出的真实消息是：

- “你现在查下今天最新的新闻能上网搜索吗？调用工具给我上网搜索”

对应 transcript 结果：

- assistant 只返回一句：
  - “好的，小姨爹，我现在帮您搜索今天最新的新闻。让我调用工具来搜索。”
- 整个 session 文件只有 `9` 行
- `toolCall = 0`
- `toolResult = 0`
- 没有后续搜索结果消息

这说明：

- 它**不是没拿到 tool schema**
- **不是没拿到新 skills**
- **不是还在旧 prompt 缓存里**
- 而是模型在真实生产会话里，依然没有把“我要调用工具”落成 OpenClaw 需要的结构化工具调用

因此现在的根因判断可以更强地表述为：

- **`dayong` 的真实问题已经收敛到 `kimi/k2p5` 当前执行链不会稳定地产生可执行 tool call**。

#### 10.6 进一步排除：Kimi API 自身支持标准 `tool_use`

为了排除“是不是 Kimi 本身就不会调工具”，本轮又直接绕过 OpenClaw，使用 `dayong` 当前同一份 `KIMI_API_KEY` 做了最小 API 探针：

- `GET https://api.kimi.com/coding/v1/models`
- `POST https://api.kimi.com/coding/v1/messages`

极简消息请求：

- `model = "k2p5"`
- `tools = [echo_tool]`
- 用户要求：**必须调用 echo_tool，一次，不要正常回答**

实测结果：

- 两种认证头都能工作：
  - `Authorization: Bearer <KIMI_API_KEY>`
  - `x-api-key: <KIMI_API_KEY>`
- `/v1/models` 返回 `200`
- `/v1/messages` 也返回 `200`
- 返回体明确包含：
  - `content[0].type = "tool_use"`
  - `name = "echo_tool"`
  - `stop_reason = "tool_use"`
- 响应中的模型名显示为：
  - `kimi-for-coding`

这一步的意义非常大：

- **Kimi API 本身会正确输出结构化工具调用**
- 所以 `dayong` 当前故障**不是**“Kimi 天生不会工具调用”

更准确的剩余怀疑范围变成：

1. OpenClaw 当前对 `dayong + kimi/k2p5` 的运行时请求组织方式有问题
2. 过厚 / 过杂的 runtime prompt 让模型在生产会话里偏离工具调用
3. OpenClaw 与 Kimi 在复杂多轮场景下的 tool-call 兼容性存在边缘问题

因此，现阶段最严谨的表述应该是：

- **不是 Kimi API 不支持工具，而是 `dayong` 当前这条 OpenClaw 接入链没有稳定拿到 Kimi 的工具调用能力。**

---

## AH. 本仓库 Git 初始化后的正确用法（2026-03-10 14:05 CST）

### 1. 当前状态
- 本仓库此前**不是** Git 仓库。
- 已于 `2026-03-10 14:05 CST` 初始化为本地 Git 仓库，默认分支为 `main`。
- 已创建首次基线提交：
  - commit: `de6815b`
  - message: `Initialize repository baseline`

### 2. 为什么现在可以用 `git diff`

`git diff` 要想稳定回答“改了哪几行”，至少需要一个 baseline。

本次初始化后，后续对以下文件的改动都可以直接精确查看：

- `findings.md`
- `progress.md`
- `task_plan.md`

### 3. 最实用的命令

查看这三个文档**当前未提交改动**：

```bash
git diff -- findings.md progress.md task_plan.md
```

只看文件名：

```bash
git diff --name-only -- findings.md progress.md task_plan.md
```

看工作区是否干净：

```bash
git status --short
```

查看提交历史：

```bash
git log --oneline -- findings.md progress.md task_plan.md
```

### 4. `find -mtime 0` 的局限

此前用户讨论过：

```bash
find . -mtime 0 -name "*.md"
```

这条命令并不等于“今天从 00:00 到现在修改的文件”，而更接近：

- “过去 24 小时内修改过的文件”

所以它适合粗筛文件，不适合精确比较内容。

### 5. 本次 `.gitignore` 的最小策略

本次只排除了明显不适合纳入基线的内容：

- `.claude/`
- `wsl_output.txt`
- `openclaw-full-migrate-*.tgz`
- `nul`

目的是：

- 保留项目脚本和文档的 diff 能力
- 避免把迁移包和临时产物纳入版本跟踪

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

---

## AJ. 远端外星人机纠偏 + Kimi 消息格式分层（2026-03-10 16:40 CST）

### 1. 目标环境纠偏

用户随后明确指出，真正目标环境不是本机 WSL，而是远端外星人 Ubuntu 专机：

- `kevinlasnh@100.64.65.65`
- `HostName = openclaw-24x7`

重新 SSH 到远端 live 主机后确认：

- `~/.openclaw/` 存在
- `~/.openclaw-dayong/` 存在
- `openclaw-gateway.service` 与 `openclaw-gateway-dayong.service` 均为 `active/running`
- 远端 OpenClaw 版本为 `2026.3.7`
- 安装路径为 `/usr/lib/node_modules/openclaw`

因此，后续关于 `dayong` / Kimi 的结论，应以**这台远端 Ubuntu 机器**为准。

### 2. 主配置里的 Kimi，消息 API 确实是 Anthropic

远端主配置 `~/.openclaw/openclaw.json` 中，Kimi provider 当前 live 声明为：

- `baseUrl = "https://api.kimi.com/coding"`
- `api = "anthropic-messages"`
- `model id = "k2p5"`

所以从**配置文件层面**看：

- `main` 里的 Kimi 不是按 `openai-completions` 接入的
- 它明确就是 **Anthropic Messages API**

### 3. 但 OpenClaw 运行时会把 Kimi 的 tools 改写成 OpenAI function 风格

远端源码 `/usr/lib/node_modules/openclaw/dist/pi-embedded-C6ITuRXf.js` 中：

- `normalizeKimiCodingToolDefinition()` 会把 Anthropic 风格工具：
  - `name`
  - `description`
  - `input_schema`
  转成：
  - `{ type: "function", function: { name, parameters } }`

源码注释原文也明确写到：

- `Kimi Coding's anthropic-messages endpoint expects OpenAI-style tool payloads`

因此需要严格区分两层：

#### 配置层

- **message API 类型**：`anthropic-messages`

#### 运行时请求层

- **tool schema**：OpenClaw 会把 Kimi tools 改写成 **OpenAI function 风格**

### 4. 远端实测：Anthropic 风格 tools 会成功，function 风格 tools 会失败

本轮在**正确远端机器**上做了两个最关键的对照实验：

#### 4.1 Anthropic 风格工具定义

请求：

- `messages` 走 Anthropic 风格
- `tools` 使用：
  - `name`
  - `description`
  - `input_schema`

结果：

- Kimi 返回标准：
  - `content[0].type = "tool_use"`
  - `stop_reason = "tool_use"`

#### 4.2 OpenAI function 风格工具定义

请求：

- `messages` 仍走 Anthropic 风格
- `tools` 改成：
  - `{ type: "function", function: { name, parameters } }`

结果：

- Kimi 不再返回结构化 `tool_use`
- 而是返回伪工具文本，例如：
  - `I'll call exec ...`
  - `<exec>printf hello</exec>`

### 5. 这与 dayong 的真实 payload 完全对上

本轮对远端 `dayong` 做隔离复现时：

- `openclaw agent --local` 在隔离目录里会超时挂住
- 但 payload logger 成功记下真实请求

而这份远端 `dayong` 的真实 payload 中：

- `tools[]` 正是 **OpenAI function 风格**

将这份 payload 直接打给 Kimi 时，返回的也是伪工具文本：

- `exec(command='printf hello')`

### 6. 最新收敛结论

截至本轮，在**正确远端环境**上的最准确结论是：

1. `main` / `dayong` 配置里的 Kimi，API 类型确实是 `anthropic-messages`
2. 但 OpenClaw 运行时会把 Kimi 的 `tools` 改写成 OpenAI function 风格
3. 在远端实测里：
   - Anthropic 风格工具定义 => Kimi 返回标准 `tool_use`
   - OpenAI function 风格工具定义 => Kimi 只返回伪工具文本

因此，当前最可疑的核心点已经从“message format”进一步收敛为：

- **OpenClaw 这层 Kimi tool schema wrapper 的假设，很可能与 Kimi 当前真实行为不一致**

### 7. `dayong` 不能只靠 `openclaw.json` 改成“真正的 Anthropic tools”

本轮继续核对了远端 OpenClaw 2026.3.7 源码，新增两个关键事实：

#### 7.1 `dayong` 配置其实已经是 Anthropic Messages

远端 `~/.openclaw-dayong/openclaw.json` 中，Kimi provider 当前 live 配置就是：

- `baseUrl = "https://api.kimi.com/coding"`
- `api = "anthropic-messages"`
- `defaults.model.primary = "kimi/k2p5"`

所以**改 `dayong` 配置文件本身，并不能让它“更 Anthropic”**，因为它现在配置层本来就是 Anthropic。

#### 7.2 真正把 tools 改坏的是共享运行时代码，而且没有 per-agent 开关

远端源码 `/usr/lib/node_modules/openclaw/dist/pi-embedded-C6ITuRXf.js` 中：

- `createKimiCodingAnthropicToolSchemaWrapper()` 会在 agent streamFn 上统一安装
- 安装位置约在：
  - `97081`
- 这不是 `dayong` 单独配置出来的，而是共享运行时逻辑

同时，本轮没有发现：

- `disableKimi...`
- `tool_schema...`
- `toolSchema...`
- 或任何能按 agent / provider 配置关闭这层 wrapper 的公开配置开关

所以当前结论非常直接：

- **无法只靠修改 `~/.openclaw-dayong/openclaw.json`，让 `dayong` 真正改回 Anthropic 风格 tools**
- 因为真正改写 tools 的不是配置，而是 `/usr/lib/node_modules/openclaw` 这套共享代码

### 8. 在“不碰 main”的前提下，真正可行的方案只剩两类

如果用户继续坚持：

- 只修 `dayong`
- 不碰 `main`
- 又要让 Kimi 真正吃到 Anthropic 风格 tools

那么现实可行的方案只剩：

#### 方案 A：dayong-only 代理绕过 wrapper

- 给 `dayong` 配一个本地反向代理
- `dayong.openclaw.json` 的 `baseUrl` 改成 `http://127.0.0.1:<port>/...`
- 让 OpenClaw 不再识别成 `kimi.com/coding`
- 从而不触发 `isKimiCodingAnthropicEndpoint()` 这层 wrapper

优点：

- 只影响 `dayong`
- 不改共享 OpenClaw 代码

缺点：

- 需要额外部署本地代理服务

#### 方案 B：给 dayong 单独拷一套 OpenClaw 并 patch

- 新装一份 dayong 专用 OpenClaw 到独立路径
- 只修改 dayong 那份运行时代码
- `openclaw-gateway-dayong.service` 指向独立二进制

优点：

- 逻辑最直接
- 可以精确只影响 `dayong`

缺点：

- 运维成本更高
- 升级时需要双份维护

#### 不推荐方案：直接 patch `/usr/lib/node_modules/openclaw`

这会同时影响：

- `main`
- `dayong`

与用户“不要动主 Gateway”的约束冲突。

---

## AI. Kimi 工具链只读深挖 v3（2026-03-10 16:15 CST）

### 1. 当前 live 环境与前文 dayong 记录不一致

本轮重新做实时扫描时发现，**当前 live WSL 环境并没有出现独立的 `~/.openclaw-dayong/`**。

实时可验证到的是：

- 只有 `~/.openclaw/`
- `~/.openclaw/openclaw.json` 当前只定义了 `main`
- `openclaw --version` 当前显示 `2026.2.26`
- OpenClaw 安装路径是：
  - `~/.npm-global/lib/node_modules/openclaw`

因此必须纠正一个边界：

- 前文关于 `~/.openclaw-dayong/*`、`openclaw-gateway-dayong.service` 的内容，**本轮不能再当作当前 live 环境事实**
- 它们仍可保留为历史排障记录，但不应继续和“这一次实时调研”混用

### 2. 当前 live 的 Kimi 接法

`~/.openclaw/openclaw.json` 当前 live 配置里，Kimi 是这样接的：

- provider 名：`kimi`
- `baseUrl = https://api.kimi.com/coding`
- `api = anthropic-messages`
- model id：`k2p5`
- 当前 `agents.defaults.model.primary = "kimi/k2p5"`
- fallback：`zai/glm-5 -> newcli/claude-opus-4-6`

也就是说，这轮最值得验证的，已经不再是“旧 dayong 独立 Gateway”，而是：

- **OpenClaw 当前这条自定义 `kimi + anthropic-messages + k2p5` live 接法，到底在哪个环节掉链子**

### 3. 隔离复现：当前 live Kimi 接法在 `/tmp/.cache` 最小环境中也会挂住

为了避免碰生产状态，本轮没有动 `main`，而是在：

- `/home/kevinlasnh/.cache/oc-kimi-research`

构造了一个最小隔离环境：

- 独立 `OPENCLAW_STATE_DIR`
- 独立 `OPENCLAW_CONFIG_PATH`
- 独立 workspace
- 仍使用当前 live 那套：
  - `kimi`
  - `anthropic-messages`
  - `https://api.kimi.com/coding`
  - `k2p5`

测试命令是：

- `openclaw agent --local --agent test --message "Mandatory: call the exec tool exactly once with command printf hello..." --json`

实测结果：

- 60 秒内没有完成，直接 timeout
- 但成功写出了：
  - `anthropic-payload.jsonl`

这说明：

- **就算完全脱离 Telegram / session 历史 / dayong 独立状态目录，这条 Kimi 工具链问题依旧存在**

因此可以继续排除：

- Telegram 会话缓存
- dayong 专属 workspace 提示词
- 独立 Gateway 进程状态

### 4. OpenClaw 真实发出的 payload 形状并没有明显协议错误

隔离复现中记录下来的真实请求 payload 关键字段如下：

- `model = "k2p5"`
- `stream = true`
- `messages = 1`
- `system = 1`
- `tools = 23`

更关键的是，tools 不是伪格式，而是**Anthropic 风格**：

- `name`
- `description`
- `input_schema`

其中 `exec` 工具也确实在 payload 里：

- `name = "exec"`
- `description` 合理
- `input_schema` 完整

因此，本轮可以明确排除一个误判：

- **不是因为 OpenClaw 根本没把 `exec` 工具带上请求**

### 5. 同一份 OpenClaw 真实 payload，直连 Kimi 可返回标准 `tool_use`

这轮最关键的新证据，是把 **OpenClaw payload logger 记下来的原始 payload** 拿出来，直接请求：

- `POST https://api.kimi.com/coding/v1/messages`

#### 5.1 控制组：极简 payload

用单个 `echo_tool` 做控制组时：

- 返回 `200`
- `content[0].type = "tool_use"`
- `stop_reason = "tool_use"`

这再次确认：

- `Kimi API` 本身支持工具调用

#### 5.2 实验组：OpenClaw 真实 payload，改成 `stream=false`

把 OpenClaw 真实生成的 payload 只做一处改动：

- `stream: true -> false`

然后直连 Kimi，返回：

- `200`
- `content[0].type = "tool_use"`
- `name = "exec"`
- `input.command = "printf hello"`
- `stop_reason = "tool_use"`

这说明：

- **OpenClaw 生成的 payload 本体是能让 Kimi 正常进入结构化工具调用的**

### 6. OpenClaw 同款 `stream=true` 请求，Kimi SSE 事件流也是标准的

为了排除“也许 Kimi 的 streaming 事件格式不标准”，本轮又把同一份 payload 保持：

- `stream = true`

直接请求 Kimi，得到的 SSE 头部是标准 Anthropic 风格：

- `event: message_start`
- `event: content_block_start`
  - `content_block.type = "tool_use"`
  - `name = "exec"`
- 多个 `content_block_delta`
  - `delta.type = "input_json_delta"`
- `event: message_delta`
  - `delta.stop_reason = "tool_use"`
- `event: message_stop`

因此可以继续排除：

- **不是因为 Kimi 的 streaming SSE 长得和 Anthropic 完全不一样**

### 7. Anthropic 两轮工具协议在 Kimi 上完整闭环

本轮还做了完整两轮闭环测试：

#### 第 1 轮

发送 OpenClaw 真实 payload（`stream=false`）：

- Kimi 返回：
  - `tool_use(exec)`
  - `input.command = "printf hello"`

#### 第 2 轮

按 Anthropic 协议追加：

- assistant：上一轮 `tool_use`
- user：`tool_result = hello`

结果：

- 返回 `200`
- `stop_reason = "end_turn"`
- 最终文本就是：
  - `"hello"`

这一步非常关键，因为它说明：

- **Kimi 在 `api.kimi.com/coding` 这条 anthropic-messages 路径下，整条“tool_use -> tool_result -> final text”工具协议是通的**

所以现在可以进一步排除：

- Kimi 只会第一轮 `tool_use`，不会第二轮收尾
- Kimi 的 `tool_result` 语义跟 Anthropic 不兼容

### 8. 根因进一步收敛：更像 OpenClaw 内部 streaming tool loop 卡住

把以上证据串起来，当前最准确的判断已经变成：

1. Kimi API 支持 tool use
2. OpenClaw 真实 payload 本体能触发 Kimi 的 `tool_use`
3. Kimi 的 streaming SSE 事件格式也是标准的
4. Kimi 的第二轮 `tool_result` 收尾也正常
5. 但 OpenClaw 自己的隔离 CLI 运行仍会挂住

因此，主根因最像是：

- **OpenClaw 在接收 Kimi 的 `tool_use` streaming 事件后，没有把内部 embedded tool loop 正常走完**

比“请求体不对”更准确的说法是：

- **问题更像出在 OpenClaw 的流式工具编排内部，而不是 Kimi 协议层**

### 9. 目前最值得盯的代码热点

本轮只读定位到的第一批热点在：

- `reply-Deht_wOB.js`
  - `handleToolExecutionStart`：约 `69812`
  - `handleToolExecutionEnd`：约 `69894`
  - `createEmbeddedPiSessionEventHandler`：约 `70011`
  - `handleMessageEnd`：约 `69231`

这说明 OpenClaw 自己的 embedded agent 路径里，明确存在这几个事件层：

- `message_start`
- `message_end`
- `tool_execution_start`
- `tool_execution_end`

下一轮真正修复时，最应该验证的是：

1. Kimi SSE 里的 `tool_use` 有没有真的被桥接成 `tool_execution_start`
2. `exec` 完成后，有没有真的触发第二轮 `tool_result` 续跑
3. 是否只有 `stream=true` 才会复现挂起

### 10. 当前最合理的修复路线

现在不建议继续把精力花在：

- prompt 厚度
- session 缓存
- tools 是否注入
- “Kimi 会不会工具调用”

因为这些层面，本轮已经有了更硬的排除证据。

更合理的修复路线是：

#### 路线 A：优先做 streaming 专项修复

直接查 OpenClaw 的 Kimi / anthropic stream 事件到内部 tool loop 的桥接。

优点：

- 这是正统修法
- 修完后保留 streaming 能力

#### 路线 B：先给 Kimi 工具调用加非流式兜底

对 `kimi + anthropic-messages + tools-present` 这条路径，优先走非流式 tool roundtrip。

理由：

- 当前已经验证：**同一 payload 的非流式两轮工具协议是通的**

优点：

- 更像工程绕行
- 可能最快恢复可用性

缺点：

- 这是 workaround，不是根治

截至本轮，最稳妥的判断是：

- **如果后面真要修，优先级应该是 “streaming tool loop” > “prompt/人格/skills”**

---

## AK. 主 Gateway Webhook 瞬时抖动诊断（2026-03-10 16:50 CST）

### 1. 结论先行

- **主小龙虾的 Telegram Webhook 当前是正常的。**
- 这次“网络抖动后不回消息”更像是：
  - `Tailscale Funnel / DERP` 路径发生了短时抖动
  - 导致 Telegram 入站延后数分钟
  - 不是 `openclaw-gateway` 服务挂掉，也不是 Webhook 配置丢失

### 2. 现场证据

#### 2.1 Telegram 侧登记正常

通过代理查询 `getWebhookInfo`，返回：

- `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- `pending_update_count = 0`
- 未见 `last_error_message`

这说明：

- Telegram 侧仍把主 bot 绑定到正确 Webhook
- 当前没有积压更新

#### 2.2 Funnel 和本地监听都还活着

实时状态：

- `tailscale funnel status`
  - `https://openclaw-24x7.tailda6e28.ts.net -> http://127.0.0.1:8787`
- `ss -ltnp`
  - `127.0.0.1:8787` 由 `openclaw-gateway` 监听

#### 2.3 Webhook 路由本身正常

两个很有用的判断点：

1. `GET https://.../telegram-webhook` 返回 `404`
   - 这是正常现象，因为 Telegram 调的是 `POST`
   - 说明公网入口能打到 OpenClaw
2. 本地 `POST http://127.0.0.1:8787/telegram-webhook`（不带 secret）返回 `401 unauthorized`
   - 这同样是好现象
   - 说明路由存在，且 secret 校验仍生效

因此：

- `404 on GET` 不代表 Webhook 坏了
- `401 on POST without secret` 反而能证明 Webhook handler 还活着

### 3. 最关键的时间线证据

主会话文件：

- `/home/kevinlasnh/.openclaw/agents/main/sessions/f54b9d93-4f29-4133-a958-3af95f81dd10.jsonl`

其中同一条真实 Telegram 消息显示：

- Telegram 元数据时间：`2026-03-10 16:41 CST`
- session 真正写入时间：`2026-03-10 16:46:27 CST`
- 随后 `sendMessage ok` 出现在：
  - `16:46:56`
  - `16:47:24`
  - `16:47:31`

这说明：

- 这条消息不是“没收到”
- 而是**晚了约 5 分钟才从入站链路送达 Gateway**

### 4. 同时段的网络侧根因线索

`tailscaled` 在 `16:43:50` 到 `16:47:02 CST` 之间出现多条异常：

- `derp.Recv ... i/o timeout`
- `PollNetMap ... connection reset by peer`
- `TLS handshake error ... connection reset by peer`
- `CreateEndpoint error ... operation timed out`
- 最后在 `16:47:02` 重新切到新的 endpoint

对照来看：

- `NetworkManager` 同时段没有异常
- `mihomo-standalone` 同时段仍能持续访问 `api.telegram.org:443`

更合理的归因是：

- **Tailscale / Funnel 入站链路瞬时抖动**
- 而不是本机主网络彻底断开
- 也不是 Telegram Bot API 出站代理挂掉

### 5. 后续排查优先级

如果用户再次反馈“Webhook 模式也突然几分钟不回”，建议按这个顺序查：

1. `getWebhookInfo`
   - 看 `pending_update_count`
   - 看 `last_error_message`
2. `tailscale funnel status`
   - 看 443 是否仍指向 `127.0.0.1:8787`
3. `journalctl -u tailscaled --since "..."`
   - 查 `derp timeout / PollNetMap reset / TLS handshake error`
4. 主 session 时间线
   - 对比 Telegram 消息元数据时间 vs session 写入时间

如果再次出现“消息元数据时间”和“session 写入时间”相差数分钟，而 Webhook 配置本身没变，优先怀疑：

- **Funnel / DERP 链路抖动，而不是 OpenClaw 配置损坏**

---

## AL. Webhook 公网暴露面与安全判断（2026-03-10 17:05 CST）

### 1. 先说结论

- **不能说“完全没有公网暴露”。**
- 因为只要用 **Telegram Webhook + Tailscale Funnel**，就意味着：
  - 至少有一个 HTTPS 入口是对公网开放的
  - 否则 Telegram 根本无法主动 POST 进来

但同时也要区分清楚：

- **暴露的是“特定入口”**
- 不是“整台电脑所有服务都直接裸露”

### 2. 当前实际暴露的是什么

实时配置与监听结果显示：

- `gateway.bind = "loopback"`
- `openclaw-gateway` 监听：
  - `127.0.0.1:18790`
  - `127.0.0.1:8787`
- `dayong` 监听：
  - `127.0.0.1:19021`
  - `127.0.0.1:8788`

也就是说：

- OpenClaw 自己的管理/API 端口没有绑定到 `0.0.0.0`
- webhook 本地端口也没有直接开放到局域网/公网

真正对公网可达的是 **Tailscale Funnel** 暴露出来的 HTTPS 入口：

- `https://openclaw-24x7.tailda6e28.ts.net/` → `127.0.0.1:8787`
- `https://openclaw-24x7.tailda6e28.ts.net:8443/` → `127.0.0.1:8788`

因此更准确的表述应该是：

- **不是主机原生公网监听**
- 而是 **Tailscale 代你把指定本地端口安全地发布成公网 HTTPS 入口**

### 3. 这台机器当前有没有“真公网 IP”

实时网卡结果：

- `wlp0s20f3 = 192.168.50.117/24`
- `tailscale0 = 100.64.65.65`

这说明从主机自身视角看：

- 当前物理网卡拿到的是 **私网地址** `192.168.50.117`
- Tailscale 拿到的是 **Tailnet 地址** `100.64.65.65`
- **机器本身当前没有直接绑定公网 IPv4**

所以目前不能说：

- “这台机器自身已经直接在公网裸奔”

### 4. Webhook 入口本身的安全性

当前主 Webhook 已验证：

- `GET /telegram-webhook` 返回 `404`
- 不带 secret 的 `POST /telegram-webhook` 返回 `401 unauthorized`

这说明：

1. webhook handler 仍在
2. 不是任意无鉴权 POST 都能直接通过
3. 至少还有一层 webhook secret 校验

所以从 OpenClaw 这一层看，当前不是“任何人随便访问就能直接调用主服务”。

### 5. 但有一个现实风险点：SSH 22 过宽

本轮最值得警惕的不是 OpenClaw 本身，而是：

- `sshd` 当前监听：
  - `0.0.0.0:22`
  - `[::]:22`
- UFW 当前规则：
  - `22/tcp ALLOW IN Anywhere`

这意味着：

- **从主机配置角度，SSH 并没有被限制到 Tailscale / 局域网**
- 只是因为当前主机还在私网地址后面，它未必真的能被互联网直接打到

但如果后面发生以下任一情况：

1. 路由器做了 `22` 端口转发
2. 主机被放进 DMZ
3. 运营商/网络环境让这台机器直接获得公网地址

那么：

- `22/tcp` 就会变成真正的公网 SSH 暴露面

### 6. 因此最准确的安全判断

#### 可以说“相对安全”的部分

- OpenClaw 主服务不直接绑公网
- Webhook 本地端口只在 loopback
- 对公网公开的是 Tailscale Funnel 的 HTTPS 入口，而不是原生 `8787/18790`
- webhook 请求还有 secret 校验

#### 不能说“完全没暴露”的部分

- Funnel 本身就是公网发布能力
- 当前 `443` 和 `8443` 入口确实是互联网可达

#### 当前最该收紧的地方

- `SSH :22` 的 UFW 规则太宽：
  - `ALLOW IN Anywhere`

### 7. 实务建议

如果用户的目标是：

- **保留 Telegram Webhook**
- 但尽量减少不必要的公网暴露

最合理的收紧顺序是：

1. 保留 Funnel 443（主 webhook 必需）
2. 如果 `dayong` 暂时不用，可关闭 Funnel 8443
3. 把 UFW 的 `22/tcp ALLOW IN Anywhere` 改成：
   - 仅允许 `100.64.0.0/10`（Tailscale）
   - 如有需要再加本地局域网网段
4. 若不需要传统 SSH 从公网直连，可直接禁止非 Tailscale 来源访问 22

### 8. 一句话总结

- **主机不是“整台裸露到公网”。**
- **但 Funnel 暴露的两个 HTTPS 入口本来就是公网可达的，这是 Webhook 正常工作的前提。**
- **当前真正偏松的配置点是 SSH 22 的防火墙规则，而不是 OpenClaw 的 loopback 绑定。**

---

## AM. 继续使用 Webhook 时的最小暴露面方案（2026-03-10 联网调研）

### 1. 官方资料确认的几个边界

#### 1.1 Funnel 的边界

Tailscale 官方文档当前明确写到：

- Funnel 的用途就是把本地资源暴露给 **public internet**
- Funnel 只支持：
  - `443`
  - `8443`
  - `10000`
- 如果某个端口最近一次被配置成 `funnel`，那它就是 **public**
- 如果最近一次被配置成 `serve`，那它就是 **private**

这意味着：

- **只要继续使用 Funnel，就一定会保留至少一个公网入口**
- 真正能做的是把暴露面压到**最小、最窄、最难滥用**

#### 1.2 Telegram Webhook 的边界

Telegram 官方 Bot API 当前确认：

- webhook 可以配置：
  - `secret_token`
  - `max_connections`
  - `allowed_updates`
- Telegram 在 webhook 请求里会带：
  - `X-Telegram-Bot-Api-Secret-Token`
- Telegram 官方 webhook 端口限制仍是：
  - `443`
  - `80`
  - `88`
  - `8443`

另外 Telegram 的 webhook 指南还提到：

- 如果你要只允许 Telegram 的来源 IP，可以只放行：
  - `149.154.160.0/20`
  - `91.108.4.0/22`

但这里要注意一个**关键推论**：

- 你现在走的是 **Tailscale Funnel**
- 按 Tailscale 文档，公网请求先到 Funnel relay，再通过加密 TCP proxy 送到你的设备
- 所以从你机器本地防火墙的角度，看到的并不是 Telegram 直连源地址

因此：

- **在 Funnel 架构下，依靠 UFW 直接按 Telegram IP 白名单来限流/限源，现实中并不好做**
- 这时更应依赖：
  - 精确路径
  - webhook secret
  - 反向代理的 method/path/header 限制

### 2. 适合你当前机器的方案排序

#### 方案 A：保留 Funnel，但把公网入口收口到 1 个端口 + 2 条精确路径（推荐）

这是我认为你当前最均衡的方案。

做法：

1. 只保留 **一个公网 Funnel 443**
2. 不再让 `8443` 单独公开
3. 在本机 loopback 上放一个很薄的反向代理（例如 nginx / caddy）
4. 这个代理只暴露两条精确路径：
   - `/main-telegram-webhook` -> `127.0.0.1:8787`
   - `/dayong-telegram-webhook` -> `127.0.0.1:8788`
5. 其他所有路径：
   - 直接 `404` / `444`
6. 只允许 `POST`
7. 可选：在代理层再校验一次 `X-Telegram-Bot-Api-Secret-Token`

优点：

- 公网入口从 `443 + 8443` 收缩成只剩 `443`
- 外部看不到 OpenClaw 的本地端口结构
- 非 webhook 路径在代理层就被截断，不再落到 OpenClaw
- 两个 Gateway 仍可继续用 Webhook

这是典型的“**公网只放一个极薄 ingress，业务服务继续全绑 loopback**”做法。

#### 方案 B：继续用 Funnel，但不用额外代理，改成 Tailscale 路径挂载

Tailscale 当前文档说明 `tailscale serve` 支持 `--set-path`，路径匹配行为类似 Go `ServeMux`。

所以理论上可以把公网入口改成类似：

- `https://.../main-telegram-webhook`
- `https://.../dayong-telegram-webhook`

而不是现在这种：

- `443 -> 整个 8787`
- `8443 -> 整个 8788`

这条路的优点是：

- 少一层 nginx/caddy

但我当前更推荐 **方案 A**，因为：

- 反向代理能更明确地做：
  - 只允许 `POST`
  - 只放指定 path
  - 额外 header 校验
  - 速率限制
- 工程可控性更高

#### 方案 C：把公网入口彻底移出这台电脑（最安全）

如果你的目标是：

- “小龙虾继续用 Webhook”
- “但这台日常电脑尽量不要承担公网入口角色”

那最强方案是：

1. 单独放一个极小的公网 ingress 节点
   - 例如小 VPS / 另一台专用机
2. 这个 ingress 只做：
   - HTTPS
   - webhook path
   - secret/header 校验
   - 反代到 Tailscale 内网里的 OpenClaw 主机
3. 你的 OpenClaw 主机只接受来自 tailnet 的内部流量

优点：

- 就算公网 webhook 节点被扫、被打、被压测
- 也不会直接把“主工作机/主电脑”暴露在第一线

缺点：

- 多一台机器
- 运维复杂度增加

### 3. 不管选哪条路，都应该立刻做的收紧项

#### 3.1 收紧 SSH 22

这是当前最值得先改的点。

你现在现场状态是：

- `sshd` 监听 `0.0.0.0:22` / `[::]:22`
- UFW 有：
  - `22/tcp ALLOW IN Anywhere`

更合理的做法是：

1. 删除 `ALLOW IN Anywhere` 的 22 规则
2. 改成只允许：
   - `100.64.0.0/10`（Tailscale）
   - 如确有需要，再加你当前局域网段 `192.168.50.0/24`
3. SSH 改成：
   - `PasswordAuthentication no`
   - `KbdInteractiveAuthentication no`
   - `PubkeyAuthentication yes`
   - `PermitRootLogin no`
   - `AllowUsers kevinlasnh`

如果你愿意进一步收口，还可以：

- 直接主要使用 **Tailscale SSH**
- 或让 OpenSSH 只接受来自 Tailscale / LAN 的连接

#### 3.2 保留 webhook secret，并把它当主鉴权

Telegram 官方 `secret_token` 是当前最适合你架构的第一层鉴权。

你这里已经启用 `webhookSecret`，这是对的，应该继续保留。

如果后面加反向代理，建议：

- 在代理层也检查 `X-Telegram-Bot-Api-Secret-Token`
- 不匹配就直接拒绝

#### 3.3 缩小 Telegram webhook 能进来的更新类型

Telegram 官方 `allowed_updates` 可以限制你实际接收的更新种类。

如果你现在主要只用私聊消息，就没必要长期开一大堆无关更新类型。

这不会减少“公网暴露”本身，但会减少：

- 不必要的入站负载
- 异常输入面

#### 3.4 适度降低 `max_connections`

Telegram 官方默认 `max_connections=40`。

对你这种两个私人 bot 的场景，这个值通常不需要那么高。

适当调低可以降低并发冲击面。

这更偏“稳态与负载控制”，不是核心安全项，但有价值。

### 4. 我给你的实际建议

如果按“收益/风险/改动量”排序，我建议是：

1. **先立刻收紧 SSH 22**
   - 这是当前最明显的安全松口
2. **把两个公网 Funnel 收缩成 1 个**
   - 最好统一到 `443`
3. **在本机 loopback 上加一个极薄反向代理**
   - 只放两条 webhook path
   - 其他一律拒绝
4. **继续保留 OpenClaw 本体全部 loopback 绑定**
5. **保留 Telegram webhook secret**
6. **收窄 `allowed_updates`，并考虑降低 `max_connections`**

### 5. 最终判断

对你当前这台机器来说，**不需要为了安全放弃 Webhook**。

真正合理的目标不是：

- “完全没有公网入口”

而是：

- **只保留 webhook 这一个必要公网入口**
- **入口尽可能薄**
- **业务端口不直接暴露**
- **SSH 不再对 Anywhere 放开**

如果按这个方向收口，整体安全性会比“裸开公网端口 + 直绑业务服务”高很多，而且还能继续享受 Webhook 的低延迟。

---

## AN. SSH 公网入口第一阶段收紧（2026-03-13）

### 1. 已落地的最小安全修复

本轮已经先做了一个**不会影响 Webhook**、但能立刻降低公网风险的动作：

- 删除 UFW 中这两条规则：
  - `22/tcp ALLOW IN Anywhere`
  - `22/tcp (v6) ALLOW IN Anywhere (v6)`

删除后保留的来源只有：

- `192.168.50.0/24`
- `100.64.0.0/10`

因此当前状态变成：

- **SSH 不再对任意公网来源开放**
- 仍允许：
  - 本地局域网
  - Tailscale tailnet

### 2. 为什么这一步不会影响 Webhook

因为你当前 Webhook 走的是：

- `Tailscale Funnel 443 -> 127.0.0.1:8787`
- `Tailscale Funnel 8443 -> 127.0.0.1:8788`

而不是：

- 公网直连 `22`

所以：

- 收紧 `SSH 22` 的 UFW 规则
- **不会影响 Telegram Webhook 收消息**
- 也不会影响 `openclaw-gateway` 的 loopback 监听

### 3. 当前风险已经降到什么程度

本轮之后，最危险的那个状态已经结束了：

- 之前：只要网络层能打到这台机器，`22` 就是开放的
- 现在：只有
  - `192.168.50.0/24`
  - `100.64.0.0/10`
  才能继续打 `SSH`

这意味着：

- 即使以后用户环境真的有公网入口变化
- 也不再是“任何公网来源都能直接碰 22”

### 4. 剩余还能继续做的第二阶段加固

本轮实时生效的 `sshd -T` 仍显示：

- `passwordauthentication yes`
- `pubkeyauthentication yes`
- `permitrootlogin without-password`

所以如果要继续第二阶段收紧，最合理的是：

1. `PasswordAuthentication no`
2. `KbdInteractiveAuthentication no`（已是 `no`）
3. `PubkeyAuthentication yes`
4. `PermitRootLogin no`
5. 如确认无副作用，再加：
   - `AllowUsers kevinlasnh`

### 5. 推荐的实际节奏

对当前线上环境，最稳妥的顺序是：

1. **先做 UFW 收口**（本轮已完成）
2. 观察 Tailscale SSH / 局域网 SSH 是否完全正常
3. 再做 `sshd_config` 的认证层收紧

这样做的好处是：

- 先挡掉最大暴露面
- 再逐步收紧认证
- 不会一下子把自己锁死

## AL. 主 Agent 与 dayong 的 Kimi 差异，核心是“版本时序 + 实际命中模型”，不是人格（2026-03-10 17:20 CST）

### 1. 两个 Gateway 现在确实共享同一套代码

远端外星人机实时复核结果：

- `openclaw-gateway.service`
  - `ExecStart=/usr/bin/openclaw gateway run --port 18790`
- `openclaw-gateway-dayong.service`
  - `ExecStart=/usr/bin/openclaw gateway run --port 19021`
- `/usr/bin/openclaw -> /usr/lib/node_modules/openclaw/dist/index.js`
- 当前 `openclaw --version = 2026.3.7`

所以这一步可以定性：

- **不是两个 Gateway 各自跑不同版本的 OpenClaw**
- **而是同一个共享安装，通过不同 state/config 目录做隔离**

### 2. 用户记忆“主 Agent 的 Kimi 以前能正常调工具”是对的

远端主状态目录里，历史 session 还留着多份成功样本。

最有代表性的样本：

- `~/.openclaw/agents/main/sessions/93fae218-1087-4184-b7e2-e885686e791c.jsonl.reset.2026-03-08T16-31-56.801Z`

其中可直接看到：

- `provider = kimi`
- `model = k2p5`
- 真正的 `toolCall(web_search)`
- 紧跟着 `toolResult`

而且同一份 session 里还有状态文本：

- `OpenClaw 2026.3.2 (85377a2)`

这说明：

- **主 Agent 在 2026-03-08 这批会话里，的确曾经用 Kimi 正常跑过结构化工具调用**

### 3. 当前 main 为什么“看起来没坏”

当前 live 主配置：

- `main.primary = minimax/MiniMax-M2.5`
- `main.fallbacks = [kimi/k2p5, zai/glm-5, newcli/claude-opus-4-6]`

再看 `2026-03-09` 之后的最新主 session：

- `~/.openclaw/agents/main/sessions/61e848f2-d7f9-4a3c-b042-f8ccc476d1b6.jsonl`
- `~/.openclaw/agents/main/sessions/9da26c19-8e65-42bb-ba1d-7cd752845546.jsonl`
- 以及同批 `.deleted/.reset` 文件

里面反复出现的都是：

- `provider = minimax`
- `model = MiniMax-M2.5`
- `OpenClaw 2026.3.7 (42a1394)`

所以：

- **用户现在觉得 main 没有暴露 Kimi 工具故障，主要不是因为 main 的 Kimi 特别健康**
- **而是因为 main 当前大多数实际请求并没有命中 Kimi，而是停在了 MiniMax 主模型**

### 4. dayong 为什么问题暴露得更直接

`dayong` 当前 live 配置里：

- `primary = kimi/k2p5`

而它的真实 session 样本：

- `~/.openclaw-dayong/agents/dayong/sessions.backup-20260310-143543/1381a73b-d170-4141-8a40-8da2f54665e0.jsonl`

能直接看到：

- `provider = kimi`
- `model = k2p5`
- 回复 `/exec({"command": "pwd"})`
- 回复 `/exec({"command": "cat /proc/sys/kernel/random/uuid"})`
- 没有真实 `toolCall / toolResult`

所以：

- **dayong 不是“比 main 更笨”**
- **而是它把当前坏掉的 Kimi 路径当主模型在跑，所以症状被放大并稳定暴露**

### 5. 时间线最像一次版本回归

目前手上的时间线证据是：

- 最新可确认的主 Agent Kimi 成功工具样本：
  - `2026-03-08`
- 这些样本内部状态文本显示：
  - `OpenClaw 2026.3.2`
- 当前共享安装目录修改时间：
  - `/usr/lib/node_modules/openclaw = 2026-03-09 02:22`
- 当前 live 版本：
  - `2026.3.7`
- `dayong` 的 Kimi 失败样本集中在：
  - `2026-03-09` 到 `2026-03-10`

因此当前最合理的工程判断是：

- **Kimi 工具调用回归更像发生在 `2026.3.2 -> 2026.3.7` 这一轮升级之后**

这是根据时间线和行为证据做出的推断，不是源码 diff 已证实的结论。

### 6. 隔离复现进一步支持“共享 Kimi 路径已坏”

本轮还做了一个只读隔离复现：

- 基于主 `~/.openclaw/openclaw.json` 复制到临时目录
- 只改：
  - `primary = kimi/k2p5`
- 不碰生产 service / 不碰主 state

结果：

- `openclaw agent --local --agent main ...`
- 在 75 秒内挂住超时

这说明：

- **如果把主 Agent 当前也强行打到 Kimi 路径，它并不会天然比 dayong 健康**
- 当前更像是：
  - **共享运行时代码里的 Kimi 路径有问题**
  - 只是 main 平时大多数时候没命中这条路

### 7. 这轮对“问题归因”的更新

先前“人格 / SOUL / AGENTS / skills 薄厚”这条线仍然能解释一部分表现差异，但现在优先级必须下调。

更准确的排序应该是：

1. **第一层**
   - 版本/运行时回归
   - 当前共享 Kimi 执行路径疑似坏了
2. **第二层**
   - main 实际常跑 MiniMax
   - dayong 实际常跑 Kimi
3. **第三层**
   - workspace/skills/memory 厚度差
   - 这些会影响“聪明程度”，但解释不了“结构化 toolCall 消失”这种硬故障

### 8. 当前一句话结论

- **用户看到的不是“同一版代码下 main 很聪明、dayong 很蠢”的单纯人格差异。**
- **更接近事实的是：主 Agent 曾在 `2026.3.2` 下用 Kimi 正常调过工具；现在共享代码已升级到 `2026.3.7`，`dayong` 因为把 Kimi 当主模型而率先稳定暴露出当前 Kimi 工具链回归，而 main 近期主要跑 MiniMax，所以看起来没出同样的问题。**

## AM. 主小龙虾“切回 MiniMax”这次其实不需要改配置（2026-03-10 17:38 CST）

### 1. 主配置当前已经是 MiniMax

远端实时读取：

- `~/.openclaw/openclaw.json`

其中：

- `agents.defaults.model.primary = minimax/MiniMax-M2.5`
- `fallbacks = [kimi/k2p5, zai/glm-5, newcli/claude-opus-4-6]`

所以：

- **从配置文件角度，主小龙虾并没有继续卡在 Kimi 上**

### 2. 主会话层当前也已经是 MiniMax

远端 `sessions.json` 与最近主 session 抽样结果显示：

- `agent:main:main`
  - `MODEL = MiniMax-M2.5`
- `agent:main:telegram:default:direct:8226087994`
  - `MODEL = MiniMax-M2.5`
- 最近主 session 样本：
  - `f54b9d93-...jsonl`
  - `61e848f2-...jsonl`
  - `9da26c19-...jsonl`
  都显示：
  - `provider = minimax`
  - `model = MiniMax-M2.5`

所以：

- **从当前主会话状态看，也不是还挂在 Kimi 上**

### 3. 这次真正需要做的是“刷新 runtime”，不是“再改模型”

用户反馈“刚把主小龙虾设到 Kimi 后不工作”，但到本轮执行时，主配置和主会话都已经回到 MiniMax。

因此本轮最合理动作是：

- **不去重复改配置**
- 只对主 Gateway 做一次重启刷新

执行：

- `systemctl --user restart openclaw-gateway`

结果：

- `openclaw-gateway.service = active (running)`
- 新启动时间：
  - `2026-03-10 17:37:36 CST`
- `openclaw gateway health = OK`
- Telegram webhook 仍正常

### 4. 这次恢复动作的边界

- 只动了：
  - `main`
- 没有动：
  - `dayong`
- 没有改：
  - 主配置文件内容
- 没有触碰：
  - 共享 Kimi 回归问题本身

### 5. 当前一句话结论

- **主小龙虾现在已经处于 MiniMax 配置与 MiniMax 会话状态。**
- **这次做的是主 Gateway 重启刷新，不是重新改模型。**

---

## AI. OpenClaw 2026.3.7 Kimi 工具调用回归 Bug 与源码补丁（2026-03-10 晚 ✅）

### 1. Bug 确认

| 来源 | 信息 |
|------|------|
| Reddit | `2026.3.7 breaks Kimi tool calls` |
| GitHub Issue #41852 | `kimi-coding provider forces OpenAI tool format, breaks Kimi k2p5 tool_use` |
| 影响版本 | 2026.3.7 |
| 2026.3.8 是否修复 | 否（issue 仍 open） |
| 社区建议 | 降级到 2026.3.2 |

### 2. 根因代码

```javascript
// 文件：reply-C5LKjXcC.js 等 10 个文件
// 注释原文："Kimi Coding's anthropic-messages endpoint expects OpenAI-style tool payloads"
// 实际情况：Kimi API 原生支持 Anthropic 格式，这个注释是错的

function isKimiCodingAnthropicEndpoint(model) {
    if (model.api !== "anthropic-messages") return false;
    if (typeof model.provider === "string" && model.provider.trim().toLowerCase() === "kimi-coding") return true;
    // ... 或检测 baseUrl 包含 kimi.com/coding ...
}

function normalizeKimiCodingToolDefinition(tool) {
    // 把 Anthropic 格式 { name, input_schema }
    // 转成 OpenAI 格式 { type: "function", function: { name, parameters } }
}

function createKimiCodingAnthropicToolSchemaWrapper(baseStreamFn) {
    // 在发送请求前拦截 payload，对 tools[] 执行 normalizeKimiCodingToolDefinition
}
```

### 3. API 直测证据

用同一份 API Key 直接请求 `https://api.kimi.com/coding/v1/messages`：

**Anthropic 原生格式**（正确）：
```json
{ "tools": [{ "name": "calc", "input_schema": { "type": "object", ... } }] }
// → 返回 tool_use, stop_reason="tool_use", input_tokens=62
```

**OpenAI function 格式**（被 OpenClaw wrapper 转换后）：
```json
{ "tools": [{ "type": "function", "function": { "name": "calc", "parameters": { ... } } }] }
// → 返回 "I don't have a calculator tool", input_tokens=21
```

`input_tokens` 差异（62 vs 21）证明 Kimi 直接丢弃了 OpenAI function 格式的工具定义。

### 4. 补丁方案

```javascript
// 让检测函数永远返回 false，跳过整个转换
function isKimiCodingAnthropicEndpoint(model) { return false;
```

### 5. 补丁文件清单（10 个）

```
dist/compact-B247y5Qt.js
dist/pi-embedded-C6ITuRXf.js
dist/pi-embedded-DoQsYfIY.js
dist/reply-C5LKjXcC.js
dist/plugin-sdk/dispatch-BP0viZiL.js
dist/plugin-sdk/dispatch-CQsjmw7g.js
dist/plugin-sdk/dispatch-Cerq29sy.js
dist/plugin-sdk/dispatch-Cndjtt0g.js
dist/plugin-sdk/dispatch-UogiJYul.js
dist/plugin-sdk/reply-DbZnH8-h.js
```

### 6. 补丁命令（升级后需重打）

```bash
for f in \
  /usr/lib/node_modules/openclaw/dist/compact-B247y5Qt.js \
  /usr/lib/node_modules/openclaw/dist/pi-embedded-C6ITuRXf.js \
  /usr/lib/node_modules/openclaw/dist/pi-embedded-DoQsYfIY.js \
  /usr/lib/node_modules/openclaw/dist/reply-C5LKjXcC.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-BP0viZiL.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-CQsjmw7g.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-Cerq29sy.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-Cndjtt0g.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/dispatch-UogiJYul.js \
  /usr/lib/node_modules/openclaw/dist/plugin-sdk/reply-DbZnH8-h.js; do
  sudo sed -i 's/function isKimiCodingAnthropicEndpoint(model) {/function isKimiCodingAnthropicEndpoint(model) { return false;/' "$f"
done
```

### 7. 注意事项

- 补丁对非 Kimi 模型（MiniMax、GLM 等）完全无影响
- 补丁在 OpenClaw 升级后会被覆盖，需重新执行上述命令
- 文件名中的 hash 后缀（如 `C5LKjXcC`）在新版本中可能不同，需用 `grep -rn "function isKimiCodingAnthropicEndpoint"` 重新定位
- 打完补丁后需重启使用 Kimi 的 Gateway

---

## AN. 主 Gateway .env 被小龙虾自删 MINIMAX_API_KEY 事故（2026-03-11 凌晨 ✅）

### 现象
- 主 Gateway 在 `2026-03-11 00:01` 进入 crash loop
- 日志：`missing env var "MINIMAX_API_KEY"` → `Gateway failed to start`
- dayong Gateway 不受影响（正常运行）

### 根因
- `~/.openclaw/.env` 在 `23:42` 被修改，`MINIMAX_API_KEY` 行被删除
- `.env` 内容只剩 4 行（KIMI + BRAVE + GOOGLE + TELEGRAM_BOT_TOKEN）
- 推测是主小龙虾自己通过 `exec` 工具修改了 `.env`
- 证据：2 个 session 文件（`c479bc24` / `d884f59e`）grep 出 `.env` 相关内容

### 修复
```bash
# 从备份配置找到原始 key
grep "MINIMAX_API_KEY" ~/.openclaw/openclaw.json.bak-rename-default
# → "MINIMAX_API_KEY": "sk-cp-2bPrxCo383eS4kl9nKW4mEVD-PUfNmQyEWn-0H49XWVO8Md6WgGQAkWdsNxDKjDSvzTFR0zukWLKbT5siYFKQI1wl0VWGQur-Mc7IaBE_aOvmnZcqlzgShg"

echo "MINIMAX_API_KEY=sk-cp-..." >> ~/.openclaw/.env
systemctl --user restart openclaw-gateway
```

### 教训与防护
1. **小龙虾有 `tools.exec.security = full` 权限**，可以修改自己的 `.env`
2. 防护方案（可选）：
   - 在 AGENTS.md 加护栏："永远不要修改 ~/.openclaw/.env 文件"
   - 给 `.env` 设 `chmod 444`（只读），systemd 仍可读取
   - 但注意：若小龙虾有 sudo 或写权限的工具，仍可绕过
3. **关键备份位置**：`~/.openclaw/openclaw.json.bak-rename-default` 包含所有历史 API Key

---

## AO. Chunyan（妈妈）Gateway 飞书 + Kimi 完整部署方案（2026-03-11 调研完成）

### 架构概览

```
飞书 App (WebSocket长连接) → chunyan Gateway (port 19001) → Kimi k2p5
```

- **不需要 Tailscale Funnel**（WebSocket 从 Gateway 主动外连，不需要公网入站端口）
- **不需要 Telegram**

### 1. 飞书凭证（已齐全）

| 凭证 | 值 | 来源 |
|------|------|------|
| App ID | `cli_a92651d8d7f81bc0` | task_plan.md / findings.md G |
| App Secret | `OmhOdKHCza3aSsaGk4r7bep6znongv5W` | `openclaw.json.bak-rename-default` |
| Bot Name | `mom openclaw` | 飞书后台 |
| Bot open_id | `ou_313199180caa7b890a9ccd668293c0e8` | task_plan.md |
| 妈妈 open_id | `ou_e4c865918d1b26e9ff11a09034e08970` | findings.md I |
| kevinlasnh open_id | `ou_d73c015003d3e69979f59312904a6caf` | findings.md I |

### 2. `.env` 文件

```bash
# ~/.openclaw-chunyan/.env
KIMI_API_KEY=sk-kimi-mXbnU5ajGXkrizwkB0otyy190dwz4J3qRWB2RoOczvnROTaDfpyC8SBDNzmvPaN0
BRAVE_API_KEY=BSAWwcmyNzLs78wv-Tld55WLYC6m-kr
GOOGLE_API_KEY=AIzaSyDvKmliF08YFBP9cwHvGXuUz3PcjuipPEI
```

### 3. `chunyan.json` 完整配置

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "kimi": {
        "baseUrl": "https://api.kimi.com/coding",
        "apiKey": "${KIMI_API_KEY}",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "k2p5",
            "name": "Kimi K2.5 (Coding)",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 8192
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "workspace": "/home/kevinlasnh/.openclaw-chunyan/workspace",
      "model": {
        "primary": "kimi/k2p5"
      },
      "blockStreamingDefault": "on",
      "blockStreamingBreak": "message_end",
      "blockStreamingChunk": {
        "minChars": 500,
        "maxChars": 4000,
        "breakPreference": "paragraph"
      },
      "blockStreamingCoalesce": {
        "idleMs": 5000
      },
      "verboseDefault": "on"
    },
    "list": [
      {
        "id": "chunyan",
        "default": true,
        "workspace": "/home/kevinlasnh/.openclaw-chunyan/workspace",
        "agentDir": "/home/kevinlasnh/.openclaw-chunyan/agents/chunyan/agent"
      }
    ]
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "domain": "feishu",
      "connectionMode": "websocket",
      "defaultAccount": "mom-feishu",
      "accounts": {
        "mom-feishu": {
          "appId": "cli_a92651d8d7f81bc0",
          "appSecret": "OmhOdKHCza3aSsaGk4r7bep6znongv5W",
          "botName": "mom openclaw",
          "dmPolicy": "allowlist",
          "allowFrom": ["ou_e4c865918d1b26e9ff11a09034e08970"],
          "typingIndicator": false,
          "resolveSenderNames": false,
          "streaming": false,
          "blockStreaming": false
        }
      }
    }
  },
  "plugins": {
    "entries": {
      "feishu": {
        "enabled": true
      }
    }
  },
  "gateway": {
    "port": 19001,
    "bind": "loopback"
  },
  "bindings": [
    {
      "agentId": "chunyan",
      "match": {
        "channel": "feishu",
        "accountId": "mom-feishu"
      }
    }
  ]
}
```

### 4. systemd service

```ini
# ~/.config/systemd/user/openclaw-gateway-chunyan.service
[Unit]
Description=OpenClaw Gateway - Chunyan (port 19001)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/openclaw gateway run --port 19001
Restart=always
RestartSec=5
KillMode=process
EnvironmentFile=/home/kevinlasnh/.openclaw-chunyan/.env
Environment=OPENCLAW_STATE_DIR=/home/kevinlasnh/.openclaw-chunyan
Environment=OPENCLAW_CONFIG_PATH=/home/kevinlasnh/.openclaw-chunyan/chunyan.json
Environment=HTTPS_PROXY=http://127.0.0.1:7897
Environment=HTTP_PROXY=http://127.0.0.1:7897
Environment=HOME=/home/kevinlasnh
Environment=TMPDIR=/tmp
Environment=PATH=/home/kevinlasnh/.local/bin:/home/kevinlasnh/.npm-global/bin:/home/kevinlasnh/bin:/home/kevinlasnh/.volta/bin:/home/kevinlasnh/.asdf/shims:/home/kevinlasnh/.bun/bin:/home/kevinlasnh/.nvm/current/bin:/home/kevinlasnh/.fnm/current/bin:/home/kevinlasnh/.local/share/pnpm:/usr/local/bin:/usr/bin:/bin
Environment=OPENCLAW_GATEWAY_PORT=19001
Environment=OPENCLAW_SYSTEMD_UNIT=openclaw-gateway-chunyan.service
Environment=OPENCLAW_SERVICE_MARKER=openclaw
Environment=OPENCLAW_SERVICE_KIND=gateway
Environment=OPENCLAW_SERVICE_VERSION=2026.3.7

[Install]
WantedBy=default.target
```

### 5. 部署执行步骤

```bash
# Step 1: 创建 .env
cat > ~/.openclaw-chunyan/.env << 'EOF'
KIMI_API_KEY=sk-kimi-mXbnU5ajGXkrizwkB0otyy190dwz4J3qRWB2RoOczvnROTaDfpyC8SBDNzmvPaN0
BRAVE_API_KEY=BSAWwcmyNzLs78wv-Tld55WLYC6m-kr
GOOGLE_API_KEY=AIzaSyDvKmliF08YFBP9cwHvGXuUz3PcjuipPEI
EOF
chmod 600 ~/.openclaw-chunyan/.env

# Step 2: 写入 chunyan.json（见上方完整 JSON）

# Step 3: 创建 systemd service（见上方完整 INI）
# systemctl --user daemon-reload
# systemctl --user enable openclaw-gateway-chunyan
# systemctl --user start openclaw-gateway-chunyan

# Step 4: 验证
# systemctl --user status openclaw-gateway-chunyan
# openclaw gateway health  （需设 OPENCLAW_STATE_DIR / OPENCLAW_CONFIG_PATH）
```

### 6. 飞书平台侧操作

1. 进入飞书开放平台 → 应用 `cli_a92651d8d7f81bc0`
2. 确认机器人能力已开启
3. 确认事件订阅 → 使用"长连接接收事件"
4. 确认已订阅 `im.message.receive_v1` 事件
5. 确认机器人消息权限（`im:message:send_as_bot`、`im:message:readonly`）
6. **重要**：先启动 Gateway，WebSocket 连接成功后再保存事件订阅配置

### 7. 飞书配置最佳实践（经验教训汇总）

| 实践 | 原因 | 参考 |
|------|------|------|
| `dmPolicy: "allowlist"` | `"any"` 不是合法值，会拦截所有消息 | findings.md H |
| `streaming: false` | 流式容易导致"打字但不回消息" | findings.md A |
| `blockStreaming: false` | 避免 block-only 回包被通道层丢弃 | findings.md A |
| `resolveSenderNames: false` | 避免 contact API 权限报错 | findings.md A |
| `typingIndicator: false` | 排查阶段建议关闭，稳定后可开启 | findings.md A |
| 不装第三方飞书插件 | 会与内置插件冲突 `duplicate plugin id` | 联网调研 |
| 先启 Gateway 再保存事件订阅 | 否则飞书平台报"连接未检测到" | 联网调研 |

### 8. 与 dayong 的关键差异

| 项目 | dayong | chunyan |
|------|--------|---------|
| 通道 | Telegram（Webhook） | 飞书（WebSocket） |
| 需要 Tailscale Funnel | ✅ 需要（端口 8443） | ❌ 不需要 |
| 模型 | kimi/k2p5 | kimi/k2p5 |
| Gateway 端口 | 19021 | 19001 |
| Bot | @openclaw_BigA_winner_bot | mom openclaw（飞书） |

## AP. 远端 Ubuntu 内存 6.3 GiB 的真实构成（2026-03-11）

### 1. 总体判断

远端主机 `100.64.65.65` 当时 `free -h` 显示：

- `Mem total = 15 GiB`
- `used = 6.3 GiB`
- `available = 9.0 GiB`
- `buff/cache = 9.4 GiB`

这说明：

- **看起来“已用 6.x GiB”并不代表机器快没内存**
- Linux 仍有 **9.0 GiB 可直接分配**
- 当时不存在 swap 压力（`Swap used = 0`）

### 2. 最大异常项不是 Gateway，而是系统监视器自己

按 RSS 排序的前几项：

| 进程 | RSS | 备注 |
|------|-----|------|
| `gnome-system-monitor` | **2.86 GiB anon / 2.99 GiB RSS** | 明显异常，已连续运行约 2 天 20 小时 |
| `openclaw-gateway`（main） | 585 MiB RSS | 主 Gateway |
| `openclaw-gateway`（dayong） | 467 MiB RSS | dayong Gateway |
| `gnome-shell` | 347 MiB RSS | GNOME 桌面壳 |
| `Xorg` | 192 MiB RSS | 图形服务 |
| `systemd-journald` | 158 MiB RSS | 日志服务 |

进一步读取 `/proc/89372/status` 可见：

- `VmRSS = 2997444 kB`
- `RssAnon = 2869288 kB`
- `VmData = 2988628 kB`
- `VmSwap = 0`

这表明：

- **系统监视器占用的 3 GiB 不是共享映射虚高，而是真实匿名内存**
- 更像是长期不关闭后发生了内存泄漏或持续累积

### 3. 除去“两个 Gateway + 代理 + 系统监视器”后，剩余大户

| 进程 | RSS |
|------|-----|
| `gnome-shell` | 347 MiB |
| `Xorg` | 192 MiB |
| `systemd-journald` | 158 MiB |
| `mutter-x11-frames` | 143 MiB |
| `xdg-desktop-portal-gnome` | 128 MiB |
| `snapd-desktop-integration` | 123 MiB |
| `dockerd` | 82 MiB |
| `gjs`（DING 扩展） | 70 MiB |
| `evolution-alarm-notify` | 65 MiB |
| `tailscaled` | 64 MiB |

### 4. 实际结论

- **真正最不正常的内存占用是 `gnome-system-monitor` 本身**
- 两个 Gateway 合计大约 `1.0 ~ 1.3 GiB`，属于当前多 Gateway 场景下可理解范围
- 代理 `verge-mihomo` 只有约 `25 ~ 52 MiB`，不是问题来源
- 如果关掉或重启 `gnome-system-monitor`，整机占用会明显下降一大截

## AQ. 远端主机 Tailscale 启动恢复能力复核（2026-03-11）

### 1. 当前 live 状态

远端主机 `openclaw-24x7` 现场检查结果：

- `tailscaled.service = enabled + active`
- 当前 Tailscale 版本：`1.94.2`
- 当前 Tailscale IPv4：`100.64.65.65`
- 当前 Tailscale IPv6：`fd7a:115c:a1e0::8f3b:4141`
- `tailscale debug prefs`：
  - `WantRunning = true`
  - `RunSSH = true`
  - `LoggedOut = false`

这说明：

- **系统重启后，tailscaled 会自动拉起**
- **节点会自动尝试连回 tailnet**
- **Tailscale SSH 也是开启状态**

### 2. 当前确实已经能通过指定 Tailscale IP 连入

本轮排查本身就是通过 Tailscale SSH 进到这台机器：

- 来源节点：`desktop-jrvidlh.tailda6e28.ts.net`
- 来源 Tailscale IP：`100.97.45.87`
- 目标节点：`openclaw-24x7`
- 目标 Tailscale IP：`100.64.65.65`

`journalctl -u tailscaled` 可见：

- `access granted`
- `SSH login: user=kevinlasnh ... from=100.97.45.87`

所以当前结论很明确：

- **外部电脑现在已经能通过 `100.64.65.65` 连接到这台机器**

### 3. IP 是否会在重启后变化

根据 Tailscale 官方文档《How Tailscale assigns IP addresses》：

- 每个节点都有 **stable IP address**
- 只要节点仍保持注册，IP 不会因为普通重启而变化
- 只有在这些场景才会变：
  - 设备从 tailnet 移除
  - 管理员手工改 IP / IP pool
  - 节点被 reset / 重装
  - 磁盘被抹掉，node key 丢失

因此：

- **正常重启后，`100.64.65.65` 预期保持不变**

### 4. Funnel / Serve 是否会在重启后恢复

当前现场：

- `tailscale serve status --json` 仍有完整配置
- `AllowFunnel` 包含：
  - `openclaw-24x7.tailda6e28.ts.net:443`
  - `openclaw-24x7.tailda6e28.ts.net:8443`
- 没有发现任何前台 `tailscale serve` / `tailscale funnel` 命令进程

结合 Tailscale 官方 CLI 文档《tailscale serve command》：

- 如果用 `-bg` 启动，**重启后会自动恢复**
- 如果不用 `-bg`，重启后需要手动重启 Serve

基于“当前没有前台 serve/funnel 进程，但配置仍在”的证据，最合理判断是：

- **当前这台机子的 Serve/Funnel 配置已经是持久化背景配置**
- **正常重启后应自动恢复**

这是根据现场状态做出的工程推断，不是直接读到了当初执行命令的 shell 历史。

### 5. 为什么这次判断基本能落到“和现在一样”

除了 `tailscaled` 本身，后端依赖也都具备开机恢复条件：

- `loginctl show-user kevinlasnh`：
  - `Linger = yes`
- `systemctl --user is-enabled`：
  - `openclaw-gateway.service = enabled`
  - `openclaw-gateway-dayong.service = enabled`
  - `mihomo-standalone.service = enabled`

这意味着：

- **即使用户不登录桌面，user systemd 也会在开机后拉起这几个服务**
- `443 -> 127.0.0.1:8787`
- `8443 -> 127.0.0.1:8788`
  后面的本地代理目标也有条件自动恢复

### 6. 当前结论

- **对于“外部电脑通过 `100.64.65.65` 连接这台机器”这件事，正常重启后预期会自动恢复。**
- **对于当前两个 Funnel webhook 入口（443 / 8443），也大概率会恢复到现在这个状态。**

### 7. 仍然存在的边界条件

- 如果开机后本地网络本身没起来，Tailscale 自然也不会立刻在线
- 如果 tailnet 认证状态被改动、设备被删除、node key 丢失，IP 可能变化
- 如果未来有人手工 `tailscale serve reset` / `tailscale funnel reset`，公网入口会消失
- 本轮**没有真的执行整机重启**，所以这是”高置信度静态验证”，不是实机 reboot 验证

---

## AQ. Dayong A 股交易系统架构重构调研（2026-03-12）

### 目标

将 dayong 的 `trading-brain` 单体 Skill 拆解，嵌入 OpenClaw 原生架构，打造专业 A 股交易小龙虾。

### 约束

- **不动 SOUL.md**（冰川纱夜人格保持不变）
- **不动 main Gateway**（只改 dayong）
- 以 OpenClaw 官方配置能力为标准

---

### AQ-1. OpenClaw 原生配置能力全景（v2026.3.7）

#### 上下文注入机制

| 文件 | 注入条件 | 子代理是否注入 | 交易系统用途 |
|------|---------|---------------|-------------|
| SOUL.md | 始终 | 不注入 | 冰川纱夜人格（不动） |
| AGENTS.md | 始终 | **注入** | 交易决策框架 + 风控红线 + 工作流 |
| TOOLS.md | 始终 | **注入** | 交易工具路径 + 数据源 + Python venv |
| USER.md | 始终 | 不注入 | 用户身份（不动） |
| IDENTITY.md | 始终 | 不注入 | Agent 身份（不动） |
| MEMORY.md | 仅私聊 | 不注入 | 策略精华 + 已验证的交易模式 |
| HEARTBEAT.md | 心跳时 | 不注入 | 结构化盘中监控任务 |
| memory/YYYY-MM-DD.md | 今天+昨天自动加载 | 不加载 | 每日交易日志 |
| memory/trading/*.md | **不自动加载**，但可被 memory_search 检索 | 不加载 | 结构化交易状态文件 |
| TRADING.md | **不自动注入** | 不注入 | 需通过 Hook 或 AGENTS.md 指令加载 |

**关键发现**：自定义 .md 文件（如 TRADING.md）不会被自动注入。有三种解决方式：

1. **bootstrap-extra-files Hook**（推荐）：启用后可注入额外 workspace 文件
   ```json
   { “hooks”: { “internal”: { “entries”: { “bootstrap-extra-files”: { “enabled”: true } } } } }
   ```
2. **shared-rules Hook**：将文件放入 `~/.openclaw-dayong/shared/`，自动注入所有 agent
3. **AGENTS.md 指令**：在 AGENTS.md 中写明”启动时 read TRADING.md”（消耗 tool call 轮次）

#### Cron 原生定时任务

格式：在 `openclaw.json` 的 `cron` 字段配置，Gateway 内置调度器执行（不依赖系统 crontab）。

```json
{
  “cron”: {
    “enabled”: true,
    “maxConcurrentRuns”: 3,
    “jobs”: [
      {
        “jobId”: “cn-morning-scan”,
        “description”: “A股早盘扫描”,
        “schedule”: { “kind”: “cron”, “cron”: “0 9 * * 1-5”, “tz”: “Asia/Shanghai” },
        “agentId”: “dayong”,
        “sessionTarget”: “isolated”,
        “payload”: {
          “kind”: “agentTurn”,
          “message”: “执行 A 股早盘扫描流程”,
          “timeoutSeconds”: 300,
          “deliver”: true,
          “channel”: “telegram”,
          “to”: “8226087994”
        }
      }
    ]
  }
}
```

两种执行模式：
- `sessionTarget: “main”` + `payload.kind: “systemEvent”`：注入主会话心跳队列
- `sessionTarget: “isolated”` + `payload.kind: “agentTurn”`：独立 session 执行（推荐用于交易任务）

**时区关键**：必须显式指定 `”tz”: “Asia/Shanghai”`，否则默认 UTC 会有 8 小时偏移。

#### Subagent 系统

子代理只注入 AGENTS.md + TOOLS.md（不注入 SOUL/USER/MEMORY），适合做后台分析任务。

配置：
```json
{
  “agents”: {
    “defaults”: {
      “subagents”: {
        “maxConcurrent”: 5,
        “maxChildrenPerAgent”: 3,
        “maxSpawnDepth”: 2
      }
    }
  }
}
```

通过 `sessions_spawn` 工具创建：
```json
{ “task”: “分析宁德时代 300750 技术面”, “mode”: “run”, “cleanup”: “delete” }
```

适合交易系统的用法：
- 并行分析多只候选股
- 独立执行宏观环境研判
- 后台跑回测任务

#### 向量记忆搜索（memorySearch）

```json
{
  “agents”: {
    “defaults”: {
      “memorySearch”: {
        “enabled”: true,
        “provider”: “openai”,
        “query”: {
          “hybrid”: {
            “enabled”: true,
            “vectorWeight”: 0.7,
            “textWeight”: 0.3,
            “temporalDecay”: { “enabled”: true, “halfLifeDays”: 30 }
          }
        }
      }
    }
  }
}
```

- 自动索引 `MEMORY.md` + `memory/` 目录下所有 .md 文件（含子目录如 `memory/trading/`）
- 支持混合搜索（BM25 + 向量）
- 时间衰减：近期记忆权重更高
- **memory/trading/ 子目录不会被自动加载到 session**，但会被 `memory_search` 工具语义检索到

#### Boot-md 系统

Gateway 启动时执行 workspace 中的 `BOOT.md`：

```json
{ “hooks”: { “internal”: { “entries”: { “boot-md”: { “enabled”: true } } } } }
```

适合交易系统：每次 Gateway 重启后自动检查市场状态、恢复持仓信息、验证数据源可用性。

#### Context Pruning（上下文裁剪）

当前 dayong 配置：`cache-ttl, TTL=1h`。对交易场景的优化建议：
- 交易数据查询的 tool result 体积大，适合 soft trim 保留头尾
- 最近 3 个 assistant 回复的数据不裁剪（`keepLastAssistants: 3`）
- 关键工具（如 risk 检查结果）可通过 deny list 豁免裁剪

#### Compaction（上下文压缩）

当前 dayong 配置：`safeguard` 模式。建议开启 `memoryFlush`，压缩前将交易状态保存到磁盘：

```json
{
  “compaction”: {
    “mode”: “safeguard”,
    “memoryFlush”: { “enabled”: true, “softThresholdTokens”: 6000 },
    “postCompactionSections”: [“Trading State”, “Risk Status”, “Open Positions”]
  }
}
```

---

### AQ-2. 当前 trading-brain 现状诊断

#### 规模

| 指标 | 数值 |
|------|------|
| 源码文件 | 100+ |
| 核心 Python 模块 | 30+ |
| 子模块 | 10 个（data/screener/signal/brain/risk/executor/backtest/reporter/learner/macro） |
| 多市场支持 | cn/hk/us |
| 配置版本历史 | 14 个 |
| JSON 数据库文件 | 15+ |
| Cron 任务 | 6 个（全在 skill 内部） |
| Python 虚拟环境 | 含在 skill 目录内 |

#### 数据流

```
data → market_env.json → screened_stocks.json → ai_analysis_request.json
  → ai_analysis_result.json → ai_decision.json → trade_signals.json
  → risk_approval.json → portfolio.json → daily_report.json
  → weekly_review.json → ai_memory.json
```

全部通过 `shared/pipeline/` 目录下的 JSON 文件做模块间通信。

#### 毕业状态（当前瓶颈）

| 指标 | 要求 | 当前 | 差距 |
|------|------|------|------|
| 胜率 | >=35% | 19.64% | **差 15.36 个百分点** |
| 盈亏比 | >=2.5 | 2.06 | 差 0.44 |
| 年化收益率 | >=15% | 3.8% | 差 11.2 个百分点 |
| 卡玛比率 | >=2.0 | 0.19 | 差 1.81 |

核心瓶颈：**胜率极低**，选股准确性不足。

#### 记忆三处分散问题

| 位置 | 内容 | 自动加载 | 向量检索 |
|------|------|---------|---------|
| `workspace/memory/trading/` | market_state, positions, decisions, signals, ai_analysis | 不自动 | 可检索（如开启） |
| `skill/shared/db/` | trade_memory, trade_history, ai_decision_log, weekly_review 等 15+ JSON | 不自动 | **不可检索** |
| `skill/modules/brain/ai_memory.py` | 短期/中期/长期三层内存 | 代码内存 | **不可检索** |
| `skill/memory/experiences/` | 各市场回放训练记忆 JSON | 不自动 | **不可检索** |

**问题**：skill 内部的大量交易历史数据完全游离于 OpenClaw 记忆系统之外，无法被语义检索。

---

### AQ-3. 重构方案总览

#### 设计原则

1. **OpenClaw 原生优先**：能用官方配置实现的，不自建
2. **始终在线的交易意识**：关键规则在 AGENTS.md（每次注入），不在 skill 调用时才激活
3. **记忆统一**：所有交易数据进入 OpenClaw 记忆体系，支持语义检索
4. **Skill 职责单一**：每个 skill 只做一件事，可独立触发
5. **原生调度**：Cron 任务进 openclaw.json，不在 skill 内部
6. **渐进式迁移**：不一次性推倒重来，分阶段替换

#### 七阶段路线图

**Phase 1：上下文骨架重塑**（优先级最高）
- 增强 AGENTS.md：嵌入交易决策框架 + 风控红线 + 紧急流程
- 增强 TOOLS.md：交易工具路径 + Python venv + 数据源信息
- 增强 HEARTBEAT.md：结构化盘中监控步骤
- 增强 MEMORY.md：策略精华 + 已验证的交易模式
- 启用 bootstrap-extra-files Hook 注入 TRADING.md
- 创建 BOOT.md + 启用 boot-md Hook

**Phase 2：记忆体系统一**
- 开启 memorySearch 向量检索
- 将 skill 内 `shared/db/` 的关键数据同步到 `memory/trading/`
- 建立 memory/trading/ 标准化格式
- 开启 memoryFlush，压缩前保存交易状态
- 将 ai_memory 三层记忆映射到 MEMORY.md + memory/

**Phase 3：Cron 原生迁移**
- 将 6 个 cron 任务从 skill 内 `cron.json` 迁移到 openclaw.json
- 配置 Telegram 投递（交易信号/日报直推）
- 配置时区和超时

**Phase 4：Skill 拆分**
- trading-brain → 精简为决策引擎（仅 brain + AI bridge）
- 新建 market-data skill（数据获取 + 行情查询）
- 新建 stock-screener skill（多因子选股）
- 新建 risk-control skill（风控 + 熔断，独立可调用）
- 新建 trade-executor skill（模拟盘/实盘执行）
- 新建 backtest skill（回测引擎）
- 新建 trading-reporter skill（日报/周报生成）
- 新建 trading-learner skill（复盘 + 参数优化 + 因子进化）

**Phase 5：openclaw.json 配置优化**
- 配置 subagent 参数（并发数、嵌套深度）
- 优化 context pruning 策略（交易数据友好）
- 优化 compaction 策略（保留交易状态）
- 配置 Telegram 自定义命令（/status /positions /risk）

**Phase 6：Subagent 多市场并行**
- 配置 allowAgents 允许 spawn 自身
- 在 AGENTS.md 中定义 subagent 调度策略
- 实现多市场并行分析（cn/hk/us 独立 subagent）

**Phase 7：高级集成**
- 替换 AI Bridge 文件 IPC 为 subagent 原生通信
- 集成 capability-evolver 自动进化交易策略
- 配置 self-improving-agent 记录交易错误和学习

---

### AQ-4. Phase 1 详细设计：上下文骨架重塑

#### AGENTS.md 增强方案

当前 AGENTS.md 主要是通用的工作流，需要嵌入交易核心规则（始终注入 = 始终在线）：

**新增内容**（在现有内容后追加）：

```markdown
## Trading Decision Framework（交易决策框架）

### 风控红线（ABSOLUTE RULES - 无例外）
1. 单只持仓 <= 总资金 20%
2. 单日亏损 > 3% → 暂停交易 1 天
3. 连续亏损 5 天 → 停机等待人工干预
4. 月度亏损 > 8% → 强制停机
5. 总回撤 > 15% → 全部清仓 + 停机
6. 硬止损：单只亏损 > 7% 立即卖出
7. 同行业持仓 <= 30%
8. 无论任何理由，不允许绕过风控检查

### 决策流程
1. 环境判断：先判断 bull/bear/swing，再决定仓位上限
2. 选股：多因子评分（MA + MACD + KDJ + 量能 + 筹码）
3. AI 辩论：Bull/Bear 双方观点 → 加权融合 → verdict
4. 风控审批：6 层检查全部通过才允许执行
5. 执行：模拟盘先行，严格记录

### 数据纪律
- 选股只用 T-1 数据（防 look-ahead bias）
- 技术指标只用 T-1 数据
- 买入用 T 日开盘价
- 任何时候不允许使用未来数据
```

#### HEARTBEAT.md 增强方案

从当前的方向性描述升级为结构化执行清单：

```markdown
## 交易时段心跳（工作日 9:00-15:00 CST）

### 每次心跳必做
1. read memory/trading/market_state.md — 获取最新市场状态
2. read memory/trading/positions.md — 检查持仓
3. read memory/trading/risk_status.md — 检查风控状态
4. 如果风控状态异常 → 立即通过 message 工具通知用户
5. 如果有持仓 → 检查止损/止盈条件

### 开盘前（8:50-9:00）
1. exec: python cli.py data download --market cn
2. exec: python cli.py macro analyze
3. 将结果更新到 memory/trading/market_state.md

### 盘中（9:30-11:30, 13:00-15:00）
1. 检查实时行情变动
2. 检查止盈止损触发
3. 熔断条件监控

### 收盘后（15:00-15:30）
1. exec: python cli.py report daily
2. 更新 memory/trading/positions.md
3. 更新 memory/trading/decisions.md
4. 将日报通过 message 工具发送到 Telegram
```

#### BOOT.md 设计

```markdown
# Gateway 启动交易准备

1. read memory/trading/market_state.md
2. read memory/trading/positions.md
3. read memory/trading/risk_status.md
4. 如果今天是交易日：
   - exec: python cli.py data download --market cn
   - 检查 Python venv 和依赖是否正常
   - 向用户发送”交易系统已就绪”消息
5. 如果今天不是交易日：
   - 向用户发送”今日休市”消息
```

#### TOOLS.md 增强方案

追加交易专用工具路径：

```markdown
## Trading Tools
- Python venv: ~/.openclaw-dayong/workspace/skills/trading-brain/venv/bin/python
- CLI 入口: ~/.openclaw-dayong/workspace/skills/trading-brain/cli.py
- 数据目录: ~/.openclaw-dayong/workspace/skills/trading-brain/shared/data/
- Pipeline: ~/.openclaw-dayong/workspace/skills/trading-brain/shared/pipeline/
- 配置: ~/.openclaw-dayong/workspace/skills/trading-brain/shared/config/global.json
- 日报输出: ~/.openclaw-dayong/workspace/skills/trading-brain/reports/
```

---

### AQ-5. Phase 2 详细设计：记忆体系统一

#### 目标记忆结构

```
workspace/
├── MEMORY.md                    ← 策略精华（始终注入私聊）
│   包含：已验证的因子模式、关键阈值、历史教训
│
├── memory/
│   ├── YYYY-MM-DD.md            ← 每日交易日志（今天+昨天自动加载）
│   │   格式：[TRADING] 开盘扫描完成 / [DECISION] 买入 300750 / [RISK] 止损触发
│   │
│   └── trading/                 ← 结构化交易状态（向量检索可达）
│       ├── market_state.md      ← 实时市场环境
│       ├── positions.md         ← 当前持仓
│       ├── decisions.md         ← 今日决策记录
│       ├── signals.md           ← 活跃信号
│       ├── ai_analysis.md       ← AI 分析结果
│       ├── risk_status.md       ← 新增：风控状态
│       ├── watchlist.md         ← 新增：关注股票池
│       ├── strategy_params.md   ← 新增：当前策略参数
│       └── weekly_summary.md    ← 新增：本周复盘摘要
```

#### openclaw.json memorySearch 配置

```json
{
  “agents”: {
    “defaults”: {
      “memorySearch”: {
        “enabled”: true,
        “provider”: “openai”,
        “query”: {
          “hybrid”: {
            “enabled”: true,
            “vectorWeight”: 0.7,
            “textWeight”: 0.3,
            “temporalDecay”: {
              “enabled”: true,
              “halfLifeDays”: 60
            }
          }
        }
      }
    }
  }
}
```

半衰期设为 60 天（比默认 30 天长），因为交易模式需要更长的历史参考。

#### 记忆同步策略

skill 内部 `shared/db/*.json` 的数据在每次交易流程结束后，由 AGENTS.md 中的规则驱动同步到 `memory/trading/*.md`，使其进入向量索引。

---

### AQ-6. Phase 3 详细设计：Cron 原生迁移

#### 当前 cron.json（skill 内部）→ 目标 openclaw.json

| 任务 | 旧 schedule | 新 cron 表达式 | sessionTarget | deliver |
|------|------------|---------------|---------------|---------|
| A 股早盘 | 09:00 工作日 | `0 9 * * 1-5` | isolated | telegram/8226087994 |
| A 股午盘 | 13:30 工作日 | `30 13 * * 1-5` | isolated | telegram/8226087994 |
| 港股训练 | 10:00 工作日 | `0 10 * * 1-5` | isolated | 不投递 |
| 美股盘前 | 21:00 工作日 | `0 21 * * 1-5` | isolated | 不投递 |
| A 股回放 | 23:00 工作日 | `0 23 * * 1-5` | isolated | 不投递 |
| 全市场回放 | 23:30 工作日 | `30 23 * * 1-5` | isolated | 不投递 |

新增建议：
| 任务 | cron | 说明 |
|------|------|------|
| 收盘日报 | `30 15 * * 1-5` | 收盘后 30 分钟生成日报并推送 |
| 周五复盘 | `0 16 * * 5` | 每周五收盘后生成周报 |
| 风控状态报告 | `0 12 * * 1-5` | 午间风控状态快照 |

---

### AQ-7. Phase 4 详细设计：Skill 拆分

#### 拆分策略

保留 `trading-brain/` 目录和所有代码不动（避免破坏 Python import 路径），通过**新建独立 Skill SKILL.md 作为入口**，分别暴露不同功能。

每个新 Skill 的 SKILL.md 调用的是 `trading-brain/cli.py` 的不同子命令。

#### 新 Skill 清单

| Skill 目录 | 触发条件 | 调用命令 | 职责 |
|-----------|---------|---------|------|
| `market-data/` | “行情””数据””下载” | `cli.py data` | 数据获取 + 实时行情 |
| `stock-screener/` | “选股””筛选””扫描” | `cli.py screener` | 多因子选股 |
| `risk-control/` | “风控””止损””熔断””仓位” | `cli.py risk` | 风控检查 + 熔断管理 |
| `trade-executor/` | “买入””卖出””交易””执行” | `cli.py trade` | 模拟盘/实盘执行 |
| `backtest/` | “回测””历史测试” | `cli.py backtest` | 回测引擎 |
| `trading-reporter/` | “日报””周报””报告” | `cli.py report` | 报告生成 |
| `trading-learner/` | “复盘””优化””学习” | `cli.py learn` | 复盘 + 参数优化 |
| `trading-brain/` | “分析””决策””判断” | `cli.py brain` | AI 决策引擎（精简后） |

#### Skill SKILL.md 模板示例（market-data）

```yaml
---
name: market-data
description: A股/港股/美股行情数据获取与实时查询
trigger:
  - 行情
  - 数据
  - 下载数据
  - 实时价格
---
```

```markdown
## 使用方法

### 下载日线数据
exec: cd ~/.openclaw-dayong/workspace/skills/trading-brain && venv/bin/python cli.py data download --market cn

### 实时行情查询
exec: cd ~/.openclaw-dayong/workspace/skills/trading-brain && venv/bin/python cli.py data quote --code 300750

### 批量更新
exec: cd ~/.openclaw-dayong/workspace/skills/trading-brain && venv/bin/python cli.py data update --all
```

---

### AQ-8. Phase 5-7 概要设计

#### Phase 5：openclaw.json 配置优化

```json
{
  “subagents”: { “maxConcurrent”: 5, “maxChildrenPerAgent”: 3, “maxSpawnDepth”: 2 },
  “contextPruning”: { “mode”: “cache-ttl”, “ttl”: “30m”, “keepLastAssistants”: 5 },
  “compaction”: {
    “mode”: “safeguard”,
    “memoryFlush”: { “enabled”: true },
    “postCompactionSections”: [“Trading State”, “Risk Status”, “Open Positions”]
  }
}
```

Telegram 自定义命令：
```json
{
  “channels”: {
    “telegram”: {
      “customCommands”: [
        { “command”: “positions”, “description”: “查看当前持仓” },
        { “command”: “risk”, “description”: “查看风控状态” },
        { “command”: “market”, “description”: “查看市场环境” },
        { “command”: “report”, “description”: “生成今日报告” }
      ]
    }
  }
}
```

#### Phase 6：Subagent 多市场并行

在 AGENTS.md 中定义调度策略：
- 收到”全市场分析”指令时，spawn 3 个 subagent 分别分析 cn/hk/us
- 每个 subagent 获得 AGENTS.md + TOOLS.md（交易规则+工具路径）
- 结果汇总到主会话

#### Phase 7：高级集成

- 将 ai_bridge.py 的文件 IPC 替换为 subagent 的 `sessions_spawn` + `sessions_history`
- 集成 capability-evolver：让它分析交易失败模式，自动优化策略参数
- 集成 self-improving-agent：记录每次交易错误到 `.learnings/ERRORS.md`

---

### AQ-9. 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| 拆分 skill 后 Python import 路径断裂 | 功能不可用 | 不移动代码，新 skill 只是 SKILL.md 入口 |
| Cron 迁移后旧 cron 残留 | 重复执行 | 迁移完成后删除 skill 内 cron.json |
| memorySearch 的 embedding API 费用 | 成本增加 | 可选用本地 embedding 或 Ollama |
| 向量索引构建耗时 | 首次启动慢 | 只索引 memory/ 目录，不索引代码 |
| Kimi 模型工具调用不稳定 | 影响交易执行 | 已有源码补丁，且 Phase 1 的 AGENTS.md 风控红线始终生效 |
| AGENTS.md 过长超出 bootstrapMaxChars | 被截断 | 控制在 20000 字符内，关键规则放前面 |

---

### AQ-10. 当前 openclaw-complete-guide.md 遗漏补充

用户提供的指南（`G:\我的云端硬盘\second-brain\life\openclaw-complete-guide.md`）中缺少以下关键信息：

1. **bootstrap-extra-files Hook**：可注入自定义 .md 文件
2. **Cron 详细配置**：sessionTarget/payload/deliver/timezone 等字段
3. **memorySearch 向量检索**：hybrid search/temporal decay/MMR 配置
4. **Boot-md 系统**：Gateway 启动时执行 BOOT.md
5. **Context Pruning 详细配置**：cache-ttl/softTrim/hardClear 参数
6. **Compaction memoryFlush**：压缩前自动保存记忆
7. **Subagent 上下文注入规则**：子代理只注入 AGENTS + TOOLS
8. **Subagent sessions_spawn 参数**：mode/cleanup/model 等
9. **Tools 按 Provider 覆盖**：`tools.byProvider` 配置
10. **Plugin API 扩展点**：registerAgentTool/registerHook 等
11. **Telegram customCommands**：自定义斜杠命令
12. **memory/子目录行为**：不自动加载但可被向量检索
13. **自定义 .md 文件不自动注入**：只有固定命名文件才注入

这些信息已在本节 AQ-1 中补全。

---

## AR. Dayong 自我进化闭环架构设计（2026-03-12）

### 目标

让 dayong 小龙虾实现"明天比今天更强"的自我进化闭环——每天自动复盘、提炼经验、更新策略参数，形成可持续的交易能力螺旋上升。

### 设计原则

1. **闭环驱动**：每个交易日产生数据 → 分析 → 学习 → 应用 → 下一个交易日
2. **分层进化**：日循环微调参数，周循环验证因子，月循环更新规则
3. **记忆即进化**：进化成果通过 OpenClaw 原生记忆体系持久化
4. **安全进化**：任何规则变更需经风控检查，不允许进化过程绕过止损红线
5. **可审计**：所有进化决策有日志，可回溯

---

### AR-1. 三层进化周期详细设计

#### 日循环（Daily Evolution Loop）

**触发**：每交易日收盘后 15:30 CST（Cron isolated session）

```
15:30  收盘复盘 Cron 触发
  │
  ├─ Step 1: 收集当日数据
  │   - 读取 memory/trading/decisions.md（今日所有决策）
  │   - 读取 memory/trading/positions.md（持仓变化）
  │   - 通过 cli.py data quote 获取今日收盘价
  │
  ├─ Step 2: 预测 vs 实际
  │   - 对比每笔 AI 分析的预测方向 vs 实际涨跌
  │   - 计算今日胜率、盈亏比、单日收益率
  │   - 标记哪些因子在今天起了正/负作用
  │
  ├─ Step 3: 因子微调
  │   - 运行 param_optimizer.py --mode daily
  │   - 对表现好的因子 +1-3% 权重
  │   - 对表现差的因子 -1-3% 权重
  │   - 单日调整幅度上限 3%（防过拟合）
  │
  ├─ Step 4: 记忆写入
  │   - 将复盘结论写入 memory/YYYY-MM-DD.md（标签 [REVIEW]）
  │   - 更新 memory/trading/decisions.md（标注实际盈亏）
  │   - 更新 memory/trading/risk_status.md
  │
  ├─ Step 5: 生成日报
  │   - 运行 cli.py report daily
  │   - 通过 message 工具推送到 Telegram
  │
  └─ Step 6: 错误学习
      - 如果今日有止损/熔断触发：
        - 写入 self-improving-agent 的 ERRORS.md
        - 分析触发原因，归类为"选股失误"/"时机失误"/"风控触发"
```

**关键参数**：
- 因子权重单日调整上限：3%
- 因子权重总范围：10%-40%（不允许极端分配）
- 负面事件（止损/熔断）写入 ERRORS.md，正面事件写入 LEARNINGS.md

#### 周循环（Weekly Evolution Loop）

**触发**：每周五收盘后 16:00 CST（Cron isolated session）

```
16:00  周循环 Cron 触发
  │
  ├─ Step 1: 因子有效性分析
  │   - 运行 weekly_review.py
  │   - 统计本周每个因子的命中率：
  │     - MA多头：命中 X/Y 次
  │     - MACD金叉：命中 X/Y 次
  │     - KDJ超卖：命中 X/Y 次
  │     - 量能温和：命中 X/Y 次
  │     - 筹码集中：命中 X/Y 次
  │   - 计算因子 Sharpe Ratio 贡献度
  │
  ├─ Step 2: 策略进化提案
  │   - 运行 strategy_evolver.py
  │   - 基于本周数据提出进化提案：
  │     - "建议将 KDJ 权重从 20% 调到 15%（本周命中率仅 22%）"
  │     - "建议增加北向资金因子（本周北向净流入日均涨幅 +1.2%）"
  │   - 进化提案写入 capability-evolver 的审计日志
  │
  ├─ Step 3: 参数大调整
  │   - 运行 param_optimizer.py --mode weekly
  │   - 周级调整幅度上限：10%
  │   - 但必须通过回测验证（新参数 vs 旧参数，最近 30 天数据）
  │   - 只有新参数的 Sharpe >= 旧参数 * 0.95 才允许应用
  │
  ├─ Step 4: 记忆晋升（短期 → 中期）
  │   - 扫描本周 memory/YYYY-MM-DD.md 中标签 [REVIEW] 的内容
  │   - 提取连续 3 天以上重复出现的模式
  │   - 写入 MEMORY.md 的"本月观察"区域
  │   - 例如："[2026-W11] 小盘股连续跑赢大盘，板块轮动加速"
  │
  ├─ Step 5: 毕业指标更新
  │   - 重新计算所有毕业指标
  │   - 更新 graduation.json
  │   - 与上周对比，标注进步/退步
  │
  └─ Step 6: 生成周报
      - 运行 cli.py report weekly
      - 包含：周收益、因子表现、进化提案、毕业进度
      - 推送到 Telegram
```

**因子进化规则**：
- 因子连续 2 周命中率 < 25% → 降权 5-10%
- 因子连续 2 周命中率 > 60% → 升权 5-10%
- 任何因子权重不低于 5%（保持多样性）
- 新因子引入需要至少 2 周回测验证

#### 月循环（Monthly Evolution Loop）

**触发**：每月最后一个交易日 16:30 CST（Cron isolated session）

```
16:30  月循环 Cron 触发
  │
  ├─ Step 1: 结构性回顾
  │   - 读取本月所有 memory/YYYY-MM-DD.md
  │   - 读取本月 4 次周报
  │   - 读取 MEMORY.md 中"本月观察"
  │   - 综合分析本月市场特征
  │
  ├─ Step 2: 记忆晋升（中期 → 长期）
  │   - MEMORY.md 中连续 3 周以上验证的模式 → 提升为"已验证策略"
  │   - 例如："[PROVEN] 北向资金连续净流入 >= 3 天时，大盘短期看多"
  │   - 这些"已验证策略"永远不被时间衰减（evergreen）
  │
  ├─ Step 3: AGENTS.md 规则进化（安全模式）
  │   - 基于本月教训，提出 AGENTS.md 新增规则
  │   - 新规则格式：
  │     ```
  │     ## Evolution Log（自动追加，勿手动编辑）
  │     - [2026-03] 新增规则：北向资金连续净流出 3 天时，降低仓位上限至 30%
  │     ```
  │   - 规则只能追加到 Evolution Log 段，不修改核心风控红线
  │   - 每条新规则在下月初需经用户确认（通过 Telegram 消息）
  │
  ├─ Step 4: 全面回测验证
  │   - 用最新参数对过去 90 天数据做完整回测
  │   - 对比 3 个月前的参数
  │   - 生成进化效果报告
  │
  └─ Step 5: 毕业评估
      - 如果 11 项毕业指标全部达标 → 发送"可考虑实盘"提醒
      - 否则标注差距最大的指标作为下月重点
```

---

### AR-2. Cron 任务完整清单（含进化任务）

| jobId | 时间 | 类型 | 说明 |
|-------|------|------|------|
| cn-morning-prep | `50 8 * * 1-5` | isolated | 早盘准备：下载数据、宏观分析 |
| cn-morning-scan | `0 9 * * 1-5` | isolated | 早盘扫描：选股、AI 分析、推送信号 |
| cn-noon-scan | `30 13 * * 1-5` | isolated | 午盘扫描：更新行情、检查止盈止损 |
| cn-daily-review | `30 15 * * 1-5` | isolated + deliver | **日循环**：收盘复盘 + 因子微调 + 日报推送 |
| cn-weekly-evolve | `0 16 * * 5` | isolated + deliver | **周循环**：因子分析 + 策略进化 + 周报推送 |
| cn-monthly-evolve | 月末交易日 16:30 | isolated + deliver | **月循环**：结构性回顾 + 规则进化 + 毕业评估 |
| cn-replay-train | `0 23 * * 1-5` | isolated | 夜间回放训练（用更新后的参数） |
| cn-risk-noon | `0 12 * * 1-5` | isolated + deliver | 午间风控状态快照 |
| hk-training | `0 10 * * 1-5` | isolated | 港股训练 |
| us-premarket | `0 21 * * 1-5` | isolated | 美股盘前 |

**月循环的 cron 表达式**：没有原生"月末交易日"表达式，可用 `30 16 28-31 * 1-5` 近似（每月 28-31 日的工作日），在 AGENTS.md 中补充"如果当天不是本月最后一个交易日则跳过"的逻辑。

---

### AR-3. 记忆晋升管道（Memory Promotion Pipeline）

```
Layer 0: 实时决策数据
  ↓ (每笔交易后立即写入)
Layer 1: memory/trading/*.md — 结构化状态文件
  ↓ (收盘后 cn-daily-review 自动写入)
Layer 2: memory/YYYY-MM-DD.md — 每日交易日志
  ↓ (今天+昨天自动加载到 session)
Layer 3: memory/trading/weekly_summary.md — 本周复盘
  ↓ (每周五 cn-weekly-evolve 更新)
Layer 4: MEMORY.md "本月观察" 区域
  ↓ (连续 3 周验证的模式 → 晋升)
Layer 5: MEMORY.md "已验证策略" 区域（evergreen，永不衰减）
  ↓ (月循环提取为 AGENTS.md 规则)
Layer 6: AGENTS.md "Evolution Log" — 硬编码规则（始终注入）
```

**向量检索加速**：开启 memorySearch 后，Layer 1-5 全部可被语义检索。当小龙虾遇到类似的市场环境时，可以通过 `memory_search "北向资金连续流出时的历史操作"` 找到过去的经验。

---

### AR-4. 进化安全护栏

| 护栏 | 规则 | 目的 |
|------|------|------|
| 因子权重单日调整上限 | 3% | 防止对单日波动过度拟合 |
| 因子权重周级调整上限 | 10% | 允许有意义的调整但不激进 |
| 因子权重范围 | 5%-40% | 防止极端分配 |
| 参数变更需回测验证 | 新 Sharpe >= 旧 * 0.95 | 防止回测退步 |
| AGENTS.md 只追加不修改 | Evolution Log 段独立 | 风控红线不可被进化覆盖 |
| 月循环新规则需用户确认 | Telegram 消息通知 | 人在回路（Human-in-the-loop） |
| 毕业指标只能自然达标 | 不允许降低标准 | 防止"通过降低标准来毕业" |
| 进化日志全量保留 | capability-evolver 审计 | 可回溯任何决策 |

---

### AR-5. 与现有模块的对接

trading-brain 已有但未接入闭环的模块：

| 现有模块 | 文件 | 当前状态 | 进化闭环中的角色 |
|---------|------|---------|---------------|
| param_optimizer | `modules/learner/param_optimizer.py` | 存在但未自动运行 | 日循环 + 周循环调用 |
| auto_param_adjust | `modules/learner/auto_param_adjust.py` | 存在但未接入 | 日循环微调的执行器 |
| strategy_evolver | `modules/learner/strategy_evolver.py` | 存在但未接入 | 周循环进化提案 |
| weekly_review | `modules/learner/weekly_review.py` | 存在但未自动运行 | 周循环因子分析 |
| error_attribution | `modules/learner/error_attribution.py` | 存在但未接入 | 日循环错误归因 |
| experience_bank | `modules/learner/experience_bank.py` | 存在但未接入 | 记忆晋升的候选库 |
| ai_memory | `modules/brain/ai_memory.py` | 三层记忆系统存在 | 与 OpenClaw 原生 MEMORY.md 对齐 |
| market_adaptive | `modules/learner/market_adaptive.py` | 存在但未接入 | 月循环市场特征识别 |
| capability-evolver | `skills/capability-evolver/` | 已安装但为空 | 进化提案审计 + GEP 协议 |
| self-improving-agent | `skills/self-improving-agent/` | 已安装但为空 | 错误/学习/特性记录 |

**关键洞察**：trading-brain 的 learner 模块里已经有了进化所需的所有零件，只是没有被 Cron 驱动起来，也没有和 OpenClaw 记忆体系打通。重构的核心工作是**串联**而非**重写**。

---

### AR-6. 进化效果度量

如何知道进化在起作用？追踪以下指标的周对比趋势：

| 指标 | 计算方式 | 目标趋势 |
|------|---------|---------|
| 周胜率 | 本周盈利笔数 / 总笔数 | 持续上升 → 35% |
| 周因子命中率 | 各因子推荐的股票中盈利比例 | 持续上升 |
| 参数稳定性 | 本周 vs 上周的权重变化幅度 | 逐渐收敛（越来越小） |
| 记忆利用率 | memory_search 被调用并影响决策的比例 | 持续上升 |
| 错误重复率 | 本周新错误中有多少是"重复犯错" | 持续下降 |
| 毕业指标达标数 | 11 项中达标的个数 | 持续上升 → 11/11 |

---

### AR-7. 与七阶段重构的整合

自我进化闭环不是独立的新 Phase，而是贯穿于多个阶段：

| 进化组件 | 所在 Phase | 依赖 |
|---------|----------|------|
| AGENTS.md Evolution Log 区域 | Phase 1（上下文骨架） | 无 |
| MEMORY.md 分层结构（观察→验证→规则） | Phase 1（上下文骨架） | 无 |
| memorySearch 启用 | Phase 2（记忆统一） | Phase 1 |
| 日/周/月循环 Cron 任务 | Phase 3（Cron 迁移） | Phase 1-2 |
| trading-learner Skill（调用进化模块） | Phase 4（Skill 拆分） | Phase 3 |
| capability-evolver 接入 | Phase 7（高级集成） | Phase 4 |
| self-improving-agent 接入 | Phase 7（高级集成） | Phase 4 |

**Phase 1-3 做完后**，日循环就能自动运转了。这是最小闭环。

---

### AQ-11. 2026-03-12 深度调研补充发现

基于本次对 dayong 实例的完整扫描和 OpenClaw 高级特性的深度调研，以下是 AQ 节之前未覆盖的新发现：

#### 安全风险

1. **API Key 硬编码**：`agents/dayong/agent/models.json` 和 `agents/main/agent/models.json` 中均硬编码了 Kimi API key (`sk-kimi-mXbn...`)。应迁移到 `.env` 并在 `models.json` 中使用环境变量引用。

2. **.env 是符号链接**：`~/.openclaw-dayong/.env` → `~/.openclaw/.env`（dayong 和 main 共享同一份 API key），之前 main 小龙虾自删 .env 导致 dayong 同时崩溃的风险仍然存在。建议断开符号链接，给 dayong 独立 .env。

#### 数据状态不一致

3. **模拟盘数据矛盾**：
   - `portfolio.json`（2026-02-26）显示：初始 100 万 → 当前 8,134 元，亏损 99.19%，持仓 17 只股票
   - `memory/trading/positions.md`（2026-03-11）显示：空仓，可用资金 100 万
   - 说明模拟盘在某个时间点被手动重置，但 `portfolio.json` 未同步清理
   - **Phase 2 执行前必须先归档旧 portfolio.json，统一数据起点**

4. **选股数据过期**：`screened_stocks.json` 最后更新 2026-02-24，已过期 16 天

#### self-improving-agent 未实际使用

5. **`.learnings/` 目录全空**：`LEARNINGS.md`、`ERRORS.md`、`FEATURE_REQUESTS.md` 均只有标题，无内容。说明 self-improving-agent 虽然安装了但从未记录过任何交易学习。Phase 7 集成时需要先建立触发机制。

#### OpenClaw 高级特性补充（对 AQ-1 的增量）

6. **Cron 模型覆盖**：cron job payload 支持 `"model"` 和 `"thinking"` 字段覆盖，关键交易决策可指定 `"thinking": "high"` 获得更深推理。

7. **Cron Telegram 投递语法**：
   - Chat ID: `"-1001234567890"`
   - Forum Topic: `"-1001234567890:topic:123"`
   - 用户私聊: `"8226087994"`（dayong 当前的 allowedUsers）

8. **Cron 防失控**：`maxConcurrentRuns` 限制并行 job 数。之前 morning-briefing cron 失控耗尽配额的教训在此。建议 dayong 交易 cron 设 `maxConcurrentRuns: 2`，并给每个 job 加 `timeoutSeconds: 300`。

9. **Tools by Provider 覆盖**：可以按模型限制工具集：
   ```json
   { "tools": { "byProvider": { "kimi/k2p5": { "profile": "coding" } } } }
   ```
   对 Kimi k2p5 的工具调用不稳定问题，可考虑限制为更小的工具集减少出错概率。

10. **Loop Detection**：OpenClaw 内置循环检测器（`tools.loopDetection`），可检测 Agent 在同一操作上反复尝试。交易场景中如果数据源暂时不可用，Agent 可能陷入重试循环。建议启用：
    ```json
    { "tools": { "loopDetection": { "enabled": true, "warningThreshold": 5, "criticalThreshold": 10 } } }
    ```

11. **Elevated Access（提权）**：当前 dayong 的 `tools.exec.security = "full"`，无需额外配置。但如果未来引入更多用户或群聊，应通过 `tools.elevated.allowFrom` 限制谁能触发交易执行。

12. **Session Memory（实验性）**：`experimental.sessionMemory: true` 可让 `memory_search` 检索近期对话内容。对交易场景有价值——可以搜索"上次分析宁德时代时说了什么"。但为实验性功能，建议 Phase 2 稳定后再评估。

13. **Compaction safeguard 流水线细节**：
    - 元数据收集：最多 8 条（文件操作 + 工具失败），每条不超 240 字符
    - 分段摘要后合并
    - `postCompactionSections` 支持指定压缩后必须保留的章节标题
    - 对交易系统，建议 sections 包含：`["当前持仓", "风控状态", "今日决策", "活跃信号"]`

14. **bootstrapMaxChars 限制**：单文件默认 20,000 字符，总注入默认 150,000 字符。当前 dayong 的 AGENTS.md (2601 chars) + TOOLS.md (1814 chars) + SOUL.md + USER.md + IDENTITY.md + MEMORY.md 总量远低于上限，Phase 1 增强后仍有充足空间。

#### 对七阶段方案的修正建议

15. **Phase 1 前置：安全修复**
    - 断开 .env 符号链接，给 dayong 独立 .env
    - 将 `models.json` 中硬编码的 API key 迁移到 .env
    - 清理/归档过期的 `portfolio.json` 和 `screened_stocks.json`

16. **Phase 2 修正：Embedding Provider 选择**
    - dayong 的 `.env` 中已有 `MINIMAX_API_KEY`（通过符号链接），但不确定 OpenClaw memorySearch 是否支持 MiniMax embedding
    - 最稳妥方案：使用 `GOOGLE_API_KEY`（已有）配合 Gemini embedding，或本地 Ollama
    - 需要确认远端是否安装了 Ollama 或其他本地 embedding 服务

17. **Phase 4 修正：Skill 拆分保持代码不动**
    - 确认策略正确：不移动/复制 Python 代码，只新建 SKILL.md 入口
    - 所有新 skill 的 SKILL.md 调用同一个 `cli.py` 的不同子命令
    - 需要先验证 `cli.py` 是否已实现所有子命令（data/screener/risk/trade/backtest/report/learn/brain）

18. **Phase 5 新增：Loop Detection 启用**
    - 交易数据源可能暂时不可用（新浪/腾讯行情接口不稳定）
    - Agent 可能陷入"获取数据失败 → 重试 → 失败"的循环
    - 启用 loopDetection 提前告警

---

## AS. Dayong A 股重构执行记录（2026-03-12）

### AS-1. Cron Jobs 不在 openclaw.json 中配置（重要发现）

**现象**：将 `cron.jobs` 数组写入 `openclaw.json` 后，Gateway 启动报错 `Unrecognized key: "jobs"`。

**根因**：OpenClaw v2026.3.7 的 config schema 对 `cron` 段使用了 `.strict()` 验证，只允许以下全局设置字段：
- `enabled`、`store`、`maxConcurrentRuns`、`retry`、`webhook`、`webhookToken`、`sessionRetention`、`runLog`、`failureAlert`、`failureDestination`

**Cron jobs 的正确管理方式**：通过 CLI 命令管理，jobs 存储在 `$STATE_DIR/cron/jobs.json`：
```bash
# 创建
openclaw cron add --name cn-morning --cron "0 9 * * 1-5" --tz "Asia/Shanghai" --agent dayong --message "描述" --timeout 300

# 列表
openclaw cron list

# 删除
openclaw cron rm <job-id>

# 手动触发（调试用）
openclaw cron run <job-id>

# 状态
openclaw cron status
```

**CLI 参数**（已验证可用）：
- `--name`：任务名称（必填）
- `--cron`：cron 表达式（与 `--at` / `--every` 三选一）
- `--tz`：时区（如 `Asia/Shanghai`）
- `--agent`：目标 agent ID
- `--message`：任务消息（与 `--system-event` 二选一）
- `--timeout`：超时秒数

**CLI 参数**（尚未验证）：
- `--deliver`：投递目标（格式待确认，默认 `announce` 模式即可）

**修正**：findings.md AQ-1 中关于 cron 在 openclaw.json 中配置 jobs 的描述需要更正。

### AS-2. Doctor 自动迁移

运行 `openclaw doctor --fix` 后发现：
- 会自动将 `channels.telegram` 顶层的配置项迁移到 `channels.telegram.accounts.default` 下
- `customCommands` 被放在 telegram 顶层时会被迁移
- 会检测 `groupPolicy: "allowlist"` 但 `groupAllowFrom` 为空的不一致

### AS-3. Phase 0-7 执行总结

| Phase | 内容 | 变更文件/操作 | 状态 |
|-------|------|-------------|------|
| 0 | 安全修复 | .env 独立化 + API key 清理 + 11 个旧数据删除 | ✅ |
| 1 | 上下文骨架 | AGENTS.md (+2420 chars) + TOOLS.md (+598 chars) + HEARTBEAT.md (重写) + BOOT.md (新建) | ✅ |
| 2 | 记忆标准化 | MEMORY.md (+策略精华) + memory/trading/ 4 个新文件 + compaction memoryFlush | ✅ |
| 3 | Cron 迁移 | 6 个 cron job 通过 CLI 创建（非 openclaw.json） | ✅ |
| 4 | Skill 拆分 | 7 个新 Skill 目录（market-data 等）→ 39/85 ready | ✅ |
| 5 | 配置优化 | hooks + subagent + pruning(30m) + loopDetection + customCommands | ✅ |
| 6 | Subagent | AGENTS.md 调度策略追加 | ✅ |
| 7 | 高级集成 | self-improving-agent .learnings 填充 + capability-evolver 确认 | ✅ |

---

## AT. 夜间自动训练系统完整方案（2026-03-12）

### AT-1. 数据源实测结果

**测试环境**：远端 Ubuntu 主机 100.64.65.65，出口 IP 浙江移动 223.74.154.77

#### push2.eastmoney.com 不可用根因

东方财富 `XX.push2.eastmoney.com`（1~90 全系列）对标准 HTTP 请求做了**服务端反爬屏蔽**：
- TLS 握手成功后，服务端主动断连（Empty reply / missing close_notify）
- 远端 Ubuntu 和本地 Windows WSL **同时失败**，排除网络/代理问题
- 加 Referer/Origin/User-Agent/cookies/HTTP2/IPv4/IPv6 均无效
- 该域名只允许浏览器内嵌 JS 调用

而 `push2his.eastmoney.com`（历史数据）走不同 IP（上海电信 vs 腾讯云北京），完全正常。

#### 各数据源实测矩阵

| 数据源 | 实时行情 | 日线历史 | 分钟线 | 指数 | 板块 | 龙虎榜 | 交易日历 | 全市场股票池 | 安装状态 |
|--------|---------|---------|--------|------|------|--------|---------|------------|---------|
| akshare (push2his) | ✗ | 当日 0.2s/只 | 当日 5min | ✗ | ✗ | 2.7s | 0.4s | ✗ | 已装 1.18.37 |
| baostock | 无 | T+1 0.1s | 当日 5min | T+1 | 行业 12.8s | 无 | 0.2s | 需特定日期 | 已装 0.8.9 |
| efinance | ✗ | 当日 0.3s | 未测 | ✗ | ✗ | - | - | - | 已装 0.5.5.2 |
| 新浪 hq.sinajs.cn | **实时 0.05s** | 无 | 无 | **实时** | 无 | 无 | 无 | 无 | 免装(HTTP) |
| 腾讯 qt.gtimg.cn | **实时 0.05s** | 无 | 无 | **实时** | 无 | 无 | 无 | 无 | 免装(HTTP) |
| Ashare 双核 | 腾讯分钟线 | 腾讯日线 | 分钟线 | 有 | 无 | 无 | 无 | 无 | 已存在 |
| sina_quote.py | **实时批量** | 日线(count) | 无 | **三大指数** | 无 | 无 | 无 | 无 | 已存在 |

**新浪批量能力**：单次最多 800 只，0.2s 返回。全市场 ~5000 只分 7 批，约 1.5 秒搞定。

#### 数据源降级策略

```
实时行情：sina_quote.py → Ashare(腾讯) → akshare(5min线聚合)
日线历史：akshare(push2his) → efinance → baostock(T+1)
指数实时：sina_quote.get_index_realtime() → Ashare(腾讯)
指数日线：akshare(stock_zh_a_hist) → baostock
行业分类：baostock
交易日历：akshare(sina) → baostock
全市场池：新浪批量(7批×800) → baostock
龙虎榜  ：akshare
```

### AT-2. 夜间训练时间窗口

A 股交易时间：09:30-11:30, 13:00-15:00（北京时间）
数据可用时间：收盘后约 15:30 当日日线数据即可通过 akshare 获取

**训练窗口：16:00 ~ 08:50 = 约 17 小时**

### AT-3. 训练流水线设计（8 阶段）

```
16:00  ┌─ Stage 1: 数据刷新 ──────────────────────────┐
       │ 下载最新日线(akshare) + 全市场快照(新浪)         │
       │ 更新缓存 + 校验数据完整性                        │
16:30  └──────────────────────────────────────────────┘
       ┌─ Stage 2: 当日复盘 ──────────────────────────┐
       │ 交易记录结算 → 错误归因 → 市场环境分类            │
       │ → 参数微调 → 经验积累（5步 learning_master 流程） │
17:30  └──────────────────────────────────────────────┘
       ┌─ Stage 3: Walk-Forward 验证 ─────────────────┐
       │ 滚动窗口回测(120训练+20测试天) × 多参数集        │
       │ 对比不同 min_score / position_pct / 止盈止损     │
20:00  └──────────────────────────────────────────────┘
       ┌─ Stage 4: 参数优化 + 版本升级 ──────────────┐
       │ 择优参数 → 备份旧版 → 更新 global.json          │
       │ → 更新 graduation.json → 版本号递增              │
21:00  └──────────────────────────────────────────────┘
       ┌─ Stage 5: 模拟盘回放 ────────────────────────┐
       │ 用优化后参数跑新日期段（增量式，每次推进 30 天）    │
       │ backtest_training.py（参数化改造后）               │
01:00  └──────────────────────────────────────────────┘
       ┌─ Stage 6: 策略进化 ──────────────────────────┐
       │ knowledge_base 待验证策略 → 回测验证               │
       │ → 错误模式 → 新策略候选生成                       │
03:00  └──────────────────────────────────────────────┘
       ┌─ Stage 7: 整合与记忆晋升 ─────────────────────┐
       │ 汇总所有结果 → 更新 experience_bank              │
       │ → 同步 memory/trading/*.md → 更新 MEMORY.md     │
       │ → 写训练日志 → 生成训练报告                       │
05:00  └──────────────────────────────────────────────┘
       ┌─ Stage 8: 盘前准备 ──────────────────────────┐
       │ 综合夜间训练成果 → 更新关注股列表                   │
       │ → 调整风控参数 → 推送训练报告到 Telegram           │
08:30  └──────────────────────────────────────────────┘
```

### AT-4. 核心经验循环机制

```
                    ┌──────────────────┐
                    │  experience_bank │
                    │  (按市场环境索引)   │
                    └───┬──────────┬───┘
                        │          ↑
              读取当前环境  │          │ 回写新经验
              最优参数    │          │
                        ↓          │
┌─────────┐    ┌──────────────┐    ┌──────────────┐
│ 盘中交易  │───→│  当日复盘     │───→│  夜间训练     │
│ (白天)   │    │ (Stage 2)    │    │ (Stage 3-6)  │
└─────────┘    └──────────────┘    └──────┬───────┘
      ↑                                   │
      │         ┌──────────────┐          │
      └─────────│  记忆晋升     │←─────────┘
                │ (Stage 7)    │
                │ 更新 MEMORY  │
                │ 更新 params  │
                │ 更新 watchlist│
                └──────────────┘
```

**每日循环**：
1. 08:30 读取昨晚训练结果 → 生成今日策略
2. 09:30-15:00 盘中交易（用训练优化后的参数）
3. 16:00-05:00 夜间训练（基于今日交易结果 + 历史数据）
4. 05:00-08:30 整合记忆，准备下一天

### AT-5. 需要新建的文件（4 个）

#### 1. `modules/data/unified_data.py` — 统一数据层

职责：封装多源降级逻辑，对上层提供统一接口

```python
# 核心接口：
get_realtime_quotes(codes) → Dict      # 实时行情（新浪→腾讯→akshare）
get_daily_history(code, start, end) → DataFrame  # 日线（akshare→efinance→baostock）
get_index_realtime() → Dict             # 三大指数实时
get_index_daily(code, start, end) → DataFrame    # 指数日线
get_stock_pool() → DataFrame            # 全市场股票池（新浪批量）
get_trade_dates(start, end) → List      # 交易日历
refresh_all_cache(codes, start, end)     # 批量刷新缓存
```

每个函数内部自动降级，记录降级日志到 `shared/logs/data_source.log`。

#### 2. `modules/overnight/overnight_pipeline.py` — 夜间训练主编排

职责：按顺序执行 8 个 Stage，每个 Stage 独立可恢复

```python
# 核心逻辑：
def run_pipeline():
    state = load_state()  # 读取上次执行到哪个 stage

    stages = [
        ("data_refresh", run_data_refresh),      # Stage 1
        ("daily_review", run_daily_review),       # Stage 2
        ("walk_forward", run_walk_forward_multi), # Stage 3
        ("param_optimize", run_param_optimize),   # Stage 4
        ("paper_replay", run_paper_replay),       # Stage 5
        ("strategy_evolve", run_strategy_evolve), # Stage 6
        ("consolidate", run_consolidate),         # Stage 7
        ("morning_prep", run_morning_prep),       # Stage 8
    ]

    for name, func in stages:
        if state.get(name) == "done":
            continue  # 跳过已完成的 stage
        try:
            result = func()
            state[name] = "done"
            save_state(state)
        except Exception as e:
            state[name] = f"error: {e}"
            save_state(state)
            # 继续下一个 stage，不中断整条流水线
```

状态文件：`shared/db/overnight_state.json`（每次 16:00 重置）

#### 3. `modules/overnight/overnight_consolidator.py` — 结果整合

职责：Stage 7 的具体逻辑

```python
# 核心逻辑：
def consolidate():
    1. 读取 walk_forward_results.json     → 提取平均收益/胜率
    2. 读取 backtest_results.json         → 提取最新训练进度
    3. 读取 param_adjust.log              → 提取参数变动
    4. 更新 graduation.json               → 刷新毕业状态
    5. 更新 experience_bank.json          → 存入今夜经验
    6. 更新 memory/trading/strategy_params.md  → 最新参数
    7. 更新 memory/trading/weekly_summary.md   → 训练周报
    8. 生成 shared/db/overnight_report.json    → 完整报告
```

#### 4. `modules/overnight/data_refresh.py` — 数据刷新

职责：Stage 1 的具体逻辑

```python
# 核心逻辑：
def refresh():
    1. 获取最近 N 天缺失的日线数据（akshare，增量更新 shared/data/*.csv）
    2. 更新指数数据缓存
    3. 更新全市场股票池
    4. 清理过期缓存文件（>30天的分钟线缓存）
    5. 校验数据完整性（检查关键股票最新日期 == 今天）
```

### AT-6. 需要修改的现有文件（2 个）

#### 1. `backtest_training.py` — 日期参数化

当前问题：
- `start_date` 硬编码为 `"2025-01-02"`
- `end_date` 硬编码为 `"2025-02-22"`
- 已跑完 31 天，status = "completed"，无法继续

修改：
- `main()` 接受 `start_date` / `end_date` 参数
- 若不传参，自动从 `last_date` 续跑到今天
- `end_date` 默认改为"昨天"（确保数据已可用）
- 增加数据源降级（`unified_data.py`）

#### 2. `walk_forward.py` — 多参数集对比

当前：只测一组固定 `min_score=55` 参数
修改：支持传入多组参数，分别走 walk-forward，对比结果

### AT-7. Cron Job 变更

**删除**：
| Job ID | 名称 | 原因 |
|--------|------|------|
| `1a8d25a7-...` | cn-replay | 被夜间训练流水线替代 |

**新增**（3 个）：
| Job ID | 时间 | 名称 | 消息内容 | Timeout |
|--------|------|------|---------|---------|
| 新 | `0 16 * * 1-5` | cn-overnight-start | "执行夜间训练：启动 overnight_pipeline.py 后台运行，依次执行 Stage 1-6（数据刷新→当日复盘→Walk-Forward→参数优化→模拟回放→策略进化）" | 600s |
| 新 | `0 5 * * 2-6` | cn-overnight-consolidate | "整合昨夜训练结果：检查 overnight_state.json，执行 Stage 7（记忆晋升）和 Stage 8（盘前准备），更新 graduation.json / experience_bank / memory 文件，生成训练报告" | 600s |
| 新 | `30 8 * * 1-5` | cn-overnight-report | "推送夜间训练报告：读取 overnight_report.json，汇总训练成果（参数变动/毕业进度/关注股更新），发送 Telegram 摘要" | 300s |

注意：
- cn-overnight-start 在周一到周五 16:00（收盘后）
- cn-overnight-consolidate 在周二到周六 05:00（因为周一晚的训练到周二凌晨结束）
- cn-overnight-report 在周一到周五 08:30（开盘前）
- 现有的 cn-morning(09:00)、cn-noon(13:30)、cn-daily-report(15:30) 等不变

### AT-8. 超时问题解决方案

**问题**：Walk-Forward + 模拟回放可能运行数小时，cron timeout 只有 300-600 秒。

**方案**：cron 触发 agent → agent 用 `nohup python3 overnight_pipeline.py &` 后台启动 → pipeline 脚本自己管理进度和状态文件 → 第二天 05:00 的 cron 让 agent 检查结果。

具体流程：
```
16:00  cron 消息 → agent 收到 → exec("nohup python3 overnight_pipeline.py &")
       → agent 确认启动成功 → 回复 Telegram "夜间训练已启动"
       → agent session 结束（不等待 pipeline 完成）

16:00~05:00  pipeline.py 独立运行，每个 stage 写状态到 overnight_state.json

05:00  cron 消息 → agent 收到 → 读取 overnight_state.json
       → 执行 Stage 7 整合 + Stage 8 盘前准备
       → 更新 memory 文件
       → 回复 Telegram 训练结果
```

### AT-9. 安全约束

1. **参数调整幅度限制**：单次权重调整 ≤ ±10%，上限 30 下限 5（现有 auto_param_adjust.py 已有此限制）
2. **版本回滚**：每次参数变更前自动备份到 `shared/config/versions/`（现有 param_optimizer.py 已有）
3. **流水线不动生产**：只改 dayong 的训练数据和参数，不影响盘中交易决策（盘中用的是当前 global.json，下一个交易日才会用到更新后的参数）
4. **Stage 隔离**：单个 Stage 失败不中断整条流水线
5. **日志审计**：每个 Stage 的输入输出记录到 `shared/logs/overnight_YYYYMMDD.log`

### AT-10. 实施步骤（执行顺序）

| 步骤 | 内容 | 影响 | 复杂度 |
|------|------|------|--------|
| 1 | 新建 `modules/data/unified_data.py` | 不影响现有代码 | 中 |
| 2 | 新建 `modules/overnight/` 目录 + 3 个文件 | 不影响现有代码 | 中 |
| 3 | 修改 `backtest_training.py` 日期参数化 | 低风险（兼容现有调用） | 低 |
| 4 | 修改 `walk_forward.py` 多参数集 | 低风险（兼容现有调用） | 低 |
| 5 | 删除 cn-replay cron，新增 3 个夜间 cron | 替换关系 | 低 |
| 6 | 更新 HEARTBEAT.md + AGENTS.md | 上下文变更 | 低 |
| 7 | 重启 dayong Gateway | 生效配置 | 低 |
| 8 | 手动触发一次 overnight_pipeline.py 验证 | 验收 | - |

### AT-11. 预期效果

- **每晚额外训练量**：30-50 个交易日的模拟回放 + 多参数 walk-forward 验证
- **参数优化频率**：从"人工偶尔调"变成"每晚自动调"
- **毕业进度加速**：当前最大短板是胜率(19.64%)和盈亏比(2.06)，通过每晚优化参数权重，持续逼近毕业线
- **经验积累**：experience_bank 每晚新增一条市场环境索引的经验记录
- **完全无人值守**：16:00 启动 → 05:00 整合 → 08:30 推送，全程自动

---

## AU. 主 Gateway “Telegram 不回消息”复核：根因不是 Webhook 失效（2026-03-12 晚）

### 现象
- 用户反馈：主 Gateway 的 Telegram Bot 看起来像 “webhook 失效”，Gateway 进程似乎还在运行，但机器人不回消息。
- 现场时间窗口集中在 `2026-03-12 21:22` 到 `21:23 CST`。

### 关键证据

#### 1. Gateway 与 Webhook 侧都还活着
- `systemctl --user show openclaw-gateway`：
  - `ActiveState=active`
  - `SubState=running`
  - `ActiveEnterTimestamp=Thu 2026-03-12 21:22:22 CST`
- Telegram 配置仍是：
  - `defaultAccount = main-bot`
  - `webhookUrl = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
  - `webhookPort = 8787`
  - `proxy = http://127.0.0.1:7897`（在 `channels.telegram.accounts.main-bot` 下）
- `tailscale funnel status` / `tailscale serve status` 仍显示：
  - `443 -> 127.0.0.1:8787`
  - `8443 -> 127.0.0.1:8788`
- 通过代理查询 `getWebhookInfo` 返回：
  - `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
  - `pending_update_count = 0`
  - 无 `last_error_message`

#### 2. 真正失败的是 Telegram 出站发送，不是 Webhook 注册
- Gateway 日志在故障窗口记录到：
  - `sendChatAction failed: Network request for 'sendChatAction' failed!`
  - `message failed: Network request for 'sendMessage' failed!`
  - 没有出现 `setWebhook failed`
  - 没有出现 webhook URL 被 Telegram 清空
- 主 agent 最新 session `e6f494f5-cdc6-493e-ac86-8a631cd0d8ff.jsonl` 明确显示：
  - `21:22:56` 尝试用 `message` 工具发 Telegram 汇报
  - `21:23:06` 第 1 次失败：`Network request for 'sendMessage' failed!`
  - `21:23:20` 第 2 次失败
  - `21:23:33` 第 3 次失败
- 这说明：
  - Agent 逻辑在运行
  - 不是“消息根本没进 Gateway”
  - 而是“消息生成后，回发 Telegram 时出站失败”

#### 3. 主机对 Telegram 直连本来就不通，必须依赖代理
- 远端实测：
  - `curl -4 https://api.telegram.org/bot.../getMe` → `timeout`
  - `curl -4 -x http://127.0.0.1:7897 https://api.telegram.org/bot.../getMe` → 成功
- 结论：
  - 这台主机本来就需要靠 `mihomo` 代理访问 Telegram
  - 只要代理节点瞬时抖动，Webhook 虽然还能收消息，但回包会失败，看起来就像“机器人死了”

#### 4. 故障随后自行恢复
- 诊断期间再次实测：
  - 直接走 Bot API + 代理 `sendMessage` 成功
  - `openclaw message send --channel telegram --account main-bot --target 8226087994 --message ... --json` 成功返回 `messageId`
- 同时 Gateway 日志重新出现：
  - `sendMessage ok chat=8226087994 message=8745`
  - `sendMessage ok chat=8226087994 message=8746`

### 最终结论
- **这次不是 Telegram Webhook 失效。**
- **根因更准确地说，是主 Gateway 在 `2026-03-12 21:22~21:23 CST` 期间发生了 Telegram 出站网络失败。**
- Webhook、Funnel、本地监听、Telegram 侧 webhook 登记都正常。
- 真正脆弱点是：
  - 主机无法直连 Telegram
  - 必须依赖 `127.0.0.1:7897` 代理
  - 代理节点短时抖动时，OpenClaw 的 `sendMessage` / `sendChatAction` 会失败

### 复发时优先检查顺序
1. `journalctl --user -u openclaw-gateway -n 120 --no-pager`
   - 先看是不是 `sendMessage failed` / `sendChatAction failed`
2. 代理连通性对比：
   - `curl -4 https://api.telegram.org/bot<TOKEN>/getMe`
   - `curl -4 -x http://127.0.0.1:7897 https://api.telegram.org/bot<TOKEN>/getMe`
3. `getWebhookInfo`
   - 看 `url` 是否还在
   - 看 `pending_update_count` 是否堆积
4. `tailscale funnel status`
   - 确认 `443 -> 8787` 还在
5. 若仍未恢复：
   - 先重启 `mihomo-standalone`
   - 再重启 `openclaw-gateway`

### 本轮处理边界
- 未修改 `openclaw.json`
- 未修改 Telegram webhook 配置
- 未修改 Tailscale Funnel 配置
- 仅做只读排查 + 发信复验

---

## AV. Dayong Webhook 持久化失败根因与修复（2026-03-13）

### 现象
- `openclaw-gateway-dayong.service` 能自启，但重启后退回 Telegram polling。
- `127.0.0.1:8788` 不监听。
- Telegram `getWebhookInfo` 返回 `url=""`。
- 日志持续出现 `polling stall detected`。

### 根因
- `~/.openclaw-dayong/openclaw.json` 中，`webhookUrl` / `webhookSecret` 被错误写到了：
  - `channels.telegram.accounts.default.webhookUrl`
  - `channels.telegram.accounts.default.webhookSecret`
- 但 OpenClaw Telegram webhook 模式读取的是顶层：
  - `channels.telegram.webhookUrl`
  - `channels.telegram.webhookSecret`
  - `channels.telegram.webhookPort`
- 对照备份 `~/.openclaw-dayong/openclaw.json.bak`，可见备份文件结构是正确的，错误是后续配置迁移引入的。

### 官方对齐
- OpenClaw Telegram 文档要求 Webhook 模式使用顶层字段：
  - `channels.telegram.webhookUrl`
  - `channels.telegram.webhookSecret`
  - `channels.telegram.webhookPort`
- 文档页：`https://docs.openclaw.ai/channels/telegram`

### 已落地修复
- 将 `webhookUrl` / `webhookSecret` 从 `channels.telegram.accounts.default` 移回 `channels.telegram` 顶层。
- 保留 `webhookPort = 8788`。
- 删除错误的 `channels.telegram.accounts.default` 节点。
- 仅重启 `openclaw-gateway-dayong.service`，未触碰主 Gateway。

### 修复后验收
- dayong 启动日志恢复为：
  - `webhook local listener on http://127.0.0.1:8788/telegram-webhook`
  - `webhook advertised to telegram on https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
- `ss -ltnp` 可见 `127.0.0.1:8788` 监听。
- Telegram `getWebhookInfo` 返回：
  - `url = https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
  - `pending_update_count = 0`
  - `last_error_message = null`

### 重要补充
- `OPENCLAW_STATE_DIR=~/.openclaw-dayong openclaw gateway health --json` 在修复后仍可能显示 `webhook.url = ""`。
- 对 dayong 而言，`gateway health` 的 webhook 字段当前**不能单独作为真值来源**。
- 更可靠的验收源应为：
  1. dayong 启动日志中的 `webhook local listener` / `webhook advertised`
  2. Telegram 官方 `getWebhookInfo`
  3. 本地 `127.0.0.1:8788` 监听状态

### 重启持久化实测
- 修复后执行整机重启，dayong 再次自动恢复为 webhook 模式：
  - `127.0.0.1:8788` 自动监听
  - Telegram webhook URL 自动恢复为 `https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
- 说明 dayong 之前“重启后回不到旧状态”的根因并不是 systemd 或 Tailscale，而是**持久配置本身已经错了**。

---

## AW. 完整稳态验收（2026-03-13）与残留问题分级

### 验收范围
- Tailscale 节点在线与 SSH 直连
- Tailscale Serve/Funnel 与证书
- Mihomo 代理、`7897` 监听、`30s url-test`
- 主 Gateway 自启、`boot-md`、主 webhook
- dayong 自启、`8443 -> 8788 webhook`
- Telegram 服务器端 `getWebhookInfo`
- Cron 持久化与最近错误状态

### 核心链路验收结果

| 项目 | 结果 | 说明 |
|------|------|------|
| `tailscaled` 自启 | ✅ 通过 | `active + enabled` |
| 固定 Tailscale IP | ✅ 通过 | 仍为 `100.64.65.65` |
| Tailscale SSH | ✅ 通过 | 两次整机重启后均自动恢复 |
| Funnel `443/8443` | ✅ 通过 | 均可从外部 `curl -I` 到 `404` |
| Tailscale 证书 | ✅ 通过 | `CN=openclaw-24x7.tailda6e28.ts.net`，有效到 `2026-06-08` |
| Mihomo 自启 | ✅ 通过 | `127.0.0.1:7897` 监听恢复 |
| Mihomo 自动切换 | ✅ 通过 | `自动选择=url-test, interval=30`，日志可见香港节点切换 |
| 主 Gateway 自启 | ✅ 通过 | `openclaw-gateway.service` 重启后自动恢复 |
| 主 Boot Hook | ✅ 通过 | `boot-md -> gateway:startup` 已注册并执行 |
| 主 Webhook | ✅ 通过 | `443 -> 8787`，Telegram `url` 正确 |
| dayong 自启 | ✅ 通过 | `openclaw-gateway-dayong.service` 重启后自动恢复 |
| dayong Webhook | ✅ 通过 | `8443 -> 8788`，Telegram `url` 正确 |

### 残留问题（不阻断主链路）

#### 1. dayong `gateway health` 的 webhook 字段仍可能假阴性
- 实际状态已正常：
  - 日志出现 `webhook local listener` / `webhook advertised`
  - `127.0.0.1:8788` 在监听
  - Telegram `getWebhookInfo` 返回正确 `8443` URL
- 但 `OPENCLAW_STATE_DIR=~/.openclaw-dayong openclaw gateway health --json` 仍可能显示 `webhook.url=""`
- 结论：这是 dayong 当前的**诊断视图问题**，不是运行面故障

#### 2. Cron 投递层仍有残留项，但主 Gateway 的 `daily-self-improvement` 已完成定点修复
- 主 Gateway `daily-self-improvement` 的根因已确认并已修复：
  - 原 `sessionKey = agent:main:telegram:default:direct:8226087994`
  - 现已改为 `sessionKey = agent:main:telegram:main-bot:direct:8226087994`
  - 旧错误状态仍保留在 job `state` 中，直到下一次成功执行才会被自然覆盖
- dayong 多个 Cron 最近一次错误：
  - `Telegram recipient @heartbeat could not be resolved to a numeric chat ID`
- 这些错误说明：
  - **Cron 任务定义/投递目标** 还需要继续收口
  - 但**不影响 Tailscale、代理、主/副 Gateway、Webhook 主链路**

### 当前结论
- 如果把“完整稳态”定义为“机器重启后，远程可接入、代理可用、主 Gateway 可用、dayong webhook 可用”，当前已经通过。
- 如果把“完整稳态”进一步定义为“连所有 Cron 投递也无残留错误”，当前**还差 Cron 投递链**需要继续治理；其中主 Gateway 这条 `daily-self-improvement` 已进入“修复完成，待下一次自然执行验收”状态。

---

## AX. 主 Gateway `daily-self-improvement` Cron Telegram 投递修复（2026-03-13）

### 现象
- 主 Gateway 的 `daily-self-improvement` Cron 在 `2026-03-12 23:02:49 CST` 报错：
  - `Telegram bot token missing. Set TELEGRAM_BOT_TOKEN or channels.telegram.botToken.`
- 这不是主 Telegram 通道整体失效，因为主 Gateway 的 webhook、bot token、人工发信链路都正常。

### 根因
- 这条 job 存在旧会话上下文遗留：
  - `sessionKey = agent:main:telegram:default:direct:8226087994`
- 但主 Gateway 当前实际 Telegram 账号语义已经是：
  - `defaultAccount = main-bot`
  - `channels.telegram.accounts.main-bot.botToken = ...`
- 对照另一条正常主任务 `weekly-expense-summary`，它的 `sessionKey` 已是：
  - `agent:main:telegram:main-bot:direct:8226087994`
- 因此真正的问题不是“缺 token”，而是 **Cron 仍在旧 `default` 账号上下文里尝试投递**。

### 已落地修复
- 使用 OpenClaw 官方 CLI 的运行态接口，而不是手改 `jobs.json`：
  - `openclaw cron edit e43f2206-2f4c-4a98-bc45-453fa2b6ae13 --session-key agent:main:telegram:main-bot:direct:8226087994`
- 这样做的好处：
  - Gateway 运行态与持久化 store 同步更新
  - 不需要重启主 Gateway
  - 不会影响主 webhook 或 dayong

### 修复后验收
- `~/.openclaw/cron/jobs.json` 已更新为：
  - `sessionKey = agent:main:telegram:main-bot:direct:8226087994`
- `updatedAtMs` 已刷新为本次修复时间。
- `saveCronStore()` 自动保留了 `~/.openclaw/cron/jobs.json.bak`。
- 主 Gateway 进程未重启：
  - `MainPID = 1698`
  - `ExecMainStartTimestamp = Fri 2026-03-13 10:37:00 CST`
  - `ActiveState = active`

### 当前边界
- 按用户要求，本次**没有手动执行**这条 cron。
- 因此 job `state` 中仍保留上次失败记录：
  - `lastRunStatus = error`
  - `lastDeliveryStatus = not-delivered`
  - `consecutiveErrors = 1`
- 下一次自然验收点是：
  - `nextRunAtMs = 1773414000000`
  - 即 `2026-03-13 23:00:00 CST`
- 只有这次自然执行成功后，才会把历史 error 状态覆盖掉。

### 注意事项
- `openclaw cron edit` 执行时会打印一段 `Doctor` 提示，但本次**没有运行** `openclaw doctor --fix`。
- 因此本轮修复不涉及 `openclaw.json` 结构迁移，也没有触碰主 Gateway 的 Telegram webhook 配置。

---

## AY. 主 Gateway `BOOT.md` 防重判断修复（2026-03-13）

### 现象
- 主 Gateway 在 `2026-03-13 11:32 CST` 手动重启后，服务本身恢复正常，但没有再发出 Boot 检查消息。
- 排查后确认：
  - `boot-md` hook 已注册
  - `gateway:startup` 事件确实触发
  - Boot prompt 也确实进入了主会话
- 真正卡住的是 `BOOT.md` 的“2 分钟防重”判断。

### 根因
- 原 `BOOT.md` 的防重逻辑是自然语言：
  - 读 `memory/last-boot.txt`
  - 自己判断“是否 < 2 分钟”
  - 自己写“当前 Unix 时间戳”
- 这一步完全依赖模型自行心算时间戳。
- 实际 transcript 已证明：
  - 它之前就曾把“当前 Unix 时间戳”写错
  - 在本次手动重启时，又把错误时间戳误判成“距离现在不到 2 分钟”
  - 于是直接回复 `NO_REPLY`

### 已落地修复
- 仅修改远端主工作区：
  - `~/.openclaw/workspace/BOOT.md`
- 仅替换 `## 防重检查` 段落，不改检查项，不改 Telegram 输出文案。
- 新逻辑要求模型：
  - 必须先用 `exec` 执行 `date +%s`
  - 同时读取 `memory/last-boot.txt`
  - 用 shell 直接计算秒差
  - 以命令输出为准，而不是自行换算时间

### 变更后行为
- 若差值 `< 120` 秒：
  - 回复 `NO_REPLY`
- 若差值 `>= 120` 秒：
  - 用 `write` 工具把本次 `now` 写入 `memory/last-boot.txt`
  - 再继续执行后续 Boot 检查

### 变更边界
- 未修改主 Gateway 其它逻辑
- 未修改 Boot 检查项目
- 未修改 Telegram 汇报风格
- 未重启服务；该修复将在**下一次 Gateway 启动**时生效
- 已保留备份：
  - `~/.openclaw/workspace/BOOT.md.pre-dedup-fix-20260313-1`

---

## AZ. 远端 Linux 主机公网防护现状复核（2026-03-14）

### 核心结论
- **当前仍然存在 2 个刻意保留的公网 HTTPS 入口**：
  - `https://openclaw-24x7.tailda6e28.ts.net`
  - `https://openclaw-24x7.tailda6e28.ts.net:8443`
- **OpenClaw 本体与代理没有直接绑公网**：
  - main：`127.0.0.1:18790` + `127.0.0.1:8787`
  - dayong：`127.0.0.1:19021` + `127.0.0.1:8788`
  - mihomo：`127.0.0.1:7897` + `127.0.0.1:5334`
- **SSH 当前不是“监听面收口”，而是“监听全网卡 + UFW 来源收口”**：
  - `ssh.socket` 监听 `0.0.0.0:22` / `[::]:22`
  - `ufw` 默认 `deny (incoming)`
  - 仅放行：
    - `192.168.50.0/24`
    - `100.64.0.0/10`

### 2026-03-14 实时证据

#### 1. Tailscale / Funnel
- `tailscale status --self --json`：
  - `BackendState = Running`
  - `TailscaleIPs = 100.64.65.65 / fd7a:115c:a1e0::8f3b:4141`
  - `Capabilities` 包含：
    - `funnel`
    - `https`
    - `https://tailscale.com/cap/ssh`
- `tailscale funnel status` / `tailscale serve status`：
  - `https://openclaw-24x7.tailda6e28.ts.net -> http://127.0.0.1:8787`
  - `https://openclaw-24x7.tailda6e28.ts.net:8443 -> http://127.0.0.1:8788`
- 本地复核公网入口：
  - 直接请求两个公网根路径均返回 `404`
  - 说明公网 HTTPS 入口当前在线

#### 2. 监听地址
- `ss -ltnp` 关键结果：
  - `127.0.0.1:8787` → `openclaw-gateway`
  - `127.0.0.1:8788` → `openclaw-gateway-dayong`
  - `127.0.0.1:18790` / `[::1]:18790` → main Gateway
  - `127.0.0.1:19021` / `[::1]:19021` → dayong Gateway
  - `127.0.0.1:7897` / `127.0.0.1:5334` → `verge-mihomo`
  - `0.0.0.0:22` / `[::]:22` → SSH socket
- 结论：
  - **OpenClaw / 代理层当前仍是正确的 `loopback` 防护**
  - **SSH 没有像 OpenClaw 一样只绑到 loopback / tailscale0**

#### 3. UFW
- `ufw status verbose`：
  - `Status: active`
  - `Default: deny (incoming), allow (outgoing), deny (routed)`
  - 仅两条入站允许：
    - `Anywhere ALLOW IN 192.168.50.0/24`
    - `Anywhere ALLOW IN 100.64.0.0/10`
- 结论：
  - **任意公网来源直打 22，当前在主机防火墙层是被挡住的**
  - **但局域网整个 `192.168.50.0/24` 仍可进 SSH**

#### 4. SSH 当前形态
- `systemctl` 状态：
  - `ssh.socket = active + enabled`
  - `ssh.service = inactive`（socket activation）
- `ssh.socket` 明确监听：
  - `0.0.0.0:22`
  - `[::]:22`
- `sshd_config` 当前显式项只有：
  - `KbdInteractiveAuthentication no`
  - `UsePAM yes`
  - `X11Forwarding yes`
- 本轮限制：
  - 非 root 运行 `/usr/sbin/sshd -T` 报 `no hostkeys available -- exiting`
  - `sudo -n /usr/sbin/sshd -T` 不可用
- 因此本轮**无法直接重跑**完整生效配置。
- 但结合：
  - 当前配置文件里**没有**显式 `PasswordAuthentication no`
  - 以及 2026-03-13 上一轮已抓到的 live 结果：
    - `passwordauthentication yes`
- 当前最稳妥判断仍是：
  - **SSH 认证层大概率还没完成第二阶段收紧**

#### 5. Webhook 本地鉴权面
- 两套配置中都确认：
  - `gateway.bind = loopback`
  - `webhookSecret_present = True`
- 本地探测：
  - `GET /telegram-webhook` → `404`
  - 无 secret / 错 secret 的最小 `POST` 请求 → `400`
- 说明：
  - 路由还在
  - 但这次用最小 JSON 负载没有得到之前见过的 `401`
- 当前只能确认：
  - **webhookSecret 仍已配置**
  - **本地随便 GET 不会命中有效 handler**
- 不能仅凭这次 `400` 断言“secret 校验已失效”；更像是请求在更早阶段被判为 bad request。

### 当前风险分级

#### 已收紧
- OpenClaw / mihomo 全部只绑 `127.0.0.1`
- 入站默认策略是 `ufw deny incoming`
- 任意公网来源不在 SSH 放行范围内
- 对公网暴露的仍是 Funnel，而不是 `18790/19021/8787/8788/7897`

#### 仍暴露 / 仍偏松
- 仍保留 **两个** 公网 Funnel 入口（`443` + `8443`）
- SSH 仍监听全部网卡，而不是只监听特定来源接口
- `192.168.50.0/24` 整个局域网都可打 SSH
- `wlp0s20f3` 当前重新处于 `UP` 状态，并拿到 `192.168.50.117/24`

#### 下一步最优先顺序
1. 第二阶段收紧 SSH：
   - 明确落地 `PasswordAuthentication no`
   - 视需要关闭 `X11Forwarding`
   - 若可行，限制 `ListenAddress` 到局域网 / Tailscale
2. 评估是否把两个 Funnel 收缩为一个 `443`
3. 若继续长期使用双 Gateway：
   - 在单一 Funnel 前加极薄反向代理，只放两条精确 webhook path

---

## BA. Windows 电脑侧 SSH / 公网防护现状复核（2026-03-14）

### 目标判定
用户的目标是：
- 允许小龙虾 Linux 机器连入本机 Windows 做操作
- 同时把 SSH 面尽量收窄到“只有那台 Linux 能连”

**本轮结论：当前还没有做到这一点。**

### 1. 当前不是 Tailscale SSH，而是 OpenSSH 跑在 Tailscale 网络上
- `tailscale debug prefs` 明确显示：
  - `RunSSH = false`
- 但本机 `22/tcp` 确实在监听：
  - `0.0.0.0:22`
  - `[::]:22`
- `sshd` 服务状态：
  - `Running`
  - `Automatic`
- 结论：
  - 现在允许连接的并不是 “Tailscale SSH policy”
  - 而是 **Windows OpenSSH Server**
  - Tailscale 只是提供了一条 `100.97.45.87` 的可达网络路径

### 2. 小龙虾 Linux 当前确实能打到本机 SSH
- 从远端 `openclaw-24x7 (100.64.65.65)` 实测：
  - `TCP_22 OPEN`
  - SSH banner 返回：`SSH-2.0-OpenSSH_for_Windows_9.5`
- 这说明：
  - Linux -> Windows 的 Tailscale 内网连通性没问题
  - 当前 22 口对那台 Linux 是开放的

### 3. 但当前 22 并没有只对那台 Linux 开放

#### 3.1 防火墙规则明显偏宽
- 当前启用的 SSH 相关入站规则包括：
  - `OpenSSH Server (sshd)`：
    - `Profile = Any`
    - `LocalPort = 22`
    - `RemoteAddress = Any`
  - `OpenSSH SSH Server (sshd)`：
    - `Profile = Private`
    - `RemoteAddress = Any`
  - `OpenSSH SSH Server (sshd) - Public LocalSubnet`
    - `Profile = Public`
    - `RemoteAddress = LocalSubnet`
  - `SSH-Tailscale-Inbound`
    - `Profile = Any`
    - `RemoteAddress = 100.97.45.0/255.255.255.0`
- 结论：
  - **并不是只有 `100.64.65.65` 能连**
  - 只要能到达这台 Windows 的主机，并且命中上述规则，也可能打到 `22`

#### 3.2 当前网络环境还会放大这个问题
- `Get-NetConnectionProfile` 显示：
  - `WLAN (work_5G) = Public`
  - `Tailscale = Private`
- 因为已有 `Profile = Any` 且 `RemoteAddress = Any` 的 SSH 规则：
  - Tailscale 内其他设备并不被排除
  - 本地网络侧的进入面也没有被精确限制到单一主机

### 4. 当前 authorized_keys 走的是管理员专用文件
- `C:\ProgramData\ssh\sshd_config` 显示：
  - `Match Group administrators`
  - `AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys`
- 本机 `kevinlasnh` 确认属于 `Administrators` 组。
- 因此，对该账号的 SSH 公钥认证，实际主要看：
  - `C:\ProgramData\ssh\administrators_authorized_keys`
- 当前限制：
  - 该文件存在，但当前会话**无提升权限**，无法读取内容
  - 因此本轮**无法确认**里面到底只有 1 把 key，还是有多把 key
- 可见侧信息：
  - `C:\Users\kevinlasnh\.ssh\authorized_keys` 存在 4 条 key
  - 但对管理员账户登录而言，它**不是主判定文件**

### 5. Tailscale 侧现状
- 本机 Tailscale 状态：
  - IP：`100.97.45.87`
  - `WantRunning = true`
  - `RunSSH = false`
  - `ShieldsUp = false`
- 远端小龙虾 Linux 节点：
  - `openclaw-24x7`
  - `100.64.65.65`
  - 当前在线
- 结论：
  - Tailscale 本身在线、可达
  - 但**没有启用 Tailscale SSH 的设备级/ACL 约束**

### 当前风险判断

#### 已满足的部分
- 小龙虾 Linux 当前可以通过 Tailscale 路径打到本机 SSH
- 这条运维链路是通的

#### 未满足的部分
- **还没有做到“只允许小龙虾 Linux 连接”**
- 当前更接近：
  - “任何能命中 Windows SSH 防火墙允许规则的来源，都可能尝试连接”

### 后续最小改动方向
1. 把 Windows 防火墙的 SSH 入站规则收窄到：
   - 仅允许远端 `100.64.65.65`
   - 或至少仅允许 `Tailscale` 接口 + 指定远端地址
2. 清理/禁用多余的 `OpenSSH` 默认规则：
   - 尤其是 `Profile=Any, RemoteAddress=Any`
3. 若目标是真正的 “Tailscale SSH”：
   - 需要重新评估是否切换 `RunSSH=true`
   - 但这与当前 Windows OpenSSH 模式是两条不同路线

---

## BB. Windows SSH 精确收口方案调研（仅手机 + Linux，2026-03-14）

### 目标重定义
用户在 2026-03-14 明确补充的真实目标不是“只允许 Linux 一台”，而是：
- 允许小龙虾 Linux 通过 Tailscale 路径 SSH 到本机 Windows
- 同时允许手机通过 Tailscale 路径 SSH 到本机 Windows
- 其余来源，尤其是其他公网来源和其他不需要的 tailnet / 局域网来源，尽量不要碰到本机 SSH

### 1. 手机当前实时身份已经确认

#### 1.1 当前在线手机节点
- 本机 `tailscale status --json` 实时显示：
  - `pixel-5-3.tailda6e28.ts.net`
  - `OS = android`
  - `Online = true`
  - `Active = true`
  - `Tailscale IP = 100.100.237.12`

#### 1.2 刚刚这次手机 SSH 已被 Windows 实时日志确认
- `OpenSSH/Operational` 日志在 **2026-03-14 10:13:02** 记录：
  - `Accepted publickey for kevinlasnh from 100.100.237.12`
  - key 指纹：
    - `SHA256:uno89lhmAtTHU//qrt306NZkx4Jiqk0t0DtVh22pbZY`
- 本机可见公钥文件 `C:\Users\kevinlasnh\.ssh\termux_phone.pub` 的指纹实测与之完全一致：
  - `SHA256:uno89lhmAtTHU//qrt306NZkx4Jiqk0t0DtVh22pbZY`
- 结论：
  - 手机这次登录来源就是 **当前在线的 `pixel-5-3 / 100.100.237.12`**
  - 至少“手机可连 Windows SSH”这条链路目前是活的

#### 1.3 手机节点存在历史漂移
- 本机当前仍保留 4 个 Android 历史节点：
  - `pixel-5` -> `100.123.112.69`
  - `pixel-5-1` -> `100.90.223.79`
  - `pixel-5-2` -> `100.84.205.105`
  - `pixel-5-3` -> `100.100.237.12`
- 其中最近一次活跃的是：
  - `pixel-5-3`
  - `LastSeen = 2026-03-14` 当次在线
- 结论：
  - 手机的 **当前节点 / IP 可以确认**
  - 但历史上确实发生过“节点重建后获得新名字 / 新 Tailscale IP”
  - 所以如果把 Windows 防火墙硬编码成“只允许某一个手机 IP”，长期维护成本会偏高

### 2. Linux 当前身份也已经确认
- 小龙虾 Linux 当前节点：
  - `openclaw-24x7.tailda6e28.ts.net`
  - `100.64.65.65`
  - 在线
- Windows `OpenSSH/Operational` 日志也已多次记录：
  - 来源：`100.64.65.65`
  - 指纹：`SHA256:oM6lVLD19Ac0tZFO0YkHdjjWCqdyW/pBlM/55MdvB9M`
- 远端 Linux 自身 `~/.ssh/id_ed25519.pub` 的指纹实测与之匹配。

### 3. 官方能力边界已经确认

#### 3.1 Windows 不能作为 Tailscale SSH 服务端目标
- Tailscale 官方 `Tailscale SSH` 文档当前写明：
  - SSH server feature supports **Linux, macOS, and FreeBSD**
  - 不包含 Windows
- 这与本机实时状态一致：
  - `tailscale debug prefs` 显示 `RunSSH = false`
- 结论：
  - 这台 Windows 机**不能**靠“开启 Tailscale SSH”来实现设备级 SSH 收口
  - 正确路线只能是：
    - **Windows OpenSSH Server**
    - 加上 **Tailscale 网络访问控制**
    - 再叠加 **Windows Defender Firewall**

#### 3.2 Tailscale 默认允许 tailnet 内设备互通
- Tailscale 官方当前文档说明：
  - `Allow incoming connections` 默认开启
  - 若不写自定义访问控制，默认行为接近“用户自有设备互通”
- 本机实时也验证了这一点：
  - `tailscale debug prefs` 显示 `ShieldsUp = false`
  - 从 Linux 对 Windows 的 `100.97.45.87` 实测，不止 `22` 可达，以下端口也可达：
    - `135`
    - `445`
    - `2179`
    - `5040`
    - `5357`
    - `7680`
    - `9527`
    - 以及 Tailscale 自身的 `2222`、`18789`
- 结论：
  - **当前不是“只有 SSH 暴露给 tailnet”**
  - 实际上这台 Windows 机在 Tailscale 私网面暴露的服务比预期更宽

#### 3.3 `Shields up` 不是这次目标的答案
- Tailscale 官方当前文档说明：
  - `Shields up` / `block incoming connections` 是本机级总开关
  - 打开后会阻止来自 tailnet 的入站连接
- 因此：
  - 若打开它，手机和 Linux 的 SSH 一起会断
  - 它适合应急熔断，不适合“只放两台设备”的精确准入

#### 3.4 Tailscale 访问控制可以精确限制设备到端口
- Tailscale 官方 `grants` / targets 文档当前说明：
  - 可以用设备、用户、IP、host alias 等选择器定义源和目标
  - 目标可以精确到 `IP:port`
- 这意味着：
  - 可以在 tailnet policy 里把访问 Windows `22/tcp` 的权限精确收窄到：
    - Linux 设备
    - 手机设备
  - 同时不给其它设备访问 Windows 的其它端口

### 4. 三层暴露面实测

#### 4.1 公网侧
- 本机实际公网出口 IP：
  - `223.74.154.77`
- 从 Linux 对该公网 IP 实测：
  - `22/135/445/2179/5040/5357/7680/9527` 全部 `CLOSED`
- 说明：
  - 当前**没有证据**显示这些端口被直接暴露到公网
- 但边界要讲清：
  - 这次测试来自同一局域网 / 同一公网出口后的机器
  - 属于 NAT hairpin 场景
  - 参考价值高，但不等于第三方互联网测点的绝对证明

#### 4.2 局域网侧
- 从 Linux 对 Windows 局域网地址 `192.168.50.113` 实测：
  - `22` = `OPEN`
  - `135` = `OPEN`
  - `2179` = `OPEN`
  - `7680` = `OPEN`
  - `9527` = `OPEN`
  - `139/445/5040/5357` 在本次测试中未打通
- 结论：
  - 即使不走 Tailscale，同一局域网内也还有多项服务可达
  - 因此“只允许手机 + Linux 连 SSH”这个目标，目前在局域网侧也还没有完全落地

#### 4.3 Tailscale 私网侧
- 从 Linux 对 Windows Tailscale 地址 `100.97.45.87` 实测：
  - `22` = `OPEN`
  - `135` = `OPEN`
  - `445` = `OPEN`
  - `2179` = `OPEN`
  - `5040` = `OPEN`
  - `5357` = `OPEN`
  - `7680` = `OPEN`
  - `9527` = `OPEN`
- 结论：
  - **当前 tailnet 内暴露面明显偏宽**
  - 这也是为什么“只收 SSH 默认规则”还不够，必须把 tailnet policy 也一起收

### 5. 为什么当前会这么宽

#### 5.1 Windows 自身的 SSH 规则过宽
- 已确认存在以下启用中的 SSH 入站规则：
  - `OpenSSH Server (sshd)`：`Profile = Any`, `RemoteAddress = Any`
  - `OpenSSH SSH Server (sshd)`：`Profile = Private`, `RemoteAddress = Any`
  - `OpenSSH SSH Server Preview (sshd)`：`Profile = Private`, `RemoteAddress = Any`
  - `SSH-Tailscale-Inbound`：`RemoteAddress = 100.97.45.0/255.255.255.0`
- 这意味着：
  - Windows 本机并没有把 SSH 精确限制到 Linux + 手机两个来源

#### 5.2 Tailscale 接口当前属于 `Private`
- 本机网络配置已确认：
  - `WLAN (work_5G) = Public`
  - `Tailscale = Private`
- 这会导致：
  - 很多 Windows “私有网络可入站”的规则同时落到 Tailscale 接口上
- 这与端口实测结果吻合。

### 6. 推荐目标态

#### 推荐方案：两层强约束 + 一层可选兜底

##### 第一层：tailnet policy 精确到设备与端口
- 在 Tailscale 管理端把访问 Windows SSH 的权限只留给：
  - `openclaw-24x7`
  - 当前手机节点（建议后续给手机设稳定 alias，而不是长期依赖 `pixel-5-3` 这种会漂的名字）
- 目标只放：
  - `Windows-device:22`
- 不给其它设备访问这台 Windows 的其它端口。

##### 第二层：Windows 防火墙只允许 Tailscale 侧 SSH
- 禁用现有过宽的 OpenSSH 默认规则：
  - 尤其是 `Profile = Any / RemoteAddress = Any`
- 新建更窄的入站规则：
  - 仅 `22/tcp`
  - 仅 SSH 程序
  - 仅来自 `100.64.0.0/10`（Tailscale CGNAT）
- 这样做的直接收益是：
  - 局域网不再能直接打本机 SSH
  - 公网也不再能直接打本机 SSH
  - SSH 链路只留给 Tailscale

##### 第三层：可选的本机 IP 白名单兜底
- 如果你坚持“即使 tailnet policy 以后被人改宽了，本机也仍然只认两台设备”，可以额外把 Windows 防火墙 SSH 规则再收成：
  - `100.64.65.65`
  - `100.100.237.12`
- 但必须接受一个代价：
  - 你的手机节点一旦重建、名字变化或换到新 Tailscale IP，这条规则会失效，需要手动同步更新

### 7. 推荐结论

#### 最稳、最可维护的路线
1. **不要**继续追“Windows 作为 Tailscale SSH 服务端”这条路：
   - 官方当前就不支持
2. 采用：
   - **Windows OpenSSH**
   - + **Tailscale grants / access control** 做“只有手机 + Linux”
   - + **Windows 防火墙** 做“只允许来自 Tailscale 的 SSH，切掉 LAN / 公网 SSH”
3. 若你要更强兜底，再把 Windows 防火墙远端地址收成两台设备当前 IP：
   - 但要接受手机节点漂移后的维护成本

#### 风险优先级
- **公网直接暴露风险**：当前未见证据被打通，风险相对低
- **局域网侧多余暴露**：当前中等
- **tailnet 侧多余暴露**：当前最高，且已经被实测证实

### 8. 下一步实施顺序
1. 先改 tailnet policy，把 Windows 设备的可达面收成“仅手机 + Linux -> 22/tcp”
2. 再改 Windows 防火墙，禁用默认过宽 SSH 规则，只保留 Tailscale 侧 SSH
3. 最后做双设备回归：
   - Linux SSH 成功
   - 手机 SSH 成功
   - 其它 tailnet 设备 / 局域网设备对 `22` 失败
4. 若需要，再追加“当前两台设备 IP 白名单”这层兜底

---

## BC. Windows SSH 收口部署（手机 + Linux，本机侧已落地，2026-03-14）

### 1. 本轮实际完成的部署

#### 1.1 `sshd_config` 已经收紧
- 部署前做了静态校验：
  - `C:\Windows\System32\OpenSSH\sshd.exe -t -f <edited sshd_config>`
  - 结果：通过
- 已落地到 `C:\ProgramData\ssh\sshd_config` 的关键项：
  - `PubkeyAuthentication yes`
  - `PasswordAuthentication no`
  - `PermitEmptyPasswords no`
  - `KbdInteractiveAuthentication no`
  - `AllowUsers kevinlasnh`
- `Match Group administrators` 仍保留：
  - `AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys`
- 提升权限后用 `sshd -T -C user=kevinlasnh,host=localhost,addr=100.64.65.65` 实测生效值：
  - `pubkeyauthentication yes`
  - `passwordauthentication no`
  - `authorizedkeysfile __PROGRAMDATA__/ssh/administrators_authorized_keys`
  - `allowusers kevinlasnh`

#### 1.2 管理员授权 key 文件已收口
- `C:\ProgramData\ssh\administrators_authorized_keys` 原先有 3 行：
  - 其中第 1 行是坏掉的 `ed25519` 公钥，`ssh-keygen` 无法识别
  - 第 2 行是当前 Linux key
  - 第 3 行是手机 `termux_phone` key
- 本轮已删除第 1 行坏 key，只保留当前两把有效 key：
  - Linux：
    - `SHA256:oM6lVLD19Ac0tZFO0YkHdjjWCqdyW/pBlM/55MdvB9M`
  - 手机：
    - `SHA256:uno89lhmAtTHU//qrt306NZkx4Jiqk0t0DtVh22pbZY`
- ACL 已重新收紧为：
  - `SYSTEM:(F)`
  - `Administrators:(F)`

#### 1.3 Windows SSH 防火墙已切成“仅批准的 Tailscale 设备”
- 原有宽规则已全部禁用：
  - `OpenSSH Server (sshd)`
  - `OpenSSH SSH Server (sshd)`
  - `OpenSSH SSH Server Preview (sshd)`
  - `OpenSSH SSH Server (sshd) - Public LocalSubnet`
  - `SSH-Tailscale-Inbound`
- 已新建规则：
  - `SSH-Approved-Tailscale-Devices`
- 新规则关键条件：
  - 方向：`Inbound`
  - 动作：`Allow`
  - 程序：`C:\Windows\System32\OpenSSH\sshd.exe`
  - 协议：`TCP`
  - 端口：`22`
  - 接口：`Tailscale`
  - 远端地址：
    - `100.64.65.65`
    - `fd7a:115c:a1e0::8f3b:4141`
    - `100.100.237.12`
    - `fd7a:115c:a1e0::63b:ed0c`

### 2. 本轮验证结果

#### 2.1 Linux -> Windows Tailscale SSH 仍正常
- 从 Linux 远端实测：
  - `ssh kevinlasnh@100.97.45.87 'echo WINDOWS_SSH_OK'`
  - 结果：成功返回 `WINDOWS_SSH_OK`
- 在手机重新确认可连之后，再次从 Linux 新建连接实测：
  - `ssh kevinlasnh@100.97.45.87 'hostname'`
  - 结果：成功返回 `DESKTOP-JRVIDLH`
- Windows `OpenSSH/Operational` 同步记录：
  - `2026-03-14 10:53:13`
  - `Accepted publickey for kevinlasnh from 100.64.65.65`
  - 指纹：`SHA256:oM6lVLD19Ac0tZFO0YkHdjjWCqdyW/pBlM/55MdvB9M`

#### 2.2 局域网直打 22 已被挡住
- 从 Linux 对 Windows 局域网地址 `192.168.50.113:22` 实测：
  - `CLOSED (TimeoutError)`

#### 2.3 公网直打 22 仍未打通
- 从 Linux 对本机公网 IP `223.74.154.77:22` 实测：
  - `CLOSED (TimeoutError)`

#### 2.4 手机当前会话仍在
- 本机部署完成后查看当前已建立 SSH 会话：
  - `100.97.45.87:22 <- 100.100.237.12:38262`
  - 状态：`Established`
- 说明：
  - 手机当前这条 SSH 链路没有被新规则切断
- 边界：
  - 这是“现有会话仍活着”的证据
  - 严格意义上，仍建议再做一次手机**新建连接**回归，以确认新会话也完全正常

### 3. 风险状态变化

#### 已经显著收紧的部分
- Windows SSH 不再对：
  - 局域网任意设备
  - 公网任意来源
  - 其它未批准的 Tailscale 设备
  开放
- SSH 认证层也已从“可能允许密码”收紧为：
  - 仅公钥
  - 仅 `kevinlasnh`

#### 仍然保留的限制 / 待办
- 本轮**没有**直接改到 Tailscale 管理后台的 `grants / ACL`
- 原因不是方案错误，而是：
  - 当前本机会话没有可直接调用 tailnet admin policy 的 CLI / API 入口
  - 仓库里历史记录也表明这类改动是在 `https://login.tailscale.com/admin/acls` 后台做的
- 因此当前状态是：
  - **Windows 本机侧已经落到比“只允许 Tailscale 侧 SSH”更严格的状态**
  - 但“设备级授权也由 tailnet policy 统一托管”这一步，还需在 Tailscale 后台补齐

### 4. 维护提醒
- 当前 Windows SSH 白名单里写死了手机当前节点 IP：
  - `100.100.237.12`
  - `fd7a:115c:a1e0::63b:ed0c`
- 如果手机未来：
  - 重新登录 Tailscale
  - 删除节点后重建
  - 生成了新的 `pixel-5-*` 节点
  - 获得新的 Tailscale IP
  那么本机 SSH 规则需要同步更新
- 这也是为什么长期来看，仍建议把“允许哪台设备访问 `Windows:22`”迁移到 tailnet policy / grants，而让 Windows 防火墙只负责“SSH 只接受 Tailscale 侧流量”。

### 5. 备份位置
- 本轮本机侧变更前的备份位于：
  - `C:\Users\kevinlasnh\AppData\Local\Temp\windows-ssh-hardening-20260314-104150`
- 其中包括：
  - `sshd_config.bak`
  - `administrators_authorized_keys.bak`
  - `ssh_firewall_rules_before.json`
  - `ssh_firewall_rules_after.json`

---

## BD. Windows 非 SSH 暴露面全面调研（tailnet / 私网，2026-03-14）

### 1. 当前问题的真实边界
- 经过 `BC` 节的部署后，Windows 的 **SSH 面**已经收住：
  - Linux 和手机可以通过 Tailscale SSH 进来
  - 局域网 / 公网对 `22` 不再直通
- 但这不等于“整台 Windows 的其它入站面也已经收住”。
- 本轮调研聚焦的是：
  - 除 `22` 之外，还有哪些 TCP/UDP 服务可从 tailnet / 局域网打到本机
  - 它们分别来自什么服务、什么规则、是否必要

### 2. 本机当前监听面（非回环）

#### 2.1 TCP 监听面
- 当前非回环 TCP 监听主要包括：
  - `135` -> `svchost` / `RpcEptMapper,RpcSs`
  - `139` -> `System`
  - `445` -> `System`
  - `2179` -> `vmms`
  - `2222` -> `tailscaled`
  - `5040` -> `svchost` / `CDPSvc`
  - `5357` -> `System`
  - `7680` -> `svchost` / `DoSvc`
  - `9527` -> `voicing.exe`
  - `18789` -> `tailscaled`
  - `49664` -> `lsass` / `KeyIso,SamSs,VaultSvc`
  - `49665` -> `wininit`
  - `49666` -> `svchost` / `Schedule`
  - `49667` -> `svchost` / `EventLog`
  - `49668` -> `spoolsv` / `Spooler`
  - `50412` -> `services`
  - `59069` -> `tailscaled`

#### 2.2 UDP 监听面（只做本机枚举，未逐项外部探测）
- 还能看到若干非回环 UDP 监听，包括：
  - `53`
  - `67/68`
  - `137/138`
  - `500/4500`
  - `1900`
  - `3702`
  - `5050`
  - `5353`
  - `5355`
  - `41641`
  - `49671-49674`
  - `54960`
- 结论：
  - 这次风险判断以 **TCP 可达性** 为主，因为这些端口已被远端实测证实
  - UDP 面后续如需再收，可以作为第二阶段细化

### 3. 远端实测：哪些端口真的能打通

#### 3.1 从 Linux 对 Windows Tailscale IP `100.97.45.87` 实测
- `OPEN`：
  - `22`
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
- 说明：
  - 当前 tailnet 内暴露面依旧很宽
  - 只是 `22` 已被特殊收成“只允许批准设备”

#### 3.2 从 Linux 对 Windows 局域网 IP `192.168.50.113` 实测
- `OPEN`：
  - `135`
  - `2179`
  - `7680`
  - `9527`
- `CLOSED`：
  - `22`
  - `139`
  - `445`
  - `5040`
  - `5357`
  - `49664`
  - `49665`
  - `49666`
  - `49667`
  - `49668`
  - `50412`
- 说明：
  - 当前 WLAN 是 `Public`
  - 所以只有 `Profile = Any` 或 `Public` 的规则还会继续打到局域网面

### 4. 这些开放面分别来自什么

#### 4.1 Hyper-V 远程管理面：`135` / `2179` 以及一部分 RPC 动态面
- 本机 `vmms` 正在运行：
  - `Hyper-V 虚拟机管理`
- 当前明确存在且启用的 Hyper-V 入站规则包括：
  - `Hyper-V - WMI (DCOM-In)` -> `TCP 135`, `Profile = Any`, `RemoteAddress = Any`
  - `Hyper-V (REMOTE_DESKTOP_TCP_IN)` -> `TCP 2179`, `Profile = Any`, `RemoteAddress = Any`
  - 以及：
    - `Hyper-V (RPC)`
    - `Hyper-V (RPC-EPMAP)`
    - `Hyper-V - WMI (Async-In)`
    - `Hyper-V - WMI (TCP-In)`
    - `Hyper-V 管理客户端 - WMI (...)`
- 结论：
  - 这组规则是当前 `135` / `2179` 在 tailnet 和局域网面暴露的主要来源之一
  - 如果用户**不需要远程管理 Hyper-V / VM console**，这是优先级最高的一批可收口对象

#### 4.2 文件和打印机共享 / SMB：`445`
- 本机 `445` 由 `System` 监听。
- `netsh advfirewall` 上下文已确认存在多条：
  - `文件和打印机共享(...)`
  - 以及与 `Spooler` / `RPCSS` 相关的共享规则
- 结论：
  - `445` 属于 **高风险传统暴露面**
  - 当前它至少对 tailnet 是通的
  - 如果用户不需要通过 Tailscale 访问 SMB / 打印共享，应优先关闭对应入站规则

#### 4.3 Connected Devices Platform：`5040`
- `5040` 当前由：
  - `svchost` / `CDPSvc`
  监听
- `netsh advfirewall` 上下文确认存在：
  - `连接设备平台(TCP-In)`
  - `连接设备平台(UDP-In)`
  - `连接设备平台 - Wi-Fi Direct 传输(TCP-In)`
- 这些规则显示的关键点是：
  - `Program = svchost.exe`
  - `Service = CDPSvc`
  - `LocalPort = Any`
  - `RemoteIP = Any`
- 结论：
  - 这是一个 **典型“系统自带功能型服务被私网放宽”** 的暴露面
  - 当前在 tailnet 可达、但在 WLAN Public 面不通，说明它大概率受 `Private` 侧规则影响
  - 若用户不依赖 Nearby / 跨设备 / Wi-Fi Direct 相关功能，这批规则很值得收

#### 4.4 Network Discovery / WSD：`5357`
- `5357` 当前由 `System` 监听。
- 已确认存在：
  - `网络发现(WSD Events-In)`
  - `网络发现(WSD EventsSecure-In)`
- 其中至少有：
  - `Profile = Private`
- 结论：
  - 这解释了为什么 `5357` 在 tailnet 可达、在当前 WLAN Public 面不通
  - 如果用户不需要网络发现 / WSD 事件，这组规则通常可以关闭

#### 4.5 Delivery Optimization：`7680`
- `7680` 当前由：
  - `svchost` / `DoSvc`
  监听
- 已确认存在：
  - `Delivery Optimization (TCP-In)`
  - `Profile = Any`
  - `RemoteAddress = Any`
- 结论：
  - 这是当前同时打到 **tailnet + 局域网** 的明确来源之一
  - 若用户不需要 P2P 交付优化，这组规则是高性价比收口目标

#### 4.6 自定义应用暴露：`9527`
- `9527` 当前由：
  - `C:\Zero\App\Life\Voicing\voicing.exe`
  监听
- 已确认存在：
  - `voicing`
  - `Profile = Private, Public`
  - `RemoteAddress = Any`
- 另外还发现一组当前未见监听、但规则很宽的应用规则：
  - `voicecoding`
  - `Profile = Private, Public`
  - `RemoteAddress = Any`
- 结论：
  - `9527` 不是系统默认必须开放的端口，而是**本机自定义应用主动对外开口**
  - 如果这类应用不需要被其他设备访问，它们通常是最容易、也最应该优先收掉的一类

#### 4.7 RPC 动态管理面：`49664-49668` / `50412`
- 本机服务映射显示：
  - `49664` -> `lsass` / `KeyIso,SamSs,VaultSvc`
  - `49666` -> `Schedule`
  - `49667` -> `EventLog`
  - `49668` -> `Spooler`
  - `50412` -> `services`
- `netsh advfirewall` 上下文里能看到多条相应远程管理规则，例如：
  - `远程计划任务管理(RPC)`
  - `远程事件监视器(RPC-EPMAP)`
  - `远程事件日志管理(NP-In)`
  - `远程服务管理(RPC)`
  - `Windows Management Instrumentation (WMI-In)`
- 结论：
  - 这是**典型的 Windows 远程管理 / RPC 生态口子**
  - 在 tailnet 里它们当前是可达的
  - 这批规则需要谨慎处理：
    - 如果你从不用远程事件日志、远程计划任务、远程服务管理、远程 WMI，就很值得关闭
    - 但它们涉及系统管理能力，不应在不做分组回归的情况下“一把梭全关”

#### 4.8 Tailscale 自身端口：`2222` / `18789` / `59069`
- 这三项都由：
  - `tailscaled`
  监听
- 结论：
  - 这是 Tailscale 自身的内部监听面
  - 本轮结论是：
    - **先不要把它们列为第一批收口对象**
    - 如要处理，必须单独确认其对 Tailscale 功能的影响

### 5. 风险分级

#### A 级：优先收口
- `445` / SMB / 文件和打印机共享
- `9527` / `voicing.exe`
- `7680` / Delivery Optimization
- `2179` / Hyper-V Remote Desktop
- `5040` / CDPSvc / 连接设备平台

#### B 级：高价值但需谨慎分组收口
- `135`
- `49664-49668`
- `50412`
- 这批与：
  - RPC
  - WMI
  - EventLog
  - Task Scheduler
  - Spooler
  - Service Control Manager
  相关

#### C 级：暂不优先动
- `2222`
- `18789`
- `59069`
- 原因：
  - 属于 `tailscaled` 自身监听
  - 贸然动它们的收益不如先处理 A/B 级明显，且更容易误伤 Tailscale 功能

### 6. 建议的后续实施顺序
1. 先收 **应用级和明显不需要的功能口**：
   - `voicing`
   - `voicecoding`
   - `Delivery Optimization`
   - `Network Discovery / WSD`
   - `Connected Devices Platform`
2. 再收 **Hyper-V 远程管理面**：
   - 前提是用户不需要跨设备远程管理 Hyper-V / VM console
3. 最后再分组收 **RPC / WMI / 远程事件日志 / 远程计划任务 / 远程服务管理**
   - 每关一组就做 Linux / 手机 / 本机功能回归
4. `tailscaled` 自身端口最后评估，不作为第一阶段目标

### 7. 当前最准确的总判断
- 现在的 Windows：
  - **SSH 面已经安全**
  - **公网直连面没有证据被打通**
  - **但 tailnet / 私网下的非 SSH 暴露面仍然偏宽**
- 因此如果要把“也安全了”说完整，应该是：
  - **对 SSH 来说，已经安全**
  - **对整台 Windows 的私网暴露面来说，还需要第二阶段全面收口**

---

## BE. 主 Gateway “又不回消息”复核：不是服务挂掉，而是 Telegram 出站短时抖动（2026-03-14 下午）

### 现象
- 用户反馈主 Gateway 再次出现“看起来不回消息”。
- 需要区分：
  - `openclaw-gateway` 进程是否挂掉
  - Telegram webhook 是否失效
  - 模型推理是否异常
  - Telegram 出站是否又短时抖动

### 实时检查结果（2026-03-14 14:56-14:58 CST）
- `openclaw-gateway.service`：
  - `active (running)`
  - 本轮查看时已连续运行自 `2026-03-14 10:40:00 CST`
- 本地监听仍正常：
  - `127.0.0.1:18790`（Gateway）
  - `127.0.0.1:8787`（Telegram webhook listener）
  - `127.0.0.1:7897`（mihomo HTTP proxy）
- `mihomo-standalone.service`：
  - `active (running)`
  - 未见重启循环
- `openclaw gateway health --json`：
  - `ok: true`
  - Telegram probe 成功
  - bot=`@OpenClaw_kevinlasnh_no1_bot`
  - webhook URL 仍为 `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- Telegram `getWebhookInfo`（经 `127.0.0.1:7897` 代理）：
  - `pending_update_count = 0`
  - webhook URL 正确
  - 说明 Telegram 侧当前没有堆积未投递更新
- 本地 agent 自检：
  - `openclaw agent --agent main --message 'Reply with exactly: MAIN_DIAG_OK' --json`
  - 返回 `MAIN_DIAG_OK`
  - provider=`minimax`
  - model=`MiniMax-M2.5`
  - `durationMs = 6931`
- 直接 Bot API 出站测试：
  - `sendMessage` 经代理成功
  - 时间：`2026-03-14 14:57-14:58 CST`
  - `message_id = 10890`

### 日志证据
- 本轮未见 service crash、未见 webhook 解绑。
- 近 90 分钟日志的关键异常都集中在 Telegram 出站：
  - `2026-03-14 13:51:54 CST`：`sendMessage failed`
  - `2026-03-14 13:52:04 CST`：`sendChatAction failed`
  - `2026-03-14 13:56:19 CST`：`sendChatAction failed`
  - `2026-03-14 14:05:48` 到 `14:07:05 CST`：连续 `sendChatAction failed` / `sendMessage failed`
- 这些失败后，日志又恢复连续 `sendMessage ok`，例如：
  - `2026-03-14 14:07:06 CST`
  - `2026-03-14 14:35:03 CST`
  - `2026-03-14 14:54:51` 到 `14:55:05 CST`

### 结论
- **这次不是主 Gateway 挂了。**
- **也不是 webhook 失效。**
- **也不是主模型 Minimax 当前不可用。**
- 更准确地说：
  - 主 Gateway、webhook、本地模型链路都正常
  - 证据指向 **Telegram 出站链路的短时抖动**
  - 与 `2026-03-12` 那次“主机本身不能直连 Telegram，必须依赖代理；代理链路短时抖动会导致看起来不回消息”的模式一致

### 更具体的根因（2026-03-14 进一步对齐 mihomo 日志）
- Telegram 规则当前走的是 `悠兔` 代理组：
  - `DOMAIN-SUFFIX,telegram.org,悠兔`
- `悠兔` 不是固定节点，而是手动 `select` 到：
  - `自动选择`
  - 或 `故障转移`
- 其中：
  - `自动选择` = `url-test`
  - `故障转移` = `fallback`
  - 两者都是 `interval: 30` + `lazy: false`
  - 健康检查地址都是 `http://www.gstatic.com/generate_204`
- `mihomo` 日志表明 Telegram 出口节点在失败前后持续切换，例如：
  - `13:45`：香港6
  - `13:46`：香港5
  - `13:47-13:48`：香港1
  - `13:49`：香港2
  - `13:50`：香港6
  - `13:51`：香港4
  - `14:05`：香港4
  - `14:06`：香港2
  - `14:07`：香港3
  - `14:07:59`：香港6
- 这说明：
  - **Telegram 流量并不是稳定钉在一个已验证节点上**
  - 而是在 30 秒探测机制下频繁漂移到不同香港节点

### 为什么会导致 `sendMessage failed`
- 这台主机对 Telegram **不能直连**，只能经 `127.0.0.1:7897 -> mihomo -> 代理节点 -> api.telegram.org` 走代理。
- 因此 Telegram 出站链路比国内直连链路多出几层不稳定点：
  1. 本机到 mihomo
  2. mihomo 到当前被选中的代理节点
  3. 代理节点到 `api.telegram.org`
  4. 节点切换窗口本身
- `url-test/fallback` 只是在测：
  - 哪个节点对 `gstatic generate_204` 响应更快/没超时
- 但这**不等于**：
  - 该节点对 Telegram API 的 TLS 建连、短连接稳定性、丢包率也最好
- `mihomo` 还明确给出过提示：
  - `It is recommended to use HTTPS for provider.health-check.url and group.url ... using HTTP may result in failed tests.`
- 结合本轮现象，最合理的推断是：
  - `generate_204` 探测结果存在噪声
  - 30 秒频繁切节点带来路由抖动
  - 某些被选中的节点对 Telegram 短时不稳
  - 于是 OpenClaw 在发送 `sendChatAction` 或 `sendMessage` 时偶发超时/网络失败

### 为什么 `sendChatAction failed` 比 `sendMessage failed` 更常见
- `sendChatAction` 是“正在输入”状态，请求更频繁。
- 只要出站链路短时有抖动，它通常会先失败，所以日志里经常先看到：
  - `sendChatAction failed`
- 但只要 bad window 很短，最终正文 `sendMessage` 仍可能在几秒后成功。
- 真正让用户体感成“完全不回”的，是 bad window 恰好覆盖了最终正文发送，此时会看到：
  - `final reply failed`
  - 或 `message processing failed`

### 当前最准确的解释
- **根因不是 OpenClaw 自己崩了。**
- **根因也不是 Telegram webhook 丢了。**
- 更准确地说，是：
  - 主机必须依赖代理访问 Telegram
  - 代理组又在 30 秒健康检查下频繁切节点
  - 健康检查目标和 Telegram 实际业务质量不完全同构
  - 导致 Telegram 出站请求偶发落在不稳定节点或切换窗口上，于是报 `Network request failed`

---

## BF. 当前 mihomo 自动切换逻辑复核 + “只在不稳定时切换”可行性调研（2026-03-14）

### 用户问题
- 用户质疑当前代理像是在“30 秒自动切换”。
- 希望确认：
  - 现在实际逻辑是不是在持续追最低延迟
  - 能不能改成“当前节点稳定就不动，只在不稳定时才切换”

### 当前真实运行逻辑

#### 1. Telegram 不是直接走固定节点
- 规则里 Telegram 走：
  - `DOMAIN-SUFFIX,telegram.org,悠兔`
- `悠兔` 不是自动测试组本身，而是一个 `Selector`
- 运行时 API 显示：
  - `悠兔.type = Selector`
  - `悠兔.now = 自动选择`

#### 2. 当前真正生效的是 `自动选择`
- 运行时 API 显示：
  - `自动选择.type = URLTest`
  - `自动选择.now = 专线2.5x-香港5`（这是检查时刻，不是固定值）
- 配置文件显示：
  - `interval: 30`
  - `lazy: false`
  - `url: http://www.gstatic.com/generate_204`
  - **没有**配置 `tolerance`
- 这意味着：
  - 当前逻辑确实是在**每 30 秒持续测一轮**
  - 并且会按测试结果倾向选择**当前延迟最低**的节点
  - 因为没有 `tolerance`，即使只是小幅领先，也更容易切换

#### 3. 当前也存在一个“只在坏时切换”的组，但没有在用
- 运行时 API 显示：
  - `故障转移.type = Fallback`
  - `故障转移.now = 官网youtunice.com`
- 官方文档对 `Fallback` 的定义是：
  - “If the current node times out, the first available node will be selected in the order of proxies”
- 也就是说：
  - `fallback` 的语义本来就更接近“**当前节点坏了才切**”
  - 但现在 Telegram 并没有走这个组，而是走 `url-test`

### 运行时证据
- 最近 2 小时 `mihomo` 日志里，Telegram 出口节点持续变化：
  - `14:47`：香港5
  - `14:48`：香港3
  - `14:49-14:50`：香港6
  - `14:51`：香港3
  - `14:52`：香港7
  - `14:53`：香港3
  - `14:54`：香港7
  - `14:54:54`：香港6
  - `14:55-14:56`：香港4
  - `14:57`：香港3
  - `14:58`：香港5
  - `14:59`：香港6
  - `15:00`：香港7
  - `15:01`：香港5
  - `15:02-15:04`：香港6
- 这已经不是“偶尔切一次”，而是**持续跟着 URLTest 结果漂移**。

### 官方文档结论（2026-03-14 联网核查）
- `proxy-groups` 通用字段：
  - `interval`：周期性健康检查间隔
  - `lazy`：默认 `true`；如果当前组未被选中，就不测试
  - `max-failed-times`：失败次数超过阈值会强制健康检查
  - `expected-status`：可要求健康检查必须返回指定状态码
- `url-test`：
  - 语义是自动选延迟更优节点
  - 支持 `tolerance`
  - 官方说明 `tolerance` 是“proxies switch tolerance”，单位毫秒
- `fallback`：
  - 语义是“当前节点超时后，按代理顺序选第一个可用节点”

### 回答用户的核心问题
- **是的，你理解得基本对。**
- 当前生效逻辑不是“稳定就不动”，而是：
  - Telegram 走 `悠兔`
  - `悠兔` 当前选中的是 `自动选择`
  - `自动选择` 是 `url-test`
  - `url-test` 每 30 秒基于 `gstatic` 健康检查追一次更低延迟
- 所以它的默认行为更接近：
  - **节点池内动态择优**
  - 而不是
  - **固定当前节点，除非坏掉**

### 能不能改成“坏了才切”
- **能。**
- 至少有 3 条路线：

#### 方案 A：直接把 Telegram 所在上层组切到 `故障转移`
- 做法：
  - 把 `悠兔` 从当前的 `自动选择` 切到 `故障转移`
- 优点：
  - 不需要重写大量配置
  - 语义最接近“当前节点不坏就不动”
- 缺点：
  - `故障转移` 当前列表顺序以 `官网youtunice.com`、`永久官网666.youtu0.com` 开头
  - 不一定是最适合 Telegram 的稳定节点
  - 仍然共享一个很大的节点池，策略不够精细

#### 方案 B：继续用 `url-test`，但把它改成“不轻易切”
- 做法：
  - 增加 `tolerance`
  - 拉长 `interval`
  - 恢复/改成 `lazy: true`
  - 健康检查改用 HTTPS，并加 `expected-status: 204`
- 优点：
  - 保留一定自动优化能力
  - 能显著减少“轻微延迟波动就切换”的抖动
- 缺点：
  - 本质仍然是“追更优延迟”，不是纯粹“坏了才切”

#### 方案 C：给 Telegram 单独建一组“稳定优先”的专用代理组（推荐）
- 做法：
  - 新建如 `telegram-stable`
  - 只放 3-5 个近期香港/新加坡节点
  - 类型用 `fallback`
  - 把 Telegram 规则从 `悠兔` 改指向这个专用组
- 优点：
  - 语义最清晰
  - 不影响浏览器、Brave、其它业务的全局自动选择
  - 可以把 Telegram 和“全局最低延迟竞争”解耦
- 缺点：
  - 需要一次明确配置改造和回归测试

### 哪些字段值得特别说明
- `lazy`
  - **不是**“稳定就不切换”的开关
  - 它的含义是“如果这个组没被选中，就不去测试”
  - 由于 Telegram 当前持续在用它，所以即使改成 `lazy: true`，在使用期间仍会继续测
- `tolerance`
  - 这是减少抖动的关键字段
  - 它不是“坏了才切”，但能避免因为 5ms、10ms 这种小差异频繁切换
- `expected-status: 204`
  - 适合配合 `generate_204` 使用
  - 可降低“被异常响应也判成健康”的噪声

### 当前推荐顺序
1. 不直接全局改 `悠兔` 的大池逻辑。
2. 先为 Telegram 单独做一组专用代理策略。
3. 若用户要“尽量只在坏时切”，优先用：
  - `fallback`
  - 小节点池
  - 近地区节点
4. 若用户仍想保留自动优选，再考虑：
  - `url-test + tolerance + 更长 interval + HTTPS health-check`

### 本轮结论
- 当前系统**确实在 30 秒周期下自动追最低延迟**，不是“坏了才切”。
- 你想要的“只在不稳定时切换”在 mihomo 里是**可以实现**的。
- 最合理的落地方式，不是继续让 Telegram 走大而杂的 `悠兔 -> 自动选择`，而是：
  - **给 Telegram 单独做一个稳定优先的专用代理组。**

### 对“每 10 秒只检查当前节点，坏了后切到下一个实时最低延迟节点”的边界判断
- 这个需求要拆成两半看：

#### 半边 1：当前节点稳定就不切
- **可行。**
- `fallback` 本身就符合这个方向：
  - 当前节点没超时，就继续用当前节点
  - 只有当前节点超时，才切换

#### 半边 2：坏了以后自动切到“下一个实时最低延迟节点”
- **Mihomo 原生 YAML 里不精确支持这个语义。**
- 原因：
  - 官方对 `fallback` 的定义是：
    - 当前节点超时时，按 `proxies` 列表顺序选择第一个可用节点
  - 它选的是：
    - **按顺序的第一个可用**
  - 不是：
    - **故障当下实时延迟最低的那个**

#### 进一步边界：是否能做到“只检查当前节点”
- 也**不是严格原生支持**。
- Mihomo 的 proxy-group 健康检查语义是：
  - 对组内 `proxies` 字段做健康检查
  - 不是只探测当前 `now` 节点
- 所以即便改成 `fallback + interval: 10`：
  - 功能效果上可以接近“当前稳定就不切”
  - 但底层不是“只检查当前节点”这一种实现

### 最终可行性结论
- **完全按你描述的原文逻辑**：
  - “每 10 秒只检查当前节点”
  - “若断开就自动切到故障当下实时延迟最低节点”
  - 这套逻辑 **不是 Mihomo 纯配置原生可部署的**
- **高相似度近似方案**：
  - 可以部署
  - 方案是：
    - Telegram 单独建 `fallback` 组
    - 只放台湾 + 日本节点
    - `interval: 10`
    - `timeout` 合理收紧
    - `max-failed-times: 1`
    - 节点按预先测得的延迟/稳定性排序
  - 这样实现的是：
    - 当前节点不坏就不动
    - 坏了以后切到“预先排好顺序的下一个最优节点”
  - 但不是：
    - 每次故障时再临时重新计算“实时最低延迟”

### 如果一定要做成“故障时切到当下最低延迟”
- 需要**额外自动化层**，不只是改 Mihomo YAML：
  - 例如一个外部脚本 / 守护进程
  - 周期采集台湾/日本节点延迟
  - 在故障时动态改组顺序或改当前选中节点
- 这种方案理论上可做，但复杂度、维护成本、误切风险都明显高于纯 `fallback` 配置。

---

## BG. Telegram 日本/台湾专用 `fallback` 组已部署到持久化 YAML（待用户重启生效，2026-03-14）

### 用户最终要求
- Telegram 单独建一个专用代理组
- 组内只允许：
  - 台湾节点
  - 日本节点
- 当前节点稳定时**不主动切换**
- 更快检查故障，最终决定用：
  - `interval: 5`
- 电脑重启后仍要自动恢复到新组，不能回到 `悠兔`

### 已确认的当前台湾/日本节点全集
当前这台机器不是 `proxy-providers` 动态模式，实际可用集合就是本机 `clash-verge.yaml` 里落盘的 12 个节点：

1. `专线2.5x-台湾1-GPT`
2. `专线2.5x-台湾2-GPT`
3. `高速隧道1x-台湾1-GPT`
4. `高速隧道1x-台湾2-GPT`
5. `专线2.5x-日本1-GPT`
6. `专线2.5x-日本2-GPT`
7. `专线2.5x-日本3-GPT`
8. `专线2.5x-日本4-GPT`
9. `高速隧道1x-日本1-GPT`
10. `高速隧道1x-日本2-GPT`
11. `高速隧道1x-日本3-GPT`
12. `高速隧道1x-日本4-GPT`

运行时 API 复核时，这 12 个节点均为 `alive=true`。

### 已落地配置
修改文件：
- `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml`

新增代理组：
```yaml
- expected-status: 204
  interval: 5
  lazy: true
  max-failed-times: 1
  name: telegram-jp-tw-stable
  proxies:
  - 专线2.5x-台湾1-GPT
  - 专线2.5x-日本3-GPT
  - 专线2.5x-日本2-GPT
  - 高速隧道1x-台湾1-GPT
  - 高速隧道1x-台湾2-GPT
  - 专线2.5x-台湾2-GPT
  - 专线2.5x-日本4-GPT
  - 专线2.5x-日本1-GPT
  - 高速隧道1x-日本1-GPT
  - 高速隧道1x-日本2-GPT
  - 高速隧道1x-日本4-GPT
  - 高速隧道1x-日本3-GPT
  timeout: 3000
  type: fallback
  url: https://www.gstatic.com/generate_204
```

### Telegram 规则已改向
以下规则已从 `悠兔` 改为 `telegram-jp-tw-stable`：
- `DOMAIN-SUFFIX,telegra.ph,...`
- `DOMAIN-SUFFIX,telegram.org,...`
- Telegram 全部 `IP-CIDR`
- Telegram 全部 `IP-CIDR6`

### 为什么重启后不会回到 `悠兔`
- 这次**不是运行时临时切组**。
- 这次是把 Telegram 规则目标**直接写进持久化 YAML**：
  - `telegram.org -> telegram-jp-tw-stable`
- `mihomo-standalone` 启动时读取的就是这份 YAML，因此：
  - 重启服务后会继续命中新组
  - 整机重启后也会继续命中新组
  - **不会自动回到 `悠兔`**

### 已完成的部署动作
- 远端配置备份：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml.pre-telegram-jp-tw-20260314-154612`
- 本地副本修改后，已上传到远端临时文件做校验：
  - `/home/kevinlasnh/clash-verge.telegram-jp-tw-test.yaml`
- 使用以下命令做语法校验：
  - `/usr/bin/verge-mihomo -t -f /home/kevinlasnh/clash-verge.telegram-jp-tw-test.yaml`
- 校验结果：
  - `test is successful`
- 校验通过后，已正式覆盖持久化路径：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml`

### 当前状态
- **部署已完成，但尚未重启 `mihomo-standalone`，所以运行时仍是旧配置。**
- 用户下一步将手动重启机器。
- 重启后需要复核：
  1. `telegram-jp-tw-stable` 是否出现在运行时 `/proxies`
  2. Telegram 出口是否不再走 `悠兔`
  3. 主 Gateway 出站消息是否恢复到新组链路

### 重启后复核结果（2026-03-14 15:49-15:51 CST）
- 用户要求由本轮直接执行重启。
- 实际重启观察：
  - `HOST_DOWN`: `2026-03-14 15:49:33`
  - `HOST_UP`: `2026-03-14 15:49:59`
- 两个关键服务均已自恢复：
  - `mihomo-standalone.service = active`
  - `openclaw-gateway.service = active`
- 运行时 `/proxies` 复核：
  - `telegram-jp-tw-stable.type = Fallback`
  - `telegram-jp-tw-stable.now = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable.alive = true`
- 这证明：
  - 新组已经随重启进入运行态
  - **没有回到 `悠兔`**

### Telegram 实际出站路由验证
- 直接发送 Telegram 诊断消息成功：
  - `message_id = 10892`
- `mihomo` 日志在重启后连续显示：
  - `match DomainSuffix(telegram.org) using telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`
- 这说明：
  - Telegram 出站已经不再走 `悠兔`
  - 而是**确实走了新的日本/台湾 fallback 组**

### 最终状态
- 这次部署已经完成闭环：
  - 持久化 YAML 已改
  - 整机重启已做
  - 新组已自动恢复
  - Telegram 实际出站已验证命中新组

### 追加复核（2026-03-14 15:57 CST）
- 连续 4 次、每次间隔约 6 秒读取运行时 `/proxies`：
  - `telegram-jp-tw-stable.type = Fallback`
  - `telegram-jp-tw-stable.now = 专线2.5x-台湾1-GPT`
  - `alive = true`
  - 4 次都未发生切换
- 这说明当前运行逻辑符合本次部署目标：
  - **节点稳定时保持当前节点不变**
  - 不是 `url-test` 那种持续追最低延迟主动切换
- 但边界仍然不变：
  - 若当前节点故障，`fallback` 会按预先排序切到下一个可用节点
  - 不是在故障当下重新计算“实时最低延迟节点”

### 四个 Gateway 当前状态（2026-03-14 15:57 CST）
- `openclaw-gateway.service`：`active`
- `openclaw-gateway-dayong.service`：`active`
- `openclaw-gateway-chunyan.service`：`active`
- `openclaw-gateway-zenglan.service`：`active`

### 两个 Telegram Webhook 当前状态（2026-03-14 15:57 CST）
- main bot：
  - webhook URL = `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
  - `pending_update_count = 0`
- dayong bot：
  - webhook URL = `https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
  - `pending_update_count = 0`
- 结论：
  - **两个 Telegram webhook 都已接上**

### 处理建议
- 当前不需要因为这次现象就重启主 Gateway。
- 若再次复发，优先检查顺序：
  1. `journalctl --user -u openclaw-gateway --since '15 minutes ago'`
  2. 看是否出现 `sendMessage failed` / `sendChatAction failed`
  3. 再看 `mihomo-standalone` 日志和当前 Telegram 出口节点
  4. 若持续 1-2 分钟仍不恢复，先重启 `mihomo-standalone`
  5. 只有在代理恢复后仍异常时，再重启 `openclaw-gateway`

### 额外记录
- `openclaw message send` 本轮第一次误用了参数形式，CLI 报：
  - `required option '-t, --target <dest>' not specified`
- 为避免继续浪费时间，本轮改用 Telegram Bot API 直连 `sendMessage` 做出站验证。

---

## BH. 主 `悠兔` / `故障转移` 全局稳定优先改造调研（2026-03-14）

### 运行时现状
- 当前主代理策略并不是“稳定时不切”：
  - `悠兔.type = Selector`
  - 运行时 `悠兔.now = 自动选择`
  - `自动选择.type = URLTest`
  - 运行时 `自动选择.now = 专线2.5x-香港6`
  - `故障转移.type = Fallback`
  - 运行时 `故障转移.now = 官网youtunice.com`
- 所以主流量现在实际仍在：
  - `悠兔 -> 自动选择(url-test)`
- `故障转移` 当前虽然是 `fallback`，但顺序仍是旧顺序：
  - `官网youtunice.com`
  - `永久官网666.youtu0.com`
  - 然后才是香港 / 新加坡 / 台湾 / 日本 / 美国 / 英国 / 澳洲 / 马来西亚 / 土耳其 / 阿根廷
- 这个旧顺序不适合直接拿来做“稳定优先”的主池。

### 影响范围
- 这次若改主 `悠兔`，不是 Telegram 那种局部路由优化。
- 已确认：
  - `悠兔` 下挂总条目 `56`
  - 其中辅助组 `2` 个：
    - `自动选择`
    - `故障转移`
  - 具体节点 `54` 个
- 规则命中面很大：
  - 明确指向 `悠兔` 的规则共 `310` 条
  - 且最后还有：
    - `MATCH,悠兔`
- 结论：
  - 这次改的是整台机器的主代理策略，影响所有默认走代理的流量。

### Mihomo 控制面补充
- 当前这台机器上的 Mihomo 运行态不能只依赖旧的 `127.0.0.1:9097` 习惯口判断。
- systemd 当前实际启动参数里带有：
  - `-ext-ctl-unix /tmp/verge/verge-mihomo.sock`
- 通过 Unix socket 读取运行态是可靠的：
  - `/tmp/verge/verge-mihomo.sock`

### `store-selected` 的边界
- `clash-verge.yaml` 里仍有：
  - `profile.store-selected: true`
- 但本轮发现一个关键不一致：
  - `profiles.yaml` 记录的是：
    - `悠兔 -> 故障转移`
    - `自动选择 -> 官网youtunice.com`
  - 运行时实际却是：
    - `悠兔 -> 自动选择`
    - `自动选择 -> 专线2.5x-香港6`
- 结论：
  - 后续若改主 `悠兔`，**不能只依赖 `store-selected` 缓存文本判断是否生效**
  - 必须以运行态 `/proxies` 复核为准
  - 也必须在改完后做一次重启或服务重启回归，确认不会漂回 `自动选择`

### 当前 54 节点的运行态健康样本
- 本轮直接读取运行态 `/proxies` 中各 concrete proxy 的 `history`，每个节点都有约 `10` 条延迟样本。
- 区域平均表现大致为：
  - `HK`：`avg_of_avg = 94.0`
  - `SG`：`100.9`
  - `TW`：`132.7`
  - `JP`：`221.1`
  - `US`：`256.1`
  - `UK`：`329.4`
  - `AU`：`234.7`
  - `MY`：`117.7`
  - `TR`：`308.9`
  - `AR`：`265.2`
  - `OTHER(官网节点)`：`89.0`

### 排序原则
- 若把 `故障转移` 改造成用户要的“`interval: 5`，稳定优先，坏了才切”的主池，顺序本身就是策略。
- 本轮建议的排序原则不是“谁偶尔最低就放前面”，而是：
  1. 近区低延迟且波动小的专线节点放前排
  2. 近区但波动偏大的节点放后排
  3. 非地理官网节点不放最前面，只做中后排兜底
  4. 长距离但稳定的线路，优先于近区但极不稳定的线路
  5. 出现 `0ms`、超大 spike、极高波动的节点压到尾部

### 当前建议顺序（按 tier 分组）
- Tier 1：主力低延迟稳定专线
  - `专线2.5x-香港6`
  - `专线2.5x-香港2`
  - `专线2.5x-香港1`
  - `专线2.5x-香港4`
  - `专线2.5x-香港5`
  - `专线2.5x-新加坡3`
  - `专线2.5x-新加坡4`
  - `专线2.5x-新加坡1`
  - `专线2.5x-台湾1-GPT`
  - `专线2.5x-日本3-GPT`
  - `专线2.5x-日本2-GPT`
  - `专线2.5x-马来西亚`
  - `专线2.5x-新加坡2`
  - `专线2.5x-台湾2-GPT`
- Tier 2：非地理官网节点 + 近区次级兜底
  - `官网youtunice.com`
  - `永久官网666.youtu0.com`
  - `高速隧道1x-香港5`
  - `高速隧道1x-香港6`
  - `高速隧道1x-香港4`
  - `高速隧道1x-香港7`
  - `高速隧道1x-香港3`
  - `高速隧道1x-香港1`
  - `高速隧道1x-新加坡4`
  - `高速隧道1x-新加坡3`
- Tier 3：中远距离但相对更稳的专线 / 日本次级
  - `专线3x-澳洲`
  - `专线2.5x-美国3`
  - `专线2.5x-美国4`
  - `专线2.5x-美国1`
  - `专线5x-阿根廷`
  - `专线2.5x-日本4-GPT`
  - `专线2.5x-日本1-GPT`
  - `高速隧道1x-日本1-GPT`
  - `高速隧道1x-日本2-GPT`
- Tier 4：仍可用，但波动更大或优先级更低
  - `高速隧道1x-新加坡2`
  - `高速隧道2.5x-马来西亚`
  - `高速隧道1x-新加坡1`
  - `高速隧道1x-台湾1-GPT`
  - `高速隧道1x-台湾2-GPT`
  - `专线2.5x-美国2`
  - `专线5x-土耳其`
  - `高速隧道3x-英国`
  - `专线2.5x-香港3`
  - `专线2.5x-香港7`
- Tier 5：尾部灾备
  - `高速隧道1x-香港2`
  - `高速隧道1x-美国4`
  - `高速隧道1x-美国3`
  - `高速隧道1x-美国1`
  - `高速隧道1x-美国2`
  - `高速隧道1x-日本3-GPT`
  - `高速隧道1x-日本4-GPT`
  - `高速隧道5x-土耳其`
  - `专线3x-英国`
  - `高速隧道5x-阿根廷`
  - `高速隧道3x-澳洲`

### 排序背后的具体证据
- 当前前排最干净的是香港专线：
  - `专线2.5x-香港6`：`avg=20.7`，`stdev=2.8`
  - `专线2.5x-香港2`：`avg=20.8`，`stdev=2.7`
  - `专线2.5x-香港1`：`avg=22.2`，`stdev=4.6`
  - `专线2.5x-香港4`：`avg=22.3`，`stdev=4.0`
- 新加坡专线也比较干净：
  - `专线2.5x-新加坡3`：`avg=51.0`，`stdev=2.4`
  - `专线2.5x-新加坡4`：`avg=51.9`，`stdev=2.3`
  - `专线2.5x-新加坡1`：`avg=52.4`，`stdev=2.8`
- 台湾 / 日本前排节点仍值得保留，但不是所有都适合放很前：
  - `专线2.5x-台湾1-GPT`：`avg=71.8`，但 `stdev=13.0`
  - `专线2.5x-台湾2-GPT`：`avg=85.1`，但 `stdev=28.2`
  - `专线2.5x-日本3-GPT`：`avg=76.0`，`stdev=4.7`
  - `专线2.5x-日本2-GPT`：`avg=78.1`，`stdev=10.7`
- 以下节点虽然偶尔看起来快，但波动明显，不适合放很前：
  - `专线2.5x-香港3`：`avg=101.5`，`max=226`，`stdev=99.0`
  - `专线2.5x-香港7`：`avg=143.6`，`max=232`，`stdev=100.3`
  - `高速隧道1x-台湾1-GPT`：`avg=187.0`，`max=386`
  - `高速隧道1x-台湾2-GPT`：`avg=186.7`，`max=518`
  - `高速隧道1x-日本3-GPT`：`avg=346.3`，存在 `0ms` 异常样本
  - `高速隧道3x-澳洲`：`avg=307.9`，存在 `0ms` 与 `563ms` 大波动

### 当前最合理的部署思路
- 若采用用户偏好的“先改 `故障转移`”路线，至少要同时做两件事：
  1. 把 `故障转移` 改造成：
     - `interval: 5`
     - `lazy: true`
     - `timeout: 3000`
     - `max-failed-times: 1`
     - `expected-status: 204`
     - `url: https://www.gstatic.com/generate_204`
     - `proxies:` 使用上面的新顺序
  2. 让主 `悠兔` 真正选到 `故障转移`
- 如果只改第 1 步、不改第 2 步，流量仍会继续走：
  - `悠兔 -> 自动选择`
- 因此上线时必须把“改 `故障转移`”和“切 `悠兔` 到 `故障转移`”作为一个动作包处理。

### 正式部署结果（2026-03-14 16:50-16:54 CST）
- 已正式把持久化配置落地到：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml`
- 这次对主 `故障转移` 的实际改动为：
  - `interval: 5`
  - `lazy: true`
  - `timeout: 3000`
  - `max-failed-times: 1`
  - `expected-status: 204`
  - `url: https://www.gstatic.com/generate_204`
  - `proxies:` 使用本节上面的新顺序
- 同时对 `悠兔` 做了两层处理：
  - `悠兔.proxies` helper 顺序改成 `故障转移` 在前、`自动选择` 在后
  - 运行时通过 Mihomo controller 明确切到：
    - `悠兔 -> 故障转移`

### 备份与校验
- 新备份文件：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml.pre-youtu-fallback-20260314-165047`
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/profiles.yaml.pre-youtu-fallback-20260314-165047`
- 临时测试文件：
  - `/home/kevinlasnh/clash-verge.youtu-fallback-test.yaml`
- 语法校验命令：
  - `/usr/bin/verge-mihomo -d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev -t -f /home/kevinlasnh/clash-verge.youtu-fallback-test.yaml`
- 校验结果：
  - `test is successful`
- 注意：
  - 不带 `-d` 的测试曾因 geodata 下载超时误报失败
  - 不是配置语法错误
- 验收完成后，临时测试文件已删除。

### 持久化验证
- 先做了 `mihomo-standalone` 服务级重启：
  - 重启后仍保持：
    - `悠兔.now = 故障转移`
- 随后做了整机重启验证：
  - `HOST_DOWN = 2026-03-14 16:53:16 CST`
  - `HOST_UP = 2026-03-14 16:53:34 CST`
- 重启后所有关键服务均恢复：
  - `tailscaled = active`
  - `mihomo-standalone = active`
  - `openclaw-gateway = active`
  - `openclaw-gateway-dayong = active`
  - `openclaw-gateway-chunyan = active`
  - `openclaw-gateway-zenglan = active`

### 重启后的最终稳定态
- 当前稳定运行态为：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-香港6`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- 连续 3 次、每次间隔约 6 秒抽样，结果都保持：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-香港6`
- 这说明：
  - 主 `悠兔` 已经不再回到 `自动选择`
  - 当前节点稳定时不会因为 `5` 秒检查而主动乱切

### 实际流量验证
- 通过本机代理访问：
  - `https://www.google.com/generate_204`
- 返回：
  - `HTTP 204`
- Mihomo 日志明确显示：
  - `www.google.com:443 ... match DomainKeyword(google) using 悠兔[专线2.5x-香港6]`
- 同时 Telegram 专用组不受影响：
  - 日志仍持续命中：
    - `telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`

### 当前结论
- 主 `悠兔` 的稳定优先改造已经部署完成。
- 服务重启后保持成功。
- 整机重启后保持成功。
- Telegram 日本/台湾专用组仍然正常，没有被这次主池改造破坏。

### 追加复核（2026-03-14 16:58-17:05 CST）
- 对 `telegram-jp-tw-stable` 做了专项复核，当前结论是：
  - 配置层正确
  - 运行态正确
  - 实际命中正确
- 持久化配置仍为：
  - `type = fallback`
  - `interval = 5`
  - `lazy = true`
  - `timeout = 3000`
  - `max-failed-times = 1`
  - `expected-status = 204`
  - `url = https://www.gstatic.com/generate_204`
- 节点范围仍严格限制在：
  - 台湾 + 日本
  - 共 `12` 个节点
- 运行态当前为：
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
  - `alive = true`
- 连续 `4` 次、每次间隔约 `6` 秒抽样，结果都保持：
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- 这说明：
  - Telegram 专用组当前稳定时**不会因为 5 秒检查而主动乱切**

### Telegram 实际命中复核
- `mihomo-standalone` 日志在 `17:02-17:04 CST` 连续显示：
  - `api.telegram.org:443 ... using telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`
- 说明 Telegram 当前实际仍走日本/台湾专用 fallback 组，不是误命中主 `悠兔`。

### 全局状态总验（同一时间窗）
- 当前服务状态：
  - `tailscaled = active`
  - `mihomo-standalone = active`
  - `openclaw-gateway = active`
  - `openclaw-gateway-dayong = active`
  - `openclaw-gateway-chunyan = active`
  - `openclaw-gateway-zenglan = active`
- 当前监听状态：
  - `127.0.0.1:7897` = Mihomo mixed proxy
  - `127.0.0.1:18790` = main Gateway
  - `127.0.0.1:19021` = dayong Gateway
  - `127.0.0.1:19001` = chunyan Gateway
  - `127.0.0.1:19041` = zenglan Gateway
  - `127.0.0.1:8787` = main Telegram webhook listener
  - `127.0.0.1:8788` = dayong Telegram webhook listener
- 主代理当前仍为：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-香港6`
- 实际 Google 流量验证：
  - `https://www.google.com/generate_204` 返回 `204`
  - 日志显示：
    - `www.google.com ... using 悠兔[专线2.5x-香港6]`

### Funnel / Webhook 复核
- `tailscale funnel status` 当前显示：
  - `https://openclaw-24x7.tailda6e28.ts.net -> 127.0.0.1:8787`
  - `https://openclaw-24x7.tailda6e28.ts.net:8443 -> 127.0.0.1:8788`
- Telegram `getWebhookInfo` 复核结果：
  - main：
    - `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
    - `pending_update_count = 0`
  - dayong：
    - `url = https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
    - `pending_update_count = 0`

### 本轮最终判断
- 当前整套状态是正常的：
  - 主 `悠兔` 稳定优先组正常
  - Telegram 日本/台湾专用组正常
  - 四个 Gateway 正常
  - Tailscale / Funnel 正常
  - 两个 Telegram webhook 当前都已接上且无堆积

### 追加变更：主 `故障转移` 节点池收缩为与 Telegram 相同的日本/台湾 12 节点（2026-03-14 17:36-17:37 CST）
- 用户新要求：
  - 主 `故障转移` 不再使用原来的 54 节点大池
  - 改为只使用与 `telegram-jp-tw-stable` 完全相同的日本/台湾 `12` 节点
  - 顺序完全一致
  - `5` 秒检测的稳定优先逻辑保持不变
- 这次实现方式很直接：
  - 保留 `悠兔 = 故障转移`
  - 只把 `故障转移.proxies` 改成与 `telegram-jp-tw-stable.proxies` 相同
  - 不改 Telegram 组本身
  - 不改 `悠兔` selector 的总体结构

### 部署与校验
- 临时测试文件：
  - `/home/kevinlasnh/clash-verge.jp-tw-main-test.yaml`
- 语法校验：
  - `/usr/bin/verge-mihomo -d ~/.local/share/io.github.clash-verge-rev.clash-verge-rev -t -f /home/kevinlasnh/clash-verge.jp-tw-main-test.yaml`
  - 返回 `test is successful`
- 正式备份：
  - `~/.local/share/io.github.clash-verge-rev.clash-verge-rev/clash-verge.yaml.pre-main-jp-tw-20260314-173636`
- 应用方式：
  - 覆盖持久化 `clash-verge.yaml`
  - `systemctl --user restart mihomo-standalone`
- 验收完成后，临时测试文件已删除。

### 变更后的当前状态
- 主 `故障转移` 当前变为：
  - `all_count = 12`
  - 节点列表与 `telegram-jp-tw-stable` 完全一致
- 运行态当前为：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- 连续 `3` 次抽样，结果都保持：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`

### 实际流量验证
- 通过代理访问：
  - `https://www.google.com/generate_204`
- 返回：
  - `HTTP 204`
- Mihomo 日志明确显示：
  - `www.google.com ... using 悠兔[专线2.5x-台湾1-GPT]`
- 这说明主代理当前已经不再落到香港/新加坡/美国等原大池节点，而是已经切到新的日本/台湾 12 节点池。

### 当前结论补充
- 现在主 `故障转移` 和 Telegram 专用组的节点池已经统一：
  - 都只使用相同的日本/台湾 `12` 节点
  - 顺序相同
  - 都保留 `5` 秒稳定优先逻辑

### 整机重启回归（2026-03-14 17:40-17:41 CST）
- 用户要求对“主 `故障转移` 已收缩为日本/台湾 `12` 节点池”的新状态再做一次整机重启验证。
- 实际观察：
  - `HOST_DOWN = 2026-03-14 17:40:23 CST`
  - `HOST_UP = 2026-03-14 17:40:43 CST`
- 重启后关键服务全部恢复：
  - `tailscaled = active`
  - `mihomo-standalone = active`
  - `openclaw-gateway = active`
  - `openclaw-gateway-dayong = active`
  - `openclaw-gateway-chunyan = active`
  - `openclaw-gateway-zenglan = active`
- 监听状态仍正确：
  - `127.0.0.1:7897`
  - `127.0.0.1:18790`
  - `127.0.0.1:19021`
  - `127.0.0.1:19001`
  - `127.0.0.1:19041`
  - `127.0.0.1:8787`
  - `127.0.0.1:8788`

### 重启后的代理组状态
- 当前运行态保持成功：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- `故障转移` 当前仍为：
  - `Fallback`
  - `all_count = 12`
  - 节点集合与 `telegram-jp-tw-stable` 完全一致
- 这说明：
  - 主 `故障转移` 的日本/台湾 `12` 节点池在整机重启后也能自动恢复
  - 没有回退到之前的 54 节点全地区大池

### 重启后的实际流量验证
- Google 代理验证：
  - `https://www.google.com/generate_204` 返回 `204`
  - Mihomo 日志显示：
    - `www.google.com ... using 悠兔[专线2.5x-台湾1-GPT]`
- 其它实际命中：
  - `api.search.brave.com ... using 悠兔[专线2.5x-台湾1-GPT]`
  - `api.telegram.org ... using telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`

### 重启后的 webhook / Funnel 状态
- 两个 Telegram `getWebhookInfo` 当前均正常：
  - main：
    - `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
    - `pending_update_count = 0`
  - dayong：
    - `url = https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
    - `pending_update_count = 0`

### 本轮最终结论
- “主 `故障转移` 与 Telegram 组统一为日本/台湾 `12` 节点池”这版配置已经通过整机重启验证。
- 重启后整套系统自动恢复正常，且保持在新的目标状态。

### 再次复核（2026-03-14 17:46 CST）
- 用户要求再次单独核查两组：
  - 主 `悠兔 / 故障转移`
  - `telegram-jp-tw-stable`
- 当前持久化配置复核结果：
  - `故障转移`：
    - `type = fallback`
    - `interval = 5`
    - `lazy = true`
    - `timeout = 3000`
    - `max-failed-times = 1`
    - `expected-status = 204`
    - `url = https://www.gstatic.com/generate_204`
    - `proxies_count = 12`
  - `telegram-jp-tw-stable`：
    - `type = fallback`
    - `interval = 5`
    - `lazy = true`
    - `timeout = 3000`
    - `max-failed-times = 1`
    - `expected-status = 204`
    - `url = https://www.gstatic.com/generate_204`
    - `proxies_count = 12`
- 两组的节点列表当前完全一致，且都只包含：
  - 台湾 + 日本 `12` 节点

### 当前运行态复核
- 当前运行态为：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- 连续 `3` 次、每次间隔约 `6` 秒抽样，结果都保持不变：
  - `悠兔 = 故障转移`
  - `故障转移 = 专线2.5x-台湾1-GPT`
  - `telegram-jp-tw-stable = 专线2.5x-台湾1-GPT`
- 说明两组当前在稳定状态下都没有发生主动切换。

### 实际命中复核
- Google 实际代理访问：
  - `https://www.google.com/generate_204` 返回 `204`
  - 日志显示：
    - `www.google.com ... using 悠兔[专线2.5x-台湾1-GPT]`
- Telegram 实际命中：
  - `api.telegram.org ... using telegram-jp-tw-stable[专线2.5x-台湾1-GPT]`
- 结论：
  - 主 `悠兔 / 故障转移` 当前命中新主池正确
  - Telegram 专用组当前命中专用池正确

## BI. 四 Gateway 实时健康复核（2026-03-14 夜）

### 总结论
- 当前系统**不是“全面健康”**，而是“主体仍可用，但存在 3 个明确健康缺口”。
- 这次不能只看 `systemctl active` 下结论，因为运行态和目标架构已经出现分叉。

### 1. 主 Gateway（main）已从 Webhook 退化回 Telegram Polling

#### 运行时证据
- `openclaw-gateway.service`
  - `ActiveState=active`
  - `ExecMainStartTimestamp=2026-03-14 20:27:29 CST`
  - `NRestarts=1`
  - `UnitFileState=disabled`
- `openclaw agent --agent main --message 'Reply with exactly: MAIN_HEALTH_OK' --json`
  - 返回 `MAIN_HEALTH_OK`
  - provider=`minimax`
  - model=`MiniMax-M2.5`
- 说明：
  - 主模型链路仍是通的
  - 但服务状态已经不是“理想稳态”

#### Webhook 退化证据链
- 配置文件仍保留：
  - `channels.telegram.accounts.main-bot.webhookUrl = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
  - `channels.telegram.accounts.main-bot.webhookSecret = ...`
- `tailscale funnel status` 仍显示：
  - `https://openclaw-24x7.tailda6e28.ts.net -> 127.0.0.1:8787`
- 但 Telegram 官方 `getWebhookInfo` 返回：
  - `url = ""`
  - `pending_update_count = 0`
- `openclaw gateway health --json` 同样显示：
  - `channels.telegram.probe.webhook.url = ""`
- `ss -ltn` 当前监听里：
  - **没有** `127.0.0.1:8787`
  - 只看到 dayong 的 `127.0.0.1:8788`

#### 日志证据
- 主 Gateway 启动后日志显示：
  - `starting provider (@OpenClaw_kevinlasnh_no1_bot)`
  - 随后反复出现：
    - `Polling stall detected`
    - `Polling runner stop timed out after 15s`
    - `polling runner stopped (polling stall detected)`
- 本轮抓到的轮询卡死时间点：
  - `20:45:37`
  - `20:55:40`
  - `21:04:30`
  - `21:13:27`
  - `21:22:25`
  - `21:31:35`
  - `21:40:51`

#### 结论
- 当前 main **不是 webhook 模式健康运行**。
- 当前状态更准确地说是：
  - 配置仍写着 webhook
  - Funnel 仍对外暴露 443
  - 但 Telegram 官方 webhook 已被清空
  - 本地 8787 监听也没起来
  - 服务实际上在跑 polling，且 polling 正持续卡死重启
- 这已经足以判定：
  - **main 不达“全面健康”标准**

### 2. dayong 主链路基本健康，但有轻微瑕疵

#### 正常项
- `openclaw-gateway-dayong.service`
  - `active`
  - 自 `2026-03-14 17:40:30 CST` 持续运行
- `openclaw gateway health --json`
  - Telegram probe `ok`
  - webhook URL 正确：`https://openclaw-24x7.tailda6e28.ts.net:8443/telegram-webhook`
  - Feishu probe `ok`
- `openclaw agent --agent dayong ...`
  - 返回 `DAYONG_HEALTH_OK`

#### 轻微问题
- `20:22:26 CST`
  - `sendChatAction failed: Network request for 'sendChatAction' failed`
- `21:00:33 CST`
  - 飞书 final reply failed
  - 根因是卡片内容超限：`card table number over limit`

#### 结论
- dayong 当前可判定为：
  - **主链路健康**
  - 但存在少量瞬时网络抖动和内容级限制，不属于“零告警完美态”

### 3. chunyan 简单对话可用，但工具链损坏

#### 正常项
- `openclaw-gateway-chunyan.service`
  - `active`
  - 自 `2026-03-14 17:40:30 CST` 持续运行
- `openclaw gateway health --json`
  - Feishu probe `ok`
- `openclaw agent --agent chunyan ...`
  - 返回 `CHUNYAN_HEALTH_OK`

#### 异常项
- 最近日志多次出现：
  - `Cannot find module '/usr/lib/node_modules/openclaw/dist/pi-tools.before-tool-call.runtime-Bc5jTKSS.js'`
  - `Cannot find module '/usr/lib/node_modules/openclaw/dist/pi-model-discovery-BI7Yaf9u.js'`
- 受影响的工具包括：
  - `read`
  - `web_search`
  - `sessions_spawn`
  - `exec`
  - `gateway`
  - `sessions_send`
- 这不是单次业务失败，而是**运行时模块缺失**

#### 结论
- chunyan 当前状态是：
  - 纯文本简单回复还能工作
  - **但工具能力已不健康**
- 若按“全面健康”标准评估：
  - **不通过**

### 4. zenglan 用户面未见硬故障，但控制面握手异常

#### 正常项
- `openclaw-gateway-zenglan.service`
  - `active`
  - 自 `2026-03-14 17:40:30 CST` 持续运行
- `openclaw gateway health --json`
  - Feishu probe `ok`
- 简单自检最终返回：
  - `ZENGLAN_HEALTH_OK`

#### 异常项
- 本轮 CLI 连接本地 Gateway 时出现：
  - `gateway connect failed`
  - `gateway closed (1008): connect challenge timeout`
  - `Target: ws://127.0.0.1:19041`
- 服务日志同步记录：
  - `[ws] closed before connect ... reason=connect challenge timeout`
- 随后 CLI 才退回 embedded 模式完成自检

#### 结论
- zenglan 目前不能直接判成“挂了”
- 但至少可以确定：
  - **Gateway 控制面存在握手超时风险**
  - 运维视角下不能算完全健康

### 5. 当前可直接复用的判断模板

#### 可以说“健康”的部分
- `mihomo-standalone.service = active`
- `tailscaled.service = active`
- dayong 的 Telegram webhook 和 Feishu probe 均正常
- 四个 agent 的“最小文本回复”都还能跑通

#### 不能说“全面健康”的原因
1. main 已退回 polling 且持续 stall
2. main webhook 在 Telegram 官方侧已被清空，8787 本地监听缺失
3. main systemd unit 当前是 `disabled`
4. chunyan 工具运行时缺模块
5. zenglan 控制面 ws 握手超时

### 当前优先修复顺序
1. 修主 Gateway：
   - 恢复 main webhook 注册
   - 恢复 `127.0.0.1:8787` 监听
   - 让主服务回到 webhook，而不是 polling
   - 重新 `systemctl --user enable openclaw-gateway`
2. 修 chunyan：
   - 排查缺失的 `pi-tools.before-tool-call.runtime-*` / `pi-model-discovery-*` 文件
3. 复查 zenglan：
   - 复现并确认 `connect challenge timeout` 是否持续存在

## BJ. 四 Gateway 健康缺口修复结果（2026-03-14 夜）

### 1. main：Webhook 退化根因与修复

#### 根因
- `~/.openclaw/openclaw.json` 里：
  - 真正运行账号是 `channels.telegram.defaultAccount = "main-bot"`
  - 但 `webhookUrl` / `webhookSecret` 被错误放在：
    - `channels.telegram.accounts.default`
- 结果：
  - `main-bot` provider 启动时拿不到 webhook 配置
  - Telegram 官方侧 webhook 被清空
  - 本地也不再监听 `127.0.0.1:8787`
  - 服务只能退回 polling，持续出现 `Polling stall detected`

#### 额外问题
- `openclaw-gateway.service` 当时：
  - `UnitFileState=disabled`
  - 启动方式也与其余三个 Gateway 不一致
  - 旧 unit 直接跑 `/usr/bin/node ... dist/index.js`
  - 并把 `NEWCLI_API_KEY` 单独写在 unit 内，而不是 `.env`

#### 修复
- 将 `webhookUrl` / `webhookSecret` 移到 `channels.telegram` 顶层
- 删除多余的 `channels.telegram.accounts.default`
- 重写 `~/.config/systemd/user/openclaw-gateway.service`：
  - 改为 `openclaw gateway run --port 18790`
  - 加入 `EnvironmentFile=/home/kevinlasnh/.openclaw/.env`
  - 显式设置 `OPENCLAW_STATE_DIR` / `OPENCLAW_CONFIG_PATH`
- 从旧 unit 备份中补回 `NEWCLI_API_KEY`
- `systemctl --user daemon-reload`
- `systemctl --user enable openclaw-gateway`
- 重启主 Gateway

#### 验证
- `getWebhookInfo`：
  - `url = https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
  - `pending_update_count = 0`
- `openclaw gateway health --json`：
  - main webhook URL 正常出现
- `ss -ltn`：
  - `127.0.0.1:8787` 恢复监听
- 启动后日志明确显示：
  - `webhook local listener on http://127.0.0.1:8787/telegram-webhook`
  - `webhook advertised to telegram on https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook`
- 修复后再扫日志：
  - 未再见新的 `Polling stall detected`
- 自检：
  - `MAIN_FIXED_OK`

### 2. chunyan：缺失 dist 模块的真实根因

#### 根因判断
- 旧进程在 `2026-03-14 17:40` 启动后，系统上的 OpenClaw 全局安装后来已变成：
  - `OpenClaw 2026.3.13`
- 但旧进程仍持有旧的动态 import 路径，例如：
  - `reply-C5LKjXcC.js`
  - `pi-tools.before-tool-call.runtime-Bc5jTKSS.js`
  - `pi-model-discovery-BI7Yaf9u.js`
- 当前磁盘上的 `dist/` 已经是新的 hash 文件集合，没有这些旧文件。
- 所以一旦旧进程触发懒加载工具模块，就会报：
  - `Cannot find module ...`

#### 修复
- 不需要手工补假文件，也不需要重装
- 直接把 `openclaw-gateway-chunyan.service` 重启到当前一致的 `2026.3.13` 代码

#### 验证
- 修复后：
  - `openclaw gateway health --json` 正常
  - 强制 `read` 工具回归成功：`CHUNYAN_READ_TOOL_OK`
  - 最小自检成功：`CHUNYAN_FIXED_OK`
- 修复后新日志时间窗中，未再看到：
  - `Cannot find module`

### 3. zenglan：ws connect challenge timeout 根因与修复

#### 第一层根因
- 与 `chunyan` 一样，旧进程也处于“旧进程 + 新磁盘 dist”混态
- 先统一重启到当前代码后，旧 chunk 问题已消除

#### 第二层根因
- `zenglan` 在控制面仍继续报：
  - `gateway closed (1008): connect challenge timeout`
- 排查后确认：
  - `~/.openclaw-zenglan/devices/paired.json`
  - `~/.openclaw-zenglan/identity/device-auth.json`
  这组 CLI 配对状态继续沿用了故障态

#### 修复
- 备份并删除：
  - `devices/paired.json`
  - `identity/device-auth.json`
- 保留 `identity/device.json`
- 重启 `openclaw-gateway-zenglan.service`
- 让 CLI 与 Gateway 重新自动配对

#### 验证
- 重新执行 `openclaw agent --agent zenglan ...`
  - 不再出现 `gateway connect failed`
  - 不再出现 fallback 提示
  - 正常返回 `ZENGLAN_GATEWAY_OK`
  - 再次自检返回 `ZENGLAN_FIXED_OK`
- 新日志时间窗中未再见新的：
  - `connect challenge timeout`

### 4. dayong：统一重启后的复核

#### 处理
- 同步重启到当前一致代码

#### 验证
- `openclaw gateway health --json`：
  - Telegram webhook 正常
  - Feishu probe 正常
- 自检：
  - `DAYONG_FIXED_OK`

### 5. 修复后的统一状态
- 当前监听：
  - `127.0.0.1:8787`
  - `127.0.0.1:8788`
  - `127.0.0.1:18790`
  - `127.0.0.1:19021`
  - `127.0.0.1:19001`
  - `127.0.0.1:19041`
- 当前 systemd：
  - 四个 Gateway 全部 `active`
  - 四个 Gateway 全部 `enabled`
- 当前通道：
  - main Telegram webhook 正常
  - dayong Telegram webhook 正常
  - dayong / chunyan / zenglan 的 Feishu probe 全正常
- 当前结论：
  - 本轮发现的明确健康缺口已全部修复完毕

### 6. 备份记录
- `~/.openclaw/openclaw.json.pre-healthfix-20260314-215620`
- `~/.config/systemd/user/openclaw-gateway.service.pre-healthfix-20260314-215652`
- `~/.openclaw-zenglan/devices/paired.json.pre-healthfix-20260314-220232`
- `~/.openclaw-zenglan/identity/device-auth.json.pre-healthfix-20260314-220232`

### 7. 当前保留的非阻断噪声
- `main`
  - 启动时仍会出现多条：
    - `Skipping skill path that resolves outside its configured root.`
  - 含义：
    - OpenClaw 技能加载器发现某些技能路径解析后越出了允许根目录，于是出于安全原因跳过加载
  - 当前影响：
    - 只影响被跳过的那些技能是否可用
    - 不影响主 Gateway、Webhook、模型回复、通道健康
- `chunyan / zenglan`
  - 启动时仍有 `Doctor warnings`
  - 内容本质是：
    - 若未来启用 Telegram 群聊，当前 `groupPolicy=allowlist` 但白名单为空，会导致群消息被静默丢弃
  - 当前影响：
    - 两个实例当前 `channels.telegram.enabled = false`
    - 实际运行只用 Feishu
    - 因此这是提醒级噪声，不是当前故障
- 用户在本轮收尾已明确：
  - **暂不处理这两类噪声**
  - 仅保留为已知项

## 2026-04-02：main 升级到 2026.4.1，并将本地语义检索稳定到 Qwen 4B GPU

### 最新版结论
- 远端 `npm view openclaw version` 确认为：
  - `2026.4.1`
- `OpenClaw 2026.4.1` 的本地 memorySearch 实现仍未把以下参数暴露到配置层：
  - `gpu`
  - `gpuLayers`
  - `contextSize`
- 对应源码位置：
  - `/usr/lib/node_modules/openclaw/dist/memory-core-host-engine-embeddings-CURmoLEe.js`
- 默认实现仍是：
  - `getLlama({ logLevel: LlamaLogLevel.error })`
  - `loadModel({ modelPath: resolved })`
  - `createEmbeddingContext()`

### 原生 GPU 自动策略的问题
- 在 `main` 上使用 OpenClaw 原生本地 provider 时，显存问题的根因不是模型文件大小本身，而是：
  - `node-llama-cpp` 的 GPU 自动策略
  - 自动创建的 embedding context
  - Vulkan compute buffer 的额外分配
- 实测即使是 `jina-embeddings-v5-text-small-retrieval-GGUF`，在“原生源码 + GPU 默认策略”下也会出现：
  - `ggml_vulkan: Device memory allocation ... failed`
  - `failed to allocate compute pp buffers`
- 结论：
  - 这台 `RTX 3060 Laptop 6GB` 上，OpenClaw 原生 `createEmbeddingContext()` 默认策略不稳
  - 需要显式限制 context，才能稳定使用 GPU 本地 embedding

### 最终采用的最小补丁
- 用户要求：
  - 只改一处源码参数
  - 保持 OpenClaw 官方 `local` provider 路径
  - 本地 embedding 继续走 GPU
- 实际补丁：
  - 文件：
    - `/usr/lib/node_modules/openclaw/dist/memory-core-host-engine-embeddings-CURmoLEe.js`
  - 改动前：
    - `if (!embeddingContext) embeddingContext = await embeddingModel.createEmbeddingContext();`
  - 改动后：
    - `if (!embeddingContext) embeddingContext = await embeddingModel.createEmbeddingContext({ contextSize: 2048 });`
- 说明：
  - 这是唯一的行为性源码改动
  - 没有改 provider 逻辑、没有接 Ollama、没有改聊天模型链路

### main 最终本地语义检索模型
- 配置位置：
  - `~/.openclaw/openclaw.json`
- 最终使用：
  - `agents.defaults.memorySearch.provider = "local"`
  - `agents.defaults.memorySearch.fallback = "none"`
  - `agents.defaults.memorySearch.local.modelPath = "/home/kevinlasnh/.cache/openclaw/models/Qwen3-Embedding-4B-Q4_K_M.gguf"`
- 聊天主模型保持：
  - `openai-codex/gpt-5.4`

### 实测结果
- 强制重建索引：
  - `openclaw memory index --agent main --force`
  - 返回：
    - `Memory index updated (main).`
- `memory status --deep --json` 关键结果：
  - `provider = "local"`
  - `model = "/home/kevinlasnh/.cache/openclaw/models/Qwen3-Embedding-4B-Q4_K_M.gguf"`
  - `vector.dims = 2560`
  - `embeddingProbe.ok = true`
- `memory search --agent main --json --query 'kevinlasnh' --max-results 5`
  - 成功返回多个结果
  - 已确认能命中：
    - `MEMORY.md`
    - `memory/*.md`
- GPU 实测：
  - 初始化后常驻大约：
    - `2412 MiB`
  - 重建索引阶段峰值大约：
    - `3048-3056 MiB`
  - 当前 6GB 卡上稳定运行，没有再次触发 OOM

### 升级相关注意事项
- `openclaw@2026.4.1` 的全局安装主包已成功升级。
- CLI 入口曾在升级过程中短暂丢失，已修回：
  - `/usr/bin/openclaw -> /usr/lib/node_modules/openclaw/openclaw.mjs`
- `node-llama-cpp` 运行时在升级后需要重新接回：
  - `/usr/lib/node_modules/openclaw/node_modules/node-llama-cpp`
  - `/usr/lib/node_modules/openclaw/node_modules/@node-llama-cpp/*`
- 当前仍存在一个非阻断噪声：
  - `amazon-bedrock` 插件缺少 `@aws-sdk/client-bedrock`
  - Gateway 可正常运行，`main` 的 Telegram / GPT-5.4 / Qwen4B memorySearch 不受影响

### 以后若再次 update 被覆盖
- 重新检查：
  - `/usr/lib/node_modules/openclaw/dist/memory-core-host-engine-embeddings-CURmoLEe.js`
- 只需重打这一处：
  - `createEmbeddingContext() -> createEmbeddingContext({ contextSize: 2048 })`
- 再确认：
  - `~/.openclaw/openclaw.json` 的 `memorySearch.local.modelPath`
  - 是否仍指向 `Qwen3-Embedding-4B-Q4_K_M.gguf`

## 2026-04-02：上游缺口记录（准备向 OpenClaw 提 PR）

### 问题定义
- OpenClaw 当前 `memorySearch.provider = "local"` 的配置层没有暴露本地 embedding 运行参数。
- 实际缺少的关键配置口子：
  - `agents.defaults.memorySearch.local.contextSize`
  - `agents.defaults.memorySearch.local.gpu`
  - `agents.defaults.memorySearch.local.gpuLayers`
  - 可选：`agents.defaults.memorySearch.local.flashAttention`

### 当前影响
- 在 `RTX 3060 Laptop 6GB` 这类显存紧张机器上：
  - 只能走 `node-llama-cpp` 的默认自动策略
  - 默认策略可能把 embedding context / GPU 分配得过激
  - 即使是较小模型，也可能在真实检索时触发 OOM
- 用户如果要稳定本地 GPU embedding，只能：
  - 修改安装后的 dist bundle
  - 而不是通过 `openclaw.json` 原生配置解决

### 当前对应源码
- 文件：
  - `/usr/lib/node_modules/openclaw/dist/memory-core-host-engine-embeddings-CURmoLEe.js`
- 当前上游默认写法：
  - `getLlama({ logLevel: LlamaLogLevel.error })`
  - `loadModel({ modelPath: resolved })`
  - `createEmbeddingContext()`

### 建议的上游改法
- 在 `memorySearch.local` 下新增可选配置：
  - `contextSize?: number`
  - `gpu?: "auto" | "cuda" | "vulkan" | false`
  - `gpuLayers?: "auto" | "max" | number`
  - `flashAttention?: boolean`
- 运行时只在用户显式配置时透传给 `node-llama-cpp`
- 不改默认行为，保持向后兼容

### 明天发 PR 时要点
- 标题方向：
  - `Expose local memorySearch llama context/gpu settings`
- PR 目标：
  - 不改变默认值
  - 只增加配置透传能力
  - 解决低显存机器上本地 embedding 无法稳定调优的问题

## 新发现（2026-04-03 中午）：`main` 上“Skill 名还在提示词里”不一定代表磁盘还没删干净，可能只是 `sessions.json` 缓存了旧 `available_skills`

### 本轮现场结论
- 在本轮先删除：
  - `~/.openclaw/skills`
  - `~/.openclaw/workspace/skills`
  - `~/.agents`
  之后，现场再次执行：
  - `openclaw agent --agent main ... --json`
  返回的 `systemPromptReport.skills.entries` 仍然继续列出：
  - `capability-evolver`
  - `planning-with-files`
  - `brainstorming`
  - `pinchtab`
  - `openclaw-updater`
  - 等大量旧 Skill

### 根因
- 当前残留来源不是磁盘上的 `SKILL.md` 文件，而是：
  - `~/.openclaw/agents/main/sessions/sessions.json`
  - 当前活跃会话对应的旧 `sessionId`
- 现场 grep 已直接命中：
  - 旧的 `<available_skills>` prompt 文本
  - 已删除路径：
    - `~/.openclaw/skills/...`
    - `~/.agents/skills/...`
    - `~/.openclaw/workspace/skills/...`
  都仍以历史记录形式保存在 `sessions.json` 中

### 稳定修法
- 只删物理 Skill 目录还不够。
- 若想让 `main` 的运行时提示词立即变干净，必须再清：
  - `~/.openclaw/agents/main/sessions`
- 清理后重启 `openclaw-gateway`，再跑新的最小会话：
  - `MAIN_SESSION_PURGE_OK`

### 修复后结果
- 新的 `main` 会话 `sessionId` 已变为新的 boot session。
- `systemPromptReport.skills.entries` 当前只剩 bundled：
  - `healthcheck`
  - `weather`
- 同时现场确认：
  - `find ~/.openclaw ~/.openclaw/workspace -type f -name SKILL.md`
  已无结果

## 新发现（2026-04-03 中午）：这次长任务超时的直接修法是显式设置 `agents.defaults.timeoutSeconds`，不是只改 `subagents.runTimeoutSeconds`

### 现场证据
- 日志时间点：
  - `2026-04-03 12:02:18 CST`
- 现场日志明确出现：
  - `Profile openai-codex:codex-cli timed out. Trying next account...`
  - `decision=surface_error reason=timeout`
- OpenClaw 用户面报错同时提示：
  - `increase agents.defaults.timeoutSeconds`

### 关键区分
- 当前 `main` 原本已有：
  - `agents.defaults.subagents.runTimeoutSeconds = 3600`
- 但这只覆盖：
  - 子代理运行时长
- 并不等于：
  - 主 assistant 生成阶段的总超时

### 本轮落地
- 已向：
  - `~/.openclaw/openclaw.json`
  写入：
  - `agents.defaults.timeoutSeconds = 3600`
- 修改后：
  - `openclaw config validate` 通过
  - `main` 自检通过：
    - `MAIN_CLEAN_OK`
    - `MAIN_SESSION_PURGE_OK`

## 新发现（2026-04-03 下午）：`main` 当前 `/status` 已明确恢复到 `272k`，`200k` 不是当前 live 配置

### 现场证据
- 直接对 `main` 发送：
  - `openclaw agent --agent main --message '/status' --json`
- 当前返回的状态卡为：
  - `📚 Context: 29k/272k (11%)`
- 继续检查 live 配置：
  - `~/.openclaw/openclaw.json`
  - 当前没有显式设置：
    - `agents.defaults.contextTokens`
- 再检查：
  - `openclaw sessions --agent main --json`
  - 当前 `main` 的以下会话都记录为：
    - `contextTokens = 272000`
  - 包括：
    - `agent:main:main`
    - `agent:main:telegram:main-bot:direct:8226087994`
    - `agent:main:telegram:slash:8226087994`

### 运维结论
- 这说明当前 `main` 的 live 上下文窗口已经对齐到：
  - `272k`
- 用户如果仍在某条聊天记录里看到：
  - `200k`
  更可能是：
  - 旧状态消息
  - 旧会话截图
  - 或不是当前这条 `main` 会话的状态卡
- 这次不需要再改：
  - `openclaw.json`
- 也不需要因为这件事再重启：
  - `openclaw-gateway`

## 新发现（2026-04-06 中午）：在当前这台 `OpenClaw 2026.4.1` 上，`main` 切智谱 `GLM-5.1` 的稳妥做法是显式补 `models.providers.zai`，并把端点固定到智谱 Coding Plan CN 的 `https://open.bigmodel.cn/api/coding/paas/v4`

### 本轮现场证据
- 智谱官方 `OpenClaw` 接入文档明确写了：
  - 非官方手工配置时，Coding 端点应使用：
    - `https://open.bigmodel.cn/api/coding/paas/v4`
- 同一篇文档还明确写了：
  - 当前 Coding Plan 支持的模型包括：
    - `GLM-5.1`
    - `GLM-5`
    - `GLM-5V-Turbo`
    - 以及多种 `4.x` 变体
- OpenClaw 官方 `Z.AI` 文档也已把 bundled catalog 写到：
  - `glm-5.1`
  - `glm-5`
  - `glm-5v-turbo`
  - 等
- 但本轮远端现场执行：
  - `openclaw models list --all --provider zai --plain`
  实际只列出了到：
    - `zai/glm-5`
    - `zai/glm-5-turbo`
  没有直接枚举出：
    - `zai/glm-5.1`
    - `zai/glm-5v-turbo`

### 工程判断
- 这说明：
  - **文档能力已经前进到 `glm-5.1`**
  - 但当前这台主机上的 live catalog 枚举结果并不完全跟上
- 在这种组合下，最稳的落地法不是“等 picker 自动出现”，而是：
  - **显式写 `models.providers.zai`**
  - **显式注册 `glm-5.1`**
  - **再把 `agents.defaults.model.primary` 指过去**

### 本轮最终可用配置
- `~/.openclaw/.env`
  - 已新增：
    - `ZAI_API_KEY`
- `~/.openclaw/openclaw.json`
  - `models.providers.zai.baseUrl`
    - `https://open.bigmodel.cn/api/coding/paas/v4`
  - `models.providers.zai.api`
    - `openai-completions`
  - `models.providers.zai.models`
    - 显式包含：
      - `glm-5.1`
  - `agents.defaults.model.primary`
    - `zai/glm-5.1`
  - `agents.defaults.model.fallbacks`
    - `[minimax/MiniMax-M2.7]`

### 实打验收
- `openclaw config validate`
  - 通过
- 重启主 Gateway 后最小实呼：
  - 返回：
    - `MAIN_GLM51_OK`
- 返回元数据明确显示：
  - `provider = zai`
  - `model = glm-5.1`
- 启动日志明确显示：
  - `agent model: zai/glm-5.1`

### 同轮带出的多模态结论
- 当前 `main` 的：
  - `imageModel`
  仍是：
  - `kimi/k2p5`
- 当前没有显式钉死：
  - `imageGenerationModel`
  - `pdfModel`
  - `audioTranscriptionModel`
  - `ttsModel`
- 但本轮 `systemPromptReport.tools.entries` 已确认：
  - `pdf`
  - `image_generate`
  仍然暴露
- 同时本轮顺手发现：
  - 现有自定义 `minimax` provider 之前把：
    - `MiniMax-M2.7`
    - `MiniMax-M2.7-highspeed`
    错写成：
    - `input = ["text"]`
- 按 OpenClaw 官方 `MiniMax` 文档应改为：
  - `input = ["text","image"]`
- 本轮已修正

### 一个容易重踩的坑
- 通过 Windows PowerShell 发 SSH 命令时，如果在双引号上下文里直接写：
  - `${ZAI_API_KEY}`
- 本地 PowerShell 会先尝试展开它，导致写到远端 JSON 时可能变成：
  - 空字符串
- 稳定修法：
  - 在生成远端 JSON 时显式拼接：
    - `'$' + '{ZAI_API_KEY}'`
  - 或避免在 PowerShell 双引号层直接出现该字面量

## 新发现（2026-04-06 中午）：`GLM-5V-Turbo` 适合挂到 `main` 的 `imageModel`，并且当前这把智谱 Coding Plan key 已实测可用

### 本轮现场依据
- 智谱官方 `GLM-5V-Turbo` 模型文档当前明确写了：
  - 定位：
    - 多模态 Coding 基座
  - 输入模态：
    - 视频、图像、文本、文件
  - 输出模态：
    - 文本
  - 上下文窗口：
    - `200K`
  - 最大输出：
    - `128K`
  - 并明确写到：
    - OpenClaw 接入后可看懂网页布局、GUI 元素和图表信息

### 本轮落地配置
- `~/.openclaw/openclaw.json`
  - `models.providers.zai.models`
    - 已显式补入：
      - `glm-5v-turbo`
  - `agents.defaults.imageModel.primary`
    - `zai/glm-5v-turbo`
  - `agents.defaults.imageModel.fallbacks`
    - `[minimax/MiniMax-M2.7]`
  - `agents.defaults.models`
    - 已补入：
      - `zai/glm-5v-turbo`

### 实打验收
- `openclaw config validate`
  - 通过
- `openclaw models status --json`
  - 当前已显示：
    - `imageModel = zai/glm-5v-turbo`
    - `imageFallbacks = [minimax/MiniMax-M2.7]`
- 直接对智谱官方通用对话端点执行带图最小请求：
  - `POST https://open.bigmodel.cn/api/paas/v4/chat/completions`
  - `model = glm-5v-turbo`
  - 输入里包含公开图片 URL
  - 当前返回：
    - `GLM5V_IMAGE_OK`
- 重启 `main` Gateway 后，文本主链路最小回归：
  - `MAIN_IMAGE_ROUTE_UPDATED_OK`
  - 文本主模型仍保持：
    - `zai/glm-5.1`

### 工程结论
- 对当前这台 `main` 来说，较稳的模型分工已经变成：
  - 文本主模型：
    - `zai/glm-5.1`
  - 文本 fallback：
    - `minimax/MiniMax-M2.7`
  - 图片理解主模型：
    - `zai/glm-5v-turbo`
  - 图片理解 fallback：
    - `minimax/MiniMax-M2.7`
- 这样做的好处是：
  - 智谱套餐负责主文本 + 主视觉
  - MiniMax 只承担兜底
  - 同时不影响现有本地 embedding 配置

## 新发现（2026-04-07 晚）：多实例从 `MiniMax` 切到 `GLM-5` 时，`openclaw config validate` 和 `Gateway restart` 都通过，不等于 live 元数据一定立即切到新模型

### 本轮现场依据
- `dayong` / `chunyan` / `zenglan` 三个实例本轮都已：
  - 补入 `ZAI_API_KEY`
  - 配置 `models.providers.zai`
  - 将：
    - `agents.defaults.model.primary`
    统一改为：
    - `zai/glm-5`
  - 清空：
    - `agents.defaults.model.fallbacks`
  - 通过：
    - `openclaw config validate`
  - 执行：
    - `systemctl --user restart`
- 但 live 最小实呼结果出现分化：
  - `chunyan`
    - `provider = zai`
    - `model = glm-5`
  - `zenglan`
    - `provider = zai`
    - `model = glm-5`
  - `dayong`
    - 回复文本已按要求返回
    - 但元数据仍显示：
      - `provider = minimax`
      - `model = MiniMax-M2.7`

### 工程结论
- 对 OpenClaw 多实例来说：
  - **配置校验通过**
  - **systemd 已重启**
  仍不足以证明：
  - 运行中实例已经切到目标 provider/model
- 更稳的验收标准应是：
  - 最小实呼成功
  - 且返回元数据明确显示：
    - `provider`
    - `model`
  都已切到目标值

## 新发现（2026-04-07 晚）：Windows 宿主机上的 `WSLService` 被禁用时，会让所有 OpenClaw live 运维瞬间失去入口

### 本轮现场依据
- 当前这台 Windows 宿主机检查到：
  - `WSLService = Disabled`
  - `vmcompute = Stopped`
- 此时所有：
  - `wsl.exe`
  调用都会直接报：
  - `Wsl/0x80070422`
- 将 `WSLService` 改回：
  - `Manual`
  并启动后，
  `wsl.exe` 不再报 `0x80070422`
- 但当前 `Ubuntu` 发行版继续报：
  - `HCS_E_HYPERV_NOT_INSTALLED`

### 工程结论
- 对这个仓库的 live 运维链路来说：
  - 一旦 Windows 宿主机的：
    - `WSLService`
    被禁用，
  即使 OpenClaw 配置本身没坏，
  也会失去：
  - `wsl.exe`
  - `\\wsl$`
  这两条常用运维入口
- 这类故障的根因层级高于 OpenClaw 本身，
  应按：
  - Windows 虚拟化/WSL 宿主机问题
  处理，而不是先怀疑 OpenClaw JSON 配置

## 更正（2026-04-07 夜）：本仓库当前 live 小龙虾并不运行在本地 WSL，上述 `WSLService` / `HCS_E_HYPERV_NOT_INSTALLED` 判断不适用于这次远程运维

### 本轮现场依据
- 用户已明确澄清：
  - 当前所有小龙虾都运行在远程机器上
- 仓库中的：
  - [CLAUDE.md](C:/Zero/Doc/Cloud/GitHub/OpenClaw/CLAUDE.md)
  也已写明当前 live 入口应为：
  - `ssh kevinlasnh@100.64.65.65`
- 继续按 SSH 复核远程机后，已能直接看到：
  - `openclaw-gateway-dayong`
  - `openclaw-gateway-chunyan`
  - `openclaw-gateway-zenglan`
  的真实状态与 live 配置

### 工程结论
- 对当前这个仓库：
  - **live 小龙虾运行在远程 Ubuntu `100.64.65.65`**
  - **本地 WSL 只属于日常工作环境，不是 live 运行时**
- 因此这次运维中提到的：
  - `WSLService`
  - `HCS_E_HYPERV_NOT_INSTALLED`
  只能视为：
  - 本地环境噪声
  不应再作为 live 小龙虾故障依据

## 新发现（2026-04-07 夜）：对多 Agent 实例，`agents.defaults.model.primary` 改成 `GLM-5` 后，如果 `agents.list[].model` 仍显式指向旧模型，live 仍会继续走旧 provider

### 本轮现场依据
- `chunyan` 与 `zenglan` 的 `agents.list[].model` 为空，
  所以继承默认值后，
  live 直接切到了：
  - `zai/glm-5`
- `dayong` 的 `~/.openclaw-dayong/openclaw.json` 中则存在 5 个显式覆盖：
  - `dayong`
  - `sector`
  - `stock`
  - `market`
  - `strategy`
  它们都写着：
  - `model = minimax/MiniMax-M2.7`
- 因此即使同文件中的：
  - `agents.defaults.model.primary = zai/glm-5`
  已经生效，
  `dayong` 的最小实呼元数据仍返回：
  - `provider = minimax`
  - `model = MiniMax-M2.7`
- 将这 5 个显式 `model` 全部改成：
  - `zai/glm-5`
  并重启 `openclaw-gateway-dayong` 后，
  再次最小实呼返回：
  - `DAYONG_GLM5_RECHECK2_OK`
  - `provider = zai`
  - `model = glm-5`

### 工程结论
- 对多 Agent 小龙虾做模型迁移时：
  - **不能只改 `agents.defaults.model.primary`**
- 还必须检查：
  - `agents.list[].model`
  是否存在显式覆盖
- 更稳的迁移验收顺序应是：
  1. 改 `agents.defaults.model`
  2. 检查并同步所有 `agents.list[].model`
  3. `openclaw config validate`
  4. 重启对应 Gateway
  5. 用最小实呼确认 live 元数据中的：
     - `provider`
     - `model`

## 新发现（2026-04-08 中午）：`openclaw@2026.4.7` 当前 npm latest 不是“可直接用”的干净包，至少存在 3 类真实打包缺口

### 本轮现场依据
- 远端现场直接确认：
  - `npm view openclaw version`
    返回：
    - `2026.4.7`
  - `dist-tags.latest`
    也是：
    - `2026.4.7`
- 但主实例一旦重启到该版本，第一时间就报：
  - `Cannot find module 'grammy'`
- 继续复核该版本真实包目录：
  - `~/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.7_@napi-rs+canvas@0.1.97/node_modules/openclaw/package.json`
  现场没有声明：
  - `grammy`
- 在补完第一层依赖后，第二层又报：
  - `bundled plugin entry "./src/channel.setup.js" failed to open`
  - `ENOENT ... dist/extensions/telegram/src/channel.setup.js`
- 继续扫描 `dist/extensions/*` 后坐实：
  - 多个 channel extension 的 `setup-entry.js` / `index.js`
    会引用：
    - `./src/secret-contract.js`
  - Telegram 还额外引用：
    - `./src/channel.setup.js`
  - 但这些文件根本没被打进 dist
- 再继续补齐后，Telegram provider 运行时又依次报：
  - `Cannot find package '@grammyjs/runner'`
  - `Cannot find package '@grammyjs/transformer-throttler'`

### 本轮额外坐实的一个 pnpm 坑
- 当前这台机上同时存在两棵虚拟仓库：
  - `~/.local/share/pnpm/global/5/.pnpm`
  - `~/.local/share/pnpm/global/5/node_modules/.pnpm`
- 真实 CLI wrapper：
  - `~/.local/share/pnpm/openclaw`
  现场内容明确写着：
  - `NODE_PATH=/home/kevinlasnh/.local/share/pnpm/global/5/.pnpm/...`
- 工程上这意味着：
  - **真实运行入口只吃第一棵树**
  - 如果误在：
    - `node_modules/.pnpm`
    那棵树里补依赖，
    CLI 仍会继续报同样的缺包错误

### 本轮最终热修法
- 在真实运行树：
  - `~/.local/share/pnpm/global/5/.pnpm/openclaw@2026.4.7_@napi-rs+canvas@0.1.97/node_modules/openclaw`
  直接补入：
  - `grammy`
  - `@grammyjs/runner`
  - `@grammyjs/transformer-throttler`
- 同时为以下扩展补回缺失桥接文件：
  - `bluebubbles`
  - `feishu`
  - `googlechat`
  - `irc`
  - `matrix`
  - `mattermost`
  - `msteams`
  - `nextcloud-talk`
  - `slack`
  - `telegram`
  - `zalo`
- 其中：
  - `src/secret-contract.js`
    统一桥接到：
    - `../secret-contract-api.js`
  - `telegram/src/channel.setup.js`
    桥接到：
    - `../channel-plugin-api.js`

### 验收结果
- 热修后：
  - `openclaw config validate`
    通过
- 主 Gateway 日志恢复为：
  - `ready`
  - `telegram starting provider`
  - `webhook local listener`
  - `webhook advertised to telegram`
- 最小实呼通过：
  - `MAIN_202647_OK`

### 工程结论
- 对当前这台主机来说：
  - `openclaw@2026.4.7`
    **不是一个可直接信任的干净上游包**
- 更准确的说法是：
  - **2026.4.7 可以跑**
  - 但前提是：
    - 先做本机热修
- 因此以后如果再次执行：
  - `openclaw update`
  - `pnpm add -g openclaw@latest`
  - 或任何重装
  应默认检查这三类问题是否被重新引入：
  1. `grammy` 是否仍缺失
  2. `dist/extensions/*/src/*.js` 桥接文件是否仍缺失
  3. Telegram runtime 的：
     - `@grammyjs/runner`
     - `@grammyjs/transformer-throttler`
     是否仍缺失

## 新发现（2026-04-08 下午）：对 `2026.4.7` 的这批本机热修，当前不是 sticky 修复；一旦安装树被重新覆盖，故障会原样复发

### 本轮现场依据
- 同日稍后再次复核时，主服务日志又重新回到：
  - `Cannot find module 'grammy'`
- 也就是说：
  - 上午已补好的：
    - `grammy`
    - `@grammyjs/runner`
    - `@grammyjs/transformer-throttler`
    - `dist/extensions/*/src/*.js`
  并没有被某种“持久层”记住
- 重新把同一批热修再次打回真实运行树后，
  主服务又再次恢复：
  - `config validate = valid`
  - `gateway active`
  - `telegram webhook local listener`
  - `sendMessage ok`

### 工程结论
- 当前这类修法的本质是：
  - **直接改安装树**
- 所以它的生命周期只和当前这棵安装树一致；
  - 任何重新安装、重新覆盖、重新生成 node_modules 的动作，
    都可能把补丁抹掉
- 更直白地说：
  - **这不是一次修完就永久生效的修复**
  - **而是“每次覆盖后都要重打”的热修**

## 新发现（2026-04-28）：main 已切到 Xiaomi MiMo V2.5 Pro 主模型，DeepSeek V4 Pro 作为 fallback，图片模型暂不配置

### 接口与模型配置
- 用户提供的 Xiaomi MiMo Token Plan CN 入口是 Anthropic Messages 兼容形态：
  - `https://token-plan-cn.xiaomimimo.com/anthropic`
- 本轮在 OpenClaw 中使用自定义 provider：
  - provider id：`xiaomi-mimo`
  - `api = anthropic-messages`
  - model id：`mimo-v2.5-pro`
  - OpenClaw 模型名：`xiaomi-mimo/mimo-v2.5-pro`
- `main` 当前文本配置：
  - `agents.defaults.model.primary = xiaomi-mimo/mimo-v2.5-pro`
  - `agents.defaults.model.fallbacks = [deepseek/deepseek-v4-pro]`
  - `agents.defaults.models` 只允许上述两个模型

### 直连策略
- 已更新 main 的 systemd user drop-in：
  - `~/.config/systemd/user/openclaw-gateway.service.d/10-deepseek-no-proxy.conf`
- 当前同时绕过代理：
  - `token-plan-cn.xiaomimimo.com`
  - `.xiaomimimo.com`
  - `api.deepseek.com`
  - `.deepseek.com`
- 仍保留：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- 远端实测：
  - Xiaomi 文本直连 `/v1/messages` 成功，返回模型 `mimo-v2.5-pro`
  - 直连约 `2.7s`
  - 经 Mihomo 代理约 `5.8s`
  - 因此 main 对 Xiaomi endpoint 采用直连更合适。

### 图片模型判断
- 本轮直接对 Xiaomi Anthropic Messages 入口发起 base64 PNG 图片块请求。
- 两次带图请求都 HTTP 200，但模型回复“没有看到图片”。
- 工程结论：
  - 当前这个 Token Plan Anthropic 入口不能作为可靠图片理解入口
  - `main` 暂不配置 `agents.defaults.imageModel`
  - 若后续小米提供 OpenAI-compatible 多模态入口或明确支持图像块，再单独复测后配置

### 验收
- `openclaw config validate` 通过。
- `openclaw models status --json` 显示：
  - `defaultModel = xiaomi-mimo/mimo-v2.5-pro`
  - `resolvedDefault = xiaomi-mimo/mimo-v2.5-pro`
  - `fallbacks = [deepseek/deepseek-v4-pro]`
  - `imageModel = null`
- `openclaw agent --agent main` 最小实呼返回：
  - `MAIN_XIAOMI_MIMO_V25_PRO_OK`
  - `winnerProvider = xiaomi-mimo`
  - `winnerModel = mimo-v2.5-pro`
  - `fallbackUsed = false`
- `openclaw gateway health --json` 复核：
  - `ok = true`
  - Telegram webhook probe ok
- 代理回归：
  - `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` 返回 `204`

## 新发现（2026-04-28）：Xiaomi MiMo V2.5 可作为 main 的图片理解模型，V2.5-Pro 不适合

### 候选模型实测
- 使用同一个 Token Plan CN Anthropic 入口：
  - `https://token-plan-cn.xiaomimimo.com/anthropic`
- 带图请求使用 base64 PNG 图片块，问题为识别纯色方块主色。
- 结果：
  - `mimo-v2.5`：HTTP 200，回复 `Green`，可看图
  - `mimo-v2-omni`：HTTP 200，回复 `Green`，可看图
  - `mimo-v2-pro`：HTTP 200，但回复看不到图片
  - `mimo-v2.5-pro`：HTTP 200，但回复看不到图片
- TTS 系列：
  - `MiMo-V2.5-TTS-VoiceClone`
  - `MiMo-V2.5-TTS-VoiceDesign`
  - `MiMo-V2.5-TTS`
  - `MiMo-V2-TTS`
  都属于语音合成方向，不适合作为 OpenClaw 图片理解模型。

### 配置决策
- 选择 `mimo-v2.5` 作为图片理解模型，而不是 `mimo-v2-omni`：
  - 同样能看图
  - 属于 V2.5 系列，比 V2 Omni 更新
  - 与文本主模型同属 Xiaomi MiMo provider
- 当前 main 配置：
  - `agents.defaults.imageModel.primary = xiaomi-mimo/mimo-v2.5`
  - `agents.defaults.imageModel.fallbacks = []`
- `models.providers.xiaomi-mimo.models` 当前包含：
  - `mimo-v2.5-pro`，`input = ["text"]`
  - `mimo-v2.5`，`input = ["text", "image"]`

### 验收
- 已备份远端配置：
  - `/home/kevinlasnh/.openclaw-backups/main-xiaomi-image-mimo-v25-20260428-140412`
- `openclaw config validate` 通过。
- `openclaw models status --json` 显示：
  - `defaultModel = xiaomi-mimo/mimo-v2.5-pro`
  - `fallbacks = [deepseek/deepseek-v4-pro]`
  - `allowed = [xiaomi-mimo/mimo-v2.5-pro, deepseek/deepseek-v4-pro, xiaomi-mimo/mimo-v2.5]`
  - `imageModel = xiaomi-mimo/mimo-v2.5`
  - `imageFallbacks = []`
- `openclaw agent --agent main` 文本 smoke test 仍走：
  - `winnerProvider = xiaomi-mimo`
  - `winnerModel = mimo-v2.5-pro`
  - `fallbackUsed = false`
- `openclaw gateway health --json` 复核：
  - `ok = true`
  - Telegram webhook probe ok
- 代理回归：
  - `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` 返回 `204`

## 新发现（2026-05-03）：main Gateway 已收敛为 1 个 Agent + 2 条喝水 cron

### 清理前状态
- `~/.openclaw/openclaw.json` 中 `agents.list.count = 1`，配置层实际只有 `main` Agent。
- 但 `~/.openclaw/agents/` 下仍残留旧状态目录：
  - `dayong`
  - `default`
  - `market`
  - `sector`
  - `stock`
- cron store 中共有 17 条任务：
  - 11 条启用
  - 6 条禁用
- 用户明确只想保留两条喝水提醒：
  - `drink-water-hourly`
  - `drink-water-half`

### 已清理内容
- 已备份：
  - `/home/kevinlasnh/.openclaw-backups/main-clean-cron-agents-20260503-143130`
- 已通过 `openclaw cron rm` 删除 15 条非喝水 cron：
  - 3 条 `morning-briefing`
  - 3 条 `market-reflection`
  - 3 条 `sector-reflection`
  - 3 条已禁用 `closing-report`
  - 3 条已禁用 `sector-daily-push`
- 已将旧 agent 状态目录移入上述备份目录。

### 当前最终状态
- `~/.openclaw/openclaw.json`：
  - `agents.list.count = 1`
  - 唯一 Agent 为 `main`
- `~/.openclaw/agents/`：
  - 只剩 `main`
- `openclaw cron status --json`：
  - `jobs = 2`
- 当前仅保留：
  - `drink-water-hourly`
    - `0 10,11,14,15,16,17,20,21 * * *`
  - `drink-water-half`
    - `30 9,10,11,13,14,15,16,17,19,20,21 * * *`
- 已重启 `openclaw-gateway`。
- 验收结果：
  - `openclaw config validate` 通过
  - `gateway health ok = true`
  - Telegram webhook probe ok
  - 日志显示 `gateway ready` 与 `webhook advertised to telegram`

## 新发现（2026-05-03）：GTD 待办管理系统设计 — OpenClaw 架构调研

### OpenClaw Workspace 文件系统（官方文档确认）

- 所有 workspace markdown 文件被 Context Engine 合成为 system prompt 的 "Project Context" 区段
- **单文件上限**: `agents.defaults.bootstrapMaxChars`（默认 12,000 字符）
- **总上限**: 60,000 字符
- **Sub-agent 只接收 AGENTS.md + TOOLS.md**（minimal 模式）
- Session 启动时快照所有合格 skill，支持 watcher 热重载

### OpenClaw Skill 系统

- SKILL.md 必填：`name` + `description`
- 可选字段：`user-invocable`（slash command）、`command-dispatch`（tool）、`disable-model-invocation`
- Gating：`metadata.openclaw.requires.bins/env/os/config`
- 注入方式：compact XML list，每个 skill 约 24 tokens 开销
- 优先级：workspace/skills/ > ~/.agents/skills/ > bundled
- 同名 skill 最高优先级胜出

### OpenClaw Cron 系统

- 3 种调度：one-shot (`--at`) / fixed interval (`--every`) / cron 表达式 (`--cron`)
- 4 种 session 模式：main / isolated / current / custom
- isolated session 可独立运行，不影响主会话
- `--announce --channel telegram` 可自动推送结果到 Telegram
- `--light-context` 跳过 workspace bootstrap 注入
- 配置持久化在 `~/.openclaw/cron/jobs.json`
- Gateway 重启后自动恢复

### OpenClaw Heartbeat 系统

- 周期性 agent turn，适合例行巡检
- HEARTBEAT.md 为空 = 跳过心跳 API 调用（不消耗 token）
- 支持 `tasks:` 块定义按间隔区分的检查项
- 只有到期任务被注入 prompt
- 不延长 session freshness

### OpenClaw Standing Orders

- 永久操作权限，定义 scope / triggers / approval gates / escalation rules
- 写在 workspace 文件中
- 可用于定义 GTD 自动化权限边界

### Todoist CLI 现状

- **`td` v1.57.0**（Doist 官方 @doist/todoist-cli）：已认证，正常工作
- **`todoist` v0.2.0**（旧版非官方）：仍存在于 `/usr/bin/todoist`，exit code 3，不再使用
- todoist-cli skill 使用 `td` 命令，位于 `~/.agents/skills/todoist-cli/SKILL.md`
- 关键 `td` 命令：
  - `td today` / `td inbox` / `td project list` — 查看
  - `td task quickadd "..."` — 快速添加（自然语言）
  - `td task add "..." --project "..." --labels "..."` — 结构化添加
  - `td task complete "..."` — 完成
  - `td task move "..." --project "..."` — 移动
  - `td label create/list` — 标签管理
  - `td filter create/list` — 过滤器管理

### GTD 方法论核心（David Allen 标准版）

- 5 大步骤：Capture → Clarify → Organize → Engage → Reflect
- Clarify 5 步决策树：可行动？→ <2min？→ 多步？→ 归位 → 标签+优先级
- 7 个归位"家"：Next Actions / Projects / Calendar / Someday / Waiting For / Horizons / Done
- Horizons of Focus：天 → 周 → 长期目标，通过 Weekly Review 对齐
- Natural Planning Model：5 步拆解大项目（目的 → 愿景 → 头脑风暴 → 组织 → Next Action）
- 执行时用 Filter（@情境标签），不直接翻 Project
- 未完成 ≠ 失败，是"系统提醒我重新决策"

## 新发现（2026-05-03）：GTD 部署方案安全审查结论

### 审查对象
- `deploy_tmp/gtd-deployment-plan.md`
- 目标运行时：远端 Ubuntu `100.64.65.65` 的 main OpenClaw workspace
- 本轮只读审查，未部署、未写远端配置、未新增 cron。

### 官方/现场依据
- GTD 官方方法论：确认 GTD 的核心执行循环为 Capture / Clarify / Organize / Reflect / Engage，Weekly Review 采用 Get Clear / Get Current / Get Creative。
- Todoist 官方 GTD 指南：Todoist 适合用 Inbox、Projects、labels、filters 来承载 GTD，但需要先建好执行视图、标签和归位结构。
- Doist `td` CLI 现场版本：`td 1.57.0`，已认证；`td doctor` 仅提示 stable 可更新到 `1.60.3`。
- OpenClaw 现场版本：`OpenClaw 2026.5.2`，`openclaw config validate` 通过，`gateway health ok=true`。
- `openclaw skills list` 已显示 `todoist-cli` 为 ready，来源 `agents-skills-personal`。
- 当前 Todoist label 为空；当前 filter 仅为默认过滤器；当前 project 中没有显式 `Someday` / `Horizons`。

### 阻断/高风险问题
1. cron 触发的 isolated agent turn 不能可靠承担"等待用户审批后继续执行"的长期状态机；审批方案需要持久化到 workspace 文件或改用明确的后续触发词读取最新 pending proposal。
2. cron add 命令缺少 `--to 8226087994`、`--agent main`、较长 `--timeout-seconds`，存在消息投递失败/投递到错误目标/长任务超时风险。
3. 周日 `13:00` 同时安排 Inbox triage 和 Weekly Review reminder，两个 isolated job 可能并发，不能保证"Inbox 处理完后再提醒周回顾"。
4. 部署方案使用任务标题 `"X"` 做 mutating command 引用；重复任务名时可能移动、删除或完成错误任务，应使用 `id:<id>` 或 Todoist URL。
5. 多条 `td` 命令与现场 CLI 帮助不匹配：
   - `td task quickadd "X" --project "Y"` 无效；quickadd 只支持自然语言文本/`--stdin`/`--json`/`--dry-run`。
   - `td task move "X" --label Someday` 无效；`task move` 只支持 project/section/parent。
   - `td task update --labels` 会替换现有标签，不能直接当作"追加标签"使用。
6. 方案把 Todoist 初始化排除在部署外，但 skills 立即依赖 `@next`、情境标签、`waiting`、`Someday`、`Horizons` 和 filters；当前现场这些结构未就绪。

### 通过项
- AGENTS.md GTD 框架总体符合 GTD 五步与 Todoist 执行逻辑。
- workspace skill 目录和 `metadata.openclaw.requires.bins=["td"]` 的方向与 OpenClaw skills 机制匹配。
- 字符预算在当前 workspace 规模下可接受。
- `todoist-cli` skill 已 ready，`td` 已认证，底座工具可用。

### 建议修正方向
- 部署前增加 GTD scaffold preflight：创建/验证 labels、filters、Someday/Horizons 承载方式，并做 `td ... --dry-run` 级别的命令校验。
- 把 cron job 设计改为"生成 proposal + 写入 pending 文件 + announce"，用户确认时由主会话读取 pending 文件并执行。
- 所有批量执行命令使用 `id:<id>`，执行前显示任务标题给用户确认。
- cron 命令显式带 `--agent main --to 8226087994 --account main-bot --timeout-seconds 900 --best-effort-deliver`，并错开 Weekly reminder 时间。

## 新发现（2026-05-03）：GTD 系统最终部署采用 reminder-only cron + 主 session 执行

### 最终架构修正
- 用户明确说明：GTD Clarify / Review 过程中会和小龙虾讨论，而不是简单审批。
- 因此最终架构从“isolated cron 直接生成 triage/review 方案”改为：
  - cron 只提醒
  - 用户在 Telegram 主会话主动说“开始整理 Inbox / 每日总结 / 开始 Weekly Review”
  - 小龙虾在主 session 里调用对应 skill，与用户讨论并确认后执行
- 这样避免 isolated session 持有审批上下文，也更符合 GTD 中 Clarify 需要人参与的原则。

### Todoist scaffold
- 已创建 Project：
  - `🗂 Someday / Maybe`
  - `🌅 Horizons`
- 已创建 labels：
  - `next`
  - `waiting`
  - `电脑`
  - `家`
  - `外出`
  - `电话`
  - `深度工作`
  - `2min`
- 已创建 GTD filters：
  - `GTD - Next Actions`：`@next & !@waiting`
  - `GTD - Waiting For`：`@waiting`
  - `GTD - Today Focus`：`today | overdue | p1`
  - `GTD - Quick Wins`：`@2min | (p1 & today)`
  - `GTD - Deep Work`：`@深度工作 & @next`
  - `GTD - Context Computer`：`@电脑 & @next`
  - `GTD - Context Home`：`@家 & @next`
  - `GTD - Context Outside`：`@外出 & @next`
  - `GTD - Context Phone`：`@电话 & @next`
- 已删除旧失效 filter：
  - `1`，旧 query 为 `#Next Actions & !@Someday & !@waiting`，现场没有 `Next Actions` project 且命名不符合最终 scaffold。

### 初始 Inbox 归位
- 部署前 Todoist 备份：
  - `/home/kevinlasnh/.openclaw-backups/todoist-gtd-before-20260503-215522`
- 部署后快照：
  - `/home/kevinlasnh/.openclaw-backups/todoist-gtd-after-20260503-220244`
- 初始 Inbox 从 8 条清到 0 条。
- 本轮没有删除任何任务，只做了保守移动、标题清理、初始 label / priority 归位。

### OpenClaw workspace
- 已使用 `skill-creator` 初始化并部署 3 个 workspace skills：
  - `~/.openclaw/workspace/skills/gtd-inbox-triage/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-daily-review/SKILL.md`
  - `~/.openclaw/workspace/skills/gtd-weekly-review/SKILL.md`
- 已更新：
  - `~/.openclaw/workspace/AGENTS.md`
- 远端备份：
  - `~/.openclaw/workspace/AGENTS.md.pre-gtd-20260503-2159`
- AGENTS.md 已记录：
  - cron 只提醒
  - 主 session 执行
  - mutating command 必须用 `id:<task_id>` 或 URL
  - `td task update --labels` 会替换全部标签，更新前必须合并现有标签

### Cron
- 已新增 5 个 reminder-only cron：
  - `gtd-inbox-reminder-0900`
  - `gtd-inbox-reminder-1300`
  - `gtd-inbox-reminder-1900`
  - `gtd-daily-review-reminder-2200`
  - `gtd-weekly-review-reminder-sun-1315`
- 这些 cron 全部：
  - `sessionTarget = isolated`
  - `agentId = main`
  - `delivery = announce -> telegram:8226087994`
  - `accountId = main-bot`
  - `bestEffort = true`
  - `staggerMs = 0`
  - `timeoutSeconds = 120`

### 验收
- `openclaw skills list` 显示 3 个 GTD skill ready。
- 主 Agent 不投递 smoke test 返回：
  - `GTD_SKILLS_READY_OK`
- `openclaw config validate` 通过。
- `openclaw gateway health --json` 返回：
  - `ok = true`
  - Telegram connected = true
- `openclaw cron status --json`：
  - `jobs = 8`
  - `runningAtMs = null`
  - GTD cron 无 consecutive errors。

### Session 刷新注意
- 本轮部署没有强制清空或重建既有主 Telegram session。
- 新 agent turn 的 smoke test 已证明新版 workspace 和 GTD skills 可被新 turn 注入。
- 若用户在旧 Telegram 主会话中感觉仍沿用旧上下文，优先由用户手动刷新/开启新会话验证；未经用户明确要求，不自动删除 session 文件或清理 lock。

## 新发现（2026-05-04）：GTD 9:00 reminder 首次触发成功但 Telegram 投递瞬断

### 现场表现
- 当前时间检查：`2026-05-04T09:10:38+08:00`
- `gtd-inbox-reminder-0900` 已触发，不是未触发。
- 原始定时运行：
  - `runAtMs = 1777856400012`（2026-05-04 09:00:00.012 +08:00）
  - `status = ok`
  - `delivered = false`
  - `deliveryStatus = not-delivered`
- 日志对应错误：
  - `2026-05-04T09:00:12.486+08:00 [telegram] message failed: Network request for 'sendMessage' failed!`
  - `[cron:46c6e47f-e759-450f-a9c8-b659a0661e2c] delivery payload failed (bestEffort): Network request for 'sendMessage' failed!`

### 后续状态
- 同一个 job 之后又有一次运行：
  - `runAtMs = 1777856894762`（2026-05-04 09:08:14.762 +08:00）
  - `status = ok`
  - `delivered = true`
  - `deliveryStatus = delivered`
- 当前 `openclaw cron show 46c6...` 因最后一次运行成功，显示：
  - `lastDelivered = true`
  - `lastDeliveryStatus = delivered`
  - `consecutiveErrors = 0`
- 09:06 之后 Telegram 日志持续出现 `sendMessage ok`。
- 当前 Telegram health：
  - `running = true`
  - `connected = true`
  - `lastError = null`
- 当前代理探测：
  - `127.0.0.1:7897` 到 `generate_204` 返回 204
  - 通过代理访问 `https://api.telegram.org` 返回 302

### 判断
- 根因不是 cron 没触发，也不是 GTD job 配置错误。
- 09:00 失败点是 Telegram `sendMessage` 网络请求瞬断；OpenClaw 因 `bestEffort=true` 将 job 本体记录为 `ok`，但该次投递为 `not-delivered`。
- 09:08 后的同 job 运行已投递成功，说明链路已恢复。

## 新发现（2026-05-05）：GTD 9:00 reminder 连续两天失败均落在 Telegram 代理链路瞬断

### 现场表现
- `gtd-inbox-reminder-0900` job id 仍为：
  - `46c6e47f-e759-450f-a9c8-b659a0661e2c`
- 今日 `2026-05-05` 9 点运行不是未触发：
  - cron isolated session：`agent:main:cron:46c6e47f-e759-450f-a9c8-b659a0661e2c:run:62485b80-0582-4017-bf3a-d8540d03a46f`
  - session start：`2026-05-05T09:00:01.664+08:00`
  - model completed：`2026-05-05T09:00:06.699+08:00`
  - assistant text 正确生成：
    - `🐰 早上好！Inbox 在等你清理哦～回复「开始整理 Inbox」，我们一起来看看有什么待办，顺便挑今天最多 3 个 MIT 吧！`
- 投递失败发生在 Telegram 出站层：
  - `2026-05-05T09:00:11.801+08:00 [telegram] message failed: Network request for 'sendMessage' failed!`
  - `[cron:46c6e47f-e759-450f-a9c8-b659a0661e2c] delivery payload failed (bestEffort): Network request for 'sendMessage' failed!`
  - `2026-05-05T09:00:16.782+08:00 [fetch-timeout] fetch timeout after 3304ms ... getWebhookInfo`

### 代理层证据
- Mihomo 同一时间窗口明确记录 Telegram 规则命中 `telegram-jp-tw-stable`，但节点建连失败：
  - `2026-05-05T09:00:11.778+08:00 ... telegram-jp-tw-stable[专线2.5x-台湾1-GPT] ... api.telegram.org:443 error: failed to create session: dial tcp 112.90.88.2:30021: i/o timeout`
  - `2026-05-05T09:00:11.794+08:00 ... i/o timeout`
  - `2026-05-05T09:00:18.475+08:00 ... context deadline exceeded`
- 之后链路恢复：
  - `2026-05-05T09:00:44` / `09:00:54` 后 Telegram 连接重新建立
  - Gateway `09:00:55` 开始重新出现 `sendMessage ok`
  - 09:02 同 job 重跑成功投递

### 状态解释
- `openclaw cron list --json` 当前显示 `gtd-inbox-reminder-0900`：
  - `lastRunAt = 2026-05-05 09:02:05`
  - `lastDelivered = true`
  - `lastDeliveryStatus = delivered`
- 这是因为后续重跑成功覆盖了 09:00 原始失败状态。
- 排查 9 点准点投递问题时，必须看：
  - `journalctl --user -u openclaw-gateway --since 'YYYY-MM-DD 08:58' --until 'YYYY-MM-DD 09:03'`
  - 对应 cron isolated trajectory
  - `journalctl --user -u mihomo-standalone` 同窗口日志

### 工程结论
- GTD cron 配置本身正确；模型也生成了正确提醒文本。
- 连续两天 9 点问题的共同根因是 Telegram Bot API 出站链路短时不可用。
- `bestEffort=true` 会让 OpenClaw 将 job 本体视作 `ok`，投递失败只记录为 delivery failure，不会自动重试，也不会留下 `consecutiveErrors`。
- 当前 `cron add/edit` 暴露了 `--best-effort-deliver` / `--no-best-effort-deliver` 与 failure alert 配置，但未看到可直接配置的 delivery retry 选项。
- 后续若要提升可靠性，应在两类方向中选：
  1. 改投递语义：取消 `bestEffort` 并配置 failure alert，让失败显性化。
  2. 增加补偿机制：对关键 reminder 增加延迟重试/补发层，避免 Telegram 代理节点瞬断导致准点提醒永久丢失。

## 新发现（2026-05-05）：GTD 核心 Markdown / Skill 审计边界与初步结论

### 本轮边界
- 用户明确收窄：不审查 Todoist 真实任务数据，只审查小龙虾 workspace 中的 GTD 核心 Agent Markdown、Todoist scaffold 说明和 GTD Skill 逻辑。
- 本轮未修改远端配置、未修改 Todoist，只读检查远端 Markdown 与 Skill 文件。

### 官方 GTD 对照基线
- GTD 核心工作流应覆盖：Capture / Clarify / Organize / Reflect / Engage。
- Weekly Review 应覆盖：Get Clear / Get Current / Get Creative。
- Natural Planning Model 应作为独立项目规划入口，典型步骤为：Purpose and Principles / Outcome Visioning / Brainstorming / Organizing / Next Actions。

### 远端 Markdown 初步结论
- `~/.openclaw/workspace/AGENTS.md` 的 GTD 主逻辑整体方向正确：
  - cron 只提醒，不自动整理；
  - 主 Telegram 会话讨论确认后执行；
  - mutating command 必须使用 `id:<task_id>` 或 URL；
  - 明确了 Inbox、Clarify、Next Action、Project、Someday/Maybe、Waiting For、Weekly Review、Calendar Hard Landscape、Reference、Horizons。
- 明确缺口：
  - 没有 Natural Planning Model 触发词和 Skill 路由；
  - 没有把复杂目标/多步项目进入 Natural Planning 的规则写进核心 Agent 逻辑；
  - `gtd-inbox-triage` / `gtd-daily-review` / `gtd-weekly-review` 与 `AGENTS.md` scaffold 存在命名漂移。
- 命名漂移：
  - `AGENTS.md` 的 scaffold 使用 `@Next Action`、`@Waiting For`、`@Focus` 等新版英文标签；
  - `gtd-inbox-triage` 仍写旧标签 `next`、`waiting`、`电脑`、`家`、`外出`、`电话`、`深度工作`、`2min`；
  - `gtd-weekly-review` 仍用 `next` / `waiting`；
  - 三个 Skill 仍引用旧项目名 `🗂 Someday / Maybe`、`🌅 Horizons`，而核心命名规范要求 `emoji + kebab-case-english`，应统一为 scaffold 的实际命名口径。

### 已落地修复（2026-05-05 09:29-09:35 +08:00）
- 备份目录：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-skill-logic-fix-20260505-092939`
- `AGENTS.md`：
  - 增加 `gtd-natural-planning` 触发词路由。
  - 增加复杂目标 / 新项目 / 模糊多步成果 / 卡住项目先走 Natural Planning 的规则。
  - scaffold 项目名统一为 `🗂 someday-maybe` 与 `🌅 horizons`。
- `gtd-inbox-triage`：
  - 标签统一为新版英文 GTD labels。
  - 增加 Reference 判断、Hard Landscape 日期判断、复杂项目转 Natural Planning。
- `gtd-daily-review`：
  - 增加 Hard Landscape、Reference、Natural Planning 分流。
  - Someday 项目名统一为 `🗂 someday-maybe`。
- `gtd-weekly-review`：
  - `next/waiting` 统一为 `Next Action` / `Waiting For`。
  - 项目名统一为 `🗂 someday-maybe` / `🌅 horizons`。
  - Project Health 增加卡住项目转 Natural Planning。
- 新增 `gtd-natural-planning`：
  - 使用 skill-creator 初始化并通过 quick validate。
  - YAML frontmatter 仅保留 `name` 和 `description`。
  - 工作流覆盖 Purpose & Principles / Outcome Visioning / Brainstorming / Organizing / Next Actions。
  - 默认先产出 proposal，确认后才执行 Todoist mutation。

### 验收结果
- `openclaw config validate` 通过。
- 旧具体命名残留检查通过：
  - 无 `🗂 Someday / Maybe`
  - 无 `🌅 Horizons`
  - 无旧标签命令 `next/waiting/电脑/深度工作/2min`
- `openclaw skills list --agent main --json` 显示四个 GTD Skill 均：
  - `eligible=true`
  - `modelVisible=true`
  - `commandVisible=true`
  - `source=openclaw-workspace`
- 重启 main Gateway 后：
  - service `active/running`
  - `gateway health ok=true`
  - Telegram `running=true / lastError=null`
  - 不投递 smoke test 返回 `GTD_NATURAL_PLANNING_READY_OK`
  - 短窗口内 `eventLoop.degraded=true`，但 `ok=true` 且实呼成功，判断为重启/实呼附近 CPU 采样噪声，非阻断问题。

## 新发现（2026-05-05）：GTD harness 二次全量审计补强点

### 审计结论
- 第一轮修复后，Skill 可见性、cron reminder-only 架构、命名漂移均已解决。
- 二次审计发现仍有 4 个逻辑薄点：
  1. `AGENTS.md` 没有显式写 GTD Clarify 的 Do / Delegate / Defer / Project / Reference 决策树。
  2. `AGENTS.md` 对 Engage 的执行选择只写了 `td today`，缺少 context / time / energy / priority 四因素。
  3. `gtd-daily-review` 的示例里仍有 `reschedule tomorrow`，容易诱导软日期滥用。
  4. `gtd-weekly-review` 只检查项目，缺少对 Next Actions / context lists 的独立回顾。

### 已落地修复
- 备份目录：
  - `/home/kevinlasnh/.openclaw-backups/main-gtd-harness-audit-fix-20260505-094154`
- `AGENTS.md`：
  - 增加 `Clarify 决策树`。
  - 增加 `Engage 执行选择`，使用 context、time available、energy available、priority。
  - `今天做什么` 路由改为查看 Today Focus / Next Actions / context filters 后给最多 3 个建议。
- `gtd-inbox-triage`：
  - 增加 agent 可代办 2 分钟动作 vs 用户现实动作的区分。
  - 增加 Waiting For 的 who / what / follow-up 要求。
  - Proposal 增加 Clarify 分类和 rationale。
- `gtd-daily-review`：
  - 去掉 `tomorrow` 软日期示例，改为硬日期示例。
  - 收尾建议使用 Engage criteria。
  - 标签更新示例改成保留既有标签的合并口径。
- `gtd-weekly-review`：
  - 增加 Next Actions / Focus / Quick Wins 清单回顾。
  - 明确 review action system itself，不只 review projects。
  - Next Week Preview 增加低/中/高精力的 context-specific options。
- `gtd-natural-planning`：
  - 增加 `td task update --labels` 需要先读并合并既有标签。
  - Waiting For 项目必须带 who / what / follow-up context。

### 最终验收
- `openclaw config validate` 通过。
- 四个 GTD Skill 均为：
  - `eligible=true`
  - `modelVisible=true`
  - `commandVisible=true`
- 五个 GTD cron 仍保持：
  - `isolated + announce`
  - `telegram:8226087994`
  - `thinking=off`
  - `lightContext=true`
  - `toolsAllow=read`
  - `timeoutSeconds=600`
- main Gateway 已重启，PID `2196131`。
- `gateway health ok=true`，Telegram `running=true / lastError=null`。
- 无 main session lock 输出。
- 不投递 smoke test 返回 `GTD_HARNESS_AUDIT_OK`。
- 重启后 `eventLoop.degraded=true` 仍出现，但 `ok=true`、无插件错误、无 Telegram 错误、实呼成功；当前作为短窗口 CPU/event loop 采样噪声记录，非阻断。

## 新发现（2026-05-05）：春燕“小龙虾死了”的真实故障层是 Feishu 插件 install record 缺失

### 现象
- `openclaw-gateway-chunyan` 进程可保持 `active/running`，`openclaw config validate` 也可通过。
- `chunyan/chunyan` agent 不投递实呼能跑通，说明模型链路不一定有问题。
- 但用户从飞书侧看仍会像“小龙虾死了”，因为 Feishu 通道没有注册：
  - `gateway health --json` 中 `channels={}`、`channelOrder=[]`
  - `channels status --probe --json` 中 `channels={}`、`channelAccounts={}`
  - 日志或工具调用会出现 `Channel is unavailable: feishu`

### 根因
- `~/.openclaw-chunyan/plugins/installs.json` 缺少 `feishu` install record。
- 磁盘上残留 `@openclaw/feishu` 包并不等于运行时会加载；OpenClaw 2026.5.3 的插件 registry 需要 install record / policy 将 state-local npm 插件纳入发现。
- 典型诊断证据：
  - `openclaw plugins inspect feishu` 返回 `Plugin not found: feishu`
  - `openclaw plugins list` 报 `plugins.entries.feishu: plugin not found: feishu`
  - 对比工作实例 `dayong`，其 `plugins/installs.json` 里有 `feishu` install record，且 `channels.feishu` 正常注册。

### 修复方法
- 备份实例配置和插件 registry 后，用 OpenClaw 官方安装入口重建 install record：
  - `OPENCLAW_STATE_DIR=$HOME/.openclaw-chunyan OPENCLAW_CONFIG_PATH=$HOME/.openclaw-chunyan/openclaw.json openclaw plugins install --force --pin --dangerously-force-unsafe-install @openclaw/feishu@2026.5.3`
- `--dangerously-force-unsafe-install` 在这里用于官方 Feishu 插件：该插件读取 app secret 并向飞书 API 发请求，会命中通用危险代码扫描；不是安装未知第三方插件。
- 建议同时收敛插件策略：
  - `plugins.allow = ["feishu","zai","minimax"]`
  - 删除 disabled 且 stale 的 `plugins.entries.brave`
- 只需重启受影响实例：
  - `systemctl --user restart openclaw-gateway-chunyan`

### 验收标准
- `openclaw plugins inspect feishu`：
  - `Status: loaded`
  - `Source: ~/.openclaw-chunyan/npm/node_modules/@openclaw/feishu/dist/index.js`
  - `Version: 2026.5.3`
- `gateway health --json`：
  - `ok=true`
  - `channels.feishu.running=true`
  - `channels.feishu.lastError=null`
  - `channelOrder=["feishu"]`
- `channels status --probe --json`：
  - `probe.ok=true`
  - `botName=chunyan`
- 日志出现：
  - `WebSocket client started`
  - `ws client ready`
- 最后跑不投递 agent smoke test，确认模型链路仍返回预期文本。
## 新发现（2026-06-08）：OpenClaw 2026.6.1 + Feishu 外部插件 2026.5.3 会出现入站派发失败

- 现象：春艳从 Feishu 私聊发消息后，小龙虾不回复，看起来像“死了”。
- 反证：
  - `openclaw-gateway-chunyan` service `active/running`，`NRestarts=0`。
  - `openclaw config validate` 通过。
  - `gateway health ok=true`。
  - `channels status --probe` 显示 Feishu `works`。
  - Feishu WebSocket 日志显示 `WebSocket client started` 与 `ws client ready`。
  - CLI 不投递 smoke 中，`chunyan` 和 `dzxy` 均可通过 `zzedu/gpt-5.5` 返回正确 token。
- 关键证据：
  - 日志显示 Feishu 入站确实收到春艳消息：
    - `feishu[chunyan-feishu]: received message ... (p2p)`
    - `dispatching to agent (session=agent:chunyan:feishu:chunyan-feishu:direct:...)`
  - 随后派发失败：
    - `failed to dispatch message: TypeError: Cannot read properties of undefined (reading 'run')`
- 版本线索：
  - OpenClaw core 已升级到 `2026.6.1 (2e08f0f)`。
  - live `dayong` / `chunyan` / `zenglan` 仍加载外部 `@openclaw/feishu@2026.5.3`。
  - npm registry 的 `@openclaw/feishu` latest 为 `2026.6.1`。
- 判断：
  - `channels status --probe` 只能证明 Feishu app/凭证/API 可用，不能证明真人入站事件能成功派发给 agent。
  - 这类问题要看日志中的 `received message` -> `dispatching to agent` -> `failed to dispatch message` 链路。
  - 根因优先判断为 Feishu 外部插件版本落后于 core，导致 2026.6.1 入站派发 API/runner 兼容性破裂。
- 建议修复路径：
  1. 先备份 `~/.openclaw-dayong` / `~/.openclaw-chunyan` / `~/.openclaw-zenglan` 的 `openclaw.json`、`.env`、插件目录和 `plugins` 相关状态。
  2. 对三个 Feishu Gateway 执行 `openclaw plugins install --force --pin --dangerously-force-unsafe-install @openclaw/feishu@2026.6.1`。
  3. 重启 `openclaw-gateway-dayong` / `openclaw-gateway-chunyan` / `openclaw-gateway-zenglan`。
  4. 验收 `config validate`、`plugins inspect feishu`、`gateway health --json`、`channels status --probe`、session locks、近期 Feishu 入站派发日志和不投递 smoke。

## 新发现（2026-06-08）：Feishu 直聊刷新后还要清理旧子会话，避免状态视图继续显示 GLM 5

### 现场结论
- 春艳 Feishu 入站派发问题修复后，正确直聊 key 已刷新为：
  - `agent:chunyan:feishu:chunyan-feishu:direct:ou_e4c865918d1b26e9ff11a09034e08970`
  - sessionId: `59f6636c-6398-49ee-a661-d737d4479746`
  - `modelProvider=zzedu`
  - `model=gpt-5.5`
- 但 `~/.openclaw-chunyan/agents/chunyan/sessions/sessions.json` 中仍可能残留由同一个 Feishu 直聊触发的历史 subagent sessions。
- 这些旧 subagent entries 的 `spawnedBy` / `deliveryContext` / `lastTo` 仍指向同一个 Feishu 用户，且模型字段可能仍是：
  - `zai/glm-5`
  - `minimax/MiniMax-M2.5`
- 这些旧子会话不一定影响当前直聊派发，但会让 session/status/history 视图继续暴露旧模型，用户会误以为当前聊天仍在用 GLM 5。

### 修复方法
- 不要只删当前 direct session；要按目标 Feishu open_id 检查所有相关 session entries：
  - key 包含目标 open_id
  - 或 entry JSON 中包含目标 open_id
  - 或 `spawnedBy` 指向当前 direct session key
- 只归档满足以下条件的旧条目：
  - 不是当前 direct session key
  - 且 `modelProvider != zzedu`，或 `model/systemPromptReport` 中含 `glm` / `minimax`
- 操作前必须备份：
  - `sessions.json`
  - 对应 `sessionFile` jsonl
- 本轮归档目录：
  - `/home/kevinlasnh/.openclaw-backups/chunyan-stale-glm-session-purge-20260608-195630`
- 本轮归档结果：
  - 旧 `zai/glm-5` / `MiniMax-M2.5` 子会话 43 个。
  - 旧 session jsonl 文件 43 个。
  - 清理后与该 Feishu 用户相关的 session entries 只剩当前 `zzedu/gpt-5.5` direct session。

### 验收标准
- `sessions.json` 中按目标 Feishu open_id 检索：
  - `relatedCount = 1`
  - `staleRelatedCount = 0`
  - 唯一剩余条目为当前 direct key。
- 当前 direct session 应显示：
  - `modelProvider=zzedu`
  - `model=gpt-5.5`
  - `systemPromptProvider=zzedu`
  - `systemPromptModel=gpt-5.5`
- 重启 `openclaw-gateway-chunyan` 后验证：
  - service `active/running`
  - `NRestarts=0`
  - `gateway health ok=true`
  - Feishu `running=true / lastError=null`
  - `channels status --probe` 成功
  - session lock 为空
- 真人聊天验收不能只看 probe；必须看到真实 Feishu 入站日志：
  - `received message`
  - `dispatching to agent`
  - `dispatch complete (queuedFinal=true, replies=1)`
- 本轮重启后已用春艳真人回复验证两次：
  - 19:58 入站最终 20:00:47 `dispatch complete`
  - 20:00:47 入站最终 20:00:53 `dispatch complete`

### 注意
- `openclaw agent --thinking xhigh` 在 CLI 层会被拒绝，错误为：
  - `Thinking level "xhigh" is not supported for zzedu/gpt-5.5`
- 配置里的 `thinkingDefault=xhigh` 可保留；CLI 验证时不要用 `--thinking xhigh` 覆盖，使用默认值或 `--thinking high`。
