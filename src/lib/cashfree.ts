import crypto from 'crypto'

const CASHFREE_APP_ID = process.env.CASHFREE_APP_ID || ''
const CASHFREE_SECRET_KEY = process.env.CASHFREE_SECRET_KEY || ''
const CASHFREE_ENV = process.env.CASHFREE_ENV || 'PRODUCTION'
const CASHFREE_API_VERSION = process.env.CASHFREE_API_VERSION || '2023-08-01'

const BASE_URL = CASHFREE_ENV === 'PRODUCTION'
  ? 'https://api.cashfree.com/pg'
  : 'https://sandbox.cashfree.com/pg'

export interface CreateCashfreeOrderParams {
  orderId: string
  amount: number
  customerId: string
  customerName?: string | null
  customerEmail?: string | null
  customerPhone: string
  returnUrl?: string
  notifyUrl?: string
  note?: string
}

export interface CashfreeOrderResponse {
  cf_order_id: string
  order_id: string
  order_status: 'ACTIVE' | 'PAID' | 'EXPIRED'
  payment_session_id: string
  order_amount: number
  order_currency: string
}

export interface CashfreePaymentRecord {
  cf_payment_id: number | string
  order_id: string
  payment_status: 'SUCCESS' | 'FAILED' | 'USER_DROPPED' | 'PENDING'
  payment_amount: number
  payment_currency: string
  payment_message: string
  payment_time: string
  payment_method: any
}

function getHeaders() {
  if (!CASHFREE_APP_ID || !CASHFREE_SECRET_KEY) {
    throw new Error('Cashfree credentials missing in environment variables (CASHFREE_APP_ID / CASHFREE_SECRET_KEY)')
  }

  return {
    'Content-Type': 'application/json',
    'x-api-version': CASHFREE_API_VERSION,
    'x-client-id': CASHFREE_APP_ID,
    'x-client-secret': CASHFREE_SECRET_KEY,
  }
}

/**
 * Creates an order in Cashfree Payment Gateway to generate payment_session_id
 */
export async function createCashfreeOrder(params: CreateCashfreeOrderParams): Promise<CashfreeOrderResponse> {
  const cleanPhone = params.customerPhone.replace(/\D/g, '').slice(-10)
  const phone = cleanPhone.length === 10 ? cleanPhone : '9999999999'

  // Cashfree requires clean order_id (alphanumeric, underscore, hyphen, max 50 chars)
  const sanitizedOrderId = params.orderId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45)

  const payload: any = {
    order_id: sanitizedOrderId,
    order_amount: parseFloat(params.amount.toFixed(2)),
    order_currency: 'INR',
    customer_details: {
      customer_id: params.customerId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45),
      customer_name: (params.customerName && params.customerName.trim().length > 0)
        ? params.customerName.trim().slice(0, 50)
        : 'FastKirana Customer',
      customer_email: (params.customerEmail && params.customerEmail.includes('@'))
        ? params.customerEmail.trim()
        : 'customer@fastkirana.in',
      customer_phone: phone,
    },
    order_meta: {
      return_url: params.returnUrl || `${process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'}/order/${params.orderId}?payment=cf_success`,
      notify_url: params.notifyUrl || `${process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'}/api/payment/cashfree/webhook`,
    },
    order_note: params.note || 'FastKirana Quick Commerce Order',
  }

  const response = await fetch(`${BASE_URL}/orders`, {
    method: 'POST',
    headers: getHeaders(),
    body: JSON.stringify(payload),
  })

  const data = await response.json()

  if (!response.ok) {
    const message = data?.message || data?.error || JSON.stringify(data)
    throw new Error(`Cashfree order creation failed (${response.status}): ${message}`)
  }

  return data as CashfreeOrderResponse
}

/**
 * Fetches order details from Cashfree
 */
export async function getCashfreeOrder(orderId: string): Promise<CashfreeOrderResponse> {
  const sanitizedOrderId = orderId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45)
  const response = await fetch(`${BASE_URL}/orders/${sanitizedOrderId}`, {
    method: 'GET',
    headers: getHeaders(),
  })

  const data = await response.json()
  if (!response.ok) {
    throw new Error(`Cashfree getOrder failed (${response.status}): ${data?.message || JSON.stringify(data)}`)
  }

  return data as CashfreeOrderResponse
}

/**
 * Fetches all payments for a given Cashfree order
 */
export async function getCashfreeOrderPayments(orderId: string): Promise<CashfreePaymentRecord[]> {
  const sanitizedOrderId = orderId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45)
  const response = await fetch(`${BASE_URL}/orders/${sanitizedOrderId}/payments`, {
    method: 'GET',
    headers: getHeaders(),
  })

  const data = await response.json()
  if (!response.ok) {
    throw new Error(`Cashfree getOrderPayments failed (${response.status}): ${data?.message || JSON.stringify(data)}`)
  }

  return Array.isArray(data) ? data : []
}

/**
 * Checks if Cashfree credentials are configured in environment variables
 */
export function isCashfreeConfigured(): boolean {
  return Boolean(CASHFREE_APP_ID && CASHFREE_SECRET_KEY)
}

export interface CashfreeUpiQrResult {
  upiUri?: string
  qrImageUrl?: string
  cfPaymentId?: string | number
  channel?: string
  raw?: any
}

