import { Resend } from 'resend'

const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null

const fromEmail = process.env.EMAIL_FROM || 'FastKirana <onboarding@resend.dev>'

export async function sendOtpEmail(email: string, otp: string) {
  console.log(`\n==============================================`)
  console.log(`[OTP Verification Code]`)
  console.log(`To: ${email}`)
  console.log(`OTP: ${otp}`)
  console.log(`==============================================\n`)

  const htmlContent = `
    <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 0; background-color: #ffffff;">
      <!-- Header -->
      <div style="background: linear-gradient(135deg, #e20a22, #ff4d62); padding: 32px 24px; text-align: center; border-radius: 12px 12px 0 0;">
        <h1 style="color: #ffffff; font-size: 24px; font-weight: 800; margin: 0; letter-spacing: -0.5px;">FastKirana</h1>
        <p style="color: rgba(255,255,255,0.85); font-size: 12px; margin: 6px 0 0; font-weight: 600;">Fast Grocery Delivery</p>
      </div>
      
      <!-- Body -->
      <div style="padding: 32px 24px; border: 1px solid #f0f0f0; border-top: none;">
        <p style="color: #333; font-size: 15px; margin: 0 0 8px; font-weight: 600;">Hello,</p>
        <p style="color: #555; font-size: 14px; margin: 0 0 24px; line-height: 1.5;">Use this one-time password to verify your email and sign in to your FastKirana account:</p>
        
        <!-- OTP Box -->
        <div style="background: linear-gradient(135deg, #fafafa, #f5f5f5); border: 2px solid #e20a22; border-radius: 12px; padding: 20px; text-align: center; margin: 0 0 24px;">
          <span style="font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #1a1a2e; font-family: 'Courier New', monospace;">${otp}</span>
        </div>
        
        <p style="color: #888; font-size: 12px; margin: 0 0 4px;">⏱ This code expires in <strong>5 minutes</strong></p>
        <p style="color: #888; font-size: 12px; margin: 0;">If you didn't request this code, you can safely ignore this email.</p>
      </div>
      
      <!-- Footer -->
      <div style="padding: 16px 24px; text-align: center; border: 1px solid #f0f0f0; border-top: none; border-radius: 0 0 12px 12px; background: #fafafa;">
        <p style="color: #aaa; font-size: 11px; margin: 0;">© ${new Date().getFullYear()} FastKirana · Fast Grocery Delivery</p>
      </div>
    </div>
  `

  if (resend) {
    try {
      const resendFrom = fromEmail.includes('@gmail.com') || fromEmail.includes('@yahoo.com') || fromEmail.includes('@outlook.com')
        ? 'onboarding@resend.dev'
        : fromEmail

      const { data, error } = await resend.emails.send({
        from: resendFrom,
        to: email,
        subject: `${otp} is your FastKirana verification code`,
        html: htmlContent,
      })
      
      if (error) {
        console.error('Error response from Resend API:', error)
      } else {
        console.log(`OTP email sent successfully via Resend to: ${email}, ID: ${data?.id}`)
      }
    } catch (error) {
      console.error('Error sending email via Resend:', error)
    }
  } else {
    console.warn('Resend is not configured (RESEND_API_KEY missing). Email NOT sent.')
  }
}
