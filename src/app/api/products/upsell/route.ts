import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { Prisma } from '@prisma/client'
import { OUTLET_AS_RESTAURANT_ID, OUTLET_WEDSON_ID } from '@/lib/constants'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const productIdsStr = searchParams.get('productIds') || ''
    
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

    const isASCart = cartProducts.some(p => 
      p.restaurantId === OUTLET_AS_RESTAURANT_ID || 
      p.tags?.some(t => ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant'].includes(t.toLowerCase()))
    )
    const isWedsonCart = cartProducts.some(p => 
      p.restaurantId === OUTLET_WEDSON_ID || 
      p.tags?.some(t => ['wedson', 'wedson-restaurant'].includes(t.toLowerCase()))
    )
    const isCafeCategoryCart = cartProducts.some(p => 
      p.category?.slug === 'cafe' || p.category?.slug === 'fastkirana-cafe' || p.tags?.some(t => ['cafe', 'shakes'].includes(t.toLowerCase()))
    )

    // Enforce strict separation: A.S. Restaurant suggests A.S., Wedson suggests Wedson, Cafe suggests Cafe, Grocery suggests Grocery
    const typeFilter: Prisma.ProductWhereInput = {}
    if (isASCart) {
      typeFilter.OR = [
        { restaurantId: OUTLET_AS_RESTAURANT_ID },
        { restaurant: { slug: { in: ['as-restaurant', 'as-cafe'] } } },
        { tags: { hasSome: ['as-restaurant', 'as-cafe', 'as_restaurant', 'a.s restaurant', 'a.s. restaurant'] } }
      ]
    } else if (isWedsonCart) {
      typeFilter.OR = [
        { restaurantId: OUTLET_WEDSON_ID },
        { restaurant: { slug: { in: ['wedson', 'restaurant-kitchen'] } } },
        { tags: { hasSome: ['wedson', 'wedson-restaurant'] } }
      ]
    } else if (isCafeCategoryCart) {
      typeFilter.OR = [
        { category: { slug: { in: ['cafe', 'fastkirana-cafe', 'ice-cream', 'beverages', 'shakes'] } } },
        { tags: { hasSome: ['cafe', 'ice-cream', 'beverages', 'shakes', 'mocktails'] } }
      ]
    } else {
      // Pure grocery cart: strictly exclude restaurant & cafe products!
      typeFilter.AND = [
        { restaurantId: null },
        { tags: { noneOf: ['as-restaurant', 'as-cafe', 'wedson', 'wedson-restaurant'] } }
      ]
    }

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
              stock: { gt: 0 }
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

    // 3. Fallback to Tag-Based association rules
    if (recommendedProducts.length < 4) {
      const neededCount = 6 - recommendedProducts.length
      const alreadyRecommendedIds = new Set(recommendedProducts.map(p => p.id))
      const excludeIds = new Set([...cartProductIds, ...alreadyRecommendedIds])

      // Define tag association mapping
      const targetTags = new Set<string>()
      
      if (isASCart || isWedsonCart) {
        // For restaurant, recommend curries, rotis, naans, biryanis or other restaurant tags
        ['north-indian', 'curry', 'roti', 'naan', 'south-indian', 'biryani-rice', 'chinese'].forEach(t => targetTags.add(t))
      } else if (isCafeCategoryCart) {
        if (cartTags.has('burgers') || cartTags.has('burger')) {
          ['shakes', 'mocktails', 'coolers', 'cold-drink', 'beverages', 'drinks', 'fries'].forEach(t => targetTags.add(t))
        }
        if (cartTags.has('sandwiches') || cartTags.has('sandwich')) {
          ['shakes', 'mocktails', 'cold-coffee', 'beverages'].forEach(t => targetTags.add(t))
        }
        if (cartTags.has('hot-beverage') || cartTags.has('tea') || cartTags.has('coffee')) {
          ['bakery', 'snacks', 'hot-bite'].forEach(t => targetTags.add(t))
        }
        if (cartTags.has('chinese') || cartTags.has('noodles') || cartTags.has('frankie-rolls')) {
          ['drinks', 'beverages', 'mocktails', 'chilled'].forEach(t => targetTags.add(t))
        }
      } else {
        if (cartTags.has('staples') || cartTags.has('cooking')) {
          ['dairy', 'breakfast'].forEach(t => targetTags.add(t))
        }
        if (cartTags.has('breakfast') || cartTags.has('dairy')) {
          ['bakery', 'bread', 'snacks'].forEach(t => targetTags.add(t))
        }
      }

      let tagMatchingProducts: any[] = []
      if (targetTags.size > 0) {
        tagMatchingProducts = await prisma.product.findMany({
          where: {
            id: { notIn: Array.from(excludeIds) },
            isAvailable: true,
            stock: { gt: 0 },
            tags: { hasSome: Array.from(targetTags) },
            ...typeFilter
          },
          include: { category: true },
          take: neededCount
        })
      }

      recommendedProducts = [...recommendedProducts, ...tagMatchingProducts]
    }

    // 4. Ultimate fallback: Cheap popular items (< ₹150) matching the exact department
    if (recommendedProducts.length < 4) {
      const neededCount = 6 - recommendedProducts.length
      const alreadyRecommendedIds = new Set(recommendedProducts.map(p => p.id))
      const excludeIds = new Set([...cartProductIds, ...alreadyRecommendedIds])

      const fallbackProducts = await prisma.product.findMany({
        where: {
          id: { notIn: Array.from(excludeIds) },
          isAvailable: true,
          stock: { gt: 0 },
          price: { lt: 150 },
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

    // Return unique items, capped at 6 recommendations
    return NextResponse.json({ products: recommendedProducts.slice(0, 6) })
  } catch (error: any) {
    console.error('Upsell recommendation error:', error)
    return NextResponse.json({ error: 'Failed to generate recommendations' }, { status: 500 })
  }
}
