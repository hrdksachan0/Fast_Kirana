'use client'

import React from 'react'

export interface RiderGpsInfo {
  label: string
  shortEmoji: string
  tone: 'live' | 'stale' | 'off'
  ageSec: number | null
}

export function getRiderGpsFreshness(gpsUpdatedAt?: string | null): RiderGpsInfo {
  if (!gpsUpdatedAt) {
    return { label: 'GPS Off', shortEmoji: '🔴', tone: 'off', ageSec: null }
  }
  const iso = /[zZ]|[+-]\d{2}:\d{2}$/.test(gpsUpdatedAt) ? gpsUpdatedAt : `${gpsUpdatedAt}Z`
  const ts = Date.parse(iso)
  if (Number.isNaN(ts)) {
    return { label: 'GPS Off', shortEmoji: '🔴', tone: 'off', ageSec: null }
  }
  const ageSec = Math.max(0, Math.floor((Date.now() - ts) / 1000))

  let ageText: string
  if (ageSec < 60) {
    ageText = `${ageSec}s ago`
  } else if (ageSec < 3600) {
    ageText = `${Math.floor(ageSec / 60)}m ago`
  } else if (ageSec < 86400) {
    ageText = `${Math.floor(ageSec / 3600)}h ago`
  } else {
    ageText = `${Math.floor(ageSec / 86400)}d ago`
  }

  if (ageSec <= 60) {
    return { label: `GPS ${ageText}`, shortEmoji: '🟢', tone: 'live', ageSec }
  }
  if (ageSec <= 300) {
    return { label: `GPS ${ageText}`, shortEmoji: '🟡', tone: 'stale', ageSec }
  }
  return { label: `GPS ${ageText}`, shortEmoji: '🔴', tone: 'off', ageSec }
}

export function RiderGpsBadge({
  gpsUpdatedAt,
  compact = false,
}: {
  gpsUpdatedAt?: string | null
  compact?: boolean
}) {
  const info = getRiderGpsFreshness(gpsUpdatedAt)
  const styles =
    info.tone === 'live'
      ? 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300 border-emerald-500/30'
      : info.tone === 'stale'
      ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300 border-amber-500/30'
      : 'bg-red-500/12 text-red-700 dark:text-red-300 border-red-500/30'

  const dotColor =
    info.tone === 'live'
      ? 'bg-emerald-500'
      : info.tone === 'stale'
      ? 'bg-amber-500'
      : 'bg-red-500'

  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border font-extrabold whitespace-nowrap ${styles} ${
        compact ? 'px-1.5 py-0.5 text-[8.5px]' : 'px-2 py-0.5 text-[9.5px]'
      }`}
      title={
        info.tone === 'live'
          ? 'Rider live GPS active'
          : info.tone === 'stale'
          ? 'Rider GPS delayed — check signal'
          : 'Rider GPS / internet appears off'
      }
    >
      <span className={`relative flex h-1.5 w-1.5 shrink-0`}>
        {info.tone === 'live' && (
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
        )}
        <span className={`relative inline-flex rounded-full h-1.5 w-1.5 ${dotColor}`} />
      </span>
      <span>{info.label}</span>
    </span>
  )
}
