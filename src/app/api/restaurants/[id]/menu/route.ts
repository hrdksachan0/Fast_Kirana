import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { checkStoreOperatingStatus } from '@/lib/restaurant-schedule'
import { getCache, setCache } from '@/lib/search-cache'

// Fallback Default Sections for Cafes & Restaurants
const DEFAULT_CAFE_SECTIONS = [
  { id: 'sec_pizza', tag: 'pizza', title: "Pizza's", emoji: '🍕', sortOrder: 1, matchTags: ['pizza', 'pizzas'] },
  { id: 'sec_burger', tag: 'burgers', title: 'Burgers', emoji: '🍔', sortOrder: 2, matchTags: ['burger', 'burgers'] },
  { id: 'sec_sandwiches', tag: 'sandwiches', title: 'Sandwiches', emoji: '🥪', sortOrder: 3, matchTags: ['sandwich', 'sandwiches'] },
  { id: 'sec_garlic_bread', tag: 'garlic-bread', title: 'Cheesy Garlic Breads', emoji: '🥖', sortOrder: 4, matchTags: ['garlic-bread', 'garlic bread'] },
  { id: 'sec_frankie_rolls', tag: 'frankie-rolls', title: 'Frankie Rolls', emoji: '🌯', sortOrder: 5, matchTags: ['frankie-rolls', 'frankie rolls', 'rolls', 'kathi roll'] },
  { id: 'sec_chinese', tag: 'chinese', title: 'Chinese Cuisine', emoji: '🥡', sortOrder: 6, matchTags: ['chinese', 'chinese-cuisine', 'noodles', 'manchurian', 'chilli-paneer'] },
  { id: 'sec_pasta', tag: 'italian-pasta', title: "Italian Pasta's", emoji: '🍝', sortOrder: 7, matchTags: ['pasta', 'italian-pasta', 'italian pasta'] },
  { id: 'sec_south_indian', tag: 'south-indian', title: 'Dosa & South Indian', emoji: '🍛', sortOrder: 8, matchTags: ['south-indian', 'dosa'] },
  { id: 'sec_pav_bhaji', tag: 'pav-bhaji', title: 'Pav Bhaji & Bombay Bites', emoji: '🫕', sortOrder: 9, matchTags: ['pav-bhaji', 'pav bhaji', 'bombay-bites'] },
  { id: 'sec_rice', tag: 'rice-dishes', title: 'Rice Dishes & Biryani', emoji: '🍚', sortOrder: 10, matchTags: ['rice-dishes', 'rice', 'biryani', 'pulav'] },
  { id: 'sec_momos_hot', tag: 'hot-bite', title: 'Hot Bites & Momos', emoji: '🥟', sortOrder: 11, matchTags: ['hot-bite', 'momos', 'spring roll', 'french fries'] },
  { id: 'sec_shakes', tag: 'shakes', title: 'Thick Shakes', emoji: '🥤', sortOrder: 12, matchTags: ['shakes', 'shake', 'milkshake'] },
  { id: 'sec_mocktails', tag: 'mocktails', title: 'Refreshing Mocktails', emoji: '🍹', sortOrder: 13, matchTags: ['mocktails', 'mocktail', 'mojito', 'cooler'] },
  { id: 'sec_cold_coffee', tag: 'cold-coffee', title: 'Chilled Cold Coffee', emoji: '🧋', sortOrder: 14, matchTags: ['cold-coffee', 'iced coffee'] },
  { id: 'sec_desserts', tag: 'desserts', title: 'Desserts & Sweets', emoji: '🍰', sortOrder: 15, matchTags: ['desserts', 'sweet', 'ice-cream'] }
]

