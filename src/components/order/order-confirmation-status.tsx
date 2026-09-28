'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { motion } from 'framer-motion'
import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

interface OrderConfirmationStatusProps {
  orderId: string
  initialStatus: string
  deliveryMethod: string
}

export function OrderConfirmationStatus({
  orderId,
  initialStatus,
  deliveryMethod,
}: OrderConfirmationStatusProps) {
  const router = useRouter()
  const [status, setStatus] = useState<string>(initialStatus)
  const [countdown, setCountdown] = useState<number>(4)
  const [stayOnPage, setStayOnPage] = useState<boolean>(false)

  // Auto-redirect countdown to live order tracking
  useEffect(() => {
    if (stayOnPage) return

    const timer = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          clearInterval(timer)
          router.push(`/order/${orderId}/track`)
          return 0
        }
        return prev - 1
      })
    }, 1000)

    return () => clearInterval(timer)
  }, [orderId, router, stayOnPage])

  // Fast live polling for status changes (4 seconds instead of 45s)
  useEffect(() => {
    if (status === 'DELIVERED' || status === 'CANCELLED') return

    const pollInterval = setInterval(async () => {
      if (document.visibilityState !== 'visible') return
      try {
        const res = await fetch(`/api/orders/${orderId}`)
        if (res.ok) {
          const data = await res.json()
          if (data && data.status && data.status !== status) {
            setStatus(data.status)
          }
        }
      } catch (err) {
        console.error('Error polling order confirmation status:', err)
      }
    }, 4000)

    return () => {
      clearInterval(pollInterval)
    }
  }, [orderId, status])

  const statusProgress: Record<string, number> = {
    PENDING: 20,
    CONFIRMED: 40,
    PACKED: 60,
    SHIPPED: 80,
    DELIVERED: 100,
    CANCELLED: 100,
  }

  const progress = statusProgress[status] || 20

  const getStatusText = () => {
    if (status === 'PENDING') {
      return deliveryMethod === 'PICKUP'
        ? '🏪 Store pickup selected! Preparing your items.'
        : '⚡ Fast delivery active! Preparing your order.'
    }
    if (status === 'CONFIRMED') {
      return '🏪 Store has accepted your order and is processing it!'
    }
    if (status === 'PACKED') {
      return '📦 Order packed! Prepared with hygiene and care.'
    }
    if (status === 'SHIPPED') {
      return deliveryMethod === 'PICKUP'
        ? '🏪 Ready for Pickup! Collect your items at the hub.'
        : '🚴 Rider is carrying your order to your location!'
    }
    if (status === 'DELIVERED') {
      return deliveryMethod === 'PICKUP'
        ? '🎉 Picked up successfully! Enjoy your items.'
        : '🎉 Delivered successfully to your doorstep!'
    }
    if (status === 'CANCELLED') {
      return '❌ Order Cancelled.'
    }
    return 'Processing...'
  }

  return (
    <div className="mt-6 w-full max-w-xs space-y-3 mx-auto">
      <div className="flex justify-between text-[10px] text-text-muted font-bold px-1 uppercase tracking-wider">
        <span className={cn(status === 'PENDING' && 'text-primary font-black')}>Placed</span>
        <span className={cn(['CONFIRMED', 'PACKED', 'SHIPPED'].includes(status) && 'text-primary font-black')}>Processing</span>
        <span className={cn(status === 'DELIVERED' && 'text-primary font-black')}>
          {deliveryMethod === 'PICKUP' ? 'Picked Up' : 'Delivered'}
        </span>
      </div>
      
      {/* Progress Bar Container */}
      <div className="relative h-2 rounded-full bg-zinc-100 dark:bg-zinc-800 overflow-hidden">
        <motion.div
          initial={{ width: `${statusProgress[initialStatus] || 20}%` }}
          animate={{ width: `${progress}%` }}
          transition={{ type: 'spring', stiffness: 80, damping: 15 }}
          className={cn(
            "absolute inset-y-0 left-0 rounded-full h-full",
            status === 'CANCELLED' ? "bg-red-500" : "bg-accent"
          )}
        />
      </div>

      <p className={cn(
        "text-[10px] font-extrabold flex items-center justify-center gap-1 pt-1 text-center transition-colors duration-300",
        status === 'CANCELLED' ? "text-red-500" : "text-accent animate-pulse-gentle"
      )}>
        {status !== 'DELIVERED' && status !== 'CANCELLED' && (
          <Loader2 className="h-3.5 w-3.5 animate-spin text-primary shrink-0" />
        )}
        <span>{getStatusText()}</span>
      </p>

      {/* Auto-Navigation Countdown Card to Live Tracking */}
      {!stayOnPage && status !== 'CANCELLED' && (
        <motion.div
          initial={{ opacity: 0, y: 5 }}
          animate={{ opacity: 1, y: 0 }}
          className="mt-3 p-3 bg-zinc-900/95 dark:bg-zinc-800 text-white rounded-2xl flex items-center justify-between gap-3 text-left shadow-xl border border-white/10"
        >
          <div className="flex items-center gap-2.5 min-w-0">
            <span className="flex h-2.5 w-2.5 relative shrink-0">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-emerald-500"></span>
            </span>
            <div className="min-w-0">
              <p className="text-[11px] font-black leading-tight truncate">
                Opening live tracking in {countdown}s...
              </p>
              <p className="text-[9.5px] text-zinc-400 font-medium">Follow live kitchen &amp; rider status</p>
            </div>
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <button
              onClick={() => router.push(`/order/${orderId}/track`)}
              className="px-2.5 py-1 bg-primary text-white text-[10.5px] font-black rounded-xl hover:bg-primary/90 transition-all shadow-sm"
            >
              Track Now ⚡
            </button>
            <button
              onClick={() => setStayOnPage(true)}
              className="p-1 text-zinc-400 hover:text-white text-[10px] font-bold rounded-lg transition-colors"
              title="Stay on this summary"
            >
              ✕
            </button>
          </div>
        </motion.div>
      )}
    </div>
  )
}
