import json

path = "/home/kevinlasnh/.openclaw/cron/jobs.json"
with open(path) as f:
    data = json.load(f)

new_jobs = []
for job in data["jobs"]:
    # Delete whatsapp-keepalive
    if job["name"] == "whatsapp-keepalive":
        print(f"DELETED: {job['name']}")
        continue

    # Fix 10086-cancel-reminder message
    if job["name"] == "10086-cancel-reminder":
        old = job["payload"]["message"]
        job["payload"]["message"] = old.replace(
            "发送 WhatsApp 消息到 +8615817413681",
            "发送 Telegram 消息到 8226087994"
        )
        print(f"UPDATED message: {job['name']}")

    # Fix morning-briefing
    if job["name"] == "morning-briefing":
        job["delivery"]["channel"] = "telegram"
        job["payload"]["message"] = job["payload"]["message"].replace(
            "发送 WhatsApp 消息", "发送 Telegram 消息"
        )
        print(f"UPDATED delivery+message: {job['name']}")

    # Fix daily-memory-save
    if job["name"] == "daily-memory-save":
        job["delivery"]["channel"] = "telegram"
        job["payload"]["message"] = job["payload"]["message"].replace(
            "WhatsApp", "Telegram"
        )
        print(f"UPDATED delivery+message: {job['name']}")

    new_jobs.append(job)

data["jobs"] = new_jobs
with open(path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print(f"\nDone. {len(new_jobs)} jobs remaining (was {len(new_jobs)+1})")
