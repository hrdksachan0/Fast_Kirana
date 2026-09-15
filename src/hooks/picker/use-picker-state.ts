'use client'

import { useState, useRef, useEffect, useMemo, useCallback } from 'react'
import { toast } from 'sonner'
import {
  Order,
  BIN_CONFIGS,
  BinConfig,
  getAisleNumber,
} from './use-picker-types'

interface UsePickerStateProps {
  orders: Order[]
  fetchOrders: (silent?: boolean) => Promise<void>
  playBeep: () => void
}

export function usePickerState({ orders, fetchOrders, playBeep }: UsePickerStateProps) {
  const [activeOrder, setActiveOrder] = useState<Order | null>(null)
  const [pickedItemIds, setPickedItemIds] = useState<Record<string, number>>({}) // itemId -> pickedQty
  const [selectedOrderIds, setSelectedOrderIds] = useState<string[]>([])
  const [isMultiPickingMode, setIsMultiPickingMode] = useState(false)
  const [multiActiveOrders, setMultiActiveOrders] = useState<Order[]>([])
  const [multiPickedItemIds, setMultiPickedItemIds] = useState<
    Record<string, Record<string, number>>
  >({}) // orderId -> { itemId -> qty }
  const [binColors, setBinColors] = useState<Record<string, BinConfig>>({})
  const [justPickedItem, setJustPickedItem] = useState<{
    name: string
    binName: string
    binColorClass: string
  } | null>(null)
  const [updatingId, setUpdatingId] = useState<string | null>(null)
  const [pickedToday, setPickedToday] = useState(0)

  // State refs for stable callbacks
  const activeOrderRef = useRef<Order | null>(null)
  const isMultiPickingModeRef = useRef(false)
  const multiActiveOrdersRef = useRef<Order[]>([])
  const updatingIdRef = useRef<string | null>(null)

  useEffect(() => {
    activeOrderRef.current = activeOrder
  }, [activeOrder])

  useEffect(() => {
    isMultiPickingModeRef.current = isMultiPickingMode
  }, [isMultiPickingMode])

  useEffect(() => {
    multiActiveOrdersRef.current = multiActiveOrders
  }, [multiActiveOrders])

  useEffect(() => {
    updatingIdRef.current = updatingId
  }, [updatingId])

  const checkIfAllPicked = (newPicked: Record<string, number>, order: Order) => {
    return order.items.every((item) => newPicked[item.id] === item.quantity)
  }

  const autoPackOrder = useCallback(
    async (orderId: string) => {
      setUpdatingId(orderId)
      const toastId = toast.loading('📦 All items picked! Automatically packing order...')
      try {
        const res = await fetch(`/api/orders/${orderId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'PACKED' }),
        })

        if (res.ok) {
          toast.dismiss(toastId)
          toast.success('📦 Order packed automatically! Transferred to Rider queue.', {
            duration: 4000,
          })
          setPickedToday((prev) => prev + 1)
          setActiveOrder(null)
          setPickedItemIds({})
          fetchOrders(true)
        } else {
          toast.dismiss(toastId)
          toast.error('Failed to automatically pack order')
        }
      } catch (err) {
        toast.dismiss(toastId)
        toast.error('Error during auto-packing')
      } finally {
        setUpdatingId(null)
      }
    },
    [fetchOrders]
  )

  const handleStartPicking = useCallback(
    async (order: Order) => {
      setUpdatingId(order.id)
      try {
        const res = await fetch(`/api/orders/${order.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'CONFIRMED' }),
        })

        if (res.ok) {
          toast.success('Order status updated to Preparing (Picking)!')
          setActiveOrder(order)
          const initialPicked: Record<string, number> = {}
          order.items.forEach((item) => {
            initialPicked[item.id] = 0
          })
          setPickedItemIds(initialPicked)
          fetchOrders(true)
        } else {
          toast.error('Failed to accept order')
        }
      } catch (err) {
        toast.error('Error accepting order')
      } finally {
        setUpdatingId(null)
      }
    },
    [fetchOrders]
  )

  const handleManualPickOne = useCallback(
    (itemId: string, maxQty: number) => {
      if (!activeOrder) return
      const current = pickedItemIds[itemId] || 0
      if (current < maxQty) {
        const newPicked = {
          ...pickedItemIds,
          [itemId]: current + 1,
        }
        setPickedItemIds(newPicked)
        playBeep()
        if (checkIfAllPicked(newPicked, activeOrder)) {
          autoPackOrder(activeOrder.id)
        }
      }
    },
    [activeOrder, pickedItemIds, playBeep, autoPackOrder]
  )

  const handleManualPickAll = useCallback(
    (itemId: string, maxQty: number) => {
      if (!activeOrder) return
      const newPicked = {
        ...pickedItemIds,
        [itemId]: maxQty,
      }
      setPickedItemIds(newPicked)
      playBeep()
      toast.success('Item checked off manually', { duration: 1000 })
      if (checkIfAllPicked(newPicked, activeOrder)) {
        autoPackOrder(activeOrder.id)
      }
    },
    [activeOrder, pickedItemIds, playBeep, autoPackOrder]
  )

  const handleResetItem = useCallback(
    (itemId: string) => {
      setPickedItemIds((prev) => ({
        ...prev,
        [itemId]: 0,
      }))
    },
    []
  )

  const handlePackOrder = useCallback(async () => {
    if (!activeOrder) return
    autoPackOrder(activeOrder.id)
  }, [activeOrder, autoPackOrder])

  // Consolidated checklist sorted by Location / Aisle number
  const consolidatedItems = useMemo(() => {
    if (!isMultiPickingMode || multiActiveOrders.length === 0) return []

    const itemsMap: Record<
      string,
      {
        productId: string
        name: string
        imageUrl?: string
        unit: string
        categorySlug: string
        location?: string | null
        totalNeeded: number
        totalPicked: number
        placements: Array<{
          orderId: string
          itemId: string
          quantityNeeded: number
          quantityPicked: number
          binInfo: BinConfig
        }>
      }
    > = {}

    multiActiveOrders.forEach((order) => {
      const bin = binColors[order.id] || BIN_CONFIGS[0]
      const orderPicked = multiPickedItemIds[order.id] || {}

      order.items.forEach((item) => {
        const picked = orderPicked[item.id] || 0
        const catSlug = item.product?.category?.slug || ''

        if (!itemsMap[item.productId]) {
          itemsMap[item.productId] = {
            productId: item.productId,
            name: item.name,
            imageUrl: item.imageUrl,
            unit:
              item.name.toLowerCase().includes('gm') || item.name.toLowerCase().includes('kg')
                ? ''
                : 'pc',
            categorySlug: catSlug,
            location: item.product?.location || null,
            totalNeeded: 0,
            totalPicked: 0,
            placements: [],
          }
        }

        const entry = itemsMap[item.productId]
        entry.totalNeeded += item.quantity
        entry.totalPicked += picked
        entry.placements.push({
          orderId: order.id,
          itemId: item.id,
          quantityNeeded: item.quantity,
          quantityPicked: picked,
          binInfo: bin,
        })
      })
    })

    return Object.values(itemsMap).sort((a, b) => {
      if (a.location && b.location) {
        return a.location.localeCompare(b.location)
      }
      if (a.location) return -1
      if (b.location) return 1
      const aisleA = getAisleNumber(a.categorySlug)
      const aisleB = getAisleNumber(b.categorySlug)
      return aisleA - aisleB
    })
  }, [isMultiPickingMode, multiActiveOrders, binColors, multiPickedItemIds])

  const handleStartMultiPicking = useCallback(async () => {
    if (selectedOrderIds.length === 0) return
    try {
      const activeOrdersToSet: Order[] = []
      const initialMultiPicked: Record<string, Record<string, number>> = {}
      const assignedBins: Record<string, BinConfig> = {}

      for (let i = 0; i < selectedOrderIds.length; i++) {
        const orderId = selectedOrderIds[i]
        const order = orders.find((o) => o.id === orderId)
        if (order) {
          await fetch(`/api/orders/${order.id}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'CONFIRMED' }),
          })

          activeOrdersToSet.push(order)
          assignedBins[order.id] = BIN_CONFIGS[i % BIN_CONFIGS.length]

          const orderPicked: Record<string, number> = {}
          order.items.forEach((item) => {
            orderPicked[item.id] = 0
          })
          initialMultiPicked[order.id] = orderPicked
        }
      }

      setMultiActiveOrders(activeOrdersToSet)
      setBinColors(assignedBins)
      setMultiPickedItemIds(initialMultiPicked)
      setIsMultiPickingMode(true)
      setSelectedOrderIds([])
      toast.success(`Multi-Picking Console started for ${activeOrdersToSet.length} orders!`)
      fetchOrders(true)
    } catch (e) {
      toast.error('Failed to start multi-picking console')
    }
  }, [selectedOrderIds, orders, fetchOrders])

  const handleMultiPickOne = useCallback(
    (productId: string) => {
      const itemEntry = consolidatedItems.find((item) => item.productId === productId)
      if (!itemEntry) return

      const targetPlacement = itemEntry.placements.find((p) => p.quantityPicked < p.quantityNeeded)
      if (!targetPlacement) return

      const orderId = targetPlacement.orderId
      const itemId = targetPlacement.itemId
      const bin = targetPlacement.binInfo

      const orderPicked = { ...(multiPickedItemIds[orderId] || {}) }
      const currentPicked = orderPicked[itemId] || 0
      orderPicked[itemId] = currentPicked + 1

      const updatedMultiPicked = {
        ...multiPickedItemIds,
        [orderId]: orderPicked,
      }
      setMultiPickedItemIds(updatedMultiPicked)
      playBeep()

      setJustPickedItem({
        name: itemEntry.name,
        binName: bin.name,
        binColorClass: bin.bg,
      })

      setTimeout(() => {
        setJustPickedItem(null)
      }, 1500)

      const order = multiActiveOrders.find((o) => o.id === orderId)
      if (order) {
        const isOrderComplete = order.items.every(
          (itm) => (orderPicked[itm.id] || 0) === itm.quantity
        )
        if (isOrderComplete) {
          toast.success(`🎉 ${bin.name} fully picked! Ready to Pack.`, { duration: 3000 })
        }
      }
    },
    [consolidatedItems, multiPickedItemIds, multiActiveOrders, playBeep]
  )

  const handleMultiPickAll = useCallback(
    (productId: string) => {
      const itemEntry = consolidatedItems.find((item) => item.productId === productId)
      if (!itemEntry) return

      const updatedMultiPicked = { ...multiPickedItemIds }
      let lastBinName = ''
      let lastBinBg = ''

      itemEntry.placements.forEach((p) => {
        if (p.quantityPicked < p.quantityNeeded) {
          if (!updatedMultiPicked[p.orderId]) {
            updatedMultiPicked[p.orderId] = {}
          }
          updatedMultiPicked[p.orderId][p.itemId] = p.quantityNeeded
          lastBinName = p.binInfo.name
          lastBinBg = p.binInfo.bg
        }
      })

      setMultiPickedItemIds(updatedMultiPicked)
      playBeep()

      if (lastBinName) {
        setJustPickedItem({
          name: itemEntry.name,
          binName: lastBinName,
          binColorClass: lastBinBg,
        })
        setTimeout(() => setJustPickedItem(null), 1500)
      }
    },
    [consolidatedItems, multiPickedItemIds, playBeep]
  )

  const handlePackMultiOrder = useCallback(
    async (orderId: string) => {
      setUpdatingId(orderId)
      const toastId = toast.loading('📦 Packing order...')
      try {
        const res = await fetch(`/api/orders/${orderId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'PACKED' }),
        })

        if (res.ok) {
          toast.dismiss(toastId)
          toast.success(`📦 Order packed and assigned to Rider queue!`, { duration: 3000 })

          setMultiActiveOrders((prev) => prev.filter((o) => o.id !== orderId))

          const updatedPicked = { ...multiPickedItemIds }
          delete updatedPicked[orderId]
          setMultiPickedItemIds(updatedPicked)

          setPickedToday((prev) => prev + 1)

          if (multiActiveOrders.length <= 1) {
            setIsMultiPickingMode(false)
          }
          fetchOrders(true)
        } else {
          toast.dismiss(toastId)
          toast.error('Failed to pack order')
        }
      } catch (err) {
        toast.dismiss(toastId)
        toast.error('Error packing order')
      } finally {
        setUpdatingId(null)
      }
    },
    [multiActiveOrders.length, multiPickedItemIds, fetchOrders]
  )

  return {
    activeOrder,
    setActiveOrder,
    pickedItemIds,
    setPickedItemIds,
    selectedOrderIds,
    setSelectedOrderIds,
    isMultiPickingMode,
    setIsMultiPickingMode,
    multiActiveOrders,
    setMultiActiveOrders,
    multiPickedItemIds,
    setMultiPickedItemIds,
    binColors,
    justPickedItem,
    updatingId,
    pickedToday,
    consolidatedItems,
    activeOrderRef,
    isMultiPickingModeRef,
    multiActiveOrdersRef,
    updatingIdRef,
    handleStartPicking,
    handleManualPickOne,
    handleManualPickAll,
    handleResetItem,
    handlePackOrder,
    handleStartMultiPicking,
    handleMultiPickOne,
    handleMultiPickAll,
    handlePackMultiOrder,
  }
}
