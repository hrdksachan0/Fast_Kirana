import 'dotenv/config'

async function main() {
  const token = process.env.WHATSAPP_TOKEN
  const wabaId = '1336051418681078'

  if (!token) {
    console.error('Missing WHATSAPP_TOKEN in .env')
    process.exit(1)
  }

  try {
    console.log(`Querying templates for WABA ${wabaId}...`)
    const res = await fetch(`https://graph.facebook.com/v20.0/${wabaId}/message_templates?limit=100`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    const data = await res.json()
    if (!res.ok) {
      console.error('Error fetching templates:', data)
      process.exit(1)
    }

    const templates = data.data || []
    console.log(`Found ${templates.length} templates:`)
    for (const t of templates) {
      console.log(`\nName: ${t.name}`)
      console.log(`Language: ${t.language}`)
      console.log(`Status: ${t.status}`)
      console.log(`Category: ${t.category}`)
      console.log(`Components:`, JSON.stringify(t.components, null, 2))
      console.log('---------------------------------------------')
    }
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
