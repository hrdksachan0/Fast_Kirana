import { NextRequest, NextResponse } from 'next/server'
import crypto from 'crypto'
import { sendWhatsAppOtp } from '@/lib/whatsapp'
import { logger } from '@/lib/logger'

/**
 * Verifies Supabase Standard Webhook signature
 * Spec: https://www.standardwebhooks.com/
 */
function verifyStandardWebhook(
  rawBody: string,
  headers: Headers,
  secret: string
): boolean {
  const webhookId = headers.get('webhook-id')
  const webhookTimestamp = headers.get('webhook-timestamp')
  const webhookSignature = headers.get('webhook-signature')

  if (!webhookId || !webhookTimestamp || !webhookSignature) {
    return false
  }

  // Prevent replay attacks (5 minute window)
  const timestampSec = parseInt(webhookTimestamp, 10)
  const nowSec = Math.floor(Date.now() / 1000)
  if (isNaN(timestampSec) || Math.abs(nowSec - timestampSec) > 300) {
    return false
  }

  try {
    const cleanSecret = secret.startsWith('v1,whsec_') ? secret.slice('v1,whsec_'.length) : secret
    const key = Buffer.from(cleanSecret, 'base64')
    const signedPayload = `${webhookId}.${webhookTimestamp}.${rawBody}`
    const expectedHmac = crypto.createHmac('sha256', key).update(signedPayload).digest('base64')

    // Signatures can be space-separated list: "v1,<sig1> v1,<sig2>"
    const passedSignatures = webhookSignature.split(' ')
    for (const part of passedSignatures) {
      const sig = part.startsWith('v1,') ? part.slice(3) : part
      const sigBuf = Buffer.from(sig)
      const expectedBuf = Buffer.from(expectedHmac)
      if (sigBuf.length === expectedBuf.length && crypto.timingSafeEqual(sigBuf, expectedBuf)) {
        return true
      }
    }
  } catch (err) {
    logger.error('auth', 'Standard Webhook verification error:', err)
  }

  return false
}

/**
 * Supabase Auth Custom SMS / WhatsApp Provider Hook
 * 
 * Invoked by Supabase Auth engine when a phone OTP is requested.
 * Payload sent by Supabase:
 * {
 *   "user": {
 *     "id": "...",
 *     "phone": "+91XXXXXXXXXX"
 *   },
 *   "sms": {
 *     "otp": "123456"
 *   }
 * }
 */
export async function POST(req: NextRequest) {
  try {
    const rawBody = await req.text()
    const expectedSecret = process.env.SUPABASE_AUTH_HOOK_SECRET

    // 1. Verify Secret strictly (fail closed if secret is not configured)
    if (!expectedSecret || !expectedSecret.trim()) {
      logger.error('auth', 'SUPABASE_AUTH_HOOK_SECRET is not configured; rejecting webhook request')
      return NextResponse.json({ error: 'Server misconfiguration' }, { status: 500 })
    }

    const secret = expectedSecret.trim()
    const hasStandardHeaders = req.headers.get('webhook-signature')

    let isAuthorized = false
    if (hasStandardHeaders) {
      isAuthorized = verifyStandardWebhook(rawBody, req.headers, secret)
    } else {
      // Fallback: check direct header or bearer token
      const authHeader = req.headers.get('x-supabase-webhook-secret') ||
                         req.headers.get('authorization')?.replace(/^Bearer\s+/i, '')
      isAuthorized = authHeader === secret
    }

    if (!isAuthorized) {
      logger.warn('auth', 'Unauthorized Supabase auth hook attempt: signature or secret mismatch')
      return NextResponse.json({ error: 'Unauthorized webhook call' }, { status: 401 })
    }

    // 2. Parse payload
    let body: any = null
    try {
      body = JSON.parse(rawBody)
    } catch {
      return NextResponse.json({ error: 'Invalid JSON payload' }, { status: 400 })
    }

    // Extract phone and OTP defensively from Supabase payload schema
    const rawPhone = body?.user?.phone || body?.sms?.phone || body?.phone
    const otp = body?.sms?.otp || body?.otp || body?.code

    if (!rawPhone || !otp) {
      logger.warn('auth', 'Missing phone or OTP in Supabase auth hook payload', { hasPhone: Boolean(rawPhone), hasOtp: Boolean(otp) })
      return NextResponse.json({ error: 'Phone and OTP are required' }, { status: 400 })
    }

    const phoneStr = String(rawPhone).trim()
    const otpStr = String(otp).trim()

    logger.info('auth', `Sending Supabase WhatsApp OTP to ${phoneStr.slice(0, 5)}***`)

    // 3. Dispatch OTP via Meta WhatsApp Cloud API
    const isSent = await sendWhatsAppOtp(phoneStr, otpStr)

    if (!isSent) {
      logger.error('auth', `Meta WhatsApp Cloud API failed to deliver OTP to ${phoneStr.slice(0, 5)}***`)
      return NextResponse.json({ error: 'Failed to deliver OTP via WhatsApp' }, { status: 502 })
    }

    return NextResponse.json({
      success: true,
      message: 'OTP delivered successfully via WhatsApp',
    }, { status: 200 })

  } catch (error: any) {
    logger.error('auth', 'Unhandled error in Supabase WhatsApp hook:', error)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
