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
- `CLAUDE.md`：本文件，项目规则和工作模式

**确保每一步指导都基于已沉淀的知识，而非凭记忆或猜测。**

## 当前配置摘要

### 多 Gateway 架构（2026-03-10 Webhook 模式）

| Gateway | 目录 | Gateway 端口 | Webhook 端口 | Funnel 端口 | Bot | 模型 | systemd 服务 |
|---------|------|-------------|-------------|------------|-----|------|-------------|
| **main** | `~/.openclaw/` | 18790 | 8787 | 443 | @OpenClaw_kevinlasnh_no1_bot | minimax/MiniMax-M2.5 | openclaw-gateway.service |
| **dayong** | `~/.openclaw-dayong/` | 19021 | 8788 | 8443 | @openclaw_BigA_winner_bot | kimi/k2p5 | openclaw-gateway-dayong.service |
| chunyan | `~/.openclaw-chunyan/` | 19001 | 待配 | 10000 | 待配 | 待配 | 未部署 |
| zenglan | `~/.openclaw-zenglan/` | 19041 | 待配 | 需 nginx | 待配 | 待配 | 未部署 |

**隔离方式**：`OPENCLAW_STATE_DIR` + `OPENCLAW_CONFIG_PATH` 环境变量（`--profile` 不可靠，见 findings.md Z 节）
**消息接收**：Webhook 模式（Tailscale Funnel 提供公网 HTTPS 端点，Telegram 主动推送消息）

### 主 Gateway 配置

| 配置项 | 值 |
|--------|-----|
| Gateway 版本 | v2026.3.7 |
| 架构 | 单 Agent（main，default=true） |
| 默认主模型 | minimax/MiniMax-M2.5 |
| Fallback 链 | kimi/k2p5 → zai/glm-5 → newcli/claude-opus-4-6 |
| Web Search | provider: brave（maxResults=20） |
| 消息通道 | Telegram（唯一启用） |
| Telegram 模式 | **Webhook**（通过 Tailscale Funnel） |
| Telegram Bot | @OpenClaw_kevinlasnh_no1_bot (main-bot) |
| Webhook URL | `https://openclaw-24x7.tailda6e28.ts.net/telegram-webhook` |
| Webhook 本地端口 | 8787（Funnel 443 → 8787） |
| Telegram Streaming | off（块流式，一条消息无预览） |
| Block Streaming Default | on |
| 飞书 | 已彻底删除（2026-03-09） |
| WhatsApp | 已彻底删除 |
| API Key 存储 | ~/.openclaw/.env (chmod 600) |
| 代理 | http://127.0.0.1:7897 |
| 代理节点池 | 54 个全地区节点，自动选择（url-test, 30s） |
| gateway.bind | loopback |
| boot-md | 已启用 |
| commands.restart | true |
| verboseDefault | on（工具执行时发送摘要消息） |
| subagents.maxConcurrent | 3 |
| 补丁文件数 | 5（stall 检测阈值补丁，Webhook 模式下不再生效，升级可不重打） |

### Tailscale Funnel 端口分配

| Funnel 端口 | 本地端口 | Gateway | 状态 |
|------------|---------|---------|------|
| 443 | 8787 | main | ✅ 运行中 |
| 8443 | 8788 | dayong | ✅ 运行中 |
| 10000 | 待定 | （预留） | 未部署 |

### Kimi 配置要点（重要 - 未解决）

**核心问题：两难困境**
- 内置 `kimi-coding` provider：有正确的 User-Agent（通过 API 403 检查），但模型 ID `k2p5` 被 API 返回 404
- 自定义 provider（任何名称）：模型 ID 正确 `kimi-for-coding`，但丢失 User-Agent 被 API 返回 403

**已尝试的 4 种方案全部失败：**
1. 自定义 provider 名 `kimi` → 403（User-Agent）
2. 自定义覆盖 `kimi-coding`（只有 models）→ 配置校验失败（baseUrl required）
3. 自定义覆盖 `kimi-coding`（带 baseUrl）→ 403（丢失 User-Agent）
4. 源码补丁 `KIMI_CODING_MODEL_ID` → 仍 403

**已打的源码补丁（可能需要回滚）：**
- 文件：`github-copilot-auth-BiaSo_ZY.js` 和 `github-copilot-auth-BeXkhisw.js`
- 改动：`KIMI_CODING_MODEL_ID = "k2p5"` → `"kimi-for-coding"`

**关键信息：**
- API 实际模型 ID：`kimi-for-coding`（`curl https://api.kimi.com/coding/v1/models` 确认）
- auth-profiles.json 位置：`~/.openclaw/agents/main/agent/auth-profiles.json`
- cooldown 机制：失败后需手动清除 `usageStats`，重启 gateway 不会清除
- 详细分析见 `findings.md` 的 "Kimi Coding Provider 深度分析 v2" 部分

## 术语

- **小龙虾 = OpenClaw**：对话和文档中，"小龙虾"即指 OpenClaw，二者等价。

## WSL 远程执行工作流（已废弃）

**重要变更**：Claude 现在可以直接访问 WSL 文件系统，通过 `\\wsl$\Ubuntu\` 路径读取/修改文件。

### 新工作模式（远程 Ubuntu）

**重要**：小龙虾现在运行在远程 Ubuntu 机器（100.64.65.65），不在本地 WSL。

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
