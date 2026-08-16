'use client'

import { useState, useEffect, useMemo, useRef, useCallback } from 'react'
import { formatPrice, formatAddress, formatDisplayEmail } from '@/lib/utils'
import { formatOrderTime, formatDate } from '@/lib/date-helpers'
import { ORDER_STATUS_LABELS, DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS, PRODUCT_TEMPLATES, HUB_CONFIG } from '@/lib/constants'
import { DashboardHubNav } from '@/components/admin/dashboard/hub-nav'
import { DashboardStatsCards } from '@/components/admin/dashboard/stats-cards'
import { OrdersTab } from '@/components/admin/dashboard/orders-tab'
import { LiveCartsPanel } from '@/components/admin/dashboard/live-carts-panel'
import { CategoriesTab } from '@/components/admin/categories-tab'
import { UsersTab } from '@/components/admin/users-tab'
import { CouponsTab } from '@/components/admin/coupons-tab'
import { ProductsTab } from '@/components/admin/products-tab'
import { LiveOpsTab } from '@/components/admin/live-ops-tab'
import { AnalyticsTab } from '@/components/admin/analytics-tab'
import { ForecastTab } from '@/components/admin/forecast-tab'
import { AlertsTab } from '@/components/admin/alerts-tab'
import { InwardTab } from '@/components/admin/inward-tab'
import { BulkUpdateTab } from '@/components/admin/bulk-update-tab'
import { ReportsTab } from '@/components/admin/reports-tab'
import { RestaurantReportTab } from '@/components/admin/restaurant-report-tab'
import { BannersTab } from '@/components/admin/banners-tab'
import { SettingsTab } from '@/components/admin/settings-tab'
import { PushNotificationsTab } from '@/components/admin/push-notifications-tab'
import { FlashDealsTab } from '@/components/admin/flash-deals-tab'
import { RiderCashTab } from '@/components/admin/rider-cash-tab'
import { CsvImportTab } from '@/components/admin/csv-import-tab'
import { RestaurantConsoleTab } from '@/components/admin/restaurant-console-tab'
import { WhatsAppAlertModal } from '@/components/admin/dashboard/whatsapp-alert-modal'
import { printKOTReceipt, printCustomerInvoice } from '@/lib/kot-print'
import { toast } from 'sonner'
import { PRESET_KITCHEN_PHOTOS } from '@/lib/preset-photos'
import { 
  Loader2, 
  Search, 
  Plus, 
  Save, 
  Trash, 
  ShoppingBag, 
  Package, 
  Layers, 
  Users, 
  PlusCircle, 
  Check, 
  X,
  Download,
  TrendingUp,
  Zap,
  AlertCircle,
  Star,
  Ticket,
  Eye,
  ToggleLeft,
  ToggleRight,
  Pencil,
  Calendar,
  Percent,
  IndianRupee,
  MessageSquare,
  SlidersHorizontal,
  FileText,
  Building2,
  Image as ImageIcon,
  Sparkles,
  Settings,
  Volume2,
  VolumeX,
  Clock,
  Utensils,
  Coffee,
  Bell,
  BrainCircuit,
  RefreshCw,
  Wallet,
} from 'lucide-react'
import Link from 'next/link'
import { motion, AnimatePresence } from 'framer-motion'
import dynamic from 'next/dynamic'
import { CreateOrderModal } from './create-order-modal'
import ProductEditModal from './product-edit-modal'
import { CategoryEditModal } from './category-edit-modal'
import { ReviewEditModal } from './review-edit-modal'
import { BlockCustomerModal } from './block-customer-modal'
import OrderTrackingModal from './order-tracking-modal'
import MediaLibraryModal from './media-library-modal'
import { AdminSortManager } from './admin-sort-manager'
import { getLast10Digits } from '@/lib/phone'

interface AdminDashboardProps {
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
    orderCount: number
    activeOrderCount?: number
    userCount: number
    lowStockCount: number
  }
}

type TabType = 'orders' | 'products' | 'categories' | 'users' | 'reviews' | 'coupons' | 'analytics' | 'alerts' | 'bulk-update' | 'reports' | 'restaurant-report' | 'inward' | 'banners' | 'settings' | 'liveops' | 'push-notifications' | 'flash-deals' | 'forecast' | 'rider-cash' | 'restaurant-console' | 'csv-import'

