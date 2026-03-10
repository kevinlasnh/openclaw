#!/usr/bin/env python3
"""Batch 2: Patches 5-7 for pi-embedded-CNutRYOy.js"""
TARGET = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist/pi-embedded-CNutRYOy.js"

with open(TARGET, "r", encoding="utf-8") as f:
    code = f.read()

patches_applied = 0

# Patch 5: runKimiSearch function (insert before runWebSearch)
old5 = "async function runWebSearch(params) {"
new5 = r"""async function runKimiSearch(params) {
	const body1 = {
		model: params.model,
		messages: [{ role: "user", content: params.query }],
		tools: [{ type: "builtin_function", function: { name: "$web_search" } }],
		thinking: { type: "disabled" },
		tool_choice: "auto"
	};
	const headers = {
		"Content-Type": "application/json",
		Authorization: `Bearer ${params.apiKey}`,
		"User-Agent": "claude-code/2.1.0"
	};
	const res1 = await fetch(KIMI_SEARCH_ENDPOINT, {
		method: "POST", headers, body: JSON.stringify(body1),
		signal: withTimeout$3(void 0, params.timeoutSeconds * 1e3)
	});
	if (!res1.ok) {
		const detail = (await readResponseText(res1, { maxBytes: 64e3 })).text;
		throw new Error(`Kimi search API error (${res1.status}): ${detail || res1.statusText}`);
	}
	const data1 = await res1.json();
	const choice1 = data1.choices?.[0];
	if (choice1?.finish_reason !== "tool_calls" || !choice1?.message?.tool_calls?.length) {
		return { content: choice1?.message?.content ?? "No response" };
	}
	const toolCall = choice1.message.tool_calls[0];
	const body2 = {
		model: params.model,
		messages: [
			{ role: "user", content: params.query },
			choice1.message,
			{ role: "tool", tool_call_id: toolCall.id, name: toolCall.function.name, content: toolCall.function.arguments }
		],
		thinking: { type: "disabled" }
	};
	const res2 = await fetch(KIMI_SEARCH_ENDPOINT, {
		method: "POST", headers, body: JSON.stringify(body2),
		signal: withTimeout$3(void 0, params.timeoutSeconds * 1e3)
	});
	if (!res2.ok) {
		const detail = (await readResponseText(res2, { maxBytes: 64e3 })).text;
		throw new Error(`Kimi search round-2 error (${res2.status}): ${detail || res2.statusText}`);
	}
	const data2 = await res2.json();
	return { content: data2.choices?.[0]?.message?.content ?? "No response" };
}
async function runWebSearch(params) {"""
if old5 in code and "runKimiSearch" not in code:
    code = code.replace(old5, new5, 1)
    patches_applied += 1
    print("Patch 5: runKimiSearch - OK")
else:
    print("Patch 5: runKimiSearch - SKIP")

print(f"Applied {patches_applied}/1 (Patch 5). Writing...")
with open(TARGET, "w", encoding="utf-8") as f:
    f.write(code)
print("Patch 5 written.")
