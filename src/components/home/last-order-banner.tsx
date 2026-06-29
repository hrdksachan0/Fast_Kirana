'use client'

import { useState, useEffect } from 'react'
import Link from 'next/link'
import { useSession } from 'next-auth/react'
import { formatPrice } from '@/lib/utils'
import { Package, ArrowRight, Clock, MapPin, RefreshCw, CheckCircle2, Truck, Sparkles, XCircle } from 'lucide-react'

interface LastOrder {
  id: string
  status: string
  total: number
  createdAt: string
  paymentMethod: string
  items: { id: string; name: string; quantity: number }[]
  address?: { area: string; city: string }
}

const STATUS_CONFIG: Record<string, { label: string; color: string; iconClass: string }> = {
  PENDING: { 
    label: 'Pending', 
    color: 'bg-amber-500/10 text-amber-600 border-amber-500/20',
    iconClass: 'bg-amber-500/10 text-amber-600 border border-amber-500/20'
  },
  CONFIRMED: { 
    label: 'Confirmed', 
    color: 'bg-blue-500/10 text-blue-600 border-blue-500/20',
    iconClass: 'bg-blue-500/10 text-blue-600 border border-blue-500/20'
  },
  PACKED: { 
    label: 'Packed', 
    color: 'bg-purple-500/10 text-purple-600 border-purple-500/20',
    iconClass: 'bg-purple-500/10 text-purple-600 border border-purple-500/20'
  },
  SHIPPED: { 
    label: 'Out for Delivery', 
    color: 'bg-primary/10 text-primary border-primary/20',
    iconClass: 'bg-primary/10 text-primary border border-primary/20'
  },
  DELIVERED: { 
    label: 'Delivered', 
    color: 'bg-accent/10 text-accent border-accent/20',
    iconClass: 'bg-accent/10 text-accent border border-accent/20'
  },
  CANCELLED: { 
    label: 'Cancelled', 
    color: 'bg-red-500/10 text-red-600 border-red-500/20',
    iconClass: 'bg-red-500/10 text-red-600 border border-red-500/20'
  },
}

const statusIconMap: Record<string, React.ComponentType<any>> = {
  PENDING: Clock,
  CONFIRMED: CheckCircle2,
  PACKED: Package,
  SHIPPED: Truck,
  DELIVERED: Sparkles,
  CANCELLED: XCircle,
}

export function LastOrderBanner() {
  const { data: session, status: authStatus } = useSession()
  const [lastOrder, setLastOrder] = useState<LastOrder | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (authStatus === 'authenticated') {
      fetchLastOrder()
    }
  }, [authStatus])

  useEffect(() => {
    if (!lastOrder) return
    const isActive = !['DELIVERED', 'CANCELLED'].includes(lastOrder.status)
    if (!isActive) return

    const pollInterval = setInterval(async () => {
      try {
        const res = await fetch(`/api/orders/${lastOrder.id}`)
        if (res.ok) {
          const data = await res.json()
          if (data && data.status && data.status !== lastOrder.status) {
            setLastOrder((prev) => prev ? { ...prev, status: data.status } : null)
          }
        }
      } catch (err) {
        console.error('Error polling last order status in banner:', err)
      }
    }, 5000)

    return () => {
      clearInterval(pollInterval)
    }
  }, [lastOrder?.id, lastOrder?.status])

  const fetchLastOrder = async () => {
    setIsLoading(true)
    try {
      const res = await fetch('/api/orders')
      if (res.ok) {
        const orders = await res.json()
        if (orders.length > 0) {
          setLastOrder(orders[0])
        }
      }
    } catch (err) {
      // Silently fail — this is a non-critical feature
    } finally {
      setIsLoading(false)
    }
  }

  const isActive = lastOrder ? !['DELIVERED', 'CANCELLED'].includes(lastOrder.status) : false;

  if (authStatus !== 'authenticated' || isLoading || !lastOrder || !isActive) return null;

  const config = STATUS_CONFIG[lastOrder.status] || STATUS_CONFIG.PENDING
  const timeAgo = getTimeAgo(lastOrder.createdAt)

  return (
    <div className="fixed bottom-[68px] md:bottom-6 left-4 right-4 md:left-auto md:right-6 md:w-[360px] z-[40] animate-slide-up pointer-events-auto">
      <Link
        href={`/order/${lastOrder.id}/track`}
        className="block group"
      >
        <div className="relative overflow-hidden rounded-2xl border border-primary/35 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-md p-3.5 shadow-xl transition-all duration-350 hover:shadow-2xl hover:border-primary/50">
          
          {/* Active order pulse indicator */}
          <div className="absolute top-3.5 right-3.5">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-accent"></span>
            </span>
          </div>

          <div className="flex items-center gap-3">
            {/* Icon */}
            <div className={`flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-xl transition-all duration-300 ${config.iconClass}`}>
              {(() => {
                const IconComp = statusIconMap[lastOrder.status] || Clock
                return <IconComp className="h-5 w-5 stroke-[1.8]" />
              })()}
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0 text-left">
              <div className="flex items-center gap-2 mb-0.5">
                <span className={`text-[9px] font-black px-2 py-0.5 rounded-full border ${config.color}`}>
                  {config.label}
                </span>
                <span className="text-[9px] text-text-muted font-bold flex items-center gap-0.5">
                  <Clock className="h-2.5 w-2.5" />
                  {timeAgo}
                </span>
              </div>
              <p className="text-xs font-bold text-text-primary truncate">
                {lastOrder.items.map(i => `${i.name} ×${i.quantity}`).join(', ')}
              </p>
            </div>

            {/* Arrow */}
            <div className="flex items-center justify-center h-8 w-8 rounded-full bg-primary/10 text-primary group-hover:bg-primary group-hover:text-white transition-all flex-shrink-0">
              <RefreshCw className="h-3.5 w-3.5 animate-spin-slow" />
            </div>
          </div>

          {/* Track bar for active orders */}
          <div className="mt-2.5 pt-2 border-t border-border/40">
            <div className="flex items-center gap-1">
              {['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED'].map((step, idx) => {
                const stepOrder = ['PENDING', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED']
                const currentIdx = stepOrder.indexOf(lastOrder.status)
                const isCompleted = idx <= currentIdx
                const isCurrent = idx === currentIdx
                return (
                  <div
                    key={step}
                    className={`flex-1 h-1.5 rounded-full transition-all ${
                      isCompleted 
                        ? isCurrent 
                          ? 'bg-accent animate-pulse' 
                          : 'bg-accent' 
                        : 'bg-border/30 dark:bg-zinc-800/60'
                    }`}
                  />
                )
              })}
            </div>
            <p className="text-[9px] font-black text-accent mt-1.5 text-center">
              Active Delivery • Tap to track details →
            </p>
          </div>
        </div>
      </Link>
    </div>
  )
}

function getTimeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'Just now'
  if (mins < 60) return `${mins}m ago`
  const hrs = Math.floor(mins / 60)
  if (hrs < 24) return `${hrs}h ago`
  const days = Math.floor(hrs / 24)
  if (days === 1) return 'Yesterday'
  return `${days}d ago`
}
