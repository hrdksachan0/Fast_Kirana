import 'dotenv/config'
import { sendWhatsAppOtp } from '../src/lib/whatsapp'

async function main() {
  const testPhone = process.argv[2]
  if (!testPhone) {
    console.error('Please provide a phone number to test. Example: npx tsx scratch/test_whatsapp.ts +919876543210')
    process.exit(1)
  }

  const testOtp = Math.floor(100000 + Math.random() * 900000).toString()
  console.log(`Sending test OTP ${testOtp} to ${testPhone}...`)

  const success = await sendWhatsAppOtp(testPhone, testOtp)
  if (success) {
    console.log('Test successful! OTP sent successfully.')
  } else {
    console.error('Test failed! Please check your Meta developer settings, token, or verified test numbers.')
  }
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
