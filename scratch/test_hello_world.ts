import 'dotenv/config'

async function main() {
  const testPhone = process.argv[2]
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID

  if (!testPhone) {
    console.error('Please provide a phone number to test. Example: npx tsx scratch/test_hello_world.ts 8112849854')
    process.exit(1)
  }

  if (!token || !phoneId) {
    console.error('Credentials not configured in .env file.')
    process.exit(1)
  }

  const cleanPhone = testPhone.replace(/\D/g, '')
  console.log(`Sending test "hello_world" template message to ${cleanPhone}...`)

  try {
    const res = await fetch(`https://graph.facebook.com/v20.0/${phoneId}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to: cleanPhone,
        type: 'template',
        template: {
          name: 'hello_world',
          language: { code: 'en_us' },
        },
      }),
    })

    const data = await res.json()
    if (!res.ok) {
      console.error('Meta API error response:', JSON.stringify(data, null, 2))
      process.exit(1)
    }

    console.log('\n✅ Success! The "hello_world" message was successfully sent.')
    console.log('API Response:', JSON.stringify(data, null, 2))
    console.log('\nPlease check WhatsApp on your phone. You should receive a standard welcome message from your business number!')
  } catch (err) {
    console.error('Connection error:', err)
    process.exit(1)
  }
}

main()
