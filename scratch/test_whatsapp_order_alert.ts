import { sendWhatsAppOrderAlert } from '../src/lib/whatsapp'
import 'dotenv/config'

async function test() {
  process.env.WHATSAPP_TEMPLATE_LANG = 'en'
  process.env.WHATSAPP_ORDER_TEMPLATE_NAME = 'fastkirana_otp'
  const adminPhone = '7054470303'
  const sampleText = '123456'
  
  console.log(`Sending test WhatsApp order alert to ${adminPhone}...`)
  const success = await sendWhatsAppOrderAlert(adminPhone, sampleText)
  if (success) {
    console.log('✅ WhatsApp order alert sent successfully!')
  } else {
    console.error('❌ Failed to send WhatsApp order alert. Please check your console logs or Meta API responses above.')
  }

}

test()
