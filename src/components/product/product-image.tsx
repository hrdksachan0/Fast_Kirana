'use client'

import { useState, useEffect, useRef } from 'react'
import { Salad, Milk, Cookie, CupSoda, Sparkles, Home, Croissant, Wheat, ShoppingBag } from 'lucide-react'

const iconMap: Record<string, React.ComponentType<any>> = {
  'fruits-vegetables': Salad,
  'dairy-breakfast': Milk,
  'snacks-munchies': Cookie,
  'beverages': CupSoda,
  'personal-care': Sparkles,
  'household': Home,
  'bakery-biscuits': Croissant,
  'atta-rice-dal': Wheat,
}

const unsplashMap: Record<string, string> = {
  // Fruits & Vegetables
  'banana': 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=300&h=300&fit=crop&q=80',
  'apple': 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?w=300&h=300&fit=crop&q=80',
  'onion': 'https://images.unsplash.com/photo-1618220179428-22790b461013?w=300&h=300&fit=crop&q=80',
  'tomato': 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=300&h=300&fit=crop&q=80',
  'potato': 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=300&h=300&fit=crop&q=80',
  'chilli': 'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=300&h=300&fit=crop&q=80',
  'coriander': 'https://images.unsplash.com/photo-1608797178974-15b35a61d121?w=300&h=300&fit=crop&q=80',
  'cucumber': 'https://images.unsplash.com/photo-1604977042946-1eecc30f269e?w=300&h=300&fit=crop&q=80',
  'mango': 'https://images.unsplash.com/photo-1553279768-865429fa0078?w=300&h=300&fit=crop&q=80',
  'lemon': 'https://images.unsplash.com/photo-1590502593747-42a996133562?w=300&h=300&fit=crop&q=80',
  
  // Dairy & Breakfast
  'milk': 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&h=300&fit=crop&q=80',
  'butter': 'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300&h=300&fit=crop&q=80',
  'cheese': 'https://images.unsplash.com/photo-1486299267070-8382e214434b?w=300&h=300&fit=crop&q=80',
  'curd': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=300&h=300&fit=crop&q=80',
  'eggs': 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=300&h=300&fit=crop&q=80',
  'paneer': 'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=300&h=300&fit=crop&q=80',
  'bread': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300&h=300&fit=crop&q=80',
  'flakes': 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=300&h=300&fit=crop&q=80',
  'ghee': 'https://images.unsplash.com/photo-1631451095765-2c91616fc9e6?w=300&h=300&fit=crop&q=80',

  // Snacks & Munchies
  'lays': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300&h=300&fit=crop&q=80',
  'chips': 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300&h=300&fit=crop&q=80',
  'kurkure': 'https://images.unsplash.com/photo-1600180758890-6b945f9a2ba6?w=300&h=300&fit=crop&q=80',
  'bhujia': 'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=300&h=300&fit=crop&q=80',
  'chocolate': 'https://images.unsplash.com/photo-1511381939415-e4401546383a?w=300&h=300&fit=crop&q=80',
  'noodles': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300&h=300&fit=crop&q=80',
  'maggi': 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300&h=300&fit=crop&q=80',
  'oreo': 'https://images.unsplash.com/photo-1558961309-dbdf71799f5a?w=300&h=300&fit=crop&q=80',
  'pringles': 'https://images.unsplash.com/photo-1582293041079-7814c2f120d3?w=300&h=300&fit=crop&q=80',
  'cookies': 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=300&h=300&fit=crop&q=80',

  // Beverages
  'cola': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&h=300&fit=crop&q=80',
  'coke': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&h=300&fit=crop&q=80',
  'sprite': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&h=300&fit=crop&q=80',
  'thumbs': 'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&h=300&fit=crop&q=80',
  'tea': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=300&h=300&fit=crop&q=80',
  'coffee': 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=300&h=300&fit=crop&q=80',
  'juice': 'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=300&h=300&fit=crop&q=80',
  'water': 'https://images.unsplash.com/photo-1608889174633-855705b68b16?w=300&h=300&fit=crop&q=80',
  'bull': 'https://images.unsplash.com/photo-1622543953490-0b7027fb0111?w=300&h=300&fit=crop&q=80',

  // Personal Care
  'soap': 'https://images.unsplash.com/photo-1607006342411-1a9032b4a241?w=300&h=300&fit=crop&q=80',
  'dove': 'https://images.unsplash.com/photo-1607006342411-1a9032b4a241?w=300&h=300&fit=crop&q=80',
  'colgate': 'https://images.unsplash.com/photo-1559599189-fe84dea4eb79?w=300&h=300&fit=crop&q=80',
  'toothpaste': 'https://images.unsplash.com/photo-1559599189-fe84dea4eb79?w=300&h=300&fit=crop&q=80',
  'shampoo': 'https://images.unsplash.com/photo-1535585209827-a15fcdbc4c2d?w=300&h=300&fit=crop&q=80',
  'handwash': 'https://images.unsplash.com/photo-1603052875302-d376b7c0638a?w=300&h=300&fit=crop&q=80',
  'lotion': 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=300&h=300&fit=crop&q=80',
  'deo': 'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=300&h=300&fit=crop&q=80',
  'razor': 'https://images.unsplash.com/photo-1616803689944-132d0c242e2a?w=300&h=300&fit=crop&q=80',
  'pads': 'https://images.unsplash.com/photo-1579684389782-64d84b5e901a?w=300&h=300&fit=crop&q=80',
  'face': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=300&h=300&fit=crop&q=80',
  'coconut-oil': 'https://images.unsplash.com/photo-1608571423902-eed4a5ad8108?w=300&h=300&fit=crop&q=80',

  // Household
  'dishwash': 'https://images.unsplash.com/photo-1607344645866-009c320c5ab8?w=300&h=300&fit=crop&q=80',
  'detergent': 'https://images.unsplash.com/photo-1607344645866-009c320c5ab8?w=300&h=300&fit=crop&q=80',
  'cleaner': 'https://images.unsplash.com/photo-1584824486509-112e4181ff6b?w=300&h=300&fit=crop&q=80',
  'mosquito': 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=300&h=300&fit=crop&q=80',
  'bags': 'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?w=300&h=300&fit=crop&q=80',
  'scrub': 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=300&h=300&fit=crop&q=80',
  'freshener': 'https://images.unsplash.com/photo-1617886903355-9354bb57751f?w=300&h=300&fit=crop&q=80',
  'foil': 'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?w=300&h=300&fit=crop&q=80',

  // Bakery & Biscuits
  'parle': 'https://images.unsplash.com/photo-1558961309-dbdf71799f5a?w=300&h=300&fit=crop&q=80',
  'good': 'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=300&h=300&fit=crop&q=80',
  'biscuit': 'https://images.unsplash.com/photo-1558961309-dbdf71799f5a?w=300&h=300&fit=crop&q=80',
  'rusk': 'https://images.unsplash.com/photo-1608686207856-001b95cf60ca?w=300&h=300&fit=crop&q=80',
  'pav': 'https://images.unsplash.com/photo-1606890737304-57a1ca8a5b62?w=300&h=300&fit=crop&q=80',
  'croissant': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=300&h=300&fit=crop&q=80',
  'muffin': 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=300&h=300&fit=crop&q=80',
  'cake': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=300&h=300&fit=crop&q=80',

  // Atta, Rice & Staples
  'atta': 'https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?w=300&h=300&fit=crop&q=80',
  'rice': 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=300&h=300&fit=crop&q=80',
  'dal': 'https://images.unsplash.com/photo-1547058886-f368f9b93cd6?w=300&h=300&fit=crop&q=80',
  'sunflower-oil': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300&h=300&fit=crop&q=80',
  'gold-oil': 'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300&h=300&fit=crop&q=80',
  'masala': 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=300&h=300&fit=crop&q=80',
  'sugar': 'https://images.unsplash.com/photo-1581781870027-04212e231e96?w=300&h=300&fit=crop&q=80',
  'salt': 'https://images.unsplash.com/photo-1615485290382-441e4d049cb5?w=300&h=300&fit=crop&q=80',

  // Cafe Specific Items
  'chai': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=300&h=300&fit=crop&q=80',
  'samosa': 'https://images.unsplash.com/photo-1601050690597-df056fb4ce78?w=300&h=300&fit=crop&q=80',
  'sandwich': 'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=300&h=300&fit=crop&q=80',
  'momo': 'https://images.unsplash.com/photo-1625220194771-7ebedd0b48b0?w=300&h=300&fit=crop&q=80'
}

