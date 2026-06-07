/**
 * Client-side Web Audio API utility to synthesize premium sound effects
 * dynamically in the browser, eliminating the need to load static audio files.
 */

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext;
  if (!AudioContextClass) return null;
  return new AudioContextClass();
}

/**
 * Play a snappy, satisfying "pop" sound when adding items to the cart
 */
export function playCartPop() {
  const ctx = getAudioContext();
  if (!ctx) return;

  try {
    // Resume context if suspended (browser security autoplays policy)
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.type = 'sine';
    
    // Quick frequency sweep upwards to make it feel bouncy
    const startTime = ctx.currentTime;
    osc.frequency.setValueAtTime(140, startTime);
    osc.frequency.exponentialRampToValueAtTime(520, startTime + 0.1);

    // Volume envelope: fast attack, quick decay
    gain.gain.setValueAtTime(0, startTime);
    gain.gain.linearRampToValueAtTime(0.25, startTime + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.001, startTime + 0.1);

    osc.start(startTime);
    osc.stop(startTime + 0.11);
  } catch (err) {
    console.warn('Web Audio Playback failed:', err);
  }
}

/**
 * Play a beautiful, sweet dual-tone success chime for order placements or notifications
 */
export function playSuccessChime() {
  const ctx = getAudioContext();
  if (!ctx) return;

  try {
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const startTime = ctx.currentTime;

    // We play two overlapping tones for harmony (C5 and G5)
    const playTone = (freq: number, delay: number, duration: number, volume: number) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.type = 'triangle'; // Softer, warmer harmonic content than sine
      osc.frequency.setValueAtTime(freq, startTime + delay);

      gain.gain.setValueAtTime(0, startTime + delay);
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration);

      osc.start(startTime + delay);
      osc.stop(startTime + delay + duration + 0.05);
    };

    // Beautiful major fifth interval: C5 (523.25 Hz) then G5 (783.99 Hz)
    playTone(523.25, 0, 0.4, 0.15);
    playTone(783.99, 0.08, 0.5, 0.15);
  } catch (err) {
    console.warn('Web Audio Playback failed:', err);
  }
}

/**
 * Play a friendly notification chime alert (perfect for dashboards)
 */
export function playNotificationChime() {
  const ctx = getAudioContext();
  if (!ctx) return;

  try {
    if (ctx.state === 'suspended') {
      ctx.resume();
    }

    const startTime = ctx.currentTime;

    const playTone = (freq: number, delay: number, duration: number, volume: number) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, startTime + delay);

      gain.gain.setValueAtTime(0, startTime + delay);
      gain.gain.linearRampToValueAtTime(volume, startTime + delay + 0.03);
      gain.gain.exponentialRampToValueAtTime(0.001, startTime + delay + duration);

      osc.start(startTime + delay);
      osc.stop(startTime + delay + duration + 0.05);
    };

    // Ascending arpeggio (E5 -> A5)
    playTone(659.25, 0, 0.3, 0.12);
    playTone(880.00, 0.07, 0.4, 0.12);
  } catch (err) {
    console.warn('Web Audio Playback failed:', err);
  }
}
