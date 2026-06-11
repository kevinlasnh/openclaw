# OpenClaw 项目规则

## 项目定位

本仓库是 **kevinlasnh、Claude（我）和小龙虾（OpenClaw）** 三方协作的工作空间。

- **Claude（我）和小龙虾**：共同维护这个仓库，记录配置变更、报错处理、故障排查
- **kevinlasnh**：用户，通过 WhatsApp 与小龙虾对话，我和小龙虾协作帮他解决问题

## 工作模式

### 1. 小龙虾自诊断
当小龙虾遇到报错或异常时，它会自动：
- 检查自己的日志 (`journalctl --user -u openclaw-gateway`)
- 分析配置文件 (`~/.openclaw/openclaw.json`)
- 将发现的问题和解决方案记录到本仓库的 `progress.md` 和 `findings.md`

### 2. Claude（我）的角色
- **直接访问 WSL 文件**：通过 `\\wsl$\Ubuntu\` 路径直接读取/修改小龙虾配置，无需脚本中转
- **协同诊断**：当 kevinlasnh 报告问题时，我检查小龙虾状态，分析日志，定位问题
- **文档维护**：每次配置变更或问题解决后，更新 `progress.md`、`findings.md`、`task_plan.md`
- **知识沉淀**：将新发现的问题、解决方案、配置技巧记录到文档中

### 3. 沟通原则
- **教学优先**：向 kevinlasnh 解释问题和解决方案，让他理解每一步操作
- **直接操作**：我有权限直接修改配置，无需让 kevinlasnh 手动执行（除非他要求）
- **透明记录**：所有操作和变更都记录在文档中，方便三方追溯

## 术语

- **小龙虾 = OpenClaw**：对话和文档中，"小龙虾"即指 OpenClaw，二者等价
- **主号码**：`+8618860901660`（小龙虾绑定的 WhatsApp 号码）
- **用户号码**：`+8615817413681`（kevinlasnh 用来与小龙虾对话的号码）

## 前置检查规则

在任何小龙虾相关操作之前，Agent 必须先读取以下项目文件：

- `findings.md`：配置方法、命令参考、架构知识、已知的报错和解决方案
- `progress.md`：当前进度、已完成步骤、历史错误记录
- `AGENTS.md` / `CLAUDE.md`：仓库项目规则和工作模式

**确保每一步指导都基于已沉淀的知识，而非凭记忆或猜测。**

## 项目级规则文件同步

- 仓库根目录的 `AGENTS.md` 与 `CLAUDE.md` 是同一份项目规则的两个入口，必须保持完全内容一致。
- 修改其中任一文件时，必须立即将修改后的完整内容同步到另一个文件；不得只改一个文件。
- 同步时不做标题、章节或措辞差异化；两个文件包括 H1、章节顺序和正文内容都应相同。
- 为避免破坏一致性，正文中不要用“本文件”指代某个单独文件；统一写 `AGENTS.md` / `CLAUDE.md`。

## 标准巡检惯例

当用户要求检查 Linux 服务器、小龙虾状态、Tailscale、代理、cron、Telegram/Feishu 通道、资源压力或类似“日常维护状态”时，优先使用本仓库标准巡检资料：

- `.agents/skills/openclaw-server-health/SKILL.md`：项目级巡检 Skill，封装触发场景、只读边界、执行入口和判读顺序
- `SERVER_HEALTH_CHECKS.md`：远程 Ubuntu `100.64.65.65` 的分层巡检 runbook
- `server_health_check.sh`：只读巡检脚本，不会重启、禁用、删除或修改远程对象

支持项目级 Skill 的宿主下，遇到“检查服务器 / 检查小龙虾 / 检查代理 / 检查 5 秒健康轮询 / OpenClaw 健康巡检”等请求时，优先加载 `openclaw-server-health` Skill。

从 Windows PowerShell 通过 SSH 执行脚本时使用：

```powershell
Get-Content -Raw -Encoding UTF8 server_health_check.sh | ssh kevinlasnh@100.64.65.65 "tr -d '\r' | bash -s"
```

也可以使用 Skill 自带 wrapper：

```powershell
.\.agents\skills\openclaw-server-health\scripts\run-openclaw-server-health.ps1
```

判断小龙虾健康时禁止只看 `systemctl --user is-active openclaw-gateway`。至少同时检查：

- Tailscale / SSH / `openclaw-sshd-2222`
- Tailscale Funnel `443 -> 8787`、`8443 -> 8788`
- Mihomo `127.0.0.1:7897` 与 `generate_204` 探测
- 四个 Gateway 的 `config validate` / `gateway health`
- Telegram webhook / Feishu probe
- `*.jsonl.lock`、`stuck session`
- `openclaw cron status/list`
- 最近日志中的 provider 429、插件加载错误、Vulkan OOM、`sendMessage failed`

## 当前配置摘要

| 配置项 | 值 |
|--------|-----|
| Gateway 版本 | OpenClaw 2026.5.3 |
| 主模型 | xiaomi-mimo/mimo-v2.5-pro |
| 备用模型 | deepseek/deepseek-v4-pro |
| 图片理解模型 | xiaomi-mimo/mimo-v2.5 |
| Web Search | provider: brave（BRAVE_API_KEY 在 env 中；需安装启用 `@openclaw/brave-plugin`，当前插件版本 2026.5.3） |
| 消息通道 | Telegram（唯一） |
| Telegram Bot | @OpenClaw_kevinlasnh_no1_bot |
| Telegram User ID | 8226087994 |
| WhatsApp | 已禁用（Phase 24 移除） |
| 代理 | 当前 `openclaw-gateway` 进程环境带 `HTTP_PROXY/HTTPS_PROXY=http://127.0.0.1:7897` |
| Xiaomi MiMo API | main 已通过 systemd drop-in 设置 `NO_PROXY/no_proxy`，`token-plan-cn.xiaomimimo.com` 走直连 |
| DeepSeek API | 作为 fallback，DeepSeek 域名仍走直连 |
| gateway.bind | loopback |
| boot-md | 已启用 |
| commands.restart | true |
| NODE_OPTIONS | 已从 systemd 删除 |
| 当前安装树补丁 | Telegram verbose 工具进度 hot patch 与 web provider runtime-empty fallback hot patch 已重打在 2026.5.3 安装树内，升级后需复查 |

