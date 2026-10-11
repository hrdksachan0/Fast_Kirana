'use client'

import { useEffect, useState } from 'react'

/** The first render is always slide zero, including SSR and hydration. */
export function useRotation(count: number, intervalMs: number, paused = false) {
  const [index, setIndex] = useState(0)
  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    let timer: ReturnType<typeof setInterval> | undefined
    const sync = () => {
      clearInterval(timer)
      timer = undefined
      if (!paused && !media.matches && document.visibilityState === 'visible' && count > 1) {
        timer = setInterval(() => setIndex((previous) => (previous + 1) % count), intervalMs)
      }
    }
    sync()
    document.addEventListener('visibilitychange', sync)
    media.addEventListener('change', sync)
    return () => {
      clearInterval(timer)
      document.removeEventListener('visibilitychange', sync)
      media.removeEventListener('change', sync)
    }
  }, [count, intervalMs, paused])
  return index % Math.max(1, count)
}
