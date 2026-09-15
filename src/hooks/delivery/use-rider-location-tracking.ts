'use client'

import { useCallback } from 'react'

export function useRiderLocationTracking() {
  const getCurrentCoords = useCallback((): Promise<{ lat: number; lng: number } | null> => {
    return new Promise((resolve) => {
      if (!navigator.geolocation) {
        resolve(null)
        return
      }

      const safetyTimeout = setTimeout(() => {
        console.warn('[Geolocation] Safety timeout fired, resolving coordinates to null')
        resolve(null)
      }, 3500)

      navigator.geolocation.getCurrentPosition(
        (position) => {
          clearTimeout(safetyTimeout)
          resolve({
            lat: position.coords.latitude,
            lng: position.coords.longitude,
          })
        },
        () => {
          clearTimeout(safetyTimeout)
          resolve(null)
        },
        { enableHighAccuracy: true, timeout: 3000 }
      )
    })
  }, [])

  return { getCurrentCoords }
}
