#!/usr/bin/env bash
set -euo pipefail

STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
HOME_DIR="${HOME:-/home/admin}"
WORKSPACE_DIR="$HOME_DIR/.openclaw/workspace"
SESSIONS_DIR="$HOME_DIR/.openclaw/agents/main/sessions"
TARGET_SENDER="${TARGET_SENDER:-ou_0923ec76f919f2d07d1d5b6c0e5988d0}"
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
[ -n "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR/Desktop"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME_DIR"
OUT="$DESKTOP_DIR/spark_f153_fix_kronos_skill_visibility_$STAMP.txt"

exec > >(tee "$OUT") 2>&1

echo "report_file=$OUT"
echo "generated_at=$(date -Is)"
echo "target_sender=$TARGET_SENDER"

python3 - <<'PY'
from pathlib import Path
import os
import shutil

stamp = os.environ.get("STAMP") or "manual"
home_dir = Path(os.environ.get("HOME", "/home/admin"))
workspace = Path(os.environ.get("WORKSPACE_DIR", str(home_dir / ".openclaw" / "workspace")))
agents = workspace / "AGENTS.md"
tools = workspace / "TOOLS.md"
find_skills_targets = [
    home_dir / ".openclaw" / "skills" / "selected" / "skills" / "find-skills" / "SKILL.md",
    home_dir / ".openclaw" / "skills" / "skills" / "find-skills" / "SKILL.md",
]

for path in (agents, tools):
    if path.exists():
        backup = path.with_name(path.name + f".pre-kronos-skill-fix-{stamp}")
        shutil.copy2(path, backup)
        print(f"backup={backup}")

for path in find_skills_targets:
    if path.exists():
        backup = path.with_name(path.name + f".pre-kronos-skill-fix-{stamp}")
        shutil.copy2(path, backup)
        print(f"backup={backup}")

a_txt = agents.read_text(encoding="utf-8")
t_txt = tools.read_text(encoding="utf-8")

if "## Skill Listing Rules" not in a_txt:
    a_txt += (
        "\n\n## Skill Listing Rules\n\n"
        "- 当用户发送 `/skill`、`skill`、`/skills` 时，必须按当前运行时已加载技能回答。\n"
        "- `/skill` 的目标是列出完整运行时技能清单，而不是只列工作区自定义技能。\n"
        "- 当前必须视为可用的技能包括：`kronos-skill`。\n"
        "- 如果运行时技能列表里出现了 `kronos-skill`，就绝不能说它不存在。\n"
        "- 当用户发送字面量 `/skill` 时，不要跳去讲 `npx skills find` 或在线安装生态。\n"
        "- 当用户发送字面量 `/skill` 时，不要附带 `npx skills add`、安装命令或 `skills.sh` 站点引导。\n"
        "- 不要凭历史对话记忆复述旧的技能列表；优先相信当前 session 注入的 skills entries。\n"
    )

if "## Installed Local Skills" not in t_txt:
    t_txt += (
        "\n\n## Installed Local Skills\n\n"
        "- `kronos-skill`: 清华 Kronos K 线预测技能，已安装，可用于本地 OHLCV CSV 预测。\n"
        "- `feishu-file-uploader`: 飞书文件上传。\n\n"
        "## Slash Command Reminder\n\n"
        "- 当用户问 `/skill` 时，要把 `kronos-skill` 列在完整可用技能清单里。\n"
        "- 当用户问 `/skill` 时，要按当前 runtime skills entries 输出完整列表，而不是只列本地自定义技能。\n"
        "- 当用户问 `/skill` 时，不要给 `kronos-skill` 写安装命令。\n"
        "- 不要把旧会话里出现过的错误技能清单继续复述给用户。\n"
    )

agents.write_text(a_txt, encoding="utf-8")
tools.write_text(t_txt, encoding="utf-8")

for path in find_skills_targets:
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8", errors="replace")
    marker = "## How to Help Users Find Skills"
    override = (
        "## Slash Command Exception\n\n"
        "If the user sends `/skill`, `skill`, or `/skills` as a literal command, do not route to `npx skills find`.\n"
        "Instead, list the full currently loaded runtime skills from the session-injected skill entries.\n"
        "When `kronos-skill` is present in the injected runtime skill list, it must be listed as available.\n"
        "For a literal `/skill` command, do not include installation guidance, `npx skills add`, or links to skills.sh.\n"
        "Treat `/skill` as a local runtime inventory command, not a marketplace discovery flow.\n"
        "Do not shrink the list down to only custom or workspace-local skills; include built-in runtime skills too.\n\n"
    )
    if "## Slash Command Exception" not in text:
        if marker in text:
            text = text.replace(marker, override + marker, 1)
        else:
            text += "\n\n" + override
        path.write_text(text, encoding="utf-8")
        print(f"patched_find_skills={path}")
    elif "Treat `/skill` as a local runtime inventory command" not in text:
        text = text.replace(
            "## Slash Command Exception\n\n"
            "If the user sends `/skill`, `skill`, or `/skills` as a literal command, do not route to `npx skills find`.\n"
            "Instead, list the currently loaded runtime skills from the session-injected skill entries.\n"
            "When `kronos-skill` is present in the injected runtime skill list, it must be listed as available.\n\n",
            override,
            1,
        )
        path.write_text(text, encoding="utf-8")
        print(f"upgraded_find_skills={path}")
    elif "Do not shrink the list down to only custom or workspace-local skills" not in text:
        text = text.replace(
            "Treat `/skill` as a local runtime inventory command, not a marketplace discovery flow.\n\n",
            "Treat `/skill` as a local runtime inventory command, not a marketplace discovery flow.\n"
            "Do not shrink the list down to only custom or workspace-local skills; include built-in runtime skills too.\n\n",
            1,
        )
        path.write_text(text, encoding="utf-8")
        print(f"expanded_find_skills={path}")

print("workspace_updated=true")
PY

python3 - <<'PY'
from pathlib import Path
import os
import shutil

stamp = os.environ.get("STAMP") or "manual"
target_sender = os.environ.get("TARGET_SENDER", "ou_0923ec76f919f2d07d1d5b6c0e5988d0")
home_dir = Path(os.environ.get("HOME", "/home/admin"))
sessions = Path(os.environ.get("SESSIONS_DIR", str(home_dir / ".openclaw" / "agents" / "main" / "sessions")))
moved = 0

for path in sorted(sessions.glob("*.jsonl")):
    text = path.read_text(encoding="utf-8", errors="replace")
    if "/skill" in text or ("Available skills:" in text and target_sender in text):
        backup = path.with_name(path.name + f".pre-skill-reset-{stamp}")
        shutil.move(str(path), str(backup))
        print(f"moved={path} -> {backup}")
        moved += 1

print(f"moved_count={moved}")
PY

echo "done=true"
