import { getDistanceKm, getDeliveryRules } from '@/lib/distance'
import { evaluateSurgeStatus } from '@/lib/surge-manager'
import {
  DELIVERY_FEE,
  GROCERY_FREE_DELIVERY_THRESHOLD,
  COMBINED_FREE_DELIVERY_THRESHOLD,
} from '@/lib/constants'

export interface RestaurantDeliveryInput {
  rId: string
  restaurant: any
  items: any[]
  subtotal: number
  deliveryFee: number
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
  targetDarkStore?: any | null
  settingsMap: Record<string, string>
  groceryItems: any[]
  grocerySubtotal: number
  restaurantData: RestaurantDeliveryInput[]
  combinedSubtotal: number
}

export interface DeliveryCalculationResult {
  error?: string
  groceryDeliveryFee: number
  hubSurgeFee: number
  hubSurgeReason: string
  restaurantFees: Record<string, number>
}

/**
 * Calculates delivery fees across Grocery Darkstore and Restaurant outlets,
 * enforcing geofencing, distance limits, hub surge fees, and free delivery thresholds.
 */
export async function calculateOrderDeliveryFees(
  params: DeliveryCalculationParams
): Promise<DeliveryCalculationResult> {
  const {
    deliveryMethod,
    isB2B,
    resolvedLat,
    resolvedLng,
    storeLat,
    storeLng,
    maxRadiusKm,
    storeDisplayName,
    targetDarkStore,
    settingsMap,
    groceryItems,
    grocerySubtotal,
    restaurantData,
    combinedSubtotal,
  } = params

  const deliveryFeeVal = settingsMap['delivery_fee']
    ? parseFloat(settingsMap['delivery_fee'])
    : DELIVERY_FEE

  let groceryDeliveryFee = 0
  let hubSurgeFee = 0
  let hubSurgeReason = ''
  const restaurantFees: Record<string, number> = {}

  // Initialize all restaurants with 0
  for (const rData of restaurantData) {
    restaurantFees[rData.rId] = 0
  }

  if (deliveryMethod === 'DELIVERY' && !isB2B) {
    // 1. Evaluate active surge for target DarkStore hub
    try {
      const activeSurge = await evaluateSurgeStatus(
        settingsMap,
        targetDarkStore?.id,
        targetDarkStore ? { lat: targetDarkStore.latitude, lng: targetDarkStore.longitude } : null
      )
      if (activeSurge.isSurgeActive && activeSurge.surgeFee > 0) {
        hubSurgeFee = activeSurge.surgeFee
        hubSurgeReason = activeSurge.surgeReason || 'Safety & Weather Surge'
      }
    } catch (surgeErr) {
      console.error('Failed to evaluate hub surge fee:', surgeErr)
    }

    // 2. Evaluate combined order threshold
    const isCombinedOrder = groceryItems.length > 0 && restaurantData.length > 0
    const combinedThreshold = settingsMap['combined_free_delivery_threshold']
      ? parseFloat(settingsMap['combined_free_delivery_threshold'])
      : (settingsMap['grocery_free_delivery_threshold']
        ? parseFloat(settingsMap['grocery_free_delivery_threshold'])
        : COMBINED_FREE_DELIVERY_THRESHOLD)

    // In a combined order, if the combined cart reaches threshold, delivery is FREE for all parts!
    const isCombinedFree = isCombinedOrder && (combinedSubtotal >= combinedThreshold)

    // 3. Process Grocery Items Delivery Fee & Validation from DarkStore Hub
    if (groceryItems.length > 0) {
      const defaultThreshold = settingsMap['grocery_free_delivery_threshold']
        ? parseFloat(settingsMap['grocery_free_delivery_threshold'])
        : GROCERY_FREE_DELIVERY_THRESHOLD

      if (resolvedLat && resolvedLng) {
        const groceryDistKm = getDistanceKm(storeLat, storeLng, resolvedLat, resolvedLng)
        const groceryRules = getDeliveryRules(groceryDistKm, { maxRadiusKm, surgeFee: hubSurgeFee, settings: settingsMap, storeName: storeDisplayName })

        if (!groceryRules.isServiceable || groceryDistKm > maxRadiusKm) {
          return {
            error: `Your delivery address is ${groceryDistKm.toFixed(1)} km away. Grocery delivery is strictly limited to ${maxRadiusKm.toFixed(1)} km from ${storeDisplayName}.`,
            groceryDeliveryFee: 0,
            hubSurgeFee,
            hubSurgeReason,
            restaurantFees,
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

    // 4. Process EACH Restaurant's Delivery Fee & Validation based on THAT restaurant's GPS location
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
        const rRules = getDeliveryRules(rDistKm, { maxRadiusKm: rMaxRadius, surgeFee: hubSurgeFee, settings: settingsMap, storeName: rName })

        if (!rRules.isServiceable || rDistKm > rMaxRadius) {
          return {
            error: `Your delivery address is ${rDistKm.toFixed(1)} km away from ${rName}. Delivery from this restaurant is strictly limited to ${rMaxRadius.toFixed(1)} km.`,
            groceryDeliveryFee,
            hubSurgeFee,
            hubSurgeReason,
            restaurantFees,
          }
        }

        if (isCombinedFree || rData.subtotal >= rRules.freeDeliveryThreshold || combinedSubtotal >= rRules.freeDeliveryThreshold) {
          restaurantFees[rData.rId] = 0
        } else {
          restaurantFees[rData.rId] = rRules.deliveryFee
        }
      } else {
        // Fallback if restaurant has no GPS coordinates saved
        if (isCombinedFree || rData.subtotal >= rDefaultThreshold || combinedSubtotal >= rDefaultThreshold) {
          restaurantFees[rData.rId] = 0
        } else {
          restaurantFees[rData.rId] = deliveryFeeVal + hubSurgeFee
        }
      }
    }

    // Single delivery fee rule for combined order under threshold:
    // If grocery has already been charged a delivery fee, waive delivery fee on the restaurant portion so customer is never double-charged
    if (isCombinedOrder && !isCombinedFree) {
      if (groceryDeliveryFee > 0) {
        for (const rData of restaurantData) {
          restaurantFees[rData.rId] = 0
        }
      }
    }
  }

  return {
    groceryDeliveryFee,
    hubSurgeFee,
    hubSurgeReason,
    restaurantFees,
  }
}
