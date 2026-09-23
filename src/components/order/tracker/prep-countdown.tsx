'use client'

import { useState, useEffect } from 'react'
import { Clock } from 'lucide-react'

export function PrepCountdown({ clockTarget }: { clockTarget: string | Date }) {
  const [timeLeft, setTimeLeft] = useState<string>('')

  useEffect(() => {
    const target = new Date(clockTarget).getTime()
    
    const updateTimer = () => {
      const now = Date.now()
      const diff = target - now
      if (diff <= 0) {
        setTimeLeft('Food is ready! Packing...')
        return
      }

      const mins = Math.floor(diff / 60000)
      const secs = Math.floor((diff % 60000) / 1000)
      setTimeLeft(`Preparing: ${mins}m ${secs.toString().padStart(2, '0')}s left`)
    }

    updateTimer()
    const interval = setInterval(updateTimer, 1000)
    return () => clearInterval(interval)
  }, [clockTarget])

  return (
    <span className="text-[10px] font-black text-primary bg-primary/10 px-2.5 py-1 rounded-lg uppercase tracking-wider flex items-center gap-1.5 animate-pulse shadow-sm">
      <Clock className="h-3.5 w-3.5 shrink-0" /> {timeLeft}
    </span>
  )
}
