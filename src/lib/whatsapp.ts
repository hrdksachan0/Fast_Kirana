export async function sendWhatsAppOtp(phone: string, otp: string): Promise<boolean> {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME

  if (!token || !phoneId) {
    console.log(`[WhatsApp Mock] Credentials not configured. Logged OTP for ${phone}: ${otp}`)
    return false
  }

  // Clean phone number to digits only (e.g. +919876543210 -> 919876543210)
  let cleanPhone = phone.replace(/\D/g, '')
  if (cleanPhone.length === 10) {
    cleanPhone = '91' + cleanPhone
  }

  try {
    let body: any = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: cleanPhone,
    }

    if (templateName) {
      const components: any[] = [
        {
          type: 'body',
          parameters: [
            {
              type: 'text',
              text: otp,
            },
          ],
        },
      ]

      if (templateName === 'verify_otp') {
        components.push({
          type: 'button',
          sub_type: 'url',
          index: 0,
          parameters: [
            {
              type: 'text',
              text: otp,
            },
          ],
        })
      }

      body = {
        ...body,
        type: 'template',
        template: {
          name: templateName,
          language: { code: process.env.WHATSAPP_TEMPLATE_LANG || 'en' },
          components,
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

    console.log(`[WhatsApp Success] Message sent to ${phone} successfully. Response:`, JSON.stringify(data, null, 2))
    return true
  } catch (err) {
    console.error('Meta WhatsApp API connection error:', err)
    return false
  }
}

export async function sendWhatsAppOrderAlert(phone: string, textParam: string): Promise<boolean> {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const templateName = process.env.WHATSAPP_ORDER_TEMPLATE_NAME || 'fastkirana_otp'

  if (!token || !phoneId) {
    console.log(`[WhatsApp Mock Alert] Logged Order Alert to ${phone}: ${textParam}`)
    return false
  }

  let cleanPhone = phone.replace(/\D/g, '')
  if (cleanPhone.length === 10) {
    cleanPhone = '91' + cleanPhone
  }

  try {
    const body = {
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: cleanPhone,
      type: 'template',
      template: {
        name: templateName,
        language: { code: process.env.WHATSAPP_TEMPLATE_LANG || 'en' },
        components: [
          {
            type: 'body',
            parameters: [
              {
                type: 'text',
                text: textParam,
              },
            ],
          },
        ],
      },
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
      console.error('Meta WhatsApp Order Alert error response:', data)
      return false
    }

    console.log(`[WhatsApp Order Alert Success] Sent to ${phone} successfully. Response:`, JSON.stringify(data, null, 2))
    return true
  } catch (err) {
    console.error('Meta WhatsApp Order Alert API connection error:', err)
    return false
  }
}
