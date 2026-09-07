'use client'

import { useState, useEffect, useCallback } from 'react'
import {
  IndianRupee, ShoppingBag, Users, TrendingUp, Store, Plus, MapPin, Phone,
  Loader2, CheckCircle, XCircle, ChevronRight, Building2, Shield, Truck,
  ChefHat, Package, RefreshCw, ExternalLink
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'
import { toast } from 'sonner'
import Link from 'next/link'

interface SuperAdminDashboardProps {
  serverUser: {
    id?: string
    name?: string | null
    email?: string | null
    phone?: string | null
  }
}

export function SuperAdminDashboard({ serverUser }: SuperAdminDashboardProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'sales' | 'staff' | 'create-store'>('overview')
  const [data, setData] = useState<any>(null)
  const [isLoading, setIsLoading] = useState(true)

  // Create store form state
  const [isCreating, setIsCreating] = useState(false)
  const [newStoreName, setNewStoreName] = useState('')
  const [newStorePincode, setNewStorePincode] = useState('')
  const [newStoreCustomId, setNewStoreCustomId] = useState('')
  const [newStoreLat, setNewStoreLat] = useState('')
  const [newStoreLng, setNewStoreLng] = useState('')
  const [newStoreRadius, setNewStoreRadius] = useState('5')
  const [newStoreManagerPhone, setNewStoreManagerPhone] = useState('')
  const [seedInventory, setSeedInventory] = useState(true)

  const fetchData = useCallback(async () => {
    setIsLoading(true)
    try {
      const res = await fetch('/api/superadmin/stats')
      if (!res.ok) throw new Error('Failed to fetch HQ stats')
      const json = await res.json()
      setData(json)
    } catch (error: any) {
      toast.error(error.message || 'Failed to load dashboard data')
    } finally {
      setIsLoading(false)
    }
  }, [])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  const handleCreateStore = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!newStoreName) {
      toast.error('Store name is required')
      return
    }

    setIsCreating(true)
    try {
      const payload = {
        name: newStoreName,
        id: newStoreCustomId || undefined,
        pincode: newStorePincode || undefined,
        latitude: parseFloat(newStoreLat) || 0,
        longitude: parseFloat(newStoreLng) || 0,
        deliveryRadiusKm: parseFloat(newStoreRadius) || 5,
        managerPhone: newStoreManagerPhone || undefined,
        seedInventory
      }

      const res = await fetch('/api/admin/stores', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      })

      if (!res.ok) {
        const err = await res.json()
        throw new Error(err.error || err.message || 'Failed to create store')
      }

      toast.success('Store created successfully!')
      
      // Reset form
      setNewStoreName('')
      setNewStorePincode('')
      setNewStoreCustomId('')
      setNewStoreLat('')
      setNewStoreLng('')
      setNewStoreRadius('5')
      setNewStoreManagerPhone('')
      setSeedInventory(true)

      // Switch tab and refresh
      setActiveTab('overview')
      fetchData()
    } catch (error: any) {
      toast.error(error.message || 'An error occurred')
    } finally {
      setIsCreating(false)
    }
  }

  if (isLoading && !data) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[400px] gap-3">
        <Loader2 className="h-8 w-8 animate-spin text-text-secondary" />
        <p className="text-sm font-bold text-text-secondary">Loading HQ data...</p>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Tab Navigation & Refresh */}
      <div className="flex items-center justify-between">
        <div className="flex flex-wrap items-center gap-2">
          {[
            { id: 'overview', label: '🏠 HQ Overview' },
            { id: 'sales', label: '💰 Store Sales' },
            { id: 'staff', label: '👥 Staff' },
            { id: 'create-store', label: '➕ New Store' }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id as any)}
              className={`px-4 py-2.5 rounded-xl text-xs font-black uppercase tracking-wider transition-all ${
                activeTab === tab.id
                  ? 'bg-[#e20a22] text-white shadow-sm'
                  : 'bg-card border border-border/60 text-text-secondary hover:text-text-primary hover:bg-muted/30'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
        <button
          onClick={fetchData}
          disabled={isLoading}
          className="h-9 w-9 shrink-0 rounded-xl bg-card border border-border/60 flex items-center justify-center hover:bg-muted/50 transition-all disabled:opacity-50"
          title="Refresh Data"
        >
          <RefreshCw className={`h-4 w-4 text-text-secondary ${isLoading ? 'animate-spin' : ''}`} />
        </button>
      </div>

      {/* Tab 1: Overview */}
      {activeTab === 'overview' && data && (
        <div className="space-y-6">
          {/* Stats Grid */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-3.5">
            {/* Combined Sales */}
            <div className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] font-bold text-text-secondary">TODAY'S COMBINED SALES</p>
                <p className="text-lg sm:text-xl font-black text-text-primary mt-1">
                  {formatPrice(data.combined?.todaySales || 0)}
                </p>
              </div>
              <div className="h-10 w-10 shrink-0 rounded-xl border border-[#e20a22]/20 bg-[#e20a22]/5 flex items-center justify-center text-[#e20a22]">
                <IndianRupee className="h-5 w-5" />
              </div>
            </div>

            {/* Net Revenue */}
            <div className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] font-bold text-text-secondary">TODAY'S NET REVENUE</p>
                <p className="text-lg sm:text-xl font-black text-text-primary mt-1">
                  {formatPrice(data.combined?.todayNetRevenue || 0)}
                </p>
              </div>
              <div className="h-10 w-10 shrink-0 rounded-xl border border-emerald-500/20 bg-emerald-500/5 flex items-center justify-center text-emerald-600">
                <TrendingUp className="h-5 w-5" />
              </div>
            </div>

            {/* Orders */}
            <div className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] font-bold text-text-secondary">TODAY'S ORDERS</p>
                <p className="text-lg sm:text-xl font-black text-text-primary mt-1">
                  {data.combined?.todayOrders || 0}
                </p>
              </div>
              <div className="h-10 w-10 shrink-0 rounded-xl border border-blue-500/20 bg-blue-500/5 flex items-center justify-center text-blue-600">
                <ShoppingBag className="h-5 w-5" />
              </div>
            </div>

            {/* Total Staff */}
            <div className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex items-center justify-between">
              <div>
                <p className="text-[11px] font-bold text-text-secondary">TOTAL STAFF</p>
                <p className="text-lg sm:text-xl font-black text-text-primary mt-1">
                  {data.combined?.totalStaff || 0}
                </p>
              </div>
              <div className="h-10 w-10 shrink-0 rounded-xl border border-purple-500/20 bg-purple-500/5 flex items-center justify-center text-purple-600">
                <Users className="h-5 w-5" />
              </div>
            </div>
          </div>

          {/* Store Health Grid */}
          <div>
            <h3 className="text-sm font-black text-text-primary uppercase tracking-wider mb-3 flex items-center gap-2">
              <Building2 className="h-4 w-4" /> Store Health
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {data.stores?.map((store: any) => (
                <div key={store.id} className="p-4 rounded-2xl bg-card border border-border/60 shadow-xs flex flex-col h-full">
                  <div className="flex items-start justify-between mb-4">
                    <div>
                      <h4 className="font-bold text-text-primary flex items-center gap-2">
                        <Store className="h-4 w-4 text-[#e20a22]" />
                        {store.name}
                      </h4>
                      {(store.managerName || store.managerPhone) && (
                        <p className="text-xs text-text-secondary mt-1 flex items-center gap-1.5">
                          Manager: {store.managerName || 'Unknown'} 
                          {store.managerPhone && (
                            <>
                              <span className="text-border">•</span>
                              <Phone className="h-3 w-3" /> {store.managerPhone}
                            </>
                          )}
                        </p>
                      )}
                    </div>
                    {store.isOpen ? (
                      <span className="bg-emerald-500/10 text-emerald-600 border border-emerald-500/20 text-[10px] font-black px-2 py-0.5 rounded-full shrink-0">
                        ● OPEN
                      </span>
                    ) : (
                      <span className="bg-rose-500/10 text-rose-600 border border-rose-500/20 text-[10px] font-black px-2 py-0.5 rounded-full shrink-0">
                        ● CLOSED
                      </span>
                    )}
                  </div>

                  <div className="flex items-center gap-4 mt-auto pt-4 border-t border-border/40 mb-4">
                    <div className="flex items-center gap-1.5 text-sm font-bold text-text-primary">
                      <Users className="h-4 w-4 text-text-secondary" />
                      {store.staffCount || 0} Staff
                    </div>
                    <div className="flex items-center gap-1.5 text-sm font-bold text-text-primary">
                      <Package className="h-4 w-4 text-text-secondary" />
                      {store.orderCount || 0} Orders
                    </div>
                  </div>

                  <Link 
                    href={`/admin?storeId=${store.id}`}
                    className="mt-auto text-xs font-bold text-[#e20a22] hover:text-[#c9081e] flex items-center gap-1 w-fit group"
                  >
                    Open Store Dashboard <ChevronRight className="h-3 w-3 group-hover:translate-x-0.5 transition-transform" />
                  </Link>
                </div>
              ))}
              
              {(!data.stores || data.stores.length === 0) && (
                <div className="col-span-full p-8 text-center text-text-secondary text-sm border border-dashed border-border/60 rounded-2xl">
                  No stores found. Create one from the "New Store" tab.
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Tab 2: Sales */}
      {activeTab === 'sales' && data && (
        <div className="bg-card border border-border/60 rounded-2xl shadow-xs overflow-hidden">
          <div className="p-4 border-b border-border/60">
            <h3 className="text-sm font-black text-text-primary uppercase tracking-wider flex items-center gap-2">
              <TrendingUp className="h-4 w-4" /> Store-wise Performance
            </h3>
          </div>
          
          <div className="overflow-x-auto">
            <div className="min-w-[800px]">
              {/* Header */}
              <div className="grid grid-cols-6 gap-4 px-4 py-3 bg-muted/50 text-[10px] font-black uppercase tracking-wider text-text-secondary">
                <div className="col-span-2">Store Name</div>
                <div>Today's Orders</div>
                <div>Today's Sales</div>
                <div>Delivered</div>
                <div>Net Revenue</div>
              </div>

              {/* Rows */}
              {data.storeWiseSales?.map((row: any, i: number) => {
                const store = data.stores?.find((s: any) => s.id === row.storeId)
                const storeName = store ? store.name : row.storeId ? `Store (${row.storeId})` : 'Primary Hub / Online'
                
                return (
                  <div key={i} className="grid grid-cols-6 gap-4 px-4 py-3.5 border-b border-border/40 items-center">
                    <div className="col-span-2 font-bold text-sm text-text-primary flex items-center gap-2">
                      <Store className="h-4 w-4 text-text-secondary" />
                      {storeName}
                    </div>
                    <div className="text-sm font-black text-text-primary">{row.orderCount || 0}</div>
                    <div className="text-sm font-black text-text-primary">{formatPrice(row.totalSales || 0)}</div>
                    <div className="text-sm font-black text-emerald-600">{row.deliveredOrders || 0}</div>
                    <div className="text-sm font-black text-text-primary">{formatPrice(row.deliveredSales || 0)}</div>
                  </div>
                )
              })}

              {(!data.storeWiseSales || data.storeWiseSales.length === 0) && (
                <div className="p-8 text-center text-text-secondary text-sm">
                  No sales data available for today.
                </div>
              )}

              {/* Combined Total */}
              {data.storeWiseSales && data.storeWiseSales.length > 0 && (
                <div className="grid grid-cols-6 gap-4 px-4 py-3.5 bg-muted/30 items-center border-t border-border/60">
                  <div className="col-span-2 font-black text-sm text-text-primary uppercase">Combined Total</div>
                  <div className="text-sm font-black text-text-primary">{data.combined?.todayOrders || 0}</div>
                  <div className="text-sm font-black text-[#e20a22]">{formatPrice(data.combined?.todaySales || 0)}</div>
                  <div className="text-sm font-black text-emerald-600">
                    {data.storeWiseSales.reduce((acc: number, curr: any) => acc + (curr.deliveredOrders || 0), 0)}
                  </div>
                  <div className="text-sm font-black text-text-primary">{formatPrice(data.combined?.todayNetRevenue || 0)}</div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Tab 3: Staff */}
      {activeTab === 'staff' && data && (
        <div className="space-y-8">
          {/* Group staff by store */}
          {(() => {
            const staffList = data.staff || []
            
            // Grouping logic
            const groupedStaff: Record<string, any[]> = {}
            staffList.forEach((staff: any) => {
              const storeId = staff.assignedStoreId || 'unassigned'
              if (!groupedStaff[storeId]) groupedStaff[storeId] = []
              groupedStaff[storeId].push(staff)
            })

            const getRoleBadge = (role: string) => {
              switch (role) {
                case 'ADMIN': return 'bg-amber-500/10 text-amber-700 border-amber-500/20'
                case 'DELIVERY': return 'bg-emerald-500/10 text-emerald-700 border-emerald-500/20'
                case 'PICKER': return 'bg-blue-500/10 text-blue-700 border-blue-500/20'
                case 'CHEF': return 'bg-orange-500/10 text-orange-700 border-orange-500/20'
                case 'RESTAURANT_OWNER': return 'bg-purple-500/10 text-purple-700 border-purple-500/20'
                default: return 'bg-muted/50 text-text-secondary border-border'
              }
            }

            return (
              <>
                {Object.entries(groupedStaff).map(([storeId, storeStaff]) => {
                  const store = data.stores?.find((s: any) => s.id === storeId)
                  const storeName = store ? store.name : storeId === 'unassigned' ? 'Unassigned / Global Staff' : `Unknown Store (${storeId})`

                  return (
                    <div key={storeId} className="space-y-3">
                      <div className="flex items-center gap-2">
                        <h3 className="text-sm font-black text-text-primary uppercase tracking-wider flex items-center gap-2">
                          <Store className="h-4 w-4" /> {storeName}
                        </h3>
                        <span className="px-2 py-0.5 rounded-full bg-muted/50 border border-border/60 text-[10px] font-bold text-text-secondary">
                          {storeStaff.length} Staff
                        </span>
                      </div>

                      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                        {storeStaff.map((staff: any) => (
                          <div key={staff.id} className="p-3.5 rounded-xl bg-card border border-border/60 flex items-start justify-between gap-2">
                            <div>
                              <p className="text-sm font-bold text-text-primary">{staff.name || 'Unknown Name'}</p>
                              <p className="text-xs text-text-secondary mt-0.5 flex items-center gap-1">
                                <Phone className="h-3 w-3" /> {staff.phone || 'No phone'}
                              </p>
                              {staff.email && (
                                <p className="text-xs text-text-secondary mt-0.5 truncate max-w-[180px]">
                                  {staff.email}
                                </p>
                              )}
                            </div>
                            <span className={`text-[10px] font-black uppercase tracking-wider px-2 py-0.5 rounded-full border shrink-0 ${getRoleBadge(staff.role)}`}>
                              {staff.role}
                            </span>
                          </div>
                        ))}
                      </div>
                    </div>
                  )
                })}

                {staffList.length === 0 && (
                  <div className="p-8 text-center text-text-secondary text-sm border border-dashed border-border/60 rounded-2xl">
                    No staff members found in the system.
                  </div>
                )}
              </>
            )
          })()}
        </div>
      )}

      {/* Tab 4: Create Store */}
      {activeTab === 'create-store' && (
        <div className="max-w-xl">
          <div className="bg-card border border-border/60 rounded-2xl shadow-xs overflow-hidden">
            <div className="p-4 border-b border-border/60">
              <h3 className="text-sm font-black text-text-primary uppercase tracking-wider flex items-center gap-2">
                <Plus className="h-4 w-4" /> Create New Store / Hub
              </h3>
            </div>
            
            <form onSubmit={handleCreateStore} className="p-5 space-y-4">
              <div>
                <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                  Store Name *
                </label>
                <input
                  type="text"
                  required
                  value={newStoreName}
                  onChange={e => setNewStoreName(e.target.value)}
                  placeholder="e.g. Indiranagar Hub"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Pincode
                  </label>
                  <input
                    type="text"
                    value={newStorePincode}
                    onChange={e => setNewStorePincode(e.target.value)}
                    placeholder="e.g. 560038"
                    maxLength={6}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Custom Store ID
                  </label>
                  <input
                    type="text"
                    value={newStoreCustomId}
                    onChange={e => setNewStoreCustomId(e.target.value)}
                    placeholder="Optional (auto-generated)"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Latitude
                  </label>
                  <input
                    type="number"
                    step="any"
                    value={newStoreLat}
                    onChange={e => setNewStoreLat(e.target.value)}
                    placeholder="e.g. 12.9716"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Longitude
                  </label>
                  <input
                    type="number"
                    step="any"
                    value={newStoreLng}
                    onChange={e => setNewStoreLng(e.target.value)}
                    placeholder="e.g. 77.5946"
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Delivery Radius (km)
                  </label>
                  <input
                    type="number"
                    step="0.1"
                    min="0"
                    value={newStoreRadius}
                    onChange={e => setNewStoreRadius(e.target.value)}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-text-secondary uppercase tracking-wider mb-1.5">
                    Manager Phone
                  </label>
                  <input
                    type="tel"
                    value={newStoreManagerPhone}
                    onChange={e => setNewStoreManagerPhone(e.target.value)}
                    placeholder="10 digit number"
                    maxLength={10}
                    className="w-full px-3.5 py-2.5 rounded-xl bg-muted/50 border border-border/60 text-sm font-medium text-text-primary focus:outline-none focus:ring-2 focus:ring-[#e20a22]/30 focus:border-[#e20a22]/50"
                  />
                </div>
              </div>

              <div className="pt-2">
                <label className="flex items-center gap-3 p-3 rounded-xl border border-border/60 bg-muted/30 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={seedInventory}
                    onChange={e => setSeedInventory(e.target.checked)}
                    className="h-4 w-4 rounded border-border/60 text-[#e20a22] focus:ring-[#e20a22]/30"
                  />
                  <div>
                    <p className="text-sm font-bold text-text-primary">Seed Inventory</p>
                    <p className="text-xs text-text-secondary mt-0.5">Copy all existing products to this new store automatically</p>
                  </div>
                </label>
              </div>

              <div className="pt-4 border-t border-border/60 flex justify-end">
                <button
                  type="submit"
                  disabled={isCreating}
                  className="bg-[#e20a22] hover:bg-[#c9081e] text-white font-black text-xs uppercase tracking-wider px-6 py-3 rounded-xl transition-all active:scale-[0.98] shadow-sm flex items-center gap-2 disabled:opacity-70 disabled:cursor-not-allowed"
                >
                  {isCreating ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" /> Creating...
                    </>
                  ) : (
                    <>
                      <Store className="h-4 w-4" /> Create Store
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
