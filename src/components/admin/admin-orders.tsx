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
    <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
      <h3 className="font-extrabold text-text-primary text-base mb-4">Manage Orders</h3>
      
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
            {orders.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center py-10 text-text-secondary">
                  No orders found.
                </td>
              </tr>
            ) : (
              orders.map((o) => (
                <tr key={o.id} className="hover:bg-muted/30">
                  <td className="py-3 px-4 font-mono font-bold text-[10px] truncate max-w-[120px]">{o.id}</td>
                  <td className="py-3 px-4 truncate max-w-[150px]">{o.userName || o.userEmail}</td>
                  <td className="py-3 px-4 max-w-[200px] truncate text-text-secondary font-medium" title={formatAddress(o.address)}>
                    {formatAddress(o.address, false)}
                  </td>
                  <td className="py-3 px-4 font-bold text-text-primary">{formatPrice(o.total)}</td>
                  <td className="py-3 px-4">
                    <select
                      value={o.status}
                      onChange={(e) => handleStatusChange(o.id, e.target.value)}
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
    </div>
  )
}
