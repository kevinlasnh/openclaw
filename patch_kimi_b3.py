#!/usr/bin/env python3
"""Batch 3: Patch 6 - runWebSearch kimi dispatch + cacheKey"""
TARGET = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/pi-embedded-CNutRYOy.js"

with open(TARGET, "r", encoding="utf-8") as f:
    code = f.read()

patches_applied = 0

# Patch 6a: cacheKey - add kimi branch
old6a = ': `${params.provider}:${params.query}:${params.grokModel ?? DEFAULT_GROK_MODEL}:${String(params.grokInlineCitations ?? false)}`);'
new6a = ': params.provider === "kimi" ? `${params.provider}:${params.query}:${params.kimiModel ?? DEFAULT_KIMI_SEARCH_MODEL}` : `${params.provider}:${params.query}:${params.grokModel ?? DEFAULT_GROK_MODEL}:${String(params.grokInlineCitations ?? false)}`);'
if old6a in code and 'params.provider === "kimi" ? `${params.provider}:${params.query}:${params.kimiModel' not in code:
    code = code.replace(old6a, new6a, 1)
    patches_applied += 1
    print("Patch 6a: cacheKey - OK")
else:
    print("Patch 6a: cacheKey - SKIP")

# Patch 6b: kimi dispatch before brave check
old6b = '\tif (params.provider !== "brave") throw new Error("Unsupported web search provider.");'
new6b = '''\tif (params.provider === "kimi") {
\t\tconst { content } = await runKimiSearch({
\t\t\tquery: params.query,
\t\t\tapiKey: params.apiKey,
\t\t\tmodel: params.kimiModel ?? DEFAULT_KIMI_SEARCH_MODEL,
\t\t\ttimeoutSeconds: params.timeoutSeconds
\t\t});
\t\tconst payload = {
\t\t\tquery: params.query,
\t\t\tprovider: params.provider,
\t\t\tmodel: params.kimiModel ?? DEFAULT_KIMI_SEARCH_MODEL,
\t\t\ttookMs: Date.now() - start,
\t\t\texternalContent: { untrusted: true, source: "web_search", provider: params.provider, wrapped: true },
\t\t\tcontent: wrapWebContent(content)
\t\t};
\t\twriteCache(SEARCH_CACHE, cacheKey, payload, params.cacheTtlMs);
\t\treturn payload;
\t}
\tif (params.provider !== "brave") throw new Error("Unsupported web search provider.");'''
if old6b in code and 'params.provider === "kimi") {' not in code:
    code = code.replace(old6b, new6b, 1)
    patches_applied += 1
    print("Patch 6b: kimi dispatch - OK")
else:
    print("Patch 6b: kimi dispatch - SKIP")

print(f"\nApplied {patches_applied}/2. Writing...")
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(code)
print("Patch 6 written.")
