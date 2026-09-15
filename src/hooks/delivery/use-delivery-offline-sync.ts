'use client'

import { useState, useEffect, useCallback } from 'react'
import { toast } from 'sonner'

export function useDeliveryOfflineSync(onSyncComplete?: () => void) {
  const [isOffline, setIsOffline] = useState(false)
  const [offlineQueue, setOfflineQueue] = useState<any[]>([])

  useEffect(() => {
    if (typeof window === 'undefined') return
    setIsOffline(!navigator.onLine)

    const goOnline = () => {
      setIsOffline(false)
      toast.success('You are back online! Syncing local delivery updates...')
    }
    const goOffline = () => {
      setIsOffline(true)
      toast.warning('You are offline. Deliveries will be saved locally.')
    }

    window.addEventListener('online', goOnline)
    window.addEventListener('offline', goOffline)
    return () => {
      window.removeEventListener('online', goOnline)
      window.removeEventListener('offline', goOffline)
    }
  }, [])

  const syncOfflineUpdates = useCallback(async () => {
    if (typeof window === 'undefined') return
    const savedQueue = JSON.parse(localStorage.getItem('offline_delivery_updates') || '[]')
    if (savedQueue.length === 0) return

    toast.loading(`Syncing ${savedQueue.length} offline updates to server...`, {
      id: 'offline-sync',
    })
    let successCount = 0

    for (const item of savedQueue) {
      try {
        const res = await fetch(`/api/orders/${item.orderId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: item.newStatus, ...item.extraData }),
        })
        if (res.ok) {
          successCount++
        }
      } catch (err) {
        console.error('Failed to sync offline order update:', item.orderId, err)
      }
    }

    localStorage.setItem('offline_delivery_updates', '[]')
    setOfflineQueue([])

    toast.dismiss('offline-sync')
    if (successCount === savedQueue.length) {
      toast.success('Successfully synced all offline delivery status updates!')
    } else if (successCount > 0) {
      toast.warning(`Synced ${successCount} of ${savedQueue.length} updates. Some failed.`)
    }
    onSyncComplete?.()
  }, [onSyncComplete])

  useEffect(() => {
    if (!isOffline) {
      syncOfflineUpdates()
    }
  }, [isOffline, syncOfflineUpdates])

  return {
    isOffline,
    offlineQueue,
    setOfflineQueue,
    syncOfflineUpdates,
  }
}
