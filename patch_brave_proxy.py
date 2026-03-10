#!/usr/bin/env python3
"""
Brave Search 代理补丁脚本
为 Brave fetch 调用添加 undici ProxyAgent 支持
适用于 v2026.2.25+
"""
import re
import shutil
import os

DIST = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist"

TARGETS = [
    "pi-embedded-A-pNScBs.js",
    "pi-embedded-NV2C9XdE.js",
    "reply-CFQ8lILc.js",
    "subagent-registry-C6qDcjAh.js",
]

# 匹配原始 Brave fetch 代码（withTimeout$N 后缀用 regex 捕获）
PATTERN = re.compile(
    r'(const res = await fetch\(url\.toString\(\), \{\n'
    r'\t\tmethod: "GET",\n'
    r'\t\theaders: \{\n'
    r'\t\t\tAccept: "application/json",\n'
    r'\t\t\t"X-Subscription-Token": params\.apiKey\n'
    r'\t\t\},\n'
    r'\t\tsignal: (withTimeout\$\d+)\(void 0, params\.timeoutSeconds \* 1e3\)\n'
    r'\t\}\);)'
)

def make_replacement(timeout_fn):
    return (
        f'const _braveProxyUrl = process.env.HTTPS_PROXY || process.env.HTTP_PROXY;\n'
        f'\tconst res = await (_braveProxyUrl\n'
        f'\t\t? fetch$1(url.toString(), {{\n'
        f'\t\t\tmethod: "GET",\n'
        f'\t\t\theaders: {{\n'
        f'\t\t\t\tAccept: "application/json",\n'
        f'\t\t\t\t"X-Subscription-Token": params.apiKey\n'
        f'\t\t\t}},\n'
        f'\t\t\tsignal: {timeout_fn}(void 0, params.timeoutSeconds * 1e3),\n'
        f'\t\t\tdispatcher: new ProxyAgent(_braveProxyUrl)\n'
        f'\t\t}})\n'
        f'\t\t: fetch(url.toString(), {{\n'
        f'\t\t\tmethod: "GET",\n'
        f'\t\t\theaders: {{\n'
        f'\t\t\t\tAccept: "application/json",\n'
        f'\t\t\t\t"X-Subscription-Token": params.apiKey\n'
        f'\t\t\t}},\n'
        f'\t\t\tsignal: {timeout_fn}(void 0, params.timeoutSeconds * 1e3)\n'
        f'\t\t}}));'
    )

def patch_file(filename):
    path = os.path.join(DIST, filename)
    if not os.path.exists(path):
        print(f"SKIP (not found): {filename}")
        return

    with open(path, "r", encoding="utf-8") as f:
        code = f.read()

    # 检查是否已打过补丁
    if "_braveProxyUrl" in code:
        print(f"SKIP (already patched): {filename}")
        return

    # 检查是否有 undici 导入
    if "ProxyAgent" not in code or "fetch$1" not in code:
        print(f"SKIP (no undici import): {filename}")
        return

    match = PATTERN.search(code)
    if not match:
        print(f"FAIL (pattern not found): {filename}")
        return

    timeout_fn = match.group(2)
    replacement = make_replacement(timeout_fn)

    # 备份
    bak = path + ".bak"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
        print(f"  Backed up to {filename}.bak")

    new_code = PATTERN.sub(replacement, code, count=1)
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_code)

    print(f"OK ({timeout_fn}): {filename}")

if __name__ == "__main__":
    print("=== Brave Search 代理补丁 ===")
    for t in TARGETS:
        patch_file(t)
    print("=== 完成，请重启 gateway ===")
