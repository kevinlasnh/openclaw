#!/usr/bin/env python3
"""Patch pi-embedded-CNutRYOy.js with Kimi web search provider support."""
import sys

TARGET = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/pi-embedded-CNutRYOy.js"

with open(TARGET, "r", encoding="utf-8") as f:
    code = f.read()

patches_applied = 0

# Patch 1: Constants after DEFAULT_GROK_MODEL
old1 = 'const DEFAULT_GROK_MODEL = "grok-4-1-fast";\nconst SEARCH_CACHE'
new1 = 'const DEFAULT_GROK_MODEL = "grok-4-1-fast";\nconst KIMI_SEARCH_ENDPOINT = "https://api.kimi.com/coding/v1/chat/completions";\nconst DEFAULT_KIMI_SEARCH_MODEL = "kimi-for-coding";\nconst SEARCH_CACHE'
if old1 in code:
    code = code.replace(old1, new1, 1)
    patches_applied += 1
    print("Patch 1: constants - OK")
else:
    print("Patch 1: constants - SKIP (already patched or not found)")

# Patch 2: resolveSearchProvider add kimi
old2 = '\tif (raw === "grok") return "grok";\n\tif (raw === "brave") return "brave";'
new2 = '\tif (raw === "grok") return "grok";\n\tif (raw === "kimi") return "kimi";\n\tif (raw === "brave") return "brave";'
if old2 in code:
    code = code.replace(old2, new2, 1)
    patches_applied += 1
    print("Patch 2: resolveSearchProvider - OK")
else:
    print("Patch 2: resolveSearchProvider - SKIP")

# Patch 3: missingSearchKeyPayload add kimi
old3 = '\t};\n\treturn {\n\t\terror: "missing_brave_api_key",'
new3 = '\t};\n\tif (provider === "kimi") return {\n\t\terror: "missing_kimi_api_key",\n\t\tmessage: "web_search (kimi) needs a Kimi API key. Set KIMI_API_KEY in the Gateway environment, or configure tools.web.search.kimi.apiKey.",\n\t\tdocs: "https://docs.openclaw.ai/tools/web"\n\t};\n\treturn {\n\t\terror: "missing_brave_api_key",'
if old3 in code:
    code = code.replace(old3, new3, 1)
    patches_applied += 1
    print("Patch 3: missingSearchKeyPayload - OK")
else:
    print("Patch 3: missingSearchKeyPayload - SKIP")

# Patch 4: Helper functions after resolveGrokInlineCitations
old4 = 'function resolveGrokInlineCitations(grok) {\n\treturn grok?.inlineCitations === true;\n}\nfunction resolveSearchCount'
new4 = '''function resolveGrokInlineCitations(grok) {
\treturn grok?.inlineCitations === true;
}
function resolveKimiConfig(search) {
\tif (!search || typeof search !== "object") return {};
\tconst kimi = "kimi" in search ? search.kimi : void 0;
\tif (!kimi || typeof kimi !== "object") return {};
\treturn kimi;
}
function resolveKimiApiKey(kimi) {
\tconst fromConfig = normalizeApiKey(kimi?.apiKey);
\tif (fromConfig) return fromConfig;
\treturn normalizeApiKey(process.env.KIMI_API_KEY) || void 0;
}
function resolveKimiModel(kimi) {
\treturn (kimi && "model" in kimi && typeof kimi.model === "string" ? kimi.model.trim() : "") || DEFAULT_KIMI_SEARCH_MODEL;
}
function resolveSearchCount'''
if old4 in code:
    code = code.replace(old4, new4, 1)
    patches_applied += 1
    print("Patch 4: helper functions - OK")
else:
    print("Patch 4: helper functions - SKIP")

print(f"\nApplied {patches_applied}/4 patches (batch 1). Writing...")
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(code)
print("Batch 1 written successfully.")
