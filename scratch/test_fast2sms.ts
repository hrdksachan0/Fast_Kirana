import 'dotenv/config'
import { sendFast2SmsOtp } from '../src/lib/fast2sms'

async function main() {
  const testPhone = process.argv[2]
  if (!testPhone) {
    console.error('Please provide a phone number to test. Example: npx tsx scratch/test_fast2sms.ts 9876543210')
    process.exit(1)
  }

  const testOtp = Math.floor(100000 + Math.random() * 900000).toString()
  console.log(`Sending test OTP ${testOtp} to ${testPhone} using Fast2SMS...`)

  const success = await sendFast2SmsOtp(testPhone, testOtp)
  if (success) {
    console.log('Test successful! OTP sent successfully via Fast2SMS.')
  } else {
    console.error('Test failed! Please check your FAST2SMS_API_KEY in .env, account balance, or DLT/OTP settings.')
  }
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
