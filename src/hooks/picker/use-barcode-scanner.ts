'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { toast } from 'sonner'
import { triggerHaptic } from '@/lib/haptic'

interface UseBarcodeScannerProps {
  onScanDetected?: (scannedText: string) => void
}

export function useBarcodeScanner({ onScanDetected }: UseBarcodeScannerProps = {}) {
  const [isCameraScanning, setIsCameraScanning] = useState(false)
  const [scanInput, setScanInput] = useState('')
  const scanInputRef = useRef<HTMLInputElement>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const videoStreamRef = useRef<MediaStream | null>(null)
  const onScanDetectedRef = useRef(onScanDetected)
  onScanDetectedRef.current = onScanDetected

  // Web Audio API Beep Sound generator
  const playBeep = useCallback(() => {
    try {
      triggerHaptic('light')
      const ctx = new (window.AudioContext || (window as any).webkitAudioContext)()
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.type = 'sine'
      osc.frequency.setValueAtTime(850, ctx.currentTime) // Crisp scanner beep
      gain.gain.setValueAtTime(0.08, ctx.currentTime)
      gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.12)
      osc.connect(gain)
      gain.connect(ctx.destination)
      osc.start()
      osc.stop(ctx.currentTime + 0.12)
    } catch (e) {
      console.warn('AudioContext failed:', e)
    }
  }, [])

  const startCamera = useCallback(() => {
    setIsCameraScanning(true)
  }, [])

  const stopCamera = useCallback(() => {
    setIsCameraScanning(false)
    if (videoStreamRef.current) {
      videoStreamRef.current.getTracks().forEach((track) => track.stop())
      videoStreamRef.current = null
    }
  }, [])

  useEffect(() => {
    if (isCameraScanning) {
      navigator.mediaDevices
        ?.getUserMedia({
          video: { facingMode: 'environment' },
        })
        .then((stream) => {
          videoStreamRef.current = stream
          if (videoRef.current) {
            videoRef.current.srcObject = stream
          }
        })
        .catch((err) => {
          console.warn('Camera access error:', err)
          toast.error('Camera block details: Simulating camera scanning feed overlays…')
        })
    } else {
      if (videoStreamRef.current) {
        videoStreamRef.current.getTracks().forEach((track) => track.stop())
        videoStreamRef.current = null
      }
    }
    return () => {
      if (videoStreamRef.current) {
        videoStreamRef.current.getTracks().forEach((track) => track.stop())
      }
    }
  }, [isCameraScanning])

  return {
    isCameraScanning,
    startCamera,
    stopCamera,
    scanInput,
    setScanInput,
    scanInputRef,
    videoRef,
    playBeep,
  }
}
