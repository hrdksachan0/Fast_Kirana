import { formatTime12h } from '@/lib/date-helpers'

/**
 * Utility helper to evaluate if a restaurant/cafe is currently open based on
 * manual isOpen toggle and configured openTime / closeTime operating hours in IST.
 */

export interface OperatingStatus {
  isOpen: boolean
  isClosedBySchedule: boolean
  isClosedByOwner: boolean
  formattedScheduleStr: string
}

export function parseTimeStringToMinutes(timeStr: string): number | null {
  if (!timeStr || typeof timeStr !== 'string') return null

  const clean = timeStr.trim().toUpperCase()
  const isPM = clean.includes('PM')
  const isAM = clean.includes('AM')

  // Strip AM/PM
  const timeOnly = clean.replace(/AM|PM/g, '').trim()
  const parts = timeOnly.split(':')
  if (parts.length < 2) return null

  let hours = parseInt(parts[0], 10)
  const minutes = parseInt(parts[1], 10)

  if (isNaN(hours) || isNaN(minutes)) return null

  if (isPM && hours < 12) hours += 12
  if (isAM && hours === 12) hours = 0

  return hours * 60 + minutes
}

export function getISTMinutes(): number {
  try {
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
    })
    const parts = formatter.formatToParts(new Date())
    let hour = parseInt(parts.find((p) => p.type === 'hour')?.value || '0', 10)
    const minute = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10)
    if (hour === 24) hour = 0
    return hour * 60 + minute
  } catch (e) {
    const now = new Date()
    return now.getHours() * 60 + now.getMinutes()
  }
}

export function isManuallyPausedToday(restaurant: {
  isOpen?: boolean | string | number | null
  openTime?: string | null
  updatedAt?: Date | string | null
}): boolean {
  const isClosed = restaurant.isOpen === false || restaurant.isOpen === 'false' || restaurant.isOpen === 0
  return isClosed
}

export function checkStoreOperatingStatus(restaurant?: {
  isOpen?: boolean | string | number | null
  openTime?: string | null
  closeTime?: string | null
  updatedAt?: Date | string | null
  pauseUntil?: Date | string | null
  closeReason?: string | null
}): OperatingStatus {
  if (!restaurant) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: 'Open for Orders',
    }
  }

  // 1. Check if owner/admin manually turned off accepting orders
  const isOwnerClosed = restaurant.isOpen === false || restaurant.isOpen === 'false' || restaurant.isOpen === 0
  if (isOwnerClosed) {
    return {
      isOpen: false,
      isClosedBySchedule: false,
      isClosedByOwner: true,
      formattedScheduleStr: restaurant.closeReason || 'Closed (Not accepting orders)',
    }
  }

  // 2. Check if kitchen busy pause is active
  if (restaurant.pauseUntil) {
    const pauseTime = new Date(restaurant.pauseUntil).getTime()
    if (!isNaN(pauseTime) && pauseTime > Date.now()) {
      return {
        isOpen: false,
        isClosedBySchedule: false,
        isClosedByOwner: true,
        formattedScheduleStr: restaurant.closeReason || 'Temporarily Paused (High Rush)',
      }
    }
  }

  const openTimeStr = restaurant.openTime?.trim() || ''
  const closeTimeStr = restaurant.closeTime?.trim() || ''
  const hasSchedule = Boolean(openTimeStr && closeTimeStr)

  const scheduleStr = hasSchedule
    ? `${formatTime12h(openTimeStr)} - ${formatTime12h(closeTimeStr)}`
    : 'Open for Orders'

  // 3. If operating hours are configured, evaluate if currently within operating hours (IST)
  if (hasSchedule) {
    const openMin = parseTimeStringToMinutes(openTimeStr)
    const closeMin = parseTimeStringToMinutes(closeTimeStr)

    if (openMin !== null && closeMin !== null) {
      const is24h = openMin === 0 && (closeMin >= 1439 || closeMin === 0)

      if (!is24h) {
        const currentMin = getISTMinutes()
        let isWithinHours = false

        if (closeMin >= openMin) {
          // Standard daytime hours: e.g. 10:00 to 22:00 (10 AM to 10 PM)
          isWithinHours = currentMin >= openMin && currentMin <= closeMin
        } else {
          // Overnight hours: e.g. 18:00 to 02:00 (6 PM to 2 AM)
          isWithinHours = currentMin >= openMin || currentMin <= closeMin
        }

        // If outside operating hours, automatically closed by schedule
        if (!isWithinHours) {
          return {
            isOpen: false,
            isClosedBySchedule: true,
            isClosedByOwner: false,
            formattedScheduleStr: `Opens at ${formatTime12h(openTimeStr)}`,
          }
        }
      }
    }
  }

  // 4. Within operating hours, automatically open on schedule
  return {
    isOpen: true,
    isClosedBySchedule: false,
    isClosedByOwner: false,
    formattedScheduleStr: scheduleStr,
  }
}
