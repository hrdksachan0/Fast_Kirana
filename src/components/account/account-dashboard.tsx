'use client'

import { signOut } from 'next-auth/react'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Button } from '@/components/ui/button'
import { formatPrice, formatAddress } from '@/lib/utils'
import { ORDER_STATUS_LABELS, ORDER_STATUS_COLORS } from '@/lib/constants'
import { LogOut, MapPin, User, Package, ArrowRight, Pencil, X, Loader2 } from 'lucide-react'
import Link from 'next/link'
import { toast } from 'sonner'
import { useState, useEffect } from 'react'
import { cn } from '@/lib/utils'
import { BuyAgainSection } from '@/components/home/buy-again-section'
import { useSearchParams } from 'next/navigation'

interface AccountDashboardProps {
  user: {
    name: string | null
    email: string
    phone: string | null
    role: 'USER' | 'PICKER' | 'CHEF' | 'DELIVERY' | 'ADMIN'
  }
  addresses: any[]
  orders: any[]
}

export function AccountDashboard({ user, addresses: initialAddresses, orders: initialOrders }: AccountDashboardProps) {
  const [addresses, setAddresses] = useState(initialAddresses)
  const [orders, setOrders] = useState(initialOrders)
  const searchParams = useSearchParams()
  const [activeTab, setActiveTab] = useState('orders')

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

  const handleSendPhoneOtp = async () => {
    if (!newPhone || newPhone.replace(/\D/g, '').length < 10) {
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

  // Live order status updates via Server-Sent Events
  useEffect(() => {
    const activeOrders = orders.filter(
      (ord) => !['DELIVERED', 'CANCELLED'].includes(ord.status)
    )
    if (activeOrders.length === 0) return

    const eventSources = activeOrders.map((ord) => {
      const es = new EventSource(`/api/orders/${ord.id}/live`)
      es.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.status && data.status !== ord.status) {
            setOrders((prevOrders) =>
              prevOrders.map((o) =>
                o.id === ord.id ? { ...o, status: data.status } : o
              )
            )
          }
        } catch (err) {
          console.error('Error parsing SSE in AccountDashboard:', err)
        }
      }
      es.onerror = (err) => {
        console.error(`SSE error for order ${ord.id}:`, err)
        es.close()
      }
      return { id: ord.id, es }
    })

    return () => {
      eventSources.forEach(({ es }) => es.close())
    }
  }, [orders.map((o) => `${o.id}:${o.status}`).join(',')])

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

  const formatEmailForDisplay = (email: string) => {
    if (email.startsWith('wa-') && email.includes('@')) {
      const phoneDigits = email.split('@')[0].replace('wa-', '')
      return `+91 ${phoneDigits}`
    }
    return email
  }

  return (
    <div className="w-full max-w-4xl mx-auto space-y-6">
      
      {/* User Welcome Card Banner */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 border border-border bg-card p-6 rounded-2xl shadow-sm">
        <div className="flex items-center gap-3.5">
          <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 text-primary text-lg font-bold">
            {user.name?.charAt(0) || 'U'}
          </div>
          <div>
            <h2 className="text-lg font-black text-text-primary">{user.name || 'User'}</h2>
            <p className="text-xs text-text-secondary">{formatEmailForDisplay(user.email)}</p>
          </div>
        </div>
        
        {/* Navigation links for Admin or Delivery Boy */}
        <div className="flex flex-wrap items-center gap-2">
          {user.role === 'ADMIN' && (
            <Link href="/admin">
              <Button variant="outline" className="border-primary/30 text-primary hover:bg-primary/5 rounded-xl text-xs h-10 px-4 font-bold">
                Admin Console
              </Button>
            </Link>
          )}
          {user.role === 'PICKER' && (
            <Link href="/picker">
              <Button variant="outline" className="border-primary/30 text-primary hover:bg-primary/5 rounded-xl text-xs h-10 px-4 font-bold">
                Picker Console
              </Button>
            </Link>
          )}
          {user.role === 'CHEF' && (
            <Link href="/cafe-kitchen">
              <Button variant="outline" className="border-rose-500/30 text-rose-500 hover:bg-rose-500/5 rounded-xl text-xs h-10 px-4 font-bold">
                Chef Console
              </Button>
            </Link>
          )}
          {user.role === 'DELIVERY' && (
            <Link href="/delivery">
              <Button variant="outline" className="border-accent/30 text-accent hover:bg-accent/5 rounded-xl text-xs h-10 px-4 font-bold">
                Rider Console
              </Button>
            </Link>
          )}
          <Button
            onClick={handleSignOut}
            variant="outline"
            className="text-danger hover:bg-danger/5 border-danger/25 hover:text-danger hover:border-danger rounded-xl text-xs flex items-center gap-1.5 h-10 px-4"
          >
            <LogOut className="h-4 w-4" />
            Logout
          </Button>
        </div>
      </div>

      {/* Tabs Layout */}
      <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
        <TabsList className="grid w-full grid-cols-3 bg-muted p-1 rounded-xl mb-6">
          <TabsTrigger value="orders" className="text-xs font-bold rounded-lg py-2 flex items-center gap-1.5 cursor-pointer">
            <Package className="h-3.5 w-3.5" />
            My Orders
          </TabsTrigger>
          <TabsTrigger value="addresses" className="text-xs font-bold rounded-lg py-2 flex items-center gap-1.5 cursor-pointer">
            <MapPin className="h-3.5 w-3.5" />
            Addresses
          </TabsTrigger>
          <TabsTrigger value="profile" className="text-xs font-bold rounded-lg py-2 flex items-center gap-1.5 cursor-pointer">
            <User className="h-3.5 w-3.5" />
            Profile Info
          </TabsTrigger>
        </TabsList>

        {/* Tab Content: Orders */}
        <TabsContent value="orders" className="space-y-4 animate-fade-in focus-visible:outline-none">
          {orders.length === 0 ? (
            <div className="text-center py-16 border border-dashed border-border bg-card rounded-2xl p-6">
              <span className="text-4xl mb-2 block">📦</span>
              <h3 className="text-sm font-bold text-text-primary">No orders placed yet</h3>
              <p className="text-xs text-text-secondary mt-1">Start shopping and place your first instant order today!</p>
              <Link href="/" className="mt-4 inline-block bg-primary text-white text-xs font-bold px-4 py-2 rounded-xl">
                Start Shopping
              </Link>
            </div>
          ) : (
            orders.map((ord) => (
              <div key={ord.id} className="bg-card border border-border p-4 rounded-xl shadow-sm space-y-4">
                <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 border-b border-border/40 pb-3">
                  <div>
                    <span className="text-[10px] text-text-muted font-mono uppercase">Order ID: {ord.id}</span>
                    <div className="flex items-center gap-2 mt-1">
                      <span className="text-xs font-bold text-text-primary">
                        Total: {formatPrice(ord.total)}
                      </span>
                      <span className="text-[10px] text-text-secondary font-medium">•</span>
                      <span className="text-[10px] text-text-secondary font-medium">
                        {ord.items.length} items
                      </span>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={cn("text-[10px] font-bold px-2.5 py-0.5 rounded-full", ORDER_STATUS_COLORS[ord.status])}>
                      {ORDER_STATUS_LABELS[ord.status]}
                    </span>
                    <Link
                      href={`/order/${ord.id}/track`}
                      className="text-[10px] font-black text-white bg-primary hover:bg-primary-dark px-3 py-1.5 rounded-xl shadow-sm hover:shadow active:scale-95 transition-all flex items-center gap-1 select-none cursor-pointer"
                    >
                      Track Order
                      <ArrowRight className="h-3 w-3 stroke-[2.8]" />
                    </Link>
                  </div>
                </div>
                <div className="text-xs font-semibold text-text-secondary flex flex-wrap gap-x-4 gap-y-1">
                  {ord.items.map((item: any) => (
                    <span key={item.id} className="bg-muted/40 px-2 py-1 rounded-md border border-border/20">
                      {item.name} (×{item.quantity})
                    </span>
                  ))}
                </div>
              </div>
            ))
          )}

          {/* One-tap Reorder Buy Again Section */}
          <BuyAgainSection />
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
                  {addresses.length <= 1 ? (
                    <span
                      className="text-text-muted self-start text-[10px] font-semibold h-7 px-2.5 flex items-center gap-1 italic"
                      title="You must keep at least one delivery address"
                    >
                      🔒 Primary address
                    </span>
                  ) : (
                    <Button
                      onClick={() => handleDeleteAddress(addr.id)}
                      variant="ghost"
                      className="text-danger hover:bg-danger/10 hover:text-danger self-start text-[10px] font-bold h-7 px-2.5"
                    >
                      Delete Address
                    </Button>
                  )}
                </div>
              ))}
            </div>
          )}
        </TabsContent>

        {/* Tab Content: Profile Settings */}
        <TabsContent value="profile" className="space-y-4 animate-fade-in focus-visible:outline-none">
          <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-4">
            <h3 className="font-extrabold text-text-primary text-base">Personal Details</h3>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs font-semibold">
              <div className="space-y-1">
                <span className="text-text-secondary block">Name</span>
                <span className="text-text-primary block font-bold text-sm bg-muted/40 p-2.5 rounded-lg border">
                  {user.name || 'Not provided'}
                </span>
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
                                onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ''))}
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
                              onChange={(e) => setPhoneOtpCode(e.target.value.replace(/\D/g, ''))}
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
            </div>
          </div>
        </TabsContent>
      </Tabs>
    </div>
  )
}
