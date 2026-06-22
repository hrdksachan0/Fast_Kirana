import 'dotenv/config'

async function main() {
  const token = process.env.WHATSAPP_TOKEN
  const messageId = 'wamid.HBgMOTE3MDU0NDcwMzAzFQIAERgSOEE1NzU1N0E2MTZFMDlFQzYyAA=='

  if (!token) {
    console.error('Missing WHATSAPP_TOKEN in .env')
    process.exit(1)
  }

  try {
    console.log(`Querying message status for ID: ${messageId}...`)
    const res = await fetch(`https://graph.facebook.com/v20.0/${messageId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    const data = await res.json()
    console.log('Status Response:', JSON.stringify(data, null, 2))
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
