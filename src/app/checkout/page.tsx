'use client'

import { useState, useEffect } from 'react'
import { useCart } from '@/hooks/use-cart'
import { useCartStore } from '@/stores/cart-store'
import { toast } from 'sonner'
import { ShieldCheck } from 'lucide-react'
import { isProductStoreClosed } from '@/lib/utils'

// Hooks
import { useCheckoutSettings } from '@/hooks/checkout/use-checkout-settings'
import { useCheckoutAddress } from '@/hooks/checkout/use-checkout-address'
import { useCheckoutPricing } from '@/hooks/checkout/use-checkout-pricing'
import { useCheckoutPayment } from '@/hooks/checkout/use-checkout-payment'

// Components
import {
  EmptyCartScreen,
  InventoryIssueScreen,
  StoreClosedScreen,
} from '@/components/checkout/checkout-barrier-screens'
import { CheckoutAddressSection } from '@/components/checkout/address/checkout-address-section'
import { OrderForSomeoneCard } from '@/components/checkout/order-for-someone-card'
import { CheckoutCartReview } from '@/components/checkout/checkout-cart-review'
import { FoodPackagingSelector } from '@/components/checkout/food-packaging-selector'
import { CheckoutBillSummary } from '@/components/checkout/checkout-bill-summary'
import { CheckoutMobileBar } from '@/components/checkout/checkout-mobile-bar'
import { SlideToOrder } from '@/components/checkout/slide-to-order'
import { PaymentSelectionModal } from '@/components/checkout/payment-selection-modal'
import { PaymentFailedCodModal } from '@/components/checkout/payment-failed-cod-modal'

