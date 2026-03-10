#!/usr/bin/env python3
"""Batch 4: Patch 7 - createWebSearchTool kimi modifications"""
TARGET = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/pi-embedded-CNutRYOy.js"

with open(TARGET, "r", encoding="utf-8") as f:
    code = f.read()

patches_applied = 0

# Patch 7a: add kimiConfig after grokConfig
old7a = '\tconst grokConfig = resolveGrokConfig(search);\n\treturn {'
new7a = '\tconst grokConfig = resolveGrokConfig(search);\n\tconst kimiConfig = resolveKimiConfig(search);\n\treturn {'
if old7a in code and 'kimiConfig' not in code.split('createWebSearchTool')[1][:200]:
    code = code.replace(old7a, new7a, 1)
    patches_applied += 1
    print("Patch 7a: kimiConfig - OK")
else:
    print("Patch 7a: kimiConfig - SKIP")

# Patch 7b: add kimi description branch
old7b = 'provider === "grok" ? "Search the web using xAI Grok. Returns AI-synthesized answers with citations from real-time web search." : "Search the web using Brave Search API.'
new7b = 'provider === "grok" ? "Search the web using xAI Grok. Returns AI-synthesized answers with citations from real-time web search." : provider === "kimi" ? "Search the web using Kimi K2.5 built-in web search. Returns AI-synthesized answers from real-time web search." : "Search the web using Brave Search API.'
if old7b in code:
    code = code.replace(old7b, new7b, 1)
    patches_applied += 1
    print("Patch 7b: description - OK")
else:
    print("Patch 7b: description - SKIP")

# Patch 7c: add kimi apiKey branch
old7c = 'provider === "grok" ? resolveGrokApiKey(grokConfig) : resolveSearchApiKey(search);'
new7c = 'provider === "grok" ? resolveGrokApiKey(grokConfig) : provider === "kimi" ? resolveKimiApiKey(kimiConfig) : resolveSearchApiKey(search);'
if old7c in code:
    code = code.replace(old7c, new7c, 1)
    patches_applied += 1
    print("Patch 7c: apiKey - OK")
else:
    print("Patch 7c: apiKey - SKIP")

# Patch 7d: add kimiModel param in runWebSearch call
old7d = '\t\t\t\tgrokInlineCitations: resolveGrokInlineCitations(grokConfig)\n\t\t\t}));'
new7d = '\t\t\t\tgrokInlineCitations: resolveGrokInlineCitations(grokConfig),\n\t\t\t\tkimiModel: resolveKimiModel(kimiConfig)\n\t\t\t}));'
if old7d in code:
    code = code.replace(old7d, new7d, 1)
    patches_applied += 1
    print("Patch 7d: kimiModel param - OK")
else:
    print("Patch 7d: kimiModel param - SKIP")

print(f"\nApplied {patches_applied}/4. Writing...")
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(code)
print("Patch 7 written. All patches complete!")
