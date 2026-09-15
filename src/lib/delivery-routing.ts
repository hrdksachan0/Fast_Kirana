/**
 * Advanced Delivery Route Optimization Engine
 *
 * Implements:
 * 1. Haversine Great-Circle Geodesic Distance Matrix
 * 2. Greedy Nearest-Neighbor Initial Tour Construction (O(N^2))
 * 3. 2-Opt Local Search Heuristic (Untangles route crossings to achieve near-optimal TSP paths)
 * 4. Priority Weighting (COD cash priority + SLA elapsed delay urgency)
 */

export const STORE_ORIGIN_LAT = 26.1534185
export const STORE_ORIGIN_LNG = 80.1714024

/**
 * Calculates great-circle distance between two geographic coordinates on spherical Earth in kilometers.
 */
export function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371 // Earth radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * Calculates total route distance including store origin start.
 */
function calculateTotalTourDistance(route: any[]): number {
  if (route.length === 0) return 0
  let totalDist = 0
  let prevLat = STORE_ORIGIN_LAT
  let prevLng = STORE_ORIGIN_LNG

  for (let i = 0; i < route.length; i++) {
    const lat = route[i].address?.lat ?? STORE_ORIGIN_LAT
    const lng = route[i].address?.lng ?? STORE_ORIGIN_LNG
    totalDist += haversineDistance(prevLat, prevLng, lat, lng)
    prevLat = lat
    prevLng = lng
  }

  return totalDist
}

/**
 * Performs a 2-Opt swap by reversing the route segment from index i to index k.
 */
function twoOptSwap(route: any[], i: number, k: number): any[] {
  const newRoute = route.slice(0, i)
  const reversedSegment = route.slice(i, k + 1).reverse()
  const remaining = route.slice(k + 1)
  return [...newRoute, ...reversedSegment, ...remaining]
}

/**
 * 2-Opt Local Search Heuristic for TSP.
 * Eliminates intersecting delivery vectors and minimizes travel time.
 */
function applyTwoOptLocalSearch(route: any[], maxIterations: number = 50): any[] {
  if (route.length < 4) return route

  let bestRoute = [...route]
  let bestDistance = calculateTotalTourDistance(bestRoute)
  let improved = true
  let iterations = 0

  while (improved && iterations < maxIterations) {
    improved = false
    iterations++

    for (let i = 0; i < bestRoute.length - 1; i++) {
      for (let k = i + 1; k < bestRoute.length; k++) {
        const newRoute = twoOptSwap(bestRoute, i, k)
        const newDistance = calculateTotalTourDistance(newRoute)

        // If we found a shorter path, accept and restart neighborhood search
        if (newDistance < bestDistance - 0.001) {
          bestRoute = newRoute
          bestDistance = newDistance
          improved = true
          break
        }
      }
      if (improved) break
    }
  }

  return bestRoute
}

/**
 * Optimizes the stop sequence for riders:
 * 1. Initial tour generated via Nearest-Neighbor with SLA urgency heuristics.
 * 2. Refined via 2-Opt local search to eliminate crossing paths.
 */
export function optimizeRoute(ordersList: any[]): any[] {
  if (!ordersList || ordersList.length <= 1) return ordersList || []

  // Phase 1: Greedy Nearest-Neighbor with SLA & COD weighting
  const unvisited = [...ordersList]
  const initialTour: any[] = []
  let currentLat = STORE_ORIGIN_LAT
  let currentLng = STORE_ORIGIN_LNG

  while (unvisited.length > 0) {
    let bestIndex = 0
    let minDistance = Infinity

    for (let i = 0; i < unvisited.length; i++) {
      const addr = unvisited[i].address
      const addrLat = addr?.lat ?? STORE_ORIGIN_LAT
      const addrLng = addr?.lng ?? STORE_ORIGIN_LNG
      const dist = haversineDistance(currentLat, currentLng, addrLat, addrLng)

      let score = dist
      // Slight priority for COD cash orders to complete settlements earlier
      if (unvisited[i].paymentMethod === 'COD') score -= 0.3
      // SLA urgency weight (orders waiting longer get prioritized)
      const elapsedMins =
        (new Date().getTime() - new Date(unvisited[i].createdAt).getTime()) / (60 * 1000)
      score -= Math.min(elapsedMins * 0.04, 2.0)

      if (score < minDistance) {
        minDistance = score
        bestIndex = i
      }
    }

    const nextOrder = unvisited.splice(bestIndex, 1)[0]
    initialTour.push(nextOrder)
    currentLat = nextOrder.address?.lat ?? currentLat
    currentLng = nextOrder.address?.lng ?? currentLng
  }

  // Phase 2: 2-Opt Local Search optimization to remove cross-overs
  return applyTwoOptLocalSearch(initialTour)
}
