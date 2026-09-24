'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import type { CartItem } from '@/stores/cart-store'
import { Address } from '@/types'
import {
  validateCheckoutEligibility,
  buildOrderPayload,
  DEFAULT_STORE_LAT,
  DEFAULT_STORE_LNG,
  DEFAULT_DELIVERY_RADIUS_KM,
  type SettingsMap,
} from '@/lib/checkout'
import { getDistanceKm } from '@/lib/distance'
import { isCafeProduct } from '@/lib/utils'
import { getRestaurantLocation } from '@/lib/restaurant-location'
import { AddressFormData } from './use-checkout-address'

export interface UseCheckoutPaymentProps {
  items: CartItem[]
  addresses: Address[]
  selectedAddressId: string
  selectedAddress?: Address
  deliveryMethod?: 'DELIVERY' | 'PICKUP'
  scheduledSlot?: string
  appliedCouponCode: string | null
  contactPhone: string
  packagingOption: 'NORMAL' | 'PREMIUM'
  packagingFee: number
  storeSettingsMap: Record<string, string>
  onlyCod: boolean
  deliveryRules: any
  distanceKm: number | null
  orderForSomeone: boolean
  recipientName: string
  recipientPhone: string
  cookingInstruction: string
  addressForm: AddressFormData
  showNewAddressForm: boolean
  setShowNewAddressForm: (val: boolean) => void
  setEditingAddressId: (val: string | null) => void
  setSelectedAddressId: (val: string) => void
  activeCheckoutAddressRef: React.MutableRefObject<{ id: string; addresses: Address[] } | null>
  saveAddressCore: () => Promise<{ savedAddress: Address; newAddresses: Address[] } | null>
  isSavingAddress: boolean
  clearCart: () => void
}

