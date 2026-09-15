export interface OrderItem {
  id: string
  productId: string
  name: string
  price: number
  quantity: number
  imageUrl?: string
  product?: {
    slug: string
    location?: string | null
    category?: {
      slug: string
    }
  }
}

export interface CompanionOrder {
  id: string
  readableId?: string
  status: string
  shopName: string | null
  items: {
    id: string
    name: string
    quantity: number
  }[]
}

export interface Order {
  id: string
  readableId?: string
  status: string
  total: number
  createdAt: string | Date
  paymentMethod: string
  deliveryMethod: string
  user: {
    name: string
    phone: string | null
  }
  address: {
    houseNo: string
    street: string
    area: string
    city: string
    pincode: string
    phone?: string
  }
  items: OrderItem[]
  companionOrder?: CompanionOrder | null
  assignedPickerId?: string | null
  assignedChefId?: string | null
  assignedPicker?: { name: string } | null
  assignedChef?: { name: string } | null
}

export interface BinConfig {
  name: string
  bg: string
  fill: string
}

export const BIN_CONFIGS: BinConfig[] = [
  {
    name: 'Blue Bin',
    bg: 'bg-blue-500/10 dark:bg-blue-500/20 text-blue-600 dark:text-blue-400 border-blue-200/50 dark:border-blue-800/30',
    fill: 'bg-blue-500',
  },
  {
    name: 'Red Bin',
    bg: 'bg-red-500/10 dark:bg-red-500/20 text-red-600 dark:text-red-400 border-red-200/50 dark:border-red-800/30',
    fill: 'bg-red-500',
  },
  {
    name: 'Green Bin',
    bg: 'bg-green-500/10 dark:bg-green-500/20 text-green-600 dark:text-green-400 border-green-200/50 dark:border-green-800/30',
    fill: 'bg-green-500',
  },
]

export const CATEGORY_AISLES: Record<string, number> = {
  'fruits-vegetables': 1,
  'dairy-breakfast': 2,
  'bakery-biscuits': 3,
  'snacks-munchies': 4,
  beverages: 5,
  'personal-care': 6,
  household: 7,
  'atta-rice-dal': 8,
}

export function getAisleNumber(categorySlug: string = ''): number {
  return CATEGORY_AISLES[categorySlug] || 9
}

export function getAisleName(aisleNo: number): string {
  switch (aisleNo) {
    case 1:
      return 'Fresh Produce Rack'
    case 2:
      return 'Chilled Dairy Section'
    case 3:
      return 'Bread & Bakery Aisle'
    case 4:
      return 'Snacks & Biscuits Aisle'
    case 5:
      return 'Chilled Beverages'
    case 6:
      return 'Hygiene & Personal Care'
    case 7:
      return 'Household Cleaners'
    case 8:
      return 'Staples & Grains Rack'
    default:
      return 'General Inventory Shelves'
  }
}

export function timeAgo(date: string | Date): string {
  const now = new Date()
  const then = new Date(date)
  const diffMs = now.getTime() - then.getTime()
  const diffSec = Math.floor(diffMs / 1000)
  if (diffSec < 60) return `${diffSec}s ago`
  const diffMin = Math.floor(diffSec / 60)
  if (diffMin < 60) return `${diffMin}m ago`
  const diffHr = Math.floor(diffMin / 60)
  if (diffHr < 24) return `${diffHr}h ago`
  return `${Math.floor(diffHr / 24)}d ago`
}

export function getSlaClass(date: string | Date, status: string): string {
  if (status !== 'PENDING') return 'text-gray-400 font-semibold'
  const now = new Date()
  const then = new Date(date)
  const diffMs = now.getTime() - then.getTime()
  const diffMin = Math.floor(diffMs / 60000)
  if (diffMin >= 10) return 'text-rose-500 font-black animate-pulse'
  if (diffMin >= 5) return 'text-amber-500 font-black animate-pulse'
  return 'text-gray-400 font-semibold'
}
