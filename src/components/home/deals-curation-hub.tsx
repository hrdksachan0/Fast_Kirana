'use client'

import { useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { ProductCard } from '@/components/product/product-card'
import { cn } from '@/lib/utils'
import { ShoppingBag, ArrowRight } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

// ==========================================
// --- PREMIUM INLINE VECTOR SVG COMPONENT DESIGN ---
// ==========================================

function PremiumEssentialsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="ess-shadow" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4" stdDeviation="3.5" flood-color="#78350F" flood-opacity="0.1" />
        </filter>
        <linearGradient id="basket-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#E29A5B" />
          <stop offset="100%" stop-color="#A76632" />
        </linearGradient>
        <linearGradient id="basket-rim" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stop-color="#F2B77A" />
          <stop offset="100%" stop-color="#B77642" />
        </linearGradient>
        <linearGradient id="apple-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FF5D5D" />
          <stop offset="100%" stop-color="#C21A1A" />
        </linearGradient>
        <linearGradient id="leaf-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#4ADE80" />
          <stop offset="100%" stop-color="#15803D" />
        </linearGradient>
        <linearGradient id="carrot-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FB923C" />
          <stop offset="100%" stop-color="#C2410C" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#F0FDF4" />

      <g filter="url(#ess-shadow)">
        {/* Lettuce Leaves */}
        <path d="M30 42C25 35 30 25 38 28C43 22 52 24 54 30C60 25 68 32 64 40" fill="url(#leaf-grad)" />
        <path d="M33 38C31 34 32 30 35 29" stroke="#14532D" stroke-width="1.2" stroke-linecap="round" />
        <path d="M48 34C48 30 46 28 44 27" stroke="#14532D" stroke-width="1.2" stroke-linecap="round" />
        <path d="M57 36C59 32 61 31 63 32" stroke="#14532D" stroke-width="1.2" stroke-linecap="round" />

        {/* Carrot */}
        <path d="M58 22L70 40L64 42L53 24L58 22Z" fill="url(#carrot-grad)" />
        <path d="M66 20C68 17 71 14 72 15C73 16 71 20 68 22" stroke="#15803D" stroke-width="1.8" stroke-linecap="round" />

        {/* Blue Milk Jug */}
        <rect x="34" y="26" width="13" height="20" rx="3" fill="#60A5FA" />
        <path d="M34 31H47" stroke="#2563EB" stroke-width="1.2" />
        <path d="M38 22H43V26H38V22Z" fill="#E2E8F0" />
        <path d="M31 29C29 29 28 31 28 34C28 37 29 39 31 39" stroke="#2563EB" stroke-width="1.8" stroke-linecap="round" />

        {/* Baguette Bread */}
        <rect x="44" y="20" width="9" height="24" rx="4.5" transform="rotate(25 44 20)" fill="#FDE047" stroke="#CA8A04" stroke-width="1.2" />
        <path d="M48 22L51 25" stroke="#CA8A04" stroke-width="1.2" stroke-linecap="round" />
        <path d="M45 28L48 31" stroke="#CA8A04" stroke-width="1.2" stroke-linecap="round" />
        <path d="M42 34L45 37" stroke="#CA8A04" stroke-width="1.2" stroke-linecap="round" />

        {/* Red Apple */}
        <circle cx="34" cy="48" r="9" fill="url(#apple-grad)" />
        <path d="M34 39C34 37 36 36 37 36" stroke="#15803D" stroke-width="1.2" stroke-linecap="round" />

        {/* Orange */}
        <circle cx="65" cy="49" r="8" fill="#FB923C" />
        <circle cx="62" cy="46" r="0.8" fill="#EA580C" />
        <circle cx="67" cy="51" r="0.8" fill="#EA580C" />

        {/* Basket Woven Base */}
        <path d="M22 45H78L70 78H30L22 45Z" fill="url(#basket-grad)" />
        <path d="M26 53H74" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M28 61H72" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M29 69H71" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        
        <path d="M30 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M38 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M46 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M54 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M62 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />
        <path d="M70 45V78" stroke="#78350F" stroke-width="1.2" opacity="0.3" />

        {/* Basket Rim & Handle */}
        <rect x="20" y="42" width="60" height="5.5" rx="2.75" fill="url(#basket-rim)" />
        <path d="M30 42C30 30 70 30 70 42" stroke="url(#basket-rim)" stroke-width="4" fill="none" stroke-linecap="round" />
      </g>
    </svg>
  )
}

function PremiumLightningDealsIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="tag-sh" x="-15%" y="-15%" width="130%" height="130%">
          <feDropShadow dx="1" dy="4" stdDeviation="3.5" flood-color="#EF4444" flood-opacity="0.22" />
        </filter>
        <linearGradient id="tag-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FF4B4B" />
          <stop offset="100%" stop-color="#C81E1E" />
        </linearGradient>
        <linearGradient id="bolt-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FFE600" />
          <stop offset="100%" stop-color="#FFA800" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#FEF2F2" />

      {/* Hanging string */}
      <path d="M50 12C46 12 40 18 42 26" stroke="#9CA3AF" stroke-width="1.8" stroke-linecap="round" fill="none" />
      <circle cx="42" cy="27" r="1.8" fill="#4B5563" />

      <g filter="url(#tag-sh)">
        {/* Red Tag Body */}
        <path d="M32 32C30 30 26 31 24 33L21 38C20 40 21 43 23 45L45 78C47 81 51 81 54 79L73 66C76 64 76 60 74 58L40 25C38 23 34 24 32 26Z" fill="url(#tag-grad)" />
        
        {/* Tag Hole */}
        <circle cx="34" cy="36" r="3" fill="#FEF2F2" />

        {/* Lightning Bolt */}
        <path d="M46 38L32 54H42L38 72L56 50H46L49 38Z" fill="url(#bolt-grad)" stroke="#FFFFFF" stroke-width="1.2" stroke-linejoin="round" />
      </g>

      {/* Floating % Badge */}
      <g filter="url(#tag-sh)">
        <circle cx="68" cy="32" r="9.5" fill="#EF4444" stroke="#FFFFFF" stroke-width="1.8" />
        <path d="M64 36L72 28" stroke="#FFFFFF" stroke-width="1.5" stroke-linecap="round" />
        <circle cx="65" cy="30" r="1.2" fill="none" stroke="#FFFFFF" stroke-width="1.2" />
        <circle cx="71" cy="34" r="1.2" fill="none" stroke="#FFFFFF" stroke-width="1.2" />
      </g>
    </svg>
  )
}

function PremiumTrendingIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="trophy-sh" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4.5" stdDeviation="3.5" flood-color="#D97706" flood-opacity="0.15" />
        </filter>
        <linearGradient id="gold-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FFEAA7" />
          <stop offset="30%" stop-color="#F1C40F" />
          <stop offset="70%" stop-color="#D98014" />
          <stop offset="100%" stop-color="#9E5A00" />
        </linearGradient>
        <linearGradient id="base-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#F3F4F6" />
          <stop offset="100%" stop-color="#D1D5DB" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#FFFDF2" />

      <g filter="url(#trophy-sh)">
        {/* Marble Pedestal Base */}
        <path d="M26 76C26 73 34 71 50 71C66 71 74 73 74 76C74 79 66 81 50 81C34 81 26 79 26 76Z" fill="url(#base-grad)" />
        <path d="M32 71C32 69 38 67 50 67C62 67 68 69 68 71C68 73 62 75 50 75C38 75 32 73 32 71Z" fill="#E5E7EB" stroke="#9CA3AF" stroke-width="0.5" />

        {/* Stem of Trophy */}
        <path d="M46 54H54V68H46V54Z" fill="url(#gold-grad)" />
        <path d="M42 66C42 66 45 68 50 68C55 68 58 66 58 66L56 69H44L42 66Z" fill="#D98014" />

        {/* Trophy Handles */}
        <path d="M34 32C28 32 26 42 34 46C38 48 38 42 38 42" stroke="url(#gold-grad)" stroke-width="3" stroke-linecap="round" fill="none" />
        <path d="M66 32C72 32 74 42 66 46C62 48 62 42 62 42" stroke="url(#gold-grad)" stroke-width="3" stroke-linecap="round" fill="none" />

        {/* Trophy Cup Body */}
        <path d="M34 26H66V40C66 48 58 54 50 54C42 54 34 48 34 40V26Z" fill="url(#gold-grad)" />
        <path d="M34 26C34 23 42 21 50 21C58 21 66 23 66 26" fill="#FFF1C4" opacity="0.3" />

        {/* Big White Center Star */}
        <path d="M50 28L53 34.5L60 35L55 40L57 47L50 43.5L43 47L45 40L40 35L47 34.5L50 28Z" fill="#FFFFFF" filter="url(#trophy-sh)" />
      </g>
    </svg>
  )
}

function PremiumTrendingFlameIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="flame-sh" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4.5" stdDeviation="3.5" flood-color="#F97316" flood-opacity="0.2" />
        </filter>
        <linearGradient id="flame-grad" x1="0" y1="1" x2="0" y2="0">
          <stop offset="0%" stop-color="#EA580C" />
          <stop offset="50%" stop-color="#F97316" />
          <stop offset="100%" stop-color="#FDE047" />
        </linearGradient>
      </defs>
      <circle cx="50" cy="50" r="46" fill="#FFF7ED" />
      <g filter="url(#flame-sh)">
        {/* Outer/back flame */}
        <path d="M50 16C50 16 34 32 34 52C34 64 42 72 50 72C58 72 66 64 66 52C66 32 50 16 50 16Z" fill="url(#flame-grad)" />
        {/* Inner glowing flame */}
        <path d="M50 30C50 30 40 42 40 56C40 64 44 68 50 68C56 68 60 64 60 56C60 42 50 30 50 30Z" fill="#FDE047" opacity="0.9" />
        <path d="M50 42C50 42 45 50 45 60C45 64 47 66 50 66C53 66 55 64 55 60C55 50 50 42 50 42Z" fill="#FFFFFF" />
      </g>
    </svg>
  )
}

function PremiumBreakfastIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="break-sh" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4" stdDeviation="3" flood-color="#CA8A04" flood-opacity="0.1" />
        </filter>
        <linearGradient id="yolk-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FBBF24" />
          <stop offset="100%" stop-color="#D97706" />
        </linearGradient>
        <linearGradient id="cup-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FF8A00" />
          <stop offset="100%" stop-color="#E52E00" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#FFFBEB" />

      <g filter="url(#break-sh)">
        {/* Steaming Coffee Cup saucer */}
        <ellipse cx="58" cy="58" rx="22" ry="4" fill="#E5E7EB" />
        <rect x="42" y="32" width="28" height="24" rx="4" fill="url(#cup-grad)" />
        {/* Cup handle */}
        <path d="M70 38C74 38 78 41 78 44C78 47 74 50 70 50" stroke="#E52E00" stroke-width="4" stroke-linecap="round" fill="none" />
        {/* Coffee surface */}
        <ellipse cx="56" cy="34" rx="12" ry="2" fill="#78350F" />
        {/* Steam */}
        <path d="M50 24C50 20 52 18 52 14" stroke="#F59E0B" stroke-width="1.5" stroke-linecap="round" />
        <path d="M58 22C58 18 60 16 60 12" stroke="#F59E0B" stroke-width="1.5" stroke-linecap="round" />
        <path d="M64 24C64 20 66 18 66 14" stroke="#F59E0B" stroke-width="1.5" stroke-linecap="round" />

        {/* Frying Pan & Fried Egg */}
        <circle cx="32" cy="54" r="17" fill="#374151" stroke="#111827" stroke-width="1.2" />
        <path d="M22 66L10 78" stroke="#111827" stroke-width="4" stroke-linecap="round" />
        <path d="M30 46C24 46 22 49 22 53C22 57 26 62 31 62C36 62 38 58 40 55C42 52 36 46 30 46Z" fill="#F9FAFB" />
        <circle cx="30" cy="54" r="5.5" fill="url(#yolk-grad)" />
      </g>
    </svg>
  )
}

function PremiumLunchIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="lunch-sh" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4" stdDeviation="3.5" flood-color="#059669" flood-opacity="0.1" />
        </filter>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#ECFDF5" />

      <g filter="url(#lunch-sh)">
        {/* Steel Plate */}
        <circle cx="50" cy="50" r="30" fill="#F3F4F6" stroke="#9CA3AF" stroke-width="2.5" />
        <circle cx="50" cy="50" r="26" fill="#E5E7EB" />

        {/* Bowls (Curry, Dal, Raita) */}
        <circle cx="40" cy="34" r="7" fill="#FBBF24" stroke="#D97706" stroke-width="0.8" />
        <circle cx="40" cy="34" r="4.5" fill="#F59E0B" />
        
        <circle cx="58" cy="33" r="7" fill="#F87171" stroke="#DC2626" stroke-width="0.8" />
        <circle cx="58" cy="33" r="4.5" fill="#EF4444" />
        
        <circle cx="64" cy="48" r="6" fill="#34D399" stroke="#059669" stroke-width="0.8" />
        <circle cx="64" cy="48" r="4" fill="#10B981" />

        {/* Steamed Rice pile */}
        <path d="M36 56C36 50 44 48 50 48C56 48 64 50 64 56C64 62 56 64 50 64C44 64 36 62 36 56Z" fill="#FFFFFF" />
        <circle cx="50" cy="55" r="1.2" fill="#10B981" />

        {/* Rotis overlapping */}
        <circle cx="40" cy="54" r="9.5" fill="#FDE047" stroke="#CA8A04" stroke-width="1" opacity="0.95" />
        <circle cx="45" cy="52" r="0.8" fill="#854D0E" />
        <circle cx="38" cy="57" r="0.8" fill="#854D0E" />
        <circle cx="42" cy="49" r="7.5" fill="#FEF08A" stroke="#CA8A04" stroke-width="0.8" opacity="0.95" />
      </g>
    </svg>
  )
}

function PremiumSnacksIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="snack-sh" x="-10%" y="-10%" width="120%" height="120%">
          <feDropShadow dx="0" dy="4" stdDeviation="3.5" flood-color="#F43F5E" flood-opacity="0.1" />
        </filter>
        <linearGradient id="tea-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#FDBA74" />
          <stop offset="100%" stop-color="#EA580C" />
        </linearGradient>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#FFF1F2" />

      <g filter="url(#snack-sh)">
        {/* Plate */}
        <ellipse cx="50" cy="62" rx="31" ry="11" fill="#F1F5F9" stroke="#E2E8F0" stroke-width="1.5" />

        {/* Indian Samosa */}
        <path d="M22 62L41 28L59 62Z" fill="#FBBF24" stroke="#D97706" stroke-width="1.8" stroke-linejoin="round" />
        <path d="M26 60L41 33L55 60Z" fill="#FCD34D" />
        <path d="M32 50L36 54" stroke="#B45309" stroke-width="1.2" stroke-linecap="round" />
        <path d="M45 46L47 52" stroke="#B45309" stroke-width="1.2" stroke-linecap="round" />

        {/* Cutting Chai cutting glass */}
        <path d="M58 32H73L69 65H62L58 32Z" fill="url(#tea-grad)" stroke="#C2410C" stroke-width="1.5" stroke-linejoin="round" />
        <rect x="61" y="36" width="9.5" height="14" fill="#EA580C" opacity="0.6" />
        <rect x="57" y="44" width="17" height="3.5" rx="0.8" fill="#9CA3AF" />
        {/* Steam */}
        <path d="M64 24C64 24 65 21 65 23" stroke="#F97316" stroke-width="1.2" stroke-linecap="round" />
        <path d="M69 24C69 24 70 21 70 23" stroke="#F97316" stroke-width="1.2" stroke-linecap="round" />
      </g>
    </svg>
  )
}

function PremiumLateNightIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg" className={className}>
      <defs>
        <filter id="moon-gl" x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur stdDeviation="3.5" result="blur" />
          <feComposite in="SourceGraphic" in2="blur" operator="over" />
        </filter>
        <linearGradient id="night-sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#0F172A" />
          <stop offset="40%" stop-color="#1E1B4B" />
          <stop offset="100%" stop-color="#311042" />
        </linearGradient>
        <linearGradient id="moon-grad" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="#FFFBEB" />
          <stop offset="100%" stop-color="#FCD34D" />
        </linearGradient>
        <linearGradient id="water-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="#312E81" />
          <stop offset="100%" stop-color="#020617" />
        </linearGradient>
        <clipPath id="dome-clip">
          <circle cx="50" cy="50" r="42" />
        </clipPath>
      </defs>

      <circle cx="50" cy="50" r="46" fill="#F5F3FF" />

      {/* Dome Window with Landscape inside */}
      <g clip-path="url(#dome-clip)">
        <rect x="0" y="0" width="100" height="100" fill="url(#night-sky)" />

        {/* Small stars */}
        <circle cx="25" cy="22" r="0.6" fill="#FFFFFF" opacity="0.8" />
        <circle cx="38" cy="15" r="0.9" fill="#FFFFFF" />
        <circle cx="70" cy="20" r="0.5" fill="#FFFFFF" opacity="0.6" />
        <circle cx="62" cy="35" r="1.1" fill="#FFFFFF" opacity="0.9" />
        <circle cx="28" cy="45" r="0.7" fill="#FFFFFF" opacity="0.7" />
        <circle cx="75" cy="48" r="0.9" fill="#FFFFFF" />

        {/* Nebula glow */}
        <circle cx="50" cy="30" r="23" fill="#4338CA" opacity="0.22" filter="url(#moon-gl)" />

        {/* Glowing crescent moon */}
        <path d="M54 20C47.37 20 42 25.37 42 32C42 38.63 47.37 44 54 44C56.2 44 58.26 43.4 60 42.4C55.8 45.2 50 44.8 46 40.8C42 36.8 41.6 31 44.4 26.8C43.4 28.54 42.8 30.6 42.8 32.8" fill="url(#moon-grad)" filter="url(#moon-gl)" transform="rotate(-15 50 32)" />

        {/* Mountains */}
        <path d="M8 65L26 50L45 62L68 46L92 65V70H8V65Z" fill="#1E1B4B" opacity="0.95" />
        <path d="M8 68L35 55L60 66L78 52L92 68V72H8V68Z" fill="#0F172A" />

        {/* Water */}
        <rect x="0" y="66" width="100" height="34" fill="url(#water-grad)" />

        {/* Reflections */}
        <ellipse cx="50" cy="74" rx="13" ry="0.9" fill="#FFFBEB" opacity="0.25" filter="url(#moon-gl)" />
        <ellipse cx="50" cy="79" rx="8" ry="0.7" fill="#FFFBEB" opacity="0.35" />
        <ellipse cx="50" cy="85" rx="4" ry="0.5" fill="#FFFBEB" opacity="0.45" />
      </g>
    </svg>
  )
}

