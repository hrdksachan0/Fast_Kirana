/**
 * Client-side Web Audio API utility to synthesize premium sound effects
 * dynamically in the browser, eliminating the need to load static audio files.
 */

let sharedAudioContext: AudioContext | null = null

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null
  const AudioContextClass =
    (window as any).AudioContext || (window as any).webkitAudioContext
  if (!AudioContextClass) return null
  if (!sharedAudioContext || sharedAudioContext.state === 'closed') {
    try {
      sharedAudioContext = new AudioContextClass()
    } catch {
      sharedAudioContext = null
      return null
    }
  }
  if (sharedAudioContext && sharedAudioContext.state === 'suspended') {
    sharedAudioContext.resume().catch(() => {})
  }
  return sharedAudioContext
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
 * Play a high-volume, unmistakable Swiggy/Zomato merchant buzzer alarm.
 * Combines native HTML5 audio chime (/sounds/order_chime.mp3) with an intense
 * dual-burst multi-tone Web Audio synthesizer (880Hz -> 1174Hz -> 1318Hz -> 1760Hz).
 */
export function playSwiggyOrderBuzzer() {
  if (typeof window === 'undefined') return

  // 1. Trigger HTML5 Audio element (/sounds/order_chime.mp3)
  try {
    const audio = new Audio('/sounds/order_chime.mp3')
    audio.volume = 1.0
    audio.play().catch(() => {})
  } catch {}

  // 2. High-urgency Web Audio dual-burst synthesizer
  const ctx = getAudioContext()
  if (!ctx) return

  try {
    if (ctx.state === 'suspended') {
      ctx.resume().catch(() => {})
    }

    const startTime = ctx.currentTime

    const playTone = (
      freq: number,
      delay: number,
      duration: number,
      volume: number,
      type: OscillatorType = 'triangle'
    ) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()

      osc.connect(gain)
      gain.connect(ctx.destination)

      osc.type = type
      osc.frequency.setValueAtTime(freq, startTime + delay)

      gain.gain.setValueAtTime(0, startTime + delay)
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.02)
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration)

      osc.start(startTime + delay)
      osc.stop(startTime + delay + duration + 0.05)
    }

    // Burst 1: Rising alarm chime
    playTone(880.0, 0.0, 0.12, 0.45, 'triangle')
    playTone(1174.66, 0.1, 0.14, 0.5, 'triangle')
    playTone(1318.51, 0.22, 0.16, 0.55, 'sine')
    playTone(1760.0, 0.36, 0.22, 0.55, 'triangle')

    // Burst 2: Second high-pitched repeat
    playTone(880.0, 0.55, 0.12, 0.45, 'triangle')
    playTone(1174.66, 0.65, 0.14, 0.5, 'triangle')
    playTone(1318.51, 0.77, 0.16, 0.55, 'sine')
    playTone(1760.0, 0.91, 0.35, 0.6, 'triangle')
  } catch (err) {
    console.warn('Web Audio Buzzer failed:', err)
  }
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

/**
 * Loud, clear voice announcement for Store Hub / Picker / Chef
 * e.g. "Naya Order number 1980 - 4 items"
 */
export function speakOrderAlert(readableId: number | string, itemCount: number) {
  if (typeof window === 'undefined') return
  try {
    // 1. Play kitchen wake-up chime first
    playKitchenAlarmChime()

    // 2. Speak Hindi/Indian-English voice announcement via Web Speech API
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel() // clear any prior speech
      const text = `Naya Order number ${readableId}, ${itemCount} items`
      const utterance = new SpeechSynthesisUtterance(text)
      utterance.rate = 1.0
      utterance.pitch = 1.05
      utterance.volume = 1.0
      utterance.lang = 'hi-IN'

      // Fallback voice search for en-IN or hi-IN
      const voices = window.speechSynthesis.getVoices()
      const indianVoice = voices.find(v => v.lang.includes('IN') || v.lang.includes('hi'))
      if (indianVoice) {
        utterance.voice = indianVoice
      }

      window.speechSynthesis.speak(utterance)
    }
  } catch (err) {
    console.warn('Voice announcement failed:', err)
  }
}

/**
 * Loud, unmistakable Paytm/PhonePe style voice announcement for Doorstep Delivery:
 * "FastMinute par [Amount] rupaye prapt hue"
 */
export function speakDoorstepPaymentReceived(amount: number, readableId?: string | number) {
  if (typeof window === 'undefined') return
  try {
    // 1. Play sweet dual-tone success chime
    playSuccessChime()

    // 2. Speak Hindi soundbox announcement
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel()
      const rounded = Math.round(amount)
      const text = `FastMinute par ${rounded} rupaye prapt hue. Order verified.`
      const utterance = new SpeechSynthesisUtterance(text)
      utterance.rate = 0.95
      utterance.pitch = 1.05
      utterance.volume = 1.0
      utterance.lang = 'hi-IN'

      const voices = window.speechSynthesis.getVoices()
      const indianVoice = voices.find(v => v.lang.includes('IN') || v.lang.includes('hi'))
      if (indianVoice) {
        utterance.voice = indianVoice
      }

      window.speechSynthesis.speak(utterance)
    }
  } catch (err) {
    console.warn('Doorstep voice announcement failed:', err)
  }
}