const DEFAULT_RESTAURANT_SECTIONS = [
  { id: 'sec_main_course', tag: 'main-course', title: 'North Indian Curries & Gravies', emoji: '🥘', sortOrder: 1, matchTags: ['main-course', 'curry', 'paneer', 'dal'] },
  { id: 'sec_roti_breads', tag: 'roti-naan-breads', title: 'Warm Naans, Rotis & Breads', emoji: '🫓', sortOrder: 2, matchTags: ['roti-naan-kulcha', 'roti', 'naan', 'kulcha', 'breads'] },
  { id: 'sec_starters_tikka', tag: 'starters-tandoori', title: 'Starters & Tandoori Tikkas', emoji: '🍢', sortOrder: 3, matchTags: ['starters-tandoori', 'tandoori-nawab-nawab', 'starter', 'tikka', 'chaap'] },
  { id: 'sec_biryani_rice', tag: 'biryani-rice', title: 'Biryani & Rice Feasts', emoji: '🍚', sortOrder: 4, matchTags: ['biryani-rice', 'biryani', 'pulav', 'basmati-rice'] },
  { id: 'sec_dal_special', tag: 'dal', title: 'Choice of Dal', emoji: '🥘', sortOrder: 5, matchTags: ['dal', 'dal-makhani'] },
  { id: 'sec_chinese_soups', tag: 'chinese-soups', title: 'Chinese Wok, Soups & Pastas', emoji: '🥡', sortOrder: 6, matchTags: ['chinese', 'noodles', 'soup', 'pasta'] },
  { id: 'sec_pizzas_burgers', tag: 'pizzas-burgers', title: 'Pizzas, Burgers & Bites', emoji: '🍕', sortOrder: 7, matchTags: ['pizza', 'burger', 'sandwich'] },
  { id: 'sec_breakfast', tag: 'breakfast', title: 'Breakfast & Nashta', emoji: '🍳', sortOrder: 8, matchTags: ['breakfast', 'paratha', 'chole-bhature'] },
  { id: 'sec_south_indian_res', tag: 'south-indian', title: 'South Indian & Dosa', emoji: '🍛', sortOrder: 9, matchTags: ['south-indian', 'dosa'] },
  { id: 'sec_beverages_shakes', tag: 'shakes-beverages', title: 'Thick Shakes & Beverages', emoji: '🥤', sortOrder: 10, matchTags: ['shake', 'shakes', 'beverage', 'mocktail'] },
  { id: 'sec_desserts_res', tag: 'desserts', title: 'Desserts & Sweets', emoji: '🍨', sortOrder: 11, matchTags: ['desserts', 'gulab-jamun', 'ice-cream', 'sweet'] }
]

