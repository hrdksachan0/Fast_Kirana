import { format, addMinutes, parseISO, getHours, getMinutes, formatDistanceToNow } from 'date-fns'

// Re-export IST timezone helpers from formatters.ts for convenience
export { getISTHour, getISTMinute, getISTTotalMinutes, formatISODate, isStoreOpen } from './formatters'

export function parseDateInput(date?: string | Date | null): Date | null {
  if (!date) return null
  if (date instanceof Date) return isNaN(date.getTime()) ? null : date
  const s = String(date).trim()
  if (!s) return null
  const dateToParse = /T\d{2}:\d{2}/.test(s) && !s.endsWith('Z') && !s.includes('+') ? `${s}Z` : s
  const d = new Date(dateToParse)
  return isNaN(d.getTime()) ? null : d
}

// --- Indian Rupee Currency Formatter ---
export function formatINR(amount?: number | string | null): string {
  if (amount === undefined || amount === null || amount === '') return '₹0'
  const numericVal = typeof amount === 'string' ? parseFloat(amount) : amount
  if (isNaN(numericVal)) return '₹0'
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: numericVal % 1 === 0 ? 0 : 2,
    minimumFractionDigits: 0,
  }).format(numericVal)
}

// --- Date Formatting (IST Enforced) ---
export function formatDate(date?: string | Date | null, _pattern = 'PP'): string {
  const d = parseDateInput(date)
  if (!d) return ''
  try {
    return d.toLocaleDateString('en-IN', {
      timeZone: 'Asia/Kolkata',
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    })
  } catch {
    return ''
  }
}

export function formatOrderTime(date?: string | Date | null): string {
  const d = parseDateInput(date)
  if (!d) return ''
  try {
    return d.toLocaleTimeString('en-IN', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    })
  } catch {
    return ''
  }
}

export function formatTime(date?: string | Date | null): string {
  return formatOrderTime(date)
}

export function formatOrderDateTime(date?: string | Date | null): string {
  const d = parseDateInput(date)
  if (!d) return ''
  const datePart = formatDate(d)
  const timePart = formatOrderTime(d)
  return datePart && timePart ? `${datePart}, ${timePart}` : datePart || timePart
}

export function formatRelativeTimestamp(date?: string | Date | null): string {
  const d = parseDateInput(date)
  if (!d) return ''
  try {
    return formatDistanceToNow(d, { addSuffix: true })
  } catch {
    return formatDate(d)
  }
}

export function formatDeliveryETA(minutes?: number | string | null): string {
  if (!minutes) return '10-15 mins'
  const m = typeof minutes === 'string' ? parseInt(minutes, 10) : minutes
  if (isNaN(m) || m <= 0) return '10-15 mins'
  if (m <= 10) return '8-12 mins'
  return `${Math.max(8, m - 3)}-${m + 3} mins`
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
    hour12: false,
  })
  const parts = formatter.formatToParts(new Date())
  const currentH = parseInt(parts.find((p) => p.type === 'hour')?.value || '0', 10)
  const currentM = parseInt(parts.find((p) => p.type === 'minute')?.value || '0', 10)
  const currentTotal = currentH * 60 + currentM

  const closeTotal = closeH * 60 + closeM
  let diff = closeTotal - currentTotal

  if (closeTotal < 300 && currentTotal > 1200) {
    diff = closeTotal + 1440 - currentTotal
  }

  return diff > 0 && diff <= 30
}
