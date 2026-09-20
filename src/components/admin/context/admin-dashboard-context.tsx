'use client'

import React, { createContext, useContext, useState, useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { useSearchParams } from 'next/navigation'
import { HUB_CONFIG } from '@/lib/constants'

export type TabType =
  | 'orders'
  | 'products'
  | 'categories'
  | 'users'
  | 'reviews'
  | 'coupons'
  | 'analytics'
  | 'alerts'
  | 'bulk-update'
  | 'reports'
  | 'restaurant-report'
  | 'inward'
  | 'banners'
  | 'settings'
  | 'liveops'
  | 'push-notifications'
  | 'flash-deals'
  | 'forecast'
  | 'rider-cash'
  | 'restaurant-console'
  | 'vendors'
  | 'csv-import'

export type HubCategory =
  | 'orders_hub'
  | 'grocery'
  | 'food'
  | 'insights'
  | 'people'
  | 'marketing'

interface AdminDashboardContextType {
  session: any
  activeUser: any
  sessionUserId: string
  sessionUserRole: string
  sessionUserEmail: string
  sessionUserPhone: string
  isSuperAdmin: boolean
  selectedHubId: string
  setSelectedHubId: (id: string) => void
  handleSelectHub: (hubId: string) => void
  activeTab: TabType
  setActiveTab: (tab: TabType) => void
  activeHub: HubCategory
  setActiveHub: (hub: HubCategory) => void
  storesList: any[]
  setStoresList: React.Dispatch<React.SetStateAction<any[]>>
  restaurantsList: any[]
  setRestaurantsList: React.Dispatch<React.SetStateAction<any[]>>
}

const AdminDashboardContext = createContext<AdminDashboardContextType | null>(null)

interface AdminDashboardProviderProps {
  children: React.ReactNode
  initialStoreId?: string | null
  serverUser?: any
}

export function AdminDashboardProvider({
  children,
  initialStoreId,
  serverUser,
}: AdminDashboardProviderProps) {
  const { data: session } = useSession()
  const activeUser = session?.user || serverUser
  const sessionUserId = (activeUser as any)?.id || ''
  const sessionUserRole = activeUser?.role || ''
  const sessionUserEmail = ((activeUser as any)?.email || '').toLowerCase().trim()
  const sessionUserPhone = (activeUser as any)?.phone || ''
  const sessionAssignedStoreId =
    serverUser?.assignedStoreId || (activeUser as any)?.assignedStoreId || null
  const phoneDigits = sessionUserPhone.replace(/\D/g, '').slice(-10)

  const isSuperAdmin =
    phoneDigits === '9170942500' ||
    sessionUserEmail === 'superadmin@fastkirana.com' ||
    sessionUserEmail.startsWith('superadmin')

  const searchParams = useSearchParams()
  const urlStoreId = searchParams?.get('storeId') || null
  const effectiveInitialHub =
    sessionAssignedStoreId ||
    initialStoreId ||
    (isSuperAdmin ? urlStoreId || 'hub-209206' : 'hub-209206')

  const [selectedHubId, setSelectedHubId] = useState<string>(() => effectiveInitialHub)
  const [activeTab, setActiveTab] = useState<TabType>('orders')
  const [activeHub, setActiveHub] = useState<HubCategory>('orders_hub')
  const [storesList, setStoresList] = useState<any[]>([])
  const [restaurantsList, setRestaurantsList] = useState<any[]>([])

  useEffect(() => {
    let isMounted = true
    const refreshStoresAndRestaurants = async () => {
      try {
        const [storesRes, restRes] = await Promise.all([
          fetch('/api/admin/stores').then((r) => (r.ok ? r.json() : [])),
          fetch('/api/restaurants').then((r) => (r.ok ? r.json() : [])),
        ])
        if (isMounted) {
          if (Array.isArray(storesRes) && storesRes.length > 0) {
            setStoresList(storesRes)
          }
          if (Array.isArray(restRes) && restRes.length > 0) {
            setRestaurantsList(restRes)
          }
        }
      } catch (e) {
        console.warn('Failed to refresh stores/restaurants in admin context:', e)
      }
    }
    refreshStoresAndRestaurants()
    return () => {
      isMounted = false
    }
  }, [])

  useEffect(() => {
    if (sessionAssignedStoreId) {
      setSelectedHubId(sessionAssignedStoreId)
    } else if (isSuperAdmin && urlStoreId && urlStoreId !== selectedHubId) {
      setSelectedHubId(urlStoreId)
    } else if (initialStoreId && initialStoreId !== selectedHubId && !urlStoreId) {
      setSelectedHubId(initialStoreId)
    }
  }, [sessionAssignedStoreId, urlStoreId, initialStoreId, isSuperAdmin, selectedHubId])

  useEffect(() => {
    const parentHub = HUB_CONFIG.find((hub) =>
      (hub.tabs as readonly string[]).includes(activeTab)
    )
    if (parentHub && parentHub.key !== activeHub) {
      setActiveHub(parentHub.key as HubCategory)
    }
  }, [activeTab, activeHub])

  const handleSelectHub = (hubId: string) => {
    setSelectedHubId(hubId)
    if (typeof window !== 'undefined') {
      const url = new URL(window.location.href)
      url.searchParams.set('storeId', hubId)
      window.history.replaceState({}, '', url.toString())
    }
  }

  return (
    <AdminDashboardContext.Provider
      value={{
        session,
        activeUser,
        sessionUserId,
        sessionUserRole,
        sessionUserEmail,
        sessionUserPhone,
        isSuperAdmin,
        selectedHubId,
        setSelectedHubId,
        handleSelectHub,
        activeTab,
        setActiveTab,
        activeHub,
        setActiveHub,
        storesList,
        setStoresList,
        restaurantsList,
        setRestaurantsList,
      }}
    >
      {children}
    </AdminDashboardContext.Provider>
  )
}

export function useAdminDashboardContext() {
  const context = useContext(AdminDashboardContext)
  if (!context) {
    throw new Error('useAdminDashboardContext must be used within an AdminDashboardProvider')
  }
  return context
}
