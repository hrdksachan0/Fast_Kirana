'use client'

import { useState, useEffect, useRef } from 'react'
import { toast } from 'sonner'
import { SERVICE_AREA_NAME } from '@/lib/store-config'
import {
  Image as ImageIcon,
  Plus,
  Trash2,
  Edit2,
  Check,
  X,
  Gift,
  Sparkles,
  Eye,
  Loader2,
  ArrowUp,
  ArrowDown,
  Power,
  LayoutGrid,
  Layers,
  Tag,
  ExternalLink,
  Palette,
  Sliders,
  Sparkle,
  Video,
  Play,
  Pause,
  UploadCloud,
  Link as LinkIcon
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'
import { compressImageClient } from '@/lib/image-compression'

interface PromoBanner {
  id: string
  title: string
  description: string
  code: string
  gradient: string
  type: string
  imageUrl?: string | null
  videoUrl?: string | null
  linkUrl?: string | null
  isActive: boolean
  sortOrder: number
  cardType?: string
  eyebrowTag?: string | null
  primaryBrand?: string | null
  secondaryBrand?: string | null
  cashbackTitle?: string | null
  cashbackSubtitle?: string | null
  disclaimerText?: string | null
  ctaText?: string | null
  ctaUrl?: string | null
  ctaBgColorHex?: string | null
  ctaTextColorHex?: string | null
  gridImages?: string[] | null
  hasWireframeGrid?: boolean
  rawCode?: string
  placement?: 'hero' | 'brand_card'
  platform?: 'all' | 'mobile' | 'web'
  storeId?: string | null
}

// Predefined Gradient Options
const GRADIENT_PRESETS = [
  { name: 'Diwali Gold (Orange/Amber)', value: 'from-amber-600 via-orange-500 to-yellow-500' },
  { name: 'Holi Colors (Pink/Purple/Yellow)', value: 'from-pink-500 via-purple-500 to-yellow-400' },
  { name: 'Eid Emerald (Green/Teal)', value: 'from-emerald-600 via-teal-500 to-cyan-500' },
  { name: 'New Year Party (Rose/Pink)', value: 'from-rose-600 via-fuchsia-600 to-pink-500' },
  { name: 'Store Red (Default Red/Orange)', value: 'from-primary via-rose-500 to-orange-400' },
  { name: 'Fresh Green (Mint/Emerald)', value: 'from-accent via-emerald-500 to-teal-400' },
  { name: 'Midnight Snacks (Blue/Amber)', value: 'from-discount via-orange-500 to-amber-400' },
  { name: 'Night Sky (Dark Slate/Blue)', value: 'from-slate-900 via-blue-900 to-blue-600' }
]

// Predefined Festival/Occasion Templates
const FESTIVAL_TEMPLATES = [
  {
    name: '📦 Fast Delivery (Ghatampur)',
    title: 'Fast Delivery in Ghatampur',
    description: 'Milk, Fruits, Vegetables, Snacks & more delivered in minutes',
    code: '',
    gradient: 'from-rose-500 via-rose-500 to-orange-400',
    type: 'real-image',
    imageUrl: '/banners/ghatampur-express-real.png',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🍔 A.S. Restaurant • Burgers, Pizza & Shakes',
    title: 'A.S. Restaurant • Burgers, Pizza & Shakes',
    description: 'Juicy burgers, cheesy loaded pizzas, hot momos & thick shakes',
    code: '',
    gradient: 'from-rose-600 via-red-500 to-amber-500',
    type: 'real-image',
    imageUrl: '/banners/as-restaurant-real.png',
    linkUrl: '/restaurant/as-restaurant'
  },
  {
    name: '🍲 Wedson Restaurant • Royal Indian & Biryani',
    title: 'Wedson Restaurant • Royal Indian & Biryani',
    description: 'Aromatic dum biryani, rich paneer curries, tandoori treats & dal makhani',
    code: '',
    gradient: 'from-amber-600 via-orange-500 to-yellow-500',
    type: 'real-image',
    imageUrl: '/banners/wedson-restaurant-real.png',
    linkUrl: '/restaurant/wedson-restaurant'
  },
  {
    name: '🍱 Bal Udyan Restaurant • Family Meals & Thalis',
    title: 'Bal Udyan Restaurant • Family Meals & Thalis',
    description: 'Homestyle North Indian thalis, special Chinese bites & evening party snacks',
    code: '',
    gradient: 'from-emerald-600 via-teal-500 to-cyan-500',
    type: 'real-image',
    imageUrl: '/banners/bal-udyan-real.png',
    linkUrl: '/restaurant/bal-udyan-restaurant'
  },
  {
    name: '🥬 Farm Fresh Vegetables & Fruits',
    title: 'Farm Fresh Vegetables & Fruits',
    description: 'Directly sourced from local farms. Handpicked for premium quality.',
    code: 'SAVE20',
    gradient: 'from-emerald-600 via-emerald-500 to-teal-400',
    type: 'fresh',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🥛 Super Savings (First Order)',
    title: 'Super Savings on First Order!',
    description: 'Get flat 50% off up to ₹100 on fruits, veggies, dairy, and snacks.',
    code: 'WELCOME50',
    gradient: 'from-rose-600 via-rose-500 to-orange-400',
    type: 'first-order',
    linkUrl: '/category/fruits-vegetables'
  },
  {
    name: '🪔 Diwali Special',
    title: 'Shubh Deepavali Festive Offer!',
    description: 'Celebrate Diwali with sweets, dry fruits, and diyas. Get flat ₹150 off on your purchase!',
    code: 'DIWALI150',
    gradient: 'from-amber-600 via-orange-500 to-yellow-500',
    type: 'festive',
    linkUrl: '/search?q=sweets'
  },
  {
    name: '🎨 Holi Splash',
    title: 'Holi Ke Rang, FastKirana Ke Sang!',
    description: 'Get natural herbal gulal, sweets, thandai, and pichkaris delivered fast!',
    code: 'HOLI100',
    gradient: 'from-pink-500 via-purple-500 to-yellow-400',
    type: 'festive',
    linkUrl: '/search?q=holi'
  },
  {
    name: '🌙 Eid Mubarak',
    title: 'Eid Mubarak Festive Delights!',
    description: 'Save 20% on fresh dates, sheer khurma ingredients, milk, and dry fruits today.',
    code: 'EIDSPECIAL',
    gradient: 'from-emerald-600 via-teal-500 to-cyan-500',
    type: 'festive',
    linkUrl: '/category/dairy-breakfast'
  },
  {
    name: '🍿 Midnight Munchies (Zepto Style)',
    title: 'Late Night Craving Remedies 🌙',
    description: 'Chips, Instant Noodles, Chocolates & Beverages under ₹49!',
    code: 'NIGHT49',
    gradient: 'from-purple-800 via-indigo-800 to-slate-950',
    type: 'festive',
    linkUrl: '/category/snacks-munchies'
  },
  {
    name: '🍦 Summer Coolers (Blinkit Style)',
    title: 'Beat the Heat with Cold Drinks 🍦',
    description: 'Amul, Kwality Walls, Coke, Pepsi & Juices delivered fast.',
    code: 'COOL20',
    gradient: 'from-cyan-600 via-blue-600 to-indigo-600',
    type: 'festive',
    linkUrl: '/category/beverages'
  },
  {
    name: '🛍️ Weekend Grocery Bazaar',
    title: 'Weekend Kirana Super Savings 📦',
    description: 'Stock up your kitchen with Atta, Rice, Ghee & Oil at wholesale prices!',
    code: 'WEEKEND50',
    gradient: 'from-emerald-700 via-teal-700 to-green-600',
    type: 'festive',
    linkUrl: '/category/atta-rice-dal'
  }
]

// Instamart-Grade High-Impact Retina Designs
export const INSTAMART_PRO_DESIGNS = [
  {
    id: 'bappa-sweets',
    name: '🪔 FastKirana Exclusive Sweets',
    badge: 'FESTIVE SPECIAL',
    title: 'FastKirana Exclusive',
    description: 'Bappa Approved Sweets! Get modaks, laddoos, pedas & dry fruits.',
    code: 'FESTIVE10',
    imageUrl: '/banners/fastkirana-bappa-retina.png',
    linkUrl: '/search?q=sweets',
    gradient: 'from-rose-600 via-rose-500 to-orange-400',
    type: 'festival'
  },
  {
    id: 'puja-flowers',
    name: '🌸 Farm To Home Puja Flowers',
    badge: 'PUJA & MANDIR',
    title: 'Farm To Home Puja Flowers',
    description: 'The freshest marigold, rose petals & lotus for worship.',
    code: 'PUJA20',
    imageUrl: '/banners/puja-flowers.png',
    linkUrl: '/category/pooja-needs',
    gradient: 'from-amber-600 via-orange-500 to-yellow-500',
    type: 'fresh'
  },
  {
    id: 'weekend-savings',
    name: '🛍️ Weekend Kirana Super Savings',
    badge: 'SUPER SAVER',
    title: 'Weekend Kirana Super Savings',
    description: 'Stock up on Atta, Dal, Pure Desi Ghee & Edible Oils at wholesale prices!',
    code: 'WEEKEND50',
    imageUrl: '/banners/festive-deals-1.png',
    linkUrl: '/category/atta-rice-dal',
    gradient: 'from-emerald-700 via-teal-700 to-green-600',
    type: 'grocery'
  },
  {
    id: 'late-night-cravings',
    name: '🌙 Late Night Craving Remedies',
    badge: 'MIDNIGHT 10-MINS',
    title: 'Late Night Craving Remedies 🌙',
    description: 'Chips, Instant Noodles, Chocolates & Beverages under ₹49!',
    code: 'NIGHT49',
    imageUrl: '/banners/festive-deals-2.png',
    linkUrl: '/category/snacks-munchies',
    gradient: 'from-purple-800 via-indigo-800 to-slate-950',
    type: 'snacks'
  },
  {
    id: 'instant-pantry',
    name: '⚡ Instant Kitchen Pantry',
    badge: 'DAILY ESSENTIALS',
    title: 'Instant Kitchen Pantry & Essentials',
    description: 'Milk, Bread, Eggs, Butter, Spices & Cooking Pastes delivered in 10 mins.',
    code: 'FAST10',
    imageUrl: '/banners/banner-instant-5.png',
    linkUrl: '/category/dairy-breakfast',
    gradient: 'from-blue-600 via-indigo-600 to-cyan-500',
    type: 'first-order'
  }
]

// Multi-Card Hero, Bento & Editorial Category-Wise Presets (Food & Grocery)
export const MULTI_CARD_PRESETS = [
  // --- FOOD CATEGORY CARDS ---
  {
    id: 'food-burger-dark-hero',
    name: '🍔 Sizzling Burgers Hero Drop',
    badge: 'FOOD HERO',
    categoryType: 'food',
    targetCategory: 'burgers',
    cardType: 'dark_showcase',
    title: 'DOUBLE CHEESE BURGER',
    description: 'Crispy Patty • Melted Cheddar • Secret Garlic Dip',
    eyebrowTag: '🔥 CHEF SPECIAL DROP',
    primaryBrand: 'A.S. RESTAURANT',
    secondaryBrand: 'FAST BITES',
    imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
    hasWireframeGrid: true,
    cashbackTitle: 'FLAT 40% OFF',
    cashbackSubtitle: '+ Extra ₹50 on UPI Payment',
    ctaText: 'ORDER BURGERS',
    ctaUrl: '/restaurant/as-restaurant',
    ctaBgColorHex: '#EF4444',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Hot & crispy delivery in 15 mins across Ghatampur.',
    gradient: 'from-neutral-950 via-neutral-900 to-black',
  },
  {
    id: 'food-cuisines-bento-grid',
    name: '🍱 4-in-1 Food Cuisines Bento',
    badge: 'CUISINES COLLAGE',
    categoryType: 'food',
    targetCategory: 'fast-food',
    cardType: 'bento_grid',
    title: 'BEST FOOD SPOTS',
    description: 'Pizzas, Dum Biryani, Frankie Rolls & Thick Shakes',
    eyebrowTag: '🍽️ MOST ORDERED IN GHATAMPUR',
    gridImages: [
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
      'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
      'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80',
      'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80',
    ],
    cashbackTitle: 'UP TO 50% OFF',
    cashbackSubtitle: 'FastKirana Food Pass Exclusive Deals',
    ctaText: 'EXPLORE CUISINES',
    ctaUrl: '/category/fast-food',
    ctaBgColorHex: '#EA580C',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Delivered fresh from top verified kitchens.',
    gradient: 'from-slate-900 via-orange-950 to-slate-900',
  },
  {
    id: 'food-wedson-editorial',
    name: '🍛 Wedson Royal Kitchens Editorial',
    badge: 'ROYAL FEAST',
    categoryType: 'food',
    targetCategory: 'main-course',
    cardType: 'editorial',
    title: 'MIN. 50% OFF',
    description: 'Shahi Paneer, Dal Makhani & Butter Naan Feasts',
    eyebrowTag: '✨ ROYAL MUGHALAI FEAST',
    primaryBrand: 'WEDSON',
    imageUrl: 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80',
    cashbackTitle: '+ EXTRA ₹100 OFF',
    cashbackSubtitle: 'Use code WEDSON100 at checkout',
    ctaText: 'VIEW FULL MENU',
    ctaUrl: '/restaurant/wedson-restaurant',
    ctaBgColorHex: '#B91C1C',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Special family thalis & party packs.',
    gradient: 'from-amber-950 via-zinc-950 to-black',
  },

  // --- GROCERY CATEGORY CARDS ---
  {
    id: 'grocery-farm-fresh-hero',
    name: '🍎 Farm Fresh Harvest Hero Drop',
    badge: '100% ORGANIC',
    categoryType: 'grocery',
    targetCategory: 'fruits-vegetables',
    cardType: 'dark_showcase',
    title: 'FARM FRESH GREENS',
    description: 'Crisp Apples, Ripe Avocados & Hydroponic Veggies',
    eyebrowTag: '🌿 MORNING HARVEST',
    primaryBrand: 'FASTKIRANA',
    secondaryBrand: 'ORGANIC',
    imageUrl: 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80',
    hasWireframeGrid: true,
    cashbackTitle: 'FLAT 35% OFF',
    cashbackSubtitle: '+ 10-Min Morning Delivery in Ghatampur',
    ctaText: 'SHOP FRESH',
    ctaUrl: '/category/fruits-vegetables',
    ctaBgColorHex: '#10B981',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Handpicked daily from verified local farms.',
    gradient: 'from-emerald-950 via-neutral-900 to-black',
  },
  {
    id: 'grocery-essentials-bento-grid',
    name: '📦 Daily Essentials 4-in-1 Bento',
    badge: 'PANTRY 4-IN-1',
    categoryType: 'grocery',
    targetCategory: 'dairy-bread-eggs',
    cardType: 'bento_grid',
    title: 'HOUSEHOLD STAPLES',
    description: 'Dairy Milk, Farm Eggs, Atta & Cooking Oils',
    eyebrowTag: '⚡ 10-MIN EXPRESS PANTRY',
    gridImages: [
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
      'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
      'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80',
    ],
    cashbackTitle: 'UP TO 60% OFF',
    cashbackSubtitle: 'Zero Minimum Order Value Required',
    ctaText: 'STOCK UP PANTRY',
    ctaUrl: '/category/dairy-bread-eggs',
    ctaBgColorHex: '#3B82F6',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Guaranteed fresh batch or instant refund.',
    gradient: 'from-slate-900 via-blue-950 to-slate-900',
  },
  {
    id: 'grocery-snacks-editorial',
    name: '🍫 Snacks & Cravings Editorial',
    badge: 'CRAVINGS DEALS',
    categoryType: 'grocery',
    targetCategory: 'snacks-munchies',
    cardType: 'editorial',
    title: 'BUY 1 GET 1 FREE',
    description: 'Cadbury Silk, Lays Maxx, Ice Creams & Sodas',
    eyebrowTag: '🎉 CRAVINGS UNLOCKED',
    primaryBrand: 'SNACKMANIA',
    imageUrl: 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=800&q=80',
    cashbackTitle: '+ EXTRA 20% OFF',
    cashbackSubtitle: 'Use code SNACK20 at checkout',
    ctaText: 'GRAB SWEET DEALS',
    ctaUrl: '/category/snacks-munchies',
    ctaBgColorHex: '#6366F1',
    ctaTextColorHex: '#FFFFFF',
    disclaimerText: '*Delivered cold & chilled in thermal bags.',
    gradient: 'from-indigo-950 via-zinc-950 to-black',
  },
]

export type CardFormat = 'standard' | 'dark_showcase' | 'bento_grid' | 'editorial'

interface AdminVideoPreviewProps {
  src: string
  className?: string
  showControls?: boolean
}

function AdminVideoPreview({
  src,
  className = 'w-full h-full object-cover',
  showControls = true
}: AdminVideoPreviewProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isPlaying, setIsPlaying] = useState(true)

  const togglePlayPause = (e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (!videoRef.current) return
    if (videoRef.current.paused) {
      videoRef.current.play()
      setIsPlaying(true)
    } else {
      videoRef.current.pause()
      setIsPlaying(false)
    }
  }

  return (
    <div className="relative w-full h-full overflow-hidden group select-none">
      <video
        ref={videoRef}
        src={src}
        autoPlay
        loop
        muted
        playsInline
        className={className}
        onPlay={() => setIsPlaying(true)}
        onPause={() => setIsPlaying(false)}
      />
      {showControls && (
        <>
          {/* Pause / Play Floating Pill Button */}
          <button
            type="button"
            onClick={togglePlayPause}
            className="absolute bottom-2.5 right-2.5 z-30 flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/75 backdrop-blur-md border border-white/25 text-white shadow-lg cursor-pointer hover:bg-black/90 hover:scale-105 transition-all text-[9px] font-extrabold tracking-wider"
          >
            {isPlaying ? (
              <>
                <Pause className="h-2.5 w-2.5 fill-white text-white" />
                <span>PAUSE</span>
              </>
            ) : (
              <>
                <Play className="h-2.5 w-2.5 fill-white text-white" />
                <span>PLAY</span>
              </>
            )}
          </button>

          {/* Centered Big Play Indicator when paused */}
          {!isPlaying && (
            <button
              type="button"
              onClick={togglePlayPause}
              className="absolute inset-0 m-auto w-11 h-11 rounded-full bg-black/70 backdrop-blur-md border border-white/35 flex items-center justify-center text-white shadow-2xl cursor-pointer hover:scale-110 transition-transform"
            >
              <Play className="h-5 w-5 fill-white text-white ml-0.5" />
            </button>
          )}
        </>
      )}
    </div>
  )
}

