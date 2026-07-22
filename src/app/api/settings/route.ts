import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { getCachedSettings, setCachedSettings } from '@/lib/settings-cache'

export const dynamic = 'force-dynamic'

const DEFAULT_SETTINGS = {
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
  cafe_auto_timing: 'false',
  cafe_open_time: '06:00',
  cafe_close_time: '23:59',
  restaurant_auto_timing: 'false',
  restaurant_open_time: '06:00',
  restaurant_close_time: '23:59',
  delivery_radius: '2',
  store_lat: '26.1534185',
  store_lng: '80.1714024',
  avg_delivery_time: '8 min',
  delivered_today: '1,231+',
  fresh_stock_loaded: '2 hrs ago',
  only_cod: 'false',
  tax_rate: '5',
  misc_fee: '0',
  misc_fee_label: 'Miscellaneous Additions',
  grocery_free_delivery_threshold: '200',
  cafe_free_delivery_threshold: '200',
  combined_free_delivery_threshold: '200',
  delivery_fee: '25',
  contact_phone: '+91 70544 70303',
  contact_email: 'help@fastkirana.com',
  contact_timings: '6 AM - 12 AM',
  contact_address: 'NH34, Ghatampur, Kanpur Nagar',
  hero_greeting_closed: "We're resting right now 💤",
  hero_subtitle_closed: "FastKirana Cafe & Mart are resting. We will be back to serve you fresh & hot goodies soon!",
  hero_greeting_morning: "Good morning, let's get breakfast! 🌅",
  hero_subtitle_morning_mart_closed: "Grocery Mart is resting, but our Cafe is firing up fresh hot brews and breakfast specials! ☕✨",
  hero_subtitle_morning_cafe_closed: "Cafe is taking a break, but Grocery Mart is wide open and delivering fresh milk & fruits! 🥛📦",
  hero_subtitle_morning_both_open: "Fresh milk, fruits, hot brews, and breakfast essentials delivered in minutes.",
  hero_greeting_afternoon: "Good afternoon! Ready for lunch? 🍛",
  hero_subtitle_afternoon_mart_closed: "Grocery Mart is resting, but our Cafe is cooking delicious hot lunch dishes and rolls! 🥡✨",
  hero_subtitle_afternoon_cafe_closed: "Cafe is taking a break, but Grocery Mart is delivering lunch staples, dal, and rice! 🌾📦",
  hero_subtitle_afternoon_both_open: "Atta, rice, dal, fresh vegetables, and delicious hot rolls delivered fast.",
  hero_greeting_evening: "It's snack o'clock! Tea & snacks are ready ☕",
  hero_subtitle_evening_mart_closed: "Grocery Mart is taking a break, but our Cafe is steaming hot chai & fresh samosas! ☕🥟",
  hero_subtitle_evening_cafe_closed: "Cafe is resting, but Grocery Mart is delivering chips, biscuits, and munchies! 🍿📦",
  hero_subtitle_evening_both_open: "Samosas, munchies, chips, and chilled soft drinks ready for tea time.",
  hero_greeting_night: "Late night cravings? We got you! 🌙",
  hero_subtitle_night_mart_closed: "Grocery Mart is closed. Cafe is open to deliver hot night snacks & dessert cravings! 🍧✨",
  hero_subtitle_night_cafe_closed: "Cafe kitchen is resting, but Grocery Mart is active for ice cream, drinks & munchies! 🍦📦",
  hero_subtitle_night_both_open: "Indulge in ice creams, chocolates, late night munchies, and cafe specialties.",
  restaurant_commission: '10',
  restaurant_profit_share: '15',
  cafe_commission: '10',
  cafe_profit_share: '15',
  cafe_default_margin: '30',
  restaurant_default_margin: '30',
}

export function checkIsStoreOpen(settingsMap: Record<string, string>, prefix: 'grocery' | 'cafe' | 'restaurant'): boolean {
  const autoTiming = settingsMap[`${prefix}_auto_timing`] === 'true'
  if (!autoTiming) {
    if (prefix === 'grocery') return settingsMap['grocery_mart_open'] !== 'false'
    if (prefix === 'cafe') return settingsMap['cafe_open'] !== 'false'
    return settingsMap['restaurant_open'] !== 'false'
  }

  const openTime = settingsMap[`${prefix}_open_time`] || '06:00'
  const closeTime = settingsMap[`${prefix}_close_time`] || '23:59'

  // Get current Indian Standard Time (IST) (UTC + 5:30)
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false
  })
  const parts = formatter.formatToParts(new Date())
  const currentHours = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
  const currentMinutes = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10)
  const currentTotal = currentHours * 60 + currentMinutes

  const [openH, openM] = openTime.split(':').map(Number)
  const openTotal = openH * 60 + openM

  const [closeH, closeM] = closeTime.split(':').map(Number)
  const closeTotal = closeH * 60 + closeM

  if (closeTotal >= openTotal) {
    return currentTotal >= openTotal && currentTotal <= closeTotal
  } else {
    // Midnight crossing
    return currentTotal >= openTotal || currentTotal <= closeTotal
  }
}

export async function GET() {
  try {
    const cached = getCachedSettings()
    let settingsMap: Record<string, string>

    if (cached) {
      settingsMap = { ...cached }
    } else {
      const settings = await prisma.storeSetting.findMany()
      settingsMap = { ...DEFAULT_SETTINGS }

      settings.forEach((s) => {
        settingsMap[s.key] = s.value
      })

      setCachedSettings(settingsMap)
    }

    // Dynamically override based on live IST scheduler timings
    settingsMap['grocery_mart_open'] = checkIsStoreOpen(settingsMap, 'grocery') ? 'true' : 'false'
    settingsMap['cafe_open'] = checkIsStoreOpen(settingsMap, 'cafe') ? 'true' : 'false'
    settingsMap['restaurant_open'] = checkIsStoreOpen(settingsMap, 'restaurant') ? 'true' : 'false'

    return NextResponse.json(settingsMap, {
      headers: {
        'Cache-Control': 'public, max-age=5, stale-while-revalidate=30',
      }
    })
  } catch (error) {
    console.error('Settings API error:', error)
    
    const settingsMap = { ...DEFAULT_SETTINGS }
    settingsMap['grocery_mart_open'] = checkIsStoreOpen(settingsMap, 'grocery') ? 'true' : 'false'
    settingsMap['cafe_open'] = checkIsStoreOpen(settingsMap, 'cafe') ? 'true' : 'false'
    settingsMap['restaurant_open'] = checkIsStoreOpen(settingsMap, 'restaurant') ? 'true' : 'false'

    return NextResponse.json(settingsMap, {
      headers: {
        'Cache-Control': 'public, max-age=5, stale-while-revalidate=30',
      }
    })
  }
}
