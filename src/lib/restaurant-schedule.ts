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
    const hour = parseInt(parts.find((p) => p.type === 'hour')?.value || '0', 10)
    const minute = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10)
    return hour * 60 + minute
  } catch (e) {
    const now = new Date()
    return now.getHours() * 60 + now.getMinutes()
  }
}

export function checkStoreOperatingStatus(restaurant?: {
  isOpen?: boolean | null
  openTime?: string | null
  closeTime?: string | null
}): OperatingStatus {
  if (!restaurant) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: '',
    }
  }

  // 1. Manual owner toggle check (Manage Outlet toggle)
  if (restaurant.isOpen === false || (restaurant.isOpen as any) === 'false') {
    return {
      isOpen: false,
      isClosedBySchedule: false,
      isClosedByOwner: true,
      formattedScheduleStr: 'Closed by Store Owner',
    }
  }

  // 2. Schedule check
  const openTimeStr = restaurant.openTime
  const closeTimeStr = restaurant.closeTime

  if (!openTimeStr || !closeTimeStr) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: 'Open 24/7',
    }
  }

  // 24/7 check
  if (
    (openTimeStr === '00:00' || openTimeStr === '0:00') &&
    (closeTimeStr === '23:59' || closeTimeStr === '24:00')
  ) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: 'Open 24/7',
    }
  }

  const openMins = parseTimeStringToMinutes(openTimeStr)
  const closeMins = parseTimeStringToMinutes(closeTimeStr)

  if (openMins === null || closeMins === null) {
    return {
      isOpen: true,
      isClosedBySchedule: false,
      isClosedByOwner: false,
      formattedScheduleStr: `${formatTime12h(openTimeStr)} - ${formatTime12h(closeTimeStr)}`,
    }
  }

  const currentMins = getISTMinutes()

  let isOpenBySchedule = false

  if (closeMins > openMins) {
    // Normal day schedule (e.g. 10:00 AM to 11:00 PM)
    isOpenBySchedule = currentMins >= openMins && currentMins < closeMins
  } else {
    // Overnight schedule (e.g. 6:00 PM to 3:00 AM)
    isOpenBySchedule = currentMins >= openMins || currentMins < closeMins
  }

  const formattedOpen = formatTime12h(openTimeStr)
  const formattedClose = formatTime12h(closeTimeStr)

  return {
    isOpen: isOpenBySchedule,
    isClosedBySchedule: !isOpenBySchedule,
    isClosedByOwner: false,
    formattedScheduleStr: isOpenBySchedule
      ? `Open until ${formattedClose}`
      : `Opens at ${formattedOpen}`,
  }
}
