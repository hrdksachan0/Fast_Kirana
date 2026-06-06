'use client'

import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'

interface FlyingItem {
  id: string
  startX: number
  startY: number
  endX: number
  endY: number
  imageUrl: string
}

export function CartFlyAnimation() {
  const [flyingItems, setFlyingItems] = useState<FlyingItem[]>([])

  useEffect(() => {
    const handleFly = (e: Event) => {
      const customEvent = e as CustomEvent<{
        startX: number
        startY: number
        imageUrl: string
      }>
      
      const { startX, startY, imageUrl } = customEvent.detail

      // Find the cart target element (mobile sticky cart or desktop navbar cart)
      const targetElement = 
        document.getElementById('cart-sticky-icon') || 
        document.getElementById('navbar-cart-icon') ||
        document.getElementById('mobile-bottom-cart-icon')

      let endX = window.innerWidth - 60
      let endY = window.innerHeight - 60

      if (targetElement) {
        const rect = targetElement.getBoundingClientRect()
        endX = rect.left + rect.width / 2
        endY = rect.top + rect.height / 2
      }

      const newItem: FlyingItem = {
        id: Math.random().toString(36).substring(2, 9),
        startX,
        startY,
        endX,
        endY,
        imageUrl: imageUrl || '📦',
      }

      setFlyingItems((prev) => [...prev, newItem])
    }

    window.addEventListener('cart-item-fly' as any, handleFly)
    return () => window.removeEventListener('cart-item-fly' as any, handleFly)
  }, [])

  const handleAnimationComplete = (id: string) => {
    // Remove completed items
    setFlyingItems((prev) => prev.filter((item) => item.id !== id))
    
    // Dispatch a bounce event to animate the cart button
    window.dispatchEvent(new CustomEvent('cart-bounce'))
  }

  return (
    <div className="fixed inset-0 pointer-events-none z-[9999] overflow-hidden">
      <AnimatePresence>
        {flyingItems.map((item) => (
          <motion.div
            key={item.id}
            initial={{
              position: 'absolute',
              left: 0,
              top: 0,
              x: item.startX,
              y: item.startY,
              scale: 1.2,
              opacity: 0.9,
              rotate: 0,
            }}
            animate={{
              x: item.endX - 24, // Center item (w-12 / 2 = 24)
              y: item.endY - 24,
              scale: 0.15,
              opacity: 0.3,
              rotate: 360,
            }}
            exit={{ opacity: 0 }}
            transition={{
              duration: 0.75,
              ease: [0.16, 1, 0.3, 1], // easeOutExpo
            }}
            onAnimationComplete={() => handleAnimationComplete(item.id)}
            className="w-12 h-12 rounded-xl border border-primary/20 bg-white dark:bg-zinc-900 shadow-[0_4px_20px_rgba(0,0,0,0.15)] flex items-center justify-center p-1 overflow-hidden"
          >
            {item.imageUrl && item.imageUrl !== '📦' ? (
              <img
                src={item.imageUrl}
                alt="flying product"
                className="w-full h-full object-contain rounded-lg"
              />
            ) : (
              <span className="text-xl">🛒</span>
            )}
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}
