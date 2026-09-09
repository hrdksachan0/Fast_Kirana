/**
 * SuperAdmin configuration — loaded from the database at cold-start,
 * cached in-memory for zero-lookups per request.
 *
 * Replaces all hardcoded phone numbers, canonical email mappings,
 * and email-heuristic checks scattered across auth.ts, auth-guard.ts,
 * and 15+ API route files.
 */

import { prisma } from '@/lib/prisma'

// ─── Default Canonical Fallback (Zero Lockout Guarantee) ───────────────────
const DEFAULT_STAFF_ACCOUNTS: Array<{ phone: string; email: string; restaurantId?: string }> = [
  { phone: '9170942500', email: 'superadmin@fastkirana.com' },
  { phone: '7054470303', email: 'admin@fastkirana.com' },
  { phone: '8112849854', email: 'asrestaurant3@gmail.com', restaurantId: 'REST-101' },
  { phone: '9250138656', email: 'restaurant@fastkirana.com', restaurantId: 'REST-102' },
  { phone: '7991488783', email: 'baludyanhotelrestaurant@gmail.com', restaurantId: 'REST-103' },
  { phone: '9900112233', email: 'chef@fastkirana.com', restaurantId: 'REST-104' },
]

// ─── In-memory cache ──────────────────────────────────────────────────────────

const superadminPhones = new Set<string>()
const phoneToEmail = new Map<string, string>() // last-10-digits → email
const phoneToRestaurantId = new Map<string, string>() // last-10-digits → restaurantId

// Pre-populate with defaults immediately
superadminPhones.add('9170942500')
for (const acc of DEFAULT_STAFF_ACCOUNTS) {
  phoneToEmail.set(acc.phone, acc.email)
  if (acc.restaurantId) {
    phoneToRestaurantId.set(acc.phone, acc.restaurantId)
  }
}

let loaded = false

async function loadCache() {
  if (loaded) return
  try {
    if ((prisma as any).superAdmin) {
      const rows = await (prisma as any).superAdmin.findMany({
        where: { isActive: true },
        select: { phone: true, email: true, assignedRestaurantId: true },
      })

      for (const row of rows) {
        const digits = row.phone.replace(/\D/g, '').slice(-10)
        if (row.email === 'superadmin@fastkirana.com' || digits === '9170942500') {
          superadminPhones.add(digits)
        }
        phoneToEmail.set(digits, row.email)
        if (row.assignedRestaurantId) {
          phoneToRestaurantId.set(digits, row.assignedRestaurantId)
        }
      }
    }
    loaded = true
  } catch (e) {
    console.warn('[SuperAdminConfig] DB table super_admins not yet ready, using default fallback cache')
  }
}

/** Load immediately on import (server-side, cold start). */
loadCache().catch(() => {})

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Check if a phone number belongs to a superadmin.
 * Accepts any format (+91XXXXXXXXXX, 91XXXXXXXXXX, XXXXXXXXXX).
 */
export function isSuperadminPhone(phone: string | null | undefined): boolean {
  if (!phone) return false
  const digits = phone.replace(/\D/g, '').slice(-10)
  return superadminPhones.has(digits)
}

/**
 * Return the canonical email for a phone number, or null.
 */
export function getCanonicalEmail(phone: string | null | undefined): string | null {
  if (!phone) return null
  const digits = phone.replace(/\D/g, '').slice(-10)
  return phoneToEmail.get(digits) ?? null
}

/**
 * Return the assigned restaurant ID for a superadmin phone, or null.
 */
export function getAssignedRestaurantId(phone: string | null | undefined): string | null {
  if (!phone) return null
  const digits = phone.replace(/\D/g, '').slice(-10)
  return phoneToRestaurantId.get(digits) ?? null
}

/**
 * Find the canonical user from a list of matching users for a given phone.
 * Returns the canonical user or null.
 *
 * Replaces the duplicated pattern:
 *   matchingUsers.find(u => (cleanDigits === '9170942500' && u.email === '...') || ...)
 */
export function findCanonicalUser<T extends { email?: string | null; assignedRestaurantId?: string | null }>(
  matchingUsers: T[],
  phoneDigits: string,
): T | null {
  const canonicalEmail = phoneToEmail.get(phoneDigits)
  if (!canonicalEmail) return null

  const canonicalRestaurantId = phoneToRestaurantId.get(phoneDigits) ?? null

  // Find user matching the canonical email
  const match = matchingUsers.find(u => {
    if (u.email?.toLowerCase() !== canonicalEmail.toLowerCase()) return false
    if (canonicalRestaurantId && u.assignedRestaurantId) {
      return u.assignedRestaurantId === canonicalRestaurantId
    }
    return true
  })

  return match ?? null
}

/** Force reload from database (e.g., after a superadmin is added/removed). */
export async function reloadSuperadminCache() {
  loaded = false
  await loadCache()
}

/** Check if the loaded cache has any entries (for health checks). */
export function isSuperadminCacheLoaded(): boolean {
  return loaded
}
