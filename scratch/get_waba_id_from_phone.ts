import 'dotenv/config'

async function main() {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID

  if (!token || !phoneId) {
    console.error('Missing env vars')
    return
  }

  try {
    console.log(`Querying details for phone number ID ${phoneId}...`)
    const res = await fetch(`https://graph.facebook.com/v20.0/${phoneId}`, {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    })

    const data = await res.json()
    console.log('Response:', JSON.stringify(data, null, 2))
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
