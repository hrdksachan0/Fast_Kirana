export async function sendWhatsAppOtp(phone: string, otp: string): Promise<boolean> {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME

  if (!token || !phoneId) {
    console.log(`[WhatsApp Mock] Credentials not configured. Logged OTP for ${phone}: ${otp}`)
    return false
  }

  // Clean phone number to digits only (e.g. +919876543210 -> 919876543210)
  const cleanPhone = phone.replace(/\D/g, '')

  try {
    let body: any = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: cleanPhone,
    }

    if (templateName) {
      body = {
        ...body,
        type: 'template',
        template: {
          name: templateName,
          language: { code: process.env.WHATSAPP_TEMPLATE_LANG || 'en' },
          components: [
            {
              type: 'body',
              parameters: templateName === 'fastkirana_otp' 
                ? [
                    {
                      type: 'text',
                      text: 'Customer',
                    },
                    {
                      type: 'text',
                      text: otp,
                    },
                  ]
                : [
                    {
                      type: 'text',
                      text: otp,
                    },
                  ],
            },
          ],
        },
      }
    } else {
      body = {
        ...body,
        type: 'text',
        text: {
          body: `Your FastKirana verification code is: ${otp}. Valid for 5 minutes.`,
        },
      }
    }

    const res = await fetch(`https://graph.facebook.com/v20.0/${phoneId}/messages`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    })

    const data = await res.json()
    if (!res.ok) {
      console.error('Meta WhatsApp API error response:', data)
      return false
    }

    console.log(`[WhatsApp Success] Message sent to ${phone} successfully.`)
    return true
  } catch (err) {
    console.error('Meta WhatsApp API connection error:', err)
    return false
  }
}
