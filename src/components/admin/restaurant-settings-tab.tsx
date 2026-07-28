'use client'

import { useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { Loader2, UtensilsCrossed } from 'lucide-react'
import { toast } from 'sonner'
import { RestaurantForm } from './restaurant-form'

export function RestaurantSettingsTab() {
  const { data: session } = useSession()
  const [restaurant, setRestaurant] = useState<any>(null)
  const [loading, setLoading] = useState(true)

  const assignedRestaurantId = (session?.user as any)?.assignedRestaurantId

  useEffect(() => {
    if (!assignedRestaurantId) {
      setLoading(false)
      return
    }

    const fetchDetails = async () => {
      try {
        const res = await fetch(`/api/restaurants/${assignedRestaurantId}`)
        if (!res.ok) throw new Error('Failed to fetch details')
        const data = await res.json()
        setRestaurant(data)
      } catch (err) {
        console.error(err)
        toast.error('Failed to load restaurant details')
      } finally {
        setLoading(false)
      }
    }

    fetchDetails()
  }, [assignedRestaurantId])

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center py-20 gap-3">
        <Loader2 className="h-8 w-8 text-orange-500 animate-spin" />
        <p className="text-sm text-text-secondary font-bold">Loading console settings...</p>
      </div>
    )
  }

  if (!restaurant) {
    return (
      <div className="bg-card border border-border rounded-3xl p-8 text-center max-w-md mx-auto space-y-4">
        <div className="h-14 w-14 rounded-2xl bg-rose-500/10 text-rose-600 flex items-center justify-center mx-auto shadow-inner">
          <UtensilsCrossed className="h-7 w-7" />
        </div>
        <h3 className="text-lg font-black text-text-primary uppercase tracking-tight">No Restaurant Assigned</h3>
        <p className="text-xs text-text-secondary leading-relaxed">
          Your staff account is currently not assigned to any specific restaurant or cafe. Please contact your administrator to set up your store linkage.
        </p>
      </div>
    )
  }

  return (
    <div className="animate-fade-in">
      <RestaurantForm restaurant={restaurant} isAdmin={false} />
    </div>
  )
}