export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const { searchParams } = new URL(request.url)
    const isVegOnly = searchParams.get('isVeg') === 'true'
    const search = searchParams.get('search')?.toLowerCase().trim() || ''

    const cacheKey = `restaurant_menu:${id}:${isVegOnly}:${search}`
    const cached = await getCache(cacheKey)
    if (cached) {
      return NextResponse.json(cached)
    }

    // 1. Find Restaurant by ID or Slug
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [
          { id },
          { slug: id },
          { slug: { equals: id, mode: 'insensitive' } }
        ]
      },
      select: {
        id: true,
        name: true,
        slug: true,
        description: true,
        logoUrl: true,
        bannerUrl: true,
        address: true,
        ownerPhone: true,
        rating: true,
        reviewCount: true,
        isVeg: true,
        isPureVeg: true,
        isOpen: true,
        openTime: true,
        closeTime: true,
        discountOffer: true,
        discountBadge: true,
        menuSections: true,
        cuisineTags: true,
        commissionRate: true
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    // 2. Compute operating status
    const opStatus = checkStoreOperatingStatus(restaurant)

    // 3. Fetch All Active Dishes of this Restaurant + Shared Darkstore Cold Drinks & Ice Creams
    const [products, darkstoreItems] = await Promise.all([
      prisma.product.findMany({
        where: {
          restaurantId: restaurant.id,
          isAvailable: true
        },
        include: {
          category: {
            select: { id: true, name: true, slug: true }
          },
          images: {
            select: { id: true, url: true, sortOrder: true }
          }
        },
        orderBy: [
          { sortOrder: 'desc' },
          { createdAt: 'desc' }
        ]
      }),
      prisma.product.findMany({
        where: {
          restaurantId: null,
          isAvailable: true,
          category: {
            slug: { in: ['beverages', 'ice-cream'] }
          }
        },
        include: {
          category: {
            select: { id: true, name: true, slug: true }
          },
          images: {
            select: { id: true, url: true, sortOrder: true }
          }
        },
        orderBy: [
          { isBestSeller: 'desc' },
          { sortOrder: 'desc' }
        ]
      })
    ])

    // 4. Resolve Menu Sections
    let rawSections: any[] = []
    if (restaurant.menuSections) {
      try {
        rawSections = typeof restaurant.menuSections === 'string'
          ? JSON.parse(restaurant.menuSections)
          : restaurant.menuSections
      } catch (e) {
        rawSections = []
      }
    }

    const isCafe = (restaurant.slug || '').includes('cafe') || (restaurant.slug || '').includes('as-')
    const baseSections = rawSections && rawSections.length > 0
      ? rawSections
      : (isCafe ? DEFAULT_CAFE_SECTIONS : DEFAULT_RESTAURANT_SECTIONS)

    // Normalize sections with unique ID and sortOrder
    const normalizedSections = baseSections
      .filter((s: any) => !s.disabled)
      .map((s: any, idx: number) => ({
        id: s.id || `sec_${s.tag || idx}`,
        tag: s.tag || `tag_${idx}`,
        title: s.title || s.name || 'Section',
        emoji: s.emoji || '🍽️',
        imageUrl: s.imageUrl || s.image || null,
        description: s.description || '',
        sortOrder: s.sortOrder !== undefined ? s.sortOrder : idx + 1,
        matchTags: Array.isArray(s.matchTags) ? s.matchTags.map((t: string) => t.toLowerCase()) : [s.tag?.toLowerCase()].filter(Boolean)
      }))

    // 5. Group Dishes into Structured Sections (ID-Wise)
    const sectionMap = new Map<string, any>()
    const otherDishes: any[] = []

    for (const sec of normalizedSections) {
      sectionMap.set(sec.id, {
        id: sec.id,
        tag: sec.tag,
        title: sec.title,
        emoji: sec.emoji,
        imageUrl: sec.imageUrl,
        description: sec.description,
        sortOrder: sec.sortOrder,
        itemsCount: 0,
        dishes: []
      })
    }

    for (const prod of products) {
      const prodTags = (prod.tags || []).map((t: string) => t.toLowerCase())
      const isDishNonVeg = prodTags.some(t => t === 'non-veg' || t === 'nonveg')
      const isDishVeg = !isDishNonVeg

      // Filter by veg if requested
      if (isVegOnly && !isDishVeg) continue

      // Filter by search query if requested
      if (search && !prod.name.toLowerCase().includes(search) && !prod.description?.toLowerCase().includes(search)) {
        continue
      }

      // Format clean dish object
      const formattedDish = {
        id: prod.id,
        name: prod.name,
        slug: prod.slug,
        description: prod.description,
        imageUrl: prod.imageUrl,
        images: prod.images,
        price: prod.price,
        mrp: prod.mrp,
        discount: prod.discount,
        unit: prod.unit,
        stock: prod.stock,
        isAvailable: prod.isAvailable,
        isVeg: isDishVeg,
        isNonVeg: isDishNonVeg,
        variants: prod.variants,
        availableStartTime: prod.availableStartTime,
        availableEndTime: prod.availableEndTime,
        categoryId: prod.categoryId,
        categoryName: prod.category?.name || 'Fast Food & Kitchen',
        restaurantId: restaurant.id,
        sectionId: null as string | null,
        sectionTitle: null as string | null
      }

      // Find matching section by tag or matchTags
      let matchedSection = normalizedSections.find(sec => {
        return prodTags.includes(sec.tag.toLowerCase()) || 
               sec.matchTags.some((mt: string) => prodTags.includes(mt))
      })

      if (matchedSection && sectionMap.has(matchedSection.id)) {
        const secGroup = sectionMap.get(matchedSection.id)
        formattedDish.sectionId = matchedSection.id
        formattedDish.sectionTitle = matchedSection.title
        secGroup.dishes.push(formattedDish)
        secGroup.itemsCount += 1
      } else {
        formattedDish.sectionId = 'sec_kitchen_specials'
        formattedDish.sectionTitle = 'Kitchen Specials'
        otherDishes.push(formattedDish)
      }
    }

    // Build final sections array (only non-empty sections)
    const finalSections = Array.from(sectionMap.values()).filter(sec => sec.itemsCount > 0)

    if (otherDishes.length > 0) {
      finalSections.push({
        id: 'sec_kitchen_specials',
        tag: 'kitchen-specials',
        title: 'Kitchen Specials & Others',
        emoji: '⭐',
        imageUrl: null,
        description: 'Chef special dishes and side items',
        sortOrder: 99,
        itemsCount: otherDishes.length,
        dishes: otherDishes
      })
    }

    // 6. Add Shared Darkstore Cold Drinks & Ice Creams Sections
    const coldDrinksDishes: any[] = []
    const iceCreamsDishes: any[] = []

    for (const item of darkstoreItems) {
      if (search && !item.name.toLowerCase().includes(search) && !item.description?.toLowerCase().includes(search)) {
        continue
      }

      const formattedGroceryItem = {
        id: item.id,
        name: item.name,
        slug: item.slug,
        description: item.description,
        imageUrl: item.imageUrl,
        images: item.images,
        price: item.price,
        mrp: item.mrp,
        discount: item.discount,
        unit: item.unit,
        stock: item.stock,
        isAvailable: item.isAvailable,
        isVeg: true,
        isNonVeg: false,
        variants: item.variants,
        availableStartTime: null,
        availableEndTime: null,
        categoryId: item.categoryId,
        categoryName: item.category?.name || 'Beverages & Desserts',
        restaurantId: null, // Null indicates FastKirana Darkstore Item
        isDarkstoreFulfillment: true,
        sectionId: '',
        sectionTitle: ''
      }

      if (item.category?.slug === 'beverages') {
        formattedGroceryItem.sectionId = 'sec_chilled_drinks'
        formattedGroceryItem.sectionTitle = 'Chilled Cold Drinks & Sodas'
        coldDrinksDishes.push(formattedGroceryItem)
      } else if (item.category?.slug === 'ice-cream') {
        formattedGroceryItem.sectionId = 'sec_ice_creams'
        formattedGroceryItem.sectionTitle = 'Ice Creams & Sweet Treats'
        iceCreamsDishes.push(formattedGroceryItem)
      }
    }

    if (coldDrinksDishes.length > 0) {
      finalSections.push({
        id: 'sec_chilled_drinks',
        tag: 'chilled-drinks',
        title: 'Chilled Cold Drinks & Sodas',
        emoji: '🥤',
        imageUrl: '/beverages_category.webp',
        description: 'Chilled soft drinks, energy boosts & refreshing coolers from FastKirana Darkstore',
        sortOrder: 90,
        itemsCount: coldDrinksDishes.length,
        dishes: coldDrinksDishes
      })
    }

    if (iceCreamsDishes.length > 0) {
      finalSections.push({
        id: 'sec_ice_creams',
        tag: 'ice-creams',
        title: 'Ice Creams & Sweet Treats',
        emoji: '🍦',
        imageUrl: '/icecream_category.png',
        description: 'Creamy cones, family tubs, sundaes & kulfis from FastKirana Darkstore',
        sortOrder: 91,
        itemsCount: iceCreamsDishes.length,
        dishes: iceCreamsDishes
      })
    }

    // Sort sections by sortOrder
    finalSections.sort((a, b) => a.sortOrder - b.sortOrder)

    const responsePayload = {
      success: true,
      restaurant: {
        id: restaurant.id,
        name: restaurant.name,
        slug: restaurant.slug,
        description: restaurant.description,
        logoUrl: restaurant.logoUrl,
        bannerUrl: restaurant.bannerUrl,
        address: restaurant.address,
        phone: restaurant.ownerPhone,
        rating: restaurant.rating,
        reviewCount: restaurant.reviewCount,
        isVeg: restaurant.isVeg,
        isPureVeg: restaurant.isPureVeg,
        isOpen: opStatus.isOpen,
        isClosedBySchedule: opStatus.isClosedBySchedule,
        isClosedByOwner: opStatus.isClosedByOwner,
        scheduleStr: opStatus.formattedScheduleStr,
        openTime: restaurant.openTime,
        closeTime: restaurant.closeTime,
        discountOffer: restaurant.discountOffer,
        discountBadge: restaurant.discountBadge,
        cuisineTags: restaurant.cuisineTags,
        totalDishes: products.length
      },
      sections: finalSections,
      totalDishesCount: products.length
    }

    // Cache for 60 seconds
    await setCache(cacheKey, responsePayload, 60)

    return NextResponse.json(responsePayload)
  } catch (error: any) {
    console.error('Error fetching ID-wise restaurant menu:', error)
    return NextResponse.json(
      { error: error?.message || 'Failed to fetch restaurant menu' },
      { status: 500 }
    )
  }
}
