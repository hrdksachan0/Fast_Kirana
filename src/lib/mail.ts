export async function sendOtpEmail(email: string, otp: string) {
  console.log(`\n==============================================`)
  console.log(`[OTP Verification Code]`)
  console.log(`To: ${email}`)
  console.log(`OTP: ${otp}`)
  console.log(`==============================================\n`)
}