interface ProductImageProps {
  src: string | null | undefined
  alt: string
  categorySlug?: string
  className?: string
  isBestseller?: boolean
}

export function ProductImage({
  src,
  alt,
  categorySlug = '',
  className = '',
  isBestseller = false,
}: ProductImageProps) {
  const [imgError, setImgError] = useState(false)
  const [currentSrc, setCurrentSrc] = useState(src)
  const imgRef = useRef<HTMLImageElement>(null)

  useEffect(() => {
    setCurrentSrc(src)
    setImgError(false)
  }, [src])

  // Get a fallback Unsplash image based on name or slug keywords
  const getFallbackUnsplash = () => {
    const term = (src || '').toLowerCase() || alt.toLowerCase()
    for (const key of Object.keys(unsplashMap)) {
      if (term.includes(key)) {
        return unsplashMap[key]
      }
    }
    // General category fallback image if no keyword matches
    const categoryPics: Record<string, string> = {
      'fruits-vegetables': 'https://images.unsplash.com/photo-1610348725531-843dff14722a?w=300&h=300&fit=crop&q=80',
      'dairy-breakfast': 'https://images.unsplash.com/photo-1528750901443-e98a7a8b6ae8?w=300&h=300&fit=crop&q=80',
      'snacks-munchies': 'https://images.unsplash.com/photo-1599490659213-e2b9527b0f76?w=300&h=300&fit=crop&q=80',
      'beverages': 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=300&h=300&fit=crop&q=80',
      'personal-care': 'https://images.unsplash.com/photo-1526947425960-945c6e72858f?w=300&h=300&fit=crop&q=80',
      'household': 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=300&h=300&fit=crop&q=80',
      'bakery-biscuits': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300&h=300&fit=crop&q=80',
      'atta-rice-dal': 'https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?w=300&h=300&fit=crop&q=80',
      'cafe': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=300&h=300&fit=crop&q=80',
    }
    return categoryPics[categorySlug] || 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300&h=300&fit=crop&q=80'
  }

  const handleError = () => {
    // If the local placeholder fails, switch to the beautiful Unsplash fallback instead of showing the icon fallback
    const fallbackPic = getFallbackUnsplash()
    if (currentSrc !== fallbackPic) {
      setCurrentSrc(fallbackPic)
    } else {
      setImgError(true)
    }
  }

  // Determine if it is a valid image URL (not an emoji or empty)
  const isValidUrl = currentSrc && (currentSrc.startsWith('/') || currentSrc.startsWith('http') || currentSrc.startsWith('https'))

  if (!imgError && isValidUrl) {
    return (
      <img
        ref={imgRef}
        src={currentSrc!}
        alt={alt}
        className={className}
        onError={handleError}
      />
    )
  }

  // Fallback layout
  const IconComp = iconMap[categorySlug] || ShoppingBag

  return (
    <div className="flex flex-col items-center justify-center gap-2 w-full h-full bg-transparent p-4">
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary/5 text-primary shadow-inner">
        <IconComp className="h-6 w-6 stroke-[1.5]" />
      </div>
      {!isBestseller && (
        <span className="text-[9px] font-bold text-text-secondary bg-muted px-2 py-0.5 rounded-full">
          FastKirana
        </span>
      )}
    </div>
  )
}
