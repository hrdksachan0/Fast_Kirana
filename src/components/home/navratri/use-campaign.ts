'use client'

import { useEffect, useState } from 'react'
import { apiUrl } from '@/lib/api-url'
import { parseCampaignConfig, type CampaignConfig } from '@/lib/campaign-config'
import { navratriData } from './data'

export const bundledCampaign = parseCampaignConfig(navratriData)
export const disabledCampaign: CampaignConfig = {
  ...bundledCampaign,
  enabled: false,
}

/** Fetch published configuration only; drafts stay inside the admin editor. */
export function useCampaign(storeId?: string | null, active = true) {
  const [state, setState] = useState<{ storeId: string; data: CampaignConfig }>({
    storeId: '',
    data: disabledCampaign,
  })
  const key = storeId ?? ''
  useEffect(() => {
    if (!active) return
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
        if (!controller.signal.aborted) setState({ storeId: key, data })
      } catch {
        if (!controller.signal.aborted) setState({ storeId: key, data: disabledCampaign })
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
  return state.storeId === key ? state.data : disabledCampaign
}
