'use client'

import { signOut } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { formatPrice, formatAddress } from '@/lib/utils'
import { useCart } from '@/hooks/use-cart'
import { useCartStore } from '@/stores/cart-store'
import { ORDER_STATUS_LABELS, ORDER_STATUS_COLORS } from '@/lib/constants'
import { LogOut, MapPin, User, Package, ArrowRight, Pencil, X, Loader2, Trash2, Search, ShoppingBag, Heart, RotateCcw, Sparkles, CheckCircle2, Zap } from 'lucide-react'
import Link from 'next/link'
import { toast } from 'sonner'
import { useState, useEffect, Suspense } from 'react'
import { supabase } from '@/lib/supabase-client'
import { motion, AnimatePresence } from 'framer-motion'
import { cn } from '@/lib/utils'
import { BuyAgainSection } from '@/components/home/buy-again-section'
import { useSearchParams } from 'next/navigation'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { triggerHaptic } from '@/lib/haptic'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'
import { WishlistClient } from '@/components/account/wishlist-client'

interface AccountDashboardProps {
  user: {
    name: string | null
    email: string
    phone: string | null
    role: 'USER' | 'PICKER' | 'CHEF' | 'RESTAURANT_OWNER' | 'DELIVERY' | 'ADMIN'
  }
  addresses: any[]
  orders: any[]
}

