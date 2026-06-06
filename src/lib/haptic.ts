/**
 * Utility to trigger browser-native haptic feedback (vibration) on mobile devices
 */
export type HapticType = 'light' | 'medium' | 'success' | 'warning'

const PATTERNS: Record<HapticType, number | number[]> = {
  light: 12, // Short, subtle tick
  medium: 25, // Standard button click tick
  success: [20, 60, 20], // Double short pulse
  warning: [50, 100, 50], // Double firm pulse
}

export function triggerHaptic(type: HapticType = 'light') {
  if (
    typeof window !== 'undefined' &&
    typeof navigator !== 'undefined' &&
    'vibrate' in navigator
  ) {
    try {
      navigator.vibrate(PATTERNS[type])
    } catch (err) {
      // Fail silently on browsers that block vibration due to permission/security policies
      console.warn('Haptic vibration failed:', err)
    }
  }
}
