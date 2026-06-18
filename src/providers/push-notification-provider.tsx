'use client'

import React, { createContext, useContext, useState, useEffect, useRef } from 'react'
import { toast } from 'sonner'
import { useSession } from 'next-auth/react'

function urlBase64ToUint8Array(base64String: string) {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/\-/g, '+').replace(/_/g, '/')
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i)
  }
  return outputArray
}

interface PushNotificationContextType {
  isSupported: boolean
  isIOS: boolean
  permission: NotificationPermission
  isSubscribed: boolean
  isLoading: boolean
  showSoftPrompt: boolean
  setShowSoftPrompt: (show: boolean) => void
  showPrompt: boolean
  subscribe: (onSuccessCallback?: () => void) => Promise<boolean>
  confirmSubscribe: () => Promise<boolean>
  dismiss: () => void
}

const PushNotificationContext = createContext<PushNotificationContextType | undefined>(undefined)

export function PushNotificationProvider({ children }: { children: React.ReactNode }) {
  const { status } = useSession()
  const [isSupported, setIsSupported] = useState(false)
  const [isIOS, setIsIOS] = useState(false)
  const [permission, setPermission] = useState<NotificationPermission>('default')
  const [isSubscribed, setIsSubscribed] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [showSoftPrompt, setShowSoftPrompt] = useState(false)
  const [showPrompt, setShowPrompt] = useState(true)
  
  const successCallbackRef = useRef<(() => void) | null>(null)

  useEffect(() => {
    if (typeof window === 'undefined') return

    const supported = 'serviceWorker' in navigator && 'PushManager' in window
    setIsSupported(supported)
    
    const ios = /iPad|iPhone|iPod/.test(navigator.userAgent)
    setIsIOS(ios)

    if (supported && 'Notification' in window) {
      setPermission(Notification.permission)
      
      navigator.serviceWorker.ready.then((registration) => {
        registration.pushManager.getSubscription().then((subscription) => {
          setIsSubscribed(!!subscription)
        })
      }).catch(err => console.log('Service worker not ready yet:', err))
    }

    const dismissed = localStorage.getItem('push-prompt-dismissed') === 'true'
    if (dismissed) {
      setShowPrompt(false)
    }
  }, [])

  const registerSubscription = async () => {
    try {
      // Prevent infinite loading state if service worker activation is delayed or blocked (e.g. non-secure local HTTP context)
      const timeoutPromise = new Promise<never>((_, reject) => 
        setTimeout(() => reject(new Error('Service Worker registration timed out')), 6000)
      )
      
      const registration = await Promise.race([
        navigator.serviceWorker.ready,
        timeoutPromise
      ]) as ServiceWorkerRegistration
      
      const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY || 'BPxeEdEbKwG5gG_jE6jT6ReXk516Pi1iszzLJSW3OHrpIg9UloqpDOlrfZISFl97PpBYMQHOoesTKtPAruF4QEw'

      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
      })

      const res = await fetch('/api/push/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subscription }),
      })

      if (!res.ok) {
        throw new Error('Failed to save subscription on server')
      }

      setIsSubscribed(true)
      toast.success('🎉 Notification subscriptions enabled!')
      
      if (successCallbackRef.current) {
        successCallbackRef.current()
        successCallbackRef.current = null
      }
      return true
    } catch (error: any) {
      console.error('Push registration error:', error)
      toast.error(`Failed to register notifications: ${error.message || error}`)
      return false
    }
  }

  const subscribe = async (onSuccessCallback?: () => void) => {
    if (!isSupported) {
      toast.error('Push notifications are not supported on this browser.')
      return false
    }

    if (onSuccessCallback) {
      successCallbackRef.current = onSuccessCallback
    }

    if (Notification.permission === 'granted') {
      setIsLoading(true)
      const success = await registerSubscription()
      setIsLoading(false)
      return success
    }

    if (Notification.permission === 'denied') {
      toast.error('Notifications are blocked by your browser settings. Please reset permissions in your address bar.')
      return false
    }

    // Default permission -> trigger Soft Prompt Dialog
    setShowSoftPrompt(true)
    return false
  }

  const confirmSubscribe = async () => {
    setShowSoftPrompt(false)
    setIsLoading(true)
    try {
      const result = await Notification.requestPermission()
      setPermission(result)

      if (result === 'granted') {
        const success = await registerSubscription()
        return success
      } else {
        toast.error('Permission denied. You can enable them later in settings.')
        return false
      }
    } catch (error) {
      console.error('Error during permission request:', error)
      return false
    } finally {
      setIsLoading(false)
    }
  }

  const dismiss = () => {
    setShowPrompt(false)
    setShowSoftPrompt(false)
    localStorage.setItem('push-prompt-dismissed', 'true')
  }

  return (
    <PushNotificationContext.Provider
      value={{
        isSupported,
        isIOS,
        permission,
        isSubscribed,
        isLoading,
        showSoftPrompt,
        setShowSoftPrompt,
        showPrompt,
        subscribe,
        confirmSubscribe,
        dismiss,
      }}
    >
      {children}
    </PushNotificationContext.Provider>
  )
}

export function usePushNotificationContext() {
  const context = useContext(PushNotificationContext)
  if (context === undefined) {
    throw new Error('usePushNotificationContext must be used within a PushNotificationProvider')
  }
  return context
}
