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
