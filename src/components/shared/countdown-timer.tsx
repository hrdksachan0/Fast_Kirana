'use client'

import { useState, useEffect } from 'react'

export function CountdownTimer() {
  const [timeLeft, setTimeLeft] = useState({ hours: 0, minutes: 0, seconds: 0 })

  useEffect(() => {
    const calculateTimeLeft = () => {
      const now = new Date()
      const midnight = new Date()
      midnight.setHours(24, 0, 0, 0) // Next midnight

      const difference = midnight.getTime() - now.getTime()

      if (difference > 0) {
        setTimeLeft({
          hours: Math.floor((difference / (1000 * 60 * 60)) % 24),
          minutes: Math.floor((difference / 1000 / 60) % 60),
          seconds: Math.floor((difference / 1000) % 60),
        })
      }
    }

    calculateTimeLeft()
    const interval = setInterval(calculateTimeLeft, 1000)
    return () => clearInterval(interval)
  }, [])

  const formatNumber = (num: number) => String(num).padStart(2, '0')

  return (
    <div className="flex items-center gap-1 font-mono text-sm font-extrabold text-discount">
      <span className="bg-discount/10 px-1.5 py-0.5 rounded border border-discount/20">
        {formatNumber(timeLeft.hours)}
      </span>
      <span className="text-discount/80 animate-pulse-gentle">:</span>
      <span className="bg-discount/10 px-1.5 py-0.5 rounded border border-discount/20">
        {formatNumber(timeLeft.minutes)}
      </span>
      <span className="text-discount/80 animate-pulse-gentle">:</span>
      <span className="bg-discount/10 px-1.5 py-0.5 rounded border border-discount/20">
        {formatNumber(timeLeft.seconds)}
      </span>
    </div>
  )
}
