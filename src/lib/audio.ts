/**
 * Client-side Web Audio API utility to synthesize premium sound effects
 * dynamically in the browser, eliminating the need to load static audio files.
 */

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null
  const AudioContextClass = (window as unknown as { AudioContext?: typeof AudioContext; webkitAudioContext?: typeof AudioContext }).AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
  if (!AudioContextClass) return null
  return new AudioContextClass()
}

/**
 * Play a snappy, satisfying "pop" sound when adding items to the cart
 */
export function playCartPop() {
  const ctx = getAudioContext()
  if (!ctx) return

  try {
    if (ctx.state === 'suspended') {
      ctx.resume()
    }

    const osc = ctx.createOscillator()
    const gain = ctx.createGain()

    osc.connect(gain)
    gain.connect(ctx.destination)

    osc.type = 'sine'
    
    const startTime = ctx.currentTime
    osc.frequency.setValueAtTime(140, startTime)
    osc.frequency.exponentialRampToValueAtTime(520, startTime + 0.1)

    gain.gain.setValueAtTime(0, startTime)
    gain.gain.linearRampToValueAtTime(0.25, startTime + 0.015)
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.1)

    osc.start(startTime)
    osc.stop(startTime + 0.11)
  } catch {
    console.warn('Web Audio Playback failed')
  }
}

/**
 * Play a beautiful, sweet dual-tone success chime for order placements or notifications
 */
export function playSuccessChime() {
  const ctx = getAudioContext()
  if (!ctx) return

  try {
    if (ctx.state === 'suspended') {
      ctx.resume()
    }

    const startTime = ctx.currentTime

    const playTone = (freq: number, delay: number, duration: number, volume: number) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.connect(gain)
      gain.connect(ctx.destination)

      osc.type = 'triangle'
      osc.frequency.setValueAtTime(freq, startTime + delay)

      gain.gain.setValueAtTime(0, startTime + delay)
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration)

      osc.start(startTime + delay)
      osc.stop(startTime + delay + duration + 0.05)
    }

    playTone(523.25, 0, 0.4, 0.15)
    playTone(783.99, 0.08, 0.5, 0.15)
  } catch {
    console.warn('Web Audio Playback failed')
  }
}

/**
 * Play a friendly notification chime alert (perfect for dashboards)
 */
export function playNotificationChime() {
  const ctx = getAudioContext()
  if (!ctx) return

  try {
    if (ctx.state === 'suspended') {
      ctx.resume()
    }

    const startTime = ctx.currentTime

    const playTone = (freq: number, delay: number, duration: number, volume: number) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.connect(gain)
      gain.connect(ctx.destination)

      osc.type = 'sine'
      osc.frequency.setValueAtTime(freq, startTime + delay)

      gain.gain.setValueAtTime(0, startTime + delay)
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.03)
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration)

      osc.start(startTime + delay)
      osc.stop(startTime + delay + duration + 0.05)
    }

    playTone(659.25, 0, 0.3, 0.12)
    playTone(880.00, 0.07, 0.4, 0.12)
  } catch {
    console.warn('Web Audio Playback failed')
  }
}

export function tryUnlockAudioContext(): Promise<boolean> {
  const ctx = getAudioContext()
  if (!ctx) return Promise.resolve(false)
  if (ctx.state === 'suspended') {
    return ctx.resume().then(() => ctx.state === 'running').catch(() => false)
  }
  return Promise.resolve(ctx.state === 'running')
}

export function isAudioContextSuspended(): boolean {
  const ctx = getAudioContext()
  return !!ctx && ctx.state === 'suspended'
}

/**
 * Play a louder, distinct dual-tone chime specifically for kitchen alerts
 */
export function playKitchenAlarmChime() {
  const ctx = getAudioContext()
  if (!ctx) return

  try {
    if (ctx.state === 'suspended') {
      ctx.resume()
    }

    const startTime = ctx.currentTime

    const playTone = (freq: number, delay: number, duration: number, volume: number) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.connect(gain)
      gain.connect(ctx.destination)

      osc.type = 'triangle'
      osc.frequency.setValueAtTime(freq, startTime + delay)

      gain.gain.setValueAtTime(0, startTime + delay)
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration)

      osc.start(startTime + delay)
      osc.stop(startTime + delay + duration + 0.05)
    }

    playTone(783.99, 0, 0.35, 0.25)
    playTone(1046.50, 0.12, 0.45, 0.25)
  } catch {
    console.warn('Web Audio Playback failed')
  }
}

/**
 * Play the custom FastKirana order stage chime file or synthesized fallback
 */
export function playOrderChime() {
  if (typeof window === 'undefined') return
  try {
    const audio = new Audio('/sounds/order_chime.mp3')
    audio.volume = 0.8
    const playPromise = audio.play()
    if (playPromise !== undefined) {
      playPromise.catch(() => {
        // Fallback to synthesized sweet chime if audio file is blocked by browser
        playSuccessChime()
      })
    }
  } catch {
    playSuccessChime()
  }
}
