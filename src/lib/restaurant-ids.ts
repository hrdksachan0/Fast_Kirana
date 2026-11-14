/**
 * Universal restaurant ID normalizer.
 * Maps legacy CUIDs, slugs, and variations to canonical database IDs:
 * - REST-101: A.S. Restaurant
 * - REST-102: Wedson Restaurant
 * - REST-103: Bal Udyan Restaurant
 * - REST-104: Hot Pizza Lovers
 * - REST-105: Zayka Non Veg Hotel
 * - REST-106: Radha Rani Restaurant
 */
export interface SessionLike {
  user?: {
    id?: string
    role?: string
    phone?: string | null
    assignedRestaurantId?: string | null
    assignedStoreId?: string | null
  } | null
}

export function normalizeRestaurantId(id: string | null | undefined): string | null {
  if (!id) return null
  const clean = String(id).trim().toLowerCase()

  if (
    clean === 'cms2p1lap0000n0id8alldboy' ||
    clean === 'rest-101' ||
    clean === 'as-restaurant' ||
    clean === 'as-cafe' ||
    clean.includes('as-restaurant') ||
    clean.includes('a.s')
  ) {
    return 'REST-101'
  }

  if (
    clean === 'cms2p1lyx0001n0idod904lfu' ||
    clean === 'rest-102' ||
    clean === 'wedson' ||
    clean === 'wedson-restaurant' ||
    clean.includes('wedson')
  ) {
    return 'REST-102'
  }

  if (
    clean === 'cmsbhxb6a000304if8kf1cwji' ||
    clean === 'rest-103' ||
    clean === 'bal-udyan' ||
    clean === 'bal-udyan-restaurant' ||
    clean === 'baludyan' ||
    clean.includes('bal')
  ) {
    return 'REST-103'
  }

  if (
    clean === 'cmtn66nhy000004k0fu84b7ke' ||
    clean === 'rest-104' ||
    clean === 'hot-pizza-lovers' ||
    clean === 'pizza-lovers' ||
    clean === 'pizza-lover' ||
    clean.includes('pizza')
  ) {
    return 'REST-104'
  }

  if (
    clean === '0b2470fa-8221-49e1-aa3b-4c98b2bb5941' ||
    clean === 'rest-105' ||
    clean === 'zayka' ||
    clean === 'zayka-non-veg' ||
    clean === 'zayka-non-veg-hotel' ||
    clean.includes('zayka')
  ) {
    return 'REST-105'
  }

  if (
    clean === 'rest-106' ||
    clean === 'radha-rani' ||
    clean === 'radha-rani-restaurant' ||
    clean === 'radharani' ||
    clean.includes('radha')
  ) {
    return 'REST-106'
  }

  return id
}

/**
 * Universal helper to resolve restaurant ID cleanly across sessions and requests.
 * Eliminates redundant `(session?.user as any)?.assignedRestaurantId` and copy-pasted if/else blocks.
 */
export function getSessionRestaurantId(
  session?: SessionLike | null,
  request?: Request | null,
  paramRestId?: string | null
): string | null {
  const isPlatformAdmin = session?.user?.role === 'ADMIN'
  const sessionRestId = session?.user?.assignedRestaurantId

  // Strict tenant isolation: If not admin, always force their own assigned restaurant ID
  let targetId = (!isPlatformAdmin && sessionRestId)
    ? sessionRestId
    : (paramRestId || sessionRestId || (request ? request.headers.get('x-restaurant-id') : null))

  if (targetId === 'ALL') return 'ALL'
  return normalizeRestaurantId(targetId)
}

