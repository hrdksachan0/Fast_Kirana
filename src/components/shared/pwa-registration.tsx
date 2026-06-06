'use client'

import { useEffect } from 'react'

export function PWARegistration() {
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker
          .register('/sw.js')
          .then((reg) => {
            console.log('ServiceWorker registered with scope: ', reg.scope)
          })
          .catch((err) => {
            console.error('ServiceWorker registration failed: ', err)
          })
      })
    }
  }, [])

  return null
}
