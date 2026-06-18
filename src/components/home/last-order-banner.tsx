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

    const eventSource = new EventSource(`/api/orders/${lastOrder.id}/live`)

    eventSource.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data.status && data.status !== lastOrder.status) {
          setLastOrder((prev) => prev ? { ...prev, status: data.status } : null)
        }
      } catch (err) {
        console.error('Error parsing SSE event in last-order-banner:', err)
      }
    }

    eventSource.onerror = (err) => {
      console.error('EventSource connection error in last-order-banner:', err)
      eventSource.close()
    }

    return () => {
      eventSource.close()
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

  if (authStatus !== 'authenticated' || isLoading || !lastOrder) return null

  const config = STATUS_CONFIG[lastOrder.status] || STATUS_CONFIG.PENDING
  const timeAgo = getTimeAgo(lastOrder.createdAt)
  const isActive = !['DELIVERED', 'CANCELLED'].includes(lastOrder.status)

  return (
    <Link
      href={isActive ? `/order/${lastOrder.id}/track` : `/account`}
      className="block group"
    >
      <div className={`relative overflow-hidden rounded-2xl border ${isActive ? 'border-primary/30 bg-primary/[0.03]' : 'border-border bg-card'} p-4 shadow-sm transition-all duration-300 hover:shadow-md hover:border-primary/40`}>
        
        {/* Active order pulse indicator */}
        {isActive && (
          <div className="absolute top-3 right-3">
            <span className="relative flex h-2.5 w-2.5">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-accent opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-accent"></span>
            </span>
          </div>
        )}

        <div className="flex items-center gap-3.5">
          {/* Icon */}
          <div className={`flex h-11 w-11 flex-shrink-0 items-center justify-center rounded-xl transition-all duration-300 ${isActive ? config.iconClass : 'bg-muted/60 text-text-secondary border border-border/40'}`}>
            {(() => {
              const IconComp = statusIconMap[lastOrder.status] || Clock
              return <IconComp className="h-5 w-5 stroke-[1.5]" />
            })()}
          </div>

          {/* Info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-0.5">
              <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${config.color}`}>
                {config.label}
              </span>
              <span className="text-[10px] text-text-muted font-medium flex items-center gap-0.5">
                <Clock className="h-2.5 w-2.5" />
                {timeAgo}
              </span>
            </div>
            <p className="text-xs font-bold text-text-primary truncate">
              {lastOrder.items.map(i => `${i.name} ×${i.quantity}`).join(', ')}
            </p>
            <div className="flex items-center gap-2 mt-0.5">
              <span className="text-xs font-extrabold text-text-primary">{formatPrice(lastOrder.total)}</span>
              {lastOrder.address && (
                <span className="text-[10px] text-text-muted flex items-center gap-0.5">
                  <MapPin className="h-2.5 w-2.5" />
                  {lastOrder.address.area}
                </span>
              )}
            </div>
          </div>

          {/* Arrow */}
          <div className="flex items-center justify-center h-8 w-8 rounded-full bg-primary/10 text-primary group-hover:bg-primary group-hover:text-white transition-colors flex-shrink-0">
            {isActive ? (
              <RefreshCw className="h-3.5 w-3.5" />
            ) : (
              <ArrowRight className="h-3.5 w-3.5" />
            )}
          </div>
        </div>

        {/* Track bar for active orders */}
        {isActive && (
          <div className="mt-3 pt-2 border-t border-border/40">
            <div className="flex items-center gap-1.5">
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
                        : 'bg-border/60'
                    }`}
                  />
                )
              })}
            </div>
            <p className="text-[9px] font-bold text-accent mt-1.5 text-center">
              {isActive ? 'Tap to track your order →' : 'View order details →'}
            </p>
          </div>
        )}
      </div>
    </Link>
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