// ==========================================

interface DealsCurationHubProps {
  flashDeals: any[]
  bestSellers: any[]
  topPicks: any[]
  breakfastProducts: any[]
  lunchProducts: any[]
  teaProducts: any[]
  nightProducts: any[]
}

export function DealsCurationHub({
  flashDeals,
  bestSellers,
  topPicks,
  breakfastProducts,
  lunchProducts,
  teaProducts,
  nightProducts
}: DealsCurationHubProps) {
  const [activeCuration, setActiveCuration] = useState<'all' | 'flash-deals' | 'best-in-town' | 'trending' | 'dynamic-craving'>('all')
  const [currentHour, setCurrentHour] = useState<number>(0) // default to 0 (Night Mode)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    setMounted(true)
    const getISTHour = () => {
      const serverTime = new Date()
      // Indian Standard Time is UTC + 5.5 hours
      const istTime = new Date(serverTime.getTime() + (serverTime.getTimezoneOffset() * 60000) + (5.5 * 60 * 60 * 1000))
      return istTime.getHours()
    }
    setCurrentHour(getISTHour())
    
    // Periodically update the hour to keep the dynamic experience synced
    const interval = setInterval(() => {
      setCurrentHour(getISTHour())
    }, 60000)
    return () => clearInterval(interval)
  }, [])

  // Dynamic Craving configuration based on current hour
  const dynamicCravingConfig = useMemo(() => {
    // 6 AM - 11 AM: Breakfast Club
    if (currentHour >= 6 && currentHour < 11) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Breakfast',
        subtitle: '🍳 Morning starts',
        icon: PremiumBreakfastIcon,
        gradient: 'from-amber-400 via-orange-500 to-yellow-500',
        activeBorderColor: '#F59E0B',
        products: breakfastProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(245,158,11,0.22)]',
        inactiveBg: 'bg-amber-500/[0.02]',
        inactiveHover: 'hover:border-amber-500/20',
        liveTag: '🍳 Breakfast Mode',
      }
    }
    // 11 AM - 4 PM: Lunch Specials
    else if (currentHour >= 11 && currentHour < 16) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Lunch',
        subtitle: '🍛 Lunch meals',
        icon: PremiumLunchIcon,
        gradient: 'from-emerald-500 via-teal-500 to-cyan-500',
        activeBorderColor: '#10B981',
        products: lunchProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(16,185,129,0.22)]',
        inactiveBg: 'bg-emerald-500/[0.02]',
        inactiveHover: 'hover:border-emerald-500/20',
        liveTag: '🍛 Lunch Mode',
      }
    }
    // 4 PM - 8 PM: Snack O'Clock
    else if (currentHour >= 16 && currentHour < 20) {
      return {
        id: 'dynamic-craving' as const,
        title: 'Snacks',
        subtitle: '☕ Tea snacks',
        icon: PremiumSnacksIcon,
        gradient: 'from-rose-500 via-orange-500 to-amber-600',
        activeBorderColor: '#F43F5E',
        products: teaProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(244,63,94,0.22)]',
        inactiveBg: 'bg-rose-500/[0.02]',
        inactiveHover: 'hover:border-rose-500/20',
        liveTag: '☕ Snacks Mode',
      }
    }
    // 8 PM - 5 AM: Night Cravings
    else {
      return {
        id: 'dynamic-craving' as const,
        title: 'Late Night',
        subtitle: '🌙 Midnight cravings',
        icon: PremiumLateNightIcon,
        gradient: 'from-purple-800 via-rose-700 to-amber-800',
        activeBorderColor: '#8B5CF6',
        products: nightProducts,
        activeShadow: 'shadow-[0_12px_25px_-5px_rgba(139,92,246,0.22)]',
        inactiveBg: 'bg-purple-500/[0.02]',
        inactiveHover: 'hover:border-purple-500/20',
        liveTag: '🌙 Cravings Mode',
      }
    }
  }, [currentHour, breakfastProducts, lunchProducts, teaProducts, nightProducts])

  // Combine products for "All" curation dynamically to ensure they stay up-to-date
  const allProducts = useMemo(() => {
    const combined = [...flashDeals, ...bestSellers, ...topPicks]
    const seen = new Set()
    return combined.filter((p) => {
      if (!p || !p.id) return false
      if (seen.has(p.id)) return false
      seen.add(p.id)
      return true
    })
  }, [flashDeals, bestSellers, topPicks])

  // All curation options linked directly to backend admin (isFlashDeal, isBestSeller, isTopPick)
  const curations = useMemo(() => [
    {
      id: 'all' as const,
      title: 'All',
      subtitle: '🔥 Mega collections',
      icon: PremiumEssentialsIcon,
      gradient: 'from-indigo-600 via-indigo-500 to-purple-600',
      activeBorderColor: '#6366F1',
      products: allProducts,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(99,102,241,0.22)]',
      inactiveBg: 'bg-indigo-500/[0.02]',
      inactiveHover: 'hover:border-indigo-500/20',
    },
    {
      id: 'flash-deals' as const,
      title: 'Flash Deals',
      subtitle: '⚡ Instant discounts',
      icon: PremiumLightningDealsIcon,
      gradient: 'from-amber-500 via-orange-500 to-rose-500',
      activeBorderColor: '#EF4444',
      products: flashDeals,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(239,68,68,0.22)]',
      inactiveBg: 'bg-orange-500/[0.02]',
      inactiveHover: 'hover:border-orange-500/20',
    },
    {
      id: 'best-in-town' as const,
      title: 'Best Sellers',
      subtitle: '🏆 Customer favorites',
      icon: PremiumTrendingIcon,
      gradient: 'from-blue-600 via-indigo-500 to-cyan-500',
      activeBorderColor: '#3B82F6',
      products: bestSellers,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(59,130,246,0.22)]',
      inactiveBg: 'bg-blue-500/[0.02]',
      inactiveHover: 'hover:border-blue-500/20',
    },
    {
      id: 'trending' as const,
      title: 'Trending',
      subtitle: '🔥 Popular in town',
      icon: PremiumTrendingFlameIcon,
      gradient: 'from-orange-600 via-amber-500 to-red-500',
      activeBorderColor: '#F97316',
      products: topPicks,
      activeShadow: 'shadow-[0_12px_25px_-5px_rgba(249,115,22,0.22)]',
      inactiveBg: 'bg-orange-500/[0.02]',
      inactiveHover: 'hover:border-orange-500/20',
    },
    {
      ...dynamicCravingConfig
    }
  ], [allProducts, flashDeals, bestSellers, topPicks, dynamicCravingConfig])

  // Active curation data
  const currentCuration = useMemo(() => {
    return curations.find((c) => c.id === activeCuration) || curations[0]
  }, [activeCuration, curations])

  // Group products of the active curation by their category dynamically
  const groupedProducts = useMemo(() => {
    const groups: Record<string, { categoryName: string; categorySlug: string; sortOrder: number; products: any[] }> = {}
    currentCuration.products.forEach((product) => {
      const categoryName = product.category?.name || 'Other Essentials'
      const categorySlug = product.category?.slug || ''
      const sortOrder = product.category?.sortOrder ?? 999
      if (!groups[categoryName]) {
        groups[categoryName] = {
          categoryName,
          categorySlug,
          sortOrder,
          products: [],
        }
      }
      groups[categoryName].products.push(product)
    })
    return Object.values(groups).sort((a, b) => a.sortOrder - b.sortOrder)
  }, [currentCuration])

  return (
    <section className="relative py-4 md:py-8 space-y-6 px-1 transition-all duration-500">
      {/* Dynamic ambient background glow */}
      <div 
        className={cn(
          "absolute inset-0 -z-20 opacity-[0.03] dark:opacity-[0.07] bg-gradient-to-tr transition-all duration-700 blur-[80px]",
          currentCuration.gradient
        )}
      />
      <div 
        className={cn(
          "absolute -top-10 -left-10 w-48 h-48 rounded-full -z-20 opacity-[0.04] dark:opacity-[0.08] bg-gradient-to-br transition-all duration-700 blur-[60px]",
          currentCuration.gradient
        )}
      />
      <div 
        className={cn(
          "absolute -bottom-10 -right-10 w-48 h-48 rounded-full -z-20 opacity-[0.04] dark:opacity-[0.08] bg-gradient-to-tl transition-all duration-700 blur-[60px]",
          currentCuration.gradient
        )}
      />

      {/* Hub Title & Subtitle */}
      <div className="px-1">
        <h2 className="text-2xl sm:text-3xl font-extrabold text-zinc-900 dark:text-white tracking-tight">
          Curated For You
        </h2>
        <p className="text-xs sm:text-sm text-zinc-500 dark:text-zinc-400 mt-1 font-medium">
          Handpicked collections for every mood
        </p>
      </div>

      {/* Premium Curation Tab Bar: Redesigned into minimal organic category circles */}
      <div className="flex items-center gap-6 sm:gap-10 overflow-x-auto pb-3.5 pt-2 select-none w-full justify-start sm:justify-center scroll-smooth snap-x snap-mandatory scrollbar-none px-1">
        {curations.map((c) => {
          const isActive = activeCuration === c.id
          return (
            <button
              key={c.id}
              onClick={() => setActiveCuration(c.id)}
              className="group flex flex-col items-center gap-2 cursor-pointer shrink-0 snap-start outline-none select-none active:scale-95 transition-transform duration-300"
              suppressHydrationWarning
            >
              {/* Clean minimal organic circle */}
              <div
                className={cn(
                  'relative w-16 h-16 sm:w-20 sm:h-20 rounded-full flex items-center justify-center transition-all duration-300 border bg-white dark:bg-zinc-950',
                  isActive
                    ? 'shadow-md border-solid scale-105'
                    : 'border-zinc-200/50 dark:border-zinc-800/40 hover:border-zinc-350 dark:hover:border-zinc-750 hover:scale-105 shadow-[0_4px_12px_rgba(0,0,0,0.04)]'
                )}
                style={isActive ? { borderColor: c.activeBorderColor, boxShadow: `0 0 16px ${c.activeBorderColor}25` } : {}}
              >
                {/* Premium Vector inline SVG icon */}
                {c.icon && (
                  <c.icon className="w-[80%] h-[80%] transition-transform duration-500 group-hover:scale-108 group-hover:rotate-2 relative z-10" />
                )}
              </div>

              {/* Title Text Centered Below */}
              <span
                className={cn(
                  'text-[11px] sm:text-xs tracking-tight transition-colors duration-300 max-w-[85px] sm:max-w-[105px] text-center line-clamp-2 leading-tight h-9 flex items-center justify-center',
                  isActive
                    ? 'text-zinc-900 dark:text-white font-extrabold'
                    : 'text-zinc-500 dark:text-zinc-400 font-medium group-hover:text-zinc-900 dark:group-hover:text-white'
                )}
                suppressHydrationWarning
              >
                {c.title}
              </span>

              {/* Bottom active underline indicator bar */}
              <div className="relative h-[3px] w-8 rounded-full overflow-hidden mt-0.5">
                {isActive && (
                  <motion.div
                    layoutId="activeCurationUnderline"
                    className="absolute inset-0"
                    style={{ backgroundColor: c.activeBorderColor }}
                    transition={{ type: 'spring', stiffness: 280, damping: 24 }}
                  />
                )}
              </div>
            </button>
          )
        })}
      </div>

      {/* Category-grouped Product Display Grid */}
      <div className="relative min-h-[250px] w-full">
        <AnimatePresence mode="wait">
          <motion.div
            key={activeCuration}
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            transition={{ duration: 0.2 }}
            className="w-full"
          >
            {currentCuration.products.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 border border-dashed border-zinc-200 dark:border-zinc-800 rounded-2xl text-center p-4 shadow-sm select-none">
                <ShoppingBag className="h-7 w-7 text-muted-foreground/60 mb-2 animate-pulse-gentle" />
                <h3 className="text-xs font-bold text-text-primary">No deals available</h3>
                <p className="text-[10px] text-text-secondary mt-0.5">Please check back later!</p>
              </div>
            ) : (
              <div className="space-y-6">
                {groupedProducts.map((group) => (
                  <div key={group.categoryName} className="space-y-2.5">
                    {/* Category Subheader */}
                    <div className="flex items-center justify-between px-1">
                      <div className="flex items-center gap-1">
                        <h3 className="text-lg sm:text-xl font-bold text-zinc-900 dark:text-white tracking-tight">
                          {group.categoryName}
                        </h3>
                        <span className="inline-flex items-center justify-center px-2.5 py-0.5 rounded-full bg-[#FFF0F2] dark:bg-rose-950/30 text-[10px] sm:text-xs font-bold text-[#FF2E55] dark:text-rose-400 ml-2">
                          {group.products.length} {group.products.length === 1 ? 'item' : 'items'}
                        </span>
                      </div>
                      
                      {/* Interactive See All link */}
                      <Link
                        href={group.categorySlug === 'cafe' ? '/cafe' : (group.categorySlug ? `/category/${group.categorySlug}` : '/category')}
                        className="group/btn inline-flex items-center gap-0.5 text-xs sm:text-sm font-bold text-[#FF2E55] hover:text-[#e02447] transition-colors select-none"
                      >
                        See All
                        <span className="inline-block transition-transform duration-300 group-hover/btn:translate-x-0.5 font-normal ml-0.5">
                          →
                        </span>
                      </Link>
                    </div>

                    {/* Category Products Horizontal Snap Track */}
                    <div 
                      className="flex gap-2.5 md:gap-4 overflow-x-auto pb-2 md:pb-4 scroll-smooth snap-x snap-mandatory"
                      style={{ scrollbarWidth: 'none', msOverflowStyle: 'none' }}
                    >
                      {group.products.slice(0, 10).map((product) => (
                        <div 
                          key={product.id} 
                          className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0 snap-start"
                        >
                          <ProductCard product={product} />
                        </div>
                      ))}
                      {group.products.length > 10 && (
                        <Link
                          href={group.categorySlug === 'cafe' ? '/cafe' : (group.categorySlug ? `/category/${group.categorySlug}` : '/category')}
                          className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0 snap-start flex flex-col items-center justify-center rounded-xl border border-border/60 dark:border-zinc-800/60 bg-gradient-to-b from-primary/[0.02] to-primary/[0.06] dark:from-primary/[0.005] dark:to-primary/[0.02] p-4 text-center cursor-pointer transition-all duration-300 shadow-card hover:shadow-[0_8px_30px_rgba(226,10,34,0.12),0_2px_8px_rgba(0,0,0,0.06)] hover:border-primary/25 h-[210px] min-[375px]:h-[230px] sm:h-[250px] md:h-[290px] group"
                        >
                          <div className="flex flex-col items-center justify-center transition-transform duration-300 group-hover:scale-[1.03]">
                            {/* Circular Icon with Soft Glow on Hover */}
                            <div className="relative flex h-13 w-13 items-center justify-center rounded-full bg-white dark:bg-zinc-900 border border-border/40 shadow-sm transition-all duration-300 group-hover:bg-primary group-hover:text-white group-hover:border-primary group-hover:shadow-[0_4px_12px_rgba(226,10,34,0.22)]">
                              <ArrowRight size={20} className="stroke-[2.5] text-primary group-hover:text-white transition-transform duration-300 group-hover:translate-x-0.5" />
                            </div>
                            
                            <span className="text-xs sm:text-sm font-extrabold text-zinc-800 dark:text-zinc-200 mt-4 leading-tight tracking-tight">
                              See All
                            </span>
                            <span className="text-[10px] sm:text-xs font-black text-primary bg-primary/10 dark:bg-primary/20 px-2.5 py-0.5 rounded-full mt-2.5 inline-block">
                              +{group.products.length - 10} More
                            </span>
                          </div>
                        </Link>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    </section>
  )
}
