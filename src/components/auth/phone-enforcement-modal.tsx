'use client'

import React, { useState } from 'react'
import { useSession } from 'next-auth/react'
import { Phone, ShieldCheck, ArrowRight, Loader2 } from 'lucide-react'
import { toast } from 'sonner'
import { isValidIndianPhone, getLast10Digits } from '@/lib/phone'

export function PhoneEnforcementModal() {
  const { data: session, status, update } = useSession()
  const [phone, setPhone] = useState('')
  const [otp, setOtp] = useState('')
  const [step, setStep] = useState<'PHONE' | 'OTP'>('PHONE')
  const [loading, setLoading] = useState(false)

  // Only show if authenticated AND user lacks verified phone
  const needsPhone = status === 'authenticated' && session?.user && Boolean(session.user.needsPhoneVerification)

  if (!needsPhone) return null

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    const cleanDigits = getLast10Digits(phone)
    if (!cleanDigits || cleanDigits.length !== 10) {
      toast.error('Please enter a valid 10-digit Indian mobile number')
      return
    }

    setLoading(true)
    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: cleanDigits }),
      })
      const data = await res.json()
      if (res.ok) {
        toast.success('Verification code sent to your WhatsApp / SMS!')
        setStep('OTP')
      } else {
        toast.error(data.error || 'Failed to send verification code')
      }
    } catch (err) {
      toast.error('Network error. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!otp || otp.trim().length < 4) {
      toast.error('Please enter the OTP code')
      return
    }

    setLoading(true)
    try {
      const cleanDigits = getLast10Digits(phone)
      const res = await fetch('/api/auth/otp/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: cleanDigits, otp: otp.trim() }),
      })
      const data = await res.json()
      if (res.ok) {
        toast.success('Mobile number verified successfully!')
        // Update local session
        await update({ phone: `+91${cleanDigits}`, needsPhoneVerification: false })
        window.location.reload()
      } else {
        toast.error(data.error || 'Invalid OTP code')
      }
    } catch (err) {
      toast.error('Verification failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-[99999] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4">
      <div className="w-full max-w-md rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-6 shadow-2xl animate-in fade-in zoom-in-95 duration-200">
        <div className="flex items-center gap-3 mb-4">
          <div className="h-11 w-11 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-bold">
            <Phone className="h-5 w-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-slate-900 dark:text-white">
              Link Your Mobile Number
            </h2>
            <p className="text-xs text-slate-500 dark:text-slate-400">
              Required for delivery alerts and order updates
            </p>
          </div>
        </div>

        {step === 'PHONE' ? (
          <form onSubmit={handleSendOtp} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                Mobile Number
              </label>
              <div className="relative flex items-center">
                <span className="absolute left-3 text-sm font-bold text-slate-500">
                  +91
                </span>
                <input
                  type="tel"
                  maxLength={10}
                  autoFocus
                  required
                  placeholder="Enter 10-digit number"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                  className="w-full pl-12 pr-4 py-2.5 rounded-xl border border-slate-300 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading || phone.length !== 10}
              className="w-full py-2.5 px-4 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm flex items-center justify-center gap-2 transition disabled:opacity-50 disabled:cursor-not-allowed shadow-md shadow-emerald-600/20"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <>Send Verification Code <ArrowRight className="h-4 w-4" /></>}
            </button>
          </form>
        ) : (
          <form onSubmit={handleVerifyOtp} className="space-y-4">
            <div>
              <div className="flex justify-between items-center mb-1.5">
                <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                  Enter 6-Digit OTP sent to +91 {phone}
                </label>
                <button
                  type="button"
                  onClick={() => setStep('PHONE')}
                  className="text-xs text-emerald-600 font-semibold hover:underline"
                >
                  Edit Phone
                </button>
              </div>
              <input
                type="text"
                maxLength={6}
                autoFocus
                required
                placeholder="e.g. 123456"
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                className="w-full px-4 py-2.5 rounded-xl border border-slate-300 dark:border-slate-700 bg-slate-50 dark:bg-slate-800 text-center tracking-widest text-lg font-bold focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <button
              type="submit"
              disabled={loading || otp.length < 4}
              className="w-full py-2.5 px-4 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm flex items-center justify-center gap-2 transition disabled:opacity-50 disabled:cursor-not-allowed shadow-md shadow-emerald-600/20"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <>Verify & Complete Profile <ShieldCheck className="h-4 w-4" /></>}
            </button>
          </form>
        )}
      </div>
    </div>
  )
}
export default PhoneEnforcementModal
