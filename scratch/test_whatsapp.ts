import dotenv from 'dotenv'
dotenv.config()

import { sendWhatsAppOrderAlert } from '../src/lib/whatsapp'

async function main() {
  const adminPhone = '7054470303'
  
  console.log('--- Test 1: Sending with default (fastkirana_otp) ---')
  process.env.WHATSAPP_ORDER_TEMPLATE_NAME = 'fastkirana_otp'
  const alertRes1 = await sendWhatsAppOrderAlert(adminPhone, 'Test Order Alert - OTP')
  console.log('Result 1:', alertRes1)

  console.log('\n--- Test 2: Sending with fastkirana_order ---')
  process.env.WHATSAPP_ORDER_TEMPLATE_NAME = 'fastkirana_order'
  const alertRes2 = await sendWhatsAppOrderAlert(adminPhone, 'Test Order Alert - Order')
  console.log('Result 2:', alertRes2)
}

main()
