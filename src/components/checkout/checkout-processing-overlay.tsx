'use client'

import { useEffect, useState, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import {
  CheckCircle2,
  ShieldCheck,
  Bike,
  ChefHat,
  Sparkles,
  MapPin,
  Clock,
  Zap,
  PackageCheck,
  Lock,
} from 'lucide-react'

export type CheckoutOverlayState =
  | 'creating-order'
  | 'awaiting-payment'
  | 'verifying-payment'
  | 'success'
  | null

interface CheckoutProcessingOverlayProps {
  state: CheckoutOverlayState
  orderReadableId?: string
}

// Micro-steps that simulate real-time Zepto / Blinkit order preparation milestones
const ORDER_CREATION_STEPS = [
  {
    icon: PackageCheck,
    title: 'Reserving Fresh Inventory',
    subtitle: 'Items locked from nearest hub',
  },
  {
    icon: MapPin,
    title: 'Optimizing Delivery Route',
    subtitle: 'Mapping shortest zero-traffic path',
  },
  {
    icon: Bike,
    title: 'Connecting Express Rider',
    subtitle: 'Assigning nearest delivery partner',
  },
]

export function CheckoutProcessingOverlay({
  state,
  orderReadableId,
}: CheckoutProcessingOverlayProps) {
  const [activeStepIndex, setActiveStepIndex] = useState(0)
  const [progress, setProgress] = useState(15)

  // Step progression timer during 'creating-order'
  useEffect(() => {
    if (state !== 'creating-order') {
      setActiveStepIndex(0)
      setProgress(15)
      return
    }

    const t1 = setTimeout(() => {
      setActiveStepIndex(1)
      setProgress(55)
    }, 900)

    const t2 = setTimeout(() => {
      setActiveStepIndex(2)
      setProgress(85)
    }, 1800)

    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
    }
  }, [state])

  // Generate dynamic celebration confetti particles for success state
  const confettiParticles = useMemo(() => {
    return Array.from({ length: 32 }).map((_, i) => ({
      id: i,
      x: (Math.random() - 0.5) * 360,
      y: (Math.random() - 0.8) * 380,
      scale: Math.random() * 0.7 + 0.6,
      rotate: Math.random() * 720 - 360,
      color: [
        '#E20A22', // FastKirana Red
        '#10B981', // Emerald Green
        '#F59E0B', // Amber Gold
        '#3B82F6', // Royal Blue
        '#EC4899', // Pink
        '#8B5CF6', // Purple
      ][i % 6],
      delay: Math.random() * 0.15,
    }))
  }, [])

  if (!state) return null

  return (
    <AnimatePresence>
      <motion.div
        key="checkout-overlay-backdrop"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        transition={{ duration: 0.3 }}
        className="fixed inset-0 z-[200] flex items-center justify-center p-4 sm:p-6 overflow-hidden bg-zinc-950/75 backdrop-blur-xl"
      >
        {/* Soft Animated Ambient Radial Glows (Zepto/Blinkit Atmosphere) */}
        <motion.div
          animate={{
            scale: [1, 1.25, 1],
            opacity: [0.35, 0.55, 0.35],
          }}
          transition={{ duration: 4, repeat: Infinity, ease: 'easeInOut' }}
          className="absolute -top-20 -left-20 w-80 h-80 rounded-full bg-gradient-to-br from-red-600/30 via-rose-500/20 to-transparent blur-3xl pointer-events-none"
        />
        <motion.div
          animate={{
            scale: [1.2, 1, 1.2],
            opacity: [0.3, 0.5, 0.3],
          }}
          transition={{ duration: 4.5, repeat: Infinity, ease: 'easeInOut', delay: 1 }}
          className="absolute -bottom-20 -right-20 w-80 h-80 rounded-full bg-gradient-to-tl from-emerald-500/30 via-teal-500/20 to-transparent blur-3xl pointer-events-none"
        />

        {/* Central Frosted Glassmorphism Card */}
        <motion.div
          initial={{ scale: 0.9, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.95, opacity: 0, y: 10 }}
          transition={{ type: 'spring', damping: 25, stiffness: 300 }}
          className="relative w-full max-w-sm sm:max-w-md bg-white/95 dark:bg-zinc-900/95 border border-zinc-200/80 dark:border-zinc-800/80 rounded-3xl p-6 sm:p-8 shadow-2xl shadow-black/30 backdrop-blur-2xl text-center overflow-hidden"
        >
          {/* Subtle Top Accent Shimmer Bar */}
          <div className="absolute top-0 inset-x-0 h-1 bg-gradient-to-r from-red-500 via-emerald-500 to-amber-500" />

          {/* ══════════════ STATE 1: CREATING ORDER (ZEPTO/BLINKIT MOTION) ══════════════ */}
          {state === 'creating-order' && (
            <div className="flex flex-col items-center">
              {/* Express Delivery Guarantee Pill */}
              <motion.div
                initial={{ opacity: 0, y: -10 }}
                animate={{ opacity: 1, y: 0 }}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-400 text-[11px] font-black tracking-wide uppercase mb-6"
              >
                <span className="relative flex h-2 w-2">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
                </span>
                <Zap className="h-3 w-3 fill-current" />
                <span>FastKirana Express • 10-15 Mins</span>
              </motion.div>

              {/* Animated Scooter / Rider Radar Stage */}
              <div className="relative w-28 h-28 flex items-center justify-center mb-6">
                {/* Sonar / Radar Pulse Rings */}
                <motion.div
                  animate={{ scale: [1, 1.8], opacity: [0.6, 0] }}
                  transition={{ duration: 1.8, repeat: Infinity, ease: 'easeOut' }}
                  className="absolute inset-0 rounded-full border-2 border-red-500/40"
                />
                <motion.div
                  animate={{ scale: [1, 2.2], opacity: [0.4, 0] }}
                  transition={{ duration: 1.8, repeat: Infinity, ease: 'easeOut', delay: 0.6 }}
                  className="absolute inset-0 rounded-full border border-red-500/25"
                />

                {/* Animated Speed Lines (Wind effect) */}
                <div className="absolute inset-x-0 -top-1 overflow-hidden pointer-events-none">
                  {[-12, 0, 12].map((offsetY, idx) => (
                    <motion.div
                      key={idx}
                      style={{ top: 56 + offsetY }}
                      animate={{ x: [-20, 110], opacity: [0, 0.8, 0] }}
                      transition={{
                        duration: 0.8,
                        repeat: Infinity,
                        delay: idx * 0.25,
                        ease: 'linear',
                      }}
                      className="absolute left-0 w-8 h-[2px] bg-gradient-to-r from-transparent via-red-500 to-transparent rounded-full"
                    />
                  ))}
                </div>

                {/* Center Vehicle Capsule */}
                <motion.div
                  animate={{
                    y: [-2, 3, -2],
                    rotate: [-1, 1.5, -1],
                  }}
                  transition={{ duration: 0.7, repeat: Infinity, ease: 'easeInOut' }}
                  className="relative z-10 w-20 h-20 rounded-2xl bg-gradient-to-br from-red-500 to-rose-600 shadow-xl shadow-red-500/30 flex items-center justify-center text-white border-2 border-white/20"
                >
                  <Bike className="h-10 w-10 drop-shadow-md" />
                </motion.div>
              </div>

              {/* Main Headline */}
              <motion.h2
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="text-xl sm:text-2xl font-black text-zinc-900 dark:text-zinc-50 tracking-tight"
              >
                Creating Your Order
              </motion.h2>
              <p className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 font-medium mt-1 mb-6">
                FastKirana Express packing station is locking your items
              </p>

              {/* Sleek Gradient Progress Track */}
              <div className="w-full bg-zinc-100 dark:bg-zinc-800/80 rounded-full h-2 p-0.5 overflow-hidden mb-6 border border-zinc-200/50 dark:border-zinc-700/50">
                <motion.div
                  initial={{ width: '15%' }}
                  animate={{ width: `${progress}%` }}
                  transition={{ duration: 0.6, ease: 'easeOut' }}
                  className="h-full rounded-full bg-gradient-to-r from-red-500 via-amber-500 to-emerald-500 shadow-sm relative overflow-hidden"
                >
                  <motion.div
                    animate={{ x: ['-100%', '200%'] }}
                    transition={{ duration: 1.2, repeat: Infinity, ease: 'linear' }}
                    className="absolute inset-0 bg-gradient-to-r from-transparent via-white/50 to-transparent w-1/2"
                  />
                </motion.div>
              </div>

              {/* Animated Live Milestones Checklist */}
              <div className="w-full space-y-2.5 text-left">
                {ORDER_CREATION_STEPS.map((step, idx) => {
                  const isDone = idx < activeStepIndex
                  const isCurrent = idx === activeStepIndex
                  const StepIcon = step.icon

                  return (
                    <motion.div
                      key={step.title}
                      initial={{ opacity: 0, x: -10 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: idx * 0.15 }}
                      className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl border transition-all ${
                        isCurrent
                          ? 'bg-red-50/80 dark:bg-red-950/20 border-red-200 dark:border-red-900/40 shadow-sm'
                          : isDone
                          ? 'bg-emerald-50/60 dark:bg-emerald-950/15 border-emerald-200/60 dark:border-emerald-900/30'
                          : 'bg-zinc-50/50 dark:bg-zinc-800/30 border-transparent opacity-50'
                      }`}
                    >
                      <div
                        className={`flex-shrink-0 w-8 h-8 rounded-lg flex items-center justify-center transition-colors ${
                          isDone
                            ? 'bg-emerald-500 text-white'
                            : isCurrent
                            ? 'bg-red-500 text-white animate-pulse'
                            : 'bg-zinc-200 dark:bg-zinc-700 text-zinc-400'
                        }`}
                      >
                        {isDone ? (
                          <CheckCircle2 className="h-4 w-4" />
                        ) : (
                          <StepIcon className="h-4 w-4" />
                        )}
                      </div>

                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <p
                            className={`text-xs font-bold truncate ${
                              isCurrent
                                ? 'text-red-700 dark:text-red-400'
                                : isDone
                                ? 'text-emerald-700 dark:text-emerald-400'
                                : 'text-zinc-600 dark:text-zinc-400'
                            }`}
                          >
                            {step.title}
                          </p>
                          {isCurrent && (
                            <span className="text-[10px] font-black uppercase text-red-600 dark:text-red-400 animate-pulse">
                              In Progress
                            </span>
                          )}
                          {isDone && (
                            <span className="text-[10px] font-black uppercase text-emerald-600 dark:text-emerald-400">
                              Done
                            </span>
                          )}
                        </div>
                        <p className="text-[11px] text-zinc-500 dark:text-zinc-400 truncate">
                          {step.subtitle}
                        </p>
                      </div>
                    </motion.div>
                  )
                })}
              </div>
            </div>
          )}

          {/* ══════════════ STATE 2: AWAITING PAYMENT (UPI FLOW) ══════════════ */}
          {state === 'awaiting-payment' && (
            <div className="flex flex-col items-center">
              <div className="relative w-24 h-24 flex items-center justify-center mb-6">
                <motion.div
                  animate={{ scale: [1, 1.4, 1], opacity: [0.4, 0.1, 0.4] }}
                  transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
                  className="absolute inset-0 rounded-full bg-blue-500/20"
                />
                <div className="relative z-10 w-20 h-20 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 shadow-xl shadow-blue-500/30 flex items-center justify-center text-white border-2 border-white/20">
                  <ShieldCheck className="h-10 w-10 drop-shadow-md" />
                </div>
              </div>

              <h2 className="text-xl sm:text-2xl font-black text-zinc-900 dark:text-zinc-50 tracking-tight">
                Approve in Your UPI App
              </h2>
              <p className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 font-medium mt-1 mb-6 max-w-xs">
                Open Google Pay, PhonePe, or Paytm to complete the payment
              </p>

              {/* Supported UPI Badges */}
              <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-xl bg-zinc-100 dark:bg-zinc-800/80 border border-zinc-200 dark:border-zinc-700 text-[11px] font-bold text-zinc-600 dark:text-zinc-300 mb-6">
                <Lock className="h-3.5 w-3.5 text-blue-500" />
                <span>100% Bank Safe • Instant Confirmation</span>
              </div>

              <div className="w-full bg-blue-50/80 dark:bg-blue-950/20 border border-blue-200 dark:border-blue-900/40 rounded-xl p-3 flex items-center justify-center gap-2 text-xs font-bold text-blue-700 dark:text-blue-300">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1.2, repeat: Infinity, ease: 'linear' }}
                  className="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full"
                />
                <span>Listening for payment approval...</span>
              </div>
            </div>
          )}

          {/* ══════════════ STATE 3: VERIFYING PAYMENT ══════════════ */}
          {state === 'verifying-payment' && (
            <div className="flex flex-col items-center">
              <div className="relative w-24 h-24 flex items-center justify-center mb-6">
                <motion.div
                  animate={{ scale: [1, 1.3, 1], rotate: [0, 180, 360] }}
                  transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
                  className="absolute inset-0 rounded-full border-2 border-dashed border-amber-500/50"
                />
                <div className="relative z-10 w-20 h-20 rounded-2xl bg-gradient-to-br from-amber-500 to-orange-600 shadow-xl shadow-amber-500/30 flex items-center justify-center text-white border-2 border-white/20">
                  <Sparkles className="h-10 w-10 drop-shadow-md" />
                </div>
              </div>

              <h2 className="text-xl sm:text-2xl font-black text-zinc-900 dark:text-zinc-50 tracking-tight">
                Verifying with Bank
              </h2>
              <p className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 font-medium mt-1 mb-6 max-w-xs">
                Almost done! Confirming transaction with payment gateway
              </p>

              <div className="w-full bg-amber-50/80 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/40 rounded-xl p-3 flex items-center justify-center gap-2 text-xs font-bold text-amber-700 dark:text-amber-300">
                <motion.div
                  animate={{ rotate: 360 }}
                  transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
                  className="w-4 h-4 border-2 border-amber-500 border-t-transparent rounded-full"
                />
                <span>Finalizing bank receipt...</span>
              </div>
            </div>
          )}

          {/* ══════════════ STATE 4: SUCCESS (BLINKIT / ZEPTO CELEBRATION) ══════════════ */}
          {state === 'success' && (
            <div className="relative flex flex-col items-center">
              {/* Confetti Explosion Burst */}
              <div className="absolute inset-0 pointer-events-none flex items-center justify-center">
                {confettiParticles.map((p) => (
                  <motion.div
                    key={p.id}
                    initial={{ x: 0, y: 0, scale: 0, rotate: 0, opacity: 1 }}
                    animate={{
                      x: p.x,
                      y: p.y,
                      scale: [0, p.scale, 0],
                      rotate: p.rotate,
                      opacity: [1, 1, 0],
                    }}
                    transition={{
                      duration: 1.4,
                      delay: p.delay,
                      ease: 'easeOut',
                    }}
                    style={{ backgroundColor: p.color }}
                    className="absolute w-2.5 h-2.5 rounded-sm shadow-sm"
                  />
                ))}
              </div>

              {/* Big Spring Checkmark */}
              <div className="relative w-28 h-28 flex items-center justify-center mb-5">
                <motion.div
                  initial={{ scale: 0 }}
                  animate={{ scale: [0, 1.4, 1] }}
                  transition={{ duration: 0.6, type: 'spring', damping: 15 }}
                  className="absolute inset-0 rounded-full bg-emerald-500/20"
                />
                <motion.div
                  initial={{ scale: 0, rotate: -45 }}
                  animate={{ scale: 1, rotate: 0 }}
                  transition={{ type: 'spring', damping: 12, stiffness: 250, delay: 0.15 }}
                  className="relative z-10 w-20 h-20 rounded-2xl bg-gradient-to-br from-emerald-500 to-teal-600 shadow-xl shadow-emerald-500/40 flex items-center justify-center text-white border-2 border-white/20"
                >
                  <CheckCircle2 className="h-11 w-11 drop-shadow-md" />
                </motion.div>
              </div>

              {/* Celebration Title */}
              <motion.h2
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.2 }}
                className="text-2xl sm:text-3xl font-black text-emerald-600 dark:text-emerald-400 tracking-tight"
              >
                Order Placed! 🎉
              </motion.h2>

              {orderReadableId && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: 0.3 }}
                  className="mt-2 inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-zinc-100 dark:bg-zinc-800 text-zinc-900 dark:text-zinc-100 text-xs font-black"
                >
                  <span>Order #{orderReadableId}</span>
                </motion.div>
              )}

              {/* ETA & Status Highlights */}
              <motion.div
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.35 }}
                className="grid grid-cols-2 gap-2.5 w-full mt-5"
              >
                <div className="flex items-center gap-2 p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-700 dark:text-emerald-300">
                  <Clock className="h-4 w-4 flex-shrink-0" />
                  <div className="text-left">
                    <p className="text-[10px] font-medium text-emerald-600/80 dark:text-emerald-400/80">
                      Estimated Arrival
                    </p>
                    <p className="text-xs font-black">10-15 Mins</p>
                  </div>
                </div>

                <div className="flex items-center gap-2 p-2.5 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-700 dark:text-blue-300">
                  <ChefHat className="h-4 w-4 flex-shrink-0" />
                  <div className="text-left">
                    <p className="text-[10px] font-medium text-blue-600/80 dark:text-blue-400/80">
                      Hub Alert
                    </p>
                    <p className="text-xs font-black">Packing Now</p>
                  </div>
                </div>
              </motion.div>

              {/* Redirecting Progress Bar */}
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ delay: 0.45 }}
                className="w-full mt-6"
              >
                <div className="flex items-center justify-between text-[11px] font-bold text-zinc-500 mb-1.5">
                  <span>Redirecting to Live Tracking</span>
                  <span className="text-emerald-600 dark:text-emerald-400">Opening...</span>
                </div>
                <div className="w-full bg-zinc-100 dark:bg-zinc-800 rounded-full h-1.5 overflow-hidden">
                  <motion.div
                    initial={{ width: '0%' }}
                    animate={{ width: '100%' }}
                    transition={{ duration: 1.8, ease: 'easeInOut' }}
                    className="h-full bg-emerald-500 rounded-full"
                  />
                </div>
              </motion.div>
            </div>
          )}
        </motion.div>
      </motion.div>
    </AnimatePresence>
  )
}
