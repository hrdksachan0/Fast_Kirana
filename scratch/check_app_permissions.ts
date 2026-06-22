import 'dotenv/config'

async function main() {
  const token = process.env.WHATSAPP_TOKEN

  if (!token) {
    console.error('Missing WHATSAPP_TOKEN in .env')
    process.exit(1)
  }

  try {
    console.log('Querying permissions for the current token...')
    const res = await fetch(`https://graph.facebook.com/v20.0/me/permissions`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    const data = await res.json()
    console.log('Permissions Response:', JSON.stringify(data, null, 2))
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