interface AdminBannersProps {
  categories?: any[]
  products?: any[]
}

export function AdminBanners({ categories = [], products = [] }: AdminBannersProps) {
  const [banners, setBanners] = useState<PromoBanner[]>([])
  const [loading, setLoading] = useState(true)
  
  // Card Format Type
  const [cardFormat, setCardFormat] = useState<CardFormat>('standard')
  const [presetCategoryFilter, setPresetCategoryFilter] = useState<'all' | 'food' | 'grocery'>('all')
  const [isGeneratingGemini, setIsGeneratingGemini] = useState(false)

  // Placement & Target Platform States (Defaults to Brand Card for Curated Carousel)
  const [placement, setPlacement] = useState<'hero' | 'brand_card'>('brand_card')
  const [platform, setPlatform] = useState<'all' | 'mobile' | 'web'>('all')
  const [storeId, setStoreId] = useState<string>('all')

  // Registered List Filtering Tabs
  const [activeListTab, setActiveListTab] = useState<'hero' | 'brand_card'>('brand_card')
  const [activePlatformFilter, setActivePlatformFilter] = useState<'all' | 'mobile' | 'web'>('all')

  // Form States
  const [editingId, setEditingId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [code, setCode] = useState('')
  const [gradient, setGradient] = useState(GRADIENT_PRESETS[4].value)
  const [type, setType] = useState('grocery')
  const [imageUrl, setImageUrl] = useState('')
  const [videoUrl, setVideoUrl] = useState('')
  const [previewMediaTab, setPreviewMediaTab] = useState<'image' | 'video'>('image')
  const [previewDevice, setPreviewDevice] = useState<'mobile' | 'web'>('mobile')
  const [linkUrl, setLinkUrl] = useState('')
  const [linkType, setLinkType] = useState<'none' | 'category' | 'product' | 'restaurant' | 'custom'>('none')
  const [selectedCategory, setSelectedCategory] = useState('')
  const [selectedProduct, setSelectedProduct] = useState('')
  const [selectedRestaurant, setSelectedRestaurant] = useState('')
  const [customLinkUrl, setCustomLinkUrl] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [sortOrder, setSortOrder] = useState('0')
  const [submitting, setSubmitting] = useState(false)

  // Restaurants list for Food & Cafe mode
  const [restaurants, setRestaurants] = useState<any[]>([])

  // Multi-Card Specific Fields
  const [eyebrowTag, setEyebrowTag] = useState('')
  const [primaryBrand, setPrimaryBrand] = useState('')
  const [secondaryBrand, setSecondaryBrand] = useState('')
  const [hasWireframeGrid, setHasWireframeGrid] = useState(true)
  const [disclaimerText, setDisclaimerText] = useState('')
  const [ctaText, setCtaText] = useState('')
  const [ctaUrl, setCtaUrl] = useState('')
  const [ctaBgColorHex, setCtaBgColorHex] = useState('#FFFFFF')
  const [ctaTextColorHex, setCtaTextColorHex] = useState('#000000')
  const [cashbackTitle, setCashbackTitle] = useState('')
  const [cashbackSubtitle, setCashbackSubtitle] = useState('')
  const [gridImage1, setGridImage1] = useState('')
  const [gridImage2, setGridImage2] = useState('')
  const [gridImage3, setGridImage3] = useState('')
  const [gridImage4, setGridImage4] = useState('')

  // Cloudinary & Supabase Storage upload states
  const [settingsMap, setSettingsMap] = useState<Record<string, string>>({})
  const [isUploading, setIsUploading] = useState(false)
  const [isVideoUploading, setIsVideoUploading] = useState(false)

  // Load settings & restaurants on Mount
  useEffect(() => {
    async function fetchSettings() {
      try {
        const res = await fetch('/api/settings')
        if (res.ok) {
          const data = await res.json()
          setSettingsMap(data)
        }
      } catch (err) {
        console.error('Failed to load settings:', err)
      }
    }
    async function fetchRestaurants() {
      try {
        const res = await fetch('/api/restaurants')
        if (res.ok) {
          const data = await res.json()
          setRestaurants(Array.isArray(data) ? data : [])
        }
      } catch (err) {
        console.error('Failed to load restaurants:', err)
      }
    }
    fetchSettings()
    fetchRestaurants()
  }, [])

  // Load Banners on Mount
  const fetchBanners = async () => {
    try {
      setLoading(true)
      const res = await fetch('/api/admin/banners')
      if (!res.ok) throw new Error('Failed to load banners')
      const data = await res.json()
      setBanners(data || [])
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Could not load promo banners')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchBanners()
  }, [])

  // Core Image upload function (compresses & uploads to /api/upload)
  const uploadImageFile = async (file: File) => {
    setIsUploading(true)
    try {
      const compressedFile = await compressImageClient(file)
      const formData = new FormData()
      formData.append('file', compressedFile)

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        if (data.url) {
          setImageUrl(data.url)
          setPreviewMediaTab('image')
          toast.success('📸 Banner image uploaded successfully!')
        }
      } else {
        if (res.status === 413) {
          toast.error('Banner is too large (max 4.5MB). Please choose a smaller image.')
        } else if (res.status === 401) {
          toast.error('Unauthorized: Please log in again.')
        } else {
          const errData = await res.json().catch(() => ({}))
          toast.error(`Upload failed: ${errData.error || res.statusText || 'Server error'}`)
        }
      }
    } catch (err: any) {
      console.error(err)
      toast.error(`Could not upload image: ${err.message || 'Network error'}`)
    } finally {
      setIsUploading(false)
    }
  }

  // Core Video upload function (uploads video loop to Supabase Storage)
  const uploadVideoFile = async (file: File) => {
    if (file.size > 15 * 1024 * 1024) {
      toast.error('Video is too large (max 15MB). Please choose a shorter loop.')
      return
    }

    setIsVideoUploading(true)
    try {
      const formData = new FormData()
      formData.append('file', file)

      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      })

      if (res.ok) {
        const data = await res.json()
        if (data.url) {
          setVideoUrl(data.url)
          setPreviewMediaTab('video')
          toast.success('🎬 Video loop uploaded successfully!')
        }
      } else {
        const errData = await res.json().catch(() => ({}))
        toast.error(`Upload failed: ${errData.error || res.statusText || 'Server error'}`)
      }
    } catch (err: any) {
      console.error(err)
      toast.error(`Could not upload video: ${err.message || 'Network error'}`)
    } finally {
      setIsVideoUploading(false)
    }
  }

  // Handle file picker event for images
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    // If user selected a video file while on Image tab, auto-redirect to video upload
    if (file.type.startsWith('video/') || /\.(mp4|webm|mov)$/i.test(file.name)) {
      await uploadVideoFile(file)
    } else {
      await uploadImageFile(file)
    }
    e.target.value = ''
  }

  // Handle file picker event for videos
  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return
    // If user selected an image file while on Video tab, auto-redirect to image upload
    if (file.type.startsWith('image/') || /\.(jpg|jpeg|png|webp|gif|svg)$/i.test(file.name)) {
      await uploadImageFile(file)
    } else {
      await uploadVideoFile(file)
    }
    e.target.value = ''
  }

  // Unified Drag and Drop Handler
  const [isMediaDragOver, setIsMediaDragOver] = useState(false)
  const handleMediaDrop = async (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault()
    setIsMediaDragOver(false)
    const file = e.dataTransfer.files?.[0]
    if (!file) return

    const isVideoFile = file.type.startsWith('video/') || /\.(mp4|webm|mov)$/i.test(file.name)
    if (isVideoFile) {
      await uploadVideoFile(file)
    } else {
      await uploadImageFile(file)
    }
  }

  // Apply a Template
  const handleApplyTemplate = (tpl: any) => {
    setTitle(tpl.title || '')
    setDescription(tpl.description || '')
    setCode(tpl.code || '')
    setGradient(tpl.gradient || GRADIENT_PRESETS[4].value)
    setType(tpl.type || 'grocery')
    setImageUrl(tpl.imageUrl || '')
    setVideoUrl(tpl.videoUrl || '')
    
    // Check if it's a multi-card template
    if (tpl.cardType) {
      setCardFormat(tpl.cardType)
      setEyebrowTag(tpl.eyebrowTag || '')
      setPrimaryBrand(tpl.primaryBrand || '')
      setSecondaryBrand(tpl.secondaryBrand || '')
      setHasWireframeGrid(tpl.hasWireframeGrid ?? true)
      setDisclaimerText(tpl.disclaimerText || '')
      setCtaText(tpl.ctaText || '')
      setCtaUrl(tpl.ctaUrl || '')
      setCtaBgColorHex(tpl.ctaBgColorHex || '#FFFFFF')
      setCtaTextColorHex(tpl.ctaTextColorHex || '#000000')
      setCashbackTitle(tpl.cashbackTitle || '')
      setCashbackSubtitle(tpl.cashbackSubtitle || '')
      if (tpl.gridImages && Array.isArray(tpl.gridImages)) {
        setGridImage1(tpl.gridImages[0] || '')
        setGridImage2(tpl.gridImages[1] || '')
        setGridImage3(tpl.gridImages[2] || '')
        setGridImage4(tpl.gridImages[3] || '')
      }
    } else {
      setCardFormat('standard')
      setEyebrowTag('')
      setPrimaryBrand('')
      setSecondaryBrand('')
      setHasWireframeGrid(false)
      setDisclaimerText('')
      setCtaText('')
      setCtaUrl('')
      setCtaBgColorHex('#FFFFFF')
      setCtaTextColorHex('#000000')
      setCashbackTitle('')
      setCashbackSubtitle('')
      setGridImage1('')
      setGridImage2('')
      setGridImage3('')
      setGridImage4('')
    }

    const link = tpl.linkUrl || tpl.ctaUrl || ''
    setLinkUrl(link)
    if (!link) {
      setLinkType('none')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/category/')) {
      setLinkType('category')
      const slug = link.replace('/category/', '')
      setSelectedCategory(slug)
      setSelectedProduct('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/product/')) {
      setLinkType('product')
      const slug = link.replace('/product/', '')
      setSelectedCategory('')
      setSelectedProduct(slug)
      setCustomLinkUrl('')
    } else {
      setLinkType('custom')
      setSelectedCategory('')
      setSelectedProduct('')
      setCustomLinkUrl(link)
    }

    toast.success(`Design "${tpl.name}" loaded into editor!`)
  }

  // 1-Click Publish Design directly to Storefront
  const handlePublishDesignDirectly = async (tpl: any) => {
    try {
      setSubmitting(true)
      const res = await fetch('/api/admin/banners', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: tpl.title,
          description: tpl.description,
          code: tpl.code || '',
          gradient: tpl.gradient || GRADIENT_PRESETS[4].value,
          type: tpl.cardType ? tpl.cardType : (tpl.type || 'grocery'),
          cardType: tpl.cardType || 'standard',
          eyebrowTag: tpl.eyebrowTag || null,
          primaryBrand: tpl.primaryBrand || null,
          secondaryBrand: tpl.secondaryBrand || null,
          hasWireframeGrid: tpl.hasWireframeGrid ?? false,
          disclaimerText: tpl.disclaimerText || null,
          ctaText: tpl.ctaText || null,
          ctaUrl: tpl.ctaUrl || tpl.linkUrl || null,
          ctaBgColorHex: tpl.ctaBgColorHex || null,
          ctaTextColorHex: tpl.ctaTextColorHex || null,
          cashbackTitle: tpl.cashbackTitle || null,
          cashbackSubtitle: tpl.cashbackSubtitle || null,
          gridImages: tpl.gridImages || null,
          imageUrl: tpl.imageUrl || null,
          videoUrl: tpl.videoUrl || null,
          linkUrl: tpl.linkUrl || tpl.ctaUrl || null,
          isActive: true,
          sortOrder: 0
        })
      })

      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        throw new Error(err.error || 'Failed to publish banner')
      }

      toast.success(`🎉 "${tpl.name}" published live to storefront!`)
      fetchBanners()
    } catch (err: any) {
      toast.error(err.message || 'Failed to publish design')
    } finally {
      setSubmitting(false)
    }
  }

  // Generate Aesthetic Card Content with Google Gemini AI
  const handleGeminiGenerate = async (customCategory?: string) => {
    try {
      setIsGeneratingGemini(true)
      const targetCat = customCategory || selectedCategory || title || (type === 'food' ? 'Burgers & Fast Food' : 'Fresh Fruits & Vegetables')
      const targetType = type === 'food' ? 'food' : 'grocery'

      const res = await fetch('/api/admin/gemini-cards', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          categoryName: targetCat,
          categoryType: targetType,
          cardFormat: cardFormat === 'standard' ? 'dark_showcase' : cardFormat,
          outletName: primaryBrand || '',
        })
      })

      const data = await res.json()
      if (data.success && data.card) {
        const c = data.card
        if (cardFormat === 'standard') setCardFormat(c.cardType || 'dark_showcase')
        setTitle(c.discountTitle || title)
        setDescription(c.subtitle || description)
        setEyebrowTag(c.eyebrowTag || eyebrowTag)
        setPrimaryBrand(c.primaryBrand || primaryBrand)
        setSecondaryBrand(c.secondaryBrand || secondaryBrand)
        setDisclaimerText(c.disclaimerText || disclaimerText)
        setCtaText(c.ctaText || ctaText)
        setCtaBgColorHex(c.ctaBgColorHex || ctaBgColorHex)
        setCtaTextColorHex(c.ctaTextColorHex || ctaTextColorHex)
        setCashbackTitle(c.cashbackTitle || cashbackTitle)
        setCashbackSubtitle(c.cashbackSubtitle || cashbackSubtitle)
        if (c.imageUrl) setImageUrl(c.imageUrl)
        if (c.gridImages && c.gridImages.length >= 4) {
          setGridImage1(c.gridImages[0])
          setGridImage2(c.gridImages[1])
          setGridImage3(c.gridImages[2])
          setGridImage4(c.gridImages[3])
        }
        if (c.ctaUrl) {
          setCtaUrl(c.ctaUrl)
          setLinkUrl(c.ctaUrl)
        }
        toast.success(`✨ Gemini AI crafted aesthetic styling for "${c.discountTitle}"!`)
      } else {
        throw new Error(data.error || 'Failed to generate card')
      }
    } catch (err: any) {
      toast.error('Gemini AI error: ' + (err.message || 'Could not generate'))
    } finally {
      setIsGeneratingGemini(false)
    }
  }

  // Clear Form
  const resetForm = () => {
    setEditingId(null)
    setCardFormat('standard')
    setPlacement('hero')
    setPlatform('all')
    setStoreId('all')
    setTitle('')
    setDescription('')
    setCode('')
    setGradient(GRADIENT_PRESETS[4].value)
    setType('grocery')
    setImageUrl('')
    setVideoUrl('')
    setPreviewMediaTab('image')
    setLinkUrl('')
    setLinkType('none')
    setSelectedCategory('')
    setSelectedProduct('')
    setSelectedRestaurant('')
    setCustomLinkUrl('')
    setIsActive(true)
    setSortOrder('0')

    // Reset multi-card fields
    setEyebrowTag('')
    setPrimaryBrand('')
    setSecondaryBrand('')
    setHasWireframeGrid(true)
    setDisclaimerText('')
    setCtaText('')
    setCtaUrl('')
    setCtaBgColorHex('#FFFFFF')
    setCtaTextColorHex('#000000')
    setCashbackTitle('')
    setCashbackSubtitle('')
    setGridImage1('')
    setGridImage2('')
    setGridImage3('')
    setGridImage4('')
  }

  // Populate Edit Fields
  const handleEditClick = (b: PromoBanner) => {
    setEditingId(b.id)
    
    // Infer card format & placement
    let fmt: CardFormat = 'standard'
    if (b.cardType === 'dark_showcase' || b.type === 'dark_showcase') fmt = 'dark_showcase'
    else if (b.cardType === 'bento_grid' || b.type === 'bento_grid') fmt = 'bento_grid'
    else if (b.cardType === 'editorial' || b.type === 'editorial') fmt = 'editorial'
    setCardFormat(fmt)

    const isBrandCard = b.placement === 'brand_card' || ['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(b.type)
    setPlacement(isBrandCard ? 'brand_card' : 'hero')
    setActiveListTab(isBrandCard ? 'brand_card' : 'hero')
    setPlatform(b.platform || 'all')
    setStoreId(b.storeId || 'all')

    setTitle(b.title)
    setDescription(b.description)
    setCode(b.code || '')
    setGradient(b.gradient || GRADIENT_PRESETS[4].value)
    setType(b.type)
    setImageUrl(b.imageUrl || '')
    setVideoUrl(b.videoUrl || '')
    setPreviewMediaTab(b.videoUrl ? 'video' : 'image')
    setLinkUrl(b.linkUrl || '')
    
    // Populate multi-card fields
    setEyebrowTag(b.eyebrowTag || '')
    setPrimaryBrand(b.primaryBrand || '')
    setSecondaryBrand(b.secondaryBrand || '')
    setHasWireframeGrid(b.hasWireframeGrid ?? true)
    setDisclaimerText(b.disclaimerText || '')
    setCtaText(b.ctaText || '')
    setCtaUrl(b.ctaUrl || '')
    setCtaBgColorHex(b.ctaBgColorHex || '#FFFFFF')
    setCtaTextColorHex(b.ctaTextColorHex || '#000000')
    setCashbackTitle(b.cashbackTitle || '')
    setCashbackSubtitle(b.cashbackSubtitle || '')

    const gImages = Array.isArray(b.gridImages) ? b.gridImages : []
    setGridImage1(gImages[0] || '')
    setGridImage2(gImages[1] || '')
    setGridImage3(gImages[2] || '')
    setGridImage4(gImages[3] || '')

    const link = b.linkUrl || b.ctaUrl || ''
    if (!link) {
      setLinkType('none')
      setSelectedCategory('')
      setSelectedProduct('')
      setSelectedRestaurant('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/restaurant/')) {
      setLinkType('restaurant')
      const slug = link.replace('/restaurant/', '')
      setSelectedCategory('')
      setSelectedProduct('')
      setSelectedRestaurant(slug)
      setCustomLinkUrl('')
    } else if (link.startsWith('/category/')) {
      setLinkType('category')
      const slug = link.replace('/category/', '')
      setSelectedCategory(slug)
      setSelectedProduct('')
      setSelectedRestaurant('')
      setCustomLinkUrl('')
    } else if (link.startsWith('/product/')) {
      setLinkType('product')
      const slug = link.replace('/product/', '')
      setSelectedCategory('')
      setSelectedProduct(slug)
      setSelectedRestaurant('')
      setCustomLinkUrl('')
    } else {
      setLinkType('custom')
      setSelectedCategory('')
      setSelectedProduct('')
      setSelectedRestaurant('')
      setCustomLinkUrl(link)
    }

    setIsActive(b.isActive)
    setSortOrder(String(b.sortOrder))
    
    // Scroll form into view
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  // Handle Bento Slot upload
  const handleBentoSlotUpload = async (slotIndex: 1 | 2 | 3 | 4, file: File) => {
    try {
      const compressedFile = await compressImageClient(file)
      const formData = new FormData()
      formData.append('file', compressedFile)
      const res = await fetch('/api/upload', { method: 'POST', body: formData })
      if (res.ok) {
        const data = await res.json()
        if (data.url) {
          if (slotIndex === 1) setGridImage1(data.url)
          if (slotIndex === 2) setGridImage2(data.url)
          if (slotIndex === 3) setGridImage3(data.url)
          if (slotIndex === 4) setGridImage4(data.url)
          toast.success(`Slot ${slotIndex} image uploaded!`)
        }
      } else {
        toast.error('Upload failed')
      }
    } catch (err: any) {
      toast.error('Upload failed: ' + err.message)
    }
  }

  // Submit banner (Create or Edit)
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const finalTitle = title.trim() || (placement === 'brand_card' ? 'Curated Brand Offer' : 'Promo Banner')
    const finalDesc = description.trim() || (placement === 'brand_card' ? 'Curated Brand Media Card' : 'Media banner')

    if (!imageUrl.trim() && !videoUrl.trim() && !title.trim()) {
      toast.error(placement === 'brand_card' ? 'Please upload a photo or looping video for the Brand Card' : 'Please upload a photo or video for the banner')
      return
    }

    try {
      setSubmitting(true)

      let computedLinkUrl: string | null = null
      if (linkType === 'category') {
        computedLinkUrl = selectedCategory ? `/category/${selectedCategory}` : null
      } else if (linkType === 'product') {
        computedLinkUrl = selectedProduct ? `/product/${selectedProduct}` : null
      } else if (linkType === 'restaurant') {
        computedLinkUrl = selectedRestaurant ? `/restaurant/${selectedRestaurant}` : null
      } else if (linkType === 'custom') {
        computedLinkUrl = customLinkUrl.trim() || null
      }

      const gridImages = cardFormat === 'bento_grid'
        ? [gridImage1.trim(), gridImage2.trim(), gridImage3.trim(), gridImage4.trim()].filter(Boolean)
        : undefined

      const payload = {
        id: editingId || undefined,
        placement,
        platform,
        storeId: storeId === 'all' ? null : storeId,
        title: finalTitle,
        description: finalDesc,
        code: code.trim().toUpperCase(),
        gradient,
        type: cardFormat === 'standard' ? type : cardFormat,
        cardType: cardFormat,
        eyebrowTag: eyebrowTag.trim() || null,
        primaryBrand: primaryBrand.trim() || null,
        secondaryBrand: secondaryBrand.trim() || null,
        hasWireframeGrid,
        disclaimerText: disclaimerText.trim() || null,
        ctaText: ctaText.trim() || null,
        ctaUrl: ctaUrl.trim() || computedLinkUrl || null,
        ctaBgColorHex: ctaBgColorHex.trim() || null,
        ctaTextColorHex: ctaTextColorHex.trim() || null,
        cashbackTitle: cashbackTitle.trim() || null,
        cashbackSubtitle: cashbackSubtitle.trim() || null,
        gridImages: gridImages && gridImages.length > 0 ? gridImages : null,
        imageUrl: imageUrl.trim() || null,
        videoUrl: videoUrl.trim() || null,
        linkUrl: computedLinkUrl,
        isActive,
        sortOrder: parseInt(sortOrder, 10) || 0
      }

      const method = editingId ? 'PUT' : 'POST'
      const res = await fetch('/api/admin/banners', {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to save banner')
      }

      toast.success(editingId ? 'Banner updated successfully!' : 'New Banner created successfully!')
      resetForm()
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error saving banner details')
    } finally {
      setSubmitting(false)
    }
  }

  // Toggle banner Active state directly
  const handleToggleActive = async (b: PromoBanner) => {
    try {
      const res = await fetch('/api/admin/banners', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: b.id, isActive: !b.isActive })
      })

      if (!res.ok) throw new Error('Failed to update active state')
      
      toast.success(`Banner ${!b.isActive ? 'activated' : 'deactivated'} successfully!`)
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error toggling active state')
    }
  }

  // Change order priority
  const handleOrderChange = async (b: PromoBanner, direction: 'up' | 'down') => {
    const delta = direction === 'up' ? -1 : 1
    try {
      const res = await fetch('/api/admin/banners', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: b.id, sortOrder: b.sortOrder + delta })
      })

      if (!res.ok) throw new Error('Failed to update ordering priority')
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error changing banner order')
    }
  }

  // Delete banner
  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this promo banner?')) return

    try {
      const res = await fetch(`/api/admin/banners?id=${id}`, {
        method: 'DELETE'
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Failed to delete banner')
      }

      toast.success('Promo banner deleted successfully')
      fetchBanners()
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error deleting banner')
    }
  }

  return (
    <motion.div 
      initial={{ opacity: 0, y: 15 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -15 }}
      transition={{ duration: 0.35, ease: 'easeOut' }}
      className="grid grid-cols-1 lg:grid-cols-3 gap-6"
    >
      {/* Creation and Edit Panel */}
      <div className="lg:col-span-2 space-y-6">
        {/* Input Form */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          {/* Clean Simple Banner Form Header */}
          <h3 className="text-base font-bold text-text-primary flex items-center gap-2">
            <ImageIcon className="h-5 w-5 text-primary" />
            {editingId ? 'Edit Banner' : 'New Banner'}
          </h3>

          {/* Simple Form */}
          <form onSubmit={handleSubmit} className="space-y-4 bg-muted/20 border border-border p-5 rounded-2xl">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              
              {/* Placement / Mode / Platform / Store Hub Selectors */}
              <div className="md:col-span-2 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 p-3 bg-card border border-border/60 rounded-2xl">
                {/* 1. Placement Selector */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                    1. Section Type *
                  </label>
                  <div className="grid grid-cols-2 gap-1 bg-muted/50 p-1 rounded-xl border border-border">
                    <button
                      type="button"
                      onClick={() => setPlacement('hero')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        placement === 'hero'
                          ? 'bg-primary text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>🖼️</span>
                      <span>Hero Slider</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setPlacement('brand_card')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        placement === 'brand_card'
                          ? 'bg-primary text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>💳</span>
                      <span>Brand Card</span>
                    </button>
                  </div>
                </div>

                {/* 2. Target Mode Selector */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                    2. Store Mode *
                  </label>
                  <div className="grid grid-cols-2 gap-1 bg-muted/50 p-1 rounded-xl border border-border">
                    <button
                      type="button"
                      onClick={() => setType('grocery')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        type === 'grocery' || type === 'express-delivery'
                          ? 'bg-emerald-600 text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>🛍️</span>
                      <span>Grocery</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setType('food')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        type === 'food' || type === 'cafe'
                          ? 'bg-rose-500 text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>🍕</span>
                      <span>Food & Cafe</span>
                    </button>
                  </div>
                </div>

                {/* 3. Target Platform Selector */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                    3. Target Platform *
                  </label>
                  <div className="grid grid-cols-3 gap-1 bg-muted/50 p-1 rounded-xl border border-border">
                    <button
                      type="button"
                      onClick={() => setPlatform('all')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        platform === 'all'
                          ? 'bg-blue-600 text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>🌐</span>
                      <span>All</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setPlatform('mobile')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        platform === 'mobile'
                          ? 'bg-blue-600 text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>📱</span>
                      <span>App</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => setPlatform('web')}
                      className={`py-2 text-[11px] font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1 ${
                        platform === 'web'
                          ? 'bg-blue-600 text-white shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                      }`}
                    >
                      <span>💻</span>
                      <span>Web</span>
                    </button>
                  </div>
                </div>

                {/* 4. Target Store Hub Selector */}
                <div className="space-y-1.5">
                  <label className="text-[10px] font-black uppercase tracking-wider text-text-secondary block">
                    4. Target Hub / City *
                  </label>
                  <select
                    value={storeId}
                    onChange={(e) => setStoreId(e.target.value)}
                    className="w-full py-2.5 px-3 text-[11px] font-bold rounded-xl bg-card border border-border text-text-primary focus:outline-none focus:ring-1 focus:ring-primary shadow-xs cursor-pointer"
                  >
                    <option value="all">🌐 All Hubs (Global)</option>
                    <option value="store-ghatampur">🏪 Ghatampur Hub</option>
                    <option value="store-akbarpur">📍 Akbarpur Hub</option>
                  </select>
                </div>
              </div>


              
              {placement === 'brand_card' ? (
                /* BRAND CARD MODE: CLEAN, INTENTIONAL, PURE MEDIA ONLY */
                <div className="space-y-1.5 md:col-span-2">
                  <label className="text-xs font-bold text-text-primary flex items-center justify-between">
                    <span>Card / Brand Name *</span>
                    <span className="text-[11px] text-text-muted font-normal">
                      (e.g., A.S. Restaurant Burger, Amul Milk, Fresh Veggies)
                    </span>
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="Enter brand or card title..."
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-bold shadow-2xs"
                  />
                </div>
              ) : (
                /* HERO SLIDER MODE: FULL CONTROLS WITH SUBTITLE & PROMO CODE */
                <>
                  {/* Banner Title */}
                  <div className="space-y-1">
                    <label className="text-xs font-bold text-text-primary">
                      Banner Title *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Fast Delivery in Ghatampur"
                      value={title}
                      onChange={(e) => setTitle(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                    />
                  </div>

                  {/* Subtitle / Description */}
                  <div className="space-y-1">
                    <label className="text-xs font-bold text-text-primary">
                      Subtitle *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Milk, Fruits, Vegetables & Snacks in minutes"
                      value={description}
                      onChange={(e) => setDescription(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                  </div>

                  {/* Coupon Code (Optional) */}
                  <div className="space-y-1">
                    <label className="text-xs font-bold text-text-primary">
                      Promo Code
                    </label>
                    <div className="relative">
                      <Gift className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                      <input
                        type="text"
                        placeholder="e.g. SAVE20"
                        value={code}
                        onChange={(e) => setCode(e.target.value.toUpperCase())}
                        className="w-full bg-card border border-border pl-9 pr-4 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-mono font-bold text-primary"
                      />
                    </div>
                  </div>
                </>
              )}

              {/* Upload Banner Image / Video */}
              <div 
                onDragOver={(e) => { e.preventDefault(); setIsMediaDragOver(true) }}
                onDragLeave={() => setIsMediaDragOver(false)}
                onDrop={handleMediaDrop}
                className={`md:col-span-2 space-y-3 border border-border/80 bg-card p-4 rounded-2xl shadow-2xs transition-all ${
                  isMediaDragOver ? 'bg-primary/10 border-2 border-dashed border-primary ring-4 ring-primary/20' : ''
                }`}
              >
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-text-primary">
                    Banner Media *
                  </label>
                  <div className="flex items-center gap-1 bg-muted p-1 rounded-xl border border-border">
                    <button
                      type="button"
                      onClick={() => setPreviewMediaTab('image')}
                      className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                        previewMediaTab === 'image'
                          ? 'bg-card text-primary shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary'
                      }`}
                    >
                      🖼️ Photo
                    </button>
                    <button
                      type="button"
                      onClick={() => setPreviewMediaTab('video')}
                      className={`px-3 py-1 text-xs font-bold rounded-lg transition-all cursor-pointer ${
                        previewMediaTab === 'video'
                          ? 'bg-card text-primary shadow-xs font-black'
                          : 'text-text-muted hover:text-text-primary'
                      }`}
                    >
                      🎬 Video
                    </button>
                  </div>
                </div>

                {previewMediaTab === 'image' ? (
                  <div className="space-y-3">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3 items-center">
                      <label
                        htmlFor="banner-image-file-simple"
                        className="flex flex-col items-center justify-center w-full h-20 border-2 border-dashed border-border hover:border-primary rounded-xl cursor-pointer bg-muted/20 hover:bg-primary/5 transition-all p-3 text-center"
                      >
                        {isUploading ? (
                          <div className="flex items-center gap-2">
                            <Loader2 className="w-5 h-5 text-primary animate-spin" />
                            <span className="text-xs font-bold text-primary">Uploading...</span>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1.5 text-primary">
                            <UploadCloud className="w-5 h-5" />
                            <span className="text-xs font-bold">
                              {imageUrl ? 'Replace Photo' : 'Drop or Click to Upload'}
                            </span>
                          </div>
                        )}
                        <input
                          id="banner-image-file-simple"
                          type="file"
                          accept="image/*"
                          disabled={isUploading}
                          onChange={handleImageUpload}
                          className="sr-only"
                        />
                      </label>

                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-text-secondary block">Or paste image URL:</label>
                        <input
                          type="url"
                          placeholder="https://images.unsplash.com/..."
                          value={imageUrl}
                          onChange={(e) => setImageUrl(e.target.value)}
                          className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                        />
                      </div>
                    </div>

                    {/* Image Preview Box */}
                    {imageUrl && (
                      <div className="relative aspect-[3/1] max-h-40 w-full overflow-hidden rounded-xl border border-border bg-black/5 mt-2">
                        <img
                          src={imageUrl}
                          alt="Banner Preview"
                          className="object-contain w-full h-full"
                        />
                        <button
                          type="button"
                          onClick={() => setImageUrl('')}
                          className="absolute top-2 right-2 px-2.5 py-1 bg-rose-600 hover:bg-rose-700 text-white text-[10px] font-bold rounded-lg shadow cursor-pointer transition-all"
                        >
                          Remove Photo
                        </button>
                      </div>
                    )}
                  </div>
                ) : (
                  <div className="space-y-3">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-3 items-center">
                      <label
                        htmlFor="banner-video-file-simple"
                        className="flex flex-col items-center justify-center w-full h-20 border-2 border-dashed border-border hover:border-primary rounded-xl cursor-pointer bg-muted/20 hover:bg-primary/5 transition-all p-3 text-center"
                      >
                        {isVideoUploading ? (
                          <div className="flex items-center gap-2">
                            <Loader2 className="w-5 h-5 text-primary animate-spin" />
                            <span className="text-xs font-bold text-primary">Uploading...</span>
                          </div>
                        ) : (
                          <div className="flex items-center gap-1.5 text-primary">
                            <Video className="w-5 h-5" />
                            <span className="text-xs font-bold">
                              {videoUrl ? 'Replace Video' : 'Drop or Click to Upload'}
                            </span>
                          </div>
                        )}
                        <input
                          id="banner-video-file-simple"
                          type="file"
                          accept="video/mp4,video/webm,video/quicktime"
                          disabled={isVideoUploading}
                          onChange={handleVideoUpload}
                          className="sr-only"
                        />
                      </label>

                      <div className="space-y-1">
                        <label className="text-[11px] font-bold text-text-secondary block">Or paste video URL:</label>
                        <input
                          type="url"
                          placeholder="https://.../video-loop.mp4"
                          value={videoUrl}
                          onChange={(e) => {
                            setVideoUrl(e.target.value)
                            setPreviewMediaTab('video')
                          }}
                          className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                        />
                      </div>
                    </div>

                    {/* Video Preview Box with Pause/Play Button */}
                    {videoUrl && (
                      <div className="relative aspect-[3/1] max-h-44 w-full overflow-hidden rounded-xl border border-border bg-black mt-2">
                        <AdminVideoPreview src={videoUrl} className="object-contain w-full h-full" />
                        <button
                          type="button"
                          onClick={() => setVideoUrl('')}
                          className="absolute top-2 right-2 z-40 px-2.5 py-1 bg-rose-600 hover:bg-rose-700 text-white text-[10px] font-bold rounded-lg shadow cursor-pointer transition-all"
                        >
                          Remove Video
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </div>

              {/* Click Destination Box */}
              <div className="md:col-span-2 space-y-3 p-4 bg-card border border-border rounded-2xl shadow-2xs">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-text-primary flex items-center gap-1.5">
                    <LinkIcon className="h-3.5 w-3.5 text-primary" />
                    <span>Click Destination</span>
                  </label>
                  {linkType !== 'none' && (
                    <span className="text-[10px] font-mono px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 font-bold border border-emerald-500/20">
                      {linkType === 'restaurant' && selectedRestaurant && `🔗 /restaurant/${selectedRestaurant}`}
                      {linkType === 'category' && selectedCategory && `🔗 /category/${selectedCategory}`}
                      {linkType === 'product' && selectedProduct && `🔗 /product/${selectedProduct}`}
                      {linkType === 'custom' && customLinkUrl && `🔗 ${customLinkUrl}`}
                      {(!selectedRestaurant && !selectedCategory && !selectedProduct && !customLinkUrl) && 'Select an option below'}
                    </span>
                  )}
                </div>

                {/* Modern Pill Buttons */}
                <div className="grid grid-cols-2 sm:grid-cols-5 gap-1.5 bg-muted/40 p-1.5 rounded-xl border border-border">
                  <button
                    type="button"
                    onClick={() => {
                      setLinkType('restaurant')
                      if (!selectedRestaurant && restaurants.length > 0) setSelectedRestaurant(restaurants[0].slug)
                    }}
                    className={`py-2 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      linkType === 'restaurant'
                        ? 'bg-rose-500 text-white shadow-xs font-black'
                        : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                    }`}
                  >
                    🍽️ Restaurant
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setLinkType('category')
                      if (!selectedCategory && categories.length > 0) setSelectedCategory(categories[0].slug)
                    }}
                    className={`py-2 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      linkType === 'category'
                        ? 'bg-emerald-600 text-white shadow-xs font-black'
                        : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                    }`}
                  >
                    🏪 Category
                  </button>

                  <button
                    type="button"
                    onClick={() => {
                      setLinkType('product')
                      if (!selectedProduct && products.length > 0) setSelectedProduct(products[0].slug)
                    }}
                    className={`py-2 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      linkType === 'product'
                        ? 'bg-blue-600 text-white shadow-xs font-black'
                        : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                    }`}
                  >
                    📦 Product
                  </button>

                  <button
                    type="button"
                    onClick={() => setLinkType('custom')}
                    className={`py-2 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      linkType === 'custom'
                        ? 'bg-primary text-white shadow-xs font-black'
                        : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                    }`}
                  >
                    🔗 Custom Link
                  </button>

                  <button
                    type="button"
                    onClick={() => setLinkType('none')}
                    className={`py-2 px-2 text-xs font-bold rounded-lg transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                      linkType === 'none'
                        ? 'bg-zinc-700 text-white shadow-xs font-black'
                        : 'text-text-muted hover:text-text-primary hover:bg-card/60'
                    }`}
                  >
                    🚫 No Link
                  </button>
                </div>

                {/* Sub-Selector based on linkType */}
                {linkType === 'restaurant' && (
                  <div className="space-y-1 pt-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      Choose Partner Restaurant
                    </label>
                    <select
                      value={selectedRestaurant}
                      onChange={(e) => setSelectedRestaurant(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-rose-500 font-bold text-text-primary"
                    >
                      <option value="">-- Choose Restaurant --</option>
                      {restaurants.map((rest: any) => (
                        <option key={rest.id} value={rest.slug}>
                          {rest.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {linkType === 'category' && (
                  <div className="space-y-1 pt-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      Choose Grocery Category
                    </label>
                    <select
                      value={selectedCategory}
                      onChange={(e) => setSelectedCategory(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-emerald-500 font-bold text-text-primary"
                    >
                      <option value="">-- Choose Category --</option>
                      {categories.map((cat: any) => (
                        <option key={cat.id} value={cat.slug}>
                          {cat.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {linkType === 'product' && (
                  <div className="space-y-1 pt-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      Choose Specific Product
                    </label>
                    <select
                      value={selectedProduct}
                      onChange={(e) => setSelectedProduct(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs focus:outline-none focus:border-blue-500 font-bold text-text-primary"
                    >
                      <option value="">-- Choose Product --</option>
                      {products.map((prod: any) => (
                        <option key={prod.id} value={prod.slug}>
                          {prod.name}
                        </option>
                      ))}
                    </select>
                  </div>
                )}

                {linkType === 'custom' && (
                  <div className="space-y-1 pt-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                      Enter Custom Link or Search URL
                    </label>
                    <input
                      type="text"
                      placeholder="e.g. /search?q=icecream or https://..."
                      value={customLinkUrl}
                      onChange={(e) => setCustomLinkUrl(e.target.value)}
                      className="w-full bg-card border border-border px-3.5 py-2.5 rounded-xl text-xs font-semibold focus:outline-none focus:border-primary"
                    />
                  </div>
                )}

                {linkType === 'none' && (
                  <p className="text-[11px] text-text-muted font-medium italic pt-1">
                    Banner will show without any tap action.
                  </p>
                )}
              </div>

              {/* Bottom Action Bar */}
              <div className="md:col-span-2 flex flex-wrap items-center justify-between gap-3 pt-3 border-t border-border/40">
                <label className="flex items-center gap-2 text-xs font-black text-text-primary cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <span>Show Live on App & Storefront</span>
                </label>

                <div className="flex items-center gap-2">
                  {(editingId || title || imageUrl || videoUrl) && (
                    <button
                      type="button"
                      onClick={resetForm}
                      className="px-3.5 py-2 border border-border rounded-xl text-xs font-bold text-text-secondary hover:text-text-primary hover:bg-muted transition-all cursor-pointer"
                    >
                      {editingId ? 'Cancel Edit' : 'Clear Form'}
                    </button>
                  )}
                  <button
                    type="submit"
                    disabled={submitting}
                    className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-black text-xs transition-all flex items-center gap-2 shadow-md hover:shadow-lg cursor-pointer disabled:opacity-50 active:scale-98"
                  >
                    {submitting ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        <span>Saving...</span>
                      </>
                    ) : (
                      <>
                        <Check className="h-4 w-4" />
                        <span>{editingId ? 'Save Changes' : (placement === 'brand_card' ? '🚀 Save & Publish Brand Card' : '🚀 Save & Publish Banner')}</span>
                      </>
                    )}
                  </button>
                </div>
              </div>

            </div>
          </form>
        </div>
      </div>

      {/* Live Preview and Active Banners Sidebar */}
      <div className="space-y-6">
        
        {/* Dynamic Visual Live Preview Card */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-1.5">
              <Eye className="h-5 w-5 text-accent" />
              <h3 className="text-sm font-bold text-text-primary">Live Storefront Preview</h3>
            </div>

            {/* Mobile / Web Device Frame Switch */}
            <div className="flex items-center gap-1 bg-muted/40 p-1 rounded-xl border border-border/60">
              <button
                type="button"
                onClick={() => setPreviewDevice('mobile')}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black transition-all cursor-pointer flex items-center gap-1 ${
                  previewDevice === 'mobile'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                📱 Mobile App
              </button>
              <button
                type="button"
                onClick={() => setPreviewDevice('web')}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black transition-all cursor-pointer flex items-center gap-1 ${
                  previewDevice === 'web'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                💻 Web Store
              </button>
            </div>
          </div>
          
          {/* DEVICE PREVIEW CONTAINER */}
          <div className="w-full flex justify-center py-2 select-none">
            {previewDevice === 'mobile' ? (
              /* MOBILE IPHONE PREVIEW MOCKUP FRAME */
              <div className="w-[300px] bg-black p-3.5 rounded-[36px] shadow-2xl border-4 border-neutral-800 space-y-3 relative">
                {/* iPhone Dynamic Island notch */}
                <div className="w-24 h-3.5 bg-neutral-900 rounded-full mx-auto" />
                
                {/* App Header simulation */}
                <div className="flex items-center justify-between text-white text-[10px] px-1 font-bold">
                  <span>⚡ 10 Mins • Ghatampur</span>
                  <span className={`text-[8px] px-1.5 py-0.5 rounded font-mono uppercase font-black ${
                    type === 'food' || type === 'cafe'
                      ? 'bg-rose-500/20 text-rose-400 border border-rose-500/30'
                      : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                  }`}>
                    {type === 'food' || type === 'cafe' ? '🍕 FOOD' : '🛍️ GROCERY'}
                  </span>
                </div>

                {/* Hero Banner Slide Mockup */}
                {placement === 'hero' ? (
                  <div className="relative w-full h-[125px] rounded-2xl overflow-hidden bg-zinc-900 border border-white/10 shadow-lg">
                    {previewMediaTab === 'video' && videoUrl ? (
                      <AdminVideoPreview src={videoUrl} />
                    ) : imageUrl ? (
                      <img
                        src={imageUrl}
                        alt={title || "Banner Preview"}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex flex-col items-center justify-center p-3 text-center bg-zinc-900 text-zinc-400">
                        <ImageIcon className="h-6 w-6 text-zinc-600 mb-1" />
                        <span className="text-[10px] font-bold text-zinc-300">{title || 'Your Banner Here'}</span>
                        <span className="text-[8px] text-zinc-500">Upload Image or MP4 Video above</span>
                      </div>
                    )}

                    {/* Floating Counter Pill at Bottom Right */}
                    <div className="absolute bottom-2 right-2 z-20 flex flex-col items-center gap-0.5 bg-black/80 backdrop-blur-md px-2 py-0.5 rounded-full border border-white/20 text-white shadow-md">
                      <span className="text-[8px] font-black tracking-widest font-mono">1/1</span>
                      <div className="w-6 h-[2px] bg-gradient-to-r from-amber-400 to-rose-400 rounded-full" />
                    </div>
                  </div>
                ) : (
                  /* CuratedBrandOffersCarousel Mobile Shelf Mockup (Pure Media Card, No Text) */
                  <div className="space-y-1.5 text-left">
                    <div className="flex items-center justify-between px-1">
                      <span className="text-[10px] font-black text-white tracking-tight">Curated Brand Offers</span>
                      <span className="text-[8px] font-bold text-rose-400 font-mono">See All</span>
                    </div>

                    <div className="flex items-center gap-2 overflow-hidden py-1">
                      {/* Active Primary Brand Card (260x380 proportion) */}
                      <div className="relative w-[190px] h-[270px] rounded-[22px] overflow-hidden bg-neutral-900 border-2 border-white/15 shadow-2xl shrink-0 group">
                        {previewMediaTab === 'video' && videoUrl ? (
                          <AdminVideoPreview src={videoUrl} />
                        ) : imageUrl ? (
                          <img
                            src={imageUrl}
                            alt="Pure Brand Visual"
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex flex-col items-center justify-center p-3 text-center bg-zinc-900/90 text-zinc-400">
                            <ImageIcon className="h-8 w-8 text-zinc-600 mb-2" />
                            <span className="text-[11px] font-extrabold text-zinc-200">Pure Media Card</span>
                            <span className="text-[8px] text-zinc-400 mt-1">Upload Photo or Looping Video</span>
                            <span className="text-[7.5px] text-primary/80 font-bold mt-1 uppercase tracking-wider">No Text Overlay</span>
                          </div>
                        )}

                        {/* Subtle Luxury Corner Glint */}
                        <div className="absolute inset-0 rounded-[22px] border border-white/10 pointer-events-none" />
                      </div>

                      {/* Adjacent Peeking Card (Simulating Horizontal Scroll) */}
                      <div className="w-[65px] h-[270px] rounded-[22px] bg-zinc-900/40 border border-white/5 opacity-40 shrink-0 flex flex-col items-center justify-center">
                        <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center">
                          <Sparkles className="h-3 w-3 text-white/40" />
                        </div>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              /* WEB STOREFRONT DESKTOP PREVIEW MOCKUP FRAME */
              <div className="w-full bg-zinc-950 p-4 rounded-2xl shadow-xl border border-zinc-800 space-y-3">
                {/* Browser top bar simulation */}
                <div className="flex items-center justify-between border-b border-zinc-800 pb-2 text-[10px] text-zinc-400">
                  <div className="flex items-center gap-1.5">
                    <div className="h-2.5 w-2.5 rounded-full bg-red-500/80" />
                    <div className="h-2.5 w-2.5 rounded-full bg-yellow-500/80" />
                    <div className="h-2.5 w-2.5 rounded-full bg-green-500/80" />
                    <span className="font-mono text-[9px] text-zinc-500 ml-2">fastkirana.com</span>
                  </div>
                  <span className={`font-bold text-[9px] uppercase px-2 py-0.5 rounded border ${
                    type === 'food' || type === 'cafe'
                      ? 'bg-rose-500/10 text-rose-400 border-rose-500/20'
                      : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                  }`}>
                    {type === 'food' || type === 'cafe' ? '🍕 Food & Cafe Tab' : '🛍️ Grocery Tab'}
                  </span>
                </div>

                {/* Hero Banner Slide Mockup */}
                {placement === 'hero' ? (
                  <div className="relative w-full aspect-[3.2/1] rounded-2xl overflow-hidden bg-zinc-900 border border-white/10 shadow-lg">
                    {previewMediaTab === 'video' && videoUrl ? (
                      <AdminVideoPreview src={videoUrl} />
                    ) : imageUrl ? (
                      <img
                        src={imageUrl}
                        alt={title || "Banner Preview"}
                        className="w-full h-full object-cover"
                      />
                    ) : (
                      <div className="w-full h-full flex flex-col items-center justify-center p-4 text-center bg-zinc-900 text-zinc-400">
                        <ImageIcon className="h-7 w-7 text-zinc-600 mb-1" />
                        <span className="text-xs font-bold text-zinc-200">{title || 'Your Storefront Banner Preview'}</span>
                        <span className="text-[9px] text-zinc-500">Upload Image or MP4 Video above to see live preview</span>
                      </div>
                    )}

                    {/* Floating Counter Pill at Bottom Right */}
                    <div className="absolute bottom-3 right-3 z-20 flex flex-col items-center gap-1 bg-black/80 backdrop-blur-md px-3 py-1 rounded-full border border-white/20 text-white shadow-lg">
                      <span className="text-[10px] font-black tracking-widest font-mono">1/1</span>
                      <div className="w-8 h-[2px] bg-gradient-to-r from-amber-400 to-rose-400 rounded-full" />
                    </div>
                  </div>
                ) : (
                  /* Brand Card Web Carousel Mockup (Pure Media Card) */
                  <div className="space-y-2 text-left">
                    <div className="flex items-center justify-between px-1">
                      <span className="text-xs font-black text-white tracking-tight">Curated Brand Offers</span>
                      <span className="text-[10px] font-bold text-rose-400 font-mono">See All →</span>
                    </div>

                    <div className="flex items-center gap-3 overflow-hidden py-1">
                      {/* Active Pure Media Card (260x380 Proportion) */}
                      <div className="relative w-[210px] h-[290px] rounded-[24px] overflow-hidden bg-neutral-900 border-2 border-white/15 shadow-2xl shrink-0">
                        {previewMediaTab === 'video' && videoUrl ? (
                          <AdminVideoPreview src={videoUrl} />
                        ) : imageUrl ? (
                          <img
                            src={imageUrl}
                            alt="Pure Brand Visual"
                            className="w-full h-full object-cover"
                          />
                        ) : (
                          <div className="w-full h-full flex flex-col items-center justify-center p-4 text-center bg-zinc-900/90 text-zinc-400">
                            <ImageIcon className="h-9 w-9 text-zinc-600 mb-2" />
                            <span className="text-xs font-extrabold text-zinc-200">Pure Media Card</span>
                            <span className="text-[9px] text-zinc-400 mt-1">Upload Photo or Looping Video</span>
                            <span className="text-[8px] text-primary/80 font-bold mt-1 uppercase tracking-wider">No Text Overlay</span>
                          </div>
                        )}
                        <div className="absolute inset-0 rounded-[24px] border border-white/10 pointer-events-none" />
                      </div>

                      {/* Adjacent Peeking Cards */}
                      <div className="w-[120px] h-[290px] rounded-[24px] bg-zinc-900/40 border border-white/5 opacity-40 shrink-0 flex flex-col items-center justify-center">
                        <Sparkles className="h-5 w-5 text-white/30" />
                      </div>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Database Active Banners List */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col space-y-4">
          <div className="border-b border-border/60 pb-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <h4 className="text-sm font-bold text-text-primary">Registered Banners & Brand Cards</h4>
              <p className="text-[10px] text-text-muted">Manage active banners, target platforms & display placement.</p>
            </div>

            {/* Platform Sub-filter */}
            <div className="flex items-center gap-1 bg-muted/40 p-1 rounded-xl border border-border/60">
              <button
                type="button"
                onClick={() => setActivePlatformFilter('all')}
                className={`px-2 py-0.5 rounded-lg text-[9px] font-extrabold transition-all cursor-pointer ${
                  activePlatformFilter === 'all'
                    ? 'bg-card text-text-primary shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                🌐 All
              </button>
              <button
                type="button"
                onClick={() => setActivePlatformFilter('mobile')}
                className={`px-2 py-0.5 rounded-lg text-[9px] font-extrabold transition-all cursor-pointer ${
                  activePlatformFilter === 'mobile'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                📱 Mobile
              </button>
              <button
                type="button"
                onClick={() => setActivePlatformFilter('web')}
                className={`px-2 py-0.5 rounded-lg text-[9px] font-extrabold transition-all cursor-pointer ${
                  activePlatformFilter === 'web'
                    ? 'bg-primary text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                💻 Web
              </button>
            </div>
          </div>

          {/* Placement Tabs: Hero Slider Banners vs Brand Cards */}
          <div className="grid grid-cols-2 gap-2 bg-muted/40 p-1 rounded-xl border border-border/60">
            <button
              type="button"
              onClick={() => setActiveListTab('hero')}
              className={`py-2 px-3 rounded-lg text-xs font-black transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                activeListTab === 'hero'
                  ? 'bg-card text-primary shadow-sm border border-border'
                  : 'text-text-muted hover:text-text-primary'
              }`}
            >
              🖼️ Hero Slider Banners ({banners.filter(b => b.placement !== 'brand_card' && !['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(b.type)).length})
            </button>
            <button
              type="button"
              onClick={() => setActiveListTab('brand_card')}
              className={`py-2 px-3 rounded-lg text-xs font-black transition-all cursor-pointer flex items-center justify-center gap-1.5 ${
                activeListTab === 'brand_card'
                  ? 'bg-card text-primary shadow-sm border border-border'
                  : 'text-text-muted hover:text-text-primary'
              }`}
            >
              💳 Brand & Offer Cards ({banners.filter(b => b.placement === 'brand_card' || ['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(b.type)).length})
            </button>
          </div>

          {loading ? (
            <div className="py-12 flex items-center justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-accent" />
            </div>
          ) : (() => {
            const filteredBanners = banners.filter(b => {
              const isBrandCard = b.placement === 'brand_card' || ['dark_showcase', 'bento_grid', 'editorial', 'brand_offer'].includes(b.type)
              const matchesTab = activeListTab === 'brand_card' ? isBrandCard : !isBrandCard
              const bPlatform = b.platform || 'all'
              const matchesPlatform = activePlatformFilter === 'all' || bPlatform === 'all' || bPlatform === activePlatformFilter
              return matchesTab && matchesPlatform
            })

            if (filteredBanners.length === 0) {
              return (
                <div className="py-12 text-center text-xs text-text-secondary bg-muted/20 border border-dashed border-border rounded-xl">
                  No {activeListTab === 'hero' ? 'Hero Banners' : 'Brand Cards'} registered for {activePlatformFilter === 'all' ? 'All Devices' : activePlatformFilter} yet.
                </div>
              )
            }

            return (
              <div className="space-y-3 max-h-[450px] overflow-y-auto pr-1">
                <AnimatePresence initial={false}>
                  {filteredBanners.map((b) => (
                    <motion.div
                      key={b.id}
                      layout
                      initial={{ opacity: 0, scale: 0.95 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.95 }}
                      className={`p-3 border rounded-xl flex items-center justify-between gap-3 ${
                        b.isActive ? 'bg-card border-border' : 'bg-muted/10 border-border-light opacity-60'
                      }`}
                    >
                      <div className="min-w-0 flex-1 space-y-1">
                        <div className="flex items-center gap-1.5 flex-wrap">
                          <span className={`inline-block h-2 w-2 rounded-full ${b.isActive ? 'bg-accent' : 'bg-text-muted'}`} />
                          <strong className="text-xs text-text-primary block font-black truncate">{b.title}</strong>
                          
                          {/* Section Tag */}
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-primary/10 text-primary border border-primary/20">
                            {b.placement === 'brand_card' ? '💳 BRAND CARD' : '🖼️ HERO BANNER'}
                          </span>

                          {/* Mode Tag */}
                          <span className={`text-[8px] font-black uppercase px-1.5 py-0.5 rounded border ${
                            b.type === 'food' || b.type === 'cafe'
                              ? 'bg-rose-500/10 text-rose-500 border-rose-500/20'
                              : 'bg-emerald-500/10 text-emerald-600 border-emerald-500/20'
                          }`}>
                            {b.type === 'food' || b.type === 'cafe' ? '🍕 FOOD' : '🛍️ GROCERY'}
                          </span>

                          {/* Platform Badge */}
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-muted text-text-secondary border border-border">
                            {b.platform === 'mobile' ? '📱 MOBILE ONLY' : b.platform === 'web' ? '💻 WEB ONLY' : '🌐 ALL DEVICES'}
                          </span>

                          {/* Hub Badge */}
                          <span className={`text-[8px] font-black uppercase px-1.5 py-0.5 rounded border ${
                            b.storeId === 'store-akbarpur'
                              ? 'bg-purple-500/10 text-purple-600 border-purple-500/20'
                              : b.storeId === 'store-ghatampur'
                              ? 'bg-amber-500/10 text-amber-600 border-amber-500/20'
                              : 'bg-blue-500/10 text-blue-600 border-blue-500/20'
                          }`}>
                            {b.storeId === 'store-akbarpur' ? '📍 AKBARPUR' : b.storeId === 'store-ghatampur' ? '🏪 GHATAMPUR' : '🌐 ALL HUBS'}
                          </span>

                          {b.videoUrl && (
                            <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center gap-1">
                              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
                              MOTION VIDEO
                            </span>
                          )}
                        </div>
                        <div className="flex flex-wrap items-center gap-1.5 pt-0.5">
                          {b.code && (
                            <span className="text-[9px] font-bold text-text-secondary bg-muted/40 border px-1.5 py-0.5 rounded font-mono">
                              Code: {b.code}
                            </span>
                          )}
                          {b.ctaText && (
                            <span className="text-[9px] font-bold text-indigo-500 bg-indigo-500/10 border border-indigo-500/20 px-1.5 py-0.5 rounded font-mono">
                              CTA: {b.ctaText}
                            </span>
                          )}
                          {(b.linkUrl || b.ctaUrl) && (
                            <span className="text-[9px] font-bold text-accent bg-accent/5 border border-accent/10 px-1.5 py-0.5 rounded font-mono">
                              Link: {b.linkUrl || b.ctaUrl}
                            </span>
                          )}
                        </div>
                        <span className="text-[10px] text-text-muted block truncate">{b.description}</span>
                      </div>

                    <div className="flex items-center gap-1 shrink-0">
                      {/* Priority change buttons */}
                      <div className="flex flex-col gap-0.5">
                        <button
                          onClick={() => handleOrderChange(b, 'up')}
                          className="p-0.5 hover:bg-muted text-text-secondary rounded"
                          title="Move Up"
                        >
                          <ArrowUp className="h-3 w-3" />
                        </button>
                        <button
                          onClick={() => handleOrderChange(b, 'down')}
                          className="p-0.5 hover:bg-muted text-text-secondary rounded"
                          title="Move Down"
                        >
                          <ArrowDown className="h-3 w-3" />
                        </button>
                      </div>

                      {/* Active toggle */}
                      <button
                        onClick={() => handleToggleActive(b)}
                        className={`p-1.5 rounded-lg border transition-colors cursor-pointer ${
                          b.isActive 
                            ? 'bg-accent/10 border-accent/20 text-accent hover:bg-accent/20' 
                            : 'bg-muted/40 border-border text-text-secondary hover:bg-muted'
                        }`}
                        title={b.isActive ? 'Deactivate Banner' : 'Activate Banner'}
                      >
                        <Power className="h-3.5 w-3.5" />
                      </button>

                      {/* Edit */}
                      <button
                        onClick={() => handleEditClick(b)}
                        className="p-1.5 border border-border hover:bg-muted text-text-secondary hover:text-text-primary rounded-lg transition-colors cursor-pointer"
                        title="Edit Card Details"
                      >
                        <Edit2 className="h-3.5 w-3.5" />
                      </button>

                      {/* Delete */}
                      <button
                        onClick={() => handleDelete(b.id)}
                        className="p-1.5 border border-danger/20 bg-danger/5 hover:bg-danger/10 text-danger rounded-lg transition-colors cursor-pointer"
                        title="Delete Card"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )
          })()}
        </div>

      </div>
    </motion.div>
  )
}
