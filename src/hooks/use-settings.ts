import { useState, useEffect } from 'react'

interface Settings {
  groceryMartOpen: boolean
  cafeOpen?: boolean
  restaurantOpen?: boolean
  grocery_free_delivery_threshold?: string
  cafe_free_delivery_threshold?: string
  combined_free_delivery_threshold?: string
  delivery_fee?: string
  tax_rate?: number
  misc_fee?: string
  misc_fee_label?: string
}

interface UseSettingsReturn {
  settings: Settings | null
  loading: boolean
  error: Error | null
  refetch: () => Promise<void>
}

export function useSettings(): UseSettingsReturn {
  const [settings, setSettings] = useState<Settings | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const fetchSettings = async () => {
    try {
      setLoading(true)
      setError(null)

      const res = await fetch('/api/settings', {
        cache: 'no-store',
        headers: {
          'Content-Type': 'application/json',
        },
      })

      if (!res.ok) {
        throw new Error(`Failed to fetch settings: ${res.status}`)
      }

      const data = await res.json()
      setSettings(data)
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Unknown error'))
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchSettings()
  }, [])

  return {
    settings,
    loading,
    error,
    refetch: fetchSettings,
  }
}
