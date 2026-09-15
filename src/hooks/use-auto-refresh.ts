'use client'

import { useState, useEffect, useRef, useCallback } from 'react'

interface AutoRefreshOptions {
  /** The async function to call on each refresh cycle */
  fetchFn: () => Promise<void>
  /** Countdown duration in seconds (default: 30) */
  intervalSeconds?: number
  /** Whether to pause countdown when the tab/page is hidden (default: true) */
  pauseOnHidden?: boolean
  /** Whether the auto-refresh is currently enabled (default: true) */
  enabled?: boolean
}

interface AutoRefreshReturn {
  /** Current countdown progress (0–100), 100 = just refreshed, 0 = about to refresh */
  progress: number
  /** Whether a background refresh is currently in progress */
  isRefreshing: boolean
  /** Manually trigger an immediate refresh and reset countdown */
  triggerManualRefresh: () => Promise<void>
}

/**
 * Shared auto-refresh countdown hook.
 *
 * Replaces the duplicated 30-second countdown + fetch pattern used in:
 * - picker/page.tsx (30s auto-refresh with linear progress bar)
 * - delivery/page.tsx (30s auto-refresh countdown)
 * - admin-dashboard.tsx (10s fallback polling)
 *
 * Features:
 * - Linear countdown progress bar (100 → 0)
 * - Pauses when tab is not visible (saves API calls)
 * - Silent background refresh (no loading spinners on auto-refresh)
 * - Manual refresh resets countdown
 */
export function useAutoRefresh({
  fetchFn,
  intervalSeconds = 30,
  pauseOnHidden = true,
  enabled = true,
}: AutoRefreshOptions): AutoRefreshReturn {
  const [progress, setProgress] = useState(100)
  const [isRefreshing, setIsRefreshing] = useState(false)
  const fetchFnRef = useRef(fetchFn)
  fetchFnRef.current = fetchFn
  const countdownRef = useRef(intervalSeconds)

  const doRefresh = useCallback(async (silent = true) => {
    if (!silent) setIsRefreshing(true)
    try {
      await fetchFnRef.current()
    } catch (err) {
      console.warn('Auto-refresh fetch error:', err)
    } finally {
      if (!silent) setIsRefreshing(false)
    }
    countdownRef.current = intervalSeconds
    setProgress(100)
  }, [intervalSeconds])

  // Countdown ticker
  useEffect(() => {
    if (!enabled) return

    const ticker = setInterval(() => {
      if (pauseOnHidden && document.visibilityState !== 'visible') return

      countdownRef.current -= 1

      if (countdownRef.current <= 0) {
        doRefresh(true) // silent auto-refresh
      } else {
        setProgress(Math.round((countdownRef.current / intervalSeconds) * 100))
      }
    }, 1000)

    return () => clearInterval(ticker)
  }, [enabled, intervalSeconds, pauseOnHidden, doRefresh])

  const triggerManualRefresh = useCallback(async () => {
    await doRefresh(false)
  }, [doRefresh])

  return { progress, isRefreshing, triggerManualRefresh }
}
