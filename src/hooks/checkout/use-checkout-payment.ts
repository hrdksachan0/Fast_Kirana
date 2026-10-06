'use client';
import { apiUrl } from '@/lib/api-url';

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'
import { getApiErrorMessage } from '@/lib/api-error'
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
import { useUIStore } from '@/stores/ui-store'
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
  storeId?: string | null
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
  storeId,
}: UseCheckoutPaymentProps) {
  const activeStoreIdFromStore = useUIStore((s) => s.activeStoreId)
  const effectiveStoreId = storeId || activeStoreIdFromStore || null
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
    cfOrderId?: string
    pendingPayload?: any
  } | null>(null)
  const [overlayState, setOverlayState] = useState<'creating-order' | 'preparing-payment' | 'awaiting-payment' | 'verifying-payment' | 'success' | null>(null)
  const [orderReadableId, setOrderReadableId] = useState<string | undefined>(undefined)

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
    setOverlayState('creating-order')
    try {
      const settingsUrl = effectiveStoreId && effectiveStoreId !== 'all'
        ? `/api/settings?storeId=${encodeURIComponent(effectiveStoreId)}`
        : '/api/settings'
      const settingsRes = await fetch(settingsUrl, { cache: 'no-store' })
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
        setOverlayState(null)
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
        storeId: effectiveStoreId,
      })

      const res = await fetch(`${apiUrl()}/api/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...payload,
          storeId: effectiveStoreId || undefined,
          existingOrderId: activePendingOrderId || undefined,
          notes: finalNotes,
        }),
      })

      const data = await res.json()

      if (res.ok) {
        triggerHaptic('success')
        setOrderReadableId(data.readableId || data.id?.slice(0, 8))
        setOverlayState('success')
        clearCart()

        // Play success chime
        try {
          const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
          if (AudioContextClass) {
            const ctx = new AudioContextClass()
            const now = ctx.currentTime
            const osc = ctx.createOscillator()
            const gain = ctx.createGain()
            osc.type = 'triangle'
            osc.frequency.setValueAtTime(880, now)
            gain.gain.setValueAtTime(0.12, now)
            gain.gain.exponentialRampToValueAtTime(0.001, now + 0.5)
            osc.connect(gain)
            gain.connect(ctx.destination)
            osc.start(now)
            osc.stop(now + 0.5)
          }
        } catch (_) {}

        // Hard redirect after showing success celebration for 1.5s
        setTimeout(() => {
          window.location.replace(`/order/${data.id}/success`)
        }, 1500)
      } else {
        setOverlayState(null)
        toast.error(getApiErrorMessage(data, 'Failed to place order'))
        setIsPlacingOrder(false)
      }
    } catch (err) {
      setOverlayState(null)
      toast.error(getApiErrorMessage(err, 'Connection error. Please try again.'))
      setIsPlacingOrder(false)
    }
  }

  const handleCashfreeCheckout = async (
    overrideMethod?: 'COD' | 'UPI' | 'CARD' | 'WALLET',
    overrideAddressId?: string,
    overrideAddresses?: Address[],
    grandTotal?: number
  ) => {
    const selectedMethod = overrideMethod || paymentMethod
    const activeAddresses = overrideAddresses || addresses
    const activeAddressId = overrideAddressId || selectedAddressId
    const activeSelectedAddress =
      activeAddresses.find((a) => a.id === activeAddressId) || selectedAddress


    setIsPlacingOrder(true)
    setOverlayState('preparing-payment')
    try {
      const settingsUrl = effectiveStoreId && effectiveStoreId !== 'all'
        ? `/api/settings?storeId=${encodeURIComponent(effectiveStoreId)}`
        : '/api/settings'
      const settingsRes = await fetch(settingsUrl, { cache: 'no-store' })
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
        setOverlayState(null)
        return
      }

      const effectiveCustomerPhone = getEffectiveCustomerPhone(activeSelectedAddress)
      const finalNotes = getOrderNotes()

      // Build the order payload (but DON'T create the order yet)
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
        storeId: effectiveStoreId,
      })

      // Calculate total for Cashfree payment
      // Use grandTotal from caller (checkout page) if available, otherwise estimate from cart
      let paymentAmount = grandTotal || 0
      if (!paymentAmount || paymentAmount <= 0) {
        const sub = items.reduce((sum, item) => sum + (item.product.price * item.quantity), 0)
        const effectivePackFee = deliveryMethod === 'PICKUP' ? 0 : (packagingFee > 0 ? packagingFee : (packagingOption === 'PREMIUM' ? 15 : 5))
        paymentAmount = sub + effectivePackFee
      }

      // Free order edge case: skip Cashfree entirely, place order directly
      if (paymentAmount <= 0) {
        const orderRes = await fetch(`${apiUrl()}/api/orders`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            ...payload,
            storeId: effectiveStoreId || undefined,
            notes: finalNotes,
            paymentStatus: 'PAID',
            paymentId: `FREE_PROMO_${Date.now()}`,
          }),
        })
        const orderData = await orderRes.json()
        if (orderRes.ok) {
          clearCart()
          triggerHaptic('success')
          setOrderReadableId(orderData.readableId || orderData.id?.slice(0, 8))
          setOverlayState('success')
          toast.success('🎉 Order placed successfully! (100% Free Promo)')
          setTimeout(() => {
            window.location.replace(`/order/${orderData.id}/success`)
          }, 1200)
        } else {
          setOverlayState(null)
          toast.error(getApiErrorMessage(orderData, 'Failed to place order'))
          setIsPlacingOrder(false)
        }
        return
      }

      // ═══════════════════════════════════════════════════════════════════════
      // PAY FIRST: Create Cashfree payment session with amount (no DB order)
      // ═══════════════════════════════════════════════════════════════════════
      const userName = (session?.user as any)?.name || 'FastKirana Customer'
      const userEmail = (session?.user as any)?.email || undefined
      const userPhone = effectiveCustomerPhone || (session?.user as any)?.phone || '9999999999'

      const cfRes = await fetch(`${apiUrl()}/api/payment/cashfree/create-order`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          amount: paymentAmount,
          customerPhone: userPhone,
          customerEmail: userEmail,
          customerName: userName,
          note: `FastKirana Checkout ₹${paymentAmount}`,
        }),
      })

      const cfData = await cfRes.json()

      if (!cfRes.ok || !cfData.paymentSessionId) {
        console.warn('Cashfree session failed:', cfData.error || cfData.detail)
        toast.error(getApiErrorMessage(cfData, 'Cashfree payment session could not be created.'))
        setIsPlacingOrder(false)
        setOverlayState(null)
        return
      }

      const loaded = await loadCashfreeScript()
      if (!loaded || !(window as any).Cashfree) {
        console.warn('Cashfree SDK failed to load')
        toast.error('Payment gateway SDK failed to load.')
        setIsPlacingOrder(false)
        setOverlayState(null)
        return
      }

      const cashfree = (window as any).Cashfree({
        mode: process.env.NEXT_PUBLIC_CASHFREE_ENV === 'SANDBOX' ? 'sandbox' : 'production',
      })

      // Store payload for post-payment order creation
      const cfTag = `[CF_ORDER:${cfData.orderId}]`
      const notesWithCf = finalNotes ? `${finalNotes} | ${cfTag}` : cfTag
      const pendingPayload = {
        ...payload,
        storeId: effectiveStoreId || undefined,
        notes: notesWithCf,
      }

      let paymentSuccess = false
      let isVerifyingOrCreating = false

      // ═══════════════════════════════════════════════════════════════════════
      // POST-PAYMENT: Verify & create order in DB only after PAID
      // ═══════════════════════════════════════════════════════════════════════
      let pollCount = 0
      const checkVerificationAndCreateOrder = async () => {
        if (paymentSuccess || isVerifyingOrCreating) return true
        isVerifyingOrCreating = true
        try {
          const verifyRes = await fetch(`${apiUrl()}/api/payment/cashfree/verify`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ orderId: cfData.orderId, cfOrderId: cfData.orderId }),
          })
          const verifyData = await verifyRes.json()
          if (verifyRes.ok && (verifyData.paymentStatus === 'PAID' || verifyData.isPaid === true)) {
            paymentSuccess = true
            clearInterval(pollTimer)
            document.removeEventListener('visibilitychange', handleVisibilityChange)

            // Payment verified! Now create the order in DB
            setOverlayState('creating-order')
            const resolvedPaymentId = verifyData.cfPaymentId || verifyData.paymentId || `CF_${cfData.orderId}`

            let orderCreated = false
            let orderData: any = null

            // Retry order creation up to 3 times (critical: payment already taken)
            for (let retry = 0; retry < 3; retry++) {
              try {
                const orderRes = await fetch(`${apiUrl()}/api/orders`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({
                    ...pendingPayload,
                    paymentStatus: 'PAID',
                    paymentId: resolvedPaymentId,
                    cfOrderId: cfData.orderId,
                  }),
                })
                orderData = await orderRes.json()
                if (orderRes.ok) {
                  orderCreated = true
                  break
                }
                console.warn(`Order creation attempt ${retry + 1} failed:`, orderData)
              } catch (orderErr) {
                console.error(`Order creation attempt ${retry + 1} error:`, orderErr)
              }
              if (retry < 2) await new Promise((r) => setTimeout(r, 2000))
            }

            if (orderCreated && orderData) {
              clearCart()
              triggerHaptic('success')
              setOrderReadableId(orderData.readableId || orderData.id?.slice(0, 8))
              setOverlayState('success')
              toast.success('🎉 Payment Verified & Order Placed!')
              setTimeout(() => {
                window.location.replace(`/order/${orderData.id}/success`)
              }, 1500)
            } else {
              // 🛡️ EMERGENCY RECOVERY: Payment succeeded but order creation failed
              // Save to localStorage as backup — webhook/cron will reconcile
              try {
                const emergencyData = {
                  payload: pendingPayload,
                  paymentId: resolvedPaymentId,
                  cfOrderId: cfData.orderId,
                  amount: paymentAmount,
                  timestamp: Date.now(),
                }
                localStorage.setItem(`fk_emergency_order_${cfData.orderId}`, JSON.stringify(emergencyData))
              } catch (_) {}

              clearCart()
              triggerHaptic('success')
              setOverlayState('success')
              toast.success(
                '✅ Payment of ₹' + paymentAmount + ' successful! Your order is being confirmed. You will receive confirmation shortly.',
                { duration: 8000 }
              )
              setTimeout(() => {
                window.location.replace('/orders')
              }, 3000)
            }
            return true
          }
        } catch (_) {
        } finally {
          if (!paymentSuccess) {
            isVerifyingOrCreating = false
          }
        }
        return false
      }

      const pollTimer = setInterval(async () => {
        pollCount++
        if (pollCount > 100 || paymentSuccess) {
          clearInterval(pollTimer)
          return
        }
        await checkVerificationAndCreateOrder()
      }, 2000)

      const handleVisibilityChange = async () => {
        if (document.visibilityState === 'visible') {
          setOverlayState('verifying-payment')
          await checkVerificationAndCreateOrder()
        }
      }
      document.addEventListener('visibilitychange', handleVisibilityChange)

      // Signal awaiting payment state before modal opens
      setOverlayState('awaiting-payment')

      try {
        const result = await cashfree.checkout({
          paymentSessionId: cfData.paymentSessionId,
          redirectTarget: '_modal',
        })

        // When user returns or modal dismisses, aggressively verify payment
        setOverlayState('verifying-payment')
        let isVerified = false
        for (let attempt = 0; attempt < 10; attempt++) {
          isVerified = await checkVerificationAndCreateOrder()
          if (isVerified || paymentSuccess) break
          await new Promise((resolve) => setTimeout(resolve, 1500))
        }

        if (!isVerified && !paymentSuccess) {
          clearInterval(pollTimer)
          document.removeEventListener('visibilitychange', handleVisibilityChange)
          setIsPlacingOrder(false)
          setOverlayState(null)
          if (result?.error) {
            console.log('Cashfree modal closed with note:', result.error)
          }
          triggerHaptic('warning')
          // No DB order was created — show retry options without orderId
          setFailedPaymentOrder({
            id: '', // No DB order exists
            totalAmount: paymentAmount,
            cfOrderId: cfData.orderId,
            pendingPayload,
          })
        }
      } catch (checkoutErr) {
        console.warn('Cashfree checkout modal error:', checkoutErr)
        setOverlayState('verifying-payment')
        let isVerified = false
        for (let attempt = 0; attempt < 8; attempt++) {
          isVerified = await checkVerificationAndCreateOrder()
          if (isVerified || paymentSuccess) break
          await new Promise((resolve) => setTimeout(resolve, 1500))
        }

        if (!isVerified && !paymentSuccess) {
          clearInterval(pollTimer)
          document.removeEventListener('visibilitychange', handleVisibilityChange)
          setIsPlacingOrder(false)
          setOverlayState(null)
          setFailedPaymentOrder({
            id: '',
            totalAmount: paymentAmount,
            cfOrderId: cfData.orderId,
            pendingPayload,
          })
        }
      }
    } catch (err) {
      console.error('Error during Cashfree checkout:', err)
      toast.error('An unexpected error occurred during checkout.')
      setIsPlacingOrder(false)
      setOverlayState(null)
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
    overlayState,
    setOverlayState,
    orderReadableId,
    clearCart,
    handlePlaceOrder,
    handleCashfreeCheckout,
    handlePlaceOrderClick,
  }
}
