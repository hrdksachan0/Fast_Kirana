/**
 * Indian phone number validation and formatting helpers.
 */

/**
 * Validates whether a given string is a valid 10-digit Indian phone number.
 * Accepts formats: 9876543210, +919876543210, 09876543210, 98765-43210
 */
export function isValidIndianPhone(phone: string): boolean {
  if (!phone) return false
  const cleaned = phone.replace(/\D/g, '')
  if (cleaned.length === 10) {
    return /^[6-9]\d{9}$/.test(cleaned)
  }
  if (cleaned.length === 12 && cleaned.startsWith('91')) {
    return /^[6-9]\d{9}$/.test(cleaned.slice(2))
  }
  if (cleaned.length === 11 && cleaned.startsWith('0')) {
    return /^[6-9]\d{9}$/.test(cleaned.slice(1))
  }
  return false
}

/**
 * Normalizes phone number to standard 10-digit format without country code.
 */
export function normalizeIndianPhone(phone: string): string {
  if (!phone) return ''
  const cleaned = phone.replace(/\D/g, '')
  if (cleaned.length === 12 && cleaned.startsWith('91')) {
    return cleaned.slice(2)
  }
  if (cleaned.length === 11 && cleaned.startsWith('0')) {
    return cleaned.slice(1)
  }
  return cleaned.slice(-10)
}

/**
 * Formats phone number for display: "+91 98765 43210"
 */
export function formatIndianPhoneDisplay(phone: string): string {
  const norm = normalizeIndianPhone(phone)
  if (norm.length !== 10) return phone
  return `+91 ${norm.slice(0, 5)} ${norm.slice(5)}`
}
