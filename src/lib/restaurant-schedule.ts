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
      formattedScheduleStr: 'Open for Orders',
    }
  }

  // 1. Manual owner toggle check (Manage Outlet toggle)
  if (restaurant.isOpen === false || (restaurant.isOpen as any) === 'false' || (restaurant.isOpen as any) === 0) {
    return {
      isOpen: false,
      isClosedBySchedule: false,
      isClosedByOwner: true,
      formattedScheduleStr: 'Closed by Store Owner',
    }
  }

  // 2. Cafe off / Schedule-blocking logic removed:
  // When owner has opened the store (isOpen != false), it stays OPEN 24/7 without schedule interruption.
  const openTimeStr = restaurant.openTime?.trim()
  const closeTimeStr = restaurant.closeTime?.trim()
  const scheduleStr = (openTimeStr && closeTimeStr)
    ? `${formatTime12h(openTimeStr)} - ${formatTime12h(closeTimeStr)}`
    : 'Open for Orders'

  return {
    isOpen: true,
    isClosedBySchedule: false,
    isClosedByOwner: false,
    formattedScheduleStr: scheduleStr,
  }
}