export function AdminDashboard({
  initialOrders,
  initialProducts,
  initialCategories,
  initialUsers,
  initialReviews,
  initialCoupons,
  allProducts: initialAllProducts,
  initialOrderCounts,
  stats
}: AdminDashboardProps) {
  const [activeTab, setActiveTab] = useState<TabType>('orders')
  const [activeHub, setActiveHub] = useState<'orders_hub' | 'grocery' | 'food' | 'insights' | 'people' | 'marketing'>('orders_hub')

  // Auto-synchronize activeHub when activeTab changes (e.g. from deep links, searches, chimes)
  useEffect(() => {
    const parentHub = HUB_CONFIG.find((hub) =>
      (hub.tabs as readonly string[]).includes(activeTab)
    )
    if (parentHub && parentHub.key !== activeHub) {
      setActiveHub(parentHub.key as any)
    }
  }, [activeTab, activeHub])


  
  // States for Orders
  const [orders, setOrders] = useState(initialOrders || [])
  const [orderCounts, setOrderCounts] = useState<Record<string, number>>(() => {
    if (initialOrderCounts) return initialOrderCounts
    const ordersList = initialOrders || []
    return {
      ALL: ordersList.length,
      PENDING: ordersList.filter((o: any) => o.status === 'PENDING').length,
      CONFIRMED: ordersList.filter((o: any) => o.status === 'CONFIRMED').length,
      PACKED: ordersList.filter((o: any) => o.status === 'PACKED').length,
      SHIPPED: ordersList.filter((o: any) => o.status === 'SHIPPED').length,
      DELIVERED: ordersList.filter((o: any) => o.status === 'DELIVERED').length,
      CANCELLED: ordersList.filter((o: any) => o.status === 'CANCELLED').length,
    }
  })
  const [liveOrders, setLiveOrders] = useState<any[]>(initialOrders || [])
  
  // Memoized live pending orders sorted by creation time (strict FIFO)
  const livePendingOrders = useMemo(() => {
    return liveOrders
      .filter((o: any) => o.status === 'PENDING')
      .sort((a: any, b: any) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime())
  }, [liveOrders])

  const [orderRefreshKey, setOrderRefreshKey] = useState(0)
  const [updatingOrderId, setUpdatingOrderId] = useState<string | null>(null)
  const [isChimeMuted, setIsChimeMuted] = useState(false)
  const [orderStatusFilter, setOrderStatusFilter] = useState('ALL')
  const [orderSearchQuery, setOrderSearchQuery] = useState('')
  const [isUploading, setIsUploading] = useState(false)
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})
  
  // Live Active Carts States
  const [activeCarts, setActiveCarts] = useState<any[]>([])
  const [activeCartsCount, setActiveCartsCount] = useState<number>(0)
  const [isLoadingCarts, setIsLoadingCarts] = useState(false)
  const [cartsRefreshKey, setCartsRefreshKey] = useState(0)
  const [apiTodaySales, setApiTodaySales] = useState<number | null>(null)
  const [apiTodayNetSales, setApiTodayNetSales] = useState<number | null>(null)
  const [apiTodayOrdersCount, setApiTodayOrdersCount] = useState<number | null>(null)

  // WhatsApp Custom Alert States
  const [whatsappModalOpen, setWhatsappModalOpen] = useState(false)
  const [whatsappTargetUser, setWhatsappTargetUser] = useState<{ name: string; phone: string } | null>(null)
  const [whatsappCustomMessage, setWhatsappCustomMessage] = useState('')
  const [whatsappSelectedTemplateIdx, setWhatsappSelectedTemplateIdx] = useState(0)
  const [isCreateOrderOpen, setIsCreateOrderOpen] = useState(false)

  // Parse cafe menu sections dynamically from database settings
  const CAFE_MENU_SECTIONS = useMemo(() => {
    const customSectionsStr = settingsMap['cafe_menu_sections'] || settingsMap['CAFE_MENU_SECTIONS']
    if (customSectionsStr) {
      try {
        const parsed = JSON.parse(customSectionsStr)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed
        }
      } catch (e) {
        console.error('Error parsing CAFE_MENU_SECTIONS from settings:', e)
      }
    }
    return DEFAULT_CAFE_MENU_SECTIONS
  }, [settingsMap])

  // Parse restaurant menu sections dynamically from database settings
  const RESTAURANT_MENU_SECTIONS = useMemo(() => {
    const customSectionsStr = settingsMap['restaurant_menu_sections'] || settingsMap['RESTAURANT_MENU_SECTIONS']
    if (customSectionsStr) {
      try {
        const parsed = JSON.parse(customSectionsStr)
        if (Array.isArray(parsed) && parsed.length > 0) {
          return parsed
        }
      } catch (e) {
        console.error('Error parsing RESTAURANT_MENU_SECTIONS from settings:', e)
      }
    }
    return DEFAULT_RESTAURANT_MENU_SECTIONS
  }, [settingsMap])

  // Fetch settings function
  const fetchSettings = useCallback(async () => {
    try {
      const res = await fetch('/api/settings', { cache: 'no-store' })
      if (res.ok) {
        const data = await res.json()
        setSettingsMap(data)
      }
    } catch (err) {
      console.error('Failed to load settings:', err)
    }
  }, [])

  // Fetch settings on mount to retrieve Cloudinary credentials
  useEffect(() => {
    fetchSettings()
  }, [fetchSettings])

  const handleCloudinaryUpload = async (file: File, onUploadSuccess: (url: string) => void) => {
    const cloudName = settingsMap['cloudinary_cloud_name']
    const uploadPreset = settingsMap['cloudinary_upload_preset']

    if (!cloudName || !uploadPreset) {
      toast.error('Cloudinary not configured! Go to the "Store Settings" tab to set Cloudinary Cloud Name and Preset first.')
      return
    }

    setIsUploading(true)
    const formData = new FormData()
    formData.append('file', file)
    formData.append('upload_preset', uploadPreset)

    try {
      const res = await fetch(`https://api.cloudinary.com/v1_1/${cloudName}/image/upload`, {
        method: 'POST',
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        onUploadSuccess(data.secure_url)
        toast.success('Image uploaded to Cloudinary successfully!')
      } else {
        const errData = await res.json()
        toast.error(`Cloudinary upload failed: ${errData.error?.message || 'Check credentials'}`)
      }
    } catch (err) {
      console.error(err)
      toast.error('Could not connect to Cloudinary.')
    } finally {
      setIsUploading(false)
    }
  }

  // Web Audio API warning chime synthesizer
  const playWarningChime = () => {
    try {
      const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
      if (!AudioContextClass) return
      const ctx = new AudioContextClass()
      const now = ctx.currentTime
      
      // Tone 1: 550Hz soft warning beep
      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'sine'
      osc1.frequency.setValueAtTime(550, now)
      gain1.gain.setValueAtTime(0, now)
      gain1.gain.linearRampToValueAtTime(0.08, now + 0.05)
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.35)
      
      osc1.connect(gain1)
      gain1.connect(ctx.destination)
      osc1.start(now)
      osc1.stop(now + 0.35)
      
      // Tone 2: 660Hz slightly offset
      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'sine'
      osc2.frequency.setValueAtTime(660, now + 0.15)
      gain2.gain.setValueAtTime(0, now + 0.15)
      gain2.gain.linearRampToValueAtTime(0.08, now + 0.20)
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.5)
      
      osc2.connect(gain2)
      gain2.connect(ctx.destination)
      osc2.start(now + 0.15)
      osc2.stop(now + 0.5)
    } catch (err) {
      console.warn('AudioContext failed to play:', err)
    }
  }

  // Web Audio API new order chime synthesizer
  const playNewOrderChime = () => {
    if (isChimeMuted) return
    try {
      const AudioContextClass = window.AudioContext || (window as any).webkitAudioContext
      if (!AudioContextClass) return
      const ctx = new AudioContextClass()
      const now = ctx.currentTime

      // Ding (High note)
      const osc1 = ctx.createOscillator()
      const gain1 = ctx.createGain()
      osc1.type = 'triangle'
      osc1.frequency.setValueAtTime(880, now) // A5
      gain1.gain.setValueAtTime(0, now)
      gain1.gain.linearRampToValueAtTime(0.15, now + 0.05)
      gain1.gain.exponentialRampToValueAtTime(0.0001, now + 0.4)
      osc1.connect(gain1)
      gain1.connect(ctx.destination)
      osc1.start(now)
      osc1.stop(now + 0.4)

      // Dong (Slightly lower note)
      const osc2 = ctx.createOscillator()
      const gain2 = ctx.createGain()
      osc2.type = 'triangle'
      osc2.frequency.setValueAtTime(659.25, now + 0.15) // E5
      gain2.gain.setValueAtTime(0, now)
      gain2.gain.setValueAtTime(0.15, now + 0.15)
      gain2.gain.exponentialRampToValueAtTime(0.0001, now + 0.6)
      osc2.connect(gain2)
      gain2.connect(ctx.destination)
      osc2.start(now + 0.15)
      osc2.stop(now + 0.6)
    } catch (err) {
      console.warn('AudioContext failed to play new order chime:', err)
    }
  }

  // Real-time EventSource listener for new orders and live updates
  useEffect(() => {
    const fetchLiveOrdersList = async () => {
      try {
        const res = await fetch('/api/orders?all=true')
        if (res.ok) {
          const data = await res.json()
          setLiveOrders(data)
        }
      } catch (err) {
        console.error('Failed to poll live orders:', err)
      }
    }

    let updateTimeout: NodeJS.Timeout | null = null

    const debouncedRefresh = () => {
      if (updateTimeout) clearTimeout(updateTimeout)
      updateTimeout = setTimeout(() => {
        fetchLiveOrdersList()
        setOrderRefreshKey(prev => prev + 1)
      }, 1000)
    }

    let sse: EventSource | null = null
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null
    let isUnmounted = false

    const connectSSE = () => {
      if (isUnmounted) return
      sse = new EventSource('/api/sse/orders')

      sse.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'new-order') {
            toast.success(`🛎️ New Order Received: #${data.orderId.slice(0, 8)}`)
            playNewOrderChime()
            debouncedRefresh()
          } else if (data.type === 'status-change') {
            debouncedRefresh()
          }
        } catch (err) {
          console.error('Failed to parse SSE message:', err)
        }
      }

      sse.onerror = () => {
        sse?.close()
        sse = null
        if (!isUnmounted) {
          reconnectTimer = setTimeout(connectSSE, 5000)
        }
      }
    }

    connectSSE()

    // Fallback polling every 30 seconds (only if tab is visible)
    const interval = setInterval(() => {
      if (document.visibilityState === 'visible') {
        fetchLiveOrdersList()
      }
    }, 30000)

    // Initial load of live orders list
    fetchLiveOrdersList()

    return () => {
      isUnmounted = true
      sse?.close()
      if (reconnectTimer) clearTimeout(reconnectTimer)
      clearInterval(interval)
      if (updateTimeout) clearTimeout(updateTimeout)
    }
  }, [isChimeMuted])

  // Warning chime manager
  useEffect(() => {
    if (isChimeMuted) return

    const delayedOrdersCount = liveOrders.filter((order) => {
      const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
      if (order.status === 'PENDING') {
        const diffMs = new Date().getTime() - new Date(order.createdAt).getTime()
        return diffMs > (isRestaurant ? 30 : 10) * 60 * 1000
      }
      if (order.status === 'PACKED') {
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        return diffMs > 10 * 60 * 1000
      }
      if (order.status === 'CONFIRMED') {
        const baseTime = order.updatedAt || order.createdAt
        const diffMs = new Date().getTime() - new Date(baseTime).getTime()
        if (isRestaurant) {
          return diffMs > 30 * 60 * 1000 // Kitchen Chef delay (30 mins after accept)
        } else {
          return diffMs > 10 * 60 * 1000 // Grocery Picker delay (10 mins after accept)
        }
      }
      return false
    }).length

    if (delayedOrdersCount === 0) return

    // Play right away
    playWarningChime()

    // Play periodically every 20 seconds
    const chimeInterval = setInterval(playWarningChime, 20000)
    return () => clearInterval(chimeInterval)
  }, [liveOrders, isChimeMuted])

  // Filter delayed orders
  const delayedOrders = liveOrders.filter((order) => {
    const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
    if (order.status === 'PENDING') {
      const diffMs = new Date().getTime() - new Date(order.createdAt).getTime()
      return diffMs > (isRestaurant ? 30 : 10) * 60 * 1000
    }
    if (order.status === 'PACKED') {
      const baseTime = order.updatedAt || order.createdAt
      const diffMs = new Date().getTime() - new Date(baseTime).getTime()
      return diffMs > 10 * 60 * 1000
    }
    if (order.status === 'CONFIRMED') {
      const baseTime = order.updatedAt || order.createdAt
      const diffMs = new Date().getTime() - new Date(baseTime).getTime()
      if (isRestaurant) {
        return diffMs > 30 * 60 * 1000
      } else {
        return diffMs > 10 * 60 * 1000
      }
    }
    return false
  })

  // Count types of delays
  const pickerDelays = delayedOrders.filter(o => 
    !o.restaurantId && o.orderType !== 'RESTAURANT' && (o.status === 'PENDING' || o.status === 'CONFIRMED')
  )
  const chefDelays = delayedOrders.filter(o => 
    (!!o.restaurantId || o.orderType === 'RESTAURANT') && (o.status === 'PENDING' || o.status === 'CONFIRMED')
  )
  const riderDelays = delayedOrders.filter(o => o.status === 'PACKED')

  // States for Products
  const [products, setProducts] = useState(initialProducts || [])
  const [allProducts, setAllProducts] = useState(initialAllProducts || [])
  const [searchQuery, setSearchQuery] = useState('')
  const [selectedCategoryFilter, setSelectedCategoryFilter] = useState('')
  const [selectedOrderForTracking, setSelectedOrderForTracking] = useState<any | null>(null)
  const [isLoadingOrderItems, setIsLoadingOrderItems] = useState<boolean>(false)
  const [ordersSubTab, setOrdersSubTab] = useState<'active' | 'history'>('active')
  const [orderShopFilter, setOrderShopFilter] = useState<'ALL' | 'GROCERY' | 'CAFE' | 'RESTAURANT'>('ALL')
  const [orderMethodFilter, setOrderMethodFilter] = useState<'ALL' | 'DELIVERY' | 'SELF_PICKUP'>('ALL')

  const handleOpenOrderModal = useCallback(async (order: any) => {
    if (!order) return
    setSelectedOrderForTracking(order)
    if (!order.items || order.items.length === 0) {
      setIsLoadingOrderItems(true)
      try {
        const res = await fetch(`/api/orders/${order.id}`)
        if (res.ok) {
          const fullData = await res.json()
          setSelectedOrderForTracking((prev: any) => ({ ...prev, ...fullData }))
        }
      } catch (err) {
        console.error('Failed to fetch full order details:', err)
      } finally {
        setIsLoadingOrderItems(false)
      }
    }
  }, [])
  
  const [editingProduct, setEditingProduct] = useState<any | null>(null)
  const [savingProductId, setSavingProductId] = useState<string | null>(null)
  const [restaurantsList, setRestaurantsList] = useState<any[]>([])

  useEffect(() => {
    fetch('/api/restaurants?all=true')
      .then((res) => res.json())
      .then((data) => {
        if (Array.isArray(data)) setRestaurantsList(data)
      })
      .catch(console.error)
  }, [])

  const [productEditForm, setProductEditForm] = useState({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: '',
    restaurantId: '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
    location: '',
    isFlashDeal: false,
    isTopPick: false,
    isBestSeller: false,
    sortOrder: '0',
    barcode: '',
  })
  
  // State for Add Product Form
  const [showAddProduct, setShowAddProduct] = useState(false)
  const [showSortManager, setShowSortManager] = useState(false)
  const [showCsvImport, setShowCsvImport] = useState(false)
  const [showExportModal, setShowExportModal] = useState(false)
  const [isExporting, setIsExporting] = useState(false)
  const [isCreatingProduct, setIsCreatingProduct] = useState(false)
  const [newProduct, setNewProduct] = useState({
    name: '',
    description: '',
    imageUrl: '',
    categoryId: initialCategories?.[0]?.id || '',
    restaurantId: '',
    mrp: '',
    price: '',
    unit: '',
    stock: '',
    isAvailable: true,
    tags: '',
    minStock: '10',
    expiryDate: '',
    costPrice: '0',
    location: '',
    isFlashDeal: false,
    isTopPick: false,
    isBestSeller: false,
    sortOrder: '0',
    barcode: '',
  })
  // Product type toggles: 'grocery' | 'cafe'
  const [newProductType, setNewProductType] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [editProductType, setEditProductType] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [newCustomTag, setNewCustomTag] = useState('')
  const [editCustomTag, setEditCustomTag] = useState('')
  const [newProductVariants, setNewProductVariants] = useState<any[]>([])
  const [editProductVariants, setEditProductVariants] = useState<any[]>([])
  const [hasVariantsNew, setHasVariantsNew] = useState(false)
  const [hasVariantsEdit, setHasVariantsEdit] = useState(false)

  const isNewProductCafe = newProductType === 'cafe'
  const isEditProductCafe = editProductType === 'cafe'
  const isNewProductRestaurant = newProductType === 'restaurant'
  const isEditProductRestaurant = editProductType === 'restaurant'

  const handleNewProductTypeChange = (type: 'grocery' | 'cafe' | 'restaurant') => {
    setNewProductType(type)
    const cafeCategory = categories.find(c => c.slug === 'cafe')
    const restaurantCategory = categories.find(c => c.slug === 'restaurant')
    
    if (type === 'cafe') {
      const cafeId = cafeCategory?.id || ''
      let currentTags = newProduct.tags.split(',').map(t => t.trim()).filter(Boolean)
      if (!currentTags.map(t => t.toLowerCase()).includes('cafe')) {
        currentTags.push('cafe')
      }
      currentTags = currentTags.filter(t => t.toLowerCase() !== 'restaurant')
      setNewProduct(prev => ({
        ...prev,
        categoryId: cafeId,
        expiryDate: '',
        tags: currentTags.join(', ')
      }))
    } else if (type === 'restaurant') {
      const restaurantId = restaurantCategory?.id || 'cmrkghpcc0007lwidl816nhtv'
      let currentTags = newProduct.tags.split(',').map(t => t.trim()).filter(Boolean)
      if (!currentTags.map(t => t.toLowerCase()).includes('restaurant')) {
        currentTags.push('restaurant')
      }
      currentTags = currentTags.filter(t => t.toLowerCase() !== 'cafe')
      setNewProduct(prev => ({
        ...prev,
        categoryId: restaurantId,
        expiryDate: '',
        tags: currentTags.join(', ')
      }))
    } else {
      const firstGroceryId = categories.find(c => c.slug !== 'cafe' && c.slug !== 'restaurant')?.id || ''
      const nonGroceryTags = ['cafe', 'restaurant']
      const currentTags = newProduct.tags.split(',').map(t => t.trim()).filter(Boolean)
      const filteredTags = currentTags.filter(t => !nonGroceryTags.includes(t.toLowerCase()))
      setNewProduct(prev => ({
        ...prev,
        categoryId: firstGroceryId,
        tags: filteredTags.join(', ')
      }))
    }
  }

  const handleEditProductTypeChange = (type: 'grocery' | 'cafe' | 'restaurant') => {
    setEditProductType(type)
    const cafeCategory = categories.find(c => c.slug === 'cafe')
    const restaurantCategory = categories.find(c => c.slug === 'restaurant')
    
    if (type === 'cafe') {
      const cafeId = cafeCategory?.id || ''
      let currentTags = productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean)
      if (!currentTags.map(t => t.toLowerCase()).includes('cafe')) {
        currentTags.push('cafe')
      }
      currentTags = currentTags.filter(t => t.toLowerCase() !== 'restaurant')
      setProductEditForm(prev => ({
        ...prev,
        categoryId: cafeId,
        expiryDate: '',
        tags: currentTags.join(', ')
      }))
    } else if (type === 'restaurant') {
      const restaurantId = restaurantCategory?.id || ''
      let currentTags = productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean)
      if (!currentTags.map(t => t.toLowerCase()).includes('restaurant')) {
        currentTags.push('restaurant')
      }
      currentTags = currentTags.filter(t => t.toLowerCase() !== 'cafe')
      setProductEditForm(prev => ({
        ...prev,
        categoryId: restaurantId,
        expiryDate: '',
        tags: currentTags.join(', ')
      }))
    } else {
      const firstGroceryId = categories.find(c => c.slug !== 'cafe' && c.slug !== 'restaurant')?.id || ''
      const nonGroceryTags = ['cafe', 'restaurant']
      const currentTags = productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean)
      const filteredTags = currentTags.filter(t => !nonGroceryTags.includes(t.toLowerCase()))
      setProductEditForm(prev => ({
        ...prev,
        categoryId: firstGroceryId,
        tags: filteredTags.join(', ')
      }))
    }
  }

  const [selectedTypeFilter, setSelectedTypeFilter] = useState<'all' | 'grocery' | 'cafe' | 'restaurant'>('all')

  // States for Categories
  const [categories, setCategories] = useState(initialCategories || [])
  const [categorySubView, setCategorySubView] = useState<'grocery' | 'cafe' | 'restaurant'>('grocery')
  const [showAddCategory, setShowAddCategory] = useState(false)
  const [isCreatingCategory, setIsCreatingCategory] = useState(false)
  const [newCategory, setNewCategory] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
    parentId: '',
  })

  // Apply template pre-fill values to add product form
  const applyProductTemplate = (templateId: string) => {
    const template = PRODUCT_TEMPLATES.find((t) => t.id === templateId)
    if (!template) return

    let categoryId = ''
    if (template.categoryName === 'FastKirana Cafe') {
      const cafeCat = categories.find((c) => c.slug === 'cafe')
      categoryId = cafeCat?.id || ''
      handleNewProductTypeChange('cafe')
    } else {
      const matchedCat = categories.find(
        (c) => c.name.toLowerCase().trim() === template.categoryName.toLowerCase().trim()
      )
      categoryId = matchedCat?.id || categories.find((c) => c.slug !== 'cafe')?.id || ''
      handleNewProductTypeChange('grocery')
    }

    setNewProduct((prev) => ({
      ...prev,
      categoryId,
      unit: template.unit,
      minStock: template.minStock.toString(),
      tags: template.tags,
    }))
    toast.success(`Applied ${template.label} template!`)
  }
  
  // Modal Edit states for Categories
  const [editingCategory, setEditingCategory] = useState<any | null>(null)
  const [savingCategoryId, setSavingCategoryId] = useState<string | null>(null)
  const [deletingCategoryId, setDeletingCategoryId] = useState<string | null>(null)
  const [categoryEditForm, setCategoryEditForm] = useState({
    name: '',
    imageUrl: '',
    sortOrder: '0',
    parentId: '',
  })

  // States for Users
  const [users, setUsers] = useState(initialUsers || [])
  const [updatingUserRoleId, setUpdatingUserRoleId] = useState<string | null>(null)
  const [settingPasswordUserId, setSettingPasswordUserId] = useState<string | null>(null)
  const [passwordInput, setPasswordInput] = useState('')
  const [savingPasswordId, setSavingPasswordId] = useState<string | null>(null)
  const [editingPhoneUserId, setEditingPhoneUserId] = useState<string | null>(null)
  const [phoneInput, setPhoneInput] = useState('')
  const [savingPhoneId, setSavingPhoneId] = useState<string | null>(null)

  // States for Pagination
  const [orderPage, setOrderPage] = useState(1)
  const [orderTotal, setOrderTotal] = useState(stats.orderCount || (initialOrders || []).length)
  const [isLoadingOrders, setIsLoadingOrders] = useState(false)

  const [productPage, setProductPage] = useState(1)
  const [productTotal, setProductTotal] = useState((initialProducts || []).length)
  const [isLoadingProducts, setIsLoadingProducts] = useState(false)

  const [userPage, setUserPage] = useState(1)

  // Media Library Modal states
  const [showMediaLibrary, setShowMediaLibrary] = useState(false)
  const [mediaTarget, setMediaTarget] = useState<'newProduct' | 'editProduct' | 'newCategory' | 'editCategory' | 'category' | null>(null)
  const [mediaSearchQuery, setMediaSearchQuery] = useState('')

  const mediaLibraryImages = useMemo(() => {
    const setOfImages = new Map<string, { url: string; name: string; tags?: string[] }>()

    PRESET_KITCHEN_PHOTOS.forEach((preset) => {
      setOfImages.set(preset.url, { url: preset.url, name: preset.name, tags: preset.tags })
    })

    allProducts.forEach((p) => {
      if (p.imageUrl && p.imageUrl.startsWith('http')) {
        if (!setOfImages.has(p.imageUrl)) {
          setOfImages.set(p.imageUrl, { url: p.imageUrl, name: p.name || 'Product Image', tags: p.tags || [] })
        }
      }
    })

    categories.forEach((c) => {
      if (c.imageUrl && c.imageUrl.startsWith('http')) {
        if (!setOfImages.has(c.imageUrl)) {
          setOfImages.set(c.imageUrl, { url: c.imageUrl, name: c.name || 'Category Image' })
        }
      }
    })

    return Array.from(setOfImages.values())
  }, [allProducts, categories])

  const filteredMediaImages = useMemo(() => {
    if (!mediaSearchQuery.trim()) return mediaLibraryImages
    const q = mediaSearchQuery.toLowerCase().trim()
    return mediaLibraryImages.filter(img => 
      img.name.toLowerCase().includes(q) || 
      img.url.toLowerCase().includes(q) ||
      (img.tags && img.tags.some(t => t.toLowerCase().includes(q)))
    )
  }, [mediaLibraryImages, mediaSearchQuery])
  const [userTotal, setUserTotal] = useState(stats.userCount || (initialUsers || []).length)
  const [isLoadingUsers, setIsLoadingUsers] = useState(false)
  const [userSearch, setUserSearch] = useState('')
  const [userRoleFilter, setUserRoleFilter] = useState('ALL')
  const [userStatusFilter, setUserStatusFilter] = useState('ALL')
  const [blockingUser, setBlockingUser] = useState<any | null>(null)
  const [blockReasonInput, setBlockReasonInput] = useState('')
  const [isUpdatingBlockStatus, setIsUpdatingBlockStatus] = useState(false)

  const todaySales = useMemo(() => {
    const todayStr = new Date().toDateString()
    return (orders || [])
      .filter((o: any) => o.status !== 'CANCELLED' && new Date(o.createdAt).toDateString() === todayStr)
      .reduce((sum: number, o: any) => sum + (o.total || 0), 0)
  }, [orders])

  const todayOrdersCount = useMemo(() => {
    const todayStr = new Date().toDateString()
    return (orders || []).filter((o: any) => o.status !== 'CANCELLED' && new Date(o.createdAt).toDateString() === todayStr).length
  }, [orders])

  const netSales = useMemo(() => {
    return (orders || [])
      .filter((o: any) => o.status !== 'CANCELLED')
      .reduce((sum: number, o: any) => sum + (o.total || 0), 0)
  }, [orders])

  // Pagination page resets
  useEffect(() => {
    setOrderPage(1)
  }, [orderStatusFilter, orderSearchQuery])

  useEffect(() => {
    setProductPage(1)
  }, [selectedCategoryFilter, searchQuery, selectedTypeFilter])

  useEffect(() => {
    setUserPage(1)
  }, [userSearch, userRoleFilter, userStatusFilter])

  // Fetch paginated/filtered orders
  useEffect(() => {
    let active = true
    const fetchOrders = async () => {
      setIsLoadingOrders(true)
      try {
        const res = await fetch(`/api/admin/orders?page=${orderPage}&limit=10&status=${orderStatusFilter}&search=${encodeURIComponent(orderSearchQuery)}`)
        if (res.ok && active) {
          const data = await res.json()
          setOrders(data.orders)
          setOrderTotal(data.total)
          if (typeof data.todaySales === 'number') setApiTodaySales(data.todaySales)
          if (typeof data.todayNetSales === 'number') setApiTodayNetSales(data.todayNetSales)
          if (typeof data.todayOrdersCount === 'number') setApiTodayOrdersCount(data.todayOrdersCount)
          if (data.counts) {
            setOrderCounts(data.counts)
          }
        }
      } catch (err) {
        console.error('Failed to fetch orders:', err)
      } finally {
        if (active) setIsLoadingOrders(false)
      }
    }
    fetchOrders()
    return () => { active = false }
  }, [orderPage, orderStatusFilter, orderSearchQuery, orderRefreshKey])

  // Fetch active carts count once on mount for the badge count
  useEffect(() => {
    let active = true
    const fetchCartsCount = async () => {
      try {
        const res = await fetch('/api/admin/live-carts')
        if (res.ok && active) {
          const data = await res.json()
          setActiveCartsCount(data.count || 0)
        }
      } catch (err) {
        console.error('Failed to fetch carts count on mount:', err)
      }
    }
    fetchCartsCount()
    return () => { active = false }
  }, [])

  // Poll active carts detail every 30 seconds only if activeTab is 'liveops'
  useEffect(() => {
    let active = true
    let intervalId: any = null

    const fetchCartsDetail = async () => {
      if (activeTab !== 'liveops') return
      setIsLoadingCarts(true)
      try {
        const res = await fetch('/api/admin/live-carts')
        if (res.ok && active) {
          const data = await res.json()
          setActiveCarts(data.carts || [])
          setActiveCartsCount(data.count || 0)
        }
      } catch (err) {
        console.error('Failed to fetch live carts detail:', err)
      } finally {
        if (active) setIsLoadingCarts(false)
      }
    }

    if (activeTab === 'liveops') {
      fetchCartsDetail()
      intervalId = setInterval(fetchCartsDetail, 30000) // Poll every 30 seconds
    }

    return () => {
      active = false
      if (intervalId) clearInterval(intervalId)
    }
  }, [activeTab, cartsRefreshKey])

  // Fetch paginated/filtered products
  useEffect(() => {
    let active = true
    const fetchProducts = async () => {
      setIsLoadingProducts(true)
      try {
        const res = await fetch(`/api/admin/products?page=${productPage}&limit=10&categoryId=${selectedCategoryFilter}&search=${encodeURIComponent(searchQuery)}&type=${selectedTypeFilter}`)
        if (res.ok && active) {
          const data = await res.json()
          setProducts(data.products)
          setProductTotal(data.total)
        }
      } catch (err) {
        console.error('Failed to fetch products:', err)
      } finally {
        if (active) setIsLoadingProducts(false)
      }
    }
    fetchProducts()
    return () => { active = false }
  }, [productPage, selectedCategoryFilter, searchQuery, selectedTypeFilter])

  // Fetch paginated/filtered users
  useEffect(() => {
    let active = true
    const fetchUsers = async () => {
      setIsLoadingUsers(true)
      try {
        const res = await fetch(`/api/admin/users?page=${userPage}&limit=10&search=${encodeURIComponent(userSearch)}&role=${userRoleFilter}&status=${userStatusFilter}`)
        if (res.ok && active) {
          const data = await res.json()
          setUsers(data.users)
          setUserTotal(data.total)
        }
      } catch (err) {
        console.error('Failed to fetch users:', err)
      } finally {
        if (active) setIsLoadingUsers(false)
      }
    }
    fetchUsers()
    return () => { active = false }
  }, [userPage, userSearch, userRoleFilter, userStatusFilter])

  const handleToggleBlock = async (userToBlock: any, isBlocked: boolean, reason?: string) => {
    setIsUpdatingBlockStatus(true)
    try {
      const res = await fetch('/api/admin/users/block', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: userToBlock.id,
          isBlocked,
          blockReason: reason
        })
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to update user block status')
      }
      toast.success(data.message)
      setBlockingUser(null)
      setBlockReasonInput('')
      setUsers(prev => prev.map(u => u.id === userToBlock.id ? { 
        ...u, 
        isBlocked, 
        blockReason: isBlocked ? (reason?.trim() || 'Blocked by administrator') : null, 
        blockedAt: isBlocked ? new Date().toISOString() : null 
      } : u))
    } catch (err: any) {
      toast.error(err.message || 'Error updating block status')
    } finally {
      setIsUpdatingBlockStatus(false)
    }
  }

  const [isExportingUsers, setIsExportingUsers] = useState(false)

  const handleExportCustomersCsv = async () => {
    setIsExportingUsers(true)
    try {
      const res = await fetch(`/api/admin/users?limit=10000&role=USER`)
      if (!res.ok) throw new Error('Failed to fetch customers')
      const data = await res.json()
      const customers = data.users || []

      if (customers.length === 0) {
        toast.error('No customers found to export.')
        return
      }

      // Format CSV
      const headers = ['Name', 'Email', 'Phone', 'Role', 'Status', 'Block Reason', 'Orders Count', 'Joined Date']
      const rows = customers.map((c: any) => [
        `"${(c.name || '').replace(/"/g, '""')}"`,
        `"${(c.email || '').replace(/"/g, '""')}"`,
        `"${(c.phone || '').replace(/"/g, '""')}"`,
        `"${(c.role || 'USER')}"`,
        `"${c.isBlocked ? 'BLOCKED' : 'ACTIVE'}"`,
        `"${(c.blockReason || '').replace(/"/g, '""')}"`,
        c._count?.orders ?? 0,
        formatDate(c.createdAt, 'dd/MM/yyyy')
      ])

      const csvContent = [headers.join(','), ...rows.map((r: any) => r.join(','))].join('\n')
      
      // Trigger download
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.setAttribute('href', url)
      link.setAttribute('download', `customers_export_${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      toast.success('Customers data exported successfully!')
    } catch (err) {
      console.error(err)
      toast.error('Could not export customer records.')
    } finally {
      setIsExportingUsers(false)
    }
  }

  // Render pagination controls helper
  const renderPagination = (currentPage: number, totalItems: number, itemsPerPage: number, onPageChange: (p: number) => void) => {
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

  // States for Reviews
  const [reviews, setReviews] = useState(initialReviews || [])
  const [isLoadingReviews, setIsLoadingReviews] = useState(false)
  const [deletingReviewId, setDeletingReviewId] = useState<string | null>(null)
  const [reviewSearch, setReviewSearch] = useState('')
  
  // Modal Edit states for Reviews
  const [editingReview, setEditingReview] = useState<any | null>(null)
  const [savingReviewId, setSavingReviewId] = useState<string | null>(null)
  const [reviewEditForm, setReviewEditForm] = useState({
    rating: 5,
    comment: '',
  })

  // States for Coupons
  const [coupons, setCoupons] = useState(initialCoupons || [])
  const [isLoadingCoupons, setIsLoadingCoupons] = useState(false)
  const [showAddCoupon, setShowAddCoupon] = useState(false)
  const [isCreatingCoupon, setIsCreatingCoupon] = useState(false)
  const [deletingCouponId, setDeletingCouponId] = useState<string | null>(null)
  const [newCoupon, setNewCoupon] = useState({
    code: '',
    discountType: 'PERCENT',
    value: '',
    minOrder: '',
    maxDiscount: '',
    maxUses: '',
    isActive: true,
    expiresAt: '',
    categoryId: '',
    oncePerCustomer: false,
  })
  
  // Modal Edit states for Coupons
  const [editingCoupon, setEditingCoupon] = useState<any | null>(null)
  const [savingCouponId, setSavingCouponId] = useState<string | null>(null)
  const [couponEditForm, setCouponEditForm] = useState({
    code: '',
    discountType: 'PERCENT',
    value: '',
    minOrder: '',
    maxDiscount: '',
    maxUses: '',
    isActive: true,
    expiresAt: '',
    categoryId: '',
    oncePerCustomer: false,
  })

  // 1. Lazy loader for reviews
  useEffect(() => {
    if (activeTab === 'reviews' && reviews.length === 0) {
      const loadReviews = async () => {
        setIsLoadingReviews(true)
        try {
          const res = await fetch('/api/admin/reviews')
          if (res.ok) {
            const data = await res.json()
            setReviews(data)
          }
        } catch (err) {
          console.error('Failed to load reviews:', err)
        } finally {
          setIsLoadingReviews(false)
        }
      }
      loadReviews()
    }
  }, [activeTab, reviews.length])

  // 2. Lazy loader for coupons
  useEffect(() => {
    if (activeTab === 'coupons' && coupons.length === 0) {
      const loadCoupons = async () => {
        setIsLoadingCoupons(true)
        try {
          const res = await fetch('/api/admin/coupons')
          if (res.ok) {
            const data = await res.json()
            setCoupons(data)
          }
        } catch (err) {
          console.error('Failed to load coupons:', err)
        } finally {
          setIsLoadingCoupons(false)
        }
      }
      loadCoupons()
    }
  }, [activeTab, coupons.length])

  // 3. Background loader for all products (used in dropdown selectors, banners, etc.)
  useEffect(() => {
    if (allProducts.length === 0) {
      const loadAllProducts = async () => {
        try {
          const res = await fetch('/api/products?limit=1000')
          if (res.ok) {
            const data = await res.json()
            if (data.products) {
              setAllProducts(data.products)
            }
          }
        } catch (err) {
          console.error('Failed to load full products list:', err)
        }
      }
      loadAllProducts()
    }
  }, [allProducts.length])

  const toggleTag = (form: 'new' | 'edit', tag: string, checked: boolean) => {
    const currentForm = form === 'new' ? newProduct : productEditForm
    const setForm: any = form === 'new' ? setNewProduct : setProductEditForm
    
    let tagsList = currentForm.tags
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0 && t.toLowerCase() !== tag.toLowerCase())
      
    if (checked) {
      tagsList.push(tag)
    }
    
    setForm((prev: any) => ({
      ...prev,
      tags: tagsList.join(', ')
    }))
  }

  const handleCreateCustomTag = (form: 'new' | 'edit', tagText: string) => {
    const cleanTag = tagText.trim().toLowerCase().replace(/\s+/g, '-');
    if (!cleanTag) return;
    
    const currentForm = form === 'new' ? newProduct : productEditForm
    const setForm: any = form === 'new' ? setNewProduct : setProductEditForm
    
    let tagsList = currentForm.tags
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
      
    if (!tagsList.map(t => t.toLowerCase()).includes(cleanTag)) {
      tagsList.push(cleanTag)
    }
    
    setForm((prev: any) => ({
      ...prev,
      tags: tagsList.join(', ')
    }))
    
    if (form === 'new') {
      setNewCustomTag('')
    } else {
      setEditCustomTag('')
    }
  }

  const handleImageFileChange = (form: 'new' | 'edit', e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    handleCloudinaryUpload(file, (url) => {
      if (form === 'new') {
        setNewCategory({ ...newCategory, imageUrl: url })
      } else {
        setCategoryEditForm({ ...categoryEditForm, imageUrl: url })
      }
    })
  }

  // ----------------------------------------------------
  // Handlers for Orders
  // ----------------------------------------------------
  const handleOrderStatusChange = async (orderId: string, newStatus: string) => {
    setUpdatingOrderId(orderId)
    try {
      const res = await fetch(`/api/orders/${orderId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: newStatus }),
      })

      if (res.ok) {
        const updated = await res.json()
        setOrders(orders.map((o) => (o.id === orderId ? { ...o, status: updated.status } : o)))
        toast.success(`Order status updated to ${ORDER_STATUS_LABELS[newStatus]}`)
      } else {
        toast.error('Failed to update order status')
      }
    } catch (err) {
      toast.error('Failed to update status')
    } finally {
      setUpdatingOrderId(null)
    }
  }

  const sendCartNotification = async (userId: string, userName: string) => {
    const defaultMsg = `Hey ${userName}! Your items are waiting. Checkout now for instant delivery!`
    const message = window.prompt(`Customize push notification for ${userName}:`, defaultMsg)
    if (message === null) return // Canceled

    setIsLoadingCarts(true)
    try {
      const res = await fetch('/api/admin/live-carts/notify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          title: 'Cart Waiting 🛒',
          body: message || defaultMsg
        })
      })

      const data = await res.json()
      if (res.ok) {
        toast.success('Push notification sent successfully!')
      } else {
        toast.error(data.error || 'Failed to send push notification')
      }
    } catch (err) {
      toast.error('Failed to send push notification')
    } finally {
      setIsLoadingCarts(false)
    }
  }

  const openWhatsAppModal = (userName: string, phone: string) => {
    if (!phone || phone === 'N/A') {
      toast.error('Customer phone number not available')
      return
    }
    const origin = typeof window !== 'undefined' ? window.location.origin : 'https://fastkirana.vercel.app'
    const templates = [
      `Hey ${userName}! 🛒 Your items are waiting in your cart. Checkout now for instant delivery: ${origin}/cart`,
      `Hey ${userName}! 🎁 We saved the items in your cart. Complete your order now and get an extra discount! Use code SAVE10 at checkout: ${origin}/cart`,
      `Hey ${userName}! 👋 We noticed you left some items in your cart. Order now before they sell out! ${origin}/cart`
    ]
    setWhatsappTargetUser({ name: userName, phone })
    setWhatsappSelectedTemplateIdx(0)
    setWhatsappCustomMessage(templates[0])
    setWhatsappModalOpen(true)
  }

  const handleTemplateSelect = (idx: number) => {
    if (!whatsappTargetUser) return
    const origin = typeof window !== 'undefined' ? window.location.origin : 'https://fastkirana.vercel.app'
    const templates = [
      `Hey ${whatsappTargetUser.name}! 🛒 Your items are waiting in your cart. Checkout now for instant delivery: ${origin}/cart`,
      `Hey ${whatsappTargetUser.name}! 🎁 We saved the items in your cart. Complete your order now and get an extra discount! Use code SAVE10 at checkout: ${origin}/cart`,
      `Hey ${whatsappTargetUser.name}! 👋 We noticed you left some items in your cart. Order now before they sell out! ${origin}/cart`
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
    const whatsappUrl = `https://wa.me/${cleanPhone}?text=${encodeURIComponent(whatsappCustomMessage)}`
    window.open(whatsappUrl, '_blank')
    setWhatsappModalOpen(false)
    setWhatsappTargetUser(null)
  }

  const handleUserRoleChange = async (userId: string, newRole: string) => {
    setUpdatingUserRoleId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, role: newRole }),
      })

      if (res.ok) {
        setUsers(users.map((u) => (u.id === userId ? { ...u, role: newRole } : u)))
        toast.success('User role updated successfully!')
      } else {
        toast.error('Failed to update user role')
      }
    } catch (err) {
      toast.error('Error updating user role')
    } finally {
      setUpdatingUserRoleId(null)
    }
  }

  const handleSetPassword = async (userId: string) => {
    if (!passwordInput || passwordInput.length < 6) {
      toast.error('Password must be at least 6 characters')
      return
    }
    setSavingPasswordId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, password: passwordInput }),
      })
      if (res.ok) {
        toast.success('Password set successfully! Worker can now login.')
        setSettingPasswordUserId(null)
        setPasswordInput('')
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to set password')
      }
    } catch (err) {
      toast.error('Error setting password')
    } finally {
      setSavingPasswordId(null)
    }
  }

  const handleUserPhoneSave = async (userId: string) => {
    if (!phoneInput.trim()) {
      toast.error('Phone number cannot be empty')
      return
    }

    setSavingPhoneId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, phone: phoneInput.trim() }),
      })

      if (!res.ok) throw new Error('Failed to update phone number')

      setUsers(users.map((u) => (u.id === userId ? { ...u, phone: phoneInput.trim() } : u)))
      toast.success('Phone number updated successfully!')
      setEditingPhoneUserId(null)
      setPhoneInput('')
    } catch (err: any) {
      toast.error(err.message || 'Error updating phone number')
    } finally {
      setSavingPhoneId(null)
    }
  }

  // ----------------------------------------------------
  // Handlers for Product Management (Modal Edit & Create)
  // ----------------------------------------------------
  const handleDuplicateProduct = (p: any) => {
    const isCafe = (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('cafe') ||
                   categories.find(c => c.id === p.categoryId)?.slug === 'cafe';
    setNewProductType(isCafe ? 'cafe' : 'grocery')
    
    const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
    setHasVariantsNew(hasVariants)
    setNewProductVariants(hasVariants ? (p.variants as any[]).map(v => ({
      name: v.name,
      price: String(v.price),
      mrp: String(v.mrp),
      costPrice: String(v.costPrice ?? 0),
      stock: String(v.stock),
    })) : [])

    setNewProduct({
      name: `${p.name} (Copy)`,
      description: p.description || '',
      imageUrl: p.imageUrl || '',
      categoryId: p.categoryId || '',
      restaurantId: p.restaurantId || '',
      mrp: String(p.mrp || ''),
      price: String(p.price || ''),
      unit: p.unit || '',
      stock: String(p.stock || ''),
      isAvailable: p.isAvailable !== false,
      tags: p.tags ? p.tags.join(', ') : '',
      minStock: String(p.minStock ?? 10),
      expiryDate: p.expiryDate ? String(p.expiryDate) : '',
      costPrice: String(p.costPrice ?? 0),
      location: p.location || '',
      isFlashDeal: p.isFlashDeal || false,
      isTopPick: p.isTopPick || false,
      isBestSeller: p.isBestSeller || false,
      sortOrder: String(p.sortOrder ?? 0),
      barcode: p.barcode || '',
    })

    setShowAddProduct(true)
    setShowCsvImport(false)
    
    // Smooth scroll to the top of the Add Product form container
    setTimeout(() => {
      const formElement = document.getElementById('add-product-form-container')
      if (formElement) {
        formElement.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }, 50)
  }

  const handleExportCsv = async (type: 'all' | 'grocery' | 'cafe') => {
    setIsExporting(true)
    try {
      const url = `/api/admin/products?limit=5000${type !== 'all' ? `&type=${type}` : ''}`
      const res = await fetch(url)
      const data = await res.json()
      
      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch products for export')
      }
      
      const exportProducts = data.products || []
      
      if (exportProducts.length === 0) {
        toast.warning('No products found to export.')
        setIsExporting(false)
        return
      }

      // Convert products array to CSV string matching the import headers
      // Headers: ID,Name,Category,Unit,MRP,Price,Stock,Tags,Description,Image URL,Cost Price,Min Stock,Location,Barcode,Variants
      const headers = [
        'ID', 'Name', 'Category', 'Unit', 'MRP', 'Price', 'Stock', 'Tags', 'Description', 'Image URL', 'Cost Price', 'Min Stock', 'Location', 'Barcode', 'Display Order', 'Variants'
      ]
      
      const csvRows = [headers.join(',')]
      
      exportProducts.forEach((p: any) => {
        const row = [
          p.id || '',
          p.name || '',
          p.category?.name || '',
          p.unit || '',
          p.mrp?.toString() || '0',
          p.price?.toString() || '0',
          p.stock?.toString() || '0',
          Array.isArray(p.tags) ? p.tags.join(', ') : p.tags || '',
          p.description || '',
          p.imageUrl || '',
          p.costPrice?.toString() || '0',
          p.minStock?.toString() || '10',
          p.location || '',
          p.barcode || '',
          p.sortOrder?.toString() || '0',
          p.variants ? (Array.isArray(p.variants) ? (p.variants as any[]).map((v) => {
            const parts = [
              v.name || '',
              v.price?.toString() || '0',
              v.mrp?.toString() || '0',
              v.stock?.toString() || '0'
            ]
            if (v.costPrice !== undefined) {
              parts.push(v.costPrice.toString())
            }
            return parts.join(':')
          }).join(' | ') : typeof p.variants === 'string' ? p.variants : '') : '',
        ]

        
        // Escape quotes and commas in CSV cells
        const escapedRow = row.map(cell => {
          const cleanCell = cell.replace(/"/g, '""') // Escape quotes
          if (cleanCell.includes(',') || cleanCell.includes('\n') || cleanCell.includes('"')) {
            return `"${cleanCell}"`
          }
          return cleanCell
        })
        
        csvRows.push(escapedRow.join(','))
      })
      
      const csvContent = csvRows.join('\n')
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const urlBlob = URL.createObjectURL(blob)
      
      const link = document.createElement('a')
      link.href = urlBlob
      
      const filename = `fastkirana_products_${type}_${new Date().toISOString().split('T')[0]}.csv`
      link.setAttribute('download', filename)
      link.click()
      URL.revokeObjectURL(urlBlob)
      
      toast.success(`Successfully exported ${exportProducts.length} items!`)
      setShowExportModal(false)
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Failed to export products')
    } finally {
      setIsExporting(false)
    }
  }

  const handleReplenishCsv = async () => {
    setIsExporting(true)
    try {
      const url = '/api/admin/products?limit=5000'
      const res = await fetch(url)
      const data = await res.json()
      
      if (!res.ok) {
        throw new Error(data.error || 'Failed to fetch products for replenish PO')
      }
      
      const replenishProducts = (data.products || []).filter((p: any) => p.stock <= (p.minStock ?? 10))
      
      if (replenishProducts.length === 0) {
        toast.success('Excellent! No products are currently below min stock levels.')
        setIsExporting(false)
        return
      }

      const headers = [
        'Name', 'Category', 'Unit', 'MRP', 'Price', 'Stock', 'Tags', 'Description', 'Image URL', 'Cost Price', 'Min Stock', 'Location'
      ]
      
      const csvRows = [headers.join(',')]
      
      replenishProducts.forEach((p: any) => {
        const row = [
          p.name || '',
          p.category?.name || '',
          p.unit || '',
          p.mrp?.toString() || '0',
          p.price?.toString() || '0',
          p.stock?.toString() || '0',
          Array.isArray(p.tags) ? p.tags.join(', ') : p.tags || '',
          p.description || '',
          p.imageUrl || '',
          p.costPrice?.toString() || '0',
          p.minStock?.toString() || '10',
          p.location || '',
        ]
        
        const escapedRow = row.map(cell => {
          const cleanCell = cell.replace(/"/g, '""')
          if (cleanCell.includes(',') || cleanCell.includes('\n') || cleanCell.includes('"')) {
            return `"${cleanCell}"`
          }
          return cleanCell
        })
        
        csvRows.push(escapedRow.join(','))
      })
      
      const csvContent = csvRows.join('\n')
      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const urlBlob = URL.createObjectURL(blob)
      
      const link = document.createElement('a')
      link.href = urlBlob
      
      const filename = `fastkirana_replenish_po_${new Date().toISOString().split('T')[0]}.csv`
      link.setAttribute('download', filename)
      link.click()
      URL.revokeObjectURL(urlBlob)
      
      toast.success(`Generated replenishment PO with ${replenishProducts.length} items!`)
    } catch (err: any) {
      toast.error(err.message || 'Error generating replenishment PO')
    } finally {
      setIsExporting(false)
    }
  }

  const startEditingProduct = (p: any) => {
    setEditingProduct(p)
    const isCafe = (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('cafe') ||
                   categories.find(c => c.id === p.categoryId)?.slug === 'cafe';
    const isRestaurant = (p.tags || []).map((t: string) => t.trim().toLowerCase()).includes('restaurant') ||
                          categories.find(c => c.id === p.categoryId)?.slug === 'restaurant';
    setEditProductType(isRestaurant ? 'restaurant' : isCafe ? 'cafe' : 'grocery')
    
    const hasVariants = p.variants && Array.isArray(p.variants) && p.variants.length > 0
    setHasVariantsEdit(hasVariants)
    setEditProductVariants(hasVariants ? (p.variants as any[]).map(v => ({
      name: v.name,
      price: String(v.price),
      mrp: String(v.mrp),
      costPrice: String(v.costPrice ?? 0),
      stock: String(v.stock),
    })) : [])

    setProductEditForm({
      name: p.name || '',
      description: p.description || '',
      imageUrl: p.imageUrl || '',
      categoryId: p.categoryId || '',
      restaurantId: p.restaurantId || '',
      mrp: String(p.mrp || ''),
      price: String(p.price || ''),
      unit: p.unit || '',
      stock: String(p.stock || ''),
      isAvailable: p.isAvailable !== false,
      tags: p.tags ? p.tags.join(', ') : '',
      minStock: String(p.minStock ?? 10),
      expiryDate: p.expiryDate ? String(p.expiryDate) : '',
      costPrice: String(p.costPrice ?? 0),
      location: p.location || '',
      isFlashDeal: p.isFlashDeal || false,
      isTopPick: p.isTopPick || false,
      isBestSeller: p.isBestSeller || false,
      sortOrder: String(p.sortOrder ?? 0),
      barcode: p.barcode || '',
    })
  }

  const saveProductChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingProduct) return

    const requiresBasePrice = !hasVariantsEdit
    const isSpecialProduct = isEditProductCafe || isEditProductRestaurant
    const hasCategory = productEditForm.categoryId || isSpecialProduct
    if (!productEditForm.name || !hasCategory || (requiresBasePrice && (!productEditForm.price || !productEditForm.mrp))) {
      toast.error('Please fill in all required fields')
      return
    }
    if (hasVariantsEdit && editProductVariants.length === 0) {
      toast.error('Please add at least one variant option')
      return
    }

    setSavingProductId(editingProduct.id)
    try {
      const tagsArray = productEditForm.tags
        ? productEditForm.tags.split(',').map((t) => t.trim()).filter((t) => t.length > 0)
        : []

      const res = await fetch(`/api/products/${editingProduct.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: productEditForm.name,
          description: productEditForm.description,
          imageUrl: productEditForm.imageUrl,
          categoryId: productEditForm.categoryId,
          restaurantId: productEditForm.restaurantId || null,
          mrp: hasVariantsEdit && editProductVariants.length > 0 ? parseFloat(editProductVariants[0].mrp) : parseFloat(productEditForm.mrp),
          price: hasVariantsEdit && editProductVariants.length > 0 ? parseFloat(editProductVariants[0].price) : parseFloat(productEditForm.price),
          unit: productEditForm.unit,
          stock: (isEditProductCafe || isEditProductRestaurant) ? 99999 : (hasVariantsEdit && editProductVariants.length > 0 ? editProductVariants.reduce((sum, v) => sum + (parseInt(v.stock) || 0), 0) : (parseInt(productEditForm.stock) || 0)),
          minStock: (isEditProductCafe || isEditProductRestaurant) ? 0 : (parseInt(productEditForm.minStock) || 10),
          isAvailable: productEditForm.isAvailable,
          tags: tagsArray,
          expiryDate: productEditForm.expiryDate ? new Date(productEditForm.expiryDate).toISOString() : null,
          costPrice: parseFloat(productEditForm.costPrice) || 0,
          location: productEditForm.location || null,
          isFlashDeal: productEditForm.isFlashDeal,
          isTopPick: productEditForm.isTopPick,
          isBestSeller: productEditForm.isBestSeller,
          sortOrder: parseInt(productEditForm.sortOrder) || 0,
          barcode: productEditForm.barcode || null,
          variants: hasVariantsEdit ? editProductVariants.map(v => ({
            name: v.name,
            price: parseFloat(v.price) || 0,
            mrp: parseFloat(v.mrp) || 0,
            costPrice: parseFloat(v.costPrice) || 0,
            stock: parseInt(v.stock) || 0,
          })) : null,
        }),

      })

      if (res.ok) {
        const updated = await res.json()
        setProducts(products.map((p) => (p.id === editingProduct.id ? updated : p)))
        setAllProducts(allProducts.map((p) => (p.id === editingProduct.id ? { ...p, ...updated } : p)))
        toast.success('Product updated successfully!')
        setEditingProduct(null)
      } else {
        toast.error('Failed to update product details')
      }
    } catch (err) {
      toast.error('Error saving product changes')
    } finally {
      setSavingProductId(null)
    }
  }

  const handleToggleProductAvailability = async (productId: string, currentAvailable: boolean) => {
    try {
      const res = await fetch(`/api/products/${productId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          isAvailable: !currentAvailable,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setProducts(products.map((p) => (p.id === productId ? updated : p)))
        setAllProducts(allProducts.map((p) => (p.id === productId ? { ...p, ...updated } : p)))
        toast.success(`Product "${updated.name}" ${!currentAvailable ? 'enabled' : 'disabled'} successfully!`)
      } else {
        toast.error('Failed to update product availability')
      }
    } catch (err) {
      toast.error('Error updating product status')
    }
  }

  const handleCreateProduct = async (e: React.FormEvent) => {
    e.preventDefault()
    const requiresBasePrice = !hasVariantsNew
    const isSpecialProduct = isNewProductCafe || isNewProductRestaurant
    const hasCategory = newProduct.categoryId || isSpecialProduct
    if (!newProduct.name || !hasCategory || (requiresBasePrice && (!newProduct.price || !newProduct.mrp))) {
      toast.error('Please fill in all required fields')
      return
    }
    if (hasVariantsNew && newProductVariants.length === 0) {
      toast.error('Please add at least one variant option')
      return
    }

    setIsCreatingProduct(true)
    try {
      const tagsArray = newProduct.tags
        ? newProduct.tags.split(',').map((t) => t.trim()).filter((t) => t.length > 0)
        : []

      let resolvedCategoryId = newProduct.categoryId
      if (newProduct.restaurantId || isSpecialProduct) {
        const restCat = categories.find(c => 
          c.slug === 'restaurant' || c.slug === 'cafe' || 
          c.name.toLowerCase().includes('restaurant') || c.name.toLowerCase().includes('food')
        )
        if (restCat) {
          resolvedCategoryId = restCat.id
        }
      }

      const res = await fetch('/api/products', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...newProduct,
          categoryId: resolvedCategoryId || newProduct.categoryId,
          mrp: hasVariantsNew && newProductVariants.length > 0 ? parseFloat(newProductVariants[0].mrp) : parseFloat(newProduct.mrp),
          price: hasVariantsNew && newProductVariants.length > 0 ? parseFloat(newProductVariants[0].price) : parseFloat(newProduct.price),
          stock: (isNewProductCafe || isNewProductRestaurant) ? 99999 : (hasVariantsNew && newProductVariants.length > 0 ? newProductVariants.reduce((sum, v) => sum + (parseInt(v.stock) || 0), 0) : (parseInt(newProduct.stock) || 0)),
          minStock: (isNewProductCafe || isNewProductRestaurant) ? 0 : (parseInt(newProduct.minStock) || 10),
          expiryDate: newProduct.expiryDate ? new Date(newProduct.expiryDate).toISOString() : null,
          costPrice: parseFloat(newProduct.costPrice) || 0,
          tags: tagsArray,
          variants: hasVariantsNew ? newProductVariants.map(v => ({
            name: v.name,
            price: parseFloat(v.price) || 0,
            mrp: parseFloat(v.mrp) || 0,
            costPrice: parseFloat(v.costPrice) || 0,
            stock: parseInt(v.stock) || 0,
          })) : null,
        }),
      })

      if (res.ok) {
        const created = await res.json()
        setProducts([created, ...products])
        setAllProducts([created, ...allProducts])
        toast.success(`Product "${created.name}" created successfully!`)
        setShowAddProduct(false)
        setNewProductVariants([])
        setHasVariantsNew(false)
        setNewProduct({
          name: '',
          description: '',
          imageUrl: '',
          categoryId: initialCategories?.[0]?.id || '',
          restaurantId: '',
          mrp: '',
          price: '',
          unit: '',
          stock: '',
          isAvailable: true,
          tags: '',
          minStock: '10',
          expiryDate: '',
          costPrice: '0',
          location: '',
          isFlashDeal: false,
          isTopPick: false,
          isBestSeller: false,
          sortOrder: '0',
          barcode: '',
        })

      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to create product')
      }
    } catch (err) {
      toast.error('Error creating product')
    } finally {
      setIsCreatingProduct(false)
    }
  }

  const handleDeleteProduct = async (productId: string) => {
    if (!confirm('⚠️ Are you sure you want to PERMANENTLY delete this product? This action cannot be undone.')) {
      return
    }

    try {
      const res = await fetch(`/api/products/${productId}`, {
        method: 'DELETE',
      })

      if (res.ok) {
        setProducts(products.filter((p) => p.id !== productId))
        setAllProducts(allProducts.filter((p) => p.id !== productId))
        toast.success('Product permanently deleted.')
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to delete product')
      }
    } catch (err) {
      toast.error('Error deleting product')
    }
  }

  // ----------------------------------------------------
  // Handlers for Category Management
  // ----------------------------------------------------
  const handleCreateCategory = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newCategory.name) {
      toast.error('Please enter a category name')
      return
    }

    setIsCreatingCategory(true)
    try {
      const res = await fetch('/api/categories', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: newCategory.name,
          imageUrl: newCategory.imageUrl,
          sortOrder: newCategory.sortOrder,
          parentId: newCategory.parentId || null,
        }),
      })

      if (res.ok) {
        const created = await res.json()
        // Map to format containing _count
        const formattedCreated = {
          ...created,
          _count: { products: 0 }
        }
        setCategories([...categories, formattedCreated])
        toast.success(`Category "${created.name}" created successfully!`)
        setShowAddCategory(false)
        setNewCategory({ name: '', imageUrl: '', sortOrder: '0', parentId: '' })
      } else {
        toast.error('Failed to create category')
      }
    } catch (err) {
      toast.error('Error creating category')
    } finally {
      setIsCreatingCategory(false)
    }
  }

  const startEditingCategory = (c: any) => {
    setEditingCategory(c)
    setCategoryEditForm({
      name: c.name || '',
      imageUrl: c.imageUrl || '',
      sortOrder: String(c.sortOrder || '0'),
      parentId: c.parentId || '',
    })
  }

  const saveCategoryChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingCategory) return

    setSavingCategoryId(editingCategory.id)
    try {
      const res = await fetch(`/api/categories/${editingCategory.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: categoryEditForm.name,
          imageUrl: categoryEditForm.imageUrl,
          sortOrder: parseInt(categoryEditForm.sortOrder) || 0,
          parentId: categoryEditForm.parentId || null,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCategories(categories.map((c) => (c.id === editingCategory.id ? { ...c, ...updated } : c)))
        toast.success('Category updated successfully!')
        setEditingCategory(null)
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to update category')
      }
    } catch (err) {
      toast.error('Error updating category')
    } finally {
      setSavingCategoryId(null)
    }
  }

  const handleDeleteCategory = async (categoryId: string) => {
    if (!confirm('Are you sure you want to delete this category? This action cannot be undone.')) {
      return
    }
    setDeletingCategoryId(categoryId)
    try {
      const res = await fetch(`/api/categories/${categoryId}`, {
        method: 'DELETE',
      })

      if (res.ok) {
        setCategories(categories.filter((c) => c.id !== categoryId))
        toast.success('Category deleted successfully!')
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to delete category')
      }
    } catch (err) {
      toast.error('Error deleting category')
    } finally {
      setDeletingCategoryId(null)
    }
  }

  // ----------------------------------------------------
  // Handlers for Reviews Management
  // ----------------------------------------------------
  const startEditingReview = (r: any) => {
    setEditingReview(r)
    setReviewEditForm({
      rating: r.rating || 5,
      comment: r.comment || '',
    })
  }

  const saveReviewChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingReview) return

    setSavingReviewId(editingReview.id)
    try {
      const res = await fetch('/api/admin/reviews', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          reviewId: editingReview.id,
          rating: reviewEditForm.rating,
          comment: reviewEditForm.comment,
          type: editingReview.type,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setReviews(reviews.map((r: any) => (r.id === editingReview.id ? { ...r, rating: updated.rating, comment: updated.comment } : r)))
        toast.success('Review updated successfully!')
        setEditingReview(null)
      } else {
        toast.error('Failed to update review')
      }
    } catch (err) {
      toast.error('Error saving review changes')
    } finally {
      setSavingReviewId(null)
    }
  }

  const handleDeleteReview = async (reviewId: string) => {
    if (!confirm('Delete this customer review? This action cannot be undone.')) return
    const reviewType = (reviews as any[]).find(r => r.id === reviewId)?.type
    setDeletingReviewId(reviewId)
    try {
      const res = await fetch('/api/admin/reviews', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reviewId, type: reviewType }),
      })
      if (res.ok) {
        setReviews(reviews.filter((r: any) => r.id !== reviewId))
        toast.success('Review deleted successfully')
      } else {
        toast.error('Failed to delete review')
      }
    } catch (err) {
      toast.error('Error deleting review')
    } finally {
      setDeletingReviewId(null)
    }
  }

  // Filtered reviews
  const filteredReviews = reviews.filter((r: any) => {
    if (!reviewSearch) return true
    const q = reviewSearch.toLowerCase()
    return (
      r.user.name?.toLowerCase().includes(q) ||
      r.user.email?.toLowerCase().includes(q) ||
      r.product.name?.toLowerCase().includes(q) ||
      r.comment?.toLowerCase().includes(q)
    )
  })

  // Star render helper
  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={`h-3.5 w-3.5 ${
          i < rating
            ? 'text-yellow-500 fill-yellow-500'
            : 'text-border'
        }`}
      />
    ))
  }

  // Average rating
  const avgRating = reviews.length > 0
    ? (reviews.reduce((sum: number, r: any) => sum + r.rating, 0) / reviews.length).toFixed(1)
    : '0.0'

  // ----------------------------------------------------
  // Handlers for Coupons / Offers Management
  // ----------------------------------------------------
  const handleCreateCoupon = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newCoupon.code || !newCoupon.value) {
      toast.error('Coupon code and discount value are required')
      return
    }

    setIsCreatingCoupon(true)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newCoupon),
      })

      if (res.ok) {
        const created = await res.json()
        setCoupons([created, ...coupons])
        toast.success(`Coupon "${created.code}" created!`)
        setShowAddCoupon(false)
        setNewCoupon({
          code: '',
          discountType: 'PERCENT',
          value: '',
          minOrder: '',
          maxDiscount: '',
          maxUses: '',
          isActive: true,
          expiresAt: '',
          categoryId: '',
          oncePerCustomer: false,
        })
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to create coupon')
      }
    } catch (err) {
      toast.error('Error creating coupon')
    } finally {
      setIsCreatingCoupon(false)
    }
  }

  const startEditingCoupon = (c: any) => {
    setEditingCoupon(c)
    setCouponEditForm({
      code: c.code || '',
      discountType: c.discountType || 'PERCENT',
      value: String(c.value || ''),
      minOrder: String(c.minOrder || ''),
      maxDiscount: c.maxDiscount ? String(c.maxDiscount) : '',
      maxUses: c.maxUses ? String(c.maxUses) : '',
      expiresAt: c.expiresAt ? c.expiresAt.slice(0, 10) : '',
      isActive: c.isActive !== false,
      categoryId: c.categoryId || '',
      oncePerCustomer: c.oncePerCustomer === true,
    })
  }

  const saveCouponChanges = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!editingCoupon) return

    setSavingCouponId(editingCoupon.id)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          couponId: editingCoupon.id,
          code: couponEditForm.code,
          discountType: couponEditForm.discountType,
          value: parseFloat(couponEditForm.value) || 0,
          minOrder: parseFloat(couponEditForm.minOrder) || 0,
          maxDiscount: couponEditForm.maxDiscount ? parseFloat(couponEditForm.maxDiscount) : null,
          maxUses: couponEditForm.maxUses ? parseInt(couponEditForm.maxUses) : null,
          expiresAt: couponEditForm.expiresAt || null,
          isActive: couponEditForm.isActive,
          categoryId: couponEditForm.categoryId || null,
          oncePerCustomer: couponEditForm.oncePerCustomer,
        }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCoupons(coupons.map((c: any) => (c.id === editingCoupon.id ? { ...c, ...updated } : c)))
        toast.success('Coupon updated successfully!')
        setEditingCoupon(null)
      } else {
        const err = await res.json()
        toast.error(err.error || 'Failed to update coupon')
      }
    } catch (err) {
      toast.error('Error saving coupon changes')
    } finally {
      setSavingCouponId(null)
    }
  }

  const handleToggleCoupon = async (couponId: string, currentActive: boolean) => {
    setSavingCouponId(couponId)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ couponId, isActive: !currentActive }),
      })

      if (res.ok) {
        const updated = await res.json()
        setCoupons(coupons.map((c: any) => (c.id === couponId ? { ...c, ...updated } : c)))
        toast.success(`Coupon ${!currentActive ? 'activated' : 'deactivated'}`)
      } else {
        toast.error('Failed to toggle coupon')
      }
    } catch (err) {
      toast.error('Error toggling coupon')
    } finally {
      setSavingCouponId(null)
    }
  }

  const handleDeleteCoupon = async (couponId: string) => {
    if (!confirm('Delete this coupon permanently?')) return
    setDeletingCouponId(couponId)
    try {
      const res = await fetch('/api/admin/coupons', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ couponId }),
      })
      if (res.ok) {
        setCoupons(coupons.filter((c: any) => c.id !== couponId))
        toast.success('Coupon deleted')
      } else {
        toast.error('Failed to delete coupon')
      }
    } catch (err) {
      toast.error('Error deleting coupon')
    } finally {
      setDeletingCouponId(null)
    }
  }

  // Filtered Products
  const filteredProducts = products.filter((p) => {
    const matchesSearch = 
      p.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.description && p.description.toLowerCase().includes(searchQuery.toLowerCase()))
    
    const matchesCategory = 
      !selectedCategoryFilter || p.categoryId === selectedCategoryFilter
      
    const isCafeItem = p.tags?.some((t: string) => t.toLowerCase() === 'cafe')
    const isRestaurantItem = p.tags?.some((t: string) => t.toLowerCase() === 'restaurant')
    const matchesType = 
      selectedTypeFilter === 'all' ||
      (selectedTypeFilter === 'cafe' && isCafeItem) ||
      (selectedTypeFilter === 'restaurant' && isRestaurantItem) ||
      (selectedTypeFilter === 'grocery' && !isCafeItem && !isRestaurantItem)

    return matchesSearch && matchesCategory && matchesType
  })

  const tabConfig: { key: TabType; label: string; icon: any; count?: number }[] = [
    { key: 'orders', label: 'Orders', icon: ShoppingBag, count: orderTotal },
    { key: 'liveops', label: 'Live Ops Tracker', icon: Zap, count: activeCartsCount },
    { key: 'products', label: 'Products', icon: Package, count: productTotal },
    { key: 'categories', label: 'Categories', icon: Layers, count: categories.length },
    { key: 'alerts', label: 'Stock Alerts', icon: AlertCircle, count: stats.lowStockCount },
    { key: 'inward', label: 'Inward Items (GRN)', icon: Building2 },
    { key: 'bulk-update', label: 'Bulk Update', icon: SlidersHorizontal },
    { key: 'csv-import', label: 'CSV Import', icon: Download },
    { key: 'restaurant-console', label: 'Restaurant Console', icon: Utensils },
    { key: 'reports', label: 'Finance & Sales', icon: IndianRupee },
    { key: 'restaurant-report', label: 'Restaurant Payouts', icon: Utensils },
    { key: 'users', label: 'Staff & Customers', icon: Users, count: userTotal },
    { key: 'rider-cash', label: 'Rider Cash & Settlement', icon: Wallet },
    { key: 'reviews', label: 'Reviews', icon: Star, count: reviews.length },
    { key: 'coupons', label: 'Offers', icon: Ticket, count: coupons.length },
    { key: 'banners', label: 'Promo Banners', icon: ImageIcon },
    { key: 'flash-deals', label: 'Store Highlights', icon: Zap },
    { key: 'push-notifications', label: 'Push Notifications', icon: Bell },
    { key: 'settings', label: 'Store Settings', icon: Settings },
    { key: 'analytics', label: 'Analytics', icon: TrendingUp },
    { key: 'forecast', label: 'AI Forecasting', icon: BrainCircuit },
  ]

  return (
    <div className="space-y-6">
      
      {/* Delayed Action Warning Alert Banner */}
      {delayedOrders.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="relative overflow-hidden rounded-2xl border border-rose-500/20 bg-gradient-to-r from-rose-500/10 via-amber-500/5 to-rose-500/10 p-5 shadow-lg backdrop-blur-md animate-glow-pulse"
        >
          {/* Decorative glowing pulse */}
          <div className="absolute right-0 top-0 -mr-6 -mt-6 h-24 w-24 rounded-full bg-rose-500/10 blur-xl animate-pulse" />
          
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div className="flex items-start gap-3.5">
              <div className="relative flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-rose-500/10 text-rose-500">
                <AlertCircle className="h-5 w-5 animate-bounce-subtle" />
                <span className="absolute -right-0.5 -top-0.5 flex h-2.5 w-2.5">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-rose-500"></span>
                </span>
              </div>
              <div>
                <h3 className="text-sm font-black text-rose-500 flex items-center gap-2">
                  Operational Bottlenecks Detected
                  <span className="rounded-full bg-rose-500/10 px-2.5 py-0.5 text-xs font-bold text-rose-600">
                    {delayedOrders.length} {delayedOrders.length === 1 ? 'order' : 'orders'} delayed
                  </span>
                </h3>
                <p className="text-xs text-text-secondary mt-0.5 max-w-2xl font-medium">
                  The following orders have exceeded the 10-minute queue limit. Please coordinate with staff immediately to prevent service level degradation.
                </p>
              </div>
            </div>
            
            {/* Control buttons */}
            <div className="flex items-center gap-2 self-end md:self-center">
              <button
                onClick={() => setIsChimeMuted(!isChimeMuted)}
                className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg border text-xs font-bold transition-all ${
                  isChimeMuted 
                    ? 'bg-muted/80 border-border/80 text-text-secondary hover:text-text-primary hover:bg-muted' 
                    : 'bg-rose-500/10 border-rose-500/30 text-rose-600 hover:bg-rose-500/20'
                }`}
              >
                {isChimeMuted ? (
                  <>
                    <VolumeX className="h-3.5 w-3.5" />
                    <span>Muted</span>
                  </>
                ) : (
                  <>
                    <Volume2 className="h-3.5 w-3.5 animate-pulse" />
                    <span>Alert Active</span>
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Breakdown Pills */}
          <div className="flex flex-wrap gap-2 mt-4">
            {pickerDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-amber-500/10 border border-amber-500/20 px-2.5 py-1 text-xs font-semibold text-amber-600">
                <ShoppingBag className="h-3.5 w-3.5" />
                <span>Grocery Picker Delay: {pickerDelays.length}</span>
              </div>
            )}
            {chefDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-orange-500/10 border border-orange-500/20 px-2.5 py-1 text-xs font-semibold text-orange-600">
                <Utensils className="h-3.5 w-3.5" />
                <span>Cafe Chef Delay: {chefDelays.length}</span>
              </div>
            )}
            {riderDelays.length > 0 && (
              <div className="flex items-center gap-1.5 rounded-lg bg-rose-500/10 border border-rose-500/20 px-2.5 py-1 text-xs font-semibold text-rose-600">
                <Clock className="h-3.5 w-3.5" />
                <span>Rider Dispatch Delay: {riderDelays.length}</span>
              </div>
            )}
          </div>

          {/* List of delayed orders */}
          <div className="mt-4 border-t border-rose-500/10 pt-3">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2 max-h-48 overflow-y-auto pr-1 scrollbar-none">
              {delayedOrders.map((order) => {
                const isRestaurant = !!order.restaurantId || order.orderType === 'RESTAURANT'
                const isPacked = order.status === 'PACKED'
                const baseTime = order.status === 'PENDING' ? order.createdAt : (order.updatedAt || order.createdAt)
                const delayMin = Math.floor((new Date().getTime() - new Date(baseTime).getTime()) / 60000)
                
                let delayType = 'Grocery Picker'
                let delayColor = 'border-amber-500/20 bg-amber-500/5 text-amber-700 dark:text-amber-400'
                if (isPacked) {
                  delayType = 'Rider Delivery'
                  delayColor = 'border-rose-500/20 bg-rose-500/5 text-rose-700 dark:text-rose-400'
                } else if (isRestaurant) {
                  delayType = 'Kitchen Chef'
                  delayColor = 'border-orange-500/20 bg-orange-500/5 text-orange-700 dark:text-orange-400'
                }

                const pendingIdx = livePendingOrders.findIndex((po) => po.id === order.id)
                const fifoRank = pendingIdx !== -1 ? pendingIdx + 1 : null

                return (
                  <div 
                    key={order.id}
                    className={`flex items-center justify-between rounded-xl border p-2.5 text-xs font-medium ${delayColor}`}
                  >
                    <div className="flex flex-col gap-0.5">
                      <span className="font-bold flex items-center gap-1.5">
                        Order #{order.readableId || order.id.slice(0, 8)}
                        {fifoRank && (
                          <span className={`text-[8px] font-black px-1.5 py-0.2 rounded-full ${
                            fifoRank === 1 
                              ? 'bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/20' 
                              : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800/40 dark:text-zinc-400 border border-border/40'
                          }`}>
                            {fifoRank === 1 ? '👑 FIFO #1' : `FIFO #${fifoRank}`}
                          </span>
                        )}
                      </span>
                      <span className="text-[10px] opacity-80">{delayType} • {order.userName || order.userEmail || 'Guest'}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <span className="rounded bg-black/5 px-1.5 py-0.5 text-[10px] font-black">
                        {delayMin}m delay
                      </span>
                      <button
                        onClick={() => {
                          setActiveTab('orders')
                          setOrderStatusFilter('ALL')
                          setOrderSearchQuery(order.id)
                        }}
                        className="rounded-lg bg-card p-1 text-text-primary shadow-sm hover:bg-muted transition-colors border border-border/40"
                        title="View order"
                      >
                        <Eye className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </motion.div>
      )}

      <DashboardStatsCards
        stats={{
          todaySales: apiTodaySales ?? stats.todaySales ?? todaySales,
          todayOrdersCount: apiTodayOrdersCount ?? stats.todayOrdersCount ?? todayOrdersCount,
          netSales: apiTodayNetSales ?? stats.netSales ?? netSales,
          orderCount: stats.orderCount || orderTotal,
          activeOrderCount: stats.activeOrderCount ?? liveOrders.filter((o: any) => ['PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY'].includes(o.status)).length,
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
          {activeTab === 'orders' && (
            <OrdersTab
              orders={orders}
              orderCounts={orderCounts}
              orderStatusFilter={orderStatusFilter}
              setOrderStatusFilter={setOrderStatusFilter}
              orderSearchQuery={orderSearchQuery}
              setOrderSearchQuery={setOrderSearchQuery}
              orderShopFilter={orderShopFilter}
              setOrderShopFilter={setOrderShopFilter}
              orderMethodFilter={orderMethodFilter}
              setOrderMethodFilter={setOrderMethodFilter}
              ordersSubTab={ordersSubTab}
              setOrdersSubTab={setOrdersSubTab}
              updatingOrderId={updatingOrderId}
              onUpdateOrderStatus={handleOrderStatusChange}
              onOpenOrderModal={handleOpenOrderModal}
              onOpenCreateOrderModal={() => setIsCreateOrderOpen(true)}
              onNavigateToUsersTab={() => setActiveTab('users')}
              livePendingOrders={livePendingOrders}
            />
          )}

      {/* ---------------------------------------------------- */}
      {/* PRODUCTS & INVENTORY TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'products' && (
        <ProductsTab
          products={products}
          categories={categories}
          restaurantsList={restaurantsList}
          settingsMap={settingsMap}
          filteredProducts={filteredProducts}
          searchQuery={searchQuery}
          selectedTypeFilter={selectedTypeFilter}
          selectedCategoryFilter={selectedCategoryFilter}
          showAddProduct={showAddProduct}
          showSortManager={showSortManager}
          showCsvImport={showCsvImport}
          showExportModal={showExportModal}
          isExporting={isExporting}
          isCreatingProduct={isCreatingProduct}
          newProduct={newProduct}
          newProductType={newProductType}
          editProductType={editProductType}
          newProductVariants={newProductVariants}
          editProductVariants={editProductVariants}
          hasVariantsNew={hasVariantsNew}
          hasVariantsEdit={hasVariantsEdit}
          newCustomTag={newCustomTag}
          editCustomTag={editCustomTag}
          isUploading={isUploading}
          productPage={productPage}
          productTotal={productTotal}
          editingProduct={editingProduct}
          savingProductId={savingProductId}
          setShowAddProduct={setShowAddProduct}
          setShowSortManager={setShowSortManager}
          setShowCsvImport={setShowCsvImport}
          setShowExportModal={setShowExportModal}
          setNewProduct={setNewProduct}
          setNewProductType={setNewProductType}
          setEditProductType={setEditProductType}
          setNewProductVariants={setNewProductVariants}
          setEditProductVariants={setEditProductVariants}
          setHasVariantsNew={setHasVariantsNew}
          setHasVariantsEdit={setHasVariantsEdit}
          setNewCustomTag={setNewCustomTag}
          setEditingProduct={setEditingProduct}
          setProductPage={setProductPage}
          setMediaTarget={setMediaTarget}
          setShowMediaLibrary={setShowMediaLibrary}
          setSearchQuery={setSearchQuery}
          setSelectedTypeFilter={setSelectedTypeFilter}
          setSelectedCategoryFilter={setSelectedCategoryFilter}
          setProducts={setProducts}
          setAllProducts={setAllProducts}
          handleNewProductTypeChange={handleNewProductTypeChange}
          handleEditProductTypeChange={handleEditProductTypeChange}
          applyProductTemplate={applyProductTemplate}
          toggleTag={toggleTag}
          handleCreateCustomTag={handleCreateCustomTag}
          handleCreateProduct={handleCreateProduct}
          handleToggleProductAvailability={handleToggleProductAvailability}
          handleDeleteProduct={handleDeleteProduct}
          startEditingProduct={startEditingProduct}
          handleDuplicateProduct={handleDuplicateProduct}
          handleCloudinaryUpload={handleCloudinaryUpload}
          handleExportCsv={handleExportCsv}
          handleReplenishCsv={handleReplenishCsv}
          renderPagination={renderPagination}
        />
      )}

      {/* ---------------------------------------------------- */}
      {/* CATEGORIES TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'categories' && (
        <CategoriesTab
          categories={categories}
          newCategory={newCategory}
          showAddCategory={showAddCategory}
          editingCategory={editingCategory}
          savingCategoryId={savingCategoryId}
          deletingCategoryId={deletingCategoryId}
          categoryEditForm={categoryEditForm}
          isCreatingCategory={isCreatingCategory}
          showMediaLibrary={showMediaLibrary}
          mediaTarget={mediaTarget}
          mediaSearchQuery={mediaSearchQuery}
          setNewCategory={setNewCategory}
          setShowAddCategory={setShowAddCategory}
          setEditingCategory={setEditingCategory}
          setCategoryEditForm={setCategoryEditForm}
          setSavingCategoryId={setSavingCategoryId}
          setDeletingCategoryId={setDeletingCategoryId}
          setMediaTarget={setMediaTarget}
          setShowMediaLibrary={setShowMediaLibrary}
          handleCreateCategory={handleCreateCategory}
          handleDeleteCategory={handleDeleteCategory}
          saveCategoryChanges={saveCategoryChanges}
          startEditingCategory={startEditingCategory}
          handleImageFileChange={handleImageFileChange}
        />
      )}

      {/* ---------------------------------------------------- */}
      {/* CUSTOMERS / USERS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'users' && (
        <UsersTab
          users={users}
          userPage={userPage}
          userTotal={userTotal}
          userSearch={userSearch}
          userRoleFilter={userRoleFilter}
          userStatusFilter={userStatusFilter}
          isExportingUsers={isExportingUsers}
          editingPhoneUserId={editingPhoneUserId}
          phoneInput={phoneInput}
          savingPhoneId={savingPhoneId}
          settingPasswordUserId={settingPasswordUserId}
          passwordInput={passwordInput}
          savingPasswordId={savingPasswordId}
          isUpdatingBlockStatus={isUpdatingBlockStatus}
          setUserPage={setUserPage}
          setUserSearch={setUserSearch}
          setUserRoleFilter={setUserRoleFilter}
          setUserStatusFilter={setUserStatusFilter}
          setEditingPhoneUserId={setEditingPhoneUserId}
          setPhoneInput={setPhoneInput}
          setSettingPasswordUserId={setSettingPasswordUserId}
          setPasswordInput={setPasswordInput}
          handleExportCustomersCsv={handleExportCustomersCsv}
          handleUserPhoneSave={handleUserPhoneSave}
          handleUserRoleChange={handleUserRoleChange}
          handleSetPassword={handleSetPassword}
          handleToggleBlock={handleToggleBlock}
          onRequestBlock={setBlockingUser}
          renderPagination={renderPagination}
        />
      )}

      {/* ---------------------------------------------------- */}
      {/* REVIEWS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'reviews' && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Reviews header with stats */}
          <div className="flex flex-col md:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border shadow-sm">
            <div className="flex items-center gap-4">
              <div>
                <h3 className="font-extrabold text-text-primary text-base">Customer Reviews</h3>
                <p className="text-[10px] text-text-secondary mt-0.5">
                  Monitor, moderate & manage all product feedback
                </p>
              </div>
              <div className="flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/20 px-3 py-1.5 rounded-xl">
                <Star className="h-4 w-4 text-yellow-500 fill-yellow-500" />
                <span className="text-sm font-black text-yellow-600 dark:text-yellow-400">{avgRating}</span>
                <span className="text-[10px] font-bold text-text-secondary">avg ({reviews.length} reviews)</span>
              </div>
            </div>
            <div className="relative w-full md:w-72">
              <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
              <input
                type="text"
                placeholder="Search by customer, product, comment..."
                value={reviewSearch}
                onChange={(e) => setReviewSearch(e.target.value)}
                className="pl-9 pr-4 py-2 w-full text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
          </div>

          {/* Rating distribution bar */}
          <div className="bg-card border border-border rounded-2xl p-5 shadow-sm">
            <h4 className="text-xs font-extrabold text-text-primary mb-3">Rating Distribution</h4>
            <div className="space-y-2">
              {[5, 4, 3, 2, 1].map((star) => {
                const count = reviews.filter((r: any) => r.rating === star).length
                const pct = reviews.length > 0 ? (count / reviews.length) * 100 : 0
                return (
                  <div key={star} className="flex items-center gap-3">
                    <div className="flex items-center gap-0.5 w-16 justify-end">
                      <span className="text-[11px] font-bold text-text-primary">{star}</span>
                      <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                    </div>
                    <div className="flex-1 h-2.5 bg-muted/50 rounded-full overflow-hidden border border-border/40">
                      <div
                        className="h-full rounded-full transition-all duration-500"
                        style={{
                          width: `${pct}%`,
                          background: star >= 4
                            ? 'linear-gradient(90deg, #22c55e, #4ade80)'
                            : star === 3
                              ? 'linear-gradient(90deg, #eab308, #facc15)'
                              : 'linear-gradient(90deg, #ef4444, #f87171)',
                        }}
                      />
                    </div>
                    <span className="text-[10px] font-bold text-text-muted w-12 text-right">{count} ({pct.toFixed(0)}%)</span>
                  </div>
                )
              })}
            </div>
          </div>

          {/* Reviews List */}
          <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse text-xs">
                <thead>
                  <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                    <th className="py-3 px-4">Customer</th>
                    <th className="py-3 px-4">Product</th>
                    <th className="py-3 px-4">Rating</th>
                    <th className="py-3 px-4">Comment</th>
                    <th className="py-3 px-4">Date</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40 font-semibold">
                  {isLoadingReviews ? (
                    <tr>
                      <td colSpan={6} className="text-center py-10 text-text-secondary">
                        <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2 text-primary" />
                        Loading reviews...
                      </td>
                    </tr>
                  ) : filteredReviews.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="text-center py-10 text-text-secondary">
                        <MessageSquare className="h-8 w-8 mx-auto mb-2 text-text-muted" />
                        No reviews found.
                      </td>
                    </tr>
                  ) : (
                    filteredReviews.map((r: any) => (
                      <tr key={r.id} className="hover:bg-muted/30">
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <div className="h-7 w-7 rounded-full bg-yellow-500/10 flex items-center justify-center text-yellow-600 font-bold text-[10px]">
                              {r.user.name?.charAt(0) || 'U'}
                            </div>
                            <div>
                              <div className="font-bold text-text-primary text-[11px]">{r.user.name || 'Anonymous'}</div>
                              <div className="text-[9px] text-text-muted font-normal">{formatDisplayEmail(r.user.email)}</div>
                            </div>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2">
                            <span className="text-lg h-7 w-7 bg-muted/60 flex items-center justify-center rounded-lg border text-[11px]">
                              {r.product.imageUrl && r.product.imageUrl.length < 5 ? r.product.imageUrl : '📦'}
                            </span>
                            <span className="font-bold text-text-primary text-[11px] max-w-[140px] truncate">{r.product.name}</span>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-0.5">
                            {renderStars(r.rating)}
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <p className="text-text-secondary font-medium text-[11px] max-w-[250px] truncate">
                            {r.comment || <span className="italic text-text-muted">No comment</span>}
                          </p>
                        </td>
                        <td className="py-3 px-4 text-text-muted font-medium text-[10px]">
                          {formatDate(r.createdAt, 'd MMM yyyy')}
                        </td>
                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              onClick={() => startEditingReview(r)}
                              className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all"
                            >
                              Edit
                            </button>
                            <button
                              onClick={() => handleDeleteReview(r.id)}
                              disabled={deletingReviewId === r.id}
                              className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors inline-flex items-center justify-center"
                            >
                              {deletingReviewId === r.id ? (
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                              ) : (
                                <Trash className="h-3.5 w-3.5" />
                              )}
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

        </div>
      )}

      {/* ---------------------------------------------------- */}
      {/* COUPONS / OFFERS TAB */}
      {/* ---------------------------------------------------- */}
      {/* COUPONS TAB */}
      {/* ---------------------------------------------------- */}
      {activeTab === 'coupons' && (
        <CouponsTab
          coupons={coupons}
          categories={categories}
          showAddCoupon={showAddCoupon}
          isCreatingCoupon={isCreatingCoupon}
          isLoadingCoupons={isLoadingCoupons}
          savingCouponId={savingCouponId}
          deletingCouponId={deletingCouponId}
          newCoupon={newCoupon}
          editingCoupon={editingCoupon}
          couponEditForm={couponEditForm}
          setShowAddCoupon={setShowAddCoupon}
          setNewCoupon={setNewCoupon}
          setEditingCoupon={setEditingCoupon}
          setCouponEditForm={setCouponEditForm}
          handleCreateCoupon={handleCreateCoupon}
          saveCouponChanges={saveCouponChanges}
          handleToggleCoupon={handleToggleCoupon}
          handleDeleteCoupon={handleDeleteCoupon}
          startEditingCoupon={startEditingCoupon}
        />
      )}

      {activeTab === 'liveops' && (
        <LiveOpsTab
          liveOrders={liveOrders}
          livePendingOrders={livePendingOrders}
          delayedOrders={delayedOrders}
          activeCarts={activeCarts}
          isLoadingCarts={isLoadingCarts}
          cartsRefreshKey={cartsRefreshKey}
          setCartsRefreshKey={setCartsRefreshKey}
          sendCartNotification={sendCartNotification}
          openWhatsAppModal={openWhatsAppModal}
        />
      )}

      {activeTab === 'analytics' && (
        <AnalyticsTab
          products={allProducts}
          orders={liveOrders}
          categories={categories}
          stats={{
            revenue: stats.revenue,
            orderCount: stats.orderCount,
            lowStockCount: stats.lowStockCount
          }}
        />
      )}

      {activeTab === 'forecast' && (
        <ForecastTab
          categories={categories}
          onRestockCompleted={async () => {
            try {
              const res = await fetch('/api/products?limit=1000')
              if (res.ok) {
                const data = await res.json()
                if (data.products) {
                  setProducts(data.products)
                  setAllProducts(data.products)
                }
              }
            } catch (err) {
              console.error(err)
            }
          }}
        />
      )}

      {activeTab === 'alerts' && (
        <AlertsTab
          onProductUpdated={async () => {
            try {
              const res = await fetch('/api/products?limit=1000')
              if (res.ok) {
                const data = await res.json()
                if (data.products) {
                  setProducts(data.products)
                  setAllProducts(data.products)
                }
              }
            } catch (err) {
              console.error(err)
            }
          }}
        />
      )}

      {activeTab === 'inward' && (
        <InwardTab />
      )}

      {activeTab === 'bulk-update' && (
        <BulkUpdateTab
          categories={categories}
          onUpdateCompleted={async () => {
            try {
              const res = await fetch('/api/products?limit=1000')
              if (res.ok) {
                const data = await res.json()
                if (data.products) {
                  setProducts(data.products)
                  setAllProducts(data.products)
                }
              }
            } catch (err) {
              console.error(err)
            }
          }}
        />
      )}

      {activeTab === 'reports' && (
        <ReportsTab />
      )}

      {activeTab === 'restaurant-report' && (
        <RestaurantReportTab />
      )}

      {activeTab === 'banners' && (
        <BannersTab categories={categories} products={allProducts} />
      )}

      {activeTab === 'settings' && (
        <SettingsTab onSettingsSaved={fetchSettings} />
      )}

      {activeTab === 'push-notifications' && (
        <PushNotificationsTab />
      )}

      {activeTab === 'flash-deals' && (
        <FlashDealsTab />
      )}

      {activeTab === 'rider-cash' && (
        <RiderCashTab />
      )}

      {activeTab === 'csv-import' && (
        <CsvImportTab categories={categories} />
      )}

      {activeTab === 'restaurant-console' && (
        <RestaurantConsoleTab />
      )}

        </motion.div>
      </AnimatePresence>

      {/* Product Edit Modal */}
      {editingProduct && (
        <ProductEditModal
          editingProduct={editingProduct}
          productEditForm={productEditForm}
          saveProductChanges={saveProductChanges}
          setEditingProduct={setEditingProduct}
          setProductEditForm={setProductEditForm}
          setHasVariantsEdit={setHasVariantsEdit}
          setEditProductVariants={setEditProductVariants}
          setNewCustomTag={setNewCustomTag}
          setShowMediaLibrary={setShowMediaLibrary}
          setMediaTarget={setMediaTarget}
          handleCloudinaryUpload={handleCloudinaryUpload}
          handleCreateCustomTag={handleCreateCustomTag}
          toggleTag={toggleTag}
          savingProductId={savingProductId}
          isUploading={isUploading}
          isEditProductCafe={isEditProductCafe}
          isEditProductRestaurant={isEditProductRestaurant}
          restaurantsList={restaurantsList}
          categories={categories}
          settingsMap={settingsMap}
          editProductVariants={editProductVariants}
          newCustomTag={newCustomTag}
          RESTAURANT_MENU_SECTIONS={RESTAURANT_MENU_SECTIONS}
          PRESET_KITCHEN_PHOTOS={PRESET_KITCHEN_PHOTOS}
        />
      )}

      {/* Category Edit Modal */}
      {false && (
        <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-2xl max-h-[90vh] overflow-y-auto p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Product: {editingProduct.name}</h4>
              <button onClick={() => setEditingProduct(null)} className="text-text-secondary hover:text-text-primary">
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={saveProductChanges} className="space-y-4">
              {/* Store / Outlet Selector */}
              <div className="bg-primary/5 border border-primary/20 rounded-xl p-3">
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Assign to Store / Restaurant Outlet *</label>
                <select
                  value={productEditForm.restaurantId}
                  onChange={(e) => setProductEditForm({ ...productEditForm, restaurantId: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border border-primary/30 bg-card focus:outline-none focus:border-primary font-bold text-text-primary cursor-pointer shadow-2xs"
                >
                  <option value="">🛒 General Kirana / Grocery Store</option>
                  {restaurantsList.map((r) => (
                    <option key={r.id} value={r.id}>
                      🍽️ Restaurant: {r.name} ({r.city || 'Outlet'})
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Product Name *</label>
                  <input
                    type="text"
                    required
                    value={productEditForm.name}
                    onChange={(e) => setProductEditForm({ ...productEditForm, name: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                {!productEditForm.restaurantId ? (() => {
                  const currentCat = categories.find(c => c.id === productEditForm.categoryId)
                  const activeParentId = currentCat ? (currentCat.parentId || currentCat.id) : ''
                  const activeSubId = currentCat && currentCat.parentId ? currentCat.id : ''

                  const parentCategories = categories.filter((c) => {
                    const slug = (c.slug || '').toLowerCase()
                    const name = (c.name || '').toLowerCase()
                    return !c.parentId && slug !== 'cafe' && slug !== 'restaurant' && !name.includes('fastkirana restaurant') && !name.includes('fastkirana cafe')
                  })

                  const availableSubcategories = activeParentId
                    ? categories.filter((c) => c.parentId === activeParentId)
                    : []

                  return (
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 col-span-1 sm:col-span-2">
                      <div>
                        <label className="text-[10px] font-bold text-text-secondary block mb-1">Main Category *</label>
                        <select
                          required={!productEditForm.restaurantId}
                          value={activeParentId}
                          onChange={(e) => {
                            const newParentId = e.target.value
                            setProductEditForm({ ...productEditForm, categoryId: newParentId })
                          }}
                          className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer"
                        >
                          <option value="">-- Select Parent Category --</option>
                          {parentCategories.map((c) => (
                            <option key={c.id} value={c.id}>
                              {c.name}
                            </option>
                          ))}
                        </select>
                      </div>

                      <div>
                        <label className="text-[10px] font-bold text-text-secondary block mb-1">
                          Subcategory {availableSubcategories.length > 0 ? '(Recommended)' : '(Optional)'}
                        </label>
                        <select
                          value={activeSubId}
                          disabled={!activeParentId || availableSubcategories.length === 0}
                          onChange={(e) => {
                            const subId = e.target.value
                            setProductEditForm({ ...productEditForm, categoryId: subId || activeParentId })
                          }}
                          className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold cursor-pointer disabled:opacity-50"
                        >
                          <option value="">
                            {availableSubcategories.length === 0
                              ? '(No subcategories created yet)'
                              : '-- All / Main Category --'}
                          </option>
                          {availableSubcategories.map((sub) => (
                            <option key={sub.id} value={sub.id}>
                              └ {sub.name}
                            </option>
                          ))}
                        </select>
                      </div>
                    </div>
                  )
                })() : (
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Restaurant Menu Section *</label>
                    <select
                      required
                      value={RESTAURANT_MENU_SECTIONS.find(sec => productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes(sec.tag))?.tag || ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        const sectionValues = RESTAURANT_MENU_SECTIONS.map(s => s.tag);
                        let cleanTags = productEditForm.tags
                          .split(',')
                          .map(t => t.trim())
                          .filter(t => t.length > 0 && !sectionValues.includes(t.toLowerCase()));
                        
                        if (val) {
                          cleanTags.push(val);
                        }
                        if (!cleanTags.map(t => t.toLowerCase()).includes('restaurant')) {
                          cleanTags.push('restaurant');
                        }
                        setProductEditForm({ ...productEditForm, tags: cleanTags.join(', ') });
                      }}
                      className="w-full px-3 py-2 text-xs rounded-xl border border-amber-500/30 bg-amber-500/5 dark:bg-amber-955/15 focus:outline-none focus:border-amber-500 font-extrabold text-amber-600 dark:text-amber-400 cursor-pointer"
                    >
                      <option value="" className="text-text-primary font-normal">-- Select Menu Section --</option>
                      {RESTAURANT_MENU_SECTIONS.map((sec) => (
                        <option key={sec.tag} value={sec.tag} className="text-text-primary font-semibold">
                          {sec.emoji} {sec.title}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Unit Specification</label>
                  <input
                    type="text"
                    value={productEditForm.unit}
                    onChange={(e) => setProductEditForm({ ...productEditForm, unit: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                {!hasVariantsEdit && (
                  <>
                    {!productEditForm.restaurantId && !isEditProductCafe && !isEditProductRestaurant && (
                      <div>
                        <label className="text-[10px] font-bold text-text-secondary block mb-1">Stock Qty *</label>
                        <input
                          type="number"
                          required={!hasVariantsEdit && !productEditForm.restaurantId}
                          value={productEditForm.stock}
                          onChange={(e) => setProductEditForm({ ...productEditForm, stock: e.target.value })}
                          className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                        />
                      </div>
                    )}
                    <div>
                      <label className="text-[10px] font-bold text-text-secondary block mb-1">MRP Price (INR) *</label>
                      <input
                        type="number"
                        step="0.01"
                        required={!hasVariantsEdit}
                        value={productEditForm.mrp}
                        onChange={(e) => setProductEditForm({ ...productEditForm, mrp: e.target.value })}
                        className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                      />
                    </div>
                    <div>
                      <label className="text-[10px] font-bold text-text-secondary block mb-1">FastKirana Discounted Price (INR) *</label>
                      <input
                        type="number"
                        step="0.01"
                        required={!hasVariantsEdit}
                        value={productEditForm.price}
                        onChange={(e) => {
                          const val = e.target.value
                          let calculatedCost = productEditForm.costPrice
                          if (isEditProductCafe || isEditProductRestaurant) {
                            const marginKey = isEditProductCafe ? 'cafe_default_margin' : 'restaurant_default_margin'
                            const marginPercent = parseFloat(settingsMap[marginKey] || '30')
                            const priceNum = parseFloat(val) || 0
                            calculatedCost = (priceNum * (1 - marginPercent / 100)).toFixed(2)
                          }
                          setProductEditForm({ ...productEditForm, price: val, costPrice: calculatedCost })
                        }}
                        className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                      />
                    </div>
                  </>
                )}

                <div className="md:col-span-2 border border-border/60 bg-muted/5 p-4 rounded-xl space-y-3">
                  <div className="flex items-center justify-between">
                    <label className="text-xs font-bold text-text-primary flex items-center gap-1.5 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={hasVariantsEdit}
                        onChange={(e) => setHasVariantsEdit(e.target.checked)}
                        className="rounded border-border text-primary focus:ring-primary h-4 w-4"
                      />
                      This product has multiple size/weight variations (Variants)
                    </label>
                  </div>

                  {hasVariantsEdit && (
                    <div className="space-y-3 pt-2 border-t border-border/60">
                      {editProductVariants.length > 0 && (
                        <div className="space-y-1.5 max-h-40 overflow-y-auto pr-1">
                          {editProductVariants.map((v, idx) => (
                            <div key={idx} className="flex justify-between items-center bg-card border border-border/50 px-3 py-1.5 rounded-lg text-xs font-semibold">
                              <span>{v.name} (Price: ₹{v.price}, MRP: ₹{v.mrp}, Cost: ₹{v.costPrice || 0}, Stock: {v.stock})</span>
                              <button
                                type="button"
                                onClick={() => setEditProductVariants(editProductVariants.filter((_, i) => i !== idx))}
                                className="text-[10px] text-red-500 hover:text-red-600 font-bold cursor-pointer"
                              >
                                Remove
                              </button>
                            </div>
                          ))}
                        </div>
                      )}

                      <div className="grid grid-cols-5 gap-2 items-end">
                        <div>
                          <label className="text-[9px] font-bold text-text-secondary block mb-1">Variant Name</label>
                          <input
                            type="text"
                            id="edit-var-name"
                            placeholder="e.g. Small, 500g"
                            className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                          />
                        </div>
                        <div>
                          <label className="text-[9px] font-bold text-text-secondary block mb-1">MRP Price</label>
                          <input
                            type="number"
                            id="edit-var-mrp"
                            placeholder="MRP"
                            className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                          />
                        </div>
                        <div>
                          <label className="text-[9px] font-bold text-text-secondary block mb-1">Selling Price</label>
                          <input
                            type="number"
                            id="edit-var-price"
                            placeholder="Selling"
                            onChange={(e) => {
                              if (isEditProductCafe || isEditProductRestaurant) {
                                const costInput = document.getElementById('edit-var-cost') as HTMLInputElement
                                if (costInput) {
                                  const marginKey = isEditProductCafe ? 'cafe_default_margin' : 'restaurant_default_margin'
                                  const marginPercent = parseFloat(settingsMap[marginKey] || '30')
                                  const priceVal = parseFloat(e.target.value) || 0
                                  costInput.value = (priceVal * (1 - marginPercent / 100)).toFixed(2)
                                }
                              }
                            }}
                            className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                          />
                        </div>
                        <div>
                          <label className="text-[9px] font-bold text-text-secondary block mb-1">Cost Price</label>
                          <input
                            type="number"
                            id="edit-var-cost"
                            placeholder="Cost"
                            className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                          />
                        </div>
                        <div>
                          <label className="text-[9px] font-bold text-text-secondary block mb-1">Stock</label>
                          <input
                            type="number"
                            id="edit-var-stock"
                            placeholder="Qty"
                            className="w-full px-2.5 py-1.5 text-xs rounded-lg border bg-muted/10 focus:outline-none"
                          />
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          const nameInput = document.getElementById('edit-var-name') as HTMLInputElement
                          const mrpInput = document.getElementById('edit-var-mrp') as HTMLInputElement
                          const priceInput = document.getElementById('edit-var-price') as HTMLInputElement
                          const costInput = document.getElementById('edit-var-cost') as HTMLInputElement
                          const stockInput = document.getElementById('edit-var-stock') as HTMLInputElement

                          const name = nameInput.value.trim()
                          const mrp = mrpInput.value.trim()
                          const price = priceInput.value.trim()
                          const costPrice = costInput.value.trim() || '0'
                          const stock = stockInput.value.trim()

                          if (!name || !mrp || !price || !stock) {
                            toast.error('Please fill in all variant fields')
                            return
                          }

                          const newVars = [...editProductVariants, { name, mrp, price, costPrice, stock }]
                          newVars.sort((a, b) => (parseFloat(a.price) || 0) - (parseFloat(b.price) || 0))
                          setEditProductVariants(newVars)
                          nameInput.value = ''
                          mrpInput.value = ''
                          priceInput.value = ''
                          costInput.value = ''
                          stockInput.value = ''
                        }}
                        className="w-full py-1.5 text-[10px] font-bold bg-primary/10 hover:bg-primary/20 text-primary border border-primary/25 rounded-lg transition-colors cursor-pointer"
                      >
                        + Add Variant Option
                      </button>
                    </div>
                  )}
                </div>
                <div className="space-y-2">
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Product Photo / Image (Cloudinary)</label>
                  <input
                    type="text"
                    placeholder="Paste image absolute URL..."
                    value={productEditForm.imageUrl}
                    onChange={(e) => setProductEditForm({ ...productEditForm, imageUrl: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                  <div className="flex flex-wrap items-center gap-2">
                    <label
                      htmlFor="edit-product-image-file"
                      className="cursor-pointer px-3.5 py-2 bg-primary/10 hover:bg-primary/20 text-primary text-xs font-black rounded-xl border border-primary/20 transition-all flex items-center gap-1.5 whitespace-nowrap"
                    >
                      {isUploading ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : '📤 Upload File'}
                    </label>
                    <button
                      type="button"
                      onClick={() => {
                        setMediaTarget('editProduct')
                        setShowMediaLibrary(true)
                      }}
                      className="px-3.5 py-2 bg-amber-500/15 hover:bg-amber-500/25 text-amber-600 dark:text-amber-400 text-xs font-black rounded-xl border border-amber-500/30 transition-all flex items-center gap-1.5 whitespace-nowrap cursor-pointer shadow-2xs"
                    >
                      🖼️ Choose from Photo Library
                    </button>
                    <input
                      id="edit-product-image-file"
                      type="file"
                      accept="image/*"
                      onChange={(e) => {
                        const file = e.target.files?.[0]
                        if (file) {
                          handleCloudinaryUpload(file, (url) => {
                            setProductEditForm({ ...productEditForm, imageUrl: url })
                          })
                        }
                        e.target.value = ''
                      }}
                      className="sr-only"
                      disabled={isUploading}
                    />
                  </div>
                  {productEditForm.imageUrl && (
                    <div className="h-20 w-20 relative overflow-hidden rounded-xl border border-border bg-white/5 p-1 mt-1">
                      <img src={productEditForm.imageUrl} alt="Preview" className="h-full w-full object-contain" />
                    </div>
                  )}
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Tags (comma-separated)</label>
                  <input
                    type="text"
                    value={productEditForm.tags}
                    onChange={(e) => setProductEditForm({ ...productEditForm, tags: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                {!isEditProductCafe && !isEditProductRestaurant && (
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Stock Alert Level</label>
                    <input
                      type="number"
                      value={productEditForm.minStock}
                      onChange={(e) => setProductEditForm({ ...productEditForm, minStock: e.target.value })}
                      className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                )}
                {!isEditProductCafe && !isEditProductRestaurant && (
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Barcode (EAN/UPC)</label>
                    <input
                      type="text"
                      placeholder="Scan or enter barcode"
                      value={productEditForm.barcode}
                      onChange={(e) => setProductEditForm({ ...productEditForm, barcode: e.target.value })}
                      className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                )}
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Cost Price (INR)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={productEditForm.costPrice}
                    onChange={(e) => setProductEditForm({ ...productEditForm, costPrice: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Aisle/Shelf Location</label>
                  <input
                    type="text"
                    placeholder="e.g. Aisle 2-B"
                    value={productEditForm.location || ''}
                    onChange={(e) => setProductEditForm({ ...productEditForm, location: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>


                {!isEditProductCafe && !isEditProductRestaurant && (
                  <div>
                    <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                    <input
                      type="date"
                      value={productEditForm.expiryDate ? productEditForm.expiryDate.split('T')[0] : ''}
                      onChange={(e) => setProductEditForm({ ...productEditForm, expiryDate: e.target.value })}
                      className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                  </div>
                )}

                <div className="md:col-span-2 flex flex-wrap gap-x-6 gap-y-2 pt-2 border-t border-border/40">
                  <span className="text-[10px] font-extrabold text-text-secondary block w-full">Quick Tags / Smart Features</span>
                  
                  {/* Common tags */}
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('popular')}
                      onChange={(e) => toggleTag('edit', 'popular', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>🔥 Trending (Popular)</span>
                  </label>
                  <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('cafe')}
                      onChange={(e) => toggleTag('edit', 'cafe', e.target.checked)}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <span>☕ Cafe Item</span>
                  </label>

                  {/* Cafe specific tags */}
                  {isEditProductCafe ? (
                    <>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('sandwiches')}
                          onChange={(e) => toggleTag('edit', 'sandwiches', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🥪 Cafe: Sandwiches</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('italian-pasta')}
                          onChange={(e) => toggleTag('edit', 'italian-pasta', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🍝 Cafe: Italian Pasta</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('bombay-bites')}
                          onChange={(e) => toggleTag('edit', 'bombay-bites', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🥪 Cafe: Bombay Bites</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('rice-dishes')}
                          onChange={(e) => toggleTag('edit', 'rice-dishes', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🍚 Cafe: Rice Dishes</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('shakes')}
                          onChange={(e) => toggleTag('edit', 'shakes', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🥤 Cafe: Shakes</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('mocktails')}
                          onChange={(e) => toggleTag('edit', 'mocktails', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🍹 Cafe: Mocktails</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('cold-coffee')}
                          onChange={(e) => toggleTag('edit', 'cold-coffee', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🧋 Cafe: Cold Coffee</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-rose-600 dark:text-rose-400 cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('frankie-rolls')}
                          onChange={(e) => toggleTag('edit', 'frankie-rolls', e.target.checked)}
                          className="h-4 w-4 text-rose-500 focus:ring-rose-500 border-border rounded cursor-pointer"
                        />
                        <span>🌯 Cafe: Frankie Rolls</span>
                      </label>
                    </>
                  ) : (
                    <>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('hot-beverage')}
                          onChange={(e) => toggleTag('edit', 'hot-beverage', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>☕ Hot Beverage</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('hot-bite')}
                          onChange={(e) => toggleTag('edit', 'hot-bite', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🥟 Hot Bite / Snack</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('chinese')}
                          onChange={(e) => toggleTag('edit', 'chinese', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🥡 Chinese</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('south-indian')}
                          onChange={(e) => toggleTag('edit', 'south-indian', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🍛 South Indian</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('breakfast')}
                          onChange={(e) => toggleTag('edit', 'breakfast', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🍳 Breakfast Essential</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('snacks')}
                          onChange={(e) => toggleTag('edit', 'snacks', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🍿 Snacks</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('dairy')}
                          onChange={(e) => toggleTag('edit', 'dairy', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🥛 Dairy</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('staples')}
                          onChange={(e) => toggleTag('edit', 'staples', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🌾 Staples</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('beverages')}
                          onChange={(e) => toggleTag('edit', 'beverages', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🥤 Beverages</span>
                      </label>
                      <label className="flex items-center gap-2 text-xs font-bold text-text-primary cursor-pointer select-none animate-fade-in">
                        <input
                          type="checkbox"
                          checked={productEditForm.tags.split(',').map(t => t.trim().toLowerCase()).includes('late-night')}
                          onChange={(e) => toggleTag('edit', 'late-night', e.target.checked)}
                          className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                        />
                        <span>🌙 Late Night Craving</span>
                      </label>
                    </>
                  )}
                </div>

                {/* Custom Tag Creator */}
                <div className="md:col-span-3 pt-3 border-t border-border/20 flex flex-col gap-2">
                  <span className="text-[10px] font-extrabold text-text-secondary block">Custom Tags Creator</span>
                  <div className="flex gap-2 max-w-sm">
                    <input
                      type="text"
                      placeholder="Type custom tag (e.g. sugar-free, organic)"
                      value={newCustomTag}
                      onChange={(e) => setNewCustomTag(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.preventDefault();
                          handleCreateCustomTag('edit', newCustomTag);
                        }
                      }}
                      className="flex-1 px-3 py-1.5 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    />
                    <button
                      type="button"
                      onClick={() => handleCreateCustomTag('edit', newCustomTag)}
                      className="px-3 py-1.5 bg-primary/10 hover:bg-primary/20 text-primary text-[10px] font-black rounded-xl border border-primary/20 transition-all"
                    >
                      Add Tag
                    </button>
                  </div>
                  {productEditForm.tags.trim() && (
                    <div className="flex flex-wrap gap-1.5 mt-1">
                      {productEditForm.tags.split(',').map(t => t.trim()).filter(Boolean).map(tag => (
                        <span key={tag} className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-muted text-[10px] font-bold text-text-primary">
                          <span>{tag}</span>
                          <button
                            type="button"
                            onClick={() => toggleTag('edit', tag, false)}
                            className="text-text-muted hover:text-rose-500 font-extrabold text-[9px] ml-0.5"
                          >
                            ×
                          </button>
                        </span>
                      ))}
                    </div>
                  )}
                </div>
              </div>
              <div>
                <label className="text-[10px] font-bold text-text-secondary block mb-1">Description</label>
                <textarea
                  rows={3}
                  value={productEditForm.description}
                  onChange={(e) => setProductEditForm({ ...productEditForm, description: e.target.value })}
                  className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                />
              </div>
              <div className="flex flex-col gap-2 pt-3 border-t border-border/20">
                <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider">Promotional Highlight Placements</p>
                <div className="flex flex-wrap items-center gap-6">
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editIsAvailable"
                      checked={productEditForm.isAvailable}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isAvailable: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editIsAvailable" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      Available for Sale
                    </label>
                  </div>
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editIsFlashDeal"
                      checked={productEditForm.isFlashDeal}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isFlashDeal: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editIsFlashDeal" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      ⚡ Flash Deal
                    </label>
                  </div>
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editIsTopPick"
                      checked={productEditForm.isTopPick}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isTopPick: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editIsTopPick" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      ⭐ Top Pick
                    </label>
                  </div>
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editIsBestSeller"
                      checked={productEditForm.isBestSeller}
                      onChange={(e) => setProductEditForm({ ...productEditForm, isBestSeller: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editIsBestSeller" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      🏆 Best Seller
                    </label>
                  </div>
                </div>
              </div>

              {/* Display Priority / Sort Order */}
              <div className="space-y-1.5">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Display Priority / Sort Order</label>
                <input
                  type="number"
                  placeholder="e.g. 100 for top, -50 for bottom"
                  value={productEditForm.sortOrder}
                  onChange={(e) => setProductEditForm({ ...productEditForm, sortOrder: e.target.value })}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-text-primary"
                />
                <p className="text-[9px] text-text-muted mt-0.5">Higher numbers display first/on top. Lower numbers display last. Default is 0.</p>
              </div>

              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setEditingProduct(null)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingProductId === editingProduct.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
                >
                  {savingProductId === editingProduct.id ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Saving...
                    </>
                  ) : (
                    'Save Changes'
                  )}
                </button>
              </div>
            </form>
          </div>
      )}

      {editingCategory && (
        <CategoryEditModal
          editingCategory={editingCategory}
          categoryEditForm={categoryEditForm}
          categories={categories}
          savingCategoryId={savingCategoryId}
          handleImageFileChange={handleImageFileChange}
          saveCategoryChanges={saveCategoryChanges}
          setEditingCategory={setEditingCategory}
          setCategoryEditForm={setCategoryEditForm}
        />
      )}

      {/* Review Edit Modal */}
      {editingReview && (
        <ReviewEditModal
          editingReview={editingReview}
          reviewEditForm={reviewEditForm}
          savingReviewId={savingReviewId}
          saveReviewChanges={saveReviewChanges}
          setEditingReview={setEditingReview}
          setReviewEditForm={setReviewEditForm}
        />
      )}

      {/* Coupon Edit Modal */}
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

      {blockingUser && (
        <BlockCustomerModal
          blockingUser={blockingUser}
          blockReasonInput={blockReasonInput}
          isUpdatingBlockStatus={isUpdatingBlockStatus}
          setBlockingUser={setBlockingUser}
          setBlockReasonInput={setBlockReasonInput}
          handleToggleBlock={handleToggleBlock}
        />
      )}

      {selectedOrderForTracking && (
        <OrderTrackingModal
          selectedOrderForTracking={selectedOrderForTracking}
          isLoadingOrderItems={isLoadingOrderItems}
          setSelectedOrderForTracking={setSelectedOrderForTracking}
        />
      )}

      <CreateOrderModal
        isOpen={isCreateOrderOpen}
        onClose={() => setIsCreateOrderOpen(false)}
        onSuccess={() => {
          setOrderRefreshKey(prev => prev + 1)
        }}
      />

      <AdminSortManager
        isOpen={showSortManager}
        onClose={() => setShowSortManager(false)}
        categories={categories}
      />

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
            setNewProduct((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'editProduct') {
            setProductEditForm((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'newCategory') {
            setNewCategory((prev) => ({ ...prev, imageUrl: url }))
          } else if (target === 'editCategory' || target === 'category') {
            setCategoryEditForm((prev) => ({ ...prev, imageUrl: url }))
          }
        }}
      />
    </div>
  )
}
