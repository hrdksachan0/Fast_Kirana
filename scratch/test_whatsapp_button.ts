import 'dotenv/config'

async function main() {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const recipient = '+917054470303'
  const otp = '987654'

  if (!token || !phoneId) {
    console.error('Missing WHATSAPP_TOKEN or WHATSAPP_PHONE_NUMBER_ID')
    process.exit(1)
  }

  console.log(`Sending verify_otp template with button parameter to ${recipient}...`)

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
        to: recipient.replace(/\D/g, ''),
        type: 'template',
        template: {
          name: 'verify_otp',
          language: { code: 'en' },
          components: [
            {
              type: 'body',
              parameters: [
                {
                  type: 'text',
                  text: otp
                }
              ]
            },
            {
              type: 'button',
              sub_type: 'url',
              index: '0',
              parameters: [
                {
                  type: 'text',
                  text: otp
                }
              ]
            }
          ]
        }
      }),
    })

    const data = await res.json()
    if (res.ok) {
      console.log('✅ Success! Response:', JSON.stringify(data, null, 2))
    } else {
      console.error('❌ Failed:', JSON.stringify(data, null, 2))
    }
  } catch (err) {
    console.error('Error:', err)
  }
}

main()
