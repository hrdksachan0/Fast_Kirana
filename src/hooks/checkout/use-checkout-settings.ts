'use client'

import { useState, useEffect } from 'react'
import {
  DEFAULT_DELIVERY_RADIUS_KM,
  DEFAULT_STORE_LAT,
  DEFAULT_STORE_LNG,
  DEFAULT_CONTACT_PHONE,
} from '@/lib/checkout'
import {
  GROCERY_FREE_DELIVERY_THRESHOLD,
  CAFE_FREE_DELIVERY_THRESHOLD,
  COMBINED_FREE_DELIVERY_THRESHOLD,
  DELIVERY_FEE,
} from '@/lib/constants'

export interface CheckoutSettings {
  storeSettingsMap: Record<string, string>
  isSettingsLoading: boolean
  deliveryRadius: number
  storeLat: number
  storeLng: number
  onlyCod: boolean
  taxRate: number
  miscFee: number
  miscFeeLabel: string
  contactPhone: string
  groceryMartOpen: boolean
  cafeOpen: boolean
  restaurantOpen: boolean
  groceryThreshold: number
  cafeThreshold: number
  combinedThreshold: number
  deliveryFeeVal: number
  groceryCloseTime: string
  cafeCloseTime: string
}

export function useCheckoutSettings(): CheckoutSettings {
  const [storeSettingsMap, setStoreSettingsMap] = useState<Record<string, string>>({})
  const [isSettingsLoading, setIsSettingsLoading] = useState(true)
  const [deliveryRadius, setDeliveryRadius] = useState(DEFAULT_DELIVERY_RADIUS_KM)
  const [storeLat, setStoreLat] = useState(DEFAULT_STORE_LAT)
  const [storeLng, setStoreLng] = useState(DEFAULT_STORE_LNG)
  const [onlyCod, setOnlyCod] = useState(false)
  const [taxRate, setTaxRate] = useState(0.0)
  const [miscFee, setMiscFee] = useState(0.0)
  const [miscFeeLabel, setMiscFeeLabel] = useState('Miscellaneous Additions')
  const [contactPhone, setContactPhone] = useState(DEFAULT_CONTACT_PHONE)
  const [groceryMartOpen, setGroceryMartOpen] = useState(true)
  const [cafeOpen, setCafeOpen] = useState(true)
  const [restaurantOpen, setRestaurantOpen] = useState(true)
  const [groceryThreshold, setGroceryThreshold] = useState(GROCERY_FREE_DELIVERY_THRESHOLD)
  const [cafeThreshold, setCafeThreshold] = useState(CAFE_FREE_DELIVERY_THRESHOLD)
  const [combinedThreshold, setCombinedThreshold] = useState(COMBINED_FREE_DELIVERY_THRESHOLD)
  const [deliveryFeeVal, setDeliveryFeeVal] = useState(DELIVERY_FEE)
  const [groceryCloseTime, setGroceryCloseTime] = useState('23:59')
  const [cafeCloseTime, setCafeCloseTime] = useState('23:59')

  useEffect(() => {
    fetch('/api/settings', { cache: 'no-store' })
      .then((res) => res.json())
      .then((data) => {
        if (data && typeof data === 'object') {
          setStoreSettingsMap(data)
        }
        if (data.grocery_mart_open !== undefined) {
          setGroceryMartOpen(data.grocery_mart_open === 'true')
        }
        if (data.cafe_open !== undefined) {
          setCafeOpen(data.cafe_open === 'true')
        }
        if (data.restaurant_open !== undefined) {
          setRestaurantOpen(data.restaurant_open === 'true')
        }
        if (data.delivery_radius) {
          setDeliveryRadius(parseFloat(data.delivery_radius))
        }
        if (data.store_lat) {
          setStoreLat(parseFloat(data.store_lat))
        }
        if (data.store_lng) {
          setStoreLng(parseFloat(data.store_lng))
        }
        if (data.only_cod !== undefined) {
          setOnlyCod(data.only_cod === 'true')
        }
        if (data.tax_rate !== undefined) {
          setTaxRate(0.0)
        }
        if (data.misc_fee !== undefined) {
          setMiscFee(parseFloat(data.misc_fee))
        }
        if (data.misc_fee_label !== undefined) {
          setMiscFeeLabel(data.misc_fee_label)
        }
        if (data.contact_phone) {
          setContactPhone(data.contact_phone)
        }
        if (data.grocery_free_delivery_threshold) {
          setGroceryThreshold(parseFloat(data.grocery_free_delivery_threshold))
        }
        if (data.cafe_free_delivery_threshold) {
          setCafeThreshold(parseFloat(data.cafe_free_delivery_threshold))
        }
        if (data.combined_free_delivery_threshold) {
          setCombinedThreshold(parseFloat(data.combined_free_delivery_threshold))
        }
        if (data.delivery_fee) {
          setDeliveryFeeVal(parseFloat(data.delivery_fee))
        }
        if (data.grocery_close_time) {
          setGroceryCloseTime(data.grocery_close_time)
        }
        if (data.cafe_close_time) {
          setCafeCloseTime(data.cafe_close_time)
        }
        setIsSettingsLoading(false)
      })
      .catch((err) => {
        console.error('Error fetching settings on checkout mount:', err)
        setIsSettingsLoading(false)
      })
  }, [])

  return {
    storeSettingsMap,
    isSettingsLoading,
    deliveryRadius,
    storeLat,
    storeLng,
    onlyCod,
    taxRate,
    miscFee,
    miscFeeLabel,
    contactPhone,
    groceryMartOpen,
    cafeOpen,
    restaurantOpen,
    groceryThreshold,
    cafeThreshold,
    combinedThreshold,
    deliveryFeeVal,
    groceryCloseTime,
    cafeCloseTime,
  }
}
