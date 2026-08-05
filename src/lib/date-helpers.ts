import { format, formatDistanceToNow, isToday, isTomorrow, addMinutes, parseISO, getHours, getMinutes } from 'date-fns'

// --- Time ---
export function formatDate(date: string | Date, pattern: string): string {
  return format(new Date(date), pattern)
}

export function formatOrderTime(date: string | Date): string {
  return format(new Date(date), 'h:mm a')
}

export function formatTime(date: string | Date): string {
  return format(new Date(date), 'h:mm a')
}

// --- Time + Date context ---
export function formatDeliveryETA(date: string | Date): string {
  const d = new Date(date)
  if (isToday(d)) return `Today, ${format(d, 'h:mm a')}`
  if (isTomorrow(d)) return `Tomorrow, ${format(d, 'h:mm a')}`
  return format(d, 'MMM d, h:mm a')
}

// --- Relative ---
export function formatRelativeTime(date: string | Date): string {
  return formatDistanceToNow(new Date(date), { addSuffix: true })
}

// --- Date arithmetic ---
export function addMinutesTo(date: Date | string, mins: number): Date {
  return addMinutes(new Date(date), mins)
}

export function getTotalMinutes(date: string | Date): number {
  const d = new Date(date)
  return getHours(d) * 60 + getMinutes(d)
}

// --- Parse ---
export function parseISODate(dateStr: string): Date {
  return parseISO(dateStr)
}

// --- 12-hour time format ---
/** Convert "14:30" → "2:30 PM" */
export function formatTime12h(timeStr?: string): string {
  if (!timeStr) return ''
  const [hStr, mStr] = timeStr.split(':')
  const h = parseInt(hStr, 10)
  if (isNaN(h)) return timeStr
  const m = parseInt(mStr, 10) || 0
  const ampm = h >= 12 ? 'PM' : 'AM'
  const h12 = h % 12 === 0 ? 12 : h % 12
  const mPad = m === 0 ? '' : `:${String(m).padStart(2, '0')}`
  return `${h12}${mPad} ${ampm}`
}

/** Check if current IST time is within 30 min of closing time */
export function isNearClosing(closeTimeStr: string): boolean {
  if (!closeTimeStr) return false
  const [closeHStr, closeMStr] = closeTimeStr.split(':')
  const closeH = parseInt(closeHStr, 10)
  const closeM = parseInt(closeMStr, 10) || 0
  if (isNaN(closeH)) return false

  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false
  })
  const parts = formatter.formatToParts(new Date())
  const currentH = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
  const currentM = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10)
  const currentTotal = currentH * 60 + currentM

  const closeTotal = closeH * 60 + closeM
  let diff = closeTotal - currentTotal

  if (closeTotal < 300 && currentTotal > 1200) {
    diff = (closeTotal + 1440) - currentTotal
  }

  return diff > 0 && diff <= 30
}
