import { DELIVERY_FEE } from '@/lib/constants'
import { getDistanceKm, getDeliveryRules } from '@/lib/distance'

export interface PricingItem {
  product: { id: string; name?: string; price?: number }
  dbProduct: any
  quantity: number
  selectedVariant?: string
}

export interface CouponDiscountResult {
  couponId: string | null
  combinedDiscount: number
  meetsMinOrder: boolean
}

export function calculateItemSubtotal(itemList: PricingItem[]): number {
  return itemList.reduce((sum, item) => {
    const isVariant = item.product.id.includes('_')
    const [_, variantNameFromId] = isVariant ? item.product.id.split('_') : [item.product.id, null]
    const variantName = item.selectedVariant || variantNameFromId
    let itemPrice = Number(item.dbProduct.price || 0)

    if (isVariant && item.dbProduct.variants && Array.isArray(item.dbProduct.variants)) {
      const variant = (item.dbProduct.variants as any[]).find((v) => v.name === variantName)
      if (variant && variant.price != null) {
        itemPrice = Number(variant.price)
      }
    }
    return sum + (itemPrice * item.quantity)
  }, 0)
}

export function calculateCouponDiscount(
  coupon: any,
  combinedSubtotal: number,
  grocerySubtotal: number,
  restaurantSubtotal: number
): CouponDiscountResult {
  if (!coupon || !coupon.isActive) {
    return { couponId: null, combinedDiscount: 0, meetsMinOrder: false }
  }

  let meetsMinOrder = true
  let eligibleSubtotal = combinedSubtotal

  if (coupon.applicableType === 'GROCERY') {
    if (grocerySubtotal < coupon.minOrder) meetsMinOrder = false
    eligibleSubtotal = grocerySubtotal
  } else if (coupon.applicableType === 'RESTAURANT') {
    if (restaurantSubtotal < coupon.minOrder) meetsMinOrder = false
    eligibleSubtotal = restaurantSubtotal
  } else {
    if (combinedSubtotal < coupon.minOrder) meetsMinOrder = false
  }

  if (!meetsMinOrder || eligibleSubtotal <= 0) {
    return { couponId: coupon.id, combinedDiscount: 0, meetsMinOrder: false }
  }

  let combinedDiscount = 0
  if (coupon.discountType === 'FLAT') {
    combinedDiscount = Math.min(Number(coupon.value || 0), eligibleSubtotal)
  } else if (coupon.discountType === 'PERCENT') {
    combinedDiscount = (eligibleSubtotal * Number(coupon.value || 0)) / 100
    if (coupon.maxDiscount) {
      combinedDiscount = Math.min(combinedDiscount, Number(coupon.maxDiscount))
    }
  }

  return {
    couponId: coupon.id,
    combinedDiscount: Math.max(0, combinedDiscount),
    meetsMinOrder: true
  }
}

export interface DeliveryCalculationParams {
  deliveryMethod: string
  isB2B: boolean
  resolvedLat: number | null
  resolvedLng: number | null
  storeLat: number
  storeLng: number
  maxRadiusKm: number
  storeDisplayName: string
  deliveryFeeVal: number
  hubSurgeFee: number
  groceryItems: any[]
  grocerySubtotal: number
  restaurantData: any[]
  combinedSubtotal: number
  combinedThreshold: number
  settingsMap: Record<string, string>
}

export interface DeliveryCalculationResult {
  error?: string
  groceryDeliveryFee: number
  restaurantData: any[]
}