### Xiaomi MiMo / DeepSeek 与代理策略

当前现场结论：

- `openclaw-gateway.service` 的 systemd 环境中存在：
  - `HTTP_PROXY=http://127.0.0.1:7897`
  - `HTTPS_PROXY=http://127.0.0.1:7897`
- `main` 进程实际也继承了上述代理变量。
- main 当前额外通过 drop-in 设置：
  - 文件：`~/.config/systemd/user/openclaw-gateway.service.d/10-deepseek-no-proxy.conf`
  - `NO_PROXY=token-plan-cn.xiaomimimo.com,.xiaomimimo.com,api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
  - `no_proxy=token-plan-cn.xiaomimimo.com,.xiaomimimo.com,api.deepseek.com,.deepseek.com,localhost,127.0.0.1,::1`
- OpenClaw 2026.5.2 安装树里存在 `EnvHttpProxyAgent` / `NO_PROXY` 相关代码，网络层支持按环境变量走代理并按 `NO_PROXY` 绕过。
- `main` 当前文本模型配置：
  - `agents.defaults.model.primary = xiaomi-mimo/mimo-v2.5-pro`
  - `agents.defaults.model.fallbacks = [deepseek/deepseek-v4-pro]`
  - `models.providers.xiaomi-mimo.api = anthropic-messages`
  - `models.providers.xiaomi-mimo.baseUrl = https://token-plan-cn.xiaomimimo.com/anthropic`
- `main` 当前图片理解模型配置：
  - `agents.defaults.imageModel.primary = xiaomi-mimo/mimo-v2.5`
  - `agents.defaults.imageModel.fallbacks = []`
  - `mimo-v2.5` 和 `mimo-v2-omni` 带图实测都能识别图片
  - `mimo-v2.5-pro` 与 `mimo-v2-pro` 带图请求 HTTP 200，但模型回复未看到图片，不适合作为 imageModel
