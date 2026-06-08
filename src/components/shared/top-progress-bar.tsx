'use client'

import { useEffect, useState } from 'react'
import { usePathname, useSearchParams } from 'next/navigation'

export function TopProgressBar() {
  const pathname = usePathname()
  const searchParams = useSearchParams()
  const [progress, setProgress] = useState(0)
  const [visible, setVisible] = useState(false)

  const startLoading = () => {
    setVisible(true)
    setProgress(10)
  }

  const stopLoading = () => {
    setProgress(100)
    setTimeout(() => {
      setVisible(false)
      setTimeout(() => {
        setProgress(0)
      }, 300)
    }, 200)
  }

  // Animate the bar loader slowly up to 90%
  useEffect(() => {
    if (progress === 0 || progress === 100) return

    const interval = setInterval(() => {
      setProgress((prev) => {
        if (prev >= 90) return prev
        const increment = prev < 50 ? 5 : prev < 75 ? 2 : 0.5
        return Math.min(90, prev + increment)
      })
    }, 100)

    return () => clearInterval(interval)
  }, [progress])

  // Stop loading when route path or search query changes
  useEffect(() => {
    stopLoading()
  }, [pathname, searchParams])

  // Safety fallback to hide loader if navigation takes too long or gets cancelled
  useEffect(() => {
    if (!visible) return
    const timeout = setTimeout(() => {
      stopLoading()
    }, 6000)
    return () => clearTimeout(timeout)
  }, [visible])

  // Global listeners for instant user feedback
  useEffect(() => {
    if (typeof window === 'undefined') return

    const handleLinkClick = (e: MouseEvent) => {
      let target = e.target as HTMLElement | null
      while (target && target.tagName !== 'A') {
        target = target.parentElement
      }

      if (target && target.tagName === 'A') {
        const href = target.getAttribute('href')
        const targetAttr = target.getAttribute('target')
        
        if (
          href &&
          href.startsWith('/') &&
          !href.startsWith('/#') &&
          targetAttr !== '_blank' &&
          !e.defaultPrevented &&
          e.button === 0 && // left click only
          !e.metaKey &&
          !e.ctrlKey &&
          !e.shiftKey &&
          !e.altKey
        ) {
          startLoading()
        }
      }
    }

    // Intercept client-side routing fetch requests
    const originalFetch = window.fetch
    window.fetch = async (...args) => {
      const url = args[0]
      const options = args[1]

      const isRSC =
        (typeof url === 'string' && (url.includes('_rsc=') || url.includes('/_next/data/'))) ||
        (options?.headers && (
          (options.headers as any)['RSC'] === '1' ||
          (options.headers as any)['Next-Router-State-Tree']
        ))

      if (isRSC) {
        startLoading()
      }

      try {
        const response = await originalFetch(...args)
        if (isRSC) {
          stopLoading()
        }
        return response
      } catch (err) {
        if (isRSC) {
          stopLoading()
        }
        throw err
      }
    }

    document.addEventListener('click', handleLinkClick, { capture: true })

    return () => {
      document.removeEventListener('click', handleLinkClick, { capture: true })
      window.fetch = originalFetch
    }
  }, [])

  if (!visible) return null

  return (
    <div 
      className="absolute bottom-0 left-0 right-0 h-[1.5px] bg-primary z-[51] transition-all duration-300 ease-out pointer-events-none"
      style={{ 
        width: `${progress}%`,
        boxShadow: '0 0 6px #e20a22, 0 0 2px #e20a22'
      }}
    />
  )
}
