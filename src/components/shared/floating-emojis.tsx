'use client'
import React, { useEffect, useState } from 'react'
import { motion } from 'framer-motion'

interface FloatingEmojisProps {
  type: 'food' | 'cafe' | 'grocery'
}

const emojiSets = {
  food: ['🍕', '🍔', '🍛', '🍜', '🍗', '🌮', '🍣', '🍩'],
  cafe: ['☕', '🍩', '🍨', '🍪', '🥤', '🥐', '🍰', '🧇'],
  grocery: ['🍎', '🍌', '🥕', '🥛', '🍞', '🥚', '🧀', '🥦', '🍇']
}

export function FloatingEmojis({ type }: FloatingEmojisProps) {
  const [emojis, setEmojis] = useState<any[]>([])
  
  useEffect(() => {
    const list = emojiSets[type] || emojiSets.food
    // Create 8 random particles
    const particles = Array.from({ length: 8 }).map((_, i) => ({
      id: i,
      char: list[Math.floor(Math.random() * list.length)],
      left: `${Math.random() * 90 + 5}%`,
      delay: Math.random() * 4,
      duration: Math.random() * 12 + 18, // 18s to 30s slow drift
      size: Math.random() * 12 + 16, // 16px to 28px
      opacity: Math.random() * 0.08 + 0.04 // Soft 4% to 12% opacity
    }))
    setEmojis(particles)
  }, [type])

  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none select-none z-0">
      {emojis.map((p) => (
        <motion.span
          key={p.id}
          className="absolute font-sans"
          style={{
            left: p.left,
            fontSize: `${p.size}px`,
            bottom: '-10%',
            opacity: 0
          }}
          animate={{
            y: [0, -1000],
            x: [0, Math.random() * 60 - 30, 0],
            rotate: [0, Math.random() * 180 - 90],
            opacity: [0, p.opacity, p.opacity, 0]
          }}
          transition={{
            duration: p.duration,
            repeat: Infinity,
            delay: p.delay,
            ease: 'linear'
          }}
        >
          {p.char}
        </motion.span>
      ))}
    </div>
  )
}
