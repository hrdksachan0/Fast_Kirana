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
