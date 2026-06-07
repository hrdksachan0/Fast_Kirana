import { Resend } from 'resend'

const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null

export async function sendOtpEmail(email: string, otp: string) {
  console.log(`\n==============================================`)
  console.log(`[OTP Verification Code]`)
  console.log(`To: ${email}`)
  console.log(`OTP: ${otp}`)
  console.log(`==============================================\n`)

  if (resend) {
    try {
      await resend.emails.send({
        from: 'FastKirana <onboarding@resend.dev>',
        to: email,
        subject: 'FastKirana Verification Code',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #eee; rounded: 12px;">
            <h2 style="color: #e20a22; text-align: center;">FastKirana</h2>
            <p>Hello,</p>
            <p>Your one-time password (OTP) verification code is:</p>
            <div style="font-size: 24px; font-weight: bold; text-align: center; padding: 15px; background-color: #f9f9f9; border-radius: 8px; letter-spacing: 4px; color: #1a1a2e; margin: 20px 0;">
              ${otp}
            </div>
            <p style="font-size: 12px; color: #666;">This code will expire in 5 minutes. If you did not request this code, please ignore this email.</p>
          </div>
        `,
      })
      console.log(`OTP email sent successfully via Resend to: ${email}`)
    } catch (error) {
      console.error('Error sending email via Resend:', error)
    }
  }
}
