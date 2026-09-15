'use client'

import { useEffect, useRef, useCallback } from 'react'

interface PaymentPollingOptions {
  /** The order ID to verify payment for */
  orderId: string
  /** Which Cashfree order ID (for Cashfree provider) */
  cfOrderId?: string
  /** Payment gateway provider */
  provider: 'cashfree' | 'razorpay'
  /** Whether polling is active */
  enabled: boolean
  /** Callback fired when payment is confirmed as PAID */
  onPaid: () => void
  /** Polling interval in milliseconds (default: 2500) */
  intervalMs?: number
  /** Maximum number of poll attempts before auto-stopping (default: 100) */
  maxPolls?: number
}

/**
 * Unified payment verification polling hook.
 *
 * Replaces 5 duplicated setInterval+fetch loops across:
 * - checkout/page.tsx (Cashfree + Razorpay = 2 loops)
 * - doorstep-pay/[orderId]/page.tsx (1 loop)
 * - components/order/pay-online-button.tsx (1 loop)
 * - delivery/components/upi-qr-modal.tsx (1 loop)
 *
 * Features:
 * - Auto-verify on document visibility change (user returns from PhonePe/GPay)
 * - Automatic cleanup on unmount
 * - Configurable interval and max poll count
 */
export function usePaymentPolling({
  orderId,
  cfOrderId,
  provider,
  enabled,
  onPaid,
  intervalMs = 2500,
  maxPolls = 100,
}: PaymentPollingOptions) {
  const pollCountRef = useRef(0)
  const isPaidRef = useRef(false)
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const onPaidRef = useRef(onPaid)
  onPaidRef.current = onPaid

  const verify = useCallback(async (): Promise<boolean> => {
    if (isPaidRef.current || !orderId) return false

    try {
      const endpoint =
        provider === 'cashfree'
          ? '/api/payment/cashfree/verify'
          : '/api/payment/razorpay/sync-order'

      const body =
        provider === 'cashfree'
          ? JSON.stringify({ orderId, cfOrderId })
          : JSON.stringify({ orderId })

      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
      })

      if (!res.ok) return false
      const data = await res.json()

      const isPaid =
        provider === 'cashfree'
          ? data.paymentStatus === 'PAID'
          : data.paymentStatus === 'PAID' || data.status === 'captured'

      if (isPaid) {
        isPaidRef.current = true
        if (intervalRef.current) {
          clearInterval(intervalRef.current)
          intervalRef.current = null
        }
        onPaidRef.current()
        return true
      }
    } catch {
      // Silently ignore network errors during polling
    }
    return false
  }, [orderId, cfOrderId, provider])

  // Main polling interval
  useEffect(() => {
    if (!enabled || !orderId || isPaidRef.current) return

    pollCountRef.current = 0

    intervalRef.current = setInterval(async () => {
      pollCountRef.current++
      if (pollCountRef.current > maxPolls || isPaidRef.current) {
        if (intervalRef.current) {
          clearInterval(intervalRef.current)
          intervalRef.current = null
        }
        return
      }
      await verify()
    }, intervalMs)

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current)
        intervalRef.current = null
      }
    }
  }, [enabled, orderId, intervalMs, maxPolls, verify])

  // Visibility change handler — auto-verify when user returns from UPI app
  useEffect(() => {
    if (!enabled || !orderId) return

    const handleVisibilityChange = async () => {
      if (document.visibilityState === 'visible' && !isPaidRef.current) {
        await verify()
      }
    }

    document.addEventListener('visibilitychange', handleVisibilityChange)
    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange)
    }
  }, [enabled, orderId, verify])

  // Reset when orderId changes
  useEffect(() => {
    isPaidRef.current = false
    pollCountRef.current = 0
  }, [orderId])

  return { verify, isPaid: isPaidRef.current }
}
