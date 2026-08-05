import { format, formatDistanceToNow, isToday, isTomorrow, addMinutes, parseISO } from 'date-fns'

export function formatOrderTime(date: string | Date): string {
  return format(new Date(date), 'h:mm a')
}

export function formatDeliveryETA(date: string | Date): string {
  const d = new Date(date)
  if (isToday(d)) return `Today, ${format(d, 'h:mm a')}`
  if (isTomorrow(d)) return `Tomorrow, ${format(d, 'h:mm a')}`
  return format(d, 'MMM d, h:mm a')
}

export function formatRelativeTime(date: string | Date): string {
  return formatDistanceToNow(new Date(date), { addSuffix: true })
}

export function addMinutesTo(date: Date | string, mins: number): Date {
  return addMinutes(new Date(date), mins)
}

export function parseISODate(dateStr: string): Date {
  return parseISO(dateStr)
}
