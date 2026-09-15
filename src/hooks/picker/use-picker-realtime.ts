'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { useSession } from 'next-auth/react'
import { toast } from 'sonner'
import { playNotificationChime, playSuccessChime } from '@/lib/audio'
import { supabase } from '@/lib/supabase-client'
import { triggerHaptic } from '@/lib/haptic'
import { Order } from './use-picker-types'
import { useAutoRefresh } from '@/hooks/use-auto-refresh'

interface UsePickerRealtimeProps {
  activeOrderRef: React.MutableRefObject<Order | null>
  setActiveOrder: React.Dispatch<React.SetStateAction<Order | null>>
  setPickedItemIds: React.Dispatch<React.SetStateAction<Record<string, number>>>
  isMultiPickingModeRef: React.MutableRefObject<boolean>
  multiActiveOrdersRef: React.MutableRefObject<Order[]>
  setMultiActiveOrders: React.Dispatch<React.SetStateAction<Order[]>>
  setMultiPickedItemIds: React.Dispatch<
    React.SetStateAction<Record<string, Record<string, number>>>
  >
  updatingIdRef: React.MutableRefObject<string | null>
}

export function usePickerRealtime({
  activeOrderRef,
  setActiveOrder,
  setPickedItemIds,
  isMultiPickingModeRef,
  multiActiveOrdersRef,
  setMultiActiveOrders,
  setMultiPickedItemIds,
  updatingIdRef,
}: UsePickerRealtimeProps) {
  const { status } = useSession()
  const [orders, setOrders] = useState<Order[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [currentTime, setCurrentTime] = useState(new Date())

  // Real-time clock
  useEffect(() => {
    const t = setInterval(() => setCurrentTime(new Date()), 1000)
    return () => clearInterval(t)
  }, [])

  // Audio alert and repeating chime when pending orders are in the queue
  useEffect(() => {
    if (status !== 'authenticated') return

    const pendingOrders = orders.filter((o) => o.status === 'PENDING')
    if (pendingOrders.length === 0) return

    playNotificationChime()
    triggerHaptic('success')
    toast.info('New pending order(s) in queue!', {
      id: 'new-order-alert',
      icon: '🛎️',
    })

    const intervalId = setInterval(() => {
      const currentPending = orders.filter((o) => o.status === 'PENDING')
      if (currentPending.length > 0) {
        playNotificationChime()
      } else {
        clearInterval(intervalId)
      }
    }, 5000)

    return () => clearInterval(intervalId)
  }, [orders, status])

  const fetchOrders = useCallback(async (silent = false) => {
    if (!silent) setIsLoading(true)

    try {
      const res = await fetch('/api/picker/orders')
      if (res.ok) {
        const data = await res.json()
        setOrders(data)

        const currentActive = activeOrderRef.current
        if (currentActive) {
          const freshActive = data.find((o: Order) => o.id === currentActive.id)
          if (freshActive) {
            setActiveOrder(freshActive)
          } else {
            if (updatingIdRef.current !== currentActive.id) {
              toast.error(
                'Active order is no longer in the queue (it may have been cancelled or claimed by another user).'
              )
              setActiveOrder(null)
              setPickedItemIds({})
            }
          }
        }

        if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
          const updatedMultiActive = multiActiveOrdersRef.current.map((mo) => {
            const fresh = data.find((o: Order) => o.id === mo.id)
            return fresh || mo
          })
          setMultiActiveOrders(updatedMultiActive)
        }
      } else {
        toast.error('Failed to fetch picker orders')
      }
    } catch (err) {
      toast.error('Error fetching picker queue')
    } finally {
      setIsLoading(false)
    }
  }, [
    activeOrderRef,
    isMultiPickingModeRef,
    multiActiveOrdersRef,
    setActiveOrder,
    setMultiActiveOrders,
    setPickedItemIds,
    updatingIdRef,
  ])

  // Shared 30-second auto-refresh countdown
  const { progress: refreshProgress, isRefreshing, triggerManualRefresh } = useAutoRefresh({
    fetchFn: () => fetchOrders(true),
    intervalSeconds: 30,
    enabled: status === 'authenticated',
  })

  // Initial fetch on authenticated mount
  useEffect(() => {
    if (status === 'authenticated') {
      fetchOrders(false)
    }
  }, [status, fetchOrders])

  // Connect to Supabase Realtime for order notifications
  useEffect(() => {
    if (status !== 'authenticated') return

    let updateTimeout: NodeJS.Timeout | null = null

    const channel = supabase
      .channel('picker-orders-live')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'orders',
        },
        (payload) => {
          if (payload.eventType === 'UPDATE') {
            const newOrder = payload.new as any
            const orderId = newOrder.id
            const newStatus = newOrder.status

            const currentActive = activeOrderRef.current
            if (currentActive && currentActive.id === orderId) {
              if (newStatus === 'CANCELLED') {
                toast.error('⚠️ The order you were picking has been CANCELLED by the customer!')
                setActiveOrder(null)
                setPickedItemIds({})
              } else if (newStatus === 'PACKED' && updatingIdRef.current !== orderId) {
                toast.info('⚠️ The active order has been packed by another picker.')
                setActiveOrder(null)
                setPickedItemIds({})
              }
            }

            if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
              const hasOrder = multiActiveOrdersRef.current.some((o) => o.id === orderId)
              if (hasOrder) {
                if (newStatus === 'CANCELLED') {
                  const cancelledOrder = multiActiveOrdersRef.current.find((o) => o.id === orderId)
                  toast.error(
                    `⚠️ Order for ${cancelledOrder?.user?.name || 'customer'} has been CANCELLED!`
                  )
                  setMultiActiveOrders((prev) => prev.filter((o) => o.id !== orderId))
                  setMultiPickedItemIds((prev) => {
                    const copy = { ...prev }
                    delete copy[orderId]
                    return copy
                  })
                } else if (newStatus === 'PACKED' && updatingIdRef.current !== orderId) {
                  const packedOrder = multiActiveOrdersRef.current.find((o) => o.id === orderId)
                  toast.info(
                    `⚠️ Order for ${packedOrder?.user?.name || 'customer'} was packed by another picker.`
                  )
                  setMultiActiveOrders((prev) => prev.filter((o) => o.id !== orderId))
                  setMultiPickedItemIds((prev) => {
                    const copy = { ...prev }
                    delete copy[orderId]
                    return copy
                  })
                }
              }
            }

            if (
              currentActive &&
              currentActive.companionOrder &&
              currentActive.companionOrder.id === orderId
            ) {
              if (newStatus === 'PACKED') {
                playSuccessChime()
                triggerHaptic('success')
                toast.success(`☕ Cafe items are ready for ${currentActive.user.name}!`, {
                  duration: 5000,
                  icon: '☕',
                })
              }
            }

            if (isMultiPickingModeRef.current && multiActiveOrdersRef.current.length > 0) {
              multiActiveOrdersRef.current.forEach((mo) => {
                if (mo.companionOrder && mo.companionOrder.id === orderId) {
                  if (newStatus === 'PACKED') {
                    playSuccessChime()
                    triggerHaptic('success')
                    toast.success(`☕ Cafe items ready for ${mo.user.name}!`, {
                      duration: 5000,
                      icon: '☕',
                    })
                  }
                }
              })
            }
          }

          if (payload.eventType === 'INSERT') {
            playNotificationChime()
            triggerHaptic('success')
            toast.info('New incoming order in queue!')
          }

          if (updateTimeout) clearTimeout(updateTimeout)
          updateTimeout = setTimeout(() => {
            fetchOrders(true)
          }, 1000)
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
      if (updateTimeout) clearTimeout(updateTimeout)
    }
  }, [
    status,
    activeOrderRef,
    isMultiPickingModeRef,
    multiActiveOrdersRef,
    fetchOrders,
    setActiveOrder,
    setMultiActiveOrders,
    setMultiPickedItemIds,
    updatingIdRef,
  ])

  return {
    orders,
    setOrders,
    isLoading,
    isRefreshing,
    currentTime,
    refreshProgress,
    fetchOrders,
    triggerManualRefresh,
  }
}
