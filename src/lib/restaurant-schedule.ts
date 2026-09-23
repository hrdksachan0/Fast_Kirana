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
  if (!isClosed) {
    return false
  }
  if (!restaurant.updatedAt) {
    return true
  }

  try {
    const updatedDate = new Date(restaurant.updatedAt)
    if (isNaN(updatedDate.getTime())) return true

    const now = new Date()
    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Kolkata',
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
    })

    const parts = formatter.formatToParts(now)
    const year = parseInt(parts.find(p => p.type === 'year')?.value || '0', 10)
    const month = parseInt(parts.find(p => p.type === 'month')?.value || '1', 10) - 1
    const day = parseInt(parts.find(p => p.type === 'day')?.value || '1', 10)

    const updatedParts = formatter.formatToParts(updatedDate)
    const uYear = parseInt(updatedParts.find(p => p.type === 'year')?.value || '0', 10)
    const uMonth = parseInt(updatedParts.find(p => p.type === 'month')?.value || '1', 10) - 1
    const uDay = parseInt(updatedParts.find(p => p.type === 'day')?.value || '1', 10)

    const isSameDay = year === uYear && month === uMonth && day === uDay
    if (!isSameDay) {
      return false
    }

    const openTimeStr = restaurant.openTime?.trim()
    if (openTimeStr) {
      const openMin = parseTimeStringToMinutes(openTimeStr)
      if (openMin !== null) {
        const uHour = parseInt(updatedParts.find(p => p.type === 'hour')?.value || '0', 10)
        const uMinute = parseInt(updatedParts.find(p => p.type === 'minute')?.value || '0', 10)
        const uTotalMin = uHour * 60 + uMinute
        if (uTotalMin < openMin) {
          return false
        }
      }
    }

    return true
  } catch {
    return true
  }
}

export function checkStoreOperatingStatus(restaurant?: {
  isOpen?: boolean | string | number | null
  openTime?: string | null
  closeTime?: string | null
  updatedAt?: Date | string | null
}): OperatingStatus {
  if (!restaurant) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: 'Open for Orders',
    }
  }

  const openTimeStr = restaurant.openTime?.trim() || ''
  const closeTimeStr = restaurant.closeTime?.trim() || ''
  const hasSchedule = Boolean(openTimeStr && closeTimeStr)

  const scheduleStr = hasSchedule
    ? `${formatTime12h(openTimeStr)} - ${formatTime12h(closeTimeStr)}`
    : 'Open for Orders'

  // 1. If operating hours are configured, evaluate if currently within operating hours (IST)
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

  // 2. Check if owner manually paused the store today during active hours
  const isOwnerPaused = restaurant.isOpen === false || restaurant.isOpen === 'false' || restaurant.isOpen === 0
  if (isOwnerPaused) {
    if (!restaurant.updatedAt || isManuallyPausedToday(restaurant)) {
      return {
        isOpen: false,
        isClosedBySchedule: false,
        isClosedByOwner: true,
        formattedScheduleStr: 'Temporarily Paused by Store Owner',
      }
    }
  }

  // 3. Within operating hours, automatically open on schedule
  return {
    isOpen: true,
    isClosedBySchedule: false,
    isClosedByOwner: false,
    formattedScheduleStr: scheduleStr,
  }
}
