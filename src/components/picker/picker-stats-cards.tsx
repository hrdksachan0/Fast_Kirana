'use client'

import { motion } from 'framer-motion'
import { ShoppingBag, ListChecks, TrendingUp } from 'lucide-react'

interface PickerStatsCardsProps {
  queueCount: number
  totalItemsToPick: number
  pickedToday: number
}

export function PickerStatsCards({
  queueCount,
  totalItemsToPick,
  pickedToday,
}: PickerStatsCardsProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.1 }}
      className="grid grid-cols-3 gap-2 sm:gap-3"
    >
      <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
        <ShoppingBag className="h-4 w-4 text-blue-500 mb-1.5" />
        <p className="text-lg sm:text-xl font-black">{queueCount}</p>
        <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">In Queue</p>
      </div>

      <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
        <ListChecks className="h-4 w-4 text-indigo-500 mb-1.5" />
        <p className="text-lg sm:text-xl font-black">{totalItemsToPick}</p>
        <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">Items</p>
      </div>

      <div className="relative overflow-hidden bg-white border border-gray-200/80 rounded-xl p-3 sm:p-3.5 shadow-sm">
        <TrendingUp className="h-4 w-4 text-green-500 mb-1.5" />
        <p className="text-lg sm:text-xl font-black">{pickedToday}</p>
        <p className="text-[8px] sm:text-[9px] font-bold text-gray-400 uppercase tracking-wider mt-0.5">Packed</p>
      </div>
    </motion.div>
  )
}
