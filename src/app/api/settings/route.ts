import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { getRedis, CACHE_KEYS, DEFAULT_TTL } from '@/lib/redis-client'
import { evaluateSurgeStatus } from '@/lib/surge-manager'

export const dynamic = 'force-dynamic'

const DEFAULT_SETTINGS: Record<string, string> = {
  deliveries_count: '10,000+',
  rating_value: '4.8',
  happy_families: '5,000+',
  trusted_text: '✨ Trusted by 5,000+ families in your town',
  grocery_mart_open: 'true',
  cafe_open: 'true',
  restaurant_open: 'true',
  grocery_auto_timing: 'false',
  grocery_open_time: '06:00',
  grocery_close_time: '23:59',
  cafe_auto_timing: 'true',
  cafe_open_time: '10:00',
  cafe_close_time: '22:00',
  restaurant_auto_timing: 'true',
  restaurant_open_time: '10:00',
  restaurant_close_time: '22:00',
  delivery_radius: '5.0',
  store_lat: '26.1534185',
  store_lng: '80.1714024',
  store_pincode: '209206',
  store_phone: process.env.NEXT_PUBLIC_SUPPORT_PHONE || '+91 8112849854',
  store_address: 'NH34, Ghatampur, Kanpur Nagar',
  shop_name: 'FastKirana Dark Store',
  min_order_value: '20',
  avg_delivery_time: 'Fast',
  delivered_today: '1,231+',
  fresh_stock_loaded: '2 hrs ago',
  admin_auto_approve_orders: 'false',
  only_cod: 'false',
  tax_rate: '5',
  misc_fee: '0',
  misc_fee_label: 'Miscellaneous Additions',
  grocery_free_delivery_threshold: '149',
  cafe_free_delivery_threshold: '149',
  combined_free_delivery_threshold: '149',
  delivery_fee: '25',
  delivery_fee_tier1: '25',
  delivery_threshold_tier1: '149',
  delivery_fee_tier2: '35',
  delivery_threshold_tier2: '249',
  delivery_fee_tier3: '50',
  delivery_threshold_tier3: '349',
  delivery_fee_per_km_beyond_5km: '10',
  surge_mode: 'MANUAL_OFF',
  surge_rain_amount: '20',
  surge_demand_amount: '15',
  surge_manual_amount: '20',
  surge_max_cap: '25',
  surge_demand_threshold: '3.0',
  contact_phone: process.env.NEXT_PUBLIC_SUPPORT_PHONE || '+91 8112849854',
  contact_email: 'help@fastkirana.com',
  contact_timings: '6 AM - 12 AM',
  contact_address: 'NH34, Ghatampur, Kanpur Nagar',
  hero_greeting_closed: "We're resting right now 💤",
  hero_subtitle_closed: "FastKirana Cafe & Mart are resting. We will be back to serve you fresh & hot goodies soon!",
  hero_greeting_morning: 'Good morning, let\'s get breakfast! 🌅',
  hero_subtitle_morning_mart_closed: 'Grocery Mart is resting, but our Cafe is firing up fresh hot brews and breakfast specials! ☕✨',
  hero_subtitle_morning_cafe_closed: 'Cafe is taking a break, but our Grocery Mart is wide open and delivering fresh milk & fruits! 🥛📦',
  hero_subtitle_morning_both_open: 'Fresh milk, fruits, hot brews, and breakfast essentials delivered in minutes.',
  hero_greeting_afternoon: 'Good afternoon! Ready for lunch? 🍛',
  hero_subtitle_afternoon_mart_closed: 'Grocery Mart is resting, but our Cafe is cooking delicious hot lunch dishes and rolls! 🥡✨',
  hero_subtitle_afternoon_cafe_closed: 'Cafe is taking a break, but our Grocery Mart is delivering lunch staples, dal, and rice! 🌾📦',
  hero_subtitle_afternoon_both_open: 'Atta, rice, dal, fresh vegetables, and delicious hot rolls delivered fast.',
  hero_greeting_evening: "It's snack o'clock! Tea & snacks are ready ☕",
  hero_subtitle_evening_mart_closed: 'Grocery Mart is taking a break, but our Cafe is steaming hot chai & fresh samosas! ☕🥟',
  hero_subtitle_evening_cafe_closed: 'Cafe is resting, but our Grocery Mart is delivering chips, biscuits, and munchies! 🍿📦',
  hero_subtitle_evening_both_open: 'Samosas, munchies, chips, and chilled soft drinks ready for tea time.',
  hero_greeting_night: 'Late night cravings? We got you! 🌙',
  hero_subtitle_night_mart_closed: 'Grocery Mart is closed. Cafe is open to deliver hot night snacks & dessert cravings! 🍧✨',
  hero_subtitle_night_cafe_closed: 'Cafe kitchen is resting, but our Grocery Mart is active for ice cream, drinks & munchies! 🍦📦',
  hero_subtitle_night_both_open: 'Indulge in ice creams, chocolates, late night munchies, and cafe specialties.',
  restaurant_commission: '10',
  restaurant_profit_share: '15',
  cafe_commission: '10',
  cafe_profit_share: '15',
  cafe_default_margin: '30',
  restaurant_default_margin: '30',
  min_app_version: '1.0.0',
  latest_app_version: '1.0.1',
  app_update_url: 'https://fastkirana.in/app-release.apk',
  app_update_message: 'FastKirana ka naya update available hai! Faster performance, bug fixes aur smooth ordering ke liye abhi update karein.',
  app_force_update: 'false',
  whatsapp_notify_store_phone: 'true',
  store_alert_phones: '',
}

