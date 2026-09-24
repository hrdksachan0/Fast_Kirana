'use client'

import { useState, useEffect, useMemo, useCallback } from 'react'
import { useSession } from 'next-auth/react'
import { useSearchParams } from 'next/navigation'
import {
  DEFAULT_CAFE_MENU_SECTIONS,
  PRODUCT_TEMPLATES,
  HUB_CONFIG,
} from '@/lib/constants'
import { DashboardHubNav } from '@/components/admin/dashboard/hub-nav'
import { DashboardStatsCards } from '@/components/admin/dashboard/stats-cards'
import { BottleneckBanner } from '@/components/admin/dashboard/bottleneck-banner'
import { StoreControlBar } from '@/components/admin/dashboard/store-control-bar'
import { AdminLiveOrdersTab } from '@/components/admin/dashboard/AdminLiveOrdersTab'
import { AdminInventoryHubTab } from '@/components/admin/dashboard/AdminInventoryHubTab'
import { AdminRidersFleetTab } from '@/components/admin/dashboard/AdminRidersFleetTab'
import { AdminReportsTab } from '@/components/admin/dashboard/AdminReportsTab'
import { AdminDarkStoresTab } from '@/components/admin/dashboard/AdminDarkStoresTab'
import { UsersTab } from '@/components/admin/users-tab'
import { CouponsTab } from '@/components/admin/coupons-tab'
import { ReviewsTab } from '@/components/admin/reviews-tab'
import { BannersTab } from '@/components/admin/banners-tab'
import { PushNotificationsTab } from '@/components/admin/push-notifications-tab'
import { FlashDealsTab } from '@/components/admin/flash-deals-tab'
import { RestaurantConsoleTab } from '@/components/admin/restaurant-console-tab'
import { VendorConsoleTab } from '@/components/admin/vendor-console-tab'
import { WhatsAppAlertModal } from '@/components/admin/dashboard/whatsapp-alert-modal'
import { toast } from 'sonner'
import { PRESET_KITCHEN_PHOTOS } from '@/lib/preset-photos'
import { compressImageClient } from '@/lib/image-compression'
import {
  ShoppingBag,
  Package,
  Layers,
  Users,
  AlertCircle,
  Star,
  Ticket,
  SlidersHorizontal,
  FileText,
  Building2,
  Image as ImageIcon,
  Settings,
  TrendingUp,
  Zap,
  Utensils,
  Bell,
  BrainCircuit,
  Wallet,
  Truck,
  Download,
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import dynamic from 'next/dynamic'
import { StoreHubsManager } from './store-hubs-manager'
import { getLast10Digits } from '@/lib/phone'

// Custom Admin Hooks
import { useAdminRealtime } from '@/hooks/admin/use-admin-realtime'
import { useAdminOrders } from '@/hooks/admin/use-admin-orders'
import { useAdminProducts } from '@/hooks/admin/use-admin-products'
import { useAdminCategories } from '@/hooks/admin/use-admin-categories'
import { useAdminUsers } from '@/hooks/admin/use-admin-users'
import { useAdminReviewsCoupons } from '@/hooks/admin/use-admin-reviews-coupons'

const CreateOrderModal = dynamic(
  () => import('./create-order-modal').then((m) => m.CreateOrderModal),
  { ssr: false }
)
const ProductEditModal = dynamic(() => import('./product-edit-modal'), { ssr: false })
const CategoryEditModal = dynamic(
  () => import('./category-edit-modal').then((m) => m.CategoryEditModal),
  { ssr: false }
)
const ReviewEditModal = dynamic(
  () => import('./review-edit-modal').then((m) => m.ReviewEditModal),
  { ssr: false }
)
const BlockCustomerModal = dynamic(
  () => import('./block-customer-modal').then((m) => m.BlockCustomerModal),
  { ssr: false }
)
const OrderTrackingModal = dynamic(() => import('./order-tracking-modal'), { ssr: false })
const MediaLibraryModal = dynamic(() => import('./media-library-modal'), { ssr: false })
import { AdminSortManager } from './admin-sort-manager'

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

interface AdminDashboardProps {
  initialStoreId?: string | null
  initialStores?: any[]
  initialRestaurants?: any[]
  serverUser?: {
    id?: string
    name?: string | null
    email?: string | null
    role?: string
    phone?: string | null
    assignedStoreId?: string | null
  }
  initialOrders?: any[]
  initialProducts?: any[]
  initialCategories?: any[]
  initialUsers?: any[]
  initialReviews?: any[]
  initialCoupons?: any[]
  allProducts?: any[]
  initialOrderCounts?: Record<string, number>
  stats: {
    revenue: number
    todaySales?: number
    netSales?: number
    todayOrdersCount?: number
    todayDeliveryFee?: number
    todayPackagingFee?: number
    orderCount: number
    activeOrderCount?: number
    userCount: number
    lowStockCount: number
    groceryRevenue?: number
    restaurantRevenue?: number
  }
}

export function AdminDashboard({
  initialStoreId,
  initialStores = [],
  initialRestaurants = [],
  serverUser,
  initialOrders,
  initialProducts,
  initialCategories,
  initialUsers,
  initialReviews,
  initialCoupons,
  allProducts: initialAllProducts,
  initialOrderCounts,
  stats,
}: AdminDashboardProps) {
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

  const [restaurantsList, setRestaurantsList] = useState<any[]>(() => initialRestaurants || [])
  const [storesList, setStoresList] = useState<any[]>(() => initialStores || [])
  const [selectedHubId, setSelectedHubId] = useState<string>(() => effectiveInitialHub)
  const [isStoreHubsModalOpen, setIsStoreHubsModalOpen] = useState(false)
  const [activeTab, setActiveTab] = useState<TabType>('orders')
  const [activeHub, setActiveHub] = useState<
    'orders_hub' | 'grocery' | 'food' | 'insights' | 'people' | 'marketing'
  >('orders_hub')
  const [isUploading, setIsUploading] = useState(false)
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})
  const [isCreateOrderOpen, setIsCreateOrderOpen] = useState(false)
  const [groceryMartOpen, setGroceryMartOpen] = useState<boolean>(true)
  const [groceryAutoTiming, setGroceryAutoTiming] = useState<boolean>(false)
  const [isTogglingStore, setIsTogglingStore] = useState<boolean>(false)

  // Fetch / refresh stores and restaurants list on mount
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
        console.warn('Failed to refresh stores/restaurants in admin dashboard:', e)
      }
    }
    refreshStoresAndRestaurants()
    return () => {
      isMounted = false
    }
  }, [])

  // Media Library state
  const [showMediaLibrary, setShowMediaLibrary] = useState(false)
  const [mediaTarget, setMediaTarget] = useState<
    'newProduct' | 'editProduct' | 'newCategory' | 'editCategory' | 'category' | null
  >(null)
  const [mediaSearchQuery, setMediaSearchQuery] = useState('')

  // WhatsApp Alert Modal state
  const [whatsappModalOpen, setWhatsappModalOpen] = useState(false)
  const [whatsappTargetUser, setWhatsappTargetUser] = useState<{
    name: string
    phone: string
  } | null>(null)
  const [whatsappCustomMessage, setWhatsappCustomMessage] = useState('')
  const [whatsappSelectedTemplateIdx, setWhatsappSelectedTemplateIdx] = useState(0)

  // Keep selectedHubId synchronized with URL or assignedStoreId
  useEffect(() => {
    if (sessionAssignedStoreId) {
      setSelectedHubId(sessionAssignedStoreId)
    } else if (isSuperAdmin && urlStoreId && urlStoreId !== selectedHubId) {
      setSelectedHubId(urlStoreId)
    } else if (initialStoreId && initialStoreId !== selectedHubId && !urlStoreId) {
      setSelectedHubId(initialStoreId)
    }
  }, [sessionAssignedStoreId, urlStoreId, initialStoreId, isSuperAdmin, selectedHubId])

  const handleSelectHub = (hubId: string) => {
    if (sessionAssignedStoreId && !isSuperAdmin) {
      return // Branch admin is strictly locked to their assigned hub
    }
    setSelectedHubId(hubId)
    if (typeof window !== 'undefined') {
      const url = new URL(window.location.href)
      url.searchParams.set('storeId', hubId)
      window.history.replaceState({}, '', url.toString())
    }
  }

  // Auto-synchronize activeHub when activeTab changes
  useEffect(() => {
    const parentHub = HUB_CONFIG.find((hub) =>
      (hub.tabs as readonly string[]).includes(activeTab)
    )
    if (parentHub && parentHub.key !== activeHub) {
      setActiveHub(parentHub.key as any)
    }
  }, [activeTab, activeHub])

  // Tri-channel Realtime & Chimes Hook
  const {
    liveOrders,
    livePendingOrders,
    delayedOrders,
    pickerDelays,
    chefDelays,
    riderDelays,
    isChimeMuted,
    setIsChimeMuted,
    activeCarts,
    activeCartsCount,
    isLoadingCarts,
    cartsRefreshKey,
    setCartsRefreshKey,
    orderRefreshKey,
    setOrderRefreshKey,
  } = useAdminRealtime({
    selectedHubId,
    initialOrders,
    activeTab,
  })

  // Categories Hook
  const categoryHook = useAdminCategories({
    initialCategories,
  })

  // Products Hook
  const productHook = useAdminProducts({
    initialProducts,
    initialAllProducts,
    categories: categoryHook.categories,
    selectedHubId,
    sessionUserId,
    sessionUserRole,
    sessionUserEmail,
    sessionUserPhone,
    activeTab,
  })

  // Orders Hook
  const orderHook = useAdminOrders({
    initialOrders,
    initialOrderCounts,
    selectedHubId,
    orderRefreshKey,
  })

  // Users Hook
  const userHook = useAdminUsers({
    initialUsers,
    initialUserCount: stats?.userCount,
    selectedHubId,
    activeTab,
  })

  // Reviews & Coupons Hook
  const reviewCouponHook = useAdminReviewsCoupons({
    initialReviews,
    initialCoupons,
    activeTab,
  })

  // Fetch settings function
  const fetchSettings = useCallback(async (targetStoreId?: string) => {
    try {
      const activeStore = targetStoreId || selectedHubId
      const storeParam = activeStore && activeStore !== 'all' ? `?storeId=${encodeURIComponent(activeStore)}` : ''
      const res = await fetch(`/api/settings${storeParam}`, { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        setSettingsMap(data)
        if (data.grocery_mart_open !== undefined) {
          setGroceryMartOpen(data.grocery_mart_open === 'true')
        }
        if (data.grocery_auto_timing !== undefined) {
          setGroceryAutoTiming(data.grocery_auto_timing === 'true')
        }
      }
    } catch (err) {
      console.error('Failed to load settings:', err)
    }
  }, [selectedHubId])

  useEffect(() => {
    fetchSettings(selectedHubId)
  }, [fetchSettings, selectedHubId])

  const fetchStoresAndRestaurants = useCallback(() => {
    const storeParam =
      selectedHubId && selectedHubId !== 'all'
        ? `&storeId=${encodeURIComponent(selectedHubId)}`
        : ''
    fetch(`/api/restaurants?all=true${storeParam}`)
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data)) setRestaurantsList(data)
      })
      .catch(console.error)

    fetch('/api/admin/stores')
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data)) {
          setStoresList(data)
          if (sessionAssignedStoreId) {
            setSelectedHubId(sessionAssignedStoreId)
          } else if (isSuperAdmin && urlStoreId && data.some((s) => s.id === urlStoreId)) {
            setSelectedHubId(urlStoreId)
          } else if (initialStoreId && data.some((s) => s.id === initialStoreId)) {
            setSelectedHubId(initialStoreId)
          } else if (
            isSuperAdmin &&
            data.length > 0 &&
            !data.some((s) => s.id === selectedHubId) &&
            selectedHubId !== 'all'
          ) {
            setSelectedHubId(data[0].id)
          }
        }
      })
      .catch(console.error)
  }, [selectedHubId, sessionAssignedStoreId, urlStoreId, initialStoreId, isSuperAdmin])

  useEffect(() => {
    fetchStoresAndRestaurants()
  }, [fetchStoresAndRestaurants])

  const handleToggleGroceryMart = async () => {
    const nextState = !groceryMartOpen
    setIsTogglingStore(true)
    try {
      const res = await fetch('/api/admin/settings', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          grocery_mart_open: nextState ? 'true' : 'false',
          grocery_auto_timing: 'false',
        }),
      })
      if (res.ok) {
        setGroceryMartOpen(nextState)
        setGroceryAutoTiming(false)
        if (selectedHubId && selectedHubId !== 'all') {
          fetch('/api/admin/stores', {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              id: selectedHubId,
              groceryOpen: nextState,
            }),
          }).catch(console.warn)
          setStoresList((prev) =>
            prev.map((s) => (s.id === selectedHubId ? { ...s, groceryOpen: nextState } : s))
          )
        }
        toast.success(
          nextState
            ? '🟢 Grocery Mart is now OPEN for orders!'
            : '🔴 Grocery Mart is now CLOSED.'
        )
      } else {
        toast.error('Failed to update store status')
      }
    } catch (err) {
      toast.error('Error toggling store status')
    } finally {
      setIsTogglingStore(false)
    }
  }

  const handleCloudinaryUpload = async (file: File, onUploadSuccess: (url: string) => void) => {
    setIsUploading(true)
    try {
      const compressedFile = await compressImageClient(file)
      const formData = new FormData()
      formData.append('file', compressedFile)

      const res = await fetch('/api/upload', {
        method: 'POST',
        headers: {
          ...(sessionUserId
            ? { 'x-user-id': sessionUserId, 'x-user-role': sessionUserRole }
            : {}),
        },
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        if (data.url) {
          onUploadSuccess(data.url)
          toast.success('Image uploaded successfully!')
        }
      } else {
        if (res.status === 413) {
          toast.error('Photo is too large (max 4.5MB). Please choose a smaller photo.')
        } else if (res.status === 401) {
          toast.error('Unauthorized: Please log in again.')
        } else {
          const errData = await res.json().catch(() => ({}))
          toast.error(`Upload failed: ${errData.error || res.statusText || 'Server error'}`)
        }
      }
    } catch (err: any) {
      console.error(err)
      toast.error(`Could not upload image: ${err.message || 'Network error'}`)
    } finally {
      setIsUploading(false)
    }
  }

  const handleImageFileChange = (
    form: 'new' | 'edit',
    e: React.ChangeEvent<HTMLInputElement>
  ) => {
    const file = e.target.files?.[0]
    if (!file) return

    handleCloudinaryUpload(file, (url) => {
      if (form === 'new') {
        categoryHook.setNewCategory({ ...categoryHook.newCategory, imageUrl: url })
      } else {
        categoryHook.setCategoryEditForm({ ...categoryHook.categoryEditForm, imageUrl: url })
      }
    })
  }

  const handleOrderStatusChange = async (orderId: string, newStatus: string) => {
    orderHook.setUpdatingOrderId(orderId)
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          ...(sessionUserId
            ? { 'x-user-id': sessionUserId, 'x-user-role': sessionUserRole }
            : {}),
        },
        body: JSON.stringify({ status: newStatus }),
      })

      if (res.ok) {
        const updated = await res.json()
        orderHook.setOrders(
          orderHook.orders.map((o) => (o.id === orderId ? { ...o, status: updated.status } : o))
        )
        setOrderRefreshKey((k) => k + 1)
        toast.success(`Order status updated to ${newStatus}`)
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(errData.detail || errData.error || 'Failed to update order status')
      }
    } catch (err: any) {
      toast.error(err?.message || 'Failed to update status')
    } finally {
      orderHook.setUpdatingOrderId(null)
    }
  }

  const sendCartNotification = async (userId: string, userName: string) => {
    const defaultMsg = `Hey ${userName}! Your items are waiting in your cart. Checkout now for instant delivery! 🛒`
    const message = window.prompt(`Customize push notification for ${userName}:`, defaultMsg)
    if (message === null) return

    try {
      const res = await fetch('/api/admin/live-carts/notify', {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          ...(serverUser?.id ? { 'x-user-id': serverUser.id } : {}),
        },
        body: JSON.stringify({
          userId,
          title: 'Cart Waiting 🛒',
          body: message || defaultMsg,
        }),
      })

      const data = await res.json()
      if (res.ok) {
        toast.success(data.message || 'Push notification sent to customer mobile app & web!')
      } else {
        toast.error(data.error || 'Failed to send push notification')
      }
    } catch (err) {
      toast.error('Failed to send push notification')
    }
  }

  const openWhatsAppModal = (userName: string, phone: string) => {
    if (!phone || phone === 'N/A') {
      toast.error('Customer phone number not available')
      return
    }
    const origin =
      typeof window !== 'undefined' ? window.location.origin : 'https://fastkirana.vercel.app'
    const templates = [
      `Hey ${userName}! 🛒 Your items are waiting in your cart. Checkout now for instant delivery: ${origin}/cart`,
      `Hey ${userName}! 🎁 We saved the items in your cart. Complete your order now and get an extra discount! Use code SAVE10 at checkout: ${origin}/cart`,
      `Hey ${userName}! 👋 We noticed you left some items in your cart. Order now before they sell out! ${origin}/cart`,
    ]
    setWhatsappTargetUser({ name: userName, phone })
    setWhatsappSelectedTemplateIdx(0)
    setWhatsappCustomMessage(templates[0])
    setWhatsappModalOpen(true)
  }

  const handleTemplateSelect = (idx: number) => {
    if (!whatsappTargetUser) return
    const origin =
      typeof window !== 'undefined' ? window.location.origin : 'https://fastkirana.vercel.app'
    const templates = [
      `Hey ${whatsappTargetUser.name}! 🛒 Your items are waiting in your cart. Checkout now for instant delivery: ${origin}/cart`,
      `Hey ${whatsappTargetUser.name}! 🎁 We saved the items in your cart. Complete your order now and get an extra discount! Use code SAVE10 at checkout: ${origin}/cart`,
      `Hey ${whatsappTargetUser.name}! 👋 We noticed you left some items in your cart. Order now before they sell out! ${origin}/cart`,
    ]
    setWhatsappSelectedTemplateIdx(idx)
    setWhatsappCustomMessage(templates[idx])
  }

  const sendWhatsAppMessage = () => {
    if (!whatsappTargetUser) return
    let cleanPhone = getLast10Digits(whatsappTargetUser.phone)
    if (cleanPhone.length === 10) {
      cleanPhone = '91' + cleanPhone
    }
    const whatsappUrl = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(
      whatsappCustomMessage
    )}`
    window.open(whatsappUrl, '_blank')
    setWhatsappModalOpen(false)
    setWhatsappTargetUser(null)
  }

  const renderPagination = (
    currentPage: number,
    totalItems: number,
    itemsPerPage: number,
    onPageChange: (p: number) => void
  ) => {
    const totalPages = Math.ceil(totalItems / itemsPerPage)
    if (totalPages <= 1) return null

    return (
      <div className="flex justify-between items-center mt-5 border-t border-border/40 pt-4 bg-card">
        <span className="text-[10px] font-bold text-text-secondary">
          Showing page {currentPage} of {totalPages} ({totalItems} items)
        </span>
        <div className="flex gap-1.5">
          <button
            type="button"
            onClick={() => onPageChange(Math.max(1, currentPage - 1))}
            disabled={currentPage === 1}
            className="px-3 py-1.5 text-[10px] font-black rounded-lg border bg-card hover:bg-muted text-text-secondary disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed select-none transition-colors"
          >
            Previous
          </button>
          <button
            type="button"
            onClick={() => onPageChange(Math.min(totalPages, currentPage + 1))}
            disabled={currentPage === totalPages}
            className="px-3 py-1.5 text-[10px] font-black rounded-lg border bg-card hover:bg-muted text-text-secondary disabled:opacity-50 cursor-pointer disabled:cursor-not-allowed select-none transition-colors"
          >
            Next
          </button>
        </div>
      </div>
    )
  }

  // Parse cafe menu sections dynamically
  const CAFE_MENU_SECTIONS = useMemo(() => {
    const customSectionsStr =
      settingsMap['cafe_menu_sections'] || settingsMap['CAFE_MENU_SECTIONS']
    if (customSectionsStr) {
      try {
        const parsed = JSON.parse(customSectionsStr)
        if (Array.isArray(parsed) && parsed.length > 0) return parsed
      } catch (e) {
        console.error('Error parsing CAFE_MENU_SECTIONS:', e)
      }
    }
    return DEFAULT_CAFE_MENU_SECTIONS
  }, [settingsMap])

  // Parse restaurant menu sections dynamically
  const RESTAURANT_MENU_SECTIONS = useMemo(() => {
    const customSectionsStr =
      settingsMap['restaurant_menu_sections'] || settingsMap['RESTAURANT_MENU_SECTIONS']
    if (customSectionsStr) {
      try {
        const parsed = JSON.parse(customSectionsStr)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed.map((s: any) => ({
            ...s,
            title: s.title ? s.title.replace(/Wedson/gi, '').trim() : s.title,
          }))
        }
      } catch (e) {
        console.error('Error parsing RESTAURANT_MENU_SECTIONS:', e)
      }
    }
    return []
  }, [settingsMap])

  // Media Library images
  const mediaLibraryImages = useMemo(() => {
    const setOfImages = new Map<string, { url: string; name: string; tags?: string[] }>()
    PRESET_KITCHEN_PHOTOS.forEach((preset) => {
      setOfImages.set(preset.url, { url: preset.url, name: preset.name, tags: preset.tags })
    })
    productHook.allProducts.forEach((p) => {
      if (p.imageUrl && p.imageUrl.startsWith('http') && !setOfImages.has(p.imageUrl)) {
        setOfImages.set(p.imageUrl, {
          url: p.imageUrl,
          name: p.name || 'Product Image',
          tags: p.tags || [],
        })
      }
    })
    categoryHook.categories.forEach((c) => {
      if (c.imageUrl && c.imageUrl.startsWith('http') && !setOfImages.has(c.imageUrl)) {
        setOfImages.set(c.imageUrl, { url: c.imageUrl, name: c.name || 'Category Image' })
      }
    })
    return Array.from(setOfImages.values())
  }, [productHook.allProducts, categoryHook.categories])

  const filteredMediaImages = useMemo(() => {
    if (!mediaSearchQuery.trim()) return mediaLibraryImages
    const q = mediaSearchQuery.toLowerCase().trim()
    return mediaLibraryImages.filter(
      (img) =>
        img.name.toLowerCase().includes(q) ||
        img.url.toLowerCase().includes(q) ||
        (img.tags && img.tags.some((t) => t.toLowerCase().includes(q)))
    )
  }, [mediaLibraryImages, mediaSearchQuery])

  // Filtered Products
  const filteredProducts = useMemo(() => {
    return (Array.isArray(productHook.products) ? productHook.products : []).filter((p) => {
      const matchesSearch =
        p.name.toLowerCase().includes(productHook.searchQuery.toLowerCase()) ||
        (p.description &&
          p.description.toLowerCase().includes(productHook.searchQuery.toLowerCase()))

      const matchesCategory =
        !productHook.selectedCategoryFilter ||
        p.categoryId === productHook.selectedCategoryFilter

      const isCafeItem = p.tags?.some((t: string) => t.toLowerCase() === 'cafe')
      const isRestaurantItem =
        !!p.restaurantId || p.tags?.some((t: string) => t.toLowerCase() === 'restaurant')

      let matchesType = true
      if (productHook.selectedTypeFilter === 'all') {
        matchesType = true
      } else if (productHook.selectedTypeFilter === 'grocery') {
        matchesType = !isCafeItem && !isRestaurantItem
      } else if (productHook.selectedTypeFilter === 'cafe') {
        matchesType = isCafeItem
      } else if (productHook.selectedTypeFilter === 'restaurant') {
        matchesType = isRestaurantItem
      } else {
        matchesType =
          p.restaurantId === productHook.selectedTypeFilter ||
          (p as any).restaurant?.id === productHook.selectedTypeFilter ||
          (p as any).restaurant?.slug === productHook.selectedTypeFilter ||
          (productHook.selectedTypeFilter.toLowerCase().includes('bal') &&
            ((p.restaurantId && p.restaurantId.toLowerCase().includes('bal')) ||
              p.name?.toLowerCase().includes('bal udyan')))
      }

      return matchesSearch && matchesCategory && matchesType
    })
  }, [
    productHook.products,
    productHook.searchQuery,
    productHook.selectedCategoryFilter,
    productHook.selectedTypeFilter,
  ])

  // Current active orders count
  const currentActiveOrdersCount = useMemo(() => {
    if (orderHook.orderCounts) {
      const pending = orderHook.orderCounts.PENDING || 0
      const confirmed = orderHook.orderCounts.CONFIRMED || 0
      const packed = orderHook.orderCounts.PACKED || 0
      const shipped = orderHook.orderCounts.SHIPPED || 0
      return pending + confirmed + packed + shipped
    }
    return stats.activeOrderCount || 0
  }, [orderHook.orderCounts, stats.activeOrderCount])

  const tabConfig = useMemo(() => {
    return [
      { key: 'orders' as TabType, label: 'Orders', icon: ShoppingBag, count: orderHook.orderTotal },
      { key: 'liveops' as TabType, label: 'Live Ops Tracker', icon: Zap, count: activeCartsCount },
      { key: 'products' as TabType, label: 'Products', icon: Package, count: productHook.productTotal },
      { key: 'categories' as TabType, label: 'Categories', icon: Layers, count: categoryHook.categories.length },
      { key: 'alerts' as TabType, label: 'Stock Alerts', icon: AlertCircle, count: stats.lowStockCount },
      { key: 'inward' as TabType, label: 'Inward Items (GRN)', icon: Building2 },
      { key: 'vendors' as TabType, label: 'Vendor Console', icon: Truck },
      { key: 'bulk-update' as TabType, label: 'Bulk Update', icon: SlidersHorizontal },
      { key: 'csv-import' as TabType, label: 'CSV Import', icon: Download },
      { key: 'restaurant-report' as TabType, label: 'Restaurant Payout', icon: Utensils },
      { key: 'reports' as TabType, label: 'Ledger Report', icon: FileText },
      { key: 'users' as TabType, label: 'Staff & Customers', icon: Users, count: userHook.userTotal },
      { key: 'rider-cash' as TabType, label: 'Rider Cash & Settlement', icon: Wallet },
      { key: 'reviews' as TabType, label: 'Reviews', icon: Star, count: reviewCouponHook.reviews.length },
      { key: 'coupons' as TabType, label: 'Offers', icon: Ticket, count: reviewCouponHook.coupons.length },
      { key: 'banners' as TabType, label: 'Promo Banners', icon: ImageIcon },
      { key: 'flash-deals' as TabType, label: 'Store Highlights', icon: Zap },
      { key: 'push-notifications' as TabType, label: 'Push Notifications', icon: Bell },
      { key: 'settings' as TabType, label: 'Store Settings', icon: Settings },
      { key: 'analytics' as TabType, label: 'Analytics', icon: TrendingUp },
      { key: 'forecast' as TabType, label: 'AI Forecasting', icon: BrainCircuit },
    ]
  }, [
    orderHook.orderTotal,
    activeCartsCount,
    productHook.productTotal,
    categoryHook.categories.length,
    stats.lowStockCount,
    userHook.userTotal,
    reviewCouponHook.reviews.length,
    reviewCouponHook.coupons.length,
  ])

  const activeStoreHub =
    storesList.find((s) => s.id === selectedHubId) ||
    (selectedHubId && selectedHubId !== 'all'
      ? {
          id: selectedHubId,
          name:
            selectedHubId
              .replace(/^hub-/, '')
              .replace(/[-_]/g, ' ')
              .replace(/\b\w/g, (c) => c.toUpperCase()) + ' Hub',
        }
      : storesList[0] || { id: 'hub-209206', name: 'Store Hub' })

  const rawHubName = activeStoreHub?.name || 'Store Hub'
  const hubCity = rawHubName
    ? rawHubName.replace(/\s*(central\s*hub|dark\s*store|hub|store)\s*/gi, '').trim().toLowerCase()
    : ''
  const hubRestaurants = (Array.isArray(restaurantsList) ? restaurantsList : []).filter((r) => {
    if (!hubCity) return false
    return r.city && r.city.toLowerCase().trim().includes(hubCity)
  })

  return (
    <div className="space-y-6">
      <BottleneckBanner
        delayedOrders={delayedOrders}
        pickerDelays={pickerDelays}
        chefDelays={chefDelays}
        riderDelays={riderDelays}
        livePendingOrders={livePendingOrders}
        isChimeMuted={isChimeMuted}
        onToggleChime={() => setIsChimeMuted(!isChimeMuted)}
        onInspectOrder={(orderId) => {
          setActiveTab('orders')
          orderHook.setOrderStatusFilter('ALL')
          orderHook.setOrderSearchQuery(orderId)
        }}
      />

      <StoreControlBar
        storeHubName={rawHubName}
        storesList={storesList}
        restaurantsList={hubRestaurants}
        selectedHubId={selectedHubId}
        onSelectHub={handleSelectHub}
        onOpenHubManager={() => setIsStoreHubsModalOpen(true)}
        isSuperAdmin={isSuperAdmin}
        groceryMartOpen={
          groceryAutoTiming
            ? groceryMartOpen
            : (activeStoreHub as any)?.groceryOpen !== undefined
            ? (activeStoreHub as any).groceryOpen
            : groceryMartOpen
        }
        groceryAutoTiming={groceryAutoTiming}
        isTogglingStore={isTogglingStore}
        onToggleGroceryMart={handleToggleGroceryMart}
        onOpenSettings={() => setActiveTab('settings')}
        onOpenCreateOrder={() => setIsCreateOrderOpen(true)}
        onOpenInward={() => setActiveTab('inward')}
        isChimeMuted={isChimeMuted}
        onToggleChime={() => setIsChimeMuted(!isChimeMuted)}
        userAssignedStoreId={sessionAssignedStoreId}
      />

      <DashboardStatsCards
        stats={{
          todaySales: orderHook.apiTodaySales ?? stats?.todaySales ?? 0,
          todayOrdersCount: orderHook.apiTodayOrdersCount ?? stats?.todayOrdersCount ?? 0,
          netSales: orderHook.apiTodayNetSales ?? stats?.netSales ?? 0,
          todayDeliveryFee:
            orderHook.apiTodayDeliveryFee ?? (stats as any)?.todayDeliveryFee ?? 0,
          todayPackagingFee:
            orderHook.apiTodayPackagingFee ?? (stats as any)?.todayPackagingFee ?? 0,
          groceryRevenue: stats?.groceryRevenue ?? 0,
          restaurantRevenue: stats?.restaurantRevenue ?? 0,
          orderCount: stats?.orderCount || orderHook.orderTotal || 0,
          activeOrderCount: currentActiveOrdersCount,
        }}
      />

      <DashboardHubNav
        activeHub={activeHub}
        setActiveHub={setActiveHub}
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        hubs={HUB_CONFIG}
        tabConfig={tabConfig}
      />

      <AnimatePresence mode="wait">
        <motion.div
          key={activeTab}
          initial={{ opacity: 0, y: 15 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -15 }}
          transition={{ duration: 0.25, ease: 'easeInOut' }}
          className="w-full"
        >
          {(activeTab === 'orders' || activeTab === 'liveops') && (
            <AdminLiveOrdersTab
              activeTab={activeTab}
              orders={orderHook.orders}
              orderCounts={orderHook.orderCounts}
              orderStatusFilter={orderHook.orderStatusFilter}
              setOrderStatusFilter={orderHook.setOrderStatusFilter}
              orderSearchQuery={orderHook.orderSearchQuery}
              setOrderSearchQuery={orderHook.setOrderSearchQuery}
              orderShopFilter={orderHook.orderShopFilter}
              setOrderShopFilter={orderHook.setOrderShopFilter}
              orderMethodFilter={orderHook.orderMethodFilter}
              setOrderMethodFilter={orderHook.setOrderMethodFilter}
              ordersSubTab={orderHook.ordersSubTab}
              setOrdersSubTab={orderHook.setOrdersSubTab}
              updatingOrderId={orderHook.updatingOrderId}
              onUpdateOrderStatus={handleOrderStatusChange}
              onOpenOrderModal={orderHook.handleOpenOrderModal}
              onOpenCreateOrderModal={() => setIsCreateOrderOpen(true)}
              onNavigateToUsersTab={() => setActiveTab('users')}
              livePendingOrders={livePendingOrders}
              liveOrders={liveOrders}
              delayedOrders={delayedOrders}
              activeCarts={activeCarts}
              isLoadingCarts={isLoadingCarts}
              cartsRefreshKey={cartsRefreshKey}
              setCartsRefreshKey={setCartsRefreshKey}
              sendCartNotification={sendCartNotification}
              openWhatsAppModal={openWhatsAppModal}
            />
          )}

          {(activeTab === 'products' ||
            activeTab === 'categories' ||
            activeTab === 'alerts' ||
            activeTab === 'inward' ||
            activeTab === 'bulk-update' ||
            activeTab === 'csv-import') && (
            <AdminInventoryHubTab
              activeTab={activeTab}
              selectedHubId={selectedHubId}
              onRefreshProducts={async () => {
                try {
                  const storeQuery =
                    selectedHubId && selectedHubId !== 'all'
                      ? `&storeId=${encodeURIComponent(selectedHubId)}`
                      : ''
                  const res = await fetch(
                    `/api/products?limit=1000${storeQuery}&t=${Date.now()}`
                  )
                  if (res.ok) {
                    const data = await res.json()
                    if (data.products) {
                      productHook.setProducts(data.products)
                      productHook.setAllProducts(data.products)
                    }
                  }
                } catch (err) {
                  console.error(err)
                }
              }}
              productProps={{
                products: productHook.products,
                categories: categoryHook.categories,
                restaurantsList: hubRestaurants,
                settingsMap: settingsMap,
                filteredProducts: filteredProducts,
                searchQuery: productHook.searchQuery,
                selectedTypeFilter: productHook.selectedTypeFilter,
                selectedCategoryFilter: productHook.selectedCategoryFilter,
                showAddProduct: productHook.showAddProduct,
                showSortManager: productHook.showSortManager,
                showCsvImport: productHook.showCsvImport,
                showExportModal: productHook.showExportModal,
                isExporting: productHook.isExporting,
                isCreatingProduct: productHook.isCreatingProduct,
                newProduct: productHook.newProduct,
                newProductType: productHook.newProductType,
                editProductType: productHook.editProductType,
                newProductVariants: productHook.newProductVariants,
                editProductVariants: productHook.editProductVariants,
                hasVariantsNew: productHook.hasVariantsNew,
                hasVariantsEdit: productHook.hasVariantsEdit,
                newCustomTag: productHook.newCustomTag,
                editCustomTag: productHook.editCustomTag,
                isUploading: isUploading,
                productPage: productHook.productPage,
                productTotal: productHook.productTotal,
                editingProduct: productHook.editingProduct,
                savingProductId: productHook.savingProductId,
                setShowAddProduct: productHook.setShowAddProduct,
                setShowSortManager: productHook.setShowSortManager,
                setShowCsvImport: productHook.setShowCsvImport,
                setShowExportModal: productHook.setShowExportModal,
                setNewProduct: productHook.setNewProduct,
                setNewProductType: productHook.setNewProductType,
                setEditProductType: productHook.setEditProductType,
                setNewProductVariants: productHook.setNewProductVariants,
                setEditProductVariants: productHook.setEditProductVariants,
                setHasVariantsNew: productHook.setHasVariantsNew,
                setHasVariantsEdit: productHook.setHasVariantsEdit,
                setNewCustomTag: productHook.setNewCustomTag,
                setEditingProduct: productHook.setEditingProduct,
                setProductPage: productHook.setProductPage,
                setMediaTarget: setMediaTarget,
                setShowMediaLibrary: setShowMediaLibrary,
                setSearchQuery: productHook.setSearchQuery,
                setSelectedTypeFilter: productHook.setSelectedTypeFilter,
                setSelectedCategoryFilter: productHook.setSelectedCategoryFilter,
                setProducts: productHook.setProducts,
                setAllProducts: productHook.setAllProducts,
                handleNewProductTypeChange: productHook.handleNewProductTypeChange,
                handleEditProductTypeChange: productHook.handleEditProductTypeChange,
                applyProductTemplate: productHook.applyProductTemplate,
                toggleTag: productHook.toggleTag,
                handleCreateCustomTag: productHook.handleCreateCustomTag,
                handleCreateProduct: productHook.handleCreateProduct,
                handleToggleProductAvailability: productHook.handleToggleProductAvailability,
                handleDeleteProduct: productHook.handleDeleteProduct,
                startEditingProduct: productHook.startEditingProduct,
                handleDuplicateProduct: productHook.handleDuplicateProduct,
                handleCloudinaryUpload: handleCloudinaryUpload,
                handleExportCsv: productHook.handleExportCsv,
                handleReplenishCsv: productHook.handleReplenishCsv,
                renderPagination: renderPagination,
              }}
              categoryProps={{
                categories: categoryHook.categories,
                newCategory: categoryHook.newCategory,
                showAddCategory: categoryHook.showAddCategory,
                editingCategory: categoryHook.editingCategory,
                savingCategoryId: categoryHook.savingCategoryId,
                deletingCategoryId: categoryHook.deletingCategoryId,
                categoryEditForm: categoryHook.categoryEditForm,
                isCreatingCategory: categoryHook.isCreatingCategory,
                showMediaLibrary: showMediaLibrary,
                mediaTarget: mediaTarget,
                mediaSearchQuery: mediaSearchQuery,
                setNewCategory: categoryHook.setNewCategory,
                setShowAddCategory: categoryHook.setShowAddCategory,
                setEditingCategory: categoryHook.setEditingCategory,
                setCategoryEditForm: categoryHook.setCategoryEditForm,
                setSavingCategoryId: categoryHook.setSavingCategoryId,
                setDeletingCategoryId: categoryHook.setDeletingCategoryId,
                setMediaTarget: setMediaTarget,
                setShowMediaLibrary: setShowMediaLibrary,
                handleCreateCategory: categoryHook.handleCreateCategory,
                handleDeleteCategory: categoryHook.handleDeleteCategory,
                saveCategoryChanges: categoryHook.saveCategoryChanges,
                startEditingCategory: categoryHook.startEditingCategory,
                handleImageFileChange: handleImageFileChange,
              }}
            />
          )}

          {activeTab === 'users' && (
            <UsersTab
              users={userHook.users}
              userPage={userHook.userPage}
              userTotal={userHook.userTotal}
              userSearch={userHook.userSearch}
              userRoleFilter={userHook.userRoleFilter}
              userStatusFilter={userHook.userStatusFilter}
              isExportingUsers={userHook.isExportingUsers}
              editingPhoneUserId={userHook.editingPhoneUserId}
              phoneInput={userHook.phoneInput}
              savingPhoneId={userHook.savingPhoneId}
              settingPasswordUserId={userHook.settingPasswordUserId}
              passwordInput={userHook.passwordInput}
              savingPasswordId={userHook.savingPasswordId}
              isUpdatingBlockStatus={userHook.isUpdatingBlockStatus}
              setUserPage={userHook.setUserPage}
              setUserSearch={userHook.setUserSearch}
              setUserRoleFilter={userHook.setUserRoleFilter}
              setUserStatusFilter={userHook.setUserStatusFilter}
              setEditingPhoneUserId={userHook.setEditingPhoneUserId}
              setPhoneInput={userHook.setPhoneInput}
              setSettingPasswordUserId={userHook.setSettingPasswordUserId}
              setPasswordInput={userHook.setPasswordInput}
              handleExportCustomersCsv={userHook.handleExportCustomersCsv}
              handleUserPhoneSave={userHook.handleUserPhoneSave}
              handleUserRoleChange={userHook.handleUserRoleChange}
              handleUserStoreChange={userHook.handleUserStoreChange}
              handleSetPassword={userHook.handleSetPassword}
              handleToggleBlock={userHook.handleToggleBlock}
              onRequestBlock={userHook.setBlockingUser}
              renderPagination={renderPagination}
              stores={storesList}
            />
          )}

          {activeTab === 'reviews' && (
            <ReviewsTab
              reviews={reviewCouponHook.reviews}
              reviewSearch={reviewCouponHook.reviewSearch}
              setReviewSearch={reviewCouponHook.setReviewSearch}
              isLoadingReviews={reviewCouponHook.isLoadingReviews}
              deletingReviewId={reviewCouponHook.deletingReviewId}
              startEditingReview={reviewCouponHook.startEditingReview}
              handleDeleteReview={reviewCouponHook.handleDeleteReview}
            />
          )}

          {activeTab === 'coupons' && (
            <CouponsTab
              coupons={reviewCouponHook.coupons}
              categories={categoryHook.categories}
              showAddCoupon={reviewCouponHook.showAddCoupon}
              isCreatingCoupon={reviewCouponHook.isCreatingCoupon}
              isLoadingCoupons={reviewCouponHook.isLoadingCoupons}
              savingCouponId={reviewCouponHook.savingCouponId}
              deletingCouponId={reviewCouponHook.deletingCouponId}
              newCoupon={reviewCouponHook.newCoupon}
              editingCoupon={reviewCouponHook.editingCoupon}
              couponEditForm={reviewCouponHook.couponEditForm}
              setShowAddCoupon={reviewCouponHook.setShowAddCoupon}
              setNewCoupon={reviewCouponHook.setNewCoupon}
              setEditingCoupon={reviewCouponHook.setEditingCoupon}
              setCouponEditForm={reviewCouponHook.setCouponEditForm}
              handleCreateCoupon={reviewCouponHook.handleCreateCoupon}
              saveCouponChanges={reviewCouponHook.saveCouponChanges}
              handleToggleCoupon={reviewCouponHook.handleToggleCoupon}
              handleDeleteCoupon={reviewCouponHook.handleDeleteCoupon}
              startEditingCoupon={reviewCouponHook.startEditingCoupon}
            />
          )}

          {(activeTab === 'reports' ||
            activeTab === 'restaurant-report' ||
            activeTab === 'analytics' ||
            activeTab === 'forecast') && (
            <AdminReportsTab
              activeTab={activeTab}
              storeId={selectedHubId}
              products={productHook.allProducts || []}
              orders={liveOrders || []}
              categories={categoryHook.categories || []}
              stats={{
                revenue:
                  (typeof orderHook.apiTodaySales === 'number'
                    ? orderHook.apiTodaySales
                    : stats?.revenue) ??
                  stats?.todaySales ??
                  0,
                orderCount:
                  (typeof orderHook.apiTodayOrdersCount === 'number'
                    ? orderHook.apiTodayOrdersCount
                    : (orderHook.orders || []).length) ?? 0,
                lowStockCount: stats?.lowStockCount ?? 0,
              }}
              onRestockCompleted={async () => {
                try {
                  const storeQuery =
                    selectedHubId && selectedHubId !== 'all'
                      ? `&storeId=${encodeURIComponent(selectedHubId)}`
                      : ''
                  const res = await fetch(
                    `/api/products?limit=1000${storeQuery}&t=${Date.now()}`
                  )
                  if (res.ok) {
                    const data = await res.json()
                    if (data.products) {
                      productHook.setProducts(data.products)
                      productHook.setAllProducts(data.products)
                    }
                  }
                } catch (err) {
                  console.error(err)
                }
              }}
            />
          )}

          {activeTab === 'banners' && (
            <BannersTab
              categories={categoryHook.categories}
              products={productHook.allProducts}
            />
          )}

          {activeTab === 'settings' && (
            <AdminDarkStoresTab
              storeId={selectedHubId}
              storeHubName={rawHubName}
              onSettingsSaved={() => fetchSettings(selectedHubId)}
            />
          )}

          {activeTab === 'push-notifications' && <PushNotificationsTab />}

          {activeTab === 'flash-deals' && <FlashDealsTab />}

          {activeTab === 'rider-cash' && <AdminRidersFleetTab storeId={selectedHubId} />}

          {activeTab === 'restaurant-console' && (
            <RestaurantConsoleTab storeId={selectedHubId} />
          )}

          {activeTab === 'vendors' && <VendorConsoleTab storeId={selectedHubId} />}
        </motion.div>
      </AnimatePresence>

      {/* Product Edit Modal */}
      {productHook.editingProduct && (
        <ProductEditModal
          editingProduct={productHook.editingProduct}
          productEditForm={productHook.productEditForm}
          saveProductChanges={productHook.saveProductChanges}
          setEditingProduct={productHook.setEditingProduct}
          setProductEditForm={productHook.setProductEditForm}
          setHasVariantsEdit={productHook.setHasVariantsEdit}
          setEditProductVariants={productHook.setEditProductVariants}
          setNewCustomTag={productHook.setNewCustomTag}
          setShowMediaLibrary={setShowMediaLibrary}
          setMediaTarget={setMediaTarget}
          handleCloudinaryUpload={handleCloudinaryUpload}
          handleCreateCustomTag={productHook.handleCreateCustomTag}
          toggleTag={productHook.toggleTag}
          savingProductId={productHook.savingProductId}
          isUploading={isUploading}
          isEditProductCafe={productHook.isEditProductCafe}
          isEditProductRestaurant={productHook.isEditProductRestaurant}
          restaurantsList={hubRestaurants}
          categories={categoryHook.categories}
          settingsMap={settingsMap}
          editProductVariants={productHook.editProductVariants}
          hasVariantsEdit={productHook.hasVariantsEdit}
          newCustomTag={productHook.newCustomTag}
          RESTAURANT_MENU_SECTIONS={RESTAURANT_MENU_SECTIONS}
          PRESET_KITCHEN_PHOTOS={PRESET_KITCHEN_PHOTOS}
        />
      )}

      {/* Category Edit Modal */}
      {categoryHook.editingCategory && (
        <CategoryEditModal
          editingCategory={categoryHook.editingCategory}
          categoryEditForm={categoryHook.categoryEditForm}
          categories={categoryHook.categories}
          savingCategoryId={categoryHook.savingCategoryId}
          handleImageFileChange={handleImageFileChange}
          saveCategoryChanges={categoryHook.saveCategoryChanges}
          setEditingCategory={categoryHook.setEditingCategory}
          setCategoryEditForm={categoryHook.setCategoryEditForm}
        />
      )}

      {/* Review Edit Modal */}
      {reviewCouponHook.editingReview && (
        <ReviewEditModal
          editingReview={reviewCouponHook.editingReview}
          reviewEditForm={reviewCouponHook.reviewEditForm}
          savingReviewId={reviewCouponHook.savingReviewId}
          saveReviewChanges={reviewCouponHook.saveReviewChanges}
          setEditingReview={reviewCouponHook.setEditingReview}
          setReviewEditForm={reviewCouponHook.setReviewEditForm}
        />
      )}

      {/* WhatsApp Modal */}
      <WhatsAppAlertModal
        isOpen={whatsappModalOpen}
        targetUser={whatsappTargetUser}
        selectedTemplateIdx={whatsappSelectedTemplateIdx}
        customMessage={whatsappCustomMessage}
        onClose={() => {
          setWhatsappModalOpen(false)
          setWhatsappTargetUser(null)
        }}
        onSelectTemplate={handleTemplateSelect}
        onCustomMessageChange={setWhatsappCustomMessage}
        onSendMessage={sendWhatsAppMessage}
      />

      {/* Block Customer Modal */}
      {userHook.blockingUser && (
        <BlockCustomerModal
          blockingUser={userHook.blockingUser}
          blockReasonInput={userHook.blockReasonInput}
          isUpdatingBlockStatus={userHook.isUpdatingBlockStatus}
          setBlockingUser={userHook.setBlockingUser}
          setBlockReasonInput={userHook.setBlockReasonInput}
          handleToggleBlock={userHook.handleToggleBlock}
        />
      )}

      {/* Order Tracking Modal */}
      {orderHook.selectedOrderForTracking && (
        <OrderTrackingModal
          selectedOrderForTracking={orderHook.selectedOrderForTracking}
          isLoadingOrderItems={orderHook.isLoadingOrderItems}
          setSelectedOrderForTracking={orderHook.setSelectedOrderForTracking}
        />
      )}

      {/* Create Order Modal */}
      <CreateOrderModal
        isOpen={isCreateOrderOpen}
        onClose={() => setIsCreateOrderOpen(false)}
        onSuccess={() => {
          setOrderRefreshKey((prev) => prev + 1)
        }}
      />

      {/* Admin Sort Manager */}
      <AdminSortManager
        isOpen={productHook.showSortManager}
        onClose={() => productHook.setShowSortManager(false)}
        categories={categoryHook.categories}
      />

      {/* Media Library Modal */}
      <MediaLibraryModal
        showMediaLibrary={showMediaLibrary}
        filteredMediaImages={filteredMediaImages}
        mediaSearchQuery={mediaSearchQuery}
        mediaTarget={mediaTarget}
        setShowMediaLibrary={setShowMediaLibrary}
        setMediaSearchQuery={setMediaSearchQuery}
        setMediaTarget={setMediaTarget}
        onSelectImage={(url, target) => {
          if (target === 'newProduct') {
            productHook.setNewProduct((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'editProduct') {
            productHook.setProductEditForm((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'newCategory') {
            categoryHook.setNewCategory((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'editCategory' || target === 'category') {
            categoryHook.setCategoryEditForm((prev) => ({ ...prev, imageUrl: url }))
          }
        }}
      />

      {/* Store Hubs Manager */}
      <StoreHubsManager
        isOpen={isStoreHubsModalOpen}
        onClose={() => setIsStoreHubsModalOpen(false)}
        stores={storesList}
        restaurants={hubRestaurants}
        selectedHubId={selectedHubId}
        isHubAdmin={!isSuperAdmin}
        assignedStoreId={sessionAssignedStoreId}
        onSelectHub={(hubId) => {
          if (isSuperAdmin) {
            handleSelectHub(hubId)
          }
          setIsStoreHubsModalOpen(false)
        }}
        onRefresh={fetchStoresAndRestaurants}
      />
    </div>
  )
}
