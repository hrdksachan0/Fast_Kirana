'use client'

import { useState, useRef, useCallback } from 'react'
import { Camera, X, CheckCircle, RotateCcw, ImageIcon, Loader2 } from 'lucide-react'

interface PhotoCaptureProps {
  orderId: string
  onConfirm: (photoBase64: string) => void
  onCancel: () => void
  isSubmitting?: boolean
}

function compressImage(base64Str: string, maxWidth = 800, maxHeight = 800): Promise<string> {
  return new Promise((resolve) => {
    const img = new Image()
    img.src = base64Str
    img.onload = () => {
      const canvas = document.createElement('canvas')
      let width = img.width
      let height = img.height

      if (width > height) {
        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width)
          width = maxWidth
        }
      } else {
        if (height > maxHeight) {
          width = Math.round((width * maxHeight) / height)
          height = maxHeight
        }
      }

      canvas.width = width
      canvas.height = height

      const ctx = canvas.getContext('2d')
      if (ctx) {
        ctx.drawImage(img, 0, 0, width, height)
        const compressedBase64 = canvas.toDataURL('image/jpeg', 0.5)
        resolve(compressedBase64)
      } else {
        resolve(base64Str)
      }
    }
    img.onerror = () => {
      resolve(base64Str)
    }
  })
}

export default function PhotoCapture({
  orderId,
  onConfirm,
  onCancel,
  isSubmitting = false,
}: PhotoCaptureProps) {
  const [preview, setPreview] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleFileChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0]
      if (!file) return

      const reader = new FileReader()
      reader.onloadend = async () => {
        const rawBase64 = reader.result as string
        const compressed = await compressImage(rawBase64, 600, 600)
        setPreview(compressed)
      }
      reader.readAsDataURL(file)
    },
    []
  )

  const handleRetake = () => {
    setPreview(null)
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const handleConfirm = () => {
    if (preview) {
      onConfirm(preview)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in">
      <div className="w-full max-w-lg bg-card rounded-t-3xl sm:rounded-3xl shadow-2xl border border-border/50 overflow-hidden animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-3">
          <div className="flex items-center gap-2.5">
            <div className="h-9 w-9 rounded-xl bg-primary/10 flex items-center justify-center">
              <Camera className="h-4.5 w-4.5 text-primary" />
            </div>
            <div>
              <h3 className="text-sm font-black text-text-primary tracking-tight">
                Delivery Photo Proof
              </h3>
              <p className="text-[10px] text-text-secondary mt-0.5">
                Order #{orderId.slice(0, 8)}…
              </p>
            </div>
          </div>
          <button
            onClick={onCancel}
            disabled={isSubmitting}
            className="h-8 w-8 rounded-xl bg-muted/60 flex items-center justify-center text-text-muted hover:bg-muted transition-colors disabled:opacity-50"
          >
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Photo Area */}
        <div className="px-5 pb-4">
          {!preview ? (
            /* Capture prompt */
            <label
              htmlFor="photo-input"
              className="flex flex-col items-center justify-center gap-3 border-2 border-dashed border-primary/30 bg-primary/[0.03] rounded-2xl p-8 cursor-pointer hover:border-primary/50 hover:bg-primary/[0.06] transition-all active:scale-[0.98]"
            >
              <div className="h-16 w-16 rounded-2xl bg-primary/10 flex items-center justify-center">
                <Camera className="h-7 w-7 text-primary" />
              </div>
              <div className="text-center">
                <p className="text-xs font-bold text-text-primary">
                  Tap to take delivery photo
                </p>
                <p className="text-[10px] text-text-secondary mt-1 leading-relaxed max-w-[200px]">
                  Capture the delivered package at the customer&apos;s doorstep
                </p>
              </div>
              <div className="px-3 py-1.5 rounded-lg bg-primary/10 text-primary text-[10px] font-bold">
                <ImageIcon className="h-3 w-3 inline mr-1" />
                Open Camera
              </div>
              <input
                ref={fileInputRef}
                id="photo-input"
                type="file"
                accept="image/*"
                capture="environment"
                onChange={handleFileChange}
                className="hidden"
              />
            </label>
          ) : (
            /* Photo Preview */
            <div className="space-y-3">
              <div className="relative rounded-2xl overflow-hidden border-2 border-accent/40 shadow-lg">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={preview}
                  alt="Delivery proof"
                  className="w-full h-[260px] object-cover"
                />
                {/* Overlay badge */}
                <div className="absolute top-3 left-3 px-2.5 py-1 rounded-lg bg-accent/90 text-white text-[10px] font-bold flex items-center gap-1 shadow-sm backdrop-blur-sm">
                  <CheckCircle className="h-3 w-3" />
                  Photo Captured
                </div>
                {/* Timestamp watermark */}
                <div className="absolute bottom-3 right-3 px-2 py-1 rounded-md bg-black/50 text-white text-[9px] font-mono backdrop-blur-sm">
                  {new Date().toLocaleString('en-IN', {
                    day: '2-digit',
                    month: 'short',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex gap-2.5">
                <button
                  onClick={handleRetake}
                  disabled={isSubmitting}
                  className="flex-1 flex items-center justify-center gap-1.5 py-3 border border-border rounded-xl text-xs font-bold text-text-secondary hover:bg-muted/50 transition-all disabled:opacity-50"
                >
                  <RotateCcw className="h-3.5 w-3.5" />
                  Retake
                </button>
                <button
                  onClick={handleConfirm}
                  disabled={isSubmitting}
                  className="flex-[2] flex items-center justify-center gap-1.5 py-3 bg-accent text-white rounded-xl text-xs font-black hover:bg-accent/95 transition-all shadow-sm active:scale-[0.98] disabled:opacity-70"
                >
                  {isSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      Confirming…
                    </>
                  ) : (
                    <>
                      <CheckCircle className="h-4 w-4" />
                      Confirm &amp; Deliver
                    </>
                  )}
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Footer hint */}
        <div className="px-5 pb-5 pt-1">
          <p className="text-[9px] text-text-muted text-center leading-relaxed">
            Photo proof ensures safe delivery confirmation. The image will be
            stored for order verification.
          </p>
        </div>
      </div>
    </div>
  )
}
