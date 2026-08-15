export const APP_NAME = 'FastKirana'
export const APP_DESCRIPTION = 'Fast grocery delivery at your doorstep'
export const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'

export const GROCERY_FREE_DELIVERY_THRESHOLD = 200
export const CAFE_FREE_DELIVERY_THRESHOLD = 200
export const COMBINED_FREE_DELIVERY_THRESHOLD = 200
export const FREE_DELIVERY_THRESHOLD = 200
export const DELIVERY_FEE = 25
export const TAX_RATE = 0.00 // 0% GST

export const MIN_CART_VALUE = 20  // Minimum cart value for checkout
export const OUTLET_WEDSON_ID = 'cms2p1lyx0001n0idod904lfu'
export const OUTLET_AS_RESTAURANT_ID = 'cms2p1lap0000n0id8alldboy'

export const CATEGORIES = [
  { name: 'Fruits & Vegetables', slug: 'fruits-vegetables', emoji: '🥬' },
  { name: 'Dairy & Breakfast', slug: 'dairy-breakfast', emoji: '🥛' },
  { name: 'Snacks & Munchies', slug: 'snacks-munchies', emoji: '🍿' },
  { name: 'Beverages', slug: 'beverages', emoji: '🥤' },
  { name: 'Personal Care', slug: 'personal-care', emoji: '🧴' },
  { name: 'Household', slug: 'household', emoji: '🏠' },
  { name: 'Bakery & Biscuits', slug: 'bakery-biscuits', emoji: '🍞' },
  { name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', emoji: '🌾' },
] as const

export const ORDER_STATUS_LABELS: Record<string, string> = {
  PENDING: 'Order Placed',
  CONFIRMED: 'Confirmed',
  PACKED: 'Packed',
  SHIPPED: 'On the Way',
  DELIVERED: 'Delivered',
  CANCELLED: 'Cancelled',
}

export const ORDER_STATUS_COLORS: Record<string, string> = {
  PENDING: 'bg-yellow-100 text-yellow-800',
  CONFIRMED: 'bg-blue-100 text-blue-800',
  PACKED: 'bg-indigo-100 text-indigo-800',
  SHIPPED: 'bg-purple-100 text-purple-800',
  DELIVERED: 'bg-green-100 text-green-800',
  CANCELLED: 'bg-red-100 text-red-800',
}

export interface CafeMenuSection {
  tag: string
  matchTags: string[]
  title: string
  emoji: string
  description: string
  imageUrl?: string
  image?: string
  disabled?: boolean
}

export const DEFAULT_CAFE_MENU_SECTIONS: CafeMenuSection[] = [
  {
    tag: 'hot-beverage',
    matchTags: ['hot-beverage', 'hot-coffee', 'hot coffee', 'tea', 'chai'],
    title: 'Brews & Tea',
    emoji: '☕',
    description: 'Chai, hot coffee, and fresh brewing mixes',
  },
  {
    tag: 'hot-bite',
    matchTags: ['hot-bite', 'snacks', 'momos'],
    title: 'Quick Snacks',
    emoji: '🥟',
    description: 'Samosas, Momos, French Fries, and warm treats',
  },
  {
    tag: 'sandwiches',
    matchTags: ['sandwiches', 'sandwich'],
    title: 'Sandwiches',
    emoji: '🥪',
    description: 'Freshly grilled sandwiches loaded with cheese, paneer, and veggies',
  },
  {
    tag: 'burgers',
    matchTags: ['burgers', 'burger', 'veg-burger', 'cheese-burger', 'paneer-burger'],
    title: 'Burgers',
    emoji: '🍔',
    description: 'Juicy veg burgers, paneer burgers, and loaded cheese burgers',
  },
  {
    tag: 'frankie-rolls',
    matchTags: ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll', 'kathi-roll'],
    title: 'Rolls & Frankie',
    emoji: '🌯',
    description: 'Fresh rolls stuffed with paneer, cheese, and veg patties',
  },
  {
    tag: 'garlic-bread',
    matchTags: ['garlic-bread', 'garlic bread', 'garlic-breads'],
    title: 'Garlic Bread',
    emoji: '🧄',
    description: 'Loaded garlic breads with corn, paneer, cheese & mix veg',
  },
  {
    tag: 'pizza',
    matchTags: ['pizza', 'pizzas'],
    title: 'Pizzas',
    emoji: '🍕',
    description: 'Loaded pizzas with fresh toppings and melted cheese',
  },
  {
    tag: 'pav-bhaji',
    matchTags: ['pav-bhaji', 'pav bhaji', 'pavbhaji'],
    title: 'Pav Bhaji',
    emoji: '🫕',
    description: 'Butter Pav Bhaji, Paneer Pav Bhaji & Extra Pav',
  },
  {
    tag: 'chinese',
    matchTags: ['chinese', 'chinese-cuisine', 'chinese cuisine'],
    title: 'Chinese',
    emoji: '🥡',
    description: 'Momos, noodles, fried dishes & sauces',
  },
  {
    tag: 'italian-pasta',
    matchTags: ['italian-pasta', 'italian-pastas', 'italian pasta\'s', 'pasta'],
    title: 'Pastas',
    emoji: '🍝',
    description: 'Fresh penne tossed in aromatic red & white sauces',
  },
  {
    tag: 'south-indian',
    matchTags: ['south-indian', 'south indian', 'dosa'],
    title: 'South Indian',
    emoji: '🍛',
    description: 'Dosa, Idli, Vada, Uttapam & more',
  },
  {
    tag: 'bombay-bites',
    matchTags: ['bombay-bites', 'bombay bites', 'bombay-bite', 'bombay bite'],
    title: 'Bombay Bites',
    emoji: '🥪',
    description: 'Vada Pav, special Bombay Masala Toast, and street snacks',
  },
  {
    tag: 'rice-dishes',
    matchTags: ['rice-dishes', 'rice dishes', 'rice-dish', 'rice dish', 'biryani', 'pulav'],
    title: 'Rice & Bowls',
    emoji: '🍚',
    description: 'Flavourful biryani, fried rice, and combos',
  },
  {
    tag: 'shakes',
    matchTags: ['shakes', 'shake', 'milkshake', 'milkshakes'],
    title: 'Shakes',
    emoji: '🥤',
    description: 'Creamy strawberry, chocolate, and Oreo shakes',
  },
  {
    tag: 'mocktails',
    matchTags: ['mocktails', 'mocktail', 'coolers', 'cooler', 'mojito'],
    title: 'Mocktails',
    emoji: '🍹',
    description: 'Iced coolers, Virgin Mojito, and summer drinks',
  },
  {
    tag: 'cold-coffee',
    matchTags: ['cold-coffee', 'cold coffee', 'iced coffee', 'iced-coffee'],
    title: 'Cold Coffee',
    emoji: '🧋',
    description: 'Classic cold brews, hazelnut cold coffee & iced sips',
  },
  {
    tag: 'bakery',
    matchTags: ['bakery', 'bakery-biscuits', 'cake', 'cakes'],
    title: 'Bakery',
    emoji: '🎂',
    description: 'Freshly baked cakes, pastries, and sweet treats',
  },
  {
    tag: 'chilled',
    matchTags: ['chilled', 'cold-drink', 'beverages', 'beverage', 'drinks', 'drink'],
    title: 'Cold Drinks',
    emoji: '🥤',
    description: 'Carbonated soft drinks and cold energy boosts',
  },
  {
    tag: 'desserts',
    matchTags: ['desserts', 'ice-cream', 'ice cream', 'kulfi', 'dessert', 'sweet'],
    title: 'Desserts',
    emoji: '🍦',
    description: 'Chilled premium ice creams, kulfis, and desserts',
  }
]

export const DEFAULT_RESTAURANT_MENU_SECTIONS: CafeMenuSection[] = [
  {
    tag: 'main-course',
    matchTags: ['north-indian', 'curry', 'dal-makhani', 'paneer-butter-masala', 'paneer', 'main-course', 'dal'],
    title: 'Curries & Gravies',
    emoji: '🥘',
    description: 'Rich paneer butter masala, creamy dal makhani, and Special Kadhai Gravies',
  },
  {
    tag: 'roti-naan-breads',
    matchTags: ['roti-naan-kulcha', 'roti', 'naan', 'kulcha', 'breads', 'paratha-bread'],
    title: 'Rotis & Naans',
    emoji: '🫓',
    description: 'Butter Naan, Garlic Naan, Tandoori Roti, Missi Roti & Stuffed Kulchas',
  },
  {
    tag: 'starters-tandoori',
    matchTags: ['special-starters', 'tandoori-nawab-nawab', 'starter', 'starters', 'kebabs', 'tikka', 'chaap'],
    title: 'Starters & Tandoori',
    emoji: '🍢',
    description: 'Soya Malai Chaap, Paneer Tikka, Veg Seekh Kebab & Dahi Kebab',
  },
  {
    tag: 'biryani-rice',
    matchTags: ['biryani-rice', 'biryani', 'pulav', 'fried-rice', 'jeera-rice', 'basmati-rice-/-biryani'],
    title: 'Biryani & Rice',
    emoji: '🍚',
    description: 'Aromatic basmati veg biryanis, paneer pulavs & loaded fried rice bowls',
  },
  {
    tag: 'pizzas-burgers',
    matchTags: ['pizza', 'burger', 'burgers', 'pizzas', 'sandwich'],
    title: 'Pizza & Burgers',
    emoji: '🍕',
    description: 'Fresh baked pizzas, loaded veggie burgers & grilled sandwiches',
  },
  {
    tag: 'chinese-soups',
    matchTags: ['chinese', 'noodles', 'manchurian', 'chilli-paneer', 'spring-rolls', 'soup', 'pasta'],
    title: 'Chinese & Soups',
    emoji: '🥡',
    description: 'Stir-fried noodles, saucy veg manchurian, hot soups & pastas',
  },
  {
    tag: 'breakfast',
    matchTags: ['breakfast', 'paratha', 'poori', 'chole-bhature', 'nashta', 'poha'],
    title: 'Breakfast',
    emoji: '🍳',
    description: 'Chole Bhature, Parathas, Poori and morning favorites',
  },
  {
    tag: 'shakes-beverages',
    matchTags: ['shake', 'shakes', 'beverage', 'beverages', 'drinks', 'drink', 'cold-drink', 'cold-drinks', 'mocktail', 'coffee', 'chilled'],
    title: 'Shakes & Drinks',
    emoji: '🥤',
    description: 'Chocolate, Oreo, Strawberry thick shakes & refreshing coolers',
  },
  {
    tag: 'desserts',
    matchTags: ['desserts', 'gulab-jamun', 'ice-cream', 'ice cream', 'kheer', 'dessert', 'sweet', 'sweets'],
    title: 'Desserts & Sweet Sips',
    emoji: '🍨',
    description: 'Hot gulab jamuns, premium ice creams, and traditional sweets',
  }
]

export const PRODUCT_TEMPLATES = [
  {
    id: 'fresh_produce',
    label: '🥦 Fresh Produce (Fruits & Veggies)',
    description: 'Fresh fruits, vegetables',
    categoryName: 'Fresh Fruits & Vegetables',
    unit: '1 kg',
    minStock: 15,
    tags: 'fresh, produce'
  },
  {
    id: 'grocery_essential',
    label: '🥤 Grocery Essential',
    description: 'Packaged foods, staples',
    categoryName: 'Atta, Rice & Dal',
    unit: '1 pc',
    minStock: 10,
    tags: 'essential, grocery'
  },
  {
    id: 'cafe_snack',
    label: '☕ Cafe Snack',
    description: 'Fresh cafe items',
    categoryName: 'FastKirana Cafe',
    unit: '1 plate',
    minStock: 5,
    tags: 'cafe, freshlyprepared'
  },
  {
    id: 'household_personal',
    label: '🧴 Household Needs',
    description: 'Soaps, cleaners, detergents',
    categoryName: 'Household Needs',
    unit: '1 Pack',
    minStock: 5,
    tags: 'cleaning, household'
  }
] as const

export const HUB_CONFIG = [
  {
    key: 'orders_hub',
    label: 'Orders & Fulfillment',
    description: 'Live order queue, dispatch tracking, and real-time ops',
    color: 'from-amber-500/10 to-orange-500/10',
    activeBorder: 'border-amber-500/60 ring-2 ring-amber-500/20',
    tabs: ['orders', 'liveops'] as const
  },
  {
    key: 'grocery',
    label: 'Products & Inventory',
    description: 'Catalog, categories, stock alerts, inward, bulk updates & CSV import',
    color: 'from-emerald-500/10 to-teal-500/10',
    activeBorder: 'border-emerald-500/60 ring-2 ring-emerald-500/20',
    tabs: ['products', 'categories', 'alerts', 'inward', 'bulk-update', 'csv-import'] as const
  },
  {
    key: 'food',
    label: 'Food & Restaurants',
    description: 'Restaurant kitchen console, outlet management & payouts',
    color: 'from-orange-500/10 to-red-500/10',
    activeBorder: 'border-orange-500/60 ring-2 ring-orange-500/20',
    tabs: ['restaurant-console', 'restaurant-report'] as const
  },
  {
    key: 'insights',
    label: 'Business Intelligence',
    description: 'Analytics dashboards, AI forecasting & sales reports',
    color: 'from-blue-500/10 to-cyan-500/10',
    activeBorder: 'border-blue-500/60 ring-2 ring-blue-500/20',
    tabs: ['analytics', 'forecast', 'reports'] as const
  },
  {
    key: 'people',
    label: 'Operations & People',
    description: 'Staff, customers, rider settlements & review moderation',
    color: 'from-indigo-500/10 to-purple-500/10',
    activeBorder: 'border-indigo-500/60 ring-2 ring-indigo-500/20',
    tabs: ['users', 'rider-cash', 'reviews'] as const
  },
  {
    key: 'marketing',
    label: 'Marketing & Settings',
    description: 'Promo banners, coupons, push notifications & store config',
    color: 'from-rose-500/10 to-pink-500/10',
    activeBorder: 'border-rose-500/60 ring-2 ring-rose-500/20',
    tabs: ['banners', 'flash-deals', 'coupons', 'push-notifications', 'settings'] as const
  }
] as const

export const OUTLET_NAMES: Record<string, string> = {
  [OUTLET_WEDSON_ID]: 'Wedson Restaurant',
  [OUTLET_AS_RESTAURANT_ID]: 'A.S Restaurant',
  wedson: 'Wedson Restaurant',
  'as-restaurant': 'A.S Restaurant',
  cafe: 'Cafe',
  'restaurant-kitchen': 'Wedson Restaurant',
}

export function getOutletName(product: any): string {
  if (!product) return 'Wedson Restaurant'

  const rId = product.restaurantId || product.restaurant?.id
  const rSlug = (product.restaurant?.slug || '').toLowerCase()
  const rName = (product.restaurantName || product.restaurant?.name || '').toLowerCase()
  const tags = Array.isArray(product.tags) ? product.tags.map((t: string) => t.toLowerCase()) : []
  const pName = (product.name || '').toLowerCase()

  // 1. Explicit A.S. Restaurant / Cafe checks (Highest Priority)
  if (
    rId === OUTLET_AS_RESTAURANT_ID ||
    rId === 'as-restaurant' ||
    rId === 'as-cafe' ||
    rSlug === 'as-restaurant' ||
    rSlug === 'as-cafe' ||
    rName.includes('a.s') ||
    rName.includes('as-restaurant') ||
    rName.includes('as restaurant') ||
    rName.includes('as cafe') ||
    tags.some((t: string) => t === 'as-restaurant' || t === 'as-cafe' || t === 'a.s. restaurant' || t === 'a.s restaurant' || t === 'as_restaurant' || t === 'as-cafe-restaurant') ||
    pName.includes('a.s special') ||
    pName.includes('a.s. special')
  ) {
    return 'A.S Restaurant'
  }

  // 2. Explicit Wedson Restaurant checks (Second Highest Priority)
  if (
    rId === OUTLET_WEDSON_ID ||
    rId === 'wedson' ||
    rSlug === 'wedson' ||
    rSlug === 'restaurant-kitchen' ||
    rName.includes('wedson') ||
    tags.some((t: string) => t === 'wedson' || t === 'wedson-restaurant' || t === 'wedson_restaurant')
  ) {
    return 'Wedson Restaurant'
  }

  // 3. Known ID mapping from OUTLET_NAMES
  if (rId && OUTLET_NAMES[rId]) return OUTLET_NAMES[rId]

  // 4. Known tag mapping from OUTLET_NAMES
  for (const tag of tags) {
    if (OUTLET_NAMES[tag]) return OUTLET_NAMES[tag]
  }

  // 5. If product has a custom restaurant name, return normalized name
  if (product.restaurant?.name) return product.restaurant.name
  if (product.restaurantName) return product.restaurantName

  // 6. Generic food fallback for items without explicit restaurant tags/ids
  if (
    tags.includes('dal-fry') ||
    tags.includes('burger') ||
    tags.includes('pizza') ||
    tags.includes('chowmein') ||
    tags.includes('fast-food') ||
    pName.includes('burger') ||
    pName.includes('pizza') ||
    pName.includes('chowmein') ||
    pName.includes('noodle') ||
    pName.includes('momos') ||
    pName.includes('fries') ||
    pName.includes('roll') ||
    pName.includes('sandwich') ||
    pName.includes('pasta') ||
    pName.includes('manchurian') ||
    pName.includes('shake') ||
    pName.includes('mocktail') ||
    pName.includes('tikki')
  ) {
    return 'Wedson Restaurant'
  }

  return 'Wedson Restaurant'
}

