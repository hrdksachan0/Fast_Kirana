'use client'

import { useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  ArrowLeft,
  User,
  Smartphone,
  Barcode,
  Camera,
  Search,
  CircleDot,
  CheckCircle,
  Check,
  RotateCcw,
  Package,
  Loader2,
  Tag,
} from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { Order, getAisleNumber } from '@/hooks/picker/use-picker-types'
import { EditProductPriceModal, EditableGroceryProduct } from './edit-product-price-modal'

interface CircularProgressProps {
  picked: number
  total: number
}

function CircularProgress({ picked, total }: CircularProgressProps) {
  const pct = total === 0 ? 100 : Math.round((picked / total) * 100)
  const radius = 40
  const circumference = 2 * Math.PI * radius
  const strokeDashoffset = circumference - (pct / 100) * circumference

  return (
    <div className="relative flex items-center justify-center">
      <svg width="96" height="96" viewBox="0 0 96 96" className="-rotate-90">
        <circle
          cx="48"
          cy="48"
          r={radius}
          fill="none"
          stroke="currentColor"
          strokeWidth="6"
          className="text-gray-200"
        />
        <motion.circle
          cx="48"
          cy="48"
          r={radius}
          fill="none"
          stroke="url(#progressGradient)"
          strokeWidth="6"
          strokeLinecap="round"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset }}
          transition={{ duration: 0.7, ease: 'easeOut' }}
        />
        <defs>
          <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#2563eb" />
            <stop offset="100%" stopColor="#4f46e5" />
          </linearGradient>
        </defs>
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-lg font-black text-gray-800">
          {picked}/{total}
        </span>
        <span className="text-[9px] font-bold text-gray-400 uppercase tracking-wider">picked</span>
      </div>
    </div>
  )
}

interface SingleOrderPickerProps {
  activeOrder: Order
  setActiveOrder: (order: Order | null) => void
  pickedItemIds: Record<string, number>
  setPickedItemIds: React.Dispatch<React.SetStateAction<Record<string, number>>>
  scanInput: string
  setScanInput: (val: string) => void
  scanInputRef: React.RefObject<HTMLInputElement | null>
  startCamera: () => void
  handleManualPickOne: (itemId: string, maxQty: number) => void
  handleManualPickAll: (itemId: string, maxQty: number) => void
  handleResetItem: (itemId: string) => void
  handlePackOrder: () => void
  updatingId: string | null
}

