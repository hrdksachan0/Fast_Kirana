export async function sendFast2SmsOtp(phone: string, otp: string): Promise<boolean> {
  const apiKey = process.env.FAST2SMS_API_KEY;

  if (!apiKey || apiKey === "YOUR_FAST2SMS_DEV_API_KEY_HERE" || apiKey === "") {
    console.log(`[Fast2SMS Mock] API key not configured. Logged OTP for ${phone}: ${otp}`);
    return false;
  }

  // Extract last 10 digits (Fast2SMS needs 10-digit Indian numbers without +91)
  const cleanPhone = phone.replace(/\D/g, '').slice(-10);

  if (cleanPhone.length !== 10) {
    console.error(`[Fast2SMS Error] Invalid 10-digit phone number: ${phone}`);
    return false;
  }

  try {
    const res = await fetch("https://www.fast2sms.com/dev/bulkV2", {
      method: "POST",
      headers: {
        "authorization": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        route: "otp",
        variables_values: otp,
        numbers: cleanPhone,
      }),
    });

    const data = await res.json();
    if (!res.ok || !data.return) {
      console.error("[Fast2SMS API Error]:", data);
      return false;
    }

    console.log(`[Fast2SMS Success] OTP sent successfully to ${cleanPhone}. Request ID: ${data.request_id}`);
    return true;
  } catch (err) {
    console.error("[Fast2SMS Connection Error]:", err);
    return false;
  }
}
