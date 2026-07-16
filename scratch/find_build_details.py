import re

with open(r"C:\Users\Sooraj\.gemini\antigravity\brain\18a12848-461a-4b0e-97ce-df9bdc13622a\.system_generated\steps\15113\content.md", "r", encoding="utf-8") as f:
    text = f.read()

# Let's clean the text of html tags to make it readable
clean_text = re.sub('<[^<]+?>', ' ', text)

# Print lines containing build status or urls
print("--- Parsing Build Details ---")
for line in clean_text.splitlines():
    line = line.strip()
    if not line:
        continue
    # Look for interesting terms
    if any(k in line.lower() for k in ["status", "download", "success", "fail", "build", "finished", "error"]):
        print(line[:150])
