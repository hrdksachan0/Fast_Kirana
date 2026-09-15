'use client'

/**
 * Lightweight HTML5 Canvas 2D confetti particle engine.
 * Spawns 120 multicolored confetti particles with physics, rotation, and auto-cleanup in 3 seconds.
 */
export function triggerConfetti() {
  if (typeof window === 'undefined') return
  const canvas = document.createElement('canvas')
  canvas.style.position = 'fixed'
  canvas.style.top = '0'
  canvas.style.left = '0'
  canvas.style.width = '100%'
  canvas.style.height = '100%'
  canvas.style.pointerEvents = 'none'
  canvas.style.zIndex = '9999'
  document.body.appendChild(canvas)

  const ctx = canvas.getContext('2d')
  if (!ctx) return

  const resizeCanvas = () => {
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
  }
  window.addEventListener('resize', resizeCanvas)
  resizeCanvas()

  const colors = ['#f43f5e', '#10b981', '#3b82f6', '#f59e0b', '#8b5cf6', '#ec4899', '#14b8a6']
  const particles: any[] = []

  for (let i = 0; i < 120; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * -canvas.height - 20,
      size: Math.random() * 6 + 4,
      color: colors[Math.floor(Math.random() * colors.length)],
      speed: Math.random() * 4 + 3,
      angle: Math.random() * 360,
      rotationSpeed: Math.random() * 4 - 2,
    })
  }

  let animationFrameId: number
  const startTime = Date.now()

  function update() {
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)

    if (Date.now() - startTime > 3000) {
      if (document.body.contains(canvas)) {
        document.body.removeChild(canvas)
      }
      window.removeEventListener('resize', resizeCanvas)
      cancelAnimationFrame(animationFrameId)
      return
    }

    let active = false
    particles.forEach((p) => {
      p.y += p.speed
      p.angle += p.rotationSpeed
      p.x += Math.sin((p.angle * Math.PI) / 180) * 0.8

      if (p.y < canvas.height + 20) {
        active = true
      }

      ctx.save()
      ctx.translate(p.x, p.y)
      ctx.rotate((p.angle * Math.PI) / 180)
      ctx.fillStyle = p.color
      ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size)
      ctx.restore()
    })

    if (active) {
      animationFrameId = requestAnimationFrame(update)
    } else {
      if (document.body.contains(canvas)) {
        document.body.removeChild(canvas)
      }
      window.removeEventListener('resize', resizeCanvas)
    }
  }

  update()
}