export function checkIsStoreOpen(settingsMap: Record<string, string>, prefix: 'grocery' | 'cafe' | 'restaurant'): boolean {
  const autoTiming = settingsMap[`${prefix}_auto_timing`] === 'true'
  const isManuallyOpen = prefix === 'grocery'
    ? settingsMap['grocery_mart_open'] !== 'false'
    : prefix === 'cafe'
      ? settingsMap['cafe_open'] !== 'false'
      : settingsMap['restaurant_open'] !== 'false'

  // When auto timing is active, store automatically opens & closes strictly according to schedule
  if (autoTiming) {
    const openTime = settingsMap[`${prefix}_open_time`] || (prefix === 'grocery' ? '06:00' : '10:00')
    const closeTime = settingsMap[`${prefix}_close_time`] || (prefix === 'grocery' ? '23:59' : '22:00')

    if ((openTime === '00:00' || openTime === '0:00') && (closeTime === '23:59' || closeTime === '24:00')) return true

    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
      hourCycle: 'h23',
    })
    const parts = formatter.formatToParts(new Date())
    const currentHours = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
    const currentMinutes = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10)
    const currentTotal = currentHours * 60 + currentMinutes

    const [openH = 0, openM = 0] = openTime.split(':').map(Number)
    const openTotal = openH * 60 + openM

    const [closeH = 23, closeM = 59] = closeTime.split(':').map(Number)
    const closeTotal = closeH * 60 + closeM

    if (closeTotal >= openTotal) {
      return currentTotal >= openTotal && currentTotal <= closeTotal
    }
    return currentTotal >= openTotal || currentTotal <= closeTotal
  }

  // If auto timing is off, fall back to manual toggle
  return isManuallyOpen
}

