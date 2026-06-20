import 'dotenv/config'
import { Resend } from 'resend'

async function main() {
  const testEmail = process.argv[2]
  if (!testEmail) {
    console.error('Please provide a destination email to test. Example: npx tsx scratch/test_resend_email.ts user@example.com')
    process.exit(1)
  }

  const apiKey = process.env.RESEND_API_KEY
  if (!apiKey) {
    console.error('RESEND_API_KEY is not defined in .env file.')
    process.exit(1)
  }

  const resend = new Resend(apiKey)
  const fromEmail = process.env.EMAIL_FROM || 'FastKirana <onboarding@resend.dev>'
  const resendFrom = fromEmail.includes('@gmail.com') || fromEmail.includes('@yahoo.com') || fromEmail.includes('@outlook.com')
    ? 'onboarding@resend.dev'
    : fromEmail

  console.log('Sending test email via Resend...')
  console.log(`From: ${resendFrom}`)
  console.log(`To: ${testEmail}`)

  try {
    const result = await resend.emails.send({
      from: resendFrom,
      to: testEmail,
      subject: 'FastKirana Test Email',
      html: '<p>This is a test email from FastKirana to verify Resend delivery.</p>',
    })

    console.log('\n--- Resend API Response ---')
    console.log(JSON.stringify(result, null, 2))
    
    if (result.error) {
      console.error('\n❌ Resend returned an error:', result.error)
    } else {
      console.log('\n✅ Resend API accepted the request successfully!')
    }
  } catch (err) {
    console.error('❌ Exception during sending:', err)
  }
}

main()
