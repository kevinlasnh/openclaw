#!/usr/bin/env python3
"""Fix withTimeout function name in runKimiSearch across ALL patched files."""

files = {
    "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/reply-B1AnbNl6.js": "withTimeout$1",
    "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/subagent-registry-kdTa9uwX.js": "withTimeout$2",
    "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/plugin-sdk/reply-BhWxw1_E.js": "withTimeout$2",
}

for path, correct in files.items():
    code = open(path, "r", encoding="utf-8").read()
    start = code.index("async function runKimiSearch")
    end = code.index("async function runWebSearch", start)
    chunk = code[start:end]
    # Replace any withTimeout$N with the correct one
    import re
    fixed = re.sub(r'withTimeout\$\d+', correct, chunk)
    count = len(re.findall(r'withTimeout\$\d+', chunk))
    code = code[:start] + fixed + code[end:]
    open(path, "w", encoding="utf-8").write(code)
    print(f"{path.split('/')[-1]}: replaced {count} -> {correct}")

print("Done.")
