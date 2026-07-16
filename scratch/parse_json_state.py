with open(r"C:\Users\Sooraj\.gemini\antigravity\brain\18a12848-461a-4b0e-97ce-df9bdc13622a\.system_generated\steps\15113\content.md", "r", encoding="utf-8") as f:
    text = f.read()

target = "fb496135-ac3a-4ffa-8d28-487093d5977a"
index = text.find(target)
while index != -1:
    print(f"--- Found target at index {index} ---")
    start = max(0, index - 300)
    end = min(len(text), index + 1000)
    print(text[start:end])
    index = text.find(target, index + 1)
