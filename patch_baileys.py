"""Baileys WhatsApp proxy patch - re-run after each OpenClaw upgrade."""
import glob, shutil, os

dist = "/home/kevinlasnh/.npm-global/lib/node_modules/openclaw/dist"
files = glob.glob(os.path.join(dist, "session-*.js"))

for f in files:
    if f.endswith(".bak"):
        continue
    shutil.copy2(f, f + ".bak")
    with open(f, "r") as fh:
        code = fh.read()
    if "HttpsProxyAgent" not in code:
        code = code.replace(
            'from "@whiskeysockets/baileys";',
            'from "@whiskeysockets/baileys";\nimport { HttpsProxyAgent } from "https-proxy-agent";',
        )
    if "agent:" not in code:
        code = code.replace(
            "markOnlineOnConnect: false\n\t});",
            "markOnlineOnConnect: false,\n\t\tagent: process.env.HTTPS_PROXY ? new HttpsProxyAgent(process.env.HTTPS_PROXY) : undefined\n\t});",
        )
    with open(f, "w") as fh:
        fh.write(code)
    print("OK: " + os.path.basename(f))
