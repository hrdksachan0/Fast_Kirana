import { getTotalMinutes } from '@/lib/date-helpers'

export interface DishTimingStatus {
  isAvailableNow: boolean
  formattedTimeSlot: string | null
  nextAvailableTimeStr: string | null
}

export function checkDishTimeAvailability(
  startTime?: string | null,
  endTime?: string | null
): DishTimingStatus {
  // If no start/end time specified, item is available 24/7 (All Day)
  if (!startTime || !endTime || !startTime.trim() || !endTime.trim()) {
    return {
      isAvailableNow: true,
      formattedTimeSlot: null,
      nextAvailableTimeStr: null,
    }
  }

  try {
    const now = new Date()
    const currentMinutes = getTotalMinutes(now)

    const [startH, startM] = startTime.split(':').map(Number)
    const [endH, endM] = endTime.split(':').map(Number)

    const startMinutes = startH * 60 + (startM || 0)
    const endMinutes = endH * 60 + (endM || 0)

    let isAvailableNow = false

    if (startMinutes <= endMinutes) {
      // Normal range e.g. 07:00 to 11:30
      isAvailableNow = currentMinutes >= startMinutes && currentMinutes <= endMinutes
    } else {
      // Overnight range e.g. 20:00 to 02:00
      isAvailableNow = currentMinutes >= startMinutes || currentMinutes <= endMinutes
    }

    const format12h = (time24: string) => {
      const [hStr, mStr] = time24.split(':')
      let h = parseInt(hStr, 10)
      const m = mStr || '00'
      const ampm = h >= 12 ? 'PM' : 'AM'
      h = h % 12 || 12
      return `${h}:${m} ${ampm}`
    }

    const formattedStart = format12h(startTime)
    const formattedEnd = format12h(endTime)

    return {
      isAvailableNow,
      formattedTimeSlot: `${formattedStart} - ${formattedEnd}`,
      nextAvailableTimeStr: formattedStart,
    }
  } catch (err) {
    console.error('Error parsing dish timing:', err)
    return {
      isAvailableNow: true,
      formattedTimeSlot: null,
      nextAvailableTimeStr: null,
    }
  }
}