export function calculateDeliveryFees(params: DeliveryCalculationParams): DeliveryCalculationResult {
  const {
    deliveryMethod,
    isB2B,
    resolvedLat,
    resolvedLng,
    storeLat,
    storeLng,
    maxRadiusKm,
    storeDisplayName,
    deliveryFeeVal,
    hubSurgeFee,
    groceryItems,
    grocerySubtotal,
    restaurantData,
    combinedSubtotal,
    combinedThreshold,
    settingsMap
  } = params

  let groceryDeliveryFee = 0

  if (deliveryMethod === 'DELIVERY' && !isB2B) {
    const isCombinedOrder = groceryItems.length > 0 && restaurantData.length > 0
    const isCombinedFree = isCombinedOrder && (combinedSubtotal >= combinedThreshold)

    // 1. Grocery Delivery Fee
    if (groceryItems.length > 0) {
      const defaultThreshold = settingsMap['grocery_free_delivery_threshold']
        ? parseFloat(settingsMap['grocery_free_delivery_threshold'])
        : 199

      if (resolvedLat && resolvedLng) {
        const groceryDistKm = getDistanceKm(storeLat, storeLng, resolvedLat, resolvedLng)
        const groceryRules = getDeliveryRules(groceryDistKm, { maxRadiusKm, surgeFee: hubSurgeFee })

        if (!groceryRules.isServiceable || groceryDistKm > maxRadiusKm) {
          return {
            error: `Your delivery address is ${groceryDistKm.toFixed(1)} km away. Grocery delivery is strictly limited to ${maxRadiusKm.toFixed(1)} km from ${storeDisplayName}.`,
            groceryDeliveryFee: 0,
            restaurantData
          }
        }

        if (isCombinedFree || grocerySubtotal >= groceryRules.freeDeliveryThreshold || combinedSubtotal >= groceryRules.freeDeliveryThreshold) {
          groceryDeliveryFee = 0
        } else {
          groceryDeliveryFee = groceryRules.deliveryFee
        }
      } else {
        groceryDeliveryFee = ((isCombinedFree || grocerySubtotal >= defaultThreshold || combinedSubtotal >= defaultThreshold) ? 0 : deliveryFeeVal) + hubSurgeFee
      }
    }

    // 2. Restaurant Delivery Fee
    for (const rData of restaurantData) {
      const r = rData.restaurant
      const rLat = r?.lat ?? (r?.latitude ? parseFloat(String(r.latitude)) : null)
      const rLng = r?.lng ?? (r?.longitude ? parseFloat(String(r.longitude)) : null)
      const rMaxRadius = r?.deliveryRadiusKm ? parseFloat(String(r.deliveryRadiusKm)) : 5.0
      const rName = r?.name || 'Restaurant'

      const rDefaultThreshold = settingsMap['restaurant_free_delivery_threshold']
        ? parseFloat(settingsMap['restaurant_free_delivery_threshold'])
        : (settingsMap['combined_free_delivery_threshold'] ? parseFloat(settingsMap['combined_free_delivery_threshold']) : 200)

      if (resolvedLat && resolvedLng && rLat && rLng) {
        const rDistKm = getDistanceKm(rLat, rLng, resolvedLat, resolvedLng)
        const rRules = getDeliveryRules(rDistKm, { maxRadiusKm: rMaxRadius, surgeFee: hubSurgeFee })

        if (!rRules.isServiceable || rDistKm > rMaxRadius) {
          return {
            error: `Your delivery address is ${rDistKm.toFixed(1)} km away from ${rName}. Delivery from this restaurant is strictly limited to ${rMaxRadius.toFixed(1)} km.`,
            groceryDeliveryFee,
            restaurantData
          }
        }

        if (isCombinedFree || rData.subtotal >= rRules.freeDeliveryThreshold || combinedSubtotal >= rRules.freeDeliveryThreshold) {
          rData.deliveryFee = 0
        } else {
          rData.deliveryFee = rRules.deliveryFee
        }
      } else {
        if (isCombinedFree || rData.subtotal >= rDefaultThreshold || combinedSubtotal >= rDefaultThreshold) {
          rData.deliveryFee = 0
        } else {
          rData.deliveryFee = deliveryFeeVal + hubSurgeFee
        }
      }
    }

    // Single delivery fee waiver on restaurant if grocery already paid
    if (isCombinedOrder && !isCombinedFree) {
      if (groceryDeliveryFee > 0) {
        for (const rData of restaurantData) {
          rData.deliveryFee = 0
        }
      }
    }
  }

  return {
    groceryDeliveryFee,
    restaurantData
  }
}