/**
 * Generates a dynamic UPI QR Code session for an existing Cashfree order
 */
export async function createCashfreeUpiQrSession(paymentSessionId: string): Promise<CashfreeUpiQrResult> {
  const response = await fetch(`${BASE_URL}/orders/sessions`, {
    method: 'POST',
    headers: getHeaders(),
    body: JSON.stringify({
      payment_session_id: paymentSessionId,
      payment_method: {
        upi: {
          channel: 'qrcode'
        }
      }
    })
  })

  const data = await response.json()
  if (!response.ok) {
    const msg = data?.message || data?.error || JSON.stringify(data)
    throw new Error(`Cashfree UPI QR session failed (${response.status}): ${msg}`)
  }

  const upiUri = data?.data?.url || data?.data?.payload?.qrcode_url || ''
  const base64Qr = data?.data?.payload?.qrcode || ''
  let qrImageUrl = ''

  if (base64Qr) {
    qrImageUrl = base64Qr.startsWith('data:') ? base64Qr : `data:image/png;base64,${base64Qr}`
  } else if (upiUri) {
    qrImageUrl = `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(upiUri)}`
  }

  return {
    upiUri,
    qrImageUrl,
    cfPaymentId: data?.cf_payment_id,
    channel: data?.channel || 'qrcode',
    raw: data,
  }
}

/**
 * Creates a Cashfree Payment Link (alternative dynamic QR source)
 */
export async function createCashfreePaymentLink(params: {
  linkId: string
  amount: number
  customerPhone: string
  customerName?: string
  customerEmail?: string
  purpose: string
  returnUrl?: string
  notifyUrl?: string
}): Promise<{ linkId: string; linkUrl: string; linkQrUrl: string }> {
  const cleanPhone = params.customerPhone.replace(/\D/g, '').slice(-10)
  const phone = cleanPhone.length === 10 ? cleanPhone : '9999999999'

  const payload = {
    link_id: params.linkId.replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 45),
    link_amount: parseFloat(params.amount.toFixed(2)),
    link_currency: 'INR',
    link_purpose: params.purpose.slice(0, 100),
    customer_details: {
      customer_phone: phone,
      customer_name: (params.customerName || 'FastKirana Customer').slice(0, 50),
      customer_email: params.customerEmail && params.customerEmail.includes('@')
        ? params.customerEmail
        : 'customer@fastkirana.in',
    },
    link_meta: {
      return_url: params.returnUrl || `${process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'}/order/${params.linkId}`,
      notify_url: params.notifyUrl || `${process.env.NEXT_PUBLIC_APP_URL || 'https://fastkirana.in'}/api/payment/cashfree/webhook`,
    },
    link_notify: {
      send_sms: false,
      send_email: false,
    }
  }

  const response = await fetch(`${BASE_URL}/links`, {
    method: 'POST',
    headers: getHeaders(),
    body: JSON.stringify(payload),
  })

  const data = await response.json()
  if (!response.ok) {
    const msg = data?.message || data?.error || JSON.stringify(data)
    throw new Error(`Cashfree payment link creation failed (${response.status}): ${msg}`)
  }

  const linkUrl = data?.link_url || ''
  const linkQrUrl = linkUrl
    ? `https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${encodeURIComponent(linkUrl)}`
    : ''

  return {
    linkId: data?.link_id,
    linkUrl,
    linkQrUrl,
  }
}

/**
 * Checks if a Cashfree order has been successfully paid
 */
export async function checkCashfreeOrderPaid(orderId: string): Promise<{
  isPaid: boolean
  paymentId?: string
  paymentTime?: string
  paymentMethod?: string
}> {
  try {
    const cfOrder = await getCashfreeOrder(orderId)
    if (cfOrder && cfOrder.order_status === 'PAID') {
      return { isPaid: true }
    }
  } catch (e) {
    // Continue to check payments list
  }

  try {
    const payments = await getCashfreeOrderPayments(orderId)
    const successPayment = payments.find(p => p.payment_status === 'SUCCESS')
    if (successPayment) {
      return {
        isPaid: true,
        paymentId: String(successPayment.cf_payment_id || ''),
        paymentTime: successPayment.payment_time,
        paymentMethod: typeof successPayment.payment_method === 'object' ? 'UPI' : String(successPayment.payment_method || 'UPI')
      }
    }
  } catch (e) {
    // Non-fatal, return not paid
  }

  return { isPaid: false }
}

/**
 * Verifies Cashfree Webhook signature
 */
export function verifyCashfreeWebhookSignature(
  rawBody: string,
  timestamp: string,
  signature: string
): boolean {
  if (!CASHFREE_SECRET_KEY || !signature || !timestamp) return false

  try {
    const dataToSign = `${timestamp}${rawBody}`
    const expectedSignature = crypto
      .createHmac('sha256', CASHFREE_SECRET_KEY)
      .update(dataToSign)
      .digest('base64')

    const sigBuf = Buffer.from(signature)
    const expectedBuf = Buffer.from(expectedSignature)
    if (sigBuf.length !== expectedBuf.length) return false

    return crypto.timingSafeEqual(sigBuf, expectedBuf)
  } catch (err) {
    console.error('Error verifying Cashfree webhook signature:', err)
    return false
  }
}
