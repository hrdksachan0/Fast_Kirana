'use client'

import { useState, useEffect, useMemo } from 'react'
import type { CartItem } from '@/stores/cart-store'
import { useCartStore } from '@/stores/cart-store'
import { isProductEligibleForCoupon } from '@/lib/coupon-rules'
import { isCafeProduct } from '@/lib/utils'
import { getDistanceKm, getDeliveryRules } from '@/lib/distance'
import { getRestaurantLocation } from '@/lib/restaurant-location'
import { Address } from '@/types'
import { CheckoutSettings } from './use-checkout-settings'

export interface UseCheckoutPricingProps {
  items: CartItem[]
  subtotal: number
  mrpTotal: number
  savings: number
  selectedAddress?: Address
  settings: CheckoutSettings
  packagingOption: 'NORMAL' | 'PREMIUM'
  deliveryMethod?: 'DELIVERY' | 'PICKUP'
}

export function useCheckoutPricing({
  items,
  subtotal,
  mrpTotal,
  savings,
  selectedAddress,
  settings,
  packagingOption,
  deliveryMethod = 'DELIVERY',
}: UseCheckoutPricingProps) {
  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)
  const [appliedCoupon, setAppliedCoupon] = useState<{
    code: string
    discountAmount: number
    discountType?: string
    bogoType?: string
    badgeText?: string
    freeGiftDetails?: {
      id: string
      name: string
      price: number
      imageUrl?: string | null
      rewardVariant?: string
    }
    nudgeMessage?: string
  } | null>(null)
  const [isValidatingCoupon, setIsValidatingCoupon] = useState(false)

  const {
    storeSettingsMap,
    storeLat,
    storeLng,
    taxRate,
    miscFee,
    groceryThreshold,
    cafeThreshold,
    combinedThreshold,
    deliveryFeeVal,
  } = settings

  const cartHash = useMemo(
    () => items.map((i) => `${i.product.id}:${i.quantity}:${i.product.price}`).join('|'),
    [items]
  )

  // Auto-validate coupon on checkout page load
  useEffect(() => {
    if (appliedCouponCode && items.length > 0) {
      // Immediate client-side check: If BOGO offer is applied, ensure cart still has enough qualifying items
      if (appliedCoupon?.discountType === 'BOGO') {
        const qualifying = items.filter((it) => isProductEligibleForCoupon(it.product, appliedCoupon))
        const qQty = qualifying.reduce((sum, it) => sum + (it.quantity || 1), 0)
        if (appliedCoupon.bogoType === 'CHEAPEST_FREE' && qQty < 2) {
          useCartStore.getState().setAppliedCouponCode(null)
          setAppliedCoupon(null)
          return
        }
        if (appliedCoupon.bogoType === 'SAME_ITEM' && !qualifying.some((it) => (it.quantity || 1) >= 2)) {
          useCartStore.getState().setAppliedCouponCode(null)
          setAppliedCoupon(null)
          return
        }
      }

      setIsValidatingCoupon(true)
      fetch('/api/coupons/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: appliedCouponCode,
          subtotal,
          items: items.map((i) => ({
            id: i.product.id,
            productId: i.product.id,
            name: i.product.name,
            price: i.product.price,
            categoryId: i.product.category?.id || (i.product as any).categoryId,
            restaurantId: i.product.restaurantId || (i.product.restaurant as any)?.id || (i.product as any).restaurant_id || null,
            menuSection: (i.product as any).menuSection || null,
            tags: i.product.tags || [],
            quantity: i.quantity,
            selectedVariant: (i.product as any).selectedVariant || (i as any).selectedVariant || i.product.unit || null,
            variant: (i.product as any).variant || (i as any).variant || i.product.unit || null,
            unit: i.product.unit || null,
          })),
        }),
      })
        .then((res) => {
          if (res.ok) return res.json()
          throw new Error('Invalid')
        })
        .then((data) => {
          if (data?.coupon && (data.coupon.discountAmount > 0 || data.coupon.nudgeMessage)) {
            setAppliedCoupon({
              code: data.coupon.code,
              discountAmount: data.coupon.discountAmount,
              discountType: data.coupon.discountType,
              bogoType: data.coupon.bogoType,
              badgeText: data.coupon.badgeText,
              freeGiftDetails: data.coupon.freeGiftDetails,
              nudgeMessage: data.coupon.nudgeMessage,
            })
          } else {
            useCartStore.getState().setAppliedCouponCode(null)
            setAppliedCoupon(null)
          }
        })
        .catch(() => {
          useCartStore.getState().setAppliedCouponCode(null)
          setAppliedCoupon(null)
        })
        .finally(() => {
          setIsValidatingCoupon(false)
        })
    } else {
      setAppliedCoupon(null)
    }
  }, [appliedCouponCode, cartHash, subtotal])

  const b2bDiscount = 0
  const adjustedSubtotal = subtotal - b2bDiscount
  const discount = savings + b2bDiscount

  const cafeCartItems = items.filter((item) => isCafeProduct(item.product))
  const groceryCartItems = items.filter((item) => !isCafeProduct(item.product))
  const hasCafeItems = cafeCartItems.length > 0
  const hasGroceryItems = groceryCartItems.length > 0

  // Grocery Calculations
  const grocerySubtotal = groceryCartItems.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  )
  const groceryMrpSubtotal = groceryCartItems.reduce(
    (sum, item) => sum + item.product.mrp * item.quantity,
    0
  )
  const grocerySavings = groceryMrpSubtotal - grocerySubtotal
  const groceryB2BDiscount = 0
  const groceryAdjustedSubtotal = grocerySubtotal - groceryB2BDiscount
  const groceryTaxes = groceryAdjustedSubtotal * taxRate

  // Cafe Calculations
  const cafeSubtotal = cafeCartItems.reduce(
    (sum, item) => sum + item.product.price * item.quantity,
    0
  )
  const cafeMrpSubtotal = cafeCartItems.reduce(
    (sum, item) => sum + item.product.mrp * item.quantity,
    0
  )
  const cafeSavings = cafeMrpSubtotal - cafeSubtotal
  const cafeB2BDiscount = 0
  const cafeAdjustedSubtotal = cafeSubtotal - cafeB2BDiscount
  const cafeTaxes = cafeAdjustedSubtotal * taxRate

  // Identify restaurant partner if cafe / restaurant items are present
  const primaryRestaurantItem =
    cafeCartItems.find((i) => i.product.restaurant || i.product.restaurantId) || cafeCartItems[0]
  const restaurantLocation = primaryRestaurantItem
    ? getRestaurantLocation(primaryRestaurantItem.product, storeLat, storeLng)
    : null

  const isPureRestaurant = hasCafeItems && !hasGroceryItems
  const isCombinedOrder = hasCafeItems && hasGroceryItems

  const defaultDarkStoreRadius = parseFloat(
    storeSettingsMap['delivery_radius'] || storeSettingsMap['max_delivery_radius'] || '5.0'
  )

  const originLat = isPureRestaurant
    ? (restaurantLocation?.lat ?? storeLat)
    : storeLat
  const originLng = isPureRestaurant
    ? (restaurantLocation?.lng ?? storeLng)
    : storeLng
  const originName = isPureRestaurant
    ? (restaurantLocation?.name || 'Restaurant')
    : (storeSettingsMap['store_name'] || 'FastKirana Dark Store')
  const originMaxRadiusKm = isPureRestaurant
    ? (restaurantLocation?.deliveryRadiusKm ?? 5.0)
    : defaultDarkStoreRadius

  // Calculate distance-based delivery rules if address has coords
  let distanceKm: number | null = null
  let groceryDistanceKm: number | null = null
  let restaurantDistanceKm: number | null = null
  let deliveryRules: any = null

  if (deliveryMethod === 'DELIVERY' && selectedAddress) {
    if (selectedAddress.lat && selectedAddress.lng) {
      const surgeFee = parseFloat(
        storeSettingsMap['surge_charge'] || storeSettingsMap['surge_fee'] || '0'
      )
      const surgeReason =
        storeSettingsMap['surge_reason'] || (surgeFee > 0 ? 'Special Delivery Surge' : '')

      if (isPureRestaurant) {
        distanceKm = getDistanceKm(originLat, originLng, selectedAddress.lat, selectedAddress.lng)
        deliveryRules = getDeliveryRules(distanceKm, {
          maxRadiusKm: originMaxRadiusKm,
          surgeFee,
          surgeReason,
          settings: storeSettingsMap,
          storeName: originName,
        })
      } else if (isCombinedOrder && restaurantLocation) {
        groceryDistanceKm = getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng)
        restaurantDistanceKm = getDistanceKm(restaurantLocation.lat, restaurantLocation.lng, selectedAddress.lat, selectedAddress.lng)
        // In combined order, fee is based on the darkstore leg, but both legs must be serviceable
        distanceKm = Math.max(groceryDistanceKm, restaurantDistanceKm)
        const groceryRules = getDeliveryRules(groceryDistanceKm, {
          maxRadiusKm: defaultDarkStoreRadius,
          surgeFee,
          surgeReason,
          settings: storeSettingsMap,
          storeName: storeSettingsMap['store_name'],
        })
        const restRules = getDeliveryRules(restaurantDistanceKm, {
          maxRadiusKm: restaurantLocation.deliveryRadiusKm,
          surgeFee,
          surgeReason,
          settings: storeSettingsMap,
          storeName: restaurantLocation.name,
        })

        if (!restRules.isServiceable) {
          deliveryRules = restRules
        } else {
          deliveryRules = groceryRules
        }
      } else {
        distanceKm = getDistanceKm(storeLat, storeLng, selectedAddress.lat, selectedAddress.lng)
        deliveryRules = getDeliveryRules(distanceKm, {
          maxRadiusKm: originMaxRadiusKm,
          surgeFee,
          surgeReason,
          settings: storeSettingsMap,
          storeName: originName,
        })
      }
    }
  }

  let groceryDeliveryFee = 0
  let cafeDeliveryFee = 0

  if (deliveryMethod === 'DELIVERY') {
    const activeThreshold =
      deliveryRules && deliveryRules.isServiceable
        ? deliveryRules.freeDeliveryThreshold
        : parseFloat(storeSettingsMap['delivery_threshold_tier1'] || storeSettingsMap['grocery_free_delivery_threshold'] || '149')

    const feeToCharge =
      deliveryRules && deliveryRules.isServiceable ? deliveryRules.deliveryFee : deliveryFeeVal

    if (adjustedSubtotal < activeThreshold) {
      if (groceryCartItems.length > 0) {
        groceryDeliveryFee = feeToCharge
      } else if (cafeCartItems.length > 0) {
        cafeDeliveryFee = feeToCharge
      }
    }
  }

  const isPremiumPackagingSelected =
    (hasCafeItems || cafeCartItems.length > 0) && packagingOption === 'PREMIUM'
  const packagingFee = isPremiumPackagingSelected ? 15 : 0

  const groceryChargedMisc =
    groceryCartItems.length > 0 && deliveryMethod !== 'PICKUP' && !isPremiumPackagingSelected
  const effectiveGroceryMiscFee = groceryChargedMisc ? miscFee : 0
  const cafeChargedMisc =
    cafeCartItems.length > 0 && !groceryChargedMisc && !isPremiumPackagingSelected
  const effectiveCafeMiscFee = cafeChargedMisc ? miscFee : 0
  const effectiveMiscFee = effectiveGroceryMiscFee + effectiveCafeMiscFee

  const couponDiscount = appliedCoupon ? appliedCoupon.discountAmount : 0
  const deliveryFee = groceryDeliveryFee + cafeDeliveryFee
  const appliedSurgeFee =
    deliveryFee > 0 && deliveryRules && deliveryRules.isServiceable
      ? deliveryRules.surgeFee || 0
      : 0
  const baseDeliveryFee = Math.max(0, deliveryFee - appliedSurgeFee)
  const taxes = Math.max(0, adjustedSubtotal - couponDiscount) * taxRate
  const grandTotal =
    Math.max(0, adjustedSubtotal - couponDiscount) +
    deliveryFee +
    taxes +
    effectiveMiscFee +
    packagingFee

  return {
    appliedCoupon,
    isValidatingCoupon,
    mrpTotal,
    savings,
    discount,
    adjustedSubtotal,
    cafeCartItems,
    groceryCartItems,
    hasCafeItems,
    hasGroceryItems,
    grocerySubtotal,
    groceryMrpSubtotal,
    grocerySavings,
    groceryB2BDiscount,
    groceryAdjustedSubtotal,
    groceryTaxes,
    cafeSubtotal,
    cafeMrpSubtotal,
    cafeSavings,
    cafeB2BDiscount,
    cafeAdjustedSubtotal,
    cafeTaxes,
    distanceKm,
    deliveryRules,
    originName,
    originLat,
    originLng,
    originMaxRadiusKm,
    isPureRestaurant,
    isCombinedOrder,
    restaurantDistanceKm,
    groceryDistanceKm,
    groceryDeliveryFee,
    cafeDeliveryFee,
    deliveryFee,
    baseDeliveryFee,
    appliedSurgeFee,
    packagingFee,
    isPremiumPackagingSelected,
    effectiveMiscFee,
    couponDiscount,
    taxes,
    grandTotal,
  }
}
