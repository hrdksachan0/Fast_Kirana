/**
 * Universal restaurant ID normalizer.
 * Maps legacy CUIDs, slugs, and variations to canonical database IDs:
 * - REST-101: A.S. Restaurant
 * - REST-102: Wedson Restaurant
 * - REST-103: Bal Udyan Restaurant
 * - REST-104: Pari Milk Dairy & Sweets
 */
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
    clean === 'pari-milk' ||
    clean === 'pari-milk-dairy-sweets' ||
    clean.includes('pari')
  ) {
    return 'REST-104'
  }

  return id
}
