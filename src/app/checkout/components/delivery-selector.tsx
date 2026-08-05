'use client'

import React from 'react'
import { MapPin, Plus, Store, Truck } from 'lucide-react'
import { Address } from '@/types'
import { formatAddress } from '@/lib/utils'

export interface DeliverySelectorProps {
  deliveryMethod: 'DELIVERY' | 'PICKUP'
  setDeliveryMethod: (method: 'DELIVERY' | 'PICKUP') => void
  addresses: Address[]
  selectedAddressId: string | null
  setSelectedAddressId: (id: string) => void
  onAddNewAddress: () => void
  deliveryInstructions: string
  setDeliveryInstructions: (instructions: string) => void
}

export function CheckoutDeliverySelector({
  deliveryMethod,
  setDeliveryMethod,
  addresses,
  selectedAddressId,
  setSelectedAddressId,
  onAddNewAddress,
  deliveryInstructions,
  setDeliveryInstructions,
}: DeliverySelectorProps) {
  return (
    <div className="bg-card border border-border p-4 sm:p-5 rounded-2xl shadow-xs space-y-4">
      {/* Method Tabs */}
      <div className="flex rounded-xl bg-muted/40 p-1 border border-border/40">
        <button
          type="button"
          onClick={() => setDeliveryMethod('DELIVERY')}
          className={`flex-1 py-2 text-xs font-black rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
            deliveryMethod === 'DELIVERY'
              ? 'bg-card text-text-primary shadow-xs'
              : 'text-text-secondary hover:text-text-primary'
          }`}
        >
          <Truck className="h-4 w-4" />
          <span>Doorstep Delivery</span>
        </button>
        <button
          type="button"
          onClick={() => setDeliveryMethod('PICKUP')}
          className={`flex-1 py-2 text-xs font-black rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer ${
            deliveryMethod === 'PICKUP'
              ? 'bg-card text-text-primary shadow-xs'
              : 'text-text-secondary hover:text-text-primary'
          }`}
        >
          <Store className="h-4 w-4" />
          <span>Self Pickup</span>
        </button>
      </div>

      {deliveryMethod === 'DELIVERY' ? (
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h4 className="text-xs font-extrabold text-text-primary">Delivery Address</h4>
            <button
              type="button"
              onClick={onAddNewAddress}
              className="text-xs font-black text-accent hover:underline flex items-center gap-1 cursor-pointer"
            >
              <Plus className="h-3.5 w-3.5" />
              <span>Add New</span>
            </button>
          </div>

          <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
            {addresses.map((addr) => {
              const selected = selectedAddressId === addr.id
              return (
                <button
                  key={addr.id}
                  type="button"
                  onClick={() => setSelectedAddressId(addr.id)}
                  className={`w-full p-3 rounded-xl border text-left transition-all cursor-pointer flex items-start gap-2.5 ${
                    selected
                      ? 'border-accent bg-accent/5 ring-1 ring-accent/30'
                      : 'border-border/60 hover:bg-muted/20'
                  }`}
                >
                  <MapPin
                    className={`h-4 w-4 shrink-0 mt-0.5 ${
                      selected ? 'text-accent' : 'text-text-muted'
                    }`}
                  />
                  <div className="text-xs">
                    <p className="font-extrabold text-text-primary">{addr.label || 'Home'}</p>
                    <p className="text-text-secondary text-[11px] mt-0.5">
                      {formatAddress(addr)}
                    </p>
                  </div>
                </button>
              )
            })}
          </div>

          {/* Delivery Note */}
          <div className="pt-2">
            <label className="text-[10px] font-bold text-text-secondary block mb-1">
              Delivery Instructions (Optional)
            </label>
            <input
              type="text"
              placeholder="e.g. Ring bell twice, leave at door"
              value={deliveryInstructions}
              onChange={(e) => setDeliveryInstructions(e.target.value)}
              className="w-full px-3 py-2 text-xs rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-accent"
            />
          </div>
        </div>
      ) : (
        <div className="p-4 rounded-xl bg-purple-500/10 border border-purple-500/20 text-xs space-y-1">
          <p className="font-extrabold text-purple-700 dark:text-purple-300">
            🏬 Store Pickup Selected
          </p>
          <p className="text-text-secondary text-[11px]">
            Collect directly from FastKirana Store counter once order is ready. No delivery fee charged.
          </p>
        </div>
      )}
    </div>
  )
}
