'use client'

import { motion, AnimatePresence } from 'framer-motion'

interface BinPlacementAlertProps {
  justPickedItem: {
    name: string
    binName: string
    binColorClass: string
  } | null
}

export function BinPlacementAlert({ justPickedItem }: BinPlacementAlertProps) {
  return (
    <AnimatePresence>
      {justPickedItem && (
        <motion.div
          initial={{ opacity: 0, scale: 0.9, y: 30 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.9, y: -20 }}
          className="fixed top-12 left-4 right-4 z-[110] max-w-sm mx-auto shadow-2xl"
        >
          <div
            className={`rounded-2xl border p-4 backdrop-blur flex items-center gap-3.5 ${justPickedItem.binColorClass} border-current/25 shadow-lg`}
          >
            <div className="h-10 w-10 rounded-xl bg-white flex items-center justify-center text-lg shadow-sm shrink-0">
              📥
            </div>
            <div className="min-w-0">
              <span className="text-[9px] font-black uppercase tracking-wider opacity-60 block">
                Put item in bin:
              </span>
              <span className="text-lg font-black block leading-tight">
                {justPickedItem.binName}
              </span>
              <span className="text-[11px] font-bold block truncate mt-0.5 opacity-90">
                {justPickedItem.name}
              </span>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
