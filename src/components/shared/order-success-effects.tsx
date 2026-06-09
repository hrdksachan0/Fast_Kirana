'use client'

import { useEffect, useRef } from 'react'
import { playSuccessChime } from '@/lib/audio'
import { triggerHaptic } from '@/lib/haptic'
import { useCart } from '@/hooks/use-cart'

export function OrderSuccessEffects() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const { clearCart } = useCart()

  useEffect(() => {
    // Play success chime & haptics instantly
    playSuccessChime()
    triggerHaptic('success')
    clearCart()


    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let animationFrameId: number

    // Set canvas sizes
    const resizeCanvas = () => {
      canvas.width = window.innerWidth
      canvas.height = window.innerHeight
    }
    resizeCanvas()
    window.addEventListener('resize', resizeCanvas)

    // Confetti particles
    interface Particle {
      x: number
      y: number
      size: number
      color: string
      speedX: number
      speedY: number
      rotation: number
      rotationSpeed: number
    }

    const colors = [
      '#e20a22', // Primary red
      '#ff4d62', // Primary light
      '#00b140', // Accent green
      '#3cc070', // Accent light
      '#f59e0b', // Amber
      '#3b82f6', // Blue
      '#8b5cf6', // Violet
    ]
    const particles: Particle[] = []

    // Populate particles starting from top/middle
    for (let i = 0; i < 140; i++) {
      particles.push({
        x: Math.random() * canvas.width,
        y: Math.random() * -200 - 20, // Start slightly above screen
        size: Math.random() * 8 + 6,
        color: colors[Math.floor(Math.random() * colors.length)],
        speedX: Math.random() * 6 - 3,
        speedY: Math.random() * 5 + 4,
        rotation: Math.random() * 360,
        rotationSpeed: Math.random() * 5 - 2.5,
      })
    }

    // Animation loop
    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      let active = false
      particles.forEach((p) => {
        p.x += p.speedX
        p.y += p.speedY
        p.rotation += p.rotationSpeed

        // Soft gravity pull
        p.speedY += 0.05

        // Render particle if on-screen
        if (p.y < canvas.height + 20) {
          active = true
          ctx.save()
          ctx.translate(p.x, p.y)
          ctx.rotate((p.rotation * Math.PI) / 180)
          ctx.fillStyle = p.color
          // Draw standard rectangular confetti
          ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 1.5)
          ctx.restore()
        }
      })

      if (active) {
        animationFrameId = requestAnimationFrame(animate)
      }
    }
    animate()

    return () => {
      window.removeEventListener('resize', resizeCanvas)
      cancelAnimationFrame(animationFrameId)
    }
  }, [])

  return (
    <canvas
      ref={canvasRef}
      className="fixed inset-0 pointer-events-none z-[9999] w-full h-full"
    />
  )
}
