'use client'

import { motion, AnimatePresence } from 'framer-motion'
import { Camera } from 'lucide-react'

interface CameraScannerOverlayProps {
  isCameraScanning: boolean
  stopCamera: () => void
  videoRef: React.RefObject<HTMLVideoElement | null>
}

export function CameraScannerOverlay({
  isCameraScanning,
  stopCamera,
  videoRef,
}: CameraScannerOverlayProps) {
  return (
    <AnimatePresence>
      {isCameraScanning && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-[100] bg-black/80 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <motion.div
            initial={{ scale: 0.95, y: 20 }}
            animate={{ scale: 1, y: 0 }}
            exit={{ scale: 0.95, y: 20 }}
            className="bg-zinc-900 border border-zinc-800 text-white rounded-3xl p-5 w-full max-w-sm flex flex-col items-center space-y-4"
          >
            <div className="text-center w-full flex justify-between items-center pb-2 border-b border-zinc-800">
              <span className="text-xs font-extrabold tracking-wider text-blue-400 flex items-center gap-1.5">
                <Camera className="h-4 w-4" /> BARCODE SCANNER
              </span>
              <button
                onClick={stopCamera}
                className="text-xs text-zinc-400 hover:text-white font-bold cursor-pointer"
              >
                Close
              </button>
            </div>

            {/* Camera view screen */}
            <div className="relative w-full h-[240px] rounded-2xl overflow-hidden bg-black border border-zinc-800 flex items-center justify-center">
              <video
                ref={videoRef}
                autoPlay
                playsInline
                className="w-full h-full object-cover"
              />

              {/* Scanner targeting laser line */}
              <div
                className="absolute left-4 right-4 h-0.5 bg-red-500 shadow-[0_0_8px_rgba(239,68,68,0.8)] animate-pulse"
                style={{ top: '50%' }}
              />

              {/* Simulated frame */}
              <div className="absolute inset-8 border border-white/20 rounded-xl pointer-events-none flex items-center justify-center">
                <span className="text-[10px] text-white/50 font-bold bg-black/40 px-2 py-0.5 rounded">
                  Center Barcode
                </span>
              </div>
            </div>

            <div className="text-center w-full">
              <p className="text-[11px] font-bold text-zinc-400 animate-pulse">
                Hold barcode up to camera...
              </p>
              <p className="text-[9px] text-zinc-500/80 mt-1 font-semibold">
                (Automatically scanning remaining items every 2.5 seconds)
              </p>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  )
}
