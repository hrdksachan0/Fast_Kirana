import { prisma } from './prisma'

export interface SurgeStatus {
  isSurgeActive: boolean
  surgeFee: number
  surgeReason: string
  surgeType: 'NONE' | 'RAIN' | 'DEMAND' | 'MANUAL'
  mode: 'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF'
  weatherInfo?: {
    temperature: number
    condition: string
    isRaining: boolean
  } | null
  demandInfo?: {
    activeOrders: number
    activeRiders: number
    ratio: number
  } | null
}

// In-memory cache for weather per coordinate area to avoid rapid external fetches
const weatherCacheMap = new Map<string, {
  temperature: number
  condition: string
  isRaining: boolean
  timestamp: number
}>()

const WEATHER_CACHE_MS = 5 * 60 * 1000 // 5 minutes

export async function fetchLiveWeather(
  lat: number = 26.1534,
  lng: number = 80.1714
): Promise<{
  temperature: number
  condition: string
  isRaining: boolean
}> {
  const now = Date.now()
  const key = `${lat.toFixed(2)},${lng.toFixed(2)}`
  const cached = weatherCacheMap.get(key)
  if (cached && now - cached.timestamp < WEATHER_CACHE_MS) {
    return cached
  }

  try {
    const res = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,rain,showers,weather_code`,
      { next: { revalidate: 300 } }
    )
    if (!res.ok) throw new Error('Weather fetch failed')
    const data = await res.json()
    const current = data?.current || {}
    const code = Number(current.weather_code ?? 0)
    const rain = Number(current.rain ?? 0)
    const showers = Number(current.showers ?? 0)
    const temp = Number(current.temperature_2m ?? 30)

    // Only genuine heavy rain (> 1.5mm) or moderate/heavy rain/thunderstorm codes trigger safety rain surge
    // Drizzle (51, 53, 55) or trace moisture (< 1.5mm) will NOT trigger surge charge
    const heavyRainCodes = [63, 65, 81, 82, 95, 96, 99]
    const isRaining = (rain >= 1.5 || showers >= 1.5) || (rain >= 0.5 && heavyRainCodes.includes(code))

    let condition = 'Clear'
    if (isRaining) {
      condition = [95, 96, 99].includes(code) ? 'Thunderstorm' : 'Rain'
    } else if ([1, 2, 3].includes(code)) {
      condition = 'Cloudy'
    }

    const result = {
      temperature: temp,
      condition,
      isRaining,
      timestamp: now,
    }
    weatherCacheMap.set(key, result)
    return result
  } catch (e) {
    return cached || { temperature: 30, condition: 'Clear', isRaining: false }
  }
}

export async function getLiveDemandInfo(storeId?: string | null): Promise<{
  activeOrders: number
  activeRiders: number
  ratio: number
}> {
  try {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000)
    
    const orderWhere: any = {
      status: { in: ['PENDING', 'CONFIRMED', 'PACKED'] },
      createdAt: { gte: thirtyMinutesAgo },
    }
    if (storeId && storeId !== 'all') {
      orderWhere.storeId = storeId
    }

    const riderWhere: any = {
      role: 'DELIVERY',
    }
    if (storeId && storeId !== 'all') {
      riderWhere.OR = [
        { assignedStoreId: storeId },
        { assignedStoreId: null },
      ]
    }

    const [activeOrdersCount, activeRidersCount] = await Promise.all([
      prisma.order.count({ where: orderWhere }),
      prisma.user.count({ where: riderWhere }),
    ])

    const safeRiders = Math.max(1, activeRidersCount)
    return {
      activeOrders: activeOrdersCount,
      activeRiders: activeRidersCount,
      ratio: parseFloat((activeOrdersCount / safeRiders).toFixed(1)),
    }
  } catch (e) {
    return { activeOrders: 0, activeRiders: 1, ratio: 0 }
  }
}

export async function evaluateSurgeStatus(
  settingsMap: Record<string, string>,
  storeId?: string | null,
  customCoords?: { lat: number; lng: number } | null
): Promise<SurgeStatus> {
  const mode = (settingsMap['surge_mode'] || 'MANUAL_OFF').toUpperCase() as 'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF'
  const rainAmount = parseFloat(settingsMap['surge_rain_amount'] || '20')
  const demandAmount = parseFloat(settingsMap['surge_demand_amount'] || '15')
  const manualAmount = parseFloat(settingsMap['surge_manual_amount'] || '20')
  const maxCap = parseFloat(settingsMap['surge_max_cap'] || '25')
  const demandThreshold = parseFloat(settingsMap['surge_demand_threshold'] || '3.0')

  // Case 1: Manual OFF
  if (mode === 'MANUAL_OFF') {
    return {
      isSurgeActive: false,
      surgeFee: 0,
      surgeReason: '',
      surgeType: 'NONE',
      mode,
    }
  }

  // Case 2: Manual ON
  if (mode === 'MANUAL_ON') {
    const fee = Math.min(manualAmount, maxCap)
    return {
      isSurgeActive: true,
      surgeFee: fee,
      surgeReason: settingsMap['surge_manual_reason'] || '⚡ Special Delivery Surge',
      surgeType: 'MANUAL',
      mode,
    }
  }

  // Resolve DarkStore hub coordinates if storeId provided
  let hubLat = customCoords?.lat ?? 26.1534
  let hubLng = customCoords?.lng ?? 80.1714

  if (storeId && storeId !== 'all') {
    try {
      const hub = await prisma.darkStore.findUnique({
        where: { id: storeId },
        select: { latitude: true, longitude: true, surgeCharge: true }
      })
      if (hub) {
        hubLat = hub.latitude
        hubLng = hub.longitude
        // If a hub has an explicit manual surgeCharge set on its database record, honor it (capped)
        if (hub.surgeCharge && hub.surgeCharge > 0) {
          const fee = Math.min(hub.surgeCharge, maxCap)
          return {
            isSurgeActive: true,
            surgeFee: fee,
            surgeReason: '⚡ Hub Specific Delivery Surge',
            surgeType: 'MANUAL',
            mode,
          }
        }
      }
    } catch (err) {
      console.warn('Could not fetch darkStore coordinates for surge:', err)
    }
  }

  // Case 3: AUTO Mode (Hub-specific weather & fleet demand)
  const [weather, demand] = await Promise.all([
    fetchLiveWeather(hubLat, hubLng),
    getLiveDemandInfo(storeId),
  ])

  // 1. Rain check takes priority
  if (weather.isRaining) {
    const fee = Math.min(rainAmount, maxCap)
    return {
      isSurgeActive: true,
      surgeFee: fee,
      surgeReason: '🌧️ Rain Surge (Delivery Partner Safety)',
      surgeType: 'RAIN',
      mode,
      weatherInfo: weather,
      demandInfo: demand,
    }
  }

  // 2. High Demand check (min 4 pending orders and ratio >= threshold)
  if (demand.activeOrders >= 4 && demand.ratio >= demandThreshold) {
    const fee = Math.min(demandAmount, maxCap)
    return {
      isSurgeActive: true,
      surgeFee: fee,
      surgeReason: '⚡ High Demand Surge',
      surgeType: 'DEMAND',
      mode,
      weatherInfo: weather,
      demandInfo: demand,
    }
  }

  return {
    isSurgeActive: false,
    surgeFee: 0,
    surgeReason: '',
    surgeType: 'NONE',
    mode,
    weatherInfo: weather,
    demandInfo: demand,
  }
}
