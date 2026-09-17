/**
 * Centralized formatting utilities for FastKirana
 *
 * Replaces 30+ scattered inline patterns for currency, dates, and timezone handling.
 * All monetary values use Indian Rupee (₹) with en-IN locale.
 * All timezone-aware functions default to Asia/Kolkata (IST).
 */

// ─── Currency ────────────────────────────────────────────────────────────────

/**
 * Format a number as Indian Rupee price string.
 * @example formatPrice(199)    → "₹199"
 * @example formatPrice(1299.5) → "₹1,299.50"
 * @example formatPrice(0)      → "₹0"
 */
export function formatPrice(amount: number | null | undefined, opts?: { decimals?: number }): string {
  if (amount === null || amount === undefined || isNaN(Number(amount))) {
    return '₹0'
  }
  const num = Number(amount)
  const decimals = opts?.decimals
  if (decimals !== undefined) {
    return `₹${num.toLocaleString('en-IN', { minimumFractionDigits: decimals, maximumFractionDigits: decimals })}`
  }
  // Auto: show decimals only if fractional part is non-zero
  const isWhole = Number.isInteger(num) || Math.abs(num - Math.round(num)) < 0.01
  if (isWhole) {
    return `₹${Math.round(num).toLocaleString('en-IN')}`
  }
  return `₹${num.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}


/**
 * Format a discount amount (always prefixed with minus sign).
 * @example formatPriceDiscount(50) → "-₹50"
 */
export function formatPriceDiscount(amount: number): string {
  return `-₹${Math.abs(Math.round(amount)).toLocaleString('en-IN')}`
}

/**
 * Format a surcharge / addition (always prefixed with plus sign).
 * @example formatPriceSurcharge(15) → "+₹15"
 */
export function formatPriceSurcharge(amount: number): string {
  return `+₹${Math.abs(Math.round(amount)).toLocaleString('en-IN')}`
}

// ─── Date Formatting ─────────────────────────────────────────────────────────

/**
 * Format a date as a human-readable display string.
 * @example formatDisplayDate(new Date()) → "14 Sep 2026"
 */
export function formatDisplayDate(date: string | Date | null | undefined): string {
  if (!date) return ''
  try {
    const d = new Date(date)
    if (isNaN(d.getTime())) return ''
    return d.toLocaleDateString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      timeZone: 'Asia/Kolkata',
    })
  } catch {
    return ''
  }
}

/**
 * Format a date with time.
 * @example formatDisplayDateTime(new Date()) → "14 Sep 2026, 3:45 PM"
 */
export function formatDisplayDateTime(date: string | Date | null | undefined): string {
  if (!date) return ''
  try {
    const d = new Date(date)
    if (isNaN(d.getTime())) return ''
    return d.toLocaleString('en-IN', {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
      timeZone: 'Asia/Kolkata',
    })
  } catch {
    return ''
  }
}

/**
 * Format time only in IST timezone (forced Asia/Kolkata).
 * @example formatTimeIST(new Date()) → "3:45 PM"
 */
export function formatTimeIST(date: string | Date | null | undefined): string {
  if (!date) return ''
  try {
    const d = new Date(date)
    if (isNaN(d.getTime())) return ''
    return d.toLocaleTimeString('en-IN', {
      timeZone: 'Asia/Kolkata',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    })
  } catch {
    return ''
  }
}

/**
 * Get ISO date string (YYYY-MM-DD) without timezone conversion issues.
 * Replaces the common `.toISOString().split('T')[0]` pattern with IST-aware formatting.
 * @example formatISODate(new Date()) → "2026-09-14"
 */
export function formatISODate(date?: Date | string): string {
  const d = date ? new Date(date) : new Date()
  if (isNaN(d.getTime())) return ''
  // Use IST timezone to avoid midnight UTC boundary issues for Indian dates
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(d)
  const year = parts.find(p => p.type === 'year')?.value || ''
  const month = parts.find(p => p.type === 'month')?.value || ''
  const day = parts.find(p => p.type === 'day')?.value || ''
  return `${year}-${month}-${day}`
}

// ─── IST Timezone Helpers ────────────────────────────────────────────────────

/** Cache the formatter to avoid re-creating on every call */
const _istFormatter = new Intl.DateTimeFormat('en-US', {
  timeZone: 'Asia/Kolkata',
  hour: 'numeric',
  minute: 'numeric',
  hour12: false,
})

function _getISTParts(): { hour: number; minute: number } {
  const parts = _istFormatter.formatToParts(new Date())
  const hour = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
  const minute = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10)
  return { hour, minute }
}

/**
 * Get the current hour in IST (0–23).
 * Replaces duplicated inline Intl.DateTimeFormat patterns across hero-area, deals-curation-hub, etc.
 */
export function getISTHour(): number {
  return _getISTParts().hour
}

/**
 * Get the current minute in IST (0–59).
 */
export function getISTMinute(): number {
  return _getISTParts().minute
}

/**
 * Get the total minutes since midnight in IST. Useful for schedule comparisons.
 * @example getISTTotalMinutes() → 945 (at 3:45 PM IST)
 */
export function getISTTotalMinutes(): number {
  const { hour, minute } = _getISTParts()
  return hour * 60 + minute
}

// ─── Date Range Presets ──────────────────────────────────────────────────────

export type DateRangePreset = 'today' | 'yesterday' | '7days' | '30days'

export const DATE_RANGE_LABELS: Record<DateRangePreset, string> = {
  today: 'Today',
  yesterday: 'Yesterday',
  '7days': '7 Days',
  '30days': '30 Days',
}

/**
 * Compute start and end ISO date strings for common report presets.
 * Replaces 3 duplicated blocks across admin-reports, admin-restaurant-report, restaurant-sales-console.
 * @returns `{ start: 'YYYY-MM-DD', end: 'YYYY-MM-DD' }`
 */
export function getDateRangePreset(preset: DateRangePreset): { start: string; end: string } {
  const now = new Date()
  const end = new Date()
  const start = new Date()

  switch (preset) {
    case 'today':
      // start = today, end = today (default)
      break
    case 'yesterday':
      start.setDate(now.getDate() - 1)
      end.setDate(now.getDate() - 1)
      break
    case '7days':
      start.setDate(now.getDate() - 7)
      break
    case '30days':
      start.setDate(now.getDate() - 30)
      break
  }

  return {
    start: formatISODate(start),
    end: formatISODate(end),
  }
}

// ─── Store Operating Status ──────────────────────────────────────────────────

/**
 * Check if the store is currently within operating hours based on IST time.
 * Consolidates the manual hour/minute parsing scattered across settings route,
 * admin-settings, restaurant-schedule, and date-helpers.
 *
 * @param openTimeStr  e.g. "08:00"
 * @param closeTimeStr e.g. "22:00"
 * @returns true if current IST time is within [open, close)
 */
export function isStoreOpen(openTimeStr: string, closeTimeStr: string): boolean {
  if (!openTimeStr || !closeTimeStr) return true // Default open if no times set

  const [openH, openM] = openTimeStr.split(':').map(Number)
  const [closeH, closeM] = closeTimeStr.split(':').map(Number)
  if (isNaN(openH) || isNaN(closeH)) return true

  const openTotal = openH * 60 + (openM || 0)
  const closeTotal = closeH * 60 + (closeM || 0)
  const currentTotal = getISTTotalMinutes()

  // Handle overnight schedules (e.g. 20:00 – 04:00)
  if (closeTotal < openTotal) {
    return currentTotal >= openTotal || currentTotal < closeTotal
  }

  return currentTotal >= openTotal && currentTotal < closeTotal
}
