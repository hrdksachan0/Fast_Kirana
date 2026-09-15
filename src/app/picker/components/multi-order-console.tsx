'use client'

import { motion } from 'framer-motion'
import { Layers, Barcode, Camera, Check, Package } from 'lucide-react'
import { ProductImage } from '@/components/product/product-image'
import { Order, BinConfig, BIN_CONFIGS, getAisleNumber, getAisleName } from '@/hooks/picker/use-picker-types'

interface MultiOrderConsoleProps {
  multiActiveOrders: Order[]
  setMultiActiveOrders: (orders: Order[]) => void
  setIsMultiPickingMode: (val: boolean) => void
  binColors: Record<string, BinConfig>
  multiPickedItemIds: Record<string, Record<string, number>>
  consolidatedItems: any[]
  startCamera: () => void
  handleMultiPickOne: (productId: string) => void
  handleMultiPickAll: (productId: string) => void
  handlePackMultiOrder: (orderId: string) => void
  updatingId: string | null
}

export function MultiOrderConsole({
  multiActiveOrders,
  setMultiActiveOrders,
  setIsMultiPickingMode,
  binColors,
  multiPickedItemIds,
  consolidatedItems,
  startCamera,
  handleMultiPickOne,
  handleMultiPickAll,
  handlePackMultiOrder,
  updatingId,
}: MultiOrderConsoleProps) {
  const aisles: Record<number, typeof consolidatedItems> = {}
  consolidatedItems.forEach((item) => {
    const aisleNo = getAisleNumber(item.categorySlug)
    if (!aisles[aisleNo]) aisles[aisleNo] = []
    aisles[aisleNo].push(item)
  })

  return (
    <div className="container mx-auto px-3 sm:px-4 py-4 sm:py-6 max-w-lg space-y-4 sm:space-y-5 pb-32">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        className="relative overflow-hidden rounded-2xl bg-slate-900 p-4 sm:p-5 text-white shadow-lg border border-slate-800"
      >
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Layers className="h-5 w-5 text-blue-500" />
            <h1 className="text-sm sm:text-base font-black tracking-tight">Multi-Pick Console</h1>
          </div>
          <button
            onClick={() => {
              if (
                confirm(
                  'Cancel multi-picking console? In-progress order states will be preserved.'
                )
              ) {
                setIsMultiPickingMode(false)
                setMultiActiveOrders([])
              }
            }}
            className="text-[10px] font-extrabold text-red-400 hover:text-red-300 transition-colors cursor-pointer min-h-[44px] px-2"
          >
            Exit Console
          </button>
        </div>

        {/* Active Bins List */}
        <div className="mt-3.5 grid grid-cols-3 gap-2">
          {multiActiveOrders.map((ord) => {
            const bin = binColors[ord.id] || BIN_CONFIGS[0]
            const itemsCount = ord.items.reduce((s, itm) => s + itm.quantity, 0)
            const itemsPicked = ord.items.reduce((s, itm) => {
              const oMap = multiPickedItemIds[ord.id] || {}
              return s + (oMap[itm.id] || 0)
            }, 0)

            return (
              <div
                key={ord.id}
                className={`rounded-xl border p-2 flex flex-col justify-between ${bin.bg}`}
              >
                <div>
                  <span className="text-[9px] font-black uppercase tracking-wider block">
                    {bin.name}
                  </span>
                  <span className="text-[8px] font-bold block opacity-60 truncate mt-0.5">
                    {ord.user.name}
                  </span>
                </div>
                <div className="mt-2 flex items-baseline gap-0.5">
                  <span className="text-sm font-black">{itemsPicked}</span>
                  <span className="text-[9px] font-bold opacity-60">/{itemsCount}</span>
                </div>
              </div>
            )
          })}
        </div>
      </motion.div>

      {/* Camera Scan Trigger */}
      <motion.div
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white border border-gray-200/80 p-4 rounded-2xl shadow-sm flex items-center justify-between"
      >
        <div className="space-y-0.5">
          <h3 className="text-xs font-black text-gray-700 flex items-center gap-1.5 uppercase tracking-wider">
            <Barcode className="h-4 w-4 text-blue-500" /> Camera Scanner
          </h3>
          <p className="text-[9px] text-gray-400 font-semibold leading-relaxed">
            Scan barcodes using your mobile camera to verify bins.
          </p>
        </div>
        <button
          onClick={startCamera}
          className="bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-xs font-black px-4 py-2.5 rounded-xl flex items-center gap-1.5 cursor-pointer shadow-md shadow-blue-500/15 active:scale-95 transition-all"
        >
          <Camera className="h-3.5 w-3.5" /> Open Camera
        </button>
      </motion.div>

      {/* Consolidated Picking List grouped by Aisle */}
      <div className="space-y-4">
        <h2 className="text-xs font-black text-gray-400 uppercase tracking-wider px-1">
          Consolidated Picking Checklist
        </h2>

        {Object.keys(aisles)
          .sort()
          .map((aisleStr) => {
            const aisleNo = parseInt(aisleStr, 10)
            const itemsList = aisles[aisleNo]
            const description = getAisleName(aisleNo)

            return (
              <div key={aisleNo} className="space-y-2.5">
                <div className="flex items-center gap-2 px-1">
                  <span className="text-xs font-black text-blue-600 bg-blue-50 px-2.5 py-1 rounded-lg">
                    Aisle {aisleNo}
                  </span>
                  <span className="text-[10px] text-gray-500 font-bold">{description}</span>
                </div>

                <div className="space-y-2">
                  {itemsList.map((item) => {
                    const allCompleted = item.totalPicked === item.totalNeeded
                    return (
                      <div
                        key={item.productId}
                        className={`bg-white border border-gray-200/80 p-3 sm:p-4 rounded-xl shadow-sm relative overflow-hidden ${
                          allCompleted ? 'opacity-50' : ''
                        }`}
                      >
                        <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-blue-500 to-indigo-500 rounded-l-xl" />

                        <div className="flex items-center justify-between gap-3 pl-2">
                          <div className="flex items-center gap-3 min-w-0">
                            <div className="h-10 w-10 bg-gray-50 rounded-lg flex-shrink-0 flex items-center justify-center overflow-hidden border border-gray-100">
                              <ProductImage
                                src={item.imageUrl}
                                alt={item.name}
                                className="h-full w-full object-contain"
                              />
                            </div>
                            <div className="min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <h4 className="text-xs sm:text-sm font-extrabold text-gray-800 truncate leading-tight">
                                  {item.name}
                                </h4>
                                {item.location && (
                                  <span className="px-1.5 py-0.5 bg-amber-50 text-amber-600 border border-amber-200 rounded text-[9px] font-black uppercase shadow-sm">
                                    📍 {item.location}
                                  </span>
                                )}
                              </div>

                              {/* Bin Placement list */}
                              <div className="flex flex-wrap gap-1.5 mt-1.5">
                                {item.placements.map((p: any, i: number) => (
                                  <span
                                    key={i}
                                    className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[8px] font-black uppercase ${p.binInfo.bg}`}
                                  >
                                    <span className={`h-1.5 w-1.5 rounded-full ${p.binInfo.fill}`} />
                                    {p.binInfo.name}: {p.quantityPicked}/{p.quantityNeeded}
                                  </span>
                                ))}
                              </div>
                            </div>
                          </div>

                          {/* Pick actions */}
                          {!allCompleted && (
                            <div className="flex gap-1.5 shrink-0">
                              <button
                                onClick={() => handleMultiPickOne(item.productId)}
                                className="bg-gray-100 hover:bg-gray-200 text-gray-600 text-[10px] sm:text-xs font-bold min-h-[38px] px-2.5 flex items-center justify-center rounded-xl border border-gray-200 cursor-pointer transition-colors"
                              >
                                +1
                              </button>
                              <button
                                onClick={() => handleMultiPickAll(item.productId)}
                                className="bg-blue-50 text-blue-600 hover:bg-blue-100 text-[10px] sm:text-xs font-black min-h-[38px] px-2.5 rounded-xl border border-blue-200/60 cursor-pointer transition-colors flex items-center gap-1"
                              >
                                <Check className="h-3 w-3 stroke-[3]" />
                                <span>All</span>
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    )
                  })}
                </div>
              </div>
            )
          })}
      </div>

      {/* Packing Actions Sticky Footer */}
      <div className="fixed bottom-0 left-0 right-0 z-50 bg-white/80 dark:bg-zinc-950/80 backdrop-blur-md border-t border-border p-4 shadow-lg flex flex-col gap-2">
        {multiActiveOrders.map((order) => {
          const bin = binColors[order.id] || BIN_CONFIGS[0]
          const orderPicked = multiPickedItemIds[order.id] || {}
          const isOrderComplete = order.items.every(
            (itm) => (orderPicked[itm.id] || 0) === itm.quantity
          )

          return (
            <button
              key={order.id}
              onClick={() => handlePackMultiOrder(order.id)}
              disabled={!isOrderComplete || updatingId === order.id}
              className={`h-11 w-full rounded-xl font-black text-xs flex items-center justify-center gap-2 cursor-pointer transition-all border ${
                isOrderComplete
                  ? 'bg-slate-900 text-white border-slate-800 hover:bg-slate-800 shadow-md active:scale-98'
                  : 'bg-gray-50 text-gray-300 border-gray-100 cursor-not-allowed opacity-60'
              }`}
            >
              <Package className="h-4 w-4" />
              <span>
                Pack {bin.name} ({order.user.name})
              </span>
              {isOrderComplete ? (
                <span className="text-[10px] bg-green-500 text-white px-2 py-0.5 rounded-full font-black uppercase ml-1 animate-pulse">
                  READY
                </span>
              ) : (
                <span className="text-[10px] font-bold text-gray-400 ml-1">IN-PROGRESS</span>
              )}
            </button>
          )
        })}
      </div>
    </div>
  )
}
