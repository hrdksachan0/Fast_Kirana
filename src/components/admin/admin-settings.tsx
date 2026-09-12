'use client'

import { useState, useEffect, useMemo } from 'react'
import { toast } from 'sonner'
import { Sliders, Save, Loader2, Eye, Heart, Star, Package, FileText, MessageSquare, Smartphone, Download, AlertCircle, RefreshCw, CloudRain, Zap, ShieldCheck } from 'lucide-react'
import { motion } from 'framer-motion'
import { STORE_PINCODE, STORE_ADDRESS, STORE_PHONE, GROCERY_PICKUP_ADDRESS, CAFE_PICKUP_ADDRESS, RESTAURANT_PICKUP_ADDRESS, SERVICE_AREA_NAME } from '@/lib/store-config'

interface AdminSettingsProps {
  onSettingsSaved?: () => void
}

export function AdminSettings({ onSettingsSaved }: AdminSettingsProps) {
  const [settingsTab, setSettingsTab] = useState<'ops' | 'cosmetics' | 'finance' | 'greetings' | 'app' | 'surge'>('ops')
  const [surgeMode, setSurgeMode] = useState<'AUTO' | 'MANUAL_ON' | 'MANUAL_OFF'>('AUTO')
  const [surgeRainAmount, setSurgeRainAmount] = useState('20')
  const [surgeDemandAmount, setSurgeDemandAmount] = useState('15')
  const [surgeManualAmount, setSurgeManualAmount] = useState('20')
  const [surgeMaxCap, setSurgeMaxCap] = useState('25')
  const [surgeDemandThreshold, setSurgeDemandThreshold] = useState('3.0')
  const [surgeActive, setSurgeActive] = useState(false)
  const [surgeFee, setSurgeFee] = useState('0')
  const [surgeReason, setSurgeReason] = useState('')
  const [currentWeatherTemp, setCurrentWeatherTemp] = useState('30')
  const [currentWeatherCondition, setCurrentWeatherCondition] = useState('Clear')
  const [currentActiveOrders, setCurrentActiveOrders] = useState('0')
  const [currentActiveRiders, setCurrentActiveRiders] = useState('0')
  const [greetingsSubTab, setGreetingsSubTab] = useState<'closed' | 'morning' | 'afternoon' | 'evening' | 'night'>('morning')
  const [minAppVersion, setMinAppVersion] = useState('1.0.0')
  const [latestAppVersion, setLatestAppVersion] = useState('1.0.1')
  const [appUpdateUrl, setAppUpdateUrl] = useState('https://fastkirana.in/app-release.apk')
  const [appUpdateMessage, setAppUpdateMessage] = useState('FastKirana ka naya update available hai! Faster performance, bug fixes aur smooth ordering ke liye abhi update karein.')
  const [appForceUpdate, setAppForceUpdate] = useState(false)
  const [deliveriesCount, setDeliveriesCount] = useState('10,000+')
  const [ratingValue, setRatingValue] = useState('4.8')
  const [happyFamilies, setHappyFamilies] = useState('5,000+')
  const [trustedText, setTrustedText] = useState('✨ Trusted by 5,000+ families in your town')
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [groceryAutoTiming, setGroceryAutoTiming] = useState(false)
  const [groceryOpenTime, setGroceryOpenTime] = useState('06:00')
  const [groceryCloseTime, setGroceryCloseTime] = useState('23:59')

  const isGroceryCurrentlyOpen = useMemo(() => {
    if (!groceryAutoTiming) return groceryMartOpen
    const openTime = groceryOpenTime || '07:00'
    const closeTime = groceryCloseTime || '22:00'
    if ((openTime === '00:00' || openTime === '0:00') && (closeTime === '23:59' || closeTime === '24:00')) return true

    const formatter = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Asia/Kolkata',
      hour: 'numeric',
      minute: 'numeric',
      hour12: false,
      hourCycle: 'h23',
    })
    const parts = formatter.formatToParts(new Date())
    const curH = parseInt(parts.find(p => p.type === 'hour')?.value || '0', 10)
    const curM = parseInt(parts.find(p => p.type === 'minute')?.value || '0', 10)
    const curTotal = curH * 60 + curM

    const [oH = 0, oM = 0] = openTime.split(':').map(Number)
    const [cH = 23, cM = 59] = closeTime.split(':').map(Number)
    const oTotal = oH * 60 + oM
    const cTotal = cH * 60 + cM

    if (cTotal >= oTotal) return curTotal >= oTotal && curTotal <= cTotal
    return curTotal >= oTotal || curTotal <= cTotal
  }, [groceryAutoTiming, groceryMartOpen, groceryOpenTime, groceryCloseTime])
  const [onlyCod, setOnlyCod] = useState(false)
  const [deliveryRadius, setDeliveryRadius] = useState('5')
  const [restaurantEmails, setRestaurantEmails] = useState('')
  const [storeUpiVpa, setStoreUpiVpa] = useState('7054470303@paytm')
  const [storeLat, setStoreLat] = useState('26.1534185')
  const [storeLng, setStoreLng] = useState('80.1714024')
  const [avgDeliveryTime, setAvgDeliveryTime] = useState('Fast')
  const [deliveredToday, setDeliveredToday] = useState('1,231+')
  const [freshStockLoaded, setFreshStockLoaded] = useState('2 hrs ago')
  const [taxRate, setTaxRate] = useState('5')
  const [miscFee, setMiscFee] = useState('0')
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')
  const [contactPhone, setContactPhone] = useState(STORE_PHONE)
  const [contactEmail, setContactEmail] = useState('help@fastkirana.com')
  const [contactTimings, setContactTimings] = useState('6 AM - 12 AM')
  const [contactAddress, setContactAddress] = useState(STORE_ADDRESS)
  const [groceryPickupAddress, setGroceryPickupAddress] = useState(GROCERY_PICKUP_ADDRESS)
  const [cafePickupAddress, setCafePickupAddress] = useState(CAFE_PICKUP_ADDRESS)
  const [restaurantPickupAddress, setRestaurantPickupAddress] = useState(RESTAURANT_PICKUP_ADDRESS)
  const [notifyPhone1, setNotifyPhone1] = useState(true)
  const [notifyPhone2, setNotifyPhone2] = useState(true)
  const [groceryFreeDeliveryThreshold, setGroceryFreeDeliveryThreshold] = useState('199')
  const [cafeFreeDeliveryThreshold, setCafeFreeDeliveryThreshold] = useState('199')
  const [combinedFreeDeliveryThreshold, setCombinedFreeDeliveryThreshold] = useState('200')
  const [deliveryFee, setDeliveryFee] = useState('25')
  const [restaurantCommission, setRestaurantCommission] = useState('10')
  const [restaurantProfitShare, setRestaurantProfitShare] = useState('15')
  const [restaurantDefaultMargin, setRestaurantDefaultMargin] = useState('30')
  const [cafeCommission, setCafeCommission] = useState('10')
  const [cafeProfitShare, setCafeProfitShare] = useState('15')
  const [cafeDefaultMargin, setCafeDefaultMargin] = useState('30')
  const [minOrderValue, setMinOrderValue] = useState('0')

  const [heroGreetingClosed, setHeroGreetingClosed] = useState("We're resting right now 💤")
  const [heroSubtitleClosed, setHeroSubtitleClosed] = useState("FastKirana Cafe & Mart are resting. We will be back to serve you fresh & hot goodies soon!")
  
  const [heroGreetingMorning, setHeroGreetingMorning] = useState("Good morning, let's get breakfast! 🌅")
  const [heroSubtitleMorningMartClosed, setHeroSubtitleMorningMartClosed] = useState("Grocery Mart is resting, but our Cafe is firing up fresh hot brews and breakfast specials! ☕✨")
  const [heroSubtitleMorningCafeClosed, setHeroSubtitleMorningCafeClosed] = useState("Cafe is taking a break, but Grocery Mart is wide open and delivering fresh milk & fruits! 🥛📦")
  const [heroSubtitleMorningBothOpen, setHeroSubtitleMorningBothOpen] = useState("Fresh milk, fruits, hot brews, and breakfast essentials delivered in minutes.")
  
  const [heroGreetingAfternoon, setHeroGreetingAfternoon] = useState("Good afternoon! Ready for lunch? 🍛")
  const [heroSubtitleAfternoonMartClosed, setHeroSubtitleAfternoonMartClosed] = useState("Grocery Mart is resting, but our Cafe is cooking delicious hot lunch dishes and rolls! 🥡✨")
  const [heroSubtitleAfternoonCafeClosed, setHeroSubtitleAfternoonCafeClosed] = useState("Cafe is taking a break, but Grocery Mart is delivering lunch staples, dal, and rice! 🌾📦")
  const [heroSubtitleAfternoonBothOpen, setHeroSubtitleAfternoonBothOpen] = useState("Atta, rice, dal, fresh vegetables, and delicious hot rolls delivered fast.")
  
  const [heroGreetingEvening, setHeroGreetingEvening] = useState("It's snack o'clock! Tea & snacks are ready ☕")
  const [heroSubtitleEveningMartClosed, setHeroSubtitleEveningMartClosed] = useState("Grocery Mart is taking a break, but our Cafe is steaming hot chai & fresh samosas! ☕🥟")
  const [heroSubtitleEveningCafeClosed, setHeroSubtitleEveningCafeClosed] = useState("Cafe is resting, but Grocery Mart is delivering chips, biscuits, and munchies! 🍿📦")
  const [heroSubtitleEveningBothOpen, setHeroSubtitleEveningBothOpen] = useState("Samosas, munchies, chips, and chilled soft drinks ready for tea time.")
  
  const [heroGreetingNight, setHeroGreetingNight] = useState("Late night cravings? We got you! 🌙")
  const [heroSubtitleNightMartClosed, setHeroSubtitleNightMartClosed] = useState("Grocery Mart is closed. Cafe is open to deliver hot night snacks & dessert cravings! 🍧✨")
  const [heroSubtitleNightCafeClosed, setHeroSubtitleNightCafeClosed] = useState("Cafe kitchen is resting, but Grocery Mart is active for ice cream, drinks & munchies! 🍦📦")
  const [heroSubtitleNightBothOpen, setHeroSubtitleNightBothOpen] = useState("Indulge in ice creams, chocolates, late night munchies, and cafe specialties.")
  
  const [categories, setCategories] = useState<any[]>([])
  const [categoryStatuses, setCategoryStatuses] = useState<Record<string, boolean>>({})
  
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  // Fetch settings on mount
  useEffect(() => {
    async function loadSettings() {
      try {
        setLoading(true)
        
        // Fetch categories first
        const catRes = await fetch('/api/categories')
        if (!catRes.ok) throw new Error('Failed to load categories')
        const cats = await catRes.json()
        setCategories(cats)

        const res = await fetch('/api/settings', { cache: 'no-store' })
        if (!res.ok) throw new Error('Failed to load settings')
        const data = await res.json()
        
        if (data.deliveries_count) setDeliveriesCount(data.deliveries_count)
        if (data.rating_value) setRatingValue(data.rating_value)
        if (data.happy_families) setHappyFamilies(data.happy_families)
        if (data.trusted_text) setTrustedText(data.trusted_text)
        if (data.grocery_mart_open !== undefined) setGroceryMartOpen(data.grocery_mart_open === 'true')
        if (data.grocery_auto_timing !== undefined) setGroceryAutoTiming(data.grocery_auto_timing === 'true')
        if (data.grocery_open_time) setGroceryOpenTime(data.grocery_open_time)
        if (data.grocery_close_time) setGroceryCloseTime(data.grocery_close_time)
        if (data.only_cod !== undefined) setOnlyCod(data.only_cod === 'true')
        if (data.delivery_radius !== undefined) setDeliveryRadius(data.delivery_radius)
        if (data.store_upi_vpa) setStoreUpiVpa(data.store_upi_vpa)
        if (data.store_lat) setStoreLat(data.store_lat)
        if (data.store_lng) setStoreLng(data.store_lng)
        if (data.avg_delivery_time) setAvgDeliveryTime(data.avg_delivery_time)
        if (data.delivered_today) setDeliveredToday(data.delivered_today)
        if (data.fresh_stock_loaded) setFreshStockLoaded(data.fresh_stock_loaded)
        if (data.tax_rate !== undefined) setTaxRate(data.tax_rate)
        if (data.misc_fee !== undefined) setMiscFee(data.misc_fee)
        if (data.misc_fee_label !== undefined) setMiscFeeLabel(data.misc_fee_label)
        if (data.contact_phone) setContactPhone(data.contact_phone)
        if (data.contact_email) setContactEmail(data.contact_email)
        if (data.contact_timings) setContactTimings(data.contact_timings)
        if (data.contact_address) setContactAddress(data.contact_address)
        if (data.grocery_pickup_address) setGroceryPickupAddress(data.grocery_pickup_address)
        if (data.cafe_pickup_address) setCafePickupAddress(data.cafe_pickup_address)
        if (data.restaurant_pickup_address) setRestaurantPickupAddress(data.restaurant_pickup_address)
        if (data.whatsapp_notify_7054470303 !== undefined) setNotifyPhone1(data.whatsapp_notify_7054470303 !== 'false')
        if (data.whatsapp_notify_8112849854 !== undefined) setNotifyPhone2(data.whatsapp_notify_8112849854 !== 'false')
        if (data.grocery_free_delivery_threshold) setGroceryFreeDeliveryThreshold(data.grocery_free_delivery_threshold)
        if (data.cafe_free_delivery_threshold) setCafeFreeDeliveryThreshold(data.cafe_free_delivery_threshold)
        if (data.combined_free_delivery_threshold) setCombinedFreeDeliveryThreshold(data.combined_free_delivery_threshold)
        if (data.delivery_fee) setDeliveryFee(data.delivery_fee)
        if (data.restaurant_commission) setRestaurantCommission(data.restaurant_commission)
        if (data.restaurant_profit_share) setRestaurantProfitShare(data.restaurant_profit_share)
        if (data.restaurant_default_margin) setRestaurantDefaultMargin(data.restaurant_default_margin)
        if (data.cafe_commission) setCafeCommission(data.cafe_commission)
        if (data.cafe_profit_share) setCafeProfitShare(data.cafe_profit_share)
        if (data.cafe_default_margin) setCafeDefaultMargin(data.cafe_default_margin)
        if (data.min_order_value !== undefined) setMinOrderValue(data.min_order_value)

        if (data.hero_greeting_closed) setHeroGreetingClosed(data.hero_greeting_closed)
        if (data.hero_subtitle_closed) setHeroSubtitleClosed(data.hero_subtitle_closed)
        if (data.hero_greeting_morning) setHeroGreetingMorning(data.hero_greeting_morning)
        if (data.hero_subtitle_morning_mart_closed) setHeroSubtitleMorningMartClosed(data.hero_subtitle_morning_mart_closed)
        if (data.hero_subtitle_morning_cafe_closed) setHeroSubtitleMorningCafeClosed(data.hero_subtitle_morning_cafe_closed)
        if (data.hero_subtitle_morning_both_open) setHeroSubtitleMorningBothOpen(data.hero_subtitle_morning_both_open)
        if (data.hero_greeting_afternoon) setHeroGreetingAfternoon(data.hero_greeting_afternoon)
        if (data.hero_subtitle_afternoon_mart_closed) setHeroSubtitleAfternoonMartClosed(data.hero_subtitle_afternoon_mart_closed)
        if (data.hero_subtitle_afternoon_cafe_closed) setHeroSubtitleAfternoonCafeClosed(data.hero_subtitle_afternoon_cafe_closed)
        if (data.hero_subtitle_afternoon_both_open) setHeroSubtitleAfternoonBothOpen(data.hero_subtitle_afternoon_both_open)
        if (data.hero_greeting_evening) setHeroGreetingEvening(data.hero_greeting_evening)
        if (data.hero_subtitle_evening_mart_closed) setHeroSubtitleEveningMartClosed(data.hero_subtitle_evening_mart_closed)
        if (data.hero_subtitle_evening_cafe_closed) setHeroSubtitleEveningCafeClosed(data.hero_subtitle_evening_cafe_closed)
        if (data.hero_subtitle_evening_both_open) setHeroSubtitleEveningBothOpen(data.hero_subtitle_evening_both_open)
        if (data.hero_greeting_night) setHeroGreetingNight(data.hero_greeting_night)
        if (data.hero_subtitle_night_mart_closed) setHeroSubtitleNightMartClosed(data.hero_subtitle_night_mart_closed)
        if (data.hero_subtitle_night_cafe_closed) setHeroSubtitleNightCafeClosed(data.hero_subtitle_night_cafe_closed)
        if (data.hero_subtitle_night_both_open) setHeroSubtitleNightBothOpen(data.hero_subtitle_night_both_open)
        if (data.min_app_version) setMinAppVersion(data.min_app_version)
        if (data.latest_app_version) setLatestAppVersion(data.latest_app_version)
        if (data.app_update_url) setAppUpdateUrl(data.app_update_url)
        if (data.app_update_message) setAppUpdateMessage(data.app_update_message)
        if (data.app_force_update !== undefined) setAppForceUpdate(data.app_force_update === 'true')
        if (data.surge_mode) setSurgeMode(data.surge_mode as any)
        if (data.surge_rain_amount) setSurgeRainAmount(data.surge_rain_amount)
        if (data.surge_demand_amount) setSurgeDemandAmount(data.surge_demand_amount)
        if (data.surge_manual_amount) setSurgeManualAmount(data.surge_manual_amount)
        if (data.surge_max_cap) setSurgeMaxCap(data.surge_max_cap)
        if (data.surge_demand_threshold) setSurgeDemandThreshold(data.surge_demand_threshold)
        if (data.surge_active !== undefined) setSurgeActive(data.surge_active === 'true')
        if (data.surge_fee) setSurgeFee(data.surge_fee)
        if (data.surge_reason) setSurgeReason(data.surge_reason)
        if (data.current_weather_temp) setCurrentWeatherTemp(data.current_weather_temp)
        if (data.current_weather_condition) setCurrentWeatherCondition(data.current_weather_condition)
        if (data.current_active_orders) setCurrentActiveOrders(data.current_active_orders)
        if (data.current_active_riders) setCurrentActiveRiders(data.current_active_riders)

        // Parse category statuses
        const catStatusMap: Record<string, boolean> = {}
        if (Array.isArray(cats)) {
          setCategories(cats)
          cats.forEach((cat: any) => {
            catStatusMap[cat.slug] = data[`category_open_${cat.slug}`] !== 'false'
          })
        }
        setCategoryStatuses(catStatusMap)
      } catch (err: any) {
        console.error(err)
        toast.error('Could not fetch store settings')
      } finally {
        setLoading(false)
      }
    }

    loadSettings()
  }, [])

  // Save settings handler
  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    
    if (!deliveriesCount.trim() || !ratingValue.trim() || !happyFamilies.trim() || !trustedText.trim() || !deliveryRadius.trim() || !storeUpiVpa.trim() || !taxRate.trim() || !minOrderValue.trim() || !miscFee.trim() || !contactPhone.trim() || !contactEmail.trim() || !contactTimings.trim() || !contactAddress.trim() ||
        !groceryPickupAddress.trim() ||
        !groceryFreeDeliveryThreshold.trim() || !combinedFreeDeliveryThreshold.trim() || !deliveryFee.trim() ||
        !heroGreetingClosed.trim() || !heroSubtitleClosed.trim() ||
        !heroGreetingMorning.trim() || !heroSubtitleMorningMartClosed.trim() || !heroSubtitleMorningCafeClosed.trim() || !heroSubtitleMorningBothOpen.trim() ||
        !heroGreetingAfternoon.trim() || !heroSubtitleAfternoonMartClosed.trim() || !heroSubtitleAfternoonCafeClosed.trim() || !heroSubtitleAfternoonBothOpen.trim() ||
        !heroGreetingEvening.trim() || !heroSubtitleEveningMartClosed.trim() || !heroSubtitleEveningCafeClosed.trim() || !heroSubtitleEveningBothOpen.trim() ||
        !heroGreetingNight.trim() || !heroSubtitleNightMartClosed.trim() || !heroSubtitleNightCafeClosed.trim() || !heroSubtitleNightBothOpen.trim()) {
      toast.error('Please fill in all setting fields')
      return
    }

    try {
      setSaving(true)
      const categorySettingsPayload: Record<string, string> = {}
      Object.entries(categoryStatuses).forEach(([slug, isOpen]) => {
        categorySettingsPayload[`category_open_${slug}`] = isOpen ? 'true' : 'false'
      })

      const res = await fetch('/api/admin/settings', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          deliveries_count: deliveriesCount.trim(),
          rating_value: ratingValue.trim(),
          happy_families: happyFamilies.trim(),
          trusted_text: trustedText.trim(),
          grocery_mart_open: groceryMartOpen ? 'true' : 'false',
          grocery_auto_timing: groceryAutoTiming ? 'true' : 'false',
          grocery_open_time: groceryOpenTime,
          grocery_close_time: groceryCloseTime,
          only_cod: onlyCod ? 'true' : 'false',
          delivery_radius: deliveryRadius.trim(),
          store_upi_vpa: storeUpiVpa.trim(),
          store_lat: storeLat.trim(),
          store_lng: storeLng.trim(),
          avg_delivery_time: avgDeliveryTime.trim(),
          delivered_today: deliveredToday.trim(),
          fresh_stock_loaded: freshStockLoaded.trim(),
          tax_rate: taxRate.trim(),
          min_order_value: minOrderValue.trim(),
          misc_fee: miscFee.trim(),
          misc_fee_label: miscFeeLabel.trim(),
          grocery_free_delivery_threshold: groceryFreeDeliveryThreshold.trim(),
          combined_free_delivery_threshold: combinedFreeDeliveryThreshold.trim(),
          delivery_fee: deliveryFee.trim(),
          contact_phone: contactPhone.trim(),
          contact_email: contactEmail.trim(),
          contact_timings: contactTimings.trim(),
          contact_address: contactAddress.trim(),
          grocery_pickup_address: groceryPickupAddress.trim(),
          whatsapp_notify_7054470303: notifyPhone1 ? 'true' : 'false',
          whatsapp_notify_8112849854: notifyPhone2 ? 'true' : 'false',
          hero_greeting_closed: heroGreetingClosed.trim(),
          hero_subtitle_closed: heroSubtitleClosed.trim(),
          hero_greeting_morning: heroGreetingMorning.trim(),
          hero_subtitle_morning_mart_closed: heroSubtitleMorningMartClosed.trim(),
          hero_subtitle_morning_cafe_closed: heroSubtitleMorningCafeClosed.trim(),
          hero_subtitle_morning_both_open: heroSubtitleMorningBothOpen.trim(),
          hero_greeting_afternoon: heroGreetingAfternoon.trim(),
          hero_subtitle_afternoon_mart_closed: heroSubtitleAfternoonMartClosed.trim(),
          hero_subtitle_afternoon_cafe_closed: heroSubtitleAfternoonCafeClosed.trim(),
          hero_subtitle_afternoon_both_open: heroSubtitleAfternoonBothOpen.trim(),
          hero_greeting_evening: heroGreetingEvening.trim(),
          hero_subtitle_evening_mart_closed: heroSubtitleEveningMartClosed.trim(),
          hero_subtitle_evening_cafe_closed: heroSubtitleEveningCafeClosed.trim(),
          hero_subtitle_evening_both_open: heroSubtitleEveningBothOpen.trim(),
          hero_greeting_night: heroGreetingNight.trim(),
          hero_subtitle_night_mart_closed: heroSubtitleNightMartClosed.trim(),
          hero_subtitle_night_cafe_closed: heroSubtitleNightCafeClosed.trim(),
          hero_subtitle_night_both_open: heroSubtitleNightBothOpen.trim(),
          min_app_version: minAppVersion.trim(),
          latest_app_version: latestAppVersion.trim(),
          app_update_url: appUpdateUrl.trim(),
          app_update_message: appUpdateMessage.trim(),
          app_force_update: appForceUpdate ? 'true' : 'false',
          surge_mode: surgeMode,
          surge_rain_amount: surgeRainAmount.trim(),
          surge_demand_amount: surgeDemandAmount.trim(),
          surge_manual_amount: surgeManualAmount.trim(),
          surge_max_cap: surgeMaxCap.trim(),
          surge_demand_threshold: surgeDemandThreshold.trim(),
          ...categorySettingsPayload,
        }),
      })

      if (!res.ok) throw new Error('Failed to update settings')
      
      toast.success('Store settings updated successfully!')
      if (onSettingsSaved) onSettingsSaved()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error saving store settings')
    } finally {
      setSaving(false)
    }
  }

  if (loading) {
    return (
      <div className="py-20 flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-accent" />
      </div>
    )
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -15 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="grid grid-cols-1 lg:grid-cols-3 gap-6"
    >
      {/* Settings Form */}
      <div className="lg:col-span-2 space-y-6">
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-border/40 pb-4">
            <div>
              <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
                <Sliders className="h-5 w-5 text-accent" />
                Store Stats & Settings
              </h3>
              <p className="text-xs text-text-secondary mt-0.5">
                Customize operational parameters, storefront branding counters, and financials.
              </p>
            </div>

            {/* Tab switch header */}
            <div className="flex gap-1.5 bg-muted/30 p-1 rounded-xl max-w-max">
              {[
                { id: 'ops', label: '🚚 Operations' },
                { id: 'cosmetics', label: '🎨 Branding' },
                { id: 'greetings', label: '👋 Greetings' },
                { id: 'finance', label: '🔑 Financials' },
                { id: 'surge', label: '🌧️ Auto Surge' },
                { id: 'app', label: '📲 App Updates' }
              ].map(t => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => setSettingsTab(t.id as any)}
                  className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all cursor-pointer ${
                    settingsTab === t.id
                      ? 'bg-card text-primary shadow-sm border border-border/40'
                      : 'text-text-secondary hover:text-text-primary'
                  }`}
                >
                  {t.label}
                </button>
              ))}
            </div>
          </div>

          <form onSubmit={handleSave} className="space-y-6">
            {settingsTab === 'cosmetics' && (
              <div className="space-y-4 animate-fade-in">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  {/* Deliveries Count */}
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Deliveries Counter *</label>
                    <div className="relative">
                      <Package className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                      <input
                        type="text"
                        required
                        placeholder="e.g. 10,000+"
                        value={deliveriesCount}
                        onChange={(e) => setDeliveriesCount(e.target.value)}
                        className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                  </div>

                  {/* Average Rating */}
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Rating *</label>
                    <div className="relative">
                      <Star className="absolute left-3 top-2.5 h-4 w-4 text-amber-500 fill-amber-500/10" />
                      <input
                        type="text"
                        required
                        placeholder="e.g. 4.8"
                        value={ratingValue}
                        onChange={(e) => setRatingValue(e.target.value)}
                        className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                  </div>

                  {/* Happy Families Count */}
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Happy Families Counter *</label>
                    <div className="relative">
                      <Heart className="absolute left-3 top-2.5 h-4 w-4 text-primary fill-primary/10" />
                      <input
                        type="text"
                        required
                        placeholder="e.g. 5,000+"
                        value={happyFamilies}
                        onChange={(e) => setHappyFamilies(e.target.value)}
                        className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                  </div>

                  {/* Social Proof Header Strip Text */}
                  <div className="md:col-span-3 space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Social Proof Strip Text (Footer) *</label>
                    <div className="relative">
                      <FileText className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                      <input
                        type="text"
                        required
                        placeholder="e.g. ✨ Trusted by 5,000+ families in your town"
                        value={trustedText}
                        onChange={(e) => setTrustedText(e.target.value)}
                        className="w-full bg-muted/40 border border-border pl-9 pr-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                      />
                    </div>
                  </div>

                  {/* Speed Strip Ticker Configuration */}
                  <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                    <h4 className="text-xs font-black text-text-primary mb-3">⚡ Live Speed Ticker Strip Settings</h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      {/* Avg Delivery Time */}
                      <div className="space-y-1.5">
                        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Average Delivery Time *</label>
                        <input
                          type="text"
                          required
                          placeholder="e.g. 8 min"
                          value={avgDeliveryTime}
                          onChange={(e) => setAvgDeliveryTime(e.target.value)}
                          className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                        />
                      </div>

                      {/* Delivered Today */}
                      <div className="space-y-1.5">
                        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Delivered Today Counter *</label>
                        <input
                          type="text"
                          required
                          placeholder="e.g. 1,231+"
                          value={deliveredToday}
                          onChange={(e) => setDeliveredToday(e.target.value)}
                          className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                        />
                      </div>

                      {/* Fresh Stock Loaded */}
                      <div className="space-y-1.5">
                        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Fresh Stock Loaded Indicator *</label>
                        <input
                          type="text"
                          required
                          placeholder="e.g. 2 hrs ago"
                          value={freshStockLoaded}
                          onChange={(e) => setFreshStockLoaded(e.target.value)}
                          className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                        />
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {settingsTab === 'ops' && (
              <div className="space-y-4 animate-fade-in">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Grocery Mart Automated Store Timings & Schedule Control */}
                  <div className="space-y-3.5 bg-muted/20 p-4 sm:p-5 rounded-2xl border border-border/60 text-left">
                    <div className="flex items-center justify-between gap-3">
                      <div>
                        <label className="text-xs font-black uppercase tracking-wider text-text-primary flex items-center gap-1.5">
                          ⏰ Grocery Mart Timings & Auto-Schedule
                        </label>
                        <p className="text-[11px] text-text-secondary mt-0.5 font-medium">
                          Store timings ke hisaab se rozana automatically ON/OFF hoga.
                        </p>
                      </div>
                      <span className={`text-[11px] font-black px-2.5 py-1 rounded-full border shrink-0 ${
                        isGroceryCurrentlyOpen
                          ? 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                          : 'bg-rose-500/10 text-rose-600 border-rose-500/20'
                      }`}>
                        {isGroceryCurrentlyOpen ? '● OPEN' : '○ CLOSED'}
                      </span>
                    </div>

                    {/* Auto-Timing Status Banner */}
                    <div className="bg-primary/5 border border-primary/20 rounded-xl p-3 flex items-start gap-2.5">
                      <span className="text-base leading-none">✨</span>
                      <div className="text-xs">
                        <p className="font-bold text-text-primary">
                          {groceryAutoTiming ? 'Auto-Schedule Active (Roj Automatic On/Off)' : 'Manual Override Active'}
                        </p>
                        <p className="text-[11px] text-text-secondary mt-0.5">
                          {groceryAutoTiming 
                            ? `Store subah ${groceryOpenTime || '07:00'} baje apne aap khulega aur raat ${groceryCloseTime || '22:00'} baje band hoga. Roj manually ON karne ki zaroorat nahi hai.`
                            : 'Auto-timing off hai. Store manual mode par chal raha hai.'}
                        </p>
                      </div>
                    </div>

                    {/* Store Timings (Opening & Closing Hours) */}
                    <div className="pt-2 border-t border-border/40 space-y-3">
                      <div className="flex items-center justify-between">
                        <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                          ⏰ Operating Hours
                        </label>
                        <label className="flex items-center gap-1.5 cursor-pointer text-[10px] font-bold text-text-secondary">
                          <input
                            type="checkbox"
                            checked={groceryAutoTiming}
                            onChange={(e) => {
                              const checked = e.target.checked
                              setGroceryAutoTiming(checked)
                            }}
                            className="rounded border-border text-primary focus:ring-primary h-3.5 w-3.5"
                          />
                          <span>Auto-timing apply</span>
                        </label>
                      </div>

                      <div className="grid grid-cols-2 gap-2.5">
                        <div className="space-y-1">
                          <span className="text-[10px] font-bold text-text-muted block">Open Time (Subah)</span>
                          <input
                            type="time"
                            value={groceryOpenTime}
                            onChange={(e) => setGroceryOpenTime(e.target.value)}
                            className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                          />
                        </div>
                        <div className="space-y-1">
                          <span className="text-[10px] font-bold text-text-muted block">Close Time (Raat)</span>
                          <input
                            type="time"
                            value={groceryCloseTime}
                            onChange={(e) => setGroceryCloseTime(e.target.value)}
                            className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-xs"
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                  {/* Only Cash on Delivery */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Only Cash on Delivery</label>
                    <select
                      value={onlyCod ? 'true' : 'false'}
                      onChange={(e) => setOnlyCod(e.target.value === 'true')}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
                    >
                      <option value="false">🔴 Off (All Payments)</option>
                      <option value="true">🟢 On (COD/COP Only)</option>
                    </select>
                  </div>

                  {/* Delivery Radius */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Delivery Radius (km) *</label>
                    <input
                      type="number"
                      required
                      min="1"
                      max="100"
                      placeholder="e.g. 5"
                      value={deliveryRadius}
                      onChange={(e) => setDeliveryRadius(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Store Latitude */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Latitude (GPS) *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 26.1555"
                      value={storeLat}
                      onChange={(e) => setStoreLat(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Store Longitude */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Longitude (GPS) *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 80.1688"
                      value={storeLng}
                      onChange={(e) => setStoreLng(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Phone */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Phone *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. +91 70544 70303"
                      value={contactPhone}
                      onChange={(e) => setContactPhone(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Email */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Email *</label>
                    <input
                      type="email"
                      required
                      placeholder="e.g. help@fastkirana.com"
                      value={contactEmail}
                      onChange={(e) => setContactEmail(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Timings */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Contact Timings *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 6 AM - 12 AM"
                      value={contactTimings}
                      onChange={(e) => setContactTimings(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Contact Address */}
                  <div className="md:col-span-3 space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Store Pickup & Contact Address *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. NH34, Ghatampur, Kanpur Nagar"
                      value={contactAddress}
                      onChange={(e) => setContactAddress(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>

                  {/* Grocery Pickup Address */}
                  <div className="md:col-span-3 space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Grocery Warehouse / Store Self-Pickup Address *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Vikas Medical Store, NH34, Ghatampur, Kanpur Nagar, Kanpur, 209206"
                      value={groceryPickupAddress}
                      onChange={(e) => setGroceryPickupAddress(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                    />
                    <p className="text-[10px] text-text-muted">Note: Individual restaurant pickup addresses are configured per outlet in the <strong>Manage Outlets</strong> tab.</p>
                  </div>

                  {/* WhatsApp Order Notifications Settings */}
                  <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2 space-y-2">
                    <h4 className="text-xs font-black text-text-primary">💬 WhatsApp Order Alerts Configuration</h4>
                    <p className="text-[10px] text-text-muted font-bold leading-relaxed">
                      Select which admin phone numbers should receive instant WhatsApp notifications when a customer places a new order.
                    </p>
                    <div className="flex flex-col sm:flex-row gap-5 bg-muted/20 p-4 rounded-2xl border border-border/40 w-fit">
                      <label className="flex items-center gap-2.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                        <input
                          type="checkbox"
                          checked={notifyPhone1}
                          onChange={(e) => setNotifyPhone1(e.target.checked)}
                          className="h-4 w-4 rounded border-border text-primary focus:ring-primary cursor-pointer"
                        />
                        <span>Send alerts to +91 70544 70303</span>
                      </label>
                      <label className="flex items-center gap-2.5 text-xs font-bold text-text-primary cursor-pointer select-none">
                        <input
                          type="checkbox"
                          checked={notifyPhone2}
                          onChange={(e) => setNotifyPhone2(e.target.checked)}
                          className="h-4 w-4 rounded border-border text-primary focus:ring-primary cursor-pointer"
                        />
                        <span>Send alerts to +91 81128 49854</span>
                      </label>
                    </div>
                  </div>

                  {/* Category-Wise Statuses Section */}
                  <div className="md:col-span-3 border-t border-border/40 pt-4 mt-2">
                    <h4 className="text-xs font-black text-text-primary mb-3">🏪 Category-Wise Status (Open/Closed)</h4>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                      {categories.map((cat) => (
                        <div key={cat.id} className="space-y-1.5">
                          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                            {cat.name} Status
                          </label>
                          <select
                            value={categoryStatuses[cat.slug] !== false ? 'true' : 'false'}
                            onChange={(e) => {
                              const isOpen = e.target.value === 'true'
                              setCategoryStatuses((prev) => ({
                                ...prev,
                                [cat.slug]: isOpen,
                              }))
                            }}
                            className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold cursor-pointer"
                          >
                            <option value="true">🟢 Open (Active)</option>
                            <option value="false">🔴 Closed (Temporarily)</option>
                          </select>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}

            {settingsTab === 'finance' && (
              <div className="space-y-4 animate-fade-in">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* GST/Tax Rate Hidden */}
                  {false && (
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">GST/Tax Rate (%) *</label>
                      <input
                        type="number"
                        required
                        min="0"
                        max="100"
                        step="0.1"
                        placeholder="e.g. 5"
                        value={taxRate}
                        onChange={(e) => setTaxRate(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                  )}

                  {/* Miscellaneous Fee */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Miscellaneous Fee (₹) *</label>
                    <input
                      type="number"
                      required
                      min="0"
                      step="0.01"
                      placeholder="e.g. 0"
                      value={miscFee}
                      onChange={(e) => setMiscFee(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Miscellaneous Fee Label */}
                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Miscellaneous Fee Label *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Packaging Charge"
                      value={miscFeeLabel}
                      onChange={(e) => setMiscFeeLabel(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Store UPI VPA / QR Code Handle */}
                  <div className="space-y-1.5 md:col-span-2 border-t border-border/40 pt-4 mt-2">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      📱 Store UPI VPA / QR Code Handle (दुकान का UPI ID) *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 7054470303@paytm or fastkirana@upi"
                      value={storeUpiVpa}
                      onChange={(e) => setStoreUpiVpa(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-mono font-bold text-emerald-600 dark:text-emerald-400"
                    />
                    <p className="text-[10px] text-text-muted font-medium">
                      This UPI VPA handle generates the dynamic doorstep QR scanner for riders in the Delivery Console. Change it anytime here.
                    </p>
                  </div>
                </div>

                {/* Delivery Fees & Free Thresholds */}
                <div className="border-t border-border/40 pt-4 mt-2">
                  <h4 className="text-xs font-black text-text-primary mb-3">🚚 Delivery Fees & Free Delivery Thresholds</h4>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {/* Delivery Fee */}
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Standard Delivery Fee (₹) *</label>
                      <input
                        type="number"
                        required
                        min="0"
                        placeholder="e.g. 25"
                        value={deliveryFee}
                        onChange={(e) => setDeliveryFee(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>

                    {/* Minimum Order Value */}
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Minimum Order Value (₹) *</label>
                      <input
                        type="number"
                        required
                        min="0"
                        placeholder="e.g. 0"
                        value={minOrderValue}
                        onChange={(e) => setMinOrderValue(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>

                    {/* Combined Free Delivery Threshold */}
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Combined Order Free Delivery Threshold (₹) *</label>
                      <input
                        type="number"
                        required
                        min="0"
                        placeholder="e.g. 200"
                        value={combinedFreeDeliveryThreshold}
                        onChange={(e) => setCombinedFreeDeliveryThreshold(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>

                    {/* Grocery Free Delivery Threshold */}
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Grocery Order Free Delivery Threshold (₹) *</label>
                      <input
                        type="number"
                        required
                        min="0"
                        placeholder="e.g. 199"
                        value={groceryFreeDeliveryThreshold}
                        onChange={(e) => setGroceryFreeDeliveryThreshold(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>

                  </div>
                </div>

                {/* Image Storage Configuration */}
                <div className="border-t border-border/40 pt-4 mt-2">
                  <h4 className="text-xs font-black text-text-primary mb-3">📦 Image Storage (Supabase Storage)</h4>
                  <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-xl p-3">
                    <div className="flex items-center gap-2">
                      <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                      <span className="text-xs font-bold text-emerald-600">Active — Supabase Storage</span>
                    </div>
                    <p className="text-[9px] text-text-secondary mt-1.5 font-semibold">
                      All product images, delivery photos, and uploads are automatically stored in Supabase Storage. No configuration needed.
                    </p>
                  </div>
                </div>
              </div>
            )}

            {settingsTab === 'greetings' && (
              <div className="space-y-6 animate-fade-in">
                {/* Time-of-day mode tabs switcher */}
                <div className="flex flex-wrap gap-1 bg-muted/20 p-1 rounded-xl">
                  {[
                    { id: 'closed', label: '💤 Closed' },
                    { id: 'morning', label: '🌅 Morning (6-11)' },
                    { id: 'afternoon', label: '🍛 Afternoon (11-16)' },
                    { id: 'evening', label: '☕ Evening (16-20)' },
                    { id: 'night', label: '🌙 Night (20-5)' }
                  ].map(subTab => (
                    <button
                      key={subTab.id}
                      type="button"
                      onClick={() => setGreetingsSubTab(subTab.id as any)}
                      className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all cursor-pointer ${
                        greetingsSubTab === subTab.id
                          ? 'bg-card text-accent border border-border/30 shadow-xs'
                          : 'text-text-secondary hover:text-text-primary'
                      }`}
                    >
                      {subTab.label}
                    </button>
                  ))}
                </div>

                {/* Sub Tab Contents */}
                {greetingsSubTab === 'closed' && (
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Closed Greeting *</label>
                      <input
                        type="text"
                        required
                        value={heroGreetingClosed}
                        onChange={(e) => setHeroGreetingClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Closed Subtitle *</label>
                      <textarea
                        required
                        rows={3}
                        value={heroSubtitleClosed}
                        onChange={(e) => setHeroSubtitleClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                  </div>
                )}

                {greetingsSubTab === 'morning' && (
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Morning Greeting *</label>
                      <input
                        type="text"
                        required
                        value={heroGreetingMorning}
                        onChange={(e) => setHeroGreetingMorning(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Grocery Mart Closed & Cafe Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleMorningMartClosed}
                        onChange={(e) => setHeroSubtitleMorningMartClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Cafe Closed & Grocery Mart Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleMorningCafeClosed}
                        onChange={(e) => setHeroSubtitleMorningCafeClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Both Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleMorningBothOpen}
                        onChange={(e) => setHeroSubtitleMorningBothOpen(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                  </div>
                )}

                {greetingsSubTab === 'afternoon' && (
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Afternoon Greeting *</label>
                      <input
                        type="text"
                        required
                        value={heroGreetingAfternoon}
                        onChange={(e) => setHeroGreetingAfternoon(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Grocery Mart Closed & Cafe Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleAfternoonMartClosed}
                        onChange={(e) => setHeroSubtitleAfternoonMartClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Cafe Closed & Grocery Mart Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleAfternoonCafeClosed}
                        onChange={(e) => setHeroSubtitleAfternoonCafeClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Both Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleAfternoonBothOpen}
                        onChange={(e) => setHeroSubtitleAfternoonBothOpen(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                  </div>
                )}

                {greetingsSubTab === 'evening' && (
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Evening Greeting *</label>
                      <input
                        type="text"
                        required
                        value={heroGreetingEvening}
                        onChange={(e) => setHeroGreetingEvening(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Grocery Mart Closed & Cafe Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleEveningMartClosed}
                        onChange={(e) => setHeroSubtitleEveningMartClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Cafe Closed & Grocery Mart Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleEveningCafeClosed}
                        onChange={(e) => setHeroSubtitleEveningCafeClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Both Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleEveningBothOpen}
                        onChange={(e) => setHeroSubtitleEveningBothOpen(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                  </div>
                )}

                {greetingsSubTab === 'night' && (
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Night Greeting *</label>
                      <input
                        type="text"
                        required
                        value={heroGreetingNight}
                        onChange={(e) => setHeroGreetingNight(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Grocery Mart Closed & Cafe Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleNightMartClosed}
                        onChange={(e) => setHeroSubtitleNightMartClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Cafe Closed & Grocery Mart Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleNightCafeClosed}
                        onChange={(e) => setHeroSubtitleNightCafeClosed(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Subtitle: Both Open *</label>
                      <textarea
                        required
                        rows={2}
                        value={heroSubtitleNightBothOpen}
                        onChange={(e) => setHeroSubtitleNightBothOpen(e.target.value)}
                        className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                      />
                    </div>
                  </div>
                )}
              </div>
            )}

            {settingsTab === 'app' && (
              <div className="space-y-6 animate-fade-in">
                <div className="bg-primary/5 border border-primary/20 rounded-xl p-4 flex items-start gap-3">
                  <Smartphone className="h-5 w-5 text-primary shrink-0 mt-0.5" />
                  <div>
                    <h4 className="text-xs font-bold text-text-primary">In-App Version & Remote Update System</h4>
                    <p className="text-[11px] text-text-secondary mt-0.5">
                      Controls which app versions customers are using. When you release a new APK, update the version and APK link here to prompt all active users to upgrade instantly.
                    </p>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {/* Latest App Version */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
                      <RefreshCw className="h-3.5 w-3.5 text-primary" />
                      Latest App Version (Target) *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 1.0.1"
                      value={latestAppVersion}
                      onChange={(e) => setLatestAppVersion(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                    <p className="text-[9px] text-text-muted">Customers below this version will see the &quot;Update Available&quot; popup.</p>
                  </div>

                  {/* Minimum Required Version */}
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
                      <AlertCircle className="h-3.5 w-3.5 text-amber-500" />
                      Minimum Supported Version *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. 1.0.0"
                      value={minAppVersion}
                      onChange={(e) => setMinAppVersion(e.target.value)}
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                    <p className="text-[9px] text-text-muted">Older versions below this floor are automatically forced to update.</p>
                  </div>
                </div>

                {/* APK Download URL */}
                <div className="space-y-1.5">
                  <div className="flex items-center justify-between">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
                      <Download className="h-3.5 w-3.5 text-accent" />
                      Direct APK Download URL *
                    </label>
                    {appUpdateUrl && (
                      <a
                        href={appUpdateUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="text-[10px] text-accent hover:underline font-bold"
                      >
                        Test Link ↗
                      </a>
                    )}
                  </div>
                  <input
                    type="url"
                    required
                    placeholder="https://fastkirana.in/app-release.apk or Supabase/Drive download URL"
                    value={appUpdateUrl}
                    onChange={(e) => setAppUpdateUrl(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-mono text-[11px]"
                  />
                  <p className="text-[9px] text-text-muted">Tapping &quot;Update Now&quot; in the mobile app opens this link directly in the user&apos;s browser to start the download.</p>
                </div>

                {/* Force Update Toggle */}
                <div className="flex items-center justify-between p-4 bg-muted/30 border border-border/60 rounded-xl">
                  <div>
                    <h5 className="text-xs font-bold text-text-primary">Enforce Mandatory Update (Force Update)</h5>
                    <p className="text-[10px] text-text-secondary mt-0.5">
                      If enabled, customers cannot dismiss the popup or use the app until they install the latest APK.
                    </p>
                  </div>
                  <label className="relative inline-flex items-center cursor-pointer">
                    <input
                      type="checkbox"
                      checked={appForceUpdate}
                      onChange={(e) => setAppForceUpdate(e.target.checked)}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-muted peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-accent"></div>
                  </label>
                </div>

                {/* Update Announcement / Release Notes */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                    Update Message / Release Notes for Customers *
                  </label>
                  <textarea
                    required
                    rows={3}
                    placeholder="Describe new features or improvements..."
                    value={appUpdateMessage}
                    onChange={(e) => setAppUpdateMessage(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                  />
                </div>
              </div>
            )}

            {/* Auto Rain & Demand Surge Tab */}
            {settingsTab === 'surge' && (
              <div className="space-y-6">
                {/* Live Realtime Telemetry Card */}
                <div className="bg-gradient-to-br from-card to-muted/30 border border-border/80 p-5 rounded-2xl shadow-sm space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-8 h-8 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-blue-500">
                        <CloudRain className="h-4 w-4" />
                      </div>
                      <div>
                        <h4 className="text-xs font-bold text-text-primary">Live Surge & Weather Telemetry</h4>
                        <p className="text-[10px] text-text-secondary">Real-time status based on Ghatampur coordinates & active rider fleet</p>
                      </div>
                    </div>
                    <span className={`px-2.5 py-1 rounded-full text-[10px] font-black border ${
                      surgeActive
                        ? 'bg-amber-500/10 text-amber-500 border-amber-500/30 animate-pulse'
                        : 'bg-emerald-500/10 text-emerald-500 border-emerald-500/30'
                    }`}>
                      {surgeActive ? `⚡ Surge Active: +₹${surgeFee}` : '🟢 Standard Rates (₹0 Surge)'}
                    </span>
                  </div>

                  {surgeActive && surgeReason && (
                    <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-xl text-xs font-medium text-amber-600 flex items-center gap-2">
                      <Zap className="h-4 w-4 shrink-0" />
                      <span><strong>Reason:</strong> {surgeReason}</span>
                    </div>
                  )}

                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-2">
                    <div className="bg-muted/40 p-3 rounded-xl border border-border/60">
                      <span className="text-[9px] font-black uppercase tracking-wider text-text-muted">Live Weather Condition</span>
                      <div className="flex items-center justify-between mt-1">
                        <span className="text-xs font-bold text-text-primary">{currentWeatherCondition}</span>
                        <span className="text-xs font-black text-blue-500">{currentWeatherTemp}°C</span>
                      </div>
                      <p className="text-[10px] text-text-secondary mt-1">Ghatampur (26.1534° N, 80.1714° E)</p>
                    </div>

                    <div className="bg-muted/40 p-3 rounded-xl border border-border/60">
                      <span className="text-[9px] font-black uppercase tracking-wider text-text-muted">Live Delivery Rush Load</span>
                      <div className="flex items-center justify-between mt-1">
                        <span className="text-xs font-bold text-text-primary">{currentActiveOrders} Active Orders</span>
                        <span className="text-xs font-black text-accent">{currentActiveRiders} Active Riders</span>
                      </div>
                      <p className="text-[10px] text-text-secondary mt-1">
                        Fleet ratio: {Number(currentActiveRiders) > 0 ? (Number(currentActiveOrders) / Number(currentActiveRiders)).toFixed(1) : currentActiveOrders} orders / rider
                      </p>
                    </div>
                  </div>
                </div>

                {/* Master Mode Selector */}
                <div className="space-y-3">
                  <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary flex items-center gap-1.5">
                    <ShieldCheck className="h-3.5 w-3.5 text-primary" /> Master Surge Control Mode
                  </label>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                    <button
                      type="button"
                      onClick={() => setSurgeMode('AUTO')}
                      className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
                        surgeMode === 'AUTO'
                          ? 'bg-primary/5 border-primary shadow-sm ring-1 ring-primary/30'
                          : 'bg-card border-border hover:border-border/80'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-black text-text-primary">🤖 Automatic (Recommended)</span>
                        {surgeMode === 'AUTO' && <span className="w-2 h-2 rounded-full bg-primary animate-ping" />}
                      </div>
                      <p className="text-[10px] text-text-secondary leading-relaxed">
                        Evaluates live rain weather and rush ratio automatically. Capped strictly at maximum ceiling.
                      </p>
                    </button>

                    <button
                      type="button"
                      onClick={() => setSurgeMode('MANUAL_ON')}
                      className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
                        surgeMode === 'MANUAL_ON'
                          ? 'bg-amber-500/5 border-amber-500 shadow-sm ring-1 ring-amber-500/30'
                          : 'bg-card border-border hover:border-border/80'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-black text-amber-500">⚡ Force ON (Manual)</span>
                        {surgeMode === 'MANUAL_ON' && <span className="w-2 h-2 rounded-full bg-amber-500" />}
                      </div>
                      <p className="text-[10px] text-text-secondary leading-relaxed">
                        Forces surge pricing on all checkouts right now, regardless of weather or rush.
                      </p>
                    </button>

                    <button
                      type="button"
                      onClick={() => setSurgeMode('MANUAL_OFF')}
                      className={`p-4 rounded-xl border text-left transition-all cursor-pointer ${
                        surgeMode === 'MANUAL_OFF'
                          ? 'bg-emerald-500/5 border-emerald-500 shadow-sm ring-1 ring-emerald-500/30'
                          : 'bg-card border-border hover:border-border/80'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-1">
                        <span className="text-xs font-black text-emerald-500">🛑 Force OFF (Strict Disabled)</span>
                        {surgeMode === 'MANUAL_OFF' && <span className="w-2 h-2 rounded-full bg-emerald-500" />}
                      </div>
                      <p className="text-[10px] text-text-secondary leading-relaxed">
                        Strictly guarantees ₹0 surge fee. Protects customers from any extra fees.
                      </p>
                    </button>
                  </div>
                </div>

                {/* Safety Cap and Surge Parameters Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      🌧️ Rain Surge Fee (₹)
                    </label>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={surgeRainAmount}
                      onChange={(e) => setSurgeRainAmount(e.target.value)}
                      placeholder="20"
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                    <p className="text-[9px] text-text-secondary">Added automatically when rain/thunderstorm is detected in Ghatampur</p>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      🔥 Demand Rush Surge Fee (₹)
                    </label>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={surgeDemandAmount}
                      onChange={(e) => setSurgeDemandAmount(e.target.value)}
                      placeholder="15"
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                    <p className="text-[9px] text-text-secondary">Added when active orders exceed active delivery boys threshold</p>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      🛡️ Strict Max Safety Cap Ceiling (₹) *
                    </label>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={surgeMaxCap}
                      onChange={(e) => setSurgeMaxCap(e.target.value)}
                      placeholder="25"
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium font-bold text-accent"
                    />
                    <p className="text-[9px] text-text-secondary font-bold">Hard safety limit: Total surge fee will NEVER exceed this amount under any condition.</p>
                  </div>

                  <div className="space-y-1.5">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      ⚡ Manual Mode Fixed Fee (₹)
                    </label>
                    <input
                      type="number"
                      min="0"
                      max="100"
                      value={surgeManualAmount}
                      onChange={(e) => setSurgeManualAmount(e.target.value)}
                      placeholder="20"
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                    <p className="text-[9px] text-text-secondary">Fee used when Master Mode is set to 'Force ON (Manual)'</p>
                  </div>

                  <div className="space-y-1.5 md:col-span-2">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      📊 Demand Ratio Trigger (Orders per Delivery Boy)
                    </label>
                    <input
                      type="number"
                      step="0.5"
                      min="1.0"
                      max="10.0"
                      value={surgeDemandThreshold}
                      onChange={(e) => setSurgeDemandThreshold(e.target.value)}
                      placeholder="3.0"
                      className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                    <p className="text-[9px] text-text-secondary">Example: 3.0 means if there are more than 3 pending orders per active rider, demand surge triggers.</p>
                  </div>
                </div>

                {/* Customer Transparency Note */}
                <div className="p-4 bg-muted/20 border border-border/80 rounded-xl space-y-1.5">
                  <span className="text-[10px] font-black text-text-primary flex items-center gap-1.5">
                    💡 Customer Transparency Policy
                  </span>
                  <p className="text-[10px] text-text-secondary leading-relaxed">
                    Surge charges are transparently listed in the customer bill breakdown as <strong>"🌧️ Rain Surge (Delivery Partner Safety Incentive)"</strong> or <strong>"⚡ High Demand Rush Fee"</strong>. This ensures total trust with customers while incentivizing delivery partners to braving harsh conditions.
                  </p>
                </div>
              </div>
            )}

            {/* Action buttons */}
            <div className="pt-4 border-t border-border/40 flex justify-end">
              <button
                type="submit"
                disabled={saving}
                className="h-10 px-6 rounded-xl bg-accent hover:bg-accent-dark text-white font-black text-xs transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 cursor-pointer shadow active:scale-98"
              >
                {saving ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    Saving Settings...
                  </>
                ) : (
                  <>
                    <Save className="h-4 w-4" />
                    Save Settings
                  </>
                )}
              </button>
            </div>
          </form>
        </div>
      </div>

      {/* Live Preview Sidebar */}
      <div className="space-y-6">
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex items-center gap-1.5">
            <Eye className="h-5 w-5 text-accent" />
            <h3 className="text-sm font-bold text-text-primary">Live Preview</h3>
          </div>
          
          {/* Stats Bar Preview */}
          <div className="space-y-2">
            <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-muted">Home Page Stats Bar</label>
            <div className="flex items-center justify-center gap-4 py-3 bg-muted/20 border border-border/60 rounded-xl px-2">
              <div className="flex items-center gap-1">
                <Package className="h-3.5 w-3.5 text-primary" />
                <span className="text-[11px] font-black text-text-primary">{deliveriesCount}</span>
                <span className="text-[10px] text-text-secondary font-medium">Deliveries</span>
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1">
                <Star className="h-3.5 w-3.5 text-amber-500" />
                <span className="text-[11px] font-black text-text-primary">{ratingValue}★</span>
                <span className="text-[10px] text-text-secondary font-medium">Rating</span>
              </div>
              <div className="h-3 w-px bg-border" />
              <div className="flex items-center gap-1">
                <Heart className="h-3.5 w-3.5 text-primary" />
                <span className="text-[11px] font-black text-text-primary">{happyFamilies}</span>
                <span className="text-[10px] text-text-secondary font-medium">Families</span>
              </div>
            </div>
          </div>

          {/* Social Proof Strip Preview */}
          <div className="space-y-2">
            <label className="text-[9px] font-extrabold uppercase tracking-wider text-text-muted">Footer Social Proof Bar</label>
            <div className="bg-text-primary py-2.5 rounded-xl text-center border border-border/60 shadow-sm overflow-hidden">
              <p className="text-[10px] font-extrabold text-accent leading-normal select-none px-4">
                {trustedText}
              </p>
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  )
}