export function AccountDashboard({ user, addresses: initialAddresses, orders: initialOrders }: AccountDashboardProps) {
  const router = useRouter()
  const [addresses, setAddresses] = useState(initialAddresses)
  const [orders, setOrders] = useState(initialOrders)
  const searchParams = useSearchParams()
  const [activeTab, setActiveTab] = useState('orders')
  const [orderSubTab, setOrderSubTab] = useState<'LIVE' | 'HISTORY'>('LIVE')
  const [editingAddress, setEditingAddress] = useState<any | null>(null)
  const [isSavingAddress, setIsSavingAddress] = useState(false)
  const [addressForm, setAddressForm] = useState({
    label: 'Home',
    street: '',
    phone: '',
    pincode: '209206',
    isDefault: false
  })
  const [orderSearchQuery, setOrderSearchQuery] = useState('')
  const [orderStatusFilter, setOrderStatusFilter] = useState<string>('ALL')
  const [reorderOrderModal, setReorderOrderModal] = useState<any | null>(null)

  const executeReorder = (ord: any) => {
    try {
      triggerHaptic('medium')
      const { addItem, clearCart } = useCartStore.getState()
      clearCart()
      for (const item of ord.items || []) {
        addItem({
          id: item.id || item.productId,
          name: item.name,
          slug: '',
          imageUrl: item.imageUrl || '',
          mrp: item.mrp || item.price,
          price: item.price,
          discount: 0,
          unit: item.unit || '',
          stock: 99,
          isAvailable: true,
          tags: [],
          category: undefined,
        })
      }
      toast.success('Items added to cart!')
      setReorderOrderModal(null)
      router.push('/cart')
    } catch {
      toast.error('Failed to reorder. Please try again.')
    }
  }

  // Resend countdown timers
  const [emailCountdown, setEmailCountdown] = useState(0)
  const [phoneCountdown, setPhoneCountdown] = useState(0)

  useEffect(() => {
    let timer: any
    if (emailCountdown > 0) {
      timer = setTimeout(() => setEmailCountdown(emailCountdown - 1), 1000)
    }
    return () => clearTimeout(timer)
  }, [emailCountdown])

  useEffect(() => {
    let timer: any
    if (phoneCountdown > 0) {
      timer = setTimeout(() => setPhoneCountdown(phoneCountdown - 1), 1000)
    }
    return () => clearTimeout(timer)
  }, [phoneCountdown])

  // Name state & editing
  const [userName, setUserName] = useState(user.name || '')
  const [isEditingName, setIsEditingName] = useState(false)
  const [newName, setNewName] = useState(user.name || '')
  const [isUpdatingName, setIsUpdatingName] = useState(false)

  const handleUpdateName = async (e?: React.FormEvent) => {
    if (e) e.preventDefault()
    if (!newName || !newName.trim()) {
      toast.error('Please enter your full name')
      return
    }
    setIsUpdatingName(true)
    try {
      const res = await fetch('/api/profile/update-name', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: newName.trim() }),
      })
      const data = await res.json()
      if (res.ok) {
        setUserName(data.name || newName.trim())
        setIsEditingName(false)
        toast.success('Name updated successfully!')
        router.refresh()
      } else {
        toast.error(data.error || 'Failed to update name')
      }
    } catch {
      toast.error('Something went wrong')
    } finally {
      setIsUpdatingName(false)
    }
  }

  // Email verification state
  const [email, setEmail] = useState(user.email)
  const [isEditingEmail, setIsEditingEmail] = useState(false)
  const [newEmail, setNewEmail] = useState(user.email)
  const [otpCode, setOtpCode] = useState('')
  const [isOtpSent, setIsOtpSent] = useState(false)
  const [isSendingOtp, setIsSendingOtp] = useState(false)
  const [isUpdatingEmail, setIsUpdatingEmail] = useState(false)

  const handleSendEmailOtp = async () => {
    if (!newEmail || !newEmail.includes('@')) {
      toast.error('Please enter a valid email address')
      return
    }
    setIsSendingOtp(true)
    try {
      const res = await fetch('/api/profile/send-email-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: newEmail }),
      })
      const data = await res.json()
      if (res.ok) {
        setIsOtpSent(true)
        setEmailCountdown(30)
        toast.success(`Verification code sent to ${newEmail}`)
      } else {
        toast.error(data.error || 'Failed to send verification code')
      }
    } catch (err) {
      toast.error('Something went wrong')
    } finally {
      setIsSendingOtp(false)
    }
  }

  const handleUpdateEmail = async () => {
    if (!otpCode || otpCode.length !== 6) {
      toast.error('Please enter a valid 6-digit OTP code')
      return
    }
    setIsUpdatingEmail(true)
    try {
      const res = await fetch('/api/profile/update-email', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: newEmail, otp: otpCode }),
      })
      const data = await res.json()
      if (res.ok) {
        setEmail(newEmail)
        setIsEditingEmail(false)
        setIsOtpSent(false)
        setOtpCode('')
        toast.success('Email address updated successfully!')
      } else {
        toast.error(data.error || 'Failed to update email address')
      }
    } catch (err) {
      toast.error('Something went wrong')
    } finally {
      setIsUpdatingEmail(false)
    }
  }

  // Phone verification state
  const [phone, setPhone] = useState(user.phone)
  const [isEditingPhone, setIsEditingPhone] = useState(false)
  const [newPhone, setNewPhone] = useState(user.phone || '')
  const [phoneOtpCode, setPhoneOtpCode] = useState('')
  const [isPhoneOtpSent, setIsPhoneOtpSent] = useState(false)
  const [isSendingPhoneOtp, setIsSendingPhoneOtp] = useState(false)
  const [isUpdatingPhone, setIsUpdatingPhone] = useState(false)

  // Account Deletion State
  const [isDeletingAccount, setIsDeletingAccount] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const handleDeleteAccount = async () => {
    setIsDeletingAccount(true)
    try {
      const res = await fetch('/api/profile/delete-account', {
        method: 'DELETE',
      })
      const data = await res.json()
      if (res.ok) {
        toast.success('Your account and personal data have been deleted.')
        window.location.href = '/api/auth/signout'
      } else {
        toast.error(data.error || 'Failed to delete account')
      }
    } catch (err) {
      toast.error('Failed to delete account. Please try again.')
    } finally {
      setIsDeletingAccount(false)
    }
  }

  const handleSendPhoneOtp = async () => {
    if (!newPhone || !isValidIndianPhone(newPhone)) {
      toast.error('Please enter a valid 10-digit mobile number')
      return
    }
    setIsSendingPhoneOtp(true)
    try {
      const res = await fetch('/api/profile/send-phone-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: newPhone }),
      })
      const data = await res.json()
      if (res.ok) {
        setIsPhoneOtpSent(true)
        setPhoneCountdown(30)
        toast.success(`Verification code sent to ${newPhone} via WhatsApp`)
      } else {
        toast.error(data.error || 'Failed to send verification code')
      }
    } catch (err) {
      toast.error('Something went wrong')
    } finally {
      setIsSendingPhoneOtp(false)
    }
  }

  const handleUpdatePhone = async () => {
    if (!phoneOtpCode || phoneOtpCode.length !== 6) {
      toast.error('Please enter a valid 6-digit OTP code')
      return
    }
    setIsUpdatingPhone(true)
    try {
      const res = await fetch('/api/profile/update-phone', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: newPhone, otp: phoneOtpCode }),
      })
      const data = await res.json()
      if (res.ok) {
        setPhone(newPhone)
        setIsEditingPhone(false)
        setIsPhoneOtpSent(false)
        setPhoneOtpCode('')
        toast.success('Phone number updated successfully!')
      } else {
        toast.error(data.error || 'Failed to update phone number')
      }
    } catch (err) {
      toast.error('Something went wrong')
    } finally {
      setIsUpdatingPhone(false)
    }
  }

  // Live order status updates via Supabase Realtime
  useEffect(() => {
    const activeOrders = orders.filter(
      (ord) => !['DELIVERED', 'CANCELLED'].includes(ord.status)
    )
    if (activeOrders.length === 0) return

    const activeIds = activeOrders.map(o => o.id)

    const channel = supabase
      .channel('customer-orders-live')
      .on(
        'postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'orders',
        },
        (payload) => {
          const updatedOrder = payload.new as any
          const orderId = updatedOrder.id
          
          if (activeIds.includes(orderId)) {
            const newStatus = updatedOrder.status
            setOrders((prevOrders) =>
              prevOrders.map((o) =>
                o.id === orderId ? { ...o, status: newStatus } : o
              )
            )
          }
        }
      )
      .subscribe()

    return () => {
      supabase.removeChannel(channel)
    }
  }, [orders.map((o) => `${o.id}:${o.status}`).join(',')])

  // Client-side fallback to sync latest orders from /api/orders
  useEffect(() => {
    async function syncOrders() {
      try {
        const res = await fetch('/api/orders')
        if (res.ok) {
          const freshOrders = await res.json()
          if (Array.isArray(freshOrders) && freshOrders.length > 0) {
            setOrders(freshOrders)
          }
        }
      } catch (err) {
        console.error('Failed to sync orders in AccountDashboard:', err)
      }
    }
    syncOrders()
  }, [])

  useEffect(() => {
    const tab = searchParams.get('tab')
    if (tab && (tab === 'orders' || tab === 'addresses' || tab === 'profile')) {
      setActiveTab(tab)
    }
  }, [searchParams])

  const handleTabChange = (value: string) => {
    setActiveTab(value)
    const url = new URL(window.location.href)
    url.searchParams.set('tab', value)
    window.history.pushState(null, '', url.toString())
  }

  const handleSignOut = async () => {
    await signOut({ redirect: false })
    toast.success('Signed out successfully!')
    window.location.href = '/'
  }

  const handleDeleteAddress = async (id: string) => {
    try {
      const res = await fetch(`/api/addresses`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id }),
      })

      const data = await res.json()

      if (res.ok) {
        setAddresses(addresses.filter((a) => a.id !== id))
        toast.success('Address deleted successfully')
      } else {
        toast.error(data.error || 'Failed to delete address')
      }
    } catch (err) {
      toast.error('Failed to delete address')
    }
  }

  const handleEditClick = (addr: any) => {
    triggerHaptic('light')
    setEditingAddress(addr)
    setAddressForm({
      label: addr.label || 'Home',
      street: addr.street || '',
      phone: addr.phone || '',
      pincode: addr.pincode || '209206',
      isDefault: addr.isDefault || false
    })
  }

  const handleUpdateAddress = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!addressForm.street || !addressForm.pincode || !addressForm.phone) {
      toast.error('Please fill in all address details')
      return
    }

    if (addressForm.pincode !== '209206') {
      toast.error('FastKirana only delivers to Ghatampur area (Pincode: 209206)')
      return
    }

    setIsSavingAddress(true)
    try {
      const payload = {
        id: editingAddress.id,
        label: addressForm.label,
        houseNo: '.',
        street: addressForm.street.trim(),
        area: '.',
        city: 'Ghatampur',
        pincode: addressForm.pincode.trim(),
        phone: addressForm.phone.trim(),
        isDefault: addressForm.isDefault,
        lat: editingAddress.lat || null,
        lng: editingAddress.lng || null
      }

      const res = await fetch('/api/addresses', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (res.ok) {
        const updated = await res.json()
        setAddresses(addresses.map(a => a.id === editingAddress.id ? updated : a))
        toast.success('Address updated successfully!')
        setEditingAddress(null)
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to update address')
      }
    } catch {
      toast.error('Failed to update address')
    } finally {
      setIsSavingAddress(false)
    }
  }

  const formatEmailForDisplay = (email: string) => {
    if (!email) return ''
    const lowerEmail = email.toLowerCase().trim()
    if (lowerEmail.endsWith('@fastkirana.com')) {
      const prefix = lowerEmail.split('@')[0]
      const phoneDigits = prefix.replace('wa-', '')
      const cleanPhone = phoneDigits.length === 12 && phoneDigits.startsWith('91')
        ? phoneDigits.slice(2)
        : phoneDigits
      if (/^\d{10}$/.test(cleanPhone)) {
        return `+91 ${cleanPhone}`
      }
      if (prefix === 'help') return email
      return prefix
    }
    return email
  }

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      
      {/* User Welcome Card Banner - Luxury Modern Glassmorphism Design */}
      <div className="relative overflow-hidden flex flex-col sm:flex-row items-start sm:items-center justify-between gap-5 border border-zinc-200/90 dark:border-white/10 bg-gradient-to-br from-white via-zinc-50/70 to-rose-50/30 dark:from-zinc-900/95 dark:via-zinc-900/70 dark:to-zinc-950 p-5 sm:p-6 rounded-[30px] shadow-[0_12px_36px_-12px_rgba(0,0,0,0.07)] backdrop-blur-xl">
        {/* Ambient Decorative Light Flare */}
        <div className="pointer-events-none absolute -top-16 -right-16 h-48 w-48 rounded-full bg-gradient-to-br from-rose-500/15 to-primary/10 blur-3xl opacity-70" />
        <div className="pointer-events-none absolute -bottom-14 -left-14 h-44 w-44 rounded-full bg-gradient-to-tr from-amber-500/10 to-violet-500/10 blur-3xl opacity-60" />

        <div className="relative z-10 flex items-center gap-4 w-full sm:w-auto">
          {/* Avatar with Glow and Verified Role Pin */}
          <div className="relative shrink-0">
            <div className="relative flex h-16 w-16 sm:h-[68px] sm:w-[68px] items-center justify-center rounded-2xl bg-gradient-to-br from-[#e8153a] via-[#ff2d55] to-[#ff6b4a] text-white text-2xl font-black shadow-lg shadow-rose-500/25 ring-4 ring-white dark:ring-zinc-900 select-none">
              {userName?.charAt(0)?.toUpperCase() || 'U'}
            </div>
            {/* Status Pin Badge */}
            <div className="absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full bg-white dark:bg-zinc-900 shadow-md ring-2 ring-white dark:ring-zinc-900">
              {user.role === 'ADMIN' ? (
                <span className="text-xs">👑</span>
              ) : user.role === 'DELIVERY' ? (
                <span className="text-xs">🚴</span>
              ) : user.role === 'CHEF' || user.role === 'RESTAURANT_OWNER' ? (
                <span className="text-xs">👨‍🍳</span>
              ) : (
                <CheckCircle2 className="h-3.5 w-3.5 text-emerald-500 stroke-[2.5]" />
              )}
            </div>
          </div>

          {/* User Details */}
          <div className="min-w-0 flex-1 space-y-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h2 className="text-base sm:text-lg font-black text-text-primary tracking-tight truncate">
                {userName || 'User'}
              </h2>
              <span className={`text-[10px] font-black uppercase px-2.5 py-0.5 rounded-full border shadow-2xs flex items-center gap-1 ${
                user.role === 'ADMIN'
                  ? 'bg-rose-500/15 text-rose-600 dark:text-rose-400 border-rose-500/30'
                  : user.role === 'DELIVERY'
                  ? 'bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30'
                  : user.role === 'CHEF' || user.role === 'RESTAURANT_OWNER'
                  ? 'bg-orange-500/15 text-orange-600 dark:text-orange-400 border-orange-500/30'
                  : 'bg-primary/10 text-primary border-primary/20'
              }`}>
                {user.role === 'ADMIN' ? '👑 Admin' : user.role === 'DELIVERY' ? '🚴 Rider' : user.role === 'CHEF' ? '👨‍🍳 Chef' : user.role === 'RESTAURANT_OWNER' ? '🏪 Partner' : '✨ Member'}
              </span>
            </div>

            <p className="text-xs font-semibold text-text-secondary truncate flex items-center gap-1.5">
              <span>{formatEmailForDisplay(user.email)}</span>
            </p>
          </div>
        </div>

        {/* Action Controls */}
        <div className="relative z-10 flex flex-wrap items-center gap-2.5 w-full sm:w-auto justify-start sm:justify-end border-t sm:border-t-0 border-border/50 pt-3 sm:pt-0">
          {user.role === 'ADMIN' && (
            <Link href="/admin" className="flex-1 sm:flex-initial">
              <Button className="w-full bg-gradient-to-r from-rose-600 via-red-600 to-rose-700 hover:from-rose-700 hover:to-red-800 text-white rounded-2xl text-xs h-10 px-5 font-black shadow-md shadow-rose-600/25 transition-all active:scale-95 flex items-center justify-center gap-1.5 border-0 cursor-pointer">
                <Zap className="h-3.5 w-3.5 fill-current" />
                <span>Admin Console</span>
              </Button>
            </Link>
          )}
          {user.role === 'PICKER' && (
            <Link href="/picker" className="flex-1 sm:flex-initial">
              <Button className="w-full bg-primary hover:bg-primary/90 text-white rounded-2xl text-xs h-10 px-5 font-black shadow-md shadow-primary/20 transition-all active:scale-95 flex items-center justify-center gap-1.5 cursor-pointer">
                <span>📦 Picker Console</span>
              </Button>
            </Link>
          )}
          {user.role === 'RESTAURANT_OWNER' && (
            <Link href="/restaurant-kitchen" className="flex-1 sm:flex-initial">
              <Button className="w-full bg-orange-600 hover:bg-orange-700 text-white rounded-2xl text-xs h-10 px-5 font-black shadow-md shadow-orange-600/20 transition-all active:scale-95 flex items-center justify-center gap-1.5 cursor-pointer">
                <span>🏪 Outlet Console</span>
              </Button>
            </Link>
          )}
          {user.role === 'CHEF' && (
            <Link href={user.email?.toLowerCase().startsWith('restaurant') ? '/restaurant-kitchen' : '/cafe-kitchen'} className="flex-1 sm:flex-initial">
              <Button className="w-full bg-rose-600 hover:bg-rose-700 text-white rounded-2xl text-xs h-10 px-5 font-black shadow-md shadow-rose-600/20 transition-all active:scale-95 flex items-center justify-center gap-1.5 cursor-pointer">
                <span>👨‍🍳 Chef Console</span>
              </Button>
            </Link>
          )}
          {user.role === 'DELIVERY' && (
            <Link href="/delivery" className="flex-1 sm:flex-initial">
              <Button className="w-full bg-gradient-to-r from-emerald-500 to-teal-600 hover:from-emerald-600 hover:to-teal-700 text-white rounded-2xl text-xs h-10 px-5 font-black shadow-md shadow-emerald-500/20 transition-all active:scale-95 flex items-center justify-center gap-1.5 cursor-pointer">
                <span>🚴 Rider Console</span>
              </Button>
            </Link>
          )}

          <Button
            onClick={handleSignOut}
            variant="outline"
            className="flex-1 sm:flex-initial text-rose-600 dark:text-rose-400 hover:bg-rose-500/10 border-rose-500/25 bg-rose-500/5 rounded-2xl text-xs flex items-center justify-center gap-1.5 h-10 px-4 font-black active:scale-95 transition-all shadow-2xs cursor-pointer"
          >
            <LogOut className="h-3.5 w-3.5" />
            <span>Logout</span>
          </Button>
        </div>
      </div>

      {/* Phone Number Missing Banner Warning */}
      {(!phone || phone === '') && (
        <div className="relative overflow-hidden bg-gradient-to-br from-amber-500/15 via-orange-500/5 to-card border border-amber-500/30 p-4 sm:p-5 rounded-[24px] shadow-xs flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-3.5 w-full sm:w-auto">
            <div className="h-10 w-10 rounded-xl bg-amber-500/15 border border-amber-500/30 flex items-center justify-center text-xl shrink-0">
              ⚠️
            </div>
            <div className="min-w-0 flex-1">
              <h4 className="text-xs font-black text-amber-700 dark:text-amber-400 uppercase tracking-widest">
                Contact Number Missing
              </h4>
              <p className="text-xs text-text-secondary mt-0.5 font-semibold">
                Please add a valid mobile number to receive order updates via WhatsApp.
              </p>
            </div>
          </div>
          <button
            onClick={() => {
              setActiveTab('profile')
              setIsEditingPhone(true)
              setNewPhone('')
            }}
            className="w-full sm:w-auto px-4.5 py-2.5 bg-amber-600 hover:bg-amber-700 text-white font-black text-xs rounded-xl shadow-md transition-all active:scale-95 text-center shrink-0 cursor-pointer"
          >
            Add Phone Number
          </button>
        </div>
      )}

      {/* Sliding Pill Tab Navigation Bar */}
      <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
        <div className="w-full overflow-x-auto no-scrollbar py-1 mb-6">
          <div className="flex items-center gap-1.5 p-1.5 bg-zinc-100/90 dark:bg-zinc-900/90 backdrop-blur-md rounded-[24px] border border-zinc-200/80 dark:border-zinc-800/80 min-w-max sm:min-w-0">
            {[
              { key: 'orders', label: 'My Orders', icon: Package, badge: orders.length },
              { key: 'wishlist', label: 'Wishlist', icon: Heart },
              { key: 'addresses', label: 'Addresses', icon: MapPin, badge: addresses.length },
              { key: 'profile', label: 'Profile', icon: User },
            ].map((tab) => {
              const Icon = tab.icon
              const isActive = activeTab === tab.key
              return (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => {
                    triggerHaptic('light')
                    handleTabChange(tab.key)
                  }}
                  className={`relative flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-black transition-colors cursor-pointer select-none flex-1 justify-center whitespace-nowrap ${
                    isActive
                      ? 'text-white'
                      : 'text-zinc-600 dark:text-zinc-400 hover:text-zinc-900 dark:hover:text-white'
                  }`}
                >
                  {isActive && (
                    <motion.div
                      layoutId="accountActiveTabPill"
                      className="absolute inset-0 bg-gradient-to-r from-[#e8153a] via-[#ff2d55] to-[#ff5533] rounded-2xl shadow-md shadow-rose-500/25"
                      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                    />
                  )}
                  <Icon className="h-4 w-4 relative z-10 shrink-0 stroke-[2.5]" />
                  <span className="relative z-10 tracking-tight">{tab.label}</span>
                  {tab.badge !== undefined && (
                    <span className={`relative z-10 px-1.5 py-0.2 rounded-full text-[10px] font-black ${
                      isActive ? 'bg-white/25 text-white' : 'bg-zinc-200 dark:bg-zinc-800 text-zinc-600 dark:text-zinc-400'
                    }`}>
                      {tab.badge}
                    </span>
                  )}
                </button>
              )
            })}
          </div>
        </div>

        {/* Tab Content: Orders */}
        <TabsContent value="orders" className="space-y-4 animate-fade-in focus-visible:outline-none">
          {/* Search & Filter Bar */}
          <div className="flex flex-col sm:flex-row gap-2.5">
            <div className="relative flex-1">
              <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 h-4 w-4 text-zinc-400" />
              <input
                type="text"
                placeholder="Search orders by ID or item name..."
                value={orderSearchQuery}
                onChange={(e) => setOrderSearchQuery(e.target.value)}
                className="w-full bg-white dark:bg-zinc-900 border border-zinc-200/80 dark:border-zinc-800 pl-10 pr-4 py-2.5 rounded-2xl text-xs focus:outline-none focus:border-rose-500 font-semibold shadow-xs"
                aria-label="Search orders"
              />
            </div>
            <select
              value={orderStatusFilter}
              onChange={(e) => setOrderStatusFilter(e.target.value)}
              className="bg-white dark:bg-zinc-900 border border-zinc-200/80 dark:border-zinc-800 px-3.5 py-2.5 rounded-2xl text-xs font-extrabold focus:outline-none focus:border-rose-500 cursor-pointer shadow-xs"
              aria-label="Filter orders by status"
            >
              <option value="ALL">All Status</option>
              {Object.entries(ORDER_STATUS_LABELS).map(([key, label]) => (
                <option key={key} value={key}>{label}</option>
              ))}
            </select>
          </div>
          {/* Sub-Tabs Bar for Live Orders vs Order History */}
          <div className="flex items-center gap-2 border-b border-zinc-200/60 dark:border-zinc-800/60 pb-3 mb-4 overflow-x-auto no-scrollbar">
            <button
              type="button"
              onClick={() => {
                triggerHaptic('light')
                setOrderSubTab('LIVE')
              }}
              className={`flex items-center gap-2 px-4 py-2 rounded-2xl text-xs font-black transition-all cursor-pointer whitespace-nowrap ${
                orderSubTab === 'LIVE'
                  ? 'bg-gradient-to-r from-[#e8153a] to-[#ff2d55] text-white shadow-md shadow-rose-500/20'
                  : 'bg-zinc-100 dark:bg-zinc-900 text-zinc-600 dark:text-zinc-400 hover:bg-zinc-200/60'
              }`}
            >
              <span>🔥 Live Active Orders</span>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                orderSubTab === 'LIVE' ? 'bg-white/25 text-white' : 'bg-zinc-200 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300'
              }`}>
                {orders.filter((o) => !['DELIVERED', 'CANCELLED'].includes(o.status)).length}
              </span>
            </button>

            <button
              type="button"
              onClick={() => {
                triggerHaptic('light')
                setOrderSubTab('HISTORY')
              }}
              className={`flex items-center gap-2 px-4 py-2 rounded-2xl text-xs font-black transition-all cursor-pointer whitespace-nowrap ${
                orderSubTab === 'HISTORY'
                  ? 'bg-gradient-to-r from-[#e8153a] to-[#ff2d55] text-white shadow-md shadow-rose-500/20'
                  : 'bg-zinc-100 dark:bg-zinc-900 text-zinc-600 dark:text-zinc-400 hover:bg-zinc-200/60'
              }`}
            >
              <span>📜 Order History</span>
              <span className={`px-2 py-0.5 rounded-full text-[10px] font-black ${
                orderSubTab === 'HISTORY' ? 'bg-white/25 text-white' : 'bg-zinc-200 dark:bg-zinc-800 text-zinc-700 dark:text-zinc-300'
              }`}>
                {orders.filter((o) => ['DELIVERED', 'CANCELLED'].includes(o.status)).length}
              </span>
            </button>
          </div>

          {/* Render Orders Based on Sub-Tab */}
          {(() => {
            let filteredOrders = orders.filter((ord) =>
              orderSubTab === 'LIVE'
                ? !['DELIVERED', 'CANCELLED'].includes(ord.status)
                : ['DELIVERED', 'CANCELLED'].includes(ord.status)
            )

            // Apply status filter
            if (orderStatusFilter !== 'ALL') {
              filteredOrders = filteredOrders.filter((ord) => ord.status === orderStatusFilter)
            }

            // Apply search filter
            if (orderSearchQuery.trim()) {
              const q = orderSearchQuery.toLowerCase().trim()
              filteredOrders = filteredOrders.filter((ord) =>
                ord.id.toLowerCase().includes(q) ||
                (ord.readableId && String(ord.readableId).toLowerCase().includes(q)) ||
                ord.items?.some((item: any) => item.name?.toLowerCase().includes(q))
              )
            }

            if (filteredOrders.length === 0) {
              return (
                <div className="text-center py-14 border border-dashed border-zinc-200 dark:border-zinc-800 bg-white/60 dark:bg-zinc-900/40 rounded-3xl p-6">
                  <span className="text-5xl mb-3 block">{orderSubTab === 'LIVE' ? '🚀' : '📦'}</span>
                  <h3 className="text-base font-black text-text-primary">
                    {orderSubTab === 'LIVE' ? 'No live active orders right now' : 'No past order history found'}
                  </h3>
                  <p className="text-xs text-text-secondary mt-1 font-medium max-w-sm mx-auto">
                    {orderSubTab === 'LIVE'
                      ? 'Place an order now to track your delivery live in real-time with GPS updates!'
                      : 'Your completed & past orders will appear here for easy one-tap reordering.'}
                  </p>
                  <Link href="/" className="mt-5 inline-flex items-center gap-2 bg-gradient-to-r from-[#e8153a] to-[#ff2d55] text-white text-xs font-black px-5 py-2.5 rounded-2xl shadow-md shadow-rose-500/20 hover:scale-[1.02] active:scale-95 transition-all">
                    Start Shopping <ArrowRight className="h-3.5 w-3.5 stroke-[2.5]" />
                  </Link>
                </div>
              )
            }

            return filteredOrders.map((ord) => (
              <div key={ord.id} className="bg-white dark:bg-zinc-950 border border-zinc-200/80 dark:border-zinc-800 p-4 sm:p-5 rounded-3xl shadow-[0_4px_20px_-10px_rgba(0,0,0,0.05)] space-y-4 hover:shadow-md transition-all">
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-zinc-100 dark:border-zinc-900 pb-3.5">
                  <div>
                    <span className="text-[11px] font-black text-rose-600 dark:text-rose-400 bg-rose-500/10 border border-rose-500/20 px-2.5 py-0.5 rounded-lg font-mono tracking-wide">
                      Order #{ord.readableId || (ord.id.length > 12 ? ord.id.slice(-6).toUpperCase() : ord.id)}
                    </span>
                    <div className="flex items-center gap-2 mt-2">
                      <span className="text-xs font-black text-text-primary">
                        Total: {formatPrice(ord.total)}
                      </span>
                      <span className="text-[10px] text-text-secondary font-medium">•</span>
                      <span className="text-[10px] text-text-secondary font-bold">
                        {ord.items.length} items
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={cn("text-[10px] font-black px-3 py-1 rounded-full", ORDER_STATUS_COLORS[ord.status])}>
                      {ORDER_STATUS_LABELS[ord.status]}
                    </span>
                    <Link
                      href={`/order/${ord.id}/track`}
                      className="text-[11px] font-black text-white bg-zinc-900 dark:bg-zinc-100 dark:text-zinc-900 hover:bg-zinc-800 px-3.5 py-1.5 rounded-2xl shadow-sm hover:shadow active:scale-95 transition-all flex items-center gap-1 select-none cursor-pointer"
                    >
                      Track
                      <ArrowRight className="h-3 w-3 stroke-[2.8]" />
                    </Link>
                    {['DELIVERED', 'CANCELLED'].includes(ord.status) && (
                      <button
                        type="button"
                        onClick={() => {
                          triggerHaptic('light')
                          setReorderOrderModal(ord)
                        }}
                        className="text-[11px] font-black text-white bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 px-3.5 py-1.5 rounded-2xl shadow-sm shadow-emerald-600/20 hover:shadow active:scale-95 transition-all flex items-center gap-1.5 cursor-pointer select-none"
                      >
                        <RotateCcw className="h-3.5 w-3.5 stroke-[2.5]" />
                        Reorder
                      </button>
                    )}
                  </div>
                </div>
                <div className="text-xs font-bold text-text-secondary flex flex-wrap gap-x-2 gap-y-1.5">
                  {ord.items.map((item: any) => (
                    <span key={item.id || item.name} className="bg-zinc-100 dark:bg-zinc-900/80 px-2.5 py-1 rounded-xl border border-zinc-200/50 dark:border-zinc-800/50 text-[11px] font-bold text-zinc-700 dark:text-zinc-300">
                      {item.name} (×{item.quantity})
                    </span>
                  ))}
                </div>
              </div>
            ))
          })()}

          {/* One-tap Reorder Buy Again Section */}
          <BuyAgainSection />
        </TabsContent>

        {/* Tab Content: Wishlist */}
        <TabsContent value="wishlist" className="animate-fade-in focus-visible:outline-none">
          <Suspense fallback={<div className="flex items-center justify-center py-20">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
          </div>}>
            <WishlistClient />
          </Suspense>
        </TabsContent>

        {/* Tab Content: Saved Addresses */}
        <TabsContent value="addresses" className="space-y-4 animate-fade-in focus-visible:outline-none">
          {addresses.length === 0 ? (
            <div className="text-center py-16 border border-dashed border-border bg-card rounded-2xl p-6">
              <span className="text-4xl mb-2 block">📍</span>
              <h3 className="text-sm font-bold text-text-primary">No addresses saved</h3>
              <p className="text-xs text-text-secondary mt-1">Save delivery destinations for faster checkouts.</p>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {addresses.map((addr) => (
                <div key={addr.id} className="bg-card border border-border p-4 rounded-xl shadow-sm flex flex-col justify-between gap-4">
                  <div className="text-xs">
                    <div className="flex items-center gap-2 mb-2">
                      <span className="font-bold text-text-primary uppercase bg-muted/60 px-2 py-0.5 rounded">
                        {addr.label}
                      </span>
                      {addr.isDefault && (
                        <span className="text-[10px] text-accent font-semibold bg-accent/10 px-1.5 py-0.5 rounded">
                          Default
                        </span>
                      )}
                    </div>
                    <p className="text-text-secondary leading-relaxed font-semibold truncate" title={formatAddress(addr)}>
                      {formatAddress(addr)}
                    </p>
                    {addr.phone && (
                      <p className="text-[10px] text-text-secondary mt-1 font-extrabold flex items-center gap-1">
                        <span>📞</span> Phone: {addr.phone}
                      </p>
                    )}
                  </div>
                  <div className="flex gap-2 items-center">
                    {addresses.length <= 1 ? (
                      <span
                        className="text-text-muted text-[10px] font-semibold h-7 px-2.5 flex items-center gap-1 italic"
                        title="You must keep at least one delivery address"
                      >
                        🔒 Primary
                      </span>
                    ) : (
                      <Button
                        onClick={() => handleDeleteAddress(addr.id)}
                        variant="ghost"
                        className="text-danger hover:bg-danger/10 hover:text-danger text-[10px] font-bold h-7 px-2.5 rounded-lg"
                      >
                        Delete
                      </Button>
                    )}
                    <Button
                      onClick={() => handleEditClick(addr)}
                      variant="ghost"
                      className="text-primary hover:bg-primary/10 text-[10px] font-bold h-7 px-2.5 rounded-lg"
                    >
                      Edit
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}

          {editingAddress && (
            <Dialog open={editingAddress !== null} onOpenChange={(open) => !open && setEditingAddress(null)}>
              <DialogContent className="max-w-[340px] w-[92%] mx-auto rounded-[24px] p-5 border border-zinc-200/80 dark:border-zinc-800 bg-white dark:bg-zinc-950">
                <DialogHeader className="text-center">
                  <DialogTitle className="text-sm font-black text-text-primary tracking-tight">Edit Address</DialogTitle>
                </DialogHeader>
                <form onSubmit={handleUpdateAddress} className="space-y-4 text-left mt-3">
                  <div className="space-y-1">
                    <Label htmlFor="label" className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider">Address Label</Label>
                    <Input
                      id="label"
                      required
                      value={addressForm.label}
                      onChange={(e) => setAddressForm({ ...addressForm, label: e.target.value })}
                      className="h-10 rounded-xl text-xs font-semibold"
                    />
                  </div>
                  <div className="space-y-1">
                    <Label htmlFor="street" className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider">Complete Address</Label>
                    <textarea
                      id="street"
                      required
                      rows={3}
                      value={addressForm.street}
                      onChange={(e) => setAddressForm({ ...addressForm, street: e.target.value })}
                      className="w-full bg-background border border-border px-3 py-2 rounded-xl text-xs font-semibold focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary"
                    />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div className="space-y-1">
                      <Label htmlFor="pincode" className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider">Pincode</Label>
                      <Input
                        id="pincode"
                        required
                        value={addressForm.pincode}
                        onChange={(e) => setAddressForm({ ...addressForm, pincode: e.target.value })}
                        className="h-10 rounded-xl text-xs font-semibold"
                      />
                    </div>
                    <div className="space-y-1">
                      <Label htmlFor="phone" className="text-[10px] font-extrabold uppercase text-text-secondary tracking-wider">Phone</Label>
                      <Input
                        id="phone"
                        required
                        value={addressForm.phone}
                        onChange={(e) => setAddressForm({ ...addressForm, phone: e.target.value })}
                        className="h-10 rounded-xl text-xs font-semibold"
                      />
                    </div>
                  </div>
                  <div className="flex gap-2 pt-2">
                    <Button
                      type="button"
                      variant="ghost"
                      onClick={() => setEditingAddress(null)}
                      disabled={isSavingAddress}
                      className="flex-1 h-10 rounded-xl text-xs font-bold"
                    >
                      Cancel
                    </Button>
                    <Button
                      type="submit"
                      disabled={isSavingAddress}
                      className="flex-1 h-10 bg-primary text-white rounded-xl text-xs font-black hover:bg-primary/95 shadow-md"
                    >
                      {isSavingAddress ? <Loader2 className="h-4.5 w-4.5 animate-spin mx-auto" /> : 'Save Changes'}
                    </Button>
                  </div>
                </form>
              </DialogContent>
            </Dialog>
          )}
        </TabsContent>

        {/* Tab Content: Profile Settings */}
        <TabsContent value="profile" className="space-y-4 animate-fade-in focus-visible:outline-none">
          <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-4">
            <h3 className="font-extrabold text-text-primary text-base">Personal Details</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold">
              <div className="space-y-1 col-span-1 sm:col-span-2">
                <div className="flex justify-between items-center">
                  <span className="text-text-secondary block">Full Name</span>
                  {!isEditingName ? (
                    <button
                      onClick={() => {
                        triggerHaptic('light')
                        setIsEditingName(true)
                        setNewName(userName)
                      }}
                      className="text-[10px] text-primary font-bold hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <Pencil className="h-3 w-3" /> Edit Name
                    </button>
                  ) : (
                    <button
                      onClick={() => {
                        triggerHaptic('light')
                        setIsEditingName(false)
                        setNewName(userName)
                      }}
                      className="text-[10px] text-text-muted font-bold hover:underline flex items-center gap-1 cursor-pointer"
                    >
                      <X className="h-3 w-3" /> Cancel
                    </button>
                  )}
                </div>

                {!isEditingName ? (
                  <span className="text-text-primary block font-bold text-sm bg-muted/40 p-2.5 rounded-lg border">
                    {userName || 'Not provided'}
                  </span>
                ) : (
                  <form onSubmit={handleUpdateName} className="space-y-2 p-3 bg-muted/10 rounded-lg border border-dashed animate-slide-up">
                    <div className="flex gap-2">
                      <input
                        type="text"
                        disabled={isUpdatingName}
                        value={newName}
                        onChange={(e) => setNewName(e.target.value)}
                        placeholder="Enter your full name"
                        maxLength={50}
                        autoFocus
                        className="flex-grow bg-background text-text-primary px-3 py-2 text-xs font-semibold rounded-lg border border-input focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                      <button
                        type="submit"
                        disabled={isUpdatingName || !newName.trim()}
                        className="bg-primary text-white text-[10px] font-black px-4 rounded-lg hover:bg-primary-dark disabled:opacity-50 flex items-center gap-1.5 cursor-pointer shadow-xs transition-all"
                      >
                        {isUpdatingName ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          'Save Name'
                        )}
                      </button>
                    </div>
                  </form>
                )}
              </div>
              {!user.email.startsWith('wa-') && (
                <div className="space-y-1 col-span-1 sm:col-span-2">
                  <div className="flex justify-between items-center">
                    <span className="text-text-secondary block">Email Address</span>
                    {!isEditingEmail ? (
                      <button
                        onClick={() => {
                          setIsEditingEmail(true)
                          setNewEmail(email)
                        }}
                        className="text-[10px] text-primary font-bold hover:underline flex items-center gap-1"
                      >
                        <Pencil className="h-3 w-3" /> Edit Email
                      </button>
                    ) : (
                      <button
                        onClick={() => {
                          setIsEditingEmail(false)
                          setIsOtpSent(false)
                        }}
                        className="text-[10px] text-text-muted font-bold hover:underline flex items-center gap-1"
                      >
                        <X className="h-3 w-3" /> Cancel
                      </button>
                    )}
                  </div>
                  
                  {!isEditingEmail ? (
                    <span className="text-text-primary block font-bold text-sm bg-muted/40 p-2.5 rounded-lg border">
                      {email}
                    </span>
                  ) : (
                    <div className="space-y-3 p-3 bg-muted/10 rounded-lg border border-dashed">
                      <div className="flex gap-2">
                        <input
                          type="email"
                          disabled={isOtpSent || isSendingOtp}
                          value={newEmail}
                          onChange={(e) => setNewEmail(e.target.value)}
                          placeholder="Enter new email address"
                          className="flex-grow bg-background text-text-primary px-3 py-2 text-xs font-semibold rounded-lg border border-input focus:outline-none focus:ring-2 focus:ring-primary/20"
                        />
                        {!isOtpSent && (
                          <button
                            type="button"
                            disabled={isSendingOtp}
                            onClick={handleSendEmailOtp}
                            className="bg-primary text-white text-[10px] font-black px-3 rounded-lg hover:bg-primary-dark disabled:opacity-50 flex items-center gap-1"
                          >
                            {isSendingOtp ? (
                              <Loader2 className="h-3 w-3 animate-spin" />
                            ) : (
                              'Send OTP'
                            )}
                          </button>
                        )}
                      </div>

                      {isOtpSent && (
                        <div className="space-y-2 pt-1 border-t border-border/40 animate-slide-up">
                          <div className="flex flex-col sm:flex-row gap-3">
                            <div className="flex-grow space-y-1">
                              <span className="text-[10px] text-text-secondary block font-bold">Verification Code (OTP)</span>
                              <input
                                type="text"
                                maxLength={6}
                                value={otpCode}
                                onChange={(e) => setOtpCode(getLast10Digits(e.target.value))}
                                placeholder="Enter 6-digit code"
                                className="w-full bg-background text-text-primary px-3 py-2 text-xs font-black tracking-wider rounded-lg border border-input focus:outline-none text-center"
                              />
                            </div>
                            <button
                              type="button"
                              disabled={isUpdatingEmail}
                              onClick={handleUpdateEmail}
                              className="bg-accent text-white text-[10px] font-black px-4 h-9 self-end rounded-lg hover:bg-accent-dark disabled:opacity-50 flex items-center justify-center gap-1"
                            >
                              {isUpdatingEmail ? (
                                <Loader2 className="h-3.5 w-3.5 animate-spin" />
                              ) : (
                                'Verify & Update'
                              )}
                            </button>
                          </div>
                          <div className="flex justify-between items-center w-full px-1">
                            {emailCountdown > 0 ? (
                              <span className="text-[10px] text-text-muted">Resend code in {emailCountdown}s</span>
                            ) : (
                              <button
                                type="button"
                                onClick={handleSendEmailOtp}
                                className="text-[10px] text-primary font-bold hover:underline"
                              >
                                Resend Code
                              </button>
                            )}
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              )}
              <div className="space-y-1 col-span-1 sm:col-span-2">
                <div className="flex justify-between items-center">
                  <span className="text-text-secondary block">Phone Number</span>
                  {!isEditingPhone ? (
                    <button
                      onClick={() => {
                        setIsEditingPhone(true)
                        setNewPhone(phone || '')
                      }}
                      className="text-[10px] text-primary font-bold hover:underline flex items-center gap-1"
                    >
                      <Pencil className="h-3 w-3" /> Edit Phone
                    </button>
                  ) : (
                    <button
                      onClick={() => {
                        setIsEditingPhone(false)
                        setIsPhoneOtpSent(false)
                      }}
                      className="text-[10px] text-text-muted font-bold hover:underline flex items-center gap-1"
                    >
                      <X className="h-3 w-3" /> Cancel
                    </button>
                  )}
                </div>
                
                {!isEditingPhone ? (
                  <span className="text-text-primary block font-bold text-sm bg-muted/40 p-2.5 rounded-lg border">
                    {phone || 'Not provided'}
                  </span>
                ) : (
                  <div className="space-y-3 p-3 bg-muted/10 rounded-lg border border-dashed">
                    <div className="flex gap-2">
                      <input
                        type="tel"
                        disabled={isPhoneOtpSent || isSendingPhoneOtp}
                        value={newPhone}
                        onChange={(e) => setNewPhone(e.target.value)}
                        placeholder="Enter 10-digit mobile number"
                        className="flex-grow bg-background text-text-primary px-3 py-2 text-xs font-semibold rounded-lg border border-input focus:outline-none focus:ring-2 focus:ring-primary/20"
                      />
                      {!isPhoneOtpSent && (
                        <button
                          type="button"
                          disabled={isSendingPhoneOtp}
                          onClick={handleSendPhoneOtp}
                          className="bg-primary text-white text-[10px] font-black px-3 rounded-lg hover:bg-primary-dark disabled:opacity-50 flex items-center gap-1"
                        >
                          {isSendingPhoneOtp ? (
                            <Loader2 className="h-3 w-3 animate-spin" />
                          ) : (
                            'Send OTP'
                          )}
                        </button>
                      )}
                    </div>

                    {isPhoneOtpSent && (
                      <div className="space-y-2 pt-1 border-t border-border/40 animate-slide-up">
                        <div className="flex flex-col sm:flex-row gap-3">
                          <div className="flex-grow space-y-1">
                            <span className="text-[10px] text-text-secondary block font-bold">Verification Code (OTP via WhatsApp)</span>
                            <input
                              type="text"
                              maxLength={6}
                              value={phoneOtpCode}
                              onChange={(e) => setPhoneOtpCode(getLast10Digits(e.target.value))}
                              placeholder="Enter 6-digit code"
                              className="w-full bg-background text-text-primary px-3 py-2 text-xs font-black tracking-wider rounded-lg border border-input focus:outline-none text-center"
                            />
                          </div>
                          <button
                            type="button"
                            disabled={isUpdatingPhone}
                            onClick={handleUpdatePhone}
                            className="bg-accent text-white text-[10px] font-black px-4 h-9 self-end rounded-lg hover:bg-accent-dark disabled:opacity-50 flex items-center justify-center gap-1"
                          >
                            {isUpdatingPhone ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              'Verify & Update'
                            )}
                          </button>
                        </div>
                        <div className="flex justify-between items-center w-full px-1">
                          {phoneCountdown > 0 ? (
                            <span className="text-[10px] text-text-muted">Resend code in {phoneCountdown}s</span>
                          ) : (
                            <button
                              type="button"
                              onClick={handleSendPhoneOtp}
                              className="text-[10px] text-primary font-bold hover:underline"
                            >
                              Resend Code
                            </button>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Danger Zone: Account Deletion */}
              <div className="mt-8 pt-6 border-t border-danger/20">
                <div className="bg-danger/5 border border-danger/20 rounded-xl p-4">
                  <h4 className="text-sm font-bold text-danger flex items-center gap-2">
                    <Trash2 className="h-4 w-4" /> Danger Zone: Delete Account
                  </h4>
                  <p className="text-xs text-text-secondary mt-1">
                    Permanently anonymize and delete your account, addresses, and personal information. This action cannot be undone.
                  </p>
                  {!showDeleteConfirm ? (
                    <button
                      type="button"
                      onClick={() => setShowDeleteConfirm(true)}
                      className="mt-3 bg-danger text-white text-xs font-bold px-4 py-2 rounded-lg hover:bg-danger-dark transition-all"
                    >
                      Delete Account
                    </button>
                  ) : (
                    <div className="mt-3 p-3 bg-background rounded-lg border border-danger/30 space-y-2">
                      <p className="text-xs font-bold text-danger">Are you sure you want to permanently delete your account?</p>
                      <div className="flex gap-2">
                        <button
                          type="button"
                          disabled={isDeletingAccount}
                          onClick={handleDeleteAccount}
                          className="bg-danger text-white text-xs font-bold px-4 py-1.5 rounded-lg hover:bg-danger-dark disabled:opacity-50 flex items-center gap-1"
                        >
                          {isDeletingAccount ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : 'Yes, Delete My Account'}
                        </button>
                        <button
                          type="button"
                          onClick={() => setShowDeleteConfirm(false)}
                          className="bg-surface text-text-secondary text-xs font-bold px-4 py-1.5 rounded-lg hover:bg-surface-hover"
                        >
                          Cancel
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>
        </TabsContent>
      </Tabs>

      {/* Premium Reorder Confirmation Modal */}
      {reorderOrderModal && (
        <Dialog open={reorderOrderModal !== null} onOpenChange={(open) => !open && setReorderOrderModal(null)}>
          <DialogContent className="max-w-[420px] w-[92%] mx-auto rounded-[32px] p-6 border border-zinc-200/80 dark:border-zinc-800 bg-white/95 dark:bg-zinc-950/95 backdrop-blur-xl shadow-2xl overflow-hidden">
            {/* Ambient Background Glow */}
            <div className="absolute -top-24 -right-24 h-48 w-48 rounded-full bg-emerald-500/15 blur-3xl pointer-events-none" />
            
            <DialogHeader className="text-center space-y-2 relative z-10">
              <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 text-white shadow-lg shadow-emerald-500/25">
                <RotateCcw className="h-7 w-7 stroke-[2.5]" />
              </div>
              <DialogTitle className="text-lg font-black text-zinc-900 dark:text-white tracking-tight">
                Reorder #{(reorderOrderModal.readableId || reorderOrderModal.id?.slice(-6)).toUpperCase()}?
              </DialogTitle>
              <p className="text-xs font-semibold text-zinc-500 dark:text-zinc-400">
                This will add all {reorderOrderModal.items?.length || 0} items from this order directly into your active cart.
              </p>
            </DialogHeader>

            {/* Order Items Preview Card */}
            <div className="mt-4 max-h-[220px] overflow-y-auto pr-1 space-y-2 scrollbar-none relative z-10">
              {reorderOrderModal.items?.map((item: any) => (
                <div
                  key={item.id || item.name}
                  className="flex items-center justify-between p-3 rounded-2xl bg-zinc-50 dark:bg-zinc-900/60 border border-zinc-200/50 dark:border-zinc-800/60"
                >
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-white dark:bg-zinc-800 border border-zinc-200/50 dark:border-zinc-700/50 text-base font-bold shadow-xs">
                      📦
                    </div>
                    <div>
                      <h4 className="text-xs font-black text-zinc-900 dark:text-white line-clamp-1">{item.name}</h4>
                      <p className="text-[10px] font-bold text-zinc-500 dark:text-zinc-400">
                        {formatPrice(item.price)} × {item.quantity}
                      </p>
                    </div>
                  </div>
                  <span className="text-xs font-black text-emerald-600 dark:text-emerald-400 bg-emerald-500/10 px-2.5 py-0.5 rounded-lg border border-emerald-500/20">
                    {formatPrice(item.price * item.quantity)}
                  </span>
                </div>
              ))}
            </div>

            {/* Price Summary Strip */}
            <div className="mt-4 p-3.5 rounded-2xl bg-zinc-900 dark:bg-zinc-900 text-white flex items-center justify-between relative z-10">
              <span className="text-xs font-bold text-zinc-300">Total Reorder Value</span>
              <span className="text-sm font-black text-emerald-400">{formatPrice(reorderOrderModal.total)}</span>
            </div>

            {/* Modal Actions */}
            <div className="flex gap-3 mt-5 relative z-10">
              <Button
                type="button"
                variant="ghost"
                onClick={() => setReorderOrderModal(null)}
                className="flex-1 h-12 rounded-2xl text-xs font-bold text-zinc-600 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-900 cursor-pointer"
              >
                Cancel
              </Button>
              <Button
                type="button"
                onClick={() => executeReorder(reorderOrderModal)}
                className="flex-[1.5] h-12 rounded-2xl bg-gradient-to-r from-emerald-600 via-teal-600 to-emerald-500 text-white text-xs font-black shadow-lg shadow-emerald-600/30 hover:shadow-emerald-600/40 hover:scale-[1.02] active:scale-[0.98] transition-all cursor-pointer flex items-center justify-center gap-1.5"
              >
                <Sparkles className="h-4 w-4" />
                Add All & Checkout
              </Button>
            </div>
          </DialogContent>
        </Dialog>
      )}
    </div>
  )
}