export function SingleOrderPicker({
  activeOrder,
  setActiveOrder,
  pickedItemIds,
  setPickedItemIds,
  scanInput,
  setScanInput,
  scanInputRef,
  startCamera,
  handleManualPickOne,
  handleManualPickAll,
  handleResetItem,
  handlePackOrder,
  updatingId,
}: SingleOrderPickerProps) {
  const totalPickedCount = Object.values(pickedItemIds).reduce((s, v) => s + v, 0)
  const totalItemsCount = activeOrder.items.reduce((s, i) => s + i.quantity, 0)
  const isAllPicked = activeOrder.items.every(
    (item) => pickedItemIds[item.id] === item.quantity
  )

  const [editingProduct, setEditingProduct] = useState<EditableGroceryProduct | null>(null)
  const [isPriceModalOpen, setIsPriceModalOpen] = useState(false)

  const handleOpenPriceEdit = (item: any) => {
    setEditingProduct({
      id: item.product?.id || item.productId || item.id,
      name: item.name,
      mrp: item.product?.mrp || item.mrp || item.price,
      price: item.product?.price || item.price,
      stock: item.product?.stock ?? 20,
      unit: item.product?.unit || item.unit || '1 pc',
      imageUrl: item.imageUrl || item.product?.imageUrl,
      barcode: item.product?.barcode,
      location: item.product?.location,
      isAvailable: item.product?.isAvailable ?? true,
    })
    setIsPriceModalOpen(true)
  }

  const handleScanSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!scanInput.trim()) return

    const query = scanInput.trim().toLowerCase()
    const matchingItem = activeOrder.items.find((item) => {
      const slug = item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-')
      return slug.includes(query) || item.name.toLowerCase().includes(query)
    })

    if (matchingItem) {
      handleManualPickOne(matchingItem.id, matchingItem.quantity)
    }
    setScanInput('')
    if (scanInputRef.current) {
      scanInputRef.current.focus()
    }
  }

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-24">
      {/* Back and Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 p-4 sm:p-5 text-white shadow-lg shadow-blue-500/20"
      >
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC4wNCI+PHBhdGggZD0iTTM2IDM0djZoNnYtNmgtNnptMC0xMHY2aDZ2LTZoLTZ6bTEwIDEwdjZoNnYtNmgtNnptLTIwIDB2Nmg2di02aC02em0xMC0xMHY2aDZ2LTZoLTZ6bS0xMCAwdjZoNnYtNmgtNnoiLz48L2c+PC9nPjwvc3ZnPg==')] opacity-50" />
        <div className="relative flex justify-between items-center">
          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                setActiveOrder(null)
                setPickedItemIds({})
              }}
              className="flex items-center gap-1 text-xs font-bold text-white/90 hover:text-white transition-colors min-h-[44px] min-w-[44px] cursor-pointer"
            >
              <ArrowLeft className="h-4 w-4" />
              <span className="hidden sm:inline">Back to Queue</span>
            </button>
          </div>
          <span className="text-[10px] font-bold text-white/70 font-mono uppercase tracking-wider">
            #{activeOrder.readableId || activeOrder.id.slice(0, 8)}
          </span>
        </div>
        <div className="relative mt-3 flex flex-col gap-1.5">
          <div className="flex items-center gap-3">
            <User className="h-4 w-4 text-white/70" />
            <span className="text-sm font-bold">{activeOrder.user.name}</span>
          </div>
          {(activeOrder.user.phone || activeOrder.address?.phone) && (
            <div className="flex items-center gap-3 text-xs text-white/80 pl-7">
              <Smartphone className="h-3.5 w-3.5" />
              <a
                href={`tel:${activeOrder.address?.phone || activeOrder.user.phone}`}
                className="hover:underline font-mono"
              >
                {activeOrder.address?.phone || activeOrder.user.phone}
              </a>
            </div>
          )}
        </div>
      </motion.div>

      {/* Circular Progress */}
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.1 }}
        className="flex flex-col items-center py-2"
      >
        <CircularProgress picked={totalPickedCount} total={totalItemsCount} />
        <p className="mt-2 text-[10px] font-bold text-gray-400 uppercase tracking-wider">
          {isAllPicked
            ? '✅ All items picked!'
            : `${
                activeOrder.items.filter(
                  (item) => (pickedItemIds[item.id] || 0) < item.quantity
                ).length
              } item(s) remaining`}
        </p>
      </motion.div>

      {/* Companion Cafe Order Info */}
      <AnimatePresence>
        {activeOrder.companionOrder && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="bg-gradient-to-r from-rose-50 to-orange-50 border border-orange-200/60 p-4 rounded-2xl shadow-sm space-y-2.5"
          >
            <div className="flex items-center justify-between">
              <span className="text-xs font-black text-rose-600 flex items-center gap-1">
                <span>☕</span> Companion Cafe Order
              </span>
              <span
                className={`text-[10px] font-black px-2 py-0.5 rounded uppercase ${
                  activeOrder.companionOrder.status === 'PACKED' ||
                  activeOrder.companionOrder.status === 'SHIPPED' ||
                  activeOrder.companionOrder.status === 'DELIVERED'
                    ? 'bg-green-100 text-green-700'
                    : 'bg-orange-100 text-orange-700'
                }`}
              >
                <span className="inline-flex items-center gap-1">
                  {!(
                    activeOrder.companionOrder.status === 'PACKED' ||
                    activeOrder.companionOrder.status === 'SHIPPED' ||
                    activeOrder.companionOrder.status === 'DELIVERED'
                  ) && (
                    <span className="relative flex h-1.5 w-1.5">
                      <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75" />
                      <span className="relative inline-flex rounded-full h-1.5 w-1.5 bg-orange-500" />
                    </span>
                  )}
                  {activeOrder.companionOrder.status === 'CONFIRMED'
                    ? 'PREPARING'
                    : activeOrder.companionOrder.status}
                </span>
              </span>
            </div>
            <p className="text-[10px] text-gray-500 leading-normal font-semibold">
              Placed in the same checkout. Kitchen is preparing these items:
            </p>
            <div className="bg-white/80 border border-orange-100/50 rounded-xl p-2.5 divide-y divide-orange-100/30">
              {activeOrder.companionOrder.items.map((item) => (
                <div
                  key={item.id}
                  className="flex justify-between items-center text-[10px] font-bold py-1 first:pt-0 last:pb-0 text-gray-700"
                >
                  <span>{item.name}</span>
                  <span className="bg-orange-50 px-1.5 py-0.5 rounded text-rose-600">
                    Qty: {item.quantity}
                  </span>
                </div>
              ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Scan Barcode Form */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.15 }}
        className="bg-white border border-gray-200/80 p-4 sm:p-5 rounded-2xl shadow-sm space-y-3"
      >
        <div className="flex justify-between items-center">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-gray-400 flex items-center gap-1.5">
            <Barcode className="h-4 w-4 text-blue-500" />
            Product Scan Simulator
          </label>
          <button
            onClick={startCamera}
            className="text-xs font-black text-blue-600 hover:text-blue-700 flex items-center gap-1 transition-colors cursor-pointer"
          >
            <Camera className="h-3.5 w-3.5" /> Use Camera Scanner
          </button>
        </div>

        <form onSubmit={handleScanSubmit} className="flex gap-2">
          <div className="relative flex-1 group">
            <input
              ref={scanInputRef}
              type="text"
              placeholder="Scan barcode or type product name…"
              value={scanInput}
              onChange={(e) => setScanInput(e.target.value)}
              className="w-full bg-gray-50 border-2 border-gray-200 px-3 sm:px-4 py-2.5 sm:py-3 rounded-xl text-xs sm:text-sm focus:outline-none focus:border-blue-500 focus:bg-white font-semibold transition-all placeholder:text-gray-300"
            />
          </div>
          <button
            type="submit"
            className="bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white text-xs font-bold px-4 sm:px-5 py-2.5 sm:py-3 rounded-xl transition-all flex items-center gap-1.5 cursor-pointer min-h-[44px] shadow-md shadow-blue-500/20 active:scale-95"
          >
            <Search className="h-4 w-4" />
            <span className="hidden sm:inline">Scan</span>
          </button>
        </form>
        <p className="text-[9px] text-gray-400 font-semibold leading-relaxed">
          💡 Type product name keywords (like &quot;Banana&quot;, &quot;Milk&quot;, or &quot;Dal&quot;) and press Enter to scan.
        </p>
      </motion.div>

      {/* Remaining to Pick Checklist */}
      <div className="space-y-3">
        <h3 className="text-xs font-black text-gray-700 uppercase tracking-wider flex items-center gap-1.5">
          <CircleDot className="h-3.5 w-3.5 text-blue-500" />
          Remaining Items (
          {
            activeOrder.items.filter((item) => (pickedItemIds[item.id] || 0) < item.quantity)
              .length
          }
          )
        </h3>

        <AnimatePresence mode="popLayout">
          {activeOrder.items.filter((item) => (pickedItemIds[item.id] || 0) < item.quantity)
            .length === 0 ? (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-gradient-to-br from-green-50 to-emerald-50 border border-green-200/60 text-green-700 text-xs font-bold p-6 rounded-2xl text-center space-y-2"
            >
              <motion.div
                animate={{ scale: [1, 1.15, 1] }}
                transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
              >
                <CheckCircle className="h-8 w-8 text-green-500 mx-auto" />
              </motion.div>
              <p>All items checked off successfully! Ready to Pack.</p>
            </motion.div>
          ) : (
            [...activeOrder.items]
              .sort((a, b) => {
                const locA = a.product?.location
                const locB = b.product?.location
                if (locA && locB) return locA.localeCompare(locB)
                if (locA) return -1
                if (locB) return 1
                const slugA = a.product?.category?.slug || ''
                const slugB = b.product?.category?.slug || ''
                return getAisleNumber(slugA) - getAisleNumber(slugB)
              })
              .filter((item) => (pickedItemIds[item.id] || 0) < item.quantity)
              .map((item, idx) => {
                const picked = pickedItemIds[item.id] || 0
                const progress = (picked / item.quantity) * 100
                return (
                  <motion.div
                    key={item.id}
                    layoutId={item.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    exit={{ opacity: 0, x: -30, scale: 0.95 }}
                    transition={{
                      type: 'spring',
                      damping: 20,
                      stiffness: 200,
                      delay: idx * 0.04,
                    }}
                    className="relative overflow-hidden bg-white border border-gray-200/80 p-3 sm:p-4 rounded-xl shadow-sm hover:shadow-md transition-shadow"
                  >
                    <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-500 rounded-l-xl" />

                    <div className="flex items-center justify-between gap-3 pl-2">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="h-10 w-10 sm:h-11 sm:w-11 bg-gray-50 rounded-lg flex-shrink-0 flex items-center justify-center overflow-hidden border border-gray-100">
                          <ProductImage
                            src={item.imageUrl}
                            alt={item.name}
                            className="h-full w-full object-contain"
                          />
                        </div>
                        <div className="min-w-0">
                          <div className="flex items-center gap-2 flex-wrap">
                            <h4 className="text-xs sm:text-sm font-extrabold text-gray-800 truncate">
                              {item.name}
                            </h4>
                            {item.product?.location && (
                              <span className="px-1.5 py-0.5 bg-amber-50 text-amber-600 border border-amber-200 rounded text-[9px] font-black uppercase shadow-sm">
                                📍 {item.product.location}
                              </span>
                            )}
                          </div>

                          <div className="flex items-center gap-2 mt-1">
                            <span className="text-[10px] text-gray-400 font-bold">
                              {picked}/{item.quantity}
                            </span>
                            <div className="w-16 h-1.5 bg-gray-100 rounded-full overflow-hidden">
                              <motion.div
                                className="h-full bg-gradient-to-r from-blue-500 to-indigo-500 rounded-full"
                                initial={{ width: 0 }}
                                animate={{ width: `${progress}%` }}
                                transition={{ duration: 0.3 }}
                              />
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="flex gap-1.5 shrink-0">
                        <motion.button
                          whileTap={{ scale: 0.85 }}
                          onClick={() => handleOpenPriceEdit(item)}
                          className="bg-orange-50 hover:bg-orange-100 text-orange-600 text-[10px] sm:text-xs font-black min-h-[44px] px-2.5 rounded-xl border border-orange-200/60 cursor-pointer transition-colors flex items-center gap-1"
                          title="Edit Grocery Price"
                        >
                          <Tag className="h-3.5 w-3.5" />
                          <span className="hidden sm:inline">₹ Price</span>
                        </motion.button>
                        <motion.button
                          whileTap={{ scale: 0.85 }}
                          onClick={() => handleManualPickOne(item.id, item.quantity)}
                          className="bg-gray-100 hover:bg-gray-200 text-gray-600 text-[10px] sm:text-xs font-bold min-h-[44px] min-w-[44px] flex items-center justify-center rounded-xl border border-gray-200 cursor-pointer transition-colors"
                        >
                          +1
                        </motion.button>
                        <motion.button
                          whileTap={{ scale: 0.85 }}
                          onClick={() => handleManualPickAll(item.id, item.quantity)}
                          className="bg-blue-50 text-blue-600 hover:bg-blue-100 text-[10px] sm:text-xs font-black min-h-[44px] px-3 rounded-xl border border-blue-200/60 cursor-pointer transition-colors flex items-center gap-1"
                        >
                          <Check className="h-3.5 w-3.5 stroke-[3]" />
                          <span className="hidden sm:inline">All</span>
                        </motion.button>
                      </div>
                    </div>
                  </motion.div>
                )
              })
          )}
        </AnimatePresence>
      </div>

      {/* Picked Checklist */}
      <AnimatePresence>
        {activeOrder.items.filter((item) => (pickedItemIds[item.id] || 0) === item.quantity)
          .length > 0 && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            className="space-y-3 pt-2"
          >
            <h3 className="text-xs font-black text-gray-400 uppercase tracking-wider flex items-center gap-1.5">
              <CheckCircle className="h-3.5 w-3.5 text-green-500" />
              Picked / Scanned (
              {
                activeOrder.items.filter(
                  (item) => (pickedItemIds[item.id] || 0) === item.quantity
                ).length
              }
              )
            </h3>

            <div className="space-y-2">
              {activeOrder.items
                .filter((item) => (pickedItemIds[item.id] || 0) === item.quantity)
                .map((item, idx) => (
                  <motion.div
                    key={item.id}
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 0.7, x: 0 }}
                    transition={{ delay: idx * 0.05 }}
                    className="relative overflow-hidden bg-green-50/50 border border-green-200/40 p-3 rounded-xl"
                  >
                    <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-green-400 to-emerald-500 rounded-l-xl" />
                    <div className="flex items-center justify-between gap-3 pl-2">
                      <div className="flex items-center gap-3 min-w-0">
                        <div className="h-8 w-8 bg-green-100 rounded-lg flex-shrink-0 flex items-center justify-center text-green-600">
                          <Check className="h-4 w-4 stroke-[3]" />
                        </div>
                        <div className="min-w-0 line-through text-gray-400">
                          <h4 className="text-[11px] font-bold truncate">{item.name}</h4>
                          <span className="text-[9px] font-medium block mt-0.5">
                            {item.quantity}/{item.quantity} picked
                          </span>
                        </div>
                      </div>

                      <button
                        onClick={() => handleResetItem(item.id)}
                        className="flex items-center gap-1 text-[9px] font-bold text-red-400 hover:text-red-500 cursor-pointer min-h-[44px] min-w-[44px] justify-center transition-colors"
                      >
                        <RotateCcw className="h-3 w-3" />
                        Reset
                      </button>
                    </div>
                  </motion.div>
                ))}
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Packing submit button */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2 }}
        className="pt-4 border-t border-gray-200/60"
      >
        <motion.button
          whileTap={isAllPicked ? { scale: 0.97 } : {}}
          onClick={handlePackOrder}
          disabled={!isAllPicked || updatingId === activeOrder.id}
          className={`h-12 sm:h-14 w-full rounded-2xl font-black text-xs sm:text-sm transition-all flex items-center justify-center gap-2 cursor-pointer ${
            isAllPicked
              ? 'bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white shadow-lg shadow-green-500/30'
              : 'bg-gray-100 text-gray-400 border border-gray-200 cursor-not-allowed opacity-60'
          }`}
        >
          {updatingId === activeOrder.id ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Packing Order...
            </>
          ) : (
            <>
              <Package className="h-4 w-4" />
              Confirm &amp; Pack Order
            </>
          )}
        </motion.button>
      </motion.div>

      {/* Edit Product Price Modal */}
      <EditProductPriceModal
        isOpen={isPriceModalOpen}
        onClose={() => setIsPriceModalOpen(false)}
        product={editingProduct}
      />
    </div>
  )
}