export function useCheckoutPayment({
  items,
  addresses,
  selectedAddressId,
  selectedAddress,
  deliveryMethod = 'DELIVERY',
  scheduledSlot = 'INSTANT',
  appliedCouponCode,
  contactPhone,
  packagingOption,
  packagingFee,
  storeSettingsMap,
  onlyCod,
  deliveryRules,
  distanceKm,
  orderForSomeone,
  recipientName,
  recipientPhone,
  cookingInstruction,
  addressForm,
  showNewAddressForm,
  setShowNewAddressForm,
  setEditingAddressId,
  setSelectedAddressId,
  activeCheckoutAddressRef,
  saveAddressCore,
  isSavingAddress,
  clearCart,
}: UseCheckoutPaymentProps) {
  const router = useRouter()
  const { data: session } = useSession()

  const [paymentMethod, setPaymentMethod] = useState<'COD' | 'UPI' | 'CARD' | 'WALLET'>('COD')
  const [isPaymentModalOpen, setIsPaymentModalOpen] = useState(false)
  const [isPlacingOrder, setIsPlacingOrder] = useState(false)
  const [activePendingOrderId, setActivePendingOrderId] = useState<string | null>(null)
  const [failedPaymentOrder, setFailedPaymentOrder] = useState<{
    id: string
    readableId?: string
    totalAmount: number
  } | null>(null)

  // Preload Payment SDKs
  const loadCashfreeScript = (): Promise<boolean> => {
    return new Promise((resolve) => {
      if ((window as any).Cashfree) {
        resolve(true)
        return
      }
      const script = document.createElement('script')
      script.src = 'https://sdk.cashfree.com/js/v3/cashfree.js'
      script.onload = () => resolve(true)
      script.onerror = () => resolve(false)
      document.body.appendChild(script)
    })
  }

  useEffect(() => {
    loadCashfreeScript()
  }, [])

  const getOrderNotes = () => {
    const cleanP = recipientPhone.replace(/\D/g, '')
    const orderForNote =
      orderForSomeone && recipientName.trim()
        ? `🎁 Order for: ${recipientName.trim()}${cleanP ? ` (${cleanP})` : ''}`
        : ''
    return [orderForNote, cookingInstruction.trim()].filter(Boolean).join(' | ') || undefined
  }

  const getEffectiveCustomerPhone = (activeSelectedAddress?: Address) => {
    const cleanP = recipientPhone.replace(/\D/g, '')
    if (orderForSomeone && cleanP.length === 10) {
      return cleanP
    }
    return activeSelectedAddress?.phone || addressForm.phone || (session?.user as any)?.phone || ''
  }

  const handlePlaceOrder = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[]
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress =
      activeAddresses.find((a) => a.id === activeAddressId) || selectedAddress

    setIsPlacingOrder(true)
    try {
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map((i) => ({ product: i.product as CartItem['product'] })),
        addresses: activeAddresses,
        selectedAddressId: activeAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        customerPhone: effectiveCustomerPhone,
        contactPhone,
        packagingOption,
        packagingFee,
        userId: session?.user?.id || undefined,
        userPhone: (session?.user as any)?.phone || undefined,
        isOrderForSomeone: Boolean(orderForSomeone),
        receiverName: orderForSomeone ? recipientName.trim() : undefined,
        receiverPhone: orderForSomeone ? recipientPhone.replace(/\D/g, '') : undefined,
      })

      const res = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        triggerHaptic('success')
        toast.success('Order placed successfully! Redirecting to tracking...')
        clearCart()
        router.push(`/order/${data.id}/success`)
      } else {
        toast.error(data.error || 'Failed to place order')
      }
    } catch (err) {
      toast.error('Connection error. Please try again.')
    } finally {
      setIsPlacingOrder(false)
    }
  }

  const handleCashfreeCheckout = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[]
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress =
      activeAddresses.find((a) => a.id === activeAddressId) || selectedAddress

    setIsPlacingOrder(true)
    try {
      const settingsRes = await fetch('/api/settings', { cache: 'no-store' })
      const settings: SettingsMap = await settingsRes.json()

      const validation = await validateCheckoutEligibility({
        items: items.map((i) => ({ product: i.product as CartItem['product'] })),
        addresses: activeAddresses,
        selectedAddressId: activeAddressId,
        deliveryMethod,
        settings,
      })

      if (!validation.valid) {
        triggerHaptic('warning')
        toast.error(validation.error!)
        setIsPlacingOrder(false)
        return
      }

      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      const payload = buildOrderPayload({
        finalAddressId: validation.finalAddressId!,
        paymentMethod: selectedMethod,
        items,
        deliveryMethod,
        scheduledSlot,
        appliedCouponCode,
        customerPhone: effectiveCustomerPhone,
        contactPhone,
        packagingOption,
        packagingFee,
        userId: session?.user?.id || undefined,
        userPhone: (session?.user as any)?.phone || undefined,
        isOrderForSomeone: Boolean(orderForSomeone),
        receiverName: orderForSomeone ? recipientName.trim() : undefined,
        receiverPhone: orderForSomeone ? recipientPhone.replace(/\D/g, '') : undefined,
      })

      const orderRes = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes,
        }),
      })

      const orderData = await orderRes.json()

      if (!orderRes.ok) {
        toast.error(orderData.error || 'Failed to initialize order')
        setIsPlacingOrder(false)
        return
      }

      // 100% Free order edge case: auto-confirmed on server
      if (orderData.paymentStatus === 'PAID' || Number(orderData.total || 0) <= 0) {
        clearCart()
        triggerHaptic('success')
        toast.success('🎉 Order placed successfully! (100% Free Promo)')
        window.location.href = `/order/${orderData.id}/success`
        return
      }

      setActivePendingOrderId(orderData.id)

      const cfRes = await fetch('/api/payment/cashfree/create-order', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderId: orderData.id }),
      })

      const cfData = await cfRes.json()

      if (!cfRes.ok || !cfData.paymentSessionId) {
        console.warn('Cashfree session failed:', cfData.error)
        toast.error(cfData.error || 'Cashfree payment session could not be created.')
        setIsPlacingOrder(false)
        setFailedPaymentOrder({
          id: orderData.id,
          readableId: orderData.readableId,
          totalAmount: Number(orderData.total || 0),
        })
        return
      }

      const loaded = await loadCashfreeScript()
      if (!loaded || !(window as any).Cashfree) {
        console.warn('Cashfree SDK failed to load')
        toast.error('Payment gateway SDK failed to load.')
        setIsPlacingOrder(false)
        setFailedPaymentOrder({
          id: orderData.id,
          readableId: orderData.readableId,
          totalAmount: Number(orderData.total || 0),
        })
        return
      }

      const cashfree = (window as any).Cashfree({
        mode: process.env.NEXT_PUBLIC_CASHFREE_ENV === 'SANDBOX' ? 'sandbox' : 'production',
      })

      let paymentSuccess = false

      let pollCount = 0
      const checkVerification = async () => {
        if (paymentSuccess) return true
        try {
          const verifyRes = await fetch('/api/payment/cashfree/verify', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId: orderData.id, cfOrderId: cfData.orderId }),
          })
          const verifyData = await verifyRes.json()
          if (verifyRes.ok && verifyData.paymentStatus === 'PAID') {
            paymentSuccess = true
            clearInterval(pollTimer)
            document.removeEventListener('visibilitychange', handleVisibilityChange)
            clearCart()
            triggerHaptic('success')
            toast.success('🎉 Payment Verified Successfully!')
            window.location.href = `/order/${orderData.id}/success`
            return true
          }
        } catch (_) {}
        return false
      }

      const pollTimer = setInterval(async () => {
        pollCount++
        if (pollCount > 100 || paymentSuccess) {
          clearInterval(pollTimer)
          return
        }
        await checkVerification()
      }, 2500)

      const handleVisibilityChange = async () => {
        if (document.visibilityState === 'visible') {
          await checkVerification()
        }
      }
      document.addEventListener('visibilitychange', handleVisibilityChange)

      try {
        const result = await cashfree.checkout({
          paymentSessionId: cfData.paymentSessionId,
          redirectTarget: '_modal',
        })

        const isVerified = await checkVerification()
        if (!isVerified && !paymentSuccess) {
          clearInterval(pollTimer)
          document.removeEventListener('visibilitychange', handleVisibilityChange)
          setIsPlacingOrder(false)
          if (result?.error) {
            console.log('Cashfree modal closed with note:', result.error)
          }
          triggerHaptic('warning')
          // Trigger the 1-min Fallback Modal to either Cancel or Convert to COD!
          setFailedPaymentOrder({
            id: orderData.id,
            readableId: orderData.readableId,
            totalAmount: Number(orderData.total || 0),
          })
        }
      } catch (checkoutErr) {
        console.warn('Cashfree checkout modal error:', checkoutErr)
        const isVerified = await checkVerification()
        if (!isVerified && !paymentSuccess) {
          clearInterval(pollTimer)
          document.removeEventListener('visibilitychange', handleVisibilityChange)
          setIsPlacingOrder(false)
          setFailedPaymentOrder({
            id: orderData.id,
            readableId: orderData.readableId,
            totalAmount: Number(orderData.total || 0),
          })
        }
      }
    } catch (err) {
      console.error('Error during Cashfree checkout:', err)
      toast.error('An unexpected error occurred during checkout.')
      setIsPlacingOrder(false)
    }
  }

  const handlePlaceOrderClick = async () => {
    if (isPlacingOrder || isSavingAddress) return

    let effectiveAddressId = selectedAddressId
    let effectiveAddresses = addresses

    if (showNewAddressForm) {
      const hasEnteredStreet = addressForm.street && addressForm.street.trim().length > 0
      if (hasEnteredStreet) {
        const result = await saveAddressCore()
        if (!result) {
          const el = document.getElementById('new-address-form')
          if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
          return
        }
        effectiveAddressId = result.savedAddress.id
        effectiveAddresses = result.newAddresses
      } else if (addresses.length > 0) {
        setShowNewAddressForm(false)
        setEditingAddressId(null)
        effectiveAddressId = selectedAddressId || addresses[0].id
        setSelectedAddressId(effectiveAddressId)
      } else {
        triggerHaptic('warning')
        toast.error('Please enter your delivery address')
        const el = document.getElementById('new-address-form')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
    }

    activeCheckoutAddressRef.current = { id: effectiveAddressId, addresses: effectiveAddresses }

    if (deliveryMethod === 'DELIVERY') {
      const targetId =
        effectiveAddressId || (effectiveAddresses.length > 0 ? effectiveAddresses[0].id : '')
      if (!targetId) {
        triggerHaptic('warning')
        toast.error('Please select or add a delivery address')
        const el = document.getElementById('address-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }

      const activeAddress = effectiveAddresses.find((a) => a.id === targetId)

      if (deliveryRules && !deliveryRules.isServiceable) {
        triggerHaptic('warning')
        toast.error(
          deliveryRules.reason ||
          `Your address is outside our delivery zone (${distanceKm?.toFixed(1) || ''} km away).`
        )
        return
      }

      if (
        activeAddress &&
        activeAddress.lat &&
        activeAddress.lng &&
        storeSettingsMap.store_lat &&
        storeSettingsMap.store_lng
      ) {
        const storeLatVal = parseFloat(storeSettingsMap.store_lat) || DEFAULT_STORE_LAT
        const storeLngVal = parseFloat(storeSettingsMap.store_lng) || DEFAULT_STORE_LNG
        const hasGrocery = items.some((i) => !isCafeProduct(i.product))
        const hasRest = items.some((i) => isCafeProduct(i.product))

        if (hasGrocery) {
          const maxDist = parseFloat(
            storeSettingsMap.delivery_radius || String(DEFAULT_DELIVERY_RADIUS_KM)
          )
          const dist = getDistanceKm(storeLatVal, storeLngVal, activeAddress.lat, activeAddress.lng)
          if (dist > maxDist) {
            triggerHaptic('warning')
            toast.error(
              `Your address is outside our grocery delivery zone (${dist.toFixed(1)} km away). We deliver only up to ${maxDist} km.`
            )
            return
          }
        }

        if (hasRest) {
          const firstRestItem = items.find((i) => isCafeProduct(i.product))
          const restLoc = getRestaurantLocation(firstRestItem?.product, storeLatVal, storeLngVal)
          if (restLoc) {
            const rDist = getDistanceKm(restLoc.lat, restLoc.lng, activeAddress.lat, activeAddress.lng)
            if (rDist > restLoc.deliveryRadiusKm) {
              triggerHaptic('warning')
              toast.error(
                `Your address is outside ${restLoc.name}'s delivery zone (${rDist.toFixed(1)} km away). Delivery from this restaurant is limited to ${restLoc.deliveryRadiusKm.toFixed(0)} km.`
              )
              return
            }
          }
        }
      }
    }

    if (orderForSomeone) {
      if (!recipientName.trim()) {
        triggerHaptic('warning')
        toast.error('Please enter recipient name')
        const el = document.getElementById('order-for-someone-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
      const cleanP = recipientPhone.replace(/\D/g, '')
      if (cleanP && cleanP.length !== 10) {
        triggerHaptic('warning')
        toast.error('Please enter a valid 10-digit mobile number')
        const el = document.getElementById('order-for-someone-section')
        if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' })
        return
      }
    }

    if (onlyCod) {
      setPaymentMethod('COD')
      handlePlaceOrder('COD', effectiveAddressId, effectiveAddresses)
    } else {
      triggerHaptic('light')
      setIsPaymentModalOpen(true)
    }
  }

  return {
    paymentMethod,
    setPaymentMethod,
    isPaymentModalOpen,
    setIsPaymentModalOpen,
    isPlacingOrder,
    activePendingOrderId,
    failedPaymentOrder,
    setFailedPaymentOrder,
    clearCart,
    handlePlaceOrder,
    handleCashfreeCheckout,
    handlePlaceOrderClick,
  }
}
