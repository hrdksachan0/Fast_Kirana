import fs from 'fs'
import readline from 'readline'

async function main() {
  const fileStream = fs.createReadStream('C:/Users/Sooraj/.gemini/antigravity/brain/f7a233b0-5f4b-4802-948a-923a262a444a/.system_generated/logs/transcript.jsonl')
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  })

  let lineNum = 0
  for await (const line of rl) {
    lineNum++
    if (lineNum > 17000 && (line.includes('public/grocery_bag_banner.png') || line.includes('copy') || line.includes('grocery_bag_banner'))) {
      const parsed = JSON.parse(line)
      console.log(`LINE ${lineNum} (Step ${parsed.step_index}, Source: ${parsed.source}, Type: ${parsed.type}):`)
      console.log(JSON.stringify(parsed.tool_calls || parsed).substring(0, 500))
      console.log('-'.repeat(40))
    }
  }
}

main().catch(console.error)
