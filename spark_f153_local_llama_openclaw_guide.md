# `spark-f153` 本地 Llama 方案

## 结论

这台客户机最稳的本地模型方案是：

- 推理栈：`Ollama`
- 本地模型：`llama3.1:8b`
- OpenClaw 接法：`OpenAI-compatible /v1`
- OpenClaw 主模型：`local-ollama/llama3.1-openclaw:8b`
- OpenClaw fallback：保留当前 Kimi 链路

## 我为什么选这个方案

1. 这台机器是 `Ubuntu 24.04.4 LTS`、`aarch64`、`NVIDIA GB10 (DGX Spark)`、`119 GiB RAM`，硬件余量足够。
2. Ollama 官方 Linux 文档提供了 ARM64 安装包，硬件支持页也明确列出 `GB10 (DGX Spark)`。
3. Ollama 官方文档同时给出了：
   - 本地 API 默认地址：`http://localhost:11434/api`
   - OpenAI 兼容地址：`http://localhost:11434/v1`
4. 当前客户机上的 OpenClaw 已经用通用 `openai-completions` provider 跑过 Moonshot/Kimi，所以直接接 Ollama 的 `/v1` 最稳，不需要改 OpenClaw 源码。
5. `llama3.1:8b` 在 Ollama 官方库中是：
   - 4.9 GB
   - 128K context
   - 工具能力相对成熟

## 为什么不是更大的本地模型

不是这台机器跑不动更大模型，而是这次目标是：

- 一键落地
- 稳定接入 OpenClaw
- 飞书实聊能马上用

所以我选了风险最低的 `8B` 档，而不是先去赌一个更大的模型会不会拖慢首 token、占用过高或把调试时间拉长。

## 落地策略

脚本会做这些事：

1. 安装用户态 `Ollama`
2. 启动 `ollama-user.service`
3. 拉取 `llama3.1:8b`
4. 基于它创建一个给 OpenClaw 用的派生模型：
   - `llama3.1-openclaw:8b`
   - 显式设置 `num_ctx=65536`
5. 把 OpenClaw 主模型切到：
   - `local-ollama/llama3.1-openclaw:8b`
6. 保留现有 Kimi fallback，避免本地模型异常时整机失声
7. 重启 `openclaw-gateway`
8. 做 API、自聊、通道三层验收

## 一键脚本

- 启用脚本：[spark_f153_enable_local_llama_openclaw.sh](/C:/Zero/Doc/Cloud/GitHub/OpenClaw/spark_f153_enable_local_llama_openclaw.sh)

## 关键边界

1. 我没有走 `ollama launch openclaw` 的自动接管模式。
2. 原因不是它不能用，而是客户机上已经有：
   - Feishu
   - 股票人格工作区
   - Kimi provider
   - 现有通道绑定
3. 直接手工补 provider 更可控，不容易把现有配置冲掉。

## 结果目标

执行成功后，客户机会变成：

- 飞书入口不变
- OpenClaw 主回复优先走本地 `Llama 3.1 8B`
- Kimi 作为远端 fallback 保底
- 不依赖节点/代理去跑主回复
