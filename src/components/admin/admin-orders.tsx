'use client'

import { useState } from 'react'
import { formatPrice, formatAddress } from '@/lib/utils'
import { ORDER_STATUS_LABELS } from '@/lib/constants'
import { toast } from 'sonner'
import { Loader2 } from 'lucide-react'
import Link from 'next/link'

interface AdminOrdersProps {
  initialOrders: any[]
}

export function AdminOrders({ initialOrders }: AdminOrdersProps) {
  const [orders, setOrders] = useState(initialOrders)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  const [filterMode, setFilterMode] = useState<'ALL' | 'PREMIUM' | 'COMBINED'>('ALL')
  const [cancelConfirmOrder, setCancelConfirmOrder] = useState<any | null>(null)

  const premiumCount = orders.filter((o) => o.notes?.includes('Premium') || o.miscFee === 15 || o.miscFee === 20).length
  const combinedCount = orders.filter((o) => !!o.combinedId).length

  const filteredOrders = orders.filter((o) => {
    if (filterMode === 'PREMIUM') {
      return o.notes?.includes('Premium') || o.miscFee === 15 || o.miscFee === 20
    }
    if (filterMode === 'COMBINED') {
      return !!o.combinedId
    }
    return true
  })

  const handleSelectStatusChange = (order: any, newStatus: string) => {
    if (newStatus === 'CANCELLED') {
      setCancelConfirmOrder(order)
    } else {
      handleStatusChange(order.id, newStatus)
    }
  }

  const handleStatusChange = async (orderId: string, newStatus: string) => {
    setUpdatingId(orderId)
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
      setUpdatingId(null)
    }
  }

  return (
    <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <h3 className="font-extrabold text-text-primary text-base">Manage Orders</h3>

        {/* Quick Filter Pills */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => setFilterMode('ALL')}
            className={`px-3 py-1.5 rounded-xl text-xs font-black transition-all cursor-pointer ${
              filterMode === 'ALL'
                ? 'bg-primary text-white shadow-xs'
                : 'bg-muted/80 text-text-secondary hover:bg-muted'
            }`}
          >
            All Orders ({orders.length})
          </button>
          <button
            type="button"
            onClick={() => setFilterMode('PREMIUM')}
            className={`px-3 py-1.5 rounded-xl text-xs font-black transition-all flex items-center gap-1.5 cursor-pointer ${
              filterMode === 'PREMIUM'
                ? 'bg-amber-500 text-white shadow-xs'
                : 'bg-amber-500/10 text-amber-700 dark:text-amber-400 border border-amber-500/20 hover:bg-amber-500/20'
            }`}
          >
            <span>✨</span> Premium Thermal ({premiumCount})
          </button>
          <button
            type="button"
            onClick={() => setFilterMode('COMBINED')}
            className={`px-3 py-1.5 rounded-xl text-xs font-black transition-all flex items-center gap-1.5 cursor-pointer ${
              filterMode === 'COMBINED'
                ? 'bg-purple-600 text-white shadow-xs'
                : 'bg-purple-500/10 text-purple-700 dark:text-purple-400 border border-purple-500/20 hover:bg-purple-500/20'
            }`}
          >
            <span>🔗</span> Combined ({combinedCount})
          </button>
        </div>
      </div>
      
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse text-xs">
          <thead>
            <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
              <th className="py-3 px-4">Order ID</th>
              <th className="py-3 px-4">Customer</th>
              <th className="py-3 px-4">Address</th>
              <th className="py-3 px-4">Total</th>
              <th className="py-3 px-4">Status</th>
              <th className="py-3 px-4">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border/40 font-semibold">
            {filteredOrders.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center py-10 text-text-secondary">
                  No {filterMode === 'PREMIUM' ? 'Premium Thermal Packaging' : filterMode === 'COMBINED' ? 'Combined' : ''} orders found.
                </td>
              </tr>
            ) : (
              filteredOrders.map((o) => (
                <tr key={o.id} className="hover:bg-muted/30">
                  <td className="py-3 px-4 font-mono font-bold text-[10px] max-w-[150px]">
                    <div className="font-extrabold text-text-primary text-xs">
                      #{o.readableId || (o.id.length > 12 ? o.id.slice(-6).toUpperCase() : o.id)}
                    </div>
                    {o.combinedId && (
                      <span className="text-[9px] font-black px-1.5 py-0.5 rounded bg-purple-500/15 text-purple-700 dark:text-purple-400 border border-purple-500/30 inline-flex items-center gap-1 mt-1">
                        🔗 Combined
                      </span>
                    )}
                    {(o.notes?.includes('Premium') || o.miscFee === 15 || o.miscFee === 20) && (
                      <span className="text-[9px] font-black px-2 py-0.5 rounded-full bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-500/30 inline-flex items-center gap-1 mt-1 animate-pulse shadow-2xs">
                        ✨ Premium Packaging (+₹15)
                      </span>
                    )}
                  </td>
                  <td className="py-3 px-4 truncate max-w-[150px]">
                    <div className="font-bold">{o.userName || 'No Name'}</div>
                    <div className="text-[10px] text-text-muted font-normal">{o.userEmail}</div>
                    {(o.userPhone || o.address?.phone) && (
                      <div className="text-[10px] text-text-secondary font-bold font-mono mt-0.5">
                        📞 {o.userPhone || o.address?.phone}
                      </div>
                    )}
                  </td>
                  <td className="py-3 px-4 max-w-[200px] truncate text-text-secondary font-medium" title={formatAddress(o.address)}>
                    <div className="flex items-center gap-1.5">
                      <span className="truncate">{formatAddress(o.address, false)}</span>
                      {o.address?.lat && o.address?.lng && (
                        <a
                          href={`https://www.google.com/maps/search/?api=1&query=${o.address.lat},${o.address.lng}`}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center justify-center p-1 rounded hover:bg-primary/10 text-primary transition-colors shrink-0 text-sm"
                          title="Open exact GPS coordinates on Google Maps"
                        >
                          📍
                        </a>
                      )}
                    </div>
                  </td>
                  <td className="py-3 px-4 font-bold text-text-primary">{formatPrice(o.total)}</td>
                  <td className="py-3 px-4">
                    <select
                      value={o.status}
                      onChange={(e) => handleSelectStatusChange(o, e.target.value)}
                      disabled={updatingId === o.id}
                      className="bg-muted px-2 py-1 rounded-lg border text-xs font-bold text-text-primary focus:outline-none cursor-pointer"
                    >
                      <option value="PENDING">Placed</option>
                      <option value="CONFIRMED">Confirmed</option>
                      <option value="PACKED">Packed</option>
                      <option value="SHIPPED">On the Way</option>
                      <option value="DELIVERED">Delivered</option>
                      <option value="CANCELLED">Cancelled</option>
                    </select>
                  </td>
                  <td className="py-3 px-4">
                    {updatingId === o.id ? (
                      <Loader2 className="h-4 w-4 animate-spin text-primary" />
                    ) : (
                      <Link
                        href={`/order/${o.id}/track`}
                        className="text-primary hover:underline text-[11px] font-bold"
                      >
                        Track
                      </Link>
                    )}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Cancel Order Confirmation Modal */}
      {cancelConfirmOrder && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-white dark:bg-zinc-900 border border-border rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center gap-3 text-rose-600 dark:text-rose-400">
              <div className="h-12 w-12 rounded-full bg-rose-500/10 flex items-center justify-center text-2xl shrink-0">
                ⚠️
              </div>
              <div>
                <h3 className="text-base font-black text-text-primary">
                  Cancel Order #{cancelConfirmOrder.readableId || cancelConfirmOrder.id.slice(0, 8)}?
                </h3>
                <p className="text-xs text-text-secondary font-medium">Are you sure you want to cancel this order?</p>
              </div>
            </div>

            <div className="bg-zinc-50 dark:bg-zinc-800/50 p-3.5 rounded-xl border border-border/60 text-xs space-y-1">
              <div className="flex justify-between text-text-secondary">
                <span>Customer:</span>
                <span className="font-bold text-text-primary">{cancelConfirmOrder.user?.name || cancelConfirmOrder.user?.email || 'Customer'}</span>
              </div>
              <div className="flex justify-between text-text-secondary">
                <span>Total Amount:</span>
                <span className="font-black text-emerald-600 dark:text-emerald-400">{formatPrice(cancelConfirmOrder.total)}</span>
              </div>
              <div className="flex justify-between text-text-secondary">
                <span>Payment Method:</span>
                <span className="font-bold text-text-primary">{cancelConfirmOrder.paymentMethod || 'COD'}</span>
              </div>
            </div>

            <p className="text-[11px] text-rose-600 dark:text-rose-400 font-semibold leading-relaxed bg-rose-500/5 border border-rose-500/20 p-2.5 rounded-xl">
              ⚠️ Warning: Cancelling will notify the customer and rider immediately. If paid online via Razorpay, please issue a refund from Razorpay Dashboard.
            </p>

            <div className="flex items-center justify-end gap-2.5 pt-2">
              <button
                type="button"
                onClick={() => setCancelConfirmOrder(null)}
                className="px-4 py-2 bg-zinc-100 dark:bg-zinc-800 hover:bg-zinc-200 dark:hover:bg-zinc-700 text-text-primary text-xs font-bold rounded-xl transition-all cursor-pointer"
              >
                No, Keep Order
              </button>
              <button
                type="button"
                onClick={() => {
                  const targetId = cancelConfirmOrder.id
                  setCancelConfirmOrder(null)
                  handleStatusChange(targetId, 'CANCELLED')
                }}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-black rounded-xl shadow-md shadow-rose-600/20 transition-all active:scale-95 cursor-pointer"
              >
                Yes, Cancel Order
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
