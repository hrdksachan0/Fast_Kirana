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
  delivery_radius: '5',
  store_lat: '26.1534185',
  store_lng: '80.1714024',
  avg_delivery_time: '8 min',
  delivered_today: '1,231+',
  fresh_stock_loaded: '2 hrs ago',
  only_cod: 'false',
  tax_rate: '5',
  misc_fee: '0',
  misc_fee_label: 'Miscellaneous Additions',
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
}

export async function GET() {
  try {
    const cached = getCachedSettings()
    if (cached) {
      return NextResponse.json(cached, {
        headers: {
          'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        }
      })
    }

    const settings = await prisma.storeSetting.findMany()
    const settingsMap: Record<string, string> = { ...DEFAULT_SETTINGS }

    settings.forEach((s) => {
      settingsMap[s.key] = s.value
    })

    setCachedSettings(settingsMap)

    return NextResponse.json(settingsMap, {
      headers: {
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }
    })
  } catch (error) {
    console.error('Settings API error:', error)
    return NextResponse.json(DEFAULT_SETTINGS, {
      headers: {
        'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      }
    })
  }
}
