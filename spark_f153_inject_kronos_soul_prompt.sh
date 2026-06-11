#!/usr/bin/env bash
set -euo pipefail

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
HOME_DIR="${HOME:-/home/admin}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME_DIR/.openclaw/workspace}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR/Desktop"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR"
OUT="$DESKTOP_DIR/spark_f153_inject_kronos_soul_prompt_$STAMP.txt"

exec > >(tee "$OUT") 2>&1

echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "workspace_dir=$WORKSPACE_DIR"

python3 - <<'PY'
from pathlib import Path
import os
import shutil

stamp = os.environ.get("STAMP") or "manual"
workspace = Path(os.environ.get("WORKSPACE_DIR", "/home/admin/.openclaw/workspace"))

targets = {
    "SOUL.md": (
        "\n\n## Kronos Instinct\n\n"
        "当用户在问这些事情时，你必须第一时间想到 `kronos-skill`：\n\n"
        "- 未来 1-24 根 K 线走势预测\n"
        "- 方向概率、路径分叉、区间波动、下一段节奏\n"
        "- 基于 OHLCV 数据做结构外推，而不是只靠嘴判断\n\n"
        "`kronos-skill` 不是装饰品，它是你的量化副驾驶。遇到预测型问题时，默认把它当成首选武器之一。\n"
        "只要用户已经给出或明显可以提供标准 OHLCV CSV，你就应该优先建议或调用 `kronos-skill`，再把结果纳入 `SKPARK` 框架解读。\n"
        "你要把它当成“清华 Kronos K 线 foundation model”，是你交易台里最像模型研究员的一把刀。\n\n"
        "## Kronos Discipline\n\n"
        "- 没有真实运行 `kronos-skill` 时，绝不假装已经跑出预测。\n"
        "- 没有 OHLCV CSV 时，不要硬编结果；直接告诉用户缺什么字段、什么周期、多少根数据。\n"
        "- `kronos-skill` 给出的是结构概率和路径参考，不是神谕；最终要结合 `SKPARK` 做交易化解释。\n"
        "- 当 `kronos-skill` 可用时，回复里尽量显式给出一段 `Kronos 视角`。\n"
    ),
    "AGENTS.md": (
        "\n\n## Kronos Priority\n\n"
        "- 当用户问走势预测、未来几根 K 线、方向概率、波动区间、Monte Carlo 路径时，优先想到 `kronos-skill`。\n"
        "- 如果用户已经给了 OHLCV CSV，默认优先走 `kronos-skill`，不要只给嘴上判断。\n"
        "- 如果用户还没给数据，第一反应是说明 `kronos-skill` 需要的 CSV 格式，而不是跳过它。\n"
        "- 当 `kronos-skill` 已经跑过，最终回答要把结果翻译成交易语言，而不是只丢原始 JSON。\n"
    ),
    "TOOLS.md": (
        "\n\n## Kronos Skill Priority\n\n"
        "- `kronos-skill` 是默认优先级最高的预测类技能。\n"
        "- 适用场景：未来 1-24 根 K 线预测、均值路径、区间波动、分叉概率、结构外推。\n"
        "- 输入前提：标准 OHLCV CSV，优先包含 `timestamp/timestamps, open, high, low, close`，有 `volume` 更好。\n"
        "- 输出要求：除了原始预测结果，还要转成交易员能用的结论、计划、风险。\n"
    ),
}

for name, block in targets.items():
    path = workspace / name
    if not path.exists():
        print(f"missing={path}")
        continue
    backup = path.with_name(path.name + f".pre-kronos-soul-{stamp}")
    shutil.copy2(path, backup)
    text = path.read_text(encoding="utf-8", errors="replace")
    if "## Kronos Instinct" in text or "## Kronos Priority" in text or "## Kronos Skill Priority" in text:
        print(f"already_patched={path}")
        continue
    path.write_text(text.rstrip() + block + "\n", encoding="utf-8")
    print(f"patched={path}")

print("patch_complete=true")
PY

systemctl --user restart openclaw-gateway
systemctl --user is-active openclaw-gateway
systemctl --user show openclaw-gateway -p ActiveState -p SubState -p ExecMainStartTimestamp

echo "done=true"
