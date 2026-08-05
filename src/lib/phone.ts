/**
 * Phone number normalization utilities.
 *
 * Handles common Indian phone formats:
 *   "9876543210"           → "+919876543210"
 *   "+919876543210"        → "+919876543210"
 *   "+91 98765-43210"      → "+919876543210"
 *   "919876543210"         → "+919876543210"
 *   "whatsapp:+91-9876543210" → "+919876543210" (after stripping prefix)
 */

/** Extract only digits from any phone string */
function digitsOnly(phone: string): string {
  return phone.replace(/\D/g, '')
}

/**
 * Normalize a phone number to E.164 format (+91XXXXXXXXXX).
 * - Strips all non-digit characters
 * - Strips "wa-" / "whatsapp:" / "wa:" prefixes if present
 * - Adds +91 if 10-digit Indian number
 * - Preserves + if already present on 12-digit (91XXXXXXXXXX)
 * Returns the normalized string, or the trimmed original if unrecognizable.
 */
export function normalizePhone(phone: string): string {
  if (!phone) return ''

  let cleaned = phone.trim()

  // Strip common prefixes
  if (cleaned.startsWith('wa-') && cleaned.includes('@')) {
    cleaned = cleaned.split('@')[0].replace('wa-', '')
  } else if (cleaned.toLowerCase().startsWith('whatsapp:')) {
    cleaned = cleaned.slice(10)
  } else if (cleaned.toLowerCase().startsWith('wa:')) {
    cleaned = cleaned.slice(3)
  }

  const digits = digitsOnly(cleaned)

  if (digits.length === 10) return `+91${digits}`
  if (digits.length === 12 && digits.startsWith('91')) return `+${digits}`

  // Return trimmed original for unrecognized formats
  return phone.trim()
}

/**
 * Get the last 10 digits of a phone number (for OTP lookup, validation, etc.)
 */
export function getLast10Digits(phone: string): string {
  return digitsOnly(phone).slice(-10)
}

/**
 * Check if a string looks like a valid Indian phone number.
 * Accepts 10-digit (XXXXXXXXXX) or 12-digit with 91 prefix (91XXXXXXXXXX)
 */
export function isValidIndianPhone(phone: string): boolean {
  const digits = digitsOnly(phone)
  return digits.length === 10 || (digits.length === 12 && digits.startsWith('91'))
}

/**
 * Format a phone for display: "+91 98765 43210"
 */
export function formatPhoneDisplay(phone: string): string {
  const digits = getLast10Digits(phone)
  if (digits.length !== 10) return phone
  return `+91 ${digits.slice(0, 5)} ${digits.slice(5)}`
}
