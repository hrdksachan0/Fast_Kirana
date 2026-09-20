'use client'

import { useState, useEffect } from 'react'
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
  Play
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

  // Form States
  const [editingId, setEditingId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [code, setCode] = useState('')
  const [gradient, setGradient] = useState(GRADIENT_PRESETS[4].value)
  const [type, setType] = useState('festival')
  const [imageUrl, setImageUrl] = useState('')
  const [videoUrl, setVideoUrl] = useState('')
  const [previewMediaTab, setPreviewMediaTab] = useState<'image' | 'video'>('image')
  const [linkUrl, setLinkUrl] = useState('')
  const [linkType, setLinkType] = useState<'none' | 'category' | 'product' | 'custom'>('none')
  const [selectedCategory, setSelectedCategory] = useState('')
  const [selectedProduct, setSelectedProduct] = useState('')
  const [customLinkUrl, setCustomLinkUrl] = useState('')
  const [isActive, setIsActive] = useState(true)
  const [sortOrder, setSortOrder] = useState('0')
  const [submitting, setSubmitting] = useState(false)

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

  // Load settings on Mount
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
    fetchSettings()
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

  // Handle Cloudinary direct upload
  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

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
          toast.success('Banner image uploaded successfully!')
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
      e.target.value = ''
    }
  }

  // Handle direct video upload to Supabase Storage
  const handleVideoUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    if (file.size > 10 * 1024 * 1024) {
      toast.error('Video is too large (max 10MB). Please choose a shorter loop.')
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
          toast.success('🎬 Video loop uploaded to Supabase Storage!')
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
      e.target.value = ''
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
    setTitle('')
    setDescription('')
    setCode('')
    setGradient(GRADIENT_PRESETS[4].value)
    setType('festival')
    setImageUrl('')
    setVideoUrl('')
    setPreviewMediaTab('image')
    setLinkUrl('')
    setLinkType('none')
    setSelectedCategory('')
    setSelectedProduct('')
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
    
    // Infer card format
    let fmt: CardFormat = 'standard'
    if (b.cardType === 'dark_showcase' || b.type === 'dark_showcase') fmt = 'dark_showcase'
    else if (b.cardType === 'bento_grid' || b.type === 'bento_grid') fmt = 'bento_grid'
    else if (b.cardType === 'editorial' || b.type === 'editorial') fmt = 'editorial'
    setCardFormat(fmt)

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
    if (!title.trim() || !description.trim()) {
      toast.error('Please fill in title and description')
      return
    }

    try {
      setSubmitting(true)

      let computedLinkUrl: string | null = null
      if (linkType === 'category') {
        computedLinkUrl = selectedCategory ? `/category/${selectedCategory}` : null
      } else if (linkType === 'product') {
        computedLinkUrl = selectedProduct ? `/product/${selectedProduct}` : null
      } else if (linkType === 'custom') {
        computedLinkUrl = customLinkUrl.trim() || null
      }

      const gridImages = cardFormat === 'bento_grid'
        ? [gridImage1.trim(), gridImage2.trim(), gridImage3.trim(), gridImage4.trim()].filter(Boolean)
        : undefined

      const payload = {
        id: editingId || undefined,
        title: title.trim(),
        description: description.trim(),
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
        
        {/* Curated Multi-Card Presets (Sneaker Street, Bento Grid, Editorial) */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 pb-3">
            <div>
              <div className="flex items-center gap-2">
                <LayoutGrid className="h-5 w-5 text-indigo-500 animate-pulse" />
                <h3 className="text-base font-black text-text-primary">
                  🔥 Category-Wise Multi-Cards (Food & Grocery Storefront)
                </h3>
                <span className="px-2 py-0.5 text-[9px] font-black uppercase tracking-wider rounded-full bg-indigo-500/15 text-indigo-600 dark:text-indigo-400 border border-indigo-500/30">
                  Ready to Publish
                </span>
              </div>
              <p className="text-[11px] text-text-secondary mt-0.5">
                Dynamic, aesthetic cards for Food (Burgers, Cuisines, Royal Meals) & Grocery (Fresh Harvest, Essentials, Snacks).
              </p>
            </div>

            {/* Category Filter Tabs */}
            <div className="flex items-center gap-1 bg-muted/40 p-1 rounded-xl border border-border/60">
              <button
                type="button"
                onClick={() => setPresetCategoryFilter('all')}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black transition-all cursor-pointer ${
                  presetCategoryFilter === 'all'
                    ? 'bg-card text-text-primary shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                All (6)
              </button>
              <button
                type="button"
                onClick={() => setPresetCategoryFilter('food')}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black transition-all cursor-pointer flex items-center gap-1 ${
                  presetCategoryFilter === 'food'
                    ? 'bg-rose-500 text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                🍔 Food Mode
              </button>
              <button
                type="button"
                onClick={() => setPresetCategoryFilter('grocery')}
                className={`px-2.5 py-1 rounded-lg text-[10px] font-black transition-all cursor-pointer flex items-center gap-1 ${
                  presetCategoryFilter === 'grocery'
                    ? 'bg-emerald-600 text-white shadow-xs'
                    : 'text-text-muted hover:text-text-primary'
                }`}
              >
                🛍️ Grocery Mode
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5 pt-1">
            {MULTI_CARD_PRESETS.filter(
              (tpl) => presetCategoryFilter === 'all' || (tpl as any).categoryType === presetCategoryFilter
            ).map((tpl) => (
              <div
                key={tpl.id}
                className="group relative rounded-2xl border border-border bg-card overflow-hidden shadow-sm hover:shadow-md hover:border-indigo-500/50 transition-all flex flex-col justify-between"
              >
                {/* Preview Graphic / Thumbnail */}
                <div className="relative aspect-[16/9] w-full overflow-hidden bg-neutral-900 flex items-center justify-center p-2">
                  {tpl.cardType === 'bento_grid' ? (
                    <div className="grid grid-cols-2 gap-1 w-full h-full">
                      {tpl.gridImages?.map((img, idx) => (
                        <div key={idx} className="relative rounded overflow-hidden bg-muted/30">
                          <img src={img} alt="" className="w-full h-full object-cover" />
                        </div>
                      ))}
                    </div>
                  ) : (
                    <img
                      src={tpl.imageUrl}
                      alt={tpl.name}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                  )}
                  <div className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-black/70 backdrop-blur-sm text-[8px] font-black text-white uppercase tracking-wider">
                    {tpl.badge}
                  </div>
                  <div className="absolute bottom-2 right-2 px-2 py-0.5 rounded-md bg-indigo-600 text-[8px] font-black text-white shadow-xs">
                    {tpl.ctaText}
                  </div>
                </div>

                {/* Details & Actions */}
                <div className="p-3 space-y-2 flex-1 flex flex-col justify-between">
                  <div>
                    <h4 className="text-xs font-black text-text-primary line-clamp-1">
                      {tpl.name}
                    </h4>
                    <p className="text-[10px] text-text-secondary line-clamp-2 mt-0.5 leading-snug">
                      {tpl.description}
                    </p>
                  </div>

                  <div className="pt-2 border-t border-border/40 flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => handlePublishDesignDirectly(tpl)}
                      disabled={submitting}
                      className="flex-1 py-1.5 px-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-[10px] font-black tracking-wide transition-all text-center cursor-pointer shadow-xs disabled:opacity-50"
                    >
                      ⚡ 1-Click Publish
                    </button>
                    <button
                      type="button"
                      onClick={() => handleApplyTemplate(tpl)}
                      className="py-1.5 px-2.5 rounded-xl border border-border bg-muted/30 hover:bg-muted text-text-primary text-[10px] font-bold transition-all text-center cursor-pointer"
                    >
                      ✏️ Edit
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Instamart Pro Designs Gallery */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-border/60 pb-3">
            <div>
              <div className="flex items-center gap-2">
                <Sparkles className="h-5 w-5 text-amber-500 animate-pulse" />
                <h3 className="text-base font-black text-text-primary">
                  Instamart Pro Banner Designs (2x Retina)
                </h3>
                <span className="px-2 py-0.5 text-[9px] font-black uppercase tracking-wider rounded-full bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30">
                  Ready to Publish
                </span>
              </div>
              <p className="text-[11px] text-text-secondary mt-0.5">
                Swiggy Instamart-grade festive banners with sunburst rays, product stages & instant 1-click publishing.
              </p>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5 pt-1">
            {INSTAMART_PRO_DESIGNS.map((tpl) => (
              <div
                key={tpl.id}
                className="group relative rounded-2xl border border-border bg-card overflow-hidden shadow-sm hover:shadow-md hover:border-primary/50 transition-all flex flex-col justify-between"
              >
                {/* Image Preview Container */}
                <div className="relative aspect-[16/9] w-full overflow-hidden bg-muted/40">
                  <img
                    src={tpl.imageUrl}
                    alt={tpl.name}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                  <div className="absolute top-2 left-2 px-2 py-0.5 rounded-md bg-black/60 backdrop-blur-sm text-[9px] font-black text-white uppercase tracking-wider">
                    {tpl.badge}
                  </div>
                  <div className="absolute bottom-2 right-2 px-2 py-0.5 rounded-md bg-primary text-[9px] font-black text-white shadow-xs">
                    Code: {tpl.code}
                  </div>
                </div>

                {/* Info & Action Buttons */}
                <div className="p-3 space-y-2 flex-1 flex flex-col justify-between">
                  <div>
                    <h4 className="text-xs font-black text-text-primary line-clamp-1">
                      {tpl.name}
                    </h4>
                    <p className="text-[10px] text-text-secondary line-clamp-2 mt-0.5 leading-snug">
                      {tpl.description}
                    </p>
                  </div>

                  <div className="pt-2 border-t border-border/40 flex items-center gap-1.5">
                    <button
                      type="button"
                      onClick={() => handlePublishDesignDirectly(tpl)}
                      disabled={submitting}
                      className="flex-1 py-1.5 px-2.5 rounded-xl bg-primary hover:bg-primary/90 text-primary-foreground text-[10px] font-black tracking-wide transition-all text-center cursor-pointer shadow-xs disabled:opacity-50"
                    >
                      ⚡ 1-Click Publish
                    </button>
                    <button
                      type="button"
                      onClick={() => handleApplyTemplate(tpl)}
                      className="py-1.5 px-2.5 rounded-xl border border-border bg-muted/30 hover:bg-muted text-text-primary text-[10px] font-bold transition-all text-center cursor-pointer"
                    >
                      ✏️ Edit
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* Quick Festival Gradient Templates Accordion */}
          <details className="pt-2 border-t border-border/50 group">
            <summary className="text-xs font-bold text-text-secondary cursor-pointer hover:text-text-primary transition-colors flex items-center justify-between">
              <span>🎨 Show Classic Gradient Templates (Diwali, Holi, Eid, Fresh...)</span>
              <span className="text-[10px] font-bold text-text-muted group-open:rotate-180 transition-transform">▼</span>
            </summary>
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-3">
              {FESTIVAL_TEMPLATES.map((tpl) => (
                <button
                  key={tpl.name}
                  type="button"
                  onClick={() => handleApplyTemplate(tpl)}
                  className="py-2 px-2.5 border border-border/80 text-[10px] font-bold rounded-xl bg-muted/20 hover:bg-primary/10 hover:border-primary hover:text-primary transition-all text-center leading-normal cursor-pointer"
                >
                  {tpl.name}
                </button>
              ))}
            </div>
          </details>
        </div>

        {/* Input Form */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
          {/* Clean Simple Banner Form Header */}
          <div>
            <h3 className="text-base font-bold text-text-primary flex items-center gap-2">
              <ImageIcon className="h-5 w-5 text-primary" />
              {editingId ? 'Edit Promo Banner' : 'Create New Promo Banner'}
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Upload a banner image, enter a title & link, and click Save. That's it!
            </p>
          </div>

          {/* Simple Form */}
          <form onSubmit={handleSubmit} className="space-y-4 bg-muted/20 border border-border p-5 rounded-2xl">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              
              {/* Banner Title */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                  Banner Title *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Fast Delivery in Ghatampur"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold"
                />
              </div>

              {/* Subtitle / Description */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                  Subtitle / Offer Text *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Milk, Fruits, Vegetables & Snacks in minutes"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                />
              </div>

              {/* Coupon Code (Optional) */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                  Promo Code (Optional)
                </label>
                <div className="relative">
                  <Gift className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
                  <input
                    type="text"
                    placeholder="e.g. SAVE20 (Leave blank if none)"
                    value={code}
                    onChange={(e) => setCode(e.target.value.toUpperCase())}
                    className="w-full bg-card border border-border pl-9 pr-4 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-mono font-bold text-primary"
                  />
                </div>
              </div>

              {/* Background Gradient Theme */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                  Card Theme / Color
                </label>
                <select
                  value={gradient}
                  onChange={(e) => setGradient(e.target.value)}
                  className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                >
                  {GRADIENT_PRESETS.map((g) => (
                    <option key={g.name} value={g.value}>
                      {g.name}
                    </option>
                  ))}
                </select>
              </div>

              {/* Upload Banner Image */}
              <div className="md:col-span-2 space-y-2 border-t border-border/40 pt-3">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary block">
                  Banner Image (Upload or Paste Link)
                </label>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3 items-center">
                  <label
                    htmlFor="banner-image-file-simple"
                    className="flex flex-col items-center justify-center w-full h-20 border-2 border-dashed border-border hover:border-primary rounded-xl cursor-pointer bg-card hover:bg-primary/5 transition-all"
                  >
                    {isUploading ? (
                      <div className="flex items-center gap-2">
                        <Loader2 className="w-5 h-5 text-primary animate-spin" />
                        <span className="text-xs font-bold text-primary">Uploading...</span>
                      </div>
                    ) : (
                      <div className="flex items-center gap-2">
                        <ImageIcon className="w-5 h-5 text-primary" />
                        <span className="text-xs font-bold text-text-primary">
                          {imageUrl ? 'Change Image File' : 'Click to Upload Image'}
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
                    <input
                      type="url"
                      placeholder="Or paste Image URL (https://...)"
                      value={imageUrl}
                      onChange={(e) => setImageUrl(e.target.value)}
                      className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-medium"
                    />
                  </div>
                </div>

                {/* Image Preview Box */}
                {imageUrl && (
                  <div className="relative aspect-[3/1] max-h-36 w-full overflow-hidden rounded-xl border border-border bg-black/5 mt-2">
                    <img
                      src={imageUrl}
                      alt="Banner Preview"
                      className="object-contain w-full h-full"
                    />
                    <button
                      type="button"
                      onClick={() => setImageUrl('')}
                      className="absolute top-2 right-2 px-2 py-1 bg-rose-600 text-white text-[10px] font-bold rounded-lg shadow cursor-pointer"
                    >
                      Remove Image
                    </button>
                  </div>
                )}
              </div>

              {/* Banner Click Target */}
              <div className="space-y-1 border-t border-border/40 pt-3">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                  On Banner Click: Where to go?
                </label>
                <select
                  value={linkType}
                  onChange={(e) => {
                    const val = e.target.value as any
                    setLinkType(val)
                    if (val === 'category' && !selectedCategory && categories.length > 0) {
                      setSelectedCategory(categories[0].slug)
                    }
                    if (val === 'product' && !selectedProduct && products.length > 0) {
                      setSelectedProduct(products[0].slug)
                    }
                  }}
                  className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-semibold"
                >
                  <option value="none">No Link (Just Display)</option>
                  <option value="category">Open Store Category</option>
                  <option value="product">Open Specific Product</option>
                  <option value="custom">Custom Link / Route</option>
                </select>
              </div>

              {/* Destination Selector */}
              <div className="border-t border-border/40 pt-3">
                {linkType === 'category' && (
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Select Category</label>
                    <select
                      value={selectedCategory}
                      onChange={(e) => setSelectedCategory(e.target.value)}
                      className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-primary"
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
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Select Product</label>
                    <select
                      value={selectedProduct}
                      onChange={(e) => setSelectedProduct(e.target.value)}
                      className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary font-bold text-primary"
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
                  <div className="space-y-1">
                    <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Paste Link URL</label>
                    <input
                      type="text"
                      placeholder="e.g. /restaurant/as-restaurant"
                      value={customLinkUrl}
                      onChange={(e) => setCustomLinkUrl(e.target.value)}
                      className="w-full bg-card border border-border px-3 py-2 rounded-xl text-xs font-semibold"
                    />
                  </div>
                )}

                {linkType === 'none' && (
                  <div className="text-[11px] text-text-muted pt-2 font-medium">
                    Banner show hoga lekin click par kahi nahi jayega.
                  </div>
                )}
              </div>

              {/* Active Switch */}
              <div className="md:col-span-2 flex items-center justify-between pt-3 border-t border-border/40">
                <label className="flex items-center gap-2 text-xs font-black text-text-primary cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                  />
                  <span>Show Live on App & Storefront</span>
                </label>

                <div className="flex items-center gap-2">
                  {editingId && (
                    <button
                      type="button"
                      onClick={resetForm}
                      className="px-3 py-1.5 border border-border rounded-xl text-xs font-bold hover:bg-muted transition-all cursor-pointer"
                    >
                      Cancel Edit
                    </button>
                  )}
                  <button
                    type="submit"
                    disabled={submitting}
                    className="px-6 py-2.5 rounded-xl bg-primary hover:bg-primary-dark text-white font-black text-xs transition-all flex items-center gap-1.5 shadow-md cursor-pointer disabled:opacity-50 active:scale-98"
                  >
                    {submitting ? (
                      <>
                        <Loader2 className="h-4 w-4 animate-spin" />
                        Saving...
                      </>
                    ) : (
                      <>
                        <Check className="h-4 w-4" />
                        {editingId ? 'Save Changes' : '🚀 Save & Publish Banner'}
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
            <span className="text-[9px] font-black uppercase px-2 py-0.5 rounded-full bg-accent/10 text-accent border border-accent/20">
              {cardFormat === 'dark_showcase' ? 'Sneaker Drop' :
               cardFormat === 'bento_grid' ? 'Bento 2x2' :
               cardFormat === 'editorial' ? 'Editorial HRX' :
               'Standard Banner'}
            </span>
          </div>
          
          <div className="relative w-full overflow-hidden rounded-2xl shadow-lg border border-border select-none bg-muted/20">
            {/* 1. DARK SNEAKER HERO PREVIEW */}
            {cardFormat === 'dark_showcase' ? (
              <div className="relative w-full min-h-[220px] p-4 bg-neutral-950 text-white flex flex-col justify-between overflow-hidden">
                {/* Wireframe background grid simulation */}
                {hasWireframeGrid && (
                  <div className="absolute inset-0 opacity-20 pointer-events-none [background:radial-gradient(#404040_1px,transparent_1px)] [background-size:16px_16px]" />
                )}
                
                {/* Top bar: Eyebrow + Brand */}
                <div className="relative z-10 flex items-center justify-between gap-2">
                  <span className="px-2 py-0.5 rounded-full bg-lime-400 text-black font-black text-[9px] uppercase tracking-wider shadow-sm">
                    {eyebrowTag || 'LIMITED DROP'}
                  </span>
                  <span className="text-[10px] font-black tracking-widest text-neutral-400 uppercase">
                    {primaryBrand || 'NIKE'} {secondaryBrand ? `• ${secondaryBrand}` : ''}
                  </span>
                </div>

                {/* Center: Floating Sneaker Image & Headline */}
                <div className="relative z-10 my-2 flex items-center justify-between gap-3">
                  <div className="space-y-1 max-w-[60%]">
                    <h4 className="text-base font-black tracking-tight leading-tight uppercase line-clamp-1 text-white">
                      {title || "AIR FORCE 1 '07"}
                    </h4>
                    <p className="text-[10px] text-neutral-400 font-medium line-clamp-2 leading-tight">
                      {description || 'Iconic Street Style • Triple White Leather'}
                    </p>
                  </div>
                  <div className="w-24 h-20 relative flex items-center justify-center shrink-0 rounded-lg overflow-hidden">
                    {previewMediaTab === 'video' && videoUrl ? (
                      <video
                        src={videoUrl}
                        autoPlay
                        loop
                        muted
                        playsInline
                        className="w-full h-full object-cover rounded-lg"
                      />
                    ) : (
                      <img
                        src={imageUrl || 'https://images.unsplash.com/photo-1595950653106-6c9ebd614d3a?w=400&q=80'}
                        alt=""
                        className="max-h-full max-w-full object-contain drop-shadow-[0_10px_10px_rgba(0,0,0,0.8)]"
                      />
                    )}
                  </div>
                </div>

                {/* Bottom bar: Cashback + CTA Pill */}
                <div className="relative z-10 pt-2 border-t border-neutral-800 flex items-center justify-between gap-2">
                  <div className="leading-none">
                    <span className="text-[10px] font-black text-amber-400 block">{cashbackTitle || 'FLAT 40% OFF'}</span>
                    <span className="text-[8px] text-neutral-500 font-bold">{cashbackSubtitle || '+ Extra 10% on UPI'}</span>
                  </div>
                  <button
                    type="button"
                    style={{
                      backgroundColor: ctaBgColorHex || '#FFFFFF',
                      color: ctaTextColorHex || '#000000'
                    }}
                    className="px-3 py-1 rounded-full text-[10px] font-black tracking-wider shadow-sm uppercase cursor-default"
                  >
                    {ctaText || 'EXPLORE NOW'}
                  </button>
                </div>

                {disclaimerText && (
                  <p className="text-[7px] text-neutral-600 mt-1 truncate">{disclaimerText}</p>
                )}
              </div>
            ) : cardFormat === 'bento_grid' ? (
              /* 2. 2X2 BENTO GRID PREVIEW */
              <div className="relative w-full min-h-[220px] p-4 bg-slate-900 text-white flex flex-col justify-between overflow-hidden">
                {/* Top row */}
                <div className="flex items-center justify-between gap-2 mb-2">
                  <div className="space-y-0.5">
                    <span className="px-2 py-0.5 rounded-full bg-indigo-500 text-white font-black text-[8px] uppercase tracking-wider inline-block">
                      {eyebrowTag || 'PRIME MEMBERS ONLY'}
                    </span>
                    <h4 className="text-xs font-black tracking-tight text-white line-clamp-1">
                      {title || 'TOP PICKS FOR YOU'}
                    </h4>
                  </div>
                </div>

                {/* 2x2 Bento Photo Quadrant */}
                <div className="grid grid-cols-2 gap-1.5 my-1">
                  {[
                    gridImage1 || 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&q=80',
                    gridImage2 || 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=300&q=80',
                    gridImage3 || 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=300&q=80',
                    gridImage4 || 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=300&q=80'
                  ].map((img, i) => (
                    <div key={i} className="aspect-[4/3] rounded-lg overflow-hidden bg-slate-800 border border-slate-700/50">
                      <img src={img} alt="" className="w-full h-full object-cover" />
                    </div>
                  ))}
                </div>

                {/* Bottom bar: Cashback + CTA */}
                <div className="pt-2 border-t border-slate-800 flex items-center justify-between gap-2">
                  <div className="leading-none">
                    <span className="text-[10px] font-black text-indigo-400 block">{cashbackTitle || 'UP TO 60% OFF'}</span>
                    <span className="text-[8px] text-slate-400 font-bold truncate max-w-[120px] block">{cashbackSubtitle || 'Prime Exclusive'}</span>
                  </div>
                  <button
                    type="button"
                    style={{
                      backgroundColor: ctaBgColorHex || '#4F46E5',
                      color: ctaTextColorHex || '#FFFFFF'
                    }}
                    className="px-3 py-1 rounded-full text-[9px] font-black tracking-wider shadow-sm uppercase cursor-default"
                  >
                    {ctaText || 'VIEW ALL 4 DEALS'}
                  </button>
                </div>
              </div>
            ) : cardFormat === 'editorial' ? (
              /* 3. EDITORIAL HRX PREVIEW */
              <div className="relative w-full min-h-[200px] p-4 bg-gradient-to-br from-red-950 via-zinc-950 to-black text-white flex flex-col justify-between overflow-hidden border border-red-900/30">
                <div className="flex items-center justify-between gap-2">
                  <span className="px-2 py-0.5 rounded-md bg-rose-600/30 border border-rose-500/50 text-rose-300 font-black text-[8px] uppercase tracking-widest">
                    {eyebrowTag || 'SPECIAL EDITION'}
                  </span>
                </div>

                <div className="my-2 flex items-center justify-between gap-2">
                  <div className="space-y-1">
                    <h3 className="text-xl font-black tracking-tighter text-white uppercase leading-none">
                      {title || 'MIN. 80% OFF'}
                    </h3>
                    {cashbackTitle && (
                      <span className="inline-block px-2 py-0.5 bg-rose-600 text-white font-black text-[9px] rounded uppercase">
                        {cashbackTitle}
                      </span>
                    )}
                    <p className="text-[9px] text-zinc-400 line-clamp-1">{description || 'Activewear, Trainers & Athleisure'}</p>
                  </div>
                  {(imageUrl || videoUrl) && (
                    <div className="w-20 h-20 rounded-lg overflow-hidden shrink-0 border border-rose-900/40">
                      {previewMediaTab === 'video' && videoUrl ? (
                        <video
                          src={videoUrl}
                          autoPlay
                          loop
                          muted
                          playsInline
                          className="w-full h-full object-cover"
                        />
                      ) : imageUrl ? (
                        <img src={imageUrl} alt="" className="w-full h-full object-cover" />
                      ) : null}
                    </div>
                  )}
                </div>

                <div className="pt-2 border-t border-zinc-800/80 flex items-center justify-between gap-2">
                  <span className="text-[8px] text-zinc-400 font-mono">{cashbackSubtitle || '*Terms apply'}</span>
                  <button
                    type="button"
                    style={{
                      backgroundColor: ctaBgColorHex || '#EF4444',
                      color: ctaTextColorHex || '#FFFFFF'
                    }}
                    className="px-3 py-1 rounded-full text-[9px] font-black tracking-wider shadow-sm uppercase cursor-default"
                  >
                    {ctaText || 'SHOP HRX SALE'}
                  </button>
                </div>
              </div>
            ) : (
              /* 4. STANDARD BANNER PREVIEW */
              (imageUrl || videoUrl) ? (
                <div className="relative aspect-[16/9] w-full overflow-hidden">
                  {previewMediaTab === 'video' && videoUrl ? (
                    <video
                      src={videoUrl}
                      autoPlay
                      loop
                      muted
                      playsInline
                      className="w-full h-full object-cover"
                    />
                  ) : imageUrl ? (
                    <img
                      src={imageUrl}
                      alt={title || "Custom Graphic Banner"}
                      className="w-full h-full object-cover"
                    />
                  ) : null}
                </div>
              ) : type === 'express-delivery' ? (
                <div className="h-[140px] flex items-center justify-between p-4 bg-[#fdf0f1] text-[#2d2d2d]">
                  <div className="text-left space-y-0.5">
                    <span className="text-[8px] font-black text-[#e20a22] uppercase tracking-wider block">Fast Delivery in</span>
                    <h4 className="text-sm font-black text-[#e20a22] tracking-tight leading-tight">{title || SERVICE_AREA_NAME}</h4>
                    <p className="text-[9px] text-[#4d4d4d] font-bold line-clamp-1">{description || 'Milk, Fruits, Vegetables, Snacks & more'}</p>
                  </div>
                  <div className="text-2xl pr-2">🛍️</div>
                </div>
              ) : (
                <div className={`h-[140px] flex flex-col justify-center p-4 text-white bg-gradient-to-br ${gradient}`}>
                  <div className="space-y-1">
                    {code.trim() && (
                      <span className="inline-flex items-center gap-1 bg-white/15 border border-white/20 px-2 py-0.5 rounded-full text-[9px] font-extrabold tracking-wide max-w-max">
                        <Gift className="h-2.5 w-2.5" />
                        Use Code: {code}
                      </span>
                    )}
                    <h4 className="text-sm font-black tracking-tight leading-tight line-clamp-1">
                      {title || 'Festive Sale Banner'}
                    </h4>
                    <p className="text-[10px] text-white/80 font-medium line-clamp-2 leading-relaxed">
                      {description || 'Offer details will appear here as you type...'}
                    </p>
                  </div>
                  <div className="absolute right-3 bottom-3 text-2xl opacity-40">
                    {type === 'festival' && '🪔'}
                    {type === 'first-order' && '🥛'}
                    {type === 'fresh' && '🥬'}
                    {type === 'snacks' && '🥤'}
                    {type === 'custom' && '📦'}
                  </div>
                </div>
              )
            )}
          </div>
        </div>

        {/* Database Active Banners List */}
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col">
          <div className="border-b border-border/60 pb-3 mb-4">
            <h4 className="text-sm font-bold text-text-primary">Currently Registered Cards & Banners</h4>
            <p className="text-[10px] text-text-muted">Edit, reorder, toggle active, or delete promotional cards.</p>
          </div>

          {loading ? (
            <div className="py-12 flex items-center justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-accent" />
            </div>
          ) : banners.length === 0 ? (
            <div className="py-12 text-center text-xs text-text-secondary">
              No banners or cards registered in database yet.
            </div>
          ) : (
            <div className="space-y-3 max-h-[450px] overflow-y-auto pr-1">
              <AnimatePresence initial={false}>
                {banners.map((b) => (
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
                        {b.cardType === 'dark_showcase' ? (
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-neutral-900 text-amber-400 border border-amber-500/30">
                            👟 SNEAKER HERO
                          </span>
                        ) : b.cardType === 'bento_grid' ? (
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-400 border border-indigo-500/30">
                            📦 BENTO 2X2
                          </span>
                        ) : b.cardType === 'editorial' ? (
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-rose-500/20 text-rose-400 border border-rose-500/30">
                            🕶️ EDITORIAL
                          </span>
                        ) : (
                          <span className="text-[8px] font-black uppercase px-1.5 py-0.5 rounded bg-muted text-text-secondary border border-border">
                            🖼️ BANNER
                          </span>
                        )}
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
          )}
        </div>

      </div>
    </motion.div>
  )
}
