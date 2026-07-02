'use client'

import { useEffect, useRef, useState } from 'react'
import { useRouter, usePathname } from 'next/navigation'
import { ArrowLeft } from 'lucide-react'
import { cn } from '@/lib/utils'

export function SwipeToBack() {
  const router = useRouter()
  const pathname = usePathname()
  const [mounted, setMounted] = useState(false)

  const containerRef = useRef<HTMLDivElement>(null)
  const progressCircleRef = useRef<SVGCircleElement>(null)

  const startX = useRef<number | null>(null)
  const startY = useRef<number | null>(null)
  const currentPull = useRef<number>(0)
  const isGestureActive = useRef<boolean>(false)
  const hasVibrated = useRef<boolean>(false)

  // Don't enable on the homepage since there's nowhere to go back to
  const isEnabled = pathname !== '/'

  useEffect(() => {
    setMounted(true)
  }, [])

  useEffect(() => {
    if (!mounted || !isEnabled) return

    const EDGE_THRESHOLD = 24 // px from left edge
    const SWIPE_THRESHOLD = 80 // px pull distance to trigger
    const MAX_PULL = 130 // max drag distance px

    const handleTouchStart = (e: TouchEvent) => {
      const touch = e.touches[0]
      if (touch.clientX < EDGE_THRESHOLD) {
        startX.current = touch.clientX
        startY.current = touch.clientY
        currentPull.current = 0
        isGestureActive.current = false
        hasVibrated.current = false
      }
    }

    const handleTouchMove = (e: TouchEvent) => {
      if (startX.current === null || startY.current === null) return
      const touch = e.touches[0]
      const deltaX = touch.clientX - startX.current
      const deltaY = touch.clientY - startY.current

      // Gesture activation detection
      if (!isGestureActive.current) {
        // Activate if horizontal swipe to the right dominates
        if (deltaX > 12 && deltaX > Math.abs(deltaY) * 1.5) {
          isGestureActive.current = true
        } else if (Math.abs(deltaY) > 8 || deltaX < 0) {
          // If vertical swipe dominates, or user swipes left, cancel start detection
          startX.current = null
          startY.current = null
          return
        }
      }

      if (isGestureActive.current) {
        // Prevent page scroll and bouncing
        if (e.cancelable) {
          e.preventDefault()
        }

        const pull = Math.min(MAX_PULL, Math.max(0, deltaX))
        currentPull.current = pull

        const progress = Math.min(100, (pull / SWIPE_THRESHOLD) * 100)
        const posY = Math.max(60, Math.min(window.innerHeight - 60, touch.clientY))

        const container = containerRef.current
        const progressCircle = progressCircleRef.current

        if (container) {
          // Slide in from left edge: pull - 56px (width of indicator)
          const translateX = pull - 64
          container.style.display = 'flex'
          container.style.opacity = String(Math.min(1, pull / 25))
          container.style.top = `${posY}px`

          if (progress >= 100) {
            container.style.transform = `translate3d(${translateX}px, -50%, 0) scale(1.1)`
            
            // Apply brand red theme when trigger is active
            container.classList.remove('bg-background/80', 'dark:bg-zinc-900/80', 'text-text-primary')
            container.classList.add('bg-primary', 'text-white', 'shadow-[0_0_15px_rgba(226,10,34,0.45)]')

            // Trigger brief single haptic vibration once when crossing threshold
            if (!hasVibrated.current) {
              try {
                if (typeof window !== 'undefined' && window.navigator && window.navigator.vibrate) {
                  window.navigator.vibrate(12)
                }
              } catch (err) {
                // Ignore silent vibrate errors
              }
              hasVibrated.current = true
            }
          } else {
            container.style.transform = `translate3d(${translateX}px, -50%, 0) scale(1)`
            
            // Revert to default glassmorphic theme
            container.classList.remove('bg-primary', 'text-white', 'shadow-[0_0_15px_rgba(226,10,34,0.45)]')
            container.classList.add('bg-background/80', 'dark:bg-zinc-900/80', 'text-text-primary')
            
            if (hasVibrated.current) {
              hasVibrated.current = false
            }
          }
        }

        if (progressCircle) {
          // Circle circumference for r=16 is 2 * PI * 16 = ~100.5
          const circumference = 100.53
          const strokeDashoffset = circumference - (progress / 100) * circumference
          progressCircle.style.strokeDashoffset = String(strokeDashoffset)
        }
      }
    }

    const resetIndicator = (didTrigger: boolean) => {
      const container = containerRef.current
      if (container) {
        container.style.transition = 'all 0.25s cubic-bezier(0.19, 1, 0.22, 1)'
        
        if (didTrigger) {
          // Slide off quickly and fade out
          container.style.transform = `translate3d(120px, -50%, 0) scale(0.8)`
          container.style.opacity = '0'
        } else {
          // Slide back left
          container.style.transform = `translate3d(-64px, -50%, 0) scale(0.9)`
          container.style.opacity = '0'
        }

        setTimeout(() => {
          container.style.transition = ''
          container.style.display = 'none'
        }, 250)
      }

      startX.current = null
      startY.current = null
      currentPull.current = 0
      isGestureActive.current = false
      hasVibrated.current = false
    }

    const handleTouchEnd = () => {
      if (startX.current === null) return

      if (isGestureActive.current && currentPull.current >= SWIPE_THRESHOLD) {
        resetIndicator(true)
        router.back()
      } else {
        resetIndicator(false)
      }
    }

    const handleTouchCancel = () => {
      resetIndicator(false)
    }

    // Register listeners with { passive: false } to allow e.preventDefault() on touchmove
    document.addEventListener('touchstart', handleTouchStart, { passive: true })
    document.addEventListener('touchmove', handleTouchMove, { passive: false })
    document.addEventListener('touchend', handleTouchEnd, { passive: true })
    document.addEventListener('touchcancel', handleTouchCancel, { passive: true })

    return () => {
      document.removeEventListener('touchstart', handleTouchStart)
      document.removeEventListener('touchmove', handleTouchMove)
      document.removeEventListener('touchend', handleTouchEnd)
      document.removeEventListener('touchcancel', handleTouchCancel)
    }
  }, [mounted, isEnabled, router])

  if (!mounted || !isEnabled) return null

  return (
    <div
      ref={containerRef}
      style={{ display: 'none', position: 'fixed', left: 0, zIndex: 99999 }}
      className="gpu-accelerated h-12 w-12 rounded-full flex items-center justify-center border border-border/80 dark:border-zinc-800 shadow-elevated backdrop-blur-md bg-background/80 dark:bg-zinc-900/80 text-text-primary pointer-events-none"
    >
      {/* Circle Progress Tracker */}
      <svg className="absolute inset-0 -rotate-90 w-full h-full" viewBox="0 0 36 36">
        <circle
          cx="18"
          cy="18"
          r="16"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.5"
          className="text-border/20 dark:text-zinc-800/30"
        />
        <circle
          ref={progressCircleRef}
          cx="18"
          cy="18"
          r="16"
          fill="none"
          stroke="currentColor"
          strokeWidth="2.5"
          className="text-primary dark:text-primary-light"
          strokeDasharray="100.53"
          strokeDashoffset="100.53"
          strokeLinecap="round"
          style={{ transition: 'stroke-dashoffset 0.05s ease-out' }}
        />
      </svg>

      <ArrowLeft size={18} className="stroke-[2.5]" />
    </div>
  )
}