export async function buildSettingsMap(storeId?: string | null): Promise<Record<string, string>> {
  const [settings, activeRestaurants] = await Promise.all([
    prisma.storeSetting.findMany({
      select: { key: true, value: true },
    }),
    prisma.restaurant.findMany({
      where: { isActive: true },
      select: { id: true, slug: true, name: true, isOpen: true, openTime: true, closeTime: true, updatedAt: true },
    }),
  ])

  const settingsMap = { ...DEFAULT_SETTINGS }
  // 1. Populate global base settings
  settings.forEach((s) => {
    if (!s.key.startsWith('store:')) {
      settingsMap[s.key] = s.value
    }
  })

  // 2. If a specific DarkStore hub is queried, layer store-scoped overrides & hub properties
  if (storeId && storeId !== 'all') {
    const storePrefix = `store:${storeId}:`
    settings.forEach((s) => {
      if (s.key.startsWith(storePrefix)) {
        const subKey = s.key.slice(storePrefix.length)
        settingsMap[subKey] = s.value
      }
    })

    try {
      const hub = await prisma.darkStore.findUnique({
        where: { id: storeId },
        select: {
          id: true,
          name: true,
          latitude: true,
          longitude: true,
          deliveryRadiusKm: true,
          groceryOpen: true,
          surgeCharge: true,
        }
      })
      if (hub) {
        settingsMap['store_id'] = hub.id
        settingsMap['store_name'] = hub.name
        settingsMap['store_lat'] = String(hub.latitude)
        if (hub.deliveryRadiusKm && (!settingsMap['delivery_radius'] || settingsMap['delivery_radius'] === '5.0')) {
          settingsMap['delivery_radius'] = String(hub.deliveryRadiusKm)
        } else if (!settingsMap['delivery_radius']) {
          settingsMap['delivery_radius'] = String(hub.deliveryRadiusKm || 5.0)
        }

        // City & Pincode inference for clean non-leaking store defaults
        const inferredCity = hub.name.replace(/\s+(Hub|Market|Central|Dark\s*Store|Branch).*$/i, '').trim()
        const inferredPincode = hub.id.match(/\b\d{6}\b/)?.[0] || ''

        const isAkbarpur = storeId === 'hub-224122' || inferredCity.toLowerCase().includes('akbarpur') || inferredPincode === '224122'
        const isGhatampur = storeId === 'hub-209206' || inferredCity.toLowerCase().includes('ghatampur') || inferredPincode === '209206'

        if (isAkbarpur) {
          if (!settingsMap['store_pincode'] || settingsMap['store_pincode'] === '209206') {
            settingsMap['store_pincode'] = '224122'
          }
          if (!settingsMap['store_address'] || settingsMap['store_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['store_address'] = 'Akbarpur, Ambedkar Nagar, Uttar Pradesh 224122'
          }
          if (!settingsMap['contact_address'] || settingsMap['contact_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['contact_address'] = 'Akbarpur, Ambedkar Nagar, Uttar Pradesh 224122'
          }
          if (!settingsMap['grocery_pickup_address'] || settingsMap['grocery_pickup_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['grocery_pickup_address'] = 'FastKirana Dark Store, Akbarpur, Ambedkar Nagar 224122'
          }
          if (!settingsMap['trusted_text'] || settingsMap['trusted_text'].toLowerCase().includes('ghatampur')) {
            settingsMap['trusted_text'] = '✨ Trusted by families in Akbarpur'
          }
        } else if (!isGhatampur && inferredCity) {
          // New store defaults - never leak Ghatampur
          if (inferredPincode && (!settingsMap['store_pincode'] || settingsMap['store_pincode'] === '209206')) {
            settingsMap['store_pincode'] = inferredPincode
          }
          if (!settingsMap['store_address'] || settingsMap['store_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['store_address'] = `${inferredCity}${inferredPincode ? `, ${inferredPincode}` : ''}`
          }
          if (!settingsMap['contact_address'] || settingsMap['contact_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['contact_address'] = `${inferredCity}${inferredPincode ? `, ${inferredPincode}` : ''}`
          }
          if (!settingsMap['grocery_pickup_address'] || settingsMap['grocery_pickup_address'].toLowerCase().includes('ghatampur')) {
            settingsMap['grocery_pickup_address'] = `FastKirana Dark Store, ${inferredCity}`
          }
          if (!settingsMap['trusted_text'] || settingsMap['trusted_text'].toLowerCase().includes('ghatampur')) {
            settingsMap['trusted_text'] = `✨ Trusted by families in ${inferredCity}`
          }
        }
      }
    } catch (hubErr) {
      console.warn('Failed to load specific hub in settings:', hubErr)
    }
  }

  for (const r of activeRestaurants) {
    const opStatus = checkStoreOperatingStatus(r)
    settingsMap[`outlet_open_${r.id}`] = opStatus.isOpen ? 'true' : 'false'
    if (r.slug) settingsMap[`outlet_open_${r.slug}`] = opStatus.isOpen ? 'true' : 'false'
  }

  const wedson = activeRestaurants.find(r => r.slug?.includes('wedson') || r.name?.toLowerCase().includes('wedson'))
  if (wedson) {
    const opStatus = checkStoreOperatingStatus(wedson)
    settingsMap['restaurant_open'] = opStatus.isOpen ? 'true' : 'false'
    if (wedson.openTime) settingsMap['restaurant_open_time'] = wedson.openTime
    if (wedson.closeTime) settingsMap['restaurant_close_time'] = wedson.closeTime
  } else {
    settingsMap['restaurant_open'] = checkIsStoreOpen(settingsMap, 'restaurant') ? 'true' : 'false'
  }

  const cafe = activeRestaurants.find(r => r.slug?.includes('as-restaurant') || r.slug?.includes('cafe') || r.name?.toLowerCase().includes('a.s.'))
  if (cafe) {
    const opStatus = checkStoreOperatingStatus(cafe)
    settingsMap['cafe_open'] = opStatus.isOpen ? 'true' : 'false'
    if (cafe.openTime) settingsMap['cafe_open_time'] = cafe.openTime
    if (cafe.closeTime) settingsMap['cafe_close_time'] = cafe.closeTime
  } else {
    settingsMap['cafe_open'] = checkIsStoreOpen(settingsMap, 'cafe') ? 'true' : 'false'
  }

  // Grocery store status calculation:
  // If auto timing is enabled, both general and hub-level follow the automated schedule.
  // If auto timing is disabled, specific hub follows hub.groceryOpen (if queried) or general grocery_mart_open.
  const autoTiming = settingsMap['grocery_auto_timing'] === 'true'
  if (autoTiming) {
    settingsMap['grocery_mart_open'] = checkIsStoreOpen(settingsMap, 'grocery') ? 'true' : 'false'
  } else if (!storeId || storeId === 'all') {
    settingsMap['grocery_mart_open'] = checkIsStoreOpen(settingsMap, 'grocery') ? 'true' : 'false'
  }

  try {
    const surge = await evaluateSurgeStatus(settingsMap, storeId)
    settingsMap['surge_active'] = surge.isSurgeActive ? 'true' : 'false'
    settingsMap['surge_fee'] = String(surge.surgeFee)
    settingsMap['surge_charge'] = String(surge.surgeFee)
    settingsMap['surge_reason'] = surge.surgeReason
    settingsMap['surge_type'] = surge.surgeType
    settingsMap['surge_mode'] = surge.mode
    if (surge.weatherInfo) {
      settingsMap['current_weather_temp'] = String(surge.weatherInfo.temperature)
      settingsMap['current_weather_condition'] = surge.weatherInfo.condition
      settingsMap['current_weather_is_raining'] = surge.weatherInfo.isRaining ? 'true' : 'false'
    }
    if (surge.demandInfo) {
      settingsMap['current_active_orders'] = String(surge.demandInfo.activeOrders)
      settingsMap['current_active_riders'] = String(surge.demandInfo.activeRiders)
      settingsMap['current_demand_ratio'] = String(surge.demandInfo.ratio)
    }
  } catch (surgeErr) {
    console.error('Surge evaluation error in settings:', surgeErr)
  }

  return settingsMap
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const storeId = searchParams.get('storeId') || searchParams.get('hubId')
    const cacheKey = storeId && storeId !== 'all' ? `${CACHE_KEYS.SETTINGS}:${storeId}` : CACHE_KEYS.SETTINGS

    const redis = getRedis()
    const cached = await redis.get<Record<string, string>>(cacheKey)

    if (cached) {
      const liveGrocery = checkIsStoreOpen(cached, 'grocery')
      cached['grocery_mart_open'] = liveGrocery ? 'true' : 'false'
      const liveCafe = checkIsStoreOpen(cached, 'cafe')
      cached['cafe_open'] = liveCafe ? 'true' : 'false'
      const liveRestaurant = checkIsStoreOpen(cached, 'restaurant')
      cached['restaurant_open'] = liveRestaurant ? 'true' : 'false'
      return NextResponse.json(cached, {
        headers: {
          'Cache-Control': 'public, s-maxage=5, stale-while-revalidate=15',
        },
      })
    }

    const settingsMap = await buildSettingsMap(storeId)
    await redis.set(cacheKey, settingsMap, { ex: DEFAULT_TTL.SETTINGS })

    return NextResponse.json(settingsMap, {
      headers: {
        'Cache-Control': 'public, s-maxage=5, stale-while-revalidate=15',
      },
    })
  } catch (error) {
    console.error('Settings API error:', error)
    const settingsMap = { ...DEFAULT_SETTINGS }
    settingsMap['grocery_mart_open'] = checkIsStoreOpen(settingsMap, 'grocery') ? 'true' : 'false'
    settingsMap['cafe_open'] = checkIsStoreOpen(settingsMap, 'cafe') ? 'true' : 'false'
    settingsMap['restaurant_open'] = checkIsStoreOpen(settingsMap, 'restaurant') ? 'true' : 'false'

    return NextResponse.json(settingsMap, {
      headers: {
        'Cache-Control': 'public, s-maxage=5, stale-while-revalidate=15',
      },
    })
  }
}
