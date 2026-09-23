'use client'

import React from 'react'
import { motion } from 'framer-motion'
import { History, RotateCcw, Loader2 } from 'lucide-react'

export interface StockHistoryLog {
  id: string
  productId: string
  quantity: number
  type: 'INWARD_GRN' | 'RETAIL_POS' | 'ONLINE_ORDER' | 'MANUAL_ADJUST' | 'BULK_IMPORT'
  prevStock: number
  newStock: number
  createdAt: string
  product?: {
    name: string
    readableId: number
    barcode?: string
    unit: string
  }
}

interface InventoryHistoryTabProps {
  historyLogs: StockHistoryLog[]
  loadingHistory: boolean
  fetchHistory: () => void
}

export function InventoryHistoryTab({
  historyLogs,
  loadingHistory,
  fetchHistory,
}: InventoryHistoryTabProps) {
  return (
    <motion.div
      key="history-tab"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="space-y-6"
    >
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
        <div className="flex justify-between items-center gap-4">
          <div>
            <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
              <History className="h-5 w-5 text-accent" />
              Stock Audit Trail Logs
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Review all historic additions, sales, and bulk modifications of inventory.
            </p>
          </div>
          <button
            onClick={fetchHistory}
            disabled={loadingHistory}
            className="p-2 border border-border rounded-xl hover:bg-muted/50 cursor-pointer"
          >
            <RotateCcw
              className={`h-4 w-4 text-text-secondary ${loadingHistory ? 'animate-spin' : ''}`}
            />
          </button>
        </div>

        {loadingHistory && historyLogs.length === 0 ? (
          <div className="py-20 flex justify-center items-center">
            <Loader2 className="h-6 w-6 text-accent animate-spin" />
          </div>
        ) : historyLogs.length === 0 ? (
          <div className="py-20 text-center text-xs text-text-secondary">
            No stock transaction logs recorded yet.
          </div>
        ) : (
          <div className="space-y-4">
            <div className="overflow-x-auto border border-border rounded-xl">
              <table className="w-full text-left border-collapse text-[11px] font-semibold">
                <thead>
                  <tr className="bg-muted/50 border-b border-border text-text-secondary uppercase text-[8px] font-extrabold tracking-wider">
                    <th className="px-4 py-3.5">Date & Time</th>
                    <th className="px-4 py-3.5">Product Name</th>
                    <th className="px-4 py-3.5">Barcode / ID</th>
                    <th className="px-4 py-3.5 text-center">Change Qty</th>
                    <th className="px-4 py-3.5">Action Type</th>
                    <th className="px-4 py-3.5 text-right">Prev Stock</th>
                    <th className="px-4 py-3.5 text-right">New Stock</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {historyLogs.map((log) => {
                    const isPositive = log.quantity > 0
                    return (
                      <tr key={log.id} className="hover:bg-muted/10 transition-colors">
                        <td className="px-4 py-3 text-text-secondary">
                          {new Date(log.createdAt).toLocaleString('en-IN', {
                            day: 'numeric',
                            month: 'short',
                            hour: '2-digit',
                            minute: '2-digit',
                          })}
                        </td>
                        <td className="px-4 py-3 text-text-primary font-black">
                          {log.product?.name || 'Deleted Product'}
                        </td>
                        <td className="px-4 py-3 font-mono text-text-muted">
                          {log.product?.barcode ||
                            `FK${String(log.product?.readableId || '').padStart(6, '0')}`}
                        </td>
                        <td
                          className={`px-4 py-3 text-center font-black ${
                            isPositive ? 'text-emerald-500' : 'text-danger'
                          }`}
                        >
                          {isPositive ? `+${log.quantity}` : log.quantity} {log.product?.unit}
                        </td>
                        <td className="px-4 py-3">
                          <span
                            className={`px-2 py-0.5 rounded text-[9px] font-black uppercase border ${
                              log.type === 'INWARD_GRN'
                                ? 'bg-emerald-500/10 border-emerald-500/10 text-emerald-500'
                                : log.type === 'RETAIL_POS'
                                ? 'bg-amber-500/10 border-amber-500/10 text-amber-500'
                                : log.type === 'ONLINE_ORDER'
                                ? 'bg-blue-500/10 border-blue-500/10 text-blue-500'
                                : 'bg-indigo-500/10 border-indigo-500/10 text-indigo-500'
                            }`}
                          >
                            {log.type.replace('_', ' ')}
                          </span>
                        </td>
                        <td className="px-4 py-3 text-right text-text-muted">{log.prevStock}</td>
                        <td className="px-4 py-3 text-right text-text-primary font-bold">
                          {log.newStock}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </motion.div>
  )
}