export default function CheckoutPage() {
  const {
    items,
    removeItem,
    clearCart,
    getSubtotal,
    getSavings,
    getMrpTotal,
    updateQuantity,
    updateCartProduct,
  } = useCart()
  const appliedCouponCode = useCartStore((s) => s.appliedCouponCode)

  // 1. Settings & Store Config Hook
  const settings = useCheckoutSettings()
  const {
    storeSettingsMap,
    isSettingsLoading,
    storeLat,
    storeLng,
    deliveryRadius,
    onlyCod,
    groceryMartOpen,
    cafeOpen,
    restaurantOpen,
    contactPhone,
    groceryThreshold,
    taxRate,
    miscFeeLabel,
  } = settings

  // 2. Address & Geolocation Hook
  const addressHook = useCheckoutAddress({
    storeLat,
    storeLng,
    deliveryRadius,
    storeSettingsMap,
  })
  const {
    addresses,
    selectedAddressId,
    setSelectedAddressId,
    selectedAddress,
    isAddressesLoading,
    showNewAddressForm,
    setShowNewAddressForm,
    isSavingAddress,
    editingAddressId,
    setEditingAddressId,
    isChangingAddress,
    setIsChangingAddress,
    showMapPicker,
    setShowMapPicker,
    isDetectingLocation,
    addressForm,
    setAddressForm,
    activeCheckoutAddressRef,
    handleDetectLocationForCheckout,
    saveAddressCore,
    handleSaveAddress,
    handleEditAddressClick,
    handleCancelAddressForm,
  } = addressHook

  // 3. User Order Inputs
  const [cookingInstruction, setCookingInstruction] = useState('')
  const [orderForSomeone, setOrderForSomeone] = useState(false)
  const [recipientName, setRecipientName] = useState('')
  const [recipientPhone, setRecipientPhone] = useState('')
  const [packagingOption, setPackagingOption] = useState<'NORMAL' | 'PREMIUM'>('NORMAL')

  // 4. Cart Live Validation on Mount
  useEffect(() => {
    async function validateCartOnCheckout() {
      if (items.length === 0) return
      try {
        const res = await fetch('/api/products/validate-cart', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ items }),
        })
        if (res.ok) {
          const data = await res.json()
          if (data.hasChanges && data.updates.length > 0) {
            data.updates.forEach((update: any) => {
              if (update.type === 'OUT_OF_STOCK') {
                removeItem(update.productId, update.name)
                toast.error(
                  `"${update.name}" is currently out of stock and was removed from your cart.`,
                  {
                    id: `checkout-out-of-stock-${update.productId}`,
                    duration: 6000,
                  }
                )
              } else if (update.type === 'QUANTITY_CAP') {
                updateQuantity(update.productId, update.name, update.newVal)
                toast.warning(
                  `Quantity for "${update.name}" was reduced to ${update.newVal} (max stock).`,
                  {
                    id: `checkout-qty-cap-${update.productId}`,
                  }
                )
              } else if (update.type === 'PRICE_UPDATE') {
                updateCartProduct(update.productId, { price: update.newVal })
                toast.info(`Price for "${update.name}" updated to ₹${update.newVal}.`, {
                  id: `checkout-price-update-${update.productId}`,
                })
              } else if (update.type === 'MRP_UPDATE') {
                updateCartProduct(update.productId, { mrp: update.newVal })
              }
            })
          }
        }
      } catch (err) {
        console.error('Error validating cart on checkout mount:', err)
      }
    }

    validateCartOnCheckout()
  }, [])

  // 5. Pricing & Discounts Calculation Hook
  const pricing = useCheckoutPricing({
    items,
    subtotal: getSubtotal(),
    mrpTotal: getMrpTotal(),
    savings: getSavings(),
    selectedAddress,
    settings,
    packagingOption,
  })

  // 6. Payment & Order Execution Hook
  const payment = useCheckoutPayment({
    items,
    addresses,
    selectedAddressId,
    selectedAddress,
    appliedCouponCode,
    contactPhone,
    packagingOption,
    packagingFee: pricing.packagingFee,
    storeSettingsMap,
    onlyCod,
    deliveryRules: pricing.deliveryRules,
    distanceKm: pricing.distanceKm,
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
  })

  // Early Return Barriers
  if (items.length === 0) {
    return <EmptyCartScreen />
  }

  const hasInventoryIssues = items.some(
    (item) =>
      item.quantity > item.product.stock ||
      item.product.stock <= 0 ||
      item.product.isAvailable === false
  )

  if (hasInventoryIssues && !isSettingsLoading) {
    return (
      <InventoryIssueScreen
        items={items}
        removeItem={removeItem}
        updateQuantity={updateQuantity}
      />
    )
  }

  const closedItems = items.filter((item) =>
    isProductStoreClosed(item.product, { groceryMartOpen, cafeOpen, restaurantOpen })
  )

  if (closedItems.length > 0 && !isSettingsLoading) {
    return <StoreClosedScreen closedItems={closedItems} removeItem={removeItem} />
  }

  return (
    <div className="container mx-auto px-3 sm:px-4 py-3 sm:py-6 max-w-5xl space-y-4 sm:space-y-6 pb-24 sm:pb-8">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-border/60 pb-2.5">
        <div>
          <h1 className="text-base sm:text-xl font-black text-text-primary tracking-tight">
            ⚡ Quick Checkout
          </h1>
          <p className="text-[11px] text-text-muted mt-0.5">
            Ghatampur fastest local delivery to your doorstep
          </p>
        </div>
        <div className="hidden sm:flex items-center gap-1.5 text-xs font-bold text-accent bg-accent/10 px-3 py-1 rounded-full border border-accent/20">
          <ShieldCheck className="h-4 w-4" />
          <span>100% Secure Checkout</span>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 sm:gap-8">
        {/* Left: Checkout Details */}
        <div className="lg:col-span-2 space-y-4 sm:space-y-6">
          <div className="bg-card border border-border p-3.5 sm:p-5 rounded-2xl shadow-xs space-y-5 sm:space-y-6 animate-fade-in">
            {/* Delivery Address Section */}
            <CheckoutAddressSection
              addresses={addresses}
              selectedAddressId={selectedAddressId}
              setSelectedAddressId={setSelectedAddressId}
              selectedAddress={selectedAddress}
              isAddressesLoading={isAddressesLoading}
              showNewAddressForm={showNewAddressForm}
              setShowNewAddressForm={setShowNewAddressForm}
              isSavingAddress={isSavingAddress}
              editingAddressId={editingAddressId}
              setEditingAddressId={setEditingAddressId}
              isChangingAddress={isChangingAddress}
              setIsChangingAddress={setIsChangingAddress}
              showMapPicker={showMapPicker}
              setShowMapPicker={setShowMapPicker}
              isDetectingLocation={isDetectingLocation}
              addressForm={addressForm}
              setAddressForm={setAddressForm}
              storeLat={storeLat}
              storeLng={storeLng}
              storeSettingsMap={storeSettingsMap}
              handleDetectLocationForCheckout={handleDetectLocationForCheckout}
              handleSaveAddress={handleSaveAddress}
              handleEditAddressClick={handleEditAddressClick}
              handleCancelAddressForm={handleCancelAddressForm}
            />

            {/* Order For Someone Else */}
            <OrderForSomeoneCard
              orderForSomeone={orderForSomeone}
              setOrderForSomeone={setOrderForSomeone}
              recipientName={recipientName}
              setRecipientName={setRecipientName}
              recipientPhone={recipientPhone}
              setRecipientPhone={setRecipientPhone}
            />

            {/* Cart Items Review */}
            <CheckoutCartReview
              items={items}
              cookingInstruction={cookingInstruction}
              setCookingInstruction={setCookingInstruction}
            />

            {/* Food Packaging Option (Cafe/Restaurant) */}
            {(pricing.hasCafeItems || pricing.cafeCartItems.length > 0) && (
              <FoodPackagingSelector
                packagingOption={packagingOption}
                setPackagingOption={setPackagingOption}
              />
            )}

            {/* Trust Banner */}
            <div className="flex items-center gap-2 border border-accent/20 bg-accent/5 p-3 rounded-xl text-xs font-semibold text-accent">
              <ShieldCheck className="h-5 w-5 shrink-0" />
              <span>100% Secure &amp; Verified Order • Fast &amp; Reliable Delivery</span>
            </div>

            {/* Desktop Slide-to-Order */}
            <div className="hidden md:block border-t border-border/40 pt-5 md:pt-6">
              <SlideToOrder
                onConfirm={payment.handlePlaceOrderClick}
                isPlacingOrder={payment.isPlacingOrder || isSavingAddress}
                amount={pricing.grandTotal}
              />
            </div>
          </div>
        </div>

        {/* Right: Consolidated Bill Summary */}
        <CheckoutBillSummary
          totalItemsCount={pricing.groceryCartItems.length + pricing.cafeCartItems.length}
          grocerySavings={pricing.grocerySavings}
          groceryB2BDiscount={pricing.groceryB2BDiscount}
          cafeSavings={pricing.cafeSavings}
          cafeB2BDiscount={pricing.cafeB2BDiscount}
          groceryMrpSubtotal={pricing.groceryMrpSubtotal}
          cafeMrpSubtotal={pricing.cafeMrpSubtotal}
          grocerySubtotal={pricing.grocerySubtotal}
          cafeSubtotal={pricing.cafeSubtotal}
          deliveryRules={pricing.deliveryRules}
          adjustedSubtotal={pricing.adjustedSubtotal}
          groceryThreshold={groceryThreshold}
          baseDeliveryFee={pricing.baseDeliveryFee}
          appliedSurgeFee={pricing.appliedSurgeFee}
          packagingFee={pricing.packagingFee}
          couponDiscount={pricing.couponDiscount}
          appliedCoupon={pricing.appliedCoupon}
          taxRate={taxRate}
          taxes={pricing.taxes}
          effectiveMiscFee={pricing.effectiveMiscFee}
          miscFeeLabel={miscFeeLabel}
          selectedAddress={selectedAddress}
          distanceKm={pricing.distanceKm}
          grandTotal={pricing.grandTotal}
        />
      </div>

      {/* Mobile Sticky Bar */}
      <CheckoutMobileBar
        grandTotal={pricing.grandTotal}
        selectedAddress={selectedAddress}
        isPlacingOrder={payment.isPlacingOrder}
        isSavingAddress={isSavingAddress}
        paymentMethod={payment.paymentMethod}
        handlePlaceOrderClick={payment.handlePlaceOrderClick}
      />

      {/* Payment Selection Modal */}
      <PaymentSelectionModal
        isOpen={payment.isPaymentModalOpen}
        onClose={() => payment.setIsPaymentModalOpen(false)}
        grandTotal={pricing.grandTotal}
        onlyCod={onlyCod}
        deliveryMethod="DELIVERY"
        isPlacingOrder={payment.isPlacingOrder}
        onSelectCod={() => {
          payment.setIsPaymentModalOpen(false)
          payment.setPaymentMethod('COD')
          payment.handlePlaceOrder(
            'COD',
            activeCheckoutAddressRef.current?.id || selectedAddressId,
            activeCheckoutAddressRef.current?.addresses || addresses
          )
        }}
        onSelectOnline={() => {
          payment.setIsPaymentModalOpen(false)
          payment.setPaymentMethod('UPI')
          payment.handleCashfreeCheckout(
            'UPI',
            activeCheckoutAddressRef.current?.id || selectedAddressId,
            activeCheckoutAddressRef.current?.addresses || addresses
          )
        }}
      />

      {/* 1-Minute Payment Failed / COD Fallback Modal */}
      <PaymentFailedCodModal
        isOpen={!!payment.failedPaymentOrder}
        orderId={payment.failedPaymentOrder?.id || ''}
        orderReadableId={payment.failedPaymentOrder?.readableId}
        totalAmount={payment.failedPaymentOrder?.totalAmount || pricing.grandTotal}
        onClose={() => payment.setFailedPaymentOrder(null)}
        onSuccessCod={(orderId) => {
          payment.setFailedPaymentOrder(null)
          payment.clearCart()
          window.location.href = `/order/${orderId}/success`
        }}
      />
    </div>
  )
}
