import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const productIdsStr = searchParams.get('productIds') || ''
    const storeId = searchParams.get('storeId')

    const cartProductIds = productIdsStr.split(',').filter(Boolean)
    if (cartProductIds.length === 0) {
      return NextResponse.json({ products: [] })
    }

    // 1. Fetch details of items in the cart to check their tags/categories/restaurant
    const cartProducts = await prisma.product.findMany({
      where: { id: { in: cartProductIds } },
      include: { category: true }
    })

    const cartTags = new Set(cartProducts.flatMap(p => p.tags || []).map(t => t.toLowerCase()))

    // Detect if cart has items from a specific restaurant
    const restaurantCartItem = cartProducts.find(p => p.restaurantId !== null)
    const activeRestaurantId = restaurantCartItem?.restaurantId || null

    // Allowed filter:
    // If cart has a restaurant item: recommend items from THAT SAME restaurant OR strictly Darkstore Beverages & Ice Cream (restaurantId: null, category: beverages/ice-cream)
    // If cart is pure grocery: recommend strictly Darkstore Groceries (restaurantId: null)
    const baseTypeFilter: Prisma.ProductWhereInput = activeRestaurantId
      ? {
          OR: [
            { restaurantId: activeRestaurantId },
            {
              restaurantId: null,
              category: { slug: { in: ['beverages', 'ice-cream'] } }
            }
          ]
        }
      : { restaurantId: null }

    const storeScope: Prisma.ProductWhereInput = (storeId && storeId !== 'all') ? {
      OR: [
        {
          restaurantId: null,
          inventories: {
            some: {
              storeId,
              stock: { gt: 0 }
            }
          }
        },
        {
          restaurant: {
            storeId
          }
        }
      ]
    } : {}

    const typeFilter: Prisma.ProductWhereInput = (storeId && storeId !== 'all')
      ? { AND: [baseTypeFilter, storeScope] }
      : baseTypeFilter

    // 2. Try to find products frequently bought together in past orders
    let recommendedProducts: any[] = []

    try {
      // Find orders that contain any of the cart products
      const orderIdsWithCartProducts = await prisma.orderItem.findMany({
        where: {
          productId: { in: cartProductIds },
          order: { status: 'DELIVERED' }
        },
        select: { orderId: true },
        take: 200 // limit scan
      })
      const orderIds = [...new Set(orderIdsWithCartProducts.map(item => item.orderId))]

      if (orderIds.length > 0) {
        // Find other products bought in those orders
        const coOccurrences = await prisma.orderItem.groupBy({
          by: ['productId'],
          where: {
            orderId: { in: orderIds },
            productId: { notIn: cartProductIds, not: null },
            product: { 
              isAvailable: true, 
              stock: { gt: 0 },
              ...typeFilter
            }
          },
          _count: {
            id: true
          },
          orderBy: {
            _count: {
              productId: 'desc'
            }
          },
          take: 8
        })

        const coOccurredProductIds = coOccurrences
          .map(item => item.productId)
          .filter((id): id is string => id !== null)

        if (coOccurredProductIds.length > 0) {
          recommendedProducts = await prisma.product.findMany({
            where: {
              id: { in: coOccurredProductIds },
              isAvailable: true,
              stock: { gt: 0 },
              ...typeFilter
            },
            include: { category: true }
          })

          // Sort by co-occurrence frequency
          recommendedProducts.sort((a, b) => {
            const freqA = coOccurrences.find(item => item.productId === a.id)?._count.id || 0
            const freqB = coOccurrences.find(item => item.productId === b.id)?._count.id || 0
            return freqB - freqA
          })
        }
      }
    } catch (dbErr) {
      console.warn('Failed to fetch frequent co-occurrences:', dbErr)
    }

    // 3. Smart Companion Association Engine (Hinglish & Quick-Commerce Affinity)
    if (recommendedProducts.length < 6) {
      const alreadyRecommendedIds = new Set(recommendedProducts.map(p => p.id))
      const excludeIds = new Set([...cartProductIds, ...alreadyRecommendedIds])
      const neededCount = 8 - recommendedProducts.length

      // Detect cart product signals
      const cartNames = cartProducts.map(p => (p.name || '').toLowerCase())
      const cartCatSlugs = cartProducts.map(p => (p.category?.slug || '').toLowerCase())
      const isPureVegCart = !cartNames.some(n => n.includes('chicken') || n.includes('mutton') || n.includes('egg') || n.includes('fish') || n.includes('meat')) &&
        !cartProducts.some(p => (p.tags || []).some(t => t.toLowerCase().includes('non-veg') || t.toLowerCase().includes('nonveg')))

      // Target companion search tokens
      const companionKeywords: string[] = []

      // ── Food / Restaurant Cart Affinity ──
      if (activeRestaurantId) {
        const hasBurgerPizza = cartNames.some(n => n.includes('burger') || n.includes('pizza') || n.includes('sandwich') || n.includes('roll') || n.includes('noodle') || n.includes('pasta'))
        const hasMealBiryani = cartNames.some(n => n.includes('biryani') || n.includes('curry') || n.includes('thali') || n.includes('paneer') || n.includes('dal') || n.includes('roti') || n.includes('rice'))

        if (hasBurgerPizza) {
          companionKeywords.push('fries', 'garlic bread', 'french fries', 'coke', 'thums up', 'sprite', 'cold drink', 'chocobar', 'ice cream', 'cornetto')
        }
        if (hasMealBiryani) {
          companionKeywords.push('raita', 'dahi', 'gulab jamun', 'thums up', 'coke', 'naan', 'roti', 'papad', 'ice cream')
        }
        // Universal restaurant addons: chilled cold drinks & ice creams
        companionKeywords.push('thums up', 'coke', 'sprite', 'cold drink', 'ice cream', 'mojito', 'cold coffee')
      } else {
        // ── Quick-Commerce Grocery Affinity ──
        // 1. Tea / Coffee (Chai)
        if (cartNames.some(n => n.includes('tea') || n.includes('chai') || n.includes('coffee') || n.includes('patti')) || cartCatSlugs.some(s => s.includes('tea') || s.includes('coffee'))) {
          companionKeywords.push('sugar', 'milk', 'rusk', 'biscuit', 'parle', 'cookies')
        }
        // 2. Bread / Pav
        if (cartNames.some(n => n.includes('bread') || n.includes('pav') || n.includes('bun')) || cartCatSlugs.some(s => s.includes('bakery'))) {
          companionKeywords.push('butter', 'jam', 'cheese', 'paneer')
          if (!isPureVegCart) companionKeywords.push('egg')
        }
        // 3. Milk / Dahi / Curd / Dairy
        if (cartNames.some(n => n.includes('dahi') || n.includes('curd') || n.includes('doodh') || n.includes('paneer') || n.includes('dairy')) || cartCatSlugs.some(s => s.includes('dairy'))) {
          companionKeywords.push('sugar', 'boondi', 'poha', 'namkeen', 'bread', 'butter')
        }
        // 4. Maggi / Instant Noodles / Pasta
        if (cartNames.some(n => n.includes('maggi') || n.includes('maggie') || n.includes('noodle') || n.includes('pasta') || n.includes('yippee'))) {
          companionKeywords.push('ketchup', 'sauce', 'cheese', 'coke', 'thums up', 'frooti')
        }
        // 5. Atta / Rice / Dal / Cooking Staples
        if (cartNames.some(n => n.includes('atta') || n.includes('rice') || n.includes('chawal') || n.includes('dal') || n.includes('oil') || n.includes('tel')) || cartCatSlugs.some(s => s.includes('staples') || s.includes('oil'))) {
          companionKeywords.push('ghee', 'mustard', 'oil', 'salt', 'masala', 'jeera', 'papad')
        }
        // 6. Snacks / Chips / Namkeen / Biscuits
        if (cartNames.some(n => n.includes('chips') || n.includes('lays') || n.includes('kurkure') || n.includes('namkeen') || n.includes('biscuit')) || cartCatSlugs.some(s => s.includes('snacks') || s.includes('namkeen'))) {
          companionKeywords.push('coke', 'thums up', 'sprite', 'frooti', 'cold drink', 'chocolate')
        }
        // 7. Personal Care / Oral / Bath
        if (cartNames.some(n => n.includes('soap') || n.includes('shampoo') || n.includes('brush') || n.includes('colgate') || n.includes('paste')) || cartCatSlugs.some(s => s.includes('personal-care'))) {
          companionKeywords.push('colgate', 'brush', 'soap', 'dettol', 'detergent')
        }
      }

      // Query companion items by name OR tags
      if (companionKeywords.length > 0) {
        const titleOrClauses = companionKeywords.slice(0, 10).map(kw => ({
          name: { contains: kw, mode: 'insensitive' as const }
        }))

        const companionProducts = await prisma.product.findMany({
          where: {
            id: { notIn: Array.from(excludeIds) },
            isAvailable: true,
            stock: { gt: 0 },
            OR: titleOrClauses,
            ...typeFilter
          },
          include: { category: true },
          take: neededCount
        })

        // Filter non-veg if cart is pure veg
        const filteredCompanions = isPureVegCart
          ? companionProducts.filter(p => {
              const n = (p.name || '').toLowerCase()
              const t = (p.tags || []).map(x => x.toLowerCase())
              return !n.includes('chicken') && !n.includes('mutton') && !n.includes('egg') && !t.includes('non-veg')
            })
          : companionProducts

        for (const p of filteredCompanions) {
          if (!excludeIds.has(p.id) && recommendedProducts.length < 8) {
            recommendedProducts.push(p)
            excludeIds.add(p.id)
          }
        }
      }
    }

    // 4. Universal Impulse Additions Fallback (Cold Drinks, Ice Cream, Bestselling Snacks <= ₹180)
    if (recommendedProducts.length < 4) {
      const neededCount = 6 - recommendedProducts.length
      const alreadyRecommendedIds = new Set(recommendedProducts.map(p => p.id))
      const excludeIds = new Set([...cartProductIds, ...alreadyRecommendedIds])

      const fallbackProducts = await prisma.product.findMany({
        where: {
          id: { notIn: Array.from(excludeIds) },
          isAvailable: true,
          stock: { gt: 0 },
          price: { lte: 180 },
          ...typeFilter
        },
        include: { category: true },
        orderBy: [
          { isBestSeller: 'desc' },
          { sortOrder: 'desc' }
        ],
        take: neededCount
      })

      recommendedProducts = [...recommendedProducts, ...fallbackProducts]
    }

    // Return unique items, capped at 8 recommendations
    return NextResponse.json({ products: recommendedProducts.slice(0, 8) })
  } catch (error: any) {
    console.error('Upsell recommendation error:', error)
    return NextResponse.json({ products: [] }, { status: 200 })
  }
}