- 远端 Ubuntu 实测：
  - Xiaomi MiMo V2.5 Pro 文本直连 `/v1/messages` 返回 HTTP 200，模型为 `mimo-v2.5-pro`
  - Xiaomi MiMo V2.5 带图直连 `/v1/messages` 返回 HTTP 200，并能正确识别纯色 PNG
  - Xiaomi 直连约 `2.7s`，经 `127.0.0.1:7897` 约 `5.8s`，当前判断直连更合适
  - DeepSeek 直连 `https://api.deepseek.com/models` 可返回 HTTP 200
  - 直连三次约 `0.14-0.17s`
  - 经 `127.0.0.1:7897` 三次约 `0.12-0.33s`
  - 当前判断：DeepSeek 直连可用且更稳定。

操作规则：

- 不要为了 Xiaomi / DeepSeek 直连直接删除 `HTTP_PROXY` / `HTTPS_PROXY`，否则 Telegram、Brave、部分外部服务可能失去代理。
- 若后续升级或重写 unit，必须保留上述 Xiaomi + DeepSeek `NO_PROXY/no_proxy` drop-in 或等价配置。
- 修改代理策略后必须验收：
  1. Xiaomi MiMo 最小实呼返回 `provider=xiaomi-mimo`、`model=mimo-v2.5-pro`
  2. `openclaw models status --json` 显示 `imageModel = xiaomi-mimo/mimo-v2.5`
  3. DeepSeek fallback 仍在 `openclaw models status --json` 的 `fallbacks` 中
  4. Telegram webhook 和 `sendMessage ok` 正常
  5. `curl -x http://127.0.0.1:7897 https://www.gstatic.com/generate_204` 仍返回 `204`

### dayong ZAI / GLM 直连状态

> 2026-05-03 复核说明：本轮用户明确要求不接管其他 Gateway 的业务配置。实际 smoke test 中，dayong 8 个 Agent 当前返回 `zai/glm-5`，且本轮没有调整 dayong 的模型 / fallback 配置。下列历史基线保留作追溯，后续如需接管 dayong 配置，应先重新现场读取 `~/.openclaw-dayong/openclaw.json`。

- `dayong` 当前 8 个 agent 均配置为：
  - `zai/glm-5.1`
- 8 个 agent：
  - `market`
  - `sector`
  - `stock`
  - `strategy`
  - `breakboard`
  - `douzhuan`
  - `volume15`
  - `volume35`
- 当前 provider endpoint：
  - `https://open.bigmodel.cn/api/coding/paas/v4`
- 当前 provider 模型注册：
  - 只保留 `glm-5.1`
  - `contextWindow = 204800`
  - `maxTokens = 131072`
  - `reasoning = true`
- 当前 fallback：
  - 无，`fallbacks = []`
- 直连策略：
  - `openclaw-gateway-dayong.service` 仍保留 `HTTP_PROXY/HTTPS_PROXY=http://127.0.0.1:7897`
  - 额外通过 drop-in 设置 `NO_PROXY/no_proxy=open.bigmodel.cn,.bigmodel.cn,localhost,127.0.0.1,::1`
  - 文件：`~/.config/systemd/user/openclaw-gateway-dayong.service.d/10-zai-no-proxy.conf`
- 当前验收：
  - `openclaw config validate` 通过
  - `openclaw models status --json` 显示 `defaultModel/resolvedDefault = zai/glm-5.1`
  - 8 个 agent 的 `agents.list[].model` 均显式为 `zai/glm-5.1`
  - 父进程和 gateway 子进程均继承 `NO_PROXY/no_proxy`
  - `127.0.0.1:19021` / `127.0.0.1:19023` 正常监听
  - 日志真实实呼显示 `provider=zai`、`model=glm-5.1`
