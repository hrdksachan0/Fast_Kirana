import 'dotenv/config'

async function registerNumber() {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const pin = process.argv[2] || '123456'

  if (!token || !phoneId) {
    console.error('Error: WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID must be set in your .env file.')
    process.exit(1)
  }

  if (pin.length !== 6 || isNaN(Number(pin))) {
    console.error('Error: Pin must be a 6-digit numeric string.')
    process.exit(1)
  }

  console.log(`Attempting to register WhatsApp Phone Number ID: ${phoneId}...`)
  console.log(`Using Registration PIN: ${pin}`)

  try {
    const url = `https://graph.facebook.com/v20.0/${phoneId}/register`
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        pin: pin,
      }),
    })

    const data = await res.json()

    if (!res.ok) {
      console.error('\n❌ Registration failed!')
      console.error('Meta API Response:', JSON.stringify(data, null, 2))
      console.error('\nCommon reasons for failure:')
      console.error('1. The number has NOT been verified via SMS/Voice call in your Meta/WhatsApp Manager dashboard.')
      console.error('2. The number is still active on your phone\'s WhatsApp / WhatsApp Business app (you must delete the account from your phone app first).')
      console.error('3. The Display Name for this phone number is not approved yet.')
      process.exit(1)
    }

    console.log('\n✅ Success! Phone number registered successfully on Meta WhatsApp Cloud API.')
    console.log('API Response:', JSON.stringify(data, null, 2))
    console.log('You can now run: npx tsx scratch/test_whatsapp.ts <your_mobile_number> to test OTP delivery!')

  } catch (err) {
    console.error('Connection error:', err)
    process.exit(1)
  }
}

registerNumber()
