#!/usr/bin/env python3
"""Fix withTimeout function name in runKimiSearch for files where it differs."""
import sys

fixes = {
    "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/subagent-registry-kdTa9uwX.js": ("withTimeout$3", "withTimeout$2"),
    "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/plugin-sdk/reply-BhWxw1_E.js": ("withTimeout$3", "withTimeout$2"),
}

for path, (old, new) in fixes.items():
    code = open(path, "r", encoding="utf-8").read()
    start = code.index("async function runKimiSearch")
    end = code.index("async function runWebSearch", start)
    chunk = code[start:end]
    count = chunk.count(old)
    fixed = chunk.replace(old, new)
    code = code[:start] + fixed + code[end:]
    open(path, "w", encoding="utf-8").write(code)
    print(f"{path.split('/')[-1]}: fixed {count} occurrences ({old} -> {new})")

print("Done.")
