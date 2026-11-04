'use client'

import { useEffect, useState, useRef } from 'react'
import { apiUrl } from '@/lib/api-url'
import { parseCampaignConfig, type CampaignConfig } from '@/lib/campaign-config'
import { navratriData } from './data'

export const bundledCampaign = parseCampaignConfig(navratriData)
export const disabledCampaign: CampaignConfig = {
  ...bundledCampaign,
  enabled: false,
}

// Global in-memory cache surviving component unmounts, tab switches, and store hydration
const memoryCampaignCache: Record<string, CampaignConfig> = {}

function getStoredCampaign(key: string): CampaignConfig | null {
  if (memoryCampaignCache[key]) return memoryCampaignCache[key]
  if (typeof window !== 'undefined') {
    try {
      const stored = localStorage.getItem(`fk_campaign_${key || 'global'}`)
      if (stored) {
        const parsed = parseCampaignConfig(JSON.parse(stored))
        memoryCampaignCache[key] = parsed
        return parsed
      }
    } catch (_) {}
  }
  return null
}

function saveCampaignToCache(key: string, data: CampaignConfig) {
  memoryCampaignCache[key] = data
  if (typeof window !== 'undefined') {
    try {
      localStorage.setItem(`fk_campaign_${key || 'global'}`, JSON.stringify(data))
    } catch (_) {}
  }
}

/** Fetch published configuration with Stale-While-Revalidate caching */
export function useCampaign(
  storeId?: string | null,
  active = true,
  initialData?: CampaignConfig | null
) {
  const key = storeId ?? ''

  // Seed cache with initialData if provided
  if (initialData && !memoryCampaignCache[key]) {
    memoryCampaignCache[key] = initialData
  }

  const [state, setState] = useState<{ storeId: string; data: CampaignConfig }>(() => {
    // 1. Initial server-rendered data
    if (initialData) return { storeId: key, data: initialData }
    // 2. Cached data for this specific store
    const cached = getStoredCampaign(key)
    if (cached) return { storeId: key, data: cached }
    // 3. Fallback to global cached campaign if store-specific isn't cached yet
    const globalCached = getStoredCampaign('')
    if (globalCached) return { storeId: key, data: globalCached }
    // 4. Bundled fallback campaign (enabled: true so it renders immediately without blank delay)
    return { storeId: key, data: bundledCampaign }
  })

  const stateRef = useRef(state)
  stateRef.current = state

  useEffect(() => {
    if (!active) return

    // If key changes (e.g. store hydration), immediately adopt cached data without dropping to disabledCampaign
    const existingCache = getStoredCampaign(key) || getStoredCampaign('') || stateRef.current.data
    if (stateRef.current.storeId !== key) {
      setState({ storeId: key, data: existingCache })
    }

    const controller = new AbortController()
    const load = async () => {
      try {
        const query = key && key !== 'all' ? `?storeId=${encodeURIComponent(key)}` : ''
        const response = await fetch(
          `${apiUrl('/api/homepage-campaign')}/api/homepage-campaign${query}`,
          { signal: controller.signal, cache: 'no-store' }
        )
        if (!response.ok) throw new Error('Campaign unavailable')
        const result = await response.json()
        const data =
          result.campaign == null ? disabledCampaign : parseCampaignConfig(result.campaign)

        if (!controller.signal.aborted) {
          saveCampaignToCache(key, data)
          setState({ storeId: key, data })
        }
      } catch {
        // On error or offline, retain the existing cached or bundled campaign instead of hiding it
        if (!controller.signal.aborted) {
          const fallback = getStoredCampaign(key) || stateRef.current.data || bundledCampaign
          setState({ storeId: key, data: fallback })
        }
      }
    }

    void load()

    const onVisible = () => {
      if (document.visibilityState === 'visible') void load()
    }
    const interval = setInterval(onVisible, 60000)
    document.addEventListener('visibilitychange', onVisible)

    return () => {
      controller.abort()
      clearInterval(interval)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [key, active])

  return state.data
}
