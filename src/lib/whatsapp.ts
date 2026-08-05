import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'

export async function sendWhatsAppOtp(phone: string, otp: string): Promise<boolean> {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const templateName = process.env.WHATSAPP_TEMPLATE_NAME

  if (!token || !phoneId) {
    return false
  }

  // Normalize phone to WhatsApp format (no +, country code included)
  const cleanPhone = normalizePhone(phone)

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

    return true
  } catch (err) {
    console.error('Meta WhatsApp API connection error:', err)
    return false
  }
}

export async function sendWhatsAppOrderAlert(phone: string, textParam: string): Promise<boolean> {
  const token = process.env.WHATSAPP_TOKEN
  const phoneId = process.env.WHATSAPP_PHONE_NUMBER_ID
  const templateName = process.env.WHATSAPP_ORDER_TEMPLATE_NAME

  if (!token || !phoneId || !templateName) {
    return false
  }

  const cleanPhone = normalizePhone(phone)

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

    return true
  } catch (err) {
    console.error('Meta WhatsApp Order Alert API connection error:', err)
    return false
  }
}
