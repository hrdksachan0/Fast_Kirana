import 'dotenv/config'
import { sendOtpEmail } from '../src/lib/mail'

async function main() {
  const testEmail = process.argv[2]
  if (!testEmail) {
    console.error('Please provide a destination email to test. Example: npx tsx scratch/test_resend_email.ts user@example.com')
    process.exit(1)
  }

  const apiKey = process.env.RESEND_API_KEY
  console.log(`Checking Resend configuration...`)
  console.log(`RESEND_API_KEY: ${apiKey ? 'Configured (starts with ' + apiKey.substring(0, 5) + ')' : 'Not Configured'}`)

  console.log(`\nTesting Resend email OTP delivery to: ${testEmail}...`)
  try {
    await sendOtpEmail(testEmail, '987654')
    console.log('\n✅ Test execution completed.')
  } catch (err) {
    console.error('❌ Test execution failed:', err)
  }
}

main()
