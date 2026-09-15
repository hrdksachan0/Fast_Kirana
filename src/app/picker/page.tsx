'use client'

import { useEffect } from 'react'
import { useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'

// Hooks
import { usePickerRealtime } from '@/hooks/picker/use-picker-realtime'
import { useBarcodeScanner } from '@/hooks/picker/use-barcode-scanner'
import { usePickerState } from '@/hooks/picker/use-picker-state'

// Components
import { CameraScannerOverlay } from '@/app/picker/components/camera-scanner-overlay'
import { BinPlacementAlert } from '@/app/picker/components/bin-placement-alert'
import { MultiOrderConsole } from '@/app/picker/components/multi-order-console'
import { SingleOrderPicker } from '@/app/picker/components/single-order-picker'
import { PickerQueueList } from '@/app/picker/components/picker-queue-list'

export default function PickerDashboard() {
  const { data: session, status } = useSession()
  const router = useRouter()

  // 1. Scanner & Audio Beep Hook
  const {
    isCameraScanning,
    startCamera,
    stopCamera,
    scanInput,
    setScanInput,
    scanInputRef,
    videoRef,
    playBeep,
  } = useBarcodeScanner()

  // 2. Picker Domain State Hook
  const picker = usePickerState({
    orders: [], // populated by realtime hook
    fetchOrders: async () => {}, // wired via realtime hook below
    playBeep,
  })

  const {
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
  } = picker

  // 3. Realtime Queue & Clock Hook
  const {
    orders,
    isLoading,
    isRefreshing,
    currentTime,
    refreshProgress,
    fetchOrders,
  } = usePickerRealtime({
    activeOrderRef,
    setActiveOrder,
    setPickedItemIds,
    isMultiPickingModeRef,
    multiActiveOrdersRef,
    setMultiActiveOrders,
    setMultiPickedItemIds,
    updatingIdRef,
  })

  // Auth Guard
  useEffect(() => {
    if (status === 'unauthenticated') {
      router.push('/login?callbackUrl=/picker')
    } else if (
      status === 'authenticated' &&
      session?.user?.role !== 'PICKER' &&
      session?.user?.role !== 'ADMIN'
    ) {
      router.push('/')
    }
  }, [status, session, router])

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-50 via-white to-blue-50/30">
      {/* Dynamic Camera Scanner Overlay */}
      <CameraScannerOverlay
        isCameraScanning={isCameraScanning}
        stopCamera={stopCamera}
        videoRef={videoRef}
      />

      {/* Bin Assignment Notification Alert */}
      <BinPlacementAlert justPickedItem={justPickedItem} />

      {/* SCENARIO A: Multi-Order Batch Picking Console */}
      {isMultiPickingMode ? (
        <MultiOrderConsole
          multiActiveOrders={multiActiveOrders}
          setMultiActiveOrders={setMultiActiveOrders}
          setIsMultiPickingMode={setIsMultiPickingMode}
          binColors={binColors}
          multiPickedItemIds={multiPickedItemIds}
          consolidatedItems={consolidatedItems}
          startCamera={startCamera}
          handleMultiPickOne={handleMultiPickOne}
          handleMultiPickAll={handleMultiPickAll}
          handlePackMultiOrder={handlePackMultiOrder}
          updatingId={updatingId}
        />
      ) : activeOrder ? (
        /* SCENARIO B: Single Order Active Picking Screen */
        <SingleOrderPicker
          activeOrder={activeOrder}
          setActiveOrder={setActiveOrder}
          pickedItemIds={pickedItemIds}
          setPickedItemIds={setPickedItemIds}
          scanInput={scanInput}
          setScanInput={setScanInput}
          scanInputRef={scanInputRef}
          startCamera={startCamera}
          handleManualPickOne={handleManualPickOne}
          handleManualPickAll={handleManualPickAll}
          handleResetItem={handleResetItem}
          handlePackOrder={handlePackOrder}
          updatingId={updatingId}
        />
      ) : (
        /* SCENARIO C: Main Queue Screen */
        <PickerQueueList
          orders={orders}
          currentTime={currentTime}
          refreshProgress={refreshProgress}
          isRefreshing={isRefreshing}
          fetchOrders={fetchOrders}
          pickedToday={pickedToday}
          selectedOrderIds={selectedOrderIds}
          setSelectedOrderIds={setSelectedOrderIds}
          userName={session?.user?.name}
          userId={session?.user?.id}
          handleStartPicking={handleStartPicking}
          setActiveOrder={setActiveOrder}
          setPickedItemIds={setPickedItemIds}
          updatingId={updatingId}
        />
      )}

      {/* Sticky Bottom Bar for Multi-picking Launch */}
      {selectedOrderIds.length > 0 && !activeOrder && !isMultiPickingMode && (
        <div className="fixed bottom-20 left-4 right-4 z-40 bg-slate-900 border border-slate-800 text-white rounded-2xl p-3 shadow-2xl flex items-center justify-between animate-slide-up">
          <div className="flex items-center gap-2 pl-2">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
            <span className="text-xs font-bold">
              {selectedOrderIds.length} order{selectedOrderIds.length !== 1 ? 's' : ''} selected
            </span>
          </div>
          <button
            onClick={handleStartMultiPicking}
            className="bg-blue-600 hover:bg-blue-700 text-white text-xs font-black px-4 py-2.5 rounded-xl cursor-pointer transition-colors active:scale-95 shadow-md shadow-blue-500/10"
          >
            Start Multi-Picking
          </button>
        </div>
      )}
    </div>
  )
}