- 当前风险：
  - 智谱服务侧当前会返回 `429 该模型当前访问量过大，请您稍后再试`
  - 因为按要求未设置 fallback，429 会直接暴露给调用方，不会自动切到其他模型。

## 术语

- **小龙虾 = OpenClaw**：对话和文档中，"小龙虾"即指 OpenClaw，二者等价。

## WSL 远程执行工作流（已废弃）

**重要变更**：当前 live 小龙虾运行在远程 Ubuntu 机器（`100.64.65.65`），不在本地 WSL。

### 新工作模式（远程 Ubuntu）

- **配置文件**：通过 SSH 连接 `ssh kevinlasnh@100.64.65.65` 后操作 `~/.openclaw/openclaw.json`
- **日志查看**：`ssh kevinlasnh@100.64.65.65 'journalctl --user -u openclaw-gateway'`
- **服务管理**：`ssh kevinlasnh@100.64.65.65 'systemctl --user {start|stop|restart|status} openclaw-gateway'`
- **本地 WSL**：仅用于日常操作，不运行 OpenClaw 服务

**不再需要**脚本投递 + 文件轮询的方式，除非特殊情况（如需要复杂的多步操作）。

### 旧工作流程（保留作为参考）

本项目的小龙虾运行在 WSL2 Ubuntu 中，早期版本 Agent 无法直接在 WSL 内执行命令，采用"脚本投递 + 文件轮询"工作流：

### 执行流程

1. **Agent 写脚本**：将需要在 WSL 中执行的命令写入项目根目录的 `.sh` 脚本文件，脚本内所有输出必须重定向到固定的结果文件：
   - 脚本路径：`C:\Zero\Doc\Cloud\GitHub\OpenClaw\wsl_run.sh`（每次覆盖）
   - 结果文件：`C:\Zero\Doc\Cloud\GitHub\OpenClaw\wsl_output.txt`（每次覆盖）
   - WSL 内对应路径：`/mnt/c/Zero/Doc/Cloud/GitHub/OpenClaw/`

2. **通知用户执行**：告知用户在 WSL 终端中运行：
   ```bash
   bash /mnt/c/Zero/Doc/Cloud/GitHub/OpenClaw/wsl_run.sh
   ```

3. **自动轮询结果**：脚本写完后，Agent 必须立即启动后台轮询任务，持续检查 `wsl_output.txt` 的变化，无需等待用户说"OK"或"跑完了"：
   - 使用 Bash 后台任务轮询文件修改时间
   - 检测到文件更新后自动读取内容并继续工作
   - 轮询超时设为 5 分钟

4. **处理结果**：读取 `wsl_output.txt`，分析输出，继续下一步工作。

### 脚本模板

所有 WSL 脚本必须遵循以下模板：

```bash
#!/bin/bash
OUT="/mnt/c/Zero/Doc/Cloud/GitHub/OpenClaw/wsl_output.txt"
export PATH="/home/kevinlasnh/.npm-global/bin:$PATH"
echo "=== 任务描述 ===" > "$OUT"

# ... 具体命令 ...

echo "=== 完成 ===" >> "$OUT"
```

### 注意事项

- 每次写新脚本前先清空或覆盖 `wsl_output.txt`，避免读到旧结果
- 脚本中对可能卡住的命令使用 `timeout` 包裹
- 敏感信息（API Key 等）不写入脚本，改用占位符让用户手动替换
- 脚本文件统一使用 `wsl_run.sh`，避免产生大量临时脚本文件

## 关联仓库

### Google Pixel 5 修机仓库
- **路径：** `C:\Zero\Doc\Cloud\GitHub\google-pixel5-fix`
- **用途：** 记录 Pixel 5 的所有硬件/软件修复（VoLTE、5G、SMS、Root 隐藏、Clash 代理等）
- **存档文件：** `task_plan.md`、`findings.md`、`progress.md`（Planning with Files 格式）
- **操作规则：** 当用户要求对该仓库撰写任务或续写内容时，使用 `planning-with-files` skill 在该仓库的存档文件下进行增量添加
