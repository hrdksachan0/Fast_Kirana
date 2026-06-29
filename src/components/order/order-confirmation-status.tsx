'use client'

import { useState, useEffect } from 'react'
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
  const [status, setStatus] = useState<string>(initialStatus)

  useEffect(() => {
    if (status === 'DELIVERED' || status === 'CANCELLED') return

    const pollInterval = setInterval(async () => {
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
    }, 5000)

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
    </div>
  )
}
