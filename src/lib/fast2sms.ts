/**
 * Fast2SMS Gateway Integration for SMS Notifications
 * Documentation: https://www.fast2sms.com/dashboard/dev-api
 */

interface SendSmsOptions {
  numbers: string[] | string
  message: string
}

export async function sendFast2Sms({ numbers, message }: SendSmsOptions): Promise<boolean> {
  const apiKey = process.env.FAST2SMS_API_KEY
  if (!apiKey) {
    console.warn('[Fast2SMS] FAST2SMS_API_KEY not configured in environment')
    return false
  }

  // Normalize phone numbers to 10-digit comma-separated string
  const rawList = Array.isArray(numbers) ? numbers : [numbers]
  const cleanNumbers = rawList
    .map((n) => n.replace(/\D/g, '').slice(-10))
    .filter((n) => n.length === 10)

  if (cleanNumbers.length === 0) {
    console.warn('[Fast2SMS] No valid 10-digit numbers provided')
    return false
  }

  const destinationString = cleanNumbers.join(',')

  try {
    const res = await fetch('https://www.fast2sms.com/dev/bulkV2', {
      method: 'POST',
      headers: {
        authorization: apiKey.trim(),
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        route: 'v3',
        sender_id: 'TXTIND',
        message: message,
        language: 'english',
        flash: 0,
        numbers: destinationString,
      }),
      signal: AbortSignal.timeout(6000),
    })

    const data = await res.json()
    if (res.ok && data?.return === true) {
      console.log(`[Fast2SMS] Successfully sent message to ${destinationString}`)
      return true
    } else {
      console.warn('[Fast2SMS] Gateway error response:', data)
      return false
    }
  } catch (err: any) {
    console.error('[Fast2SMS] Connection or timeout error:', err?.message || err)
    return false
  }
}
