import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { couponLimiter } from '@/lib/rate-limit'
import { validateCouponSchema, validateBodyLegacy } from '@/lib/validation'

export async function POST(request: NextRequest) {
  const limited = await couponLimiter.check(request)
  if (limited) return limited

  const validation = await validateBodyLegacy(request, validateCouponSchema)
  if (!validation.success) return validation.error

  const { code, subtotal, items } = validation.data

  try {
    const session = await auth()

    const coupon = await prisma.coupon.findUnique({
      where: { code: code.toUpperCase() },
    })

    if (!coupon || !coupon.isActive) {
      return NextResponse.json({ error: 'Invalid or inactive coupon code' }, { status: 400 })
    }

    if (coupon.oncePerCustomer) {
      if (!session?.user?.id) {
        return NextResponse.json({ error: 'Please log in to use this coupon' }, { status: 400 })
      }
      const alreadyUsed = await prisma.order.findFirst({
        where: {
          userId: session.user.id,
          couponCode: code.toUpperCase(),
          status: { not: 'CANCELLED' }
        }
      })
      if (alreadyUsed) {
        return NextResponse.json({ error: 'You have already used this coupon code once' }, { status: 400 })
      }
    }

    if (coupon.expiresAt && new Date(coupon.expiresAt) < new Date()) {
      return NextResponse.json({ error: 'Coupon code has expired' }, { status: 400 })
    }

    if (coupon.maxUses && coupon.usedCount >= coupon.maxUses) {
      return NextResponse.json({ error: 'Coupon code limit reached' }, { status: 400 })
    }

    let eligibleSubtotal = subtotal
    let discountAmount = 0
    let nudgeMessage: string | null = null
    let freeGiftDetails: any = null

    // 1. Category-restricted coupon
    if (coupon.categoryId) {
      if (!items || items.length === 0) {
        return NextResponse.json({ error: 'This coupon is restricted to a category. Cart items are required.' }, { status: 400 })
      }

      const categoryItems = items.filter((item: any) => item.categoryId === coupon.categoryId)
      const categorySubtotal = categoryItems.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)

      if (categorySubtotal === 0) {
        return NextResponse.json({ error: 'This coupon is only valid for items in the restricted category.' }, { status: 400 })
      }

      if (categorySubtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} in the restricted category is required.` },
          { status: 400 }
        )
      }
      eligibleSubtotal = categorySubtotal
    } 
    // 2. Restaurant-restricted coupon (including BOGO & Free Delivery)
    else if (coupon.restaurantId) {
      if (!items || items.length === 0) {
        return NextResponse.json({ error: 'Cart items from this restaurant are required.' }, { status: 400 })
      }

      const restaurant = await prisma.restaurant.findUnique({
        where: { id: coupon.restaurantId },
        select: { id: true, name: true, slug: true }
      })

      const restaurantItems = items.filter((item: any) => {
        const itemRestaurantId = item.restaurantId || item.product?.restaurantId
        return itemRestaurantId === coupon.restaurantId
      })
      const restaurantSubtotal = restaurantItems.reduce((sum: number, item: any) => sum + (item.price * item.quantity), 0)

      if (restaurantSubtotal === 0) {
        return NextResponse.json({ error: `This coupon is only valid for items from ${restaurant?.name || 'this restaurant'}.` }, { status: 400 })
      }

      if (restaurantSubtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} from ${restaurant?.name || 'this restaurant'} is required.` },
          { status: 400 }
        )
      }
      eligibleSubtotal = restaurantSubtotal

      // ── BOGO CALCULATION ENGINE ──
      if (coupon.discountType === 'BOGO') {
        const maxFreeCap = coupon.maxFreeItems || 3

        if (coupon.bogoType === 'BUY_LARGE_GET_SMALL') {
          const triggerVariant = (coupon.triggerVariant || 'large').toLowerCase().trim()
          const rewardVariant = (coupon.rewardVariant || 'small').toLowerCase().trim()

          // Trigger Items (e.g. Large pizzas)
          const triggerItems = restaurantItems.filter((it: any) => {
            const v = (it.selectedVariant || it.variant || it.name || '').toLowerCase()
            return v.includes(triggerVariant)
          })
          const totalTriggerQty = triggerItems.reduce((acc: number, it: any) => acc + (it.quantity || 1), 0)

          if (totalTriggerQty === 0) {
            return NextResponse.json({
              error: `This offer requires adding a ${coupon.triggerVariant || 'Large'} item from ${restaurant?.name || 'this restaurant'}.`,
            }, { status: 400 })
          }

          // Reward Items (e.g. Small pizzas)
          const rewardItems = restaurantItems.filter((it: any) => {
            const v = (it.selectedVariant || it.variant || it.name || '').toLowerCase()
            return v.includes(rewardVariant)
          })

          const allowedFreeCount = Math.min(totalTriggerQty, maxFreeCap)

          if (rewardItems.length === 0) {
            // Free item not yet in cart -> Nudge customer or trigger auto-drop
            nudgeMessage = `Add any ${coupon.rewardVariant || 'Small'} item to get it 100% FREE! 🎁`
            discountAmount = 0
            
            // Look up default free dish if configured
            if (coupon.defaultFreeDishId) {
              try {
                const defaultDish = await prisma.foodDish.findUnique({
                  where: { id: coupon.defaultFreeDishId },
                  select: { id: true, name: true, price: true, imageUrl: true }
                })
                if (defaultDish) {
                  freeGiftDetails = {
                    ...defaultDish,
                    rewardVariant: coupon.rewardVariant || 'Small',
                    eligibleQty: allowedFreeCount
                  }
                }
              } catch (err) {
                console.warn('Failed to load default free dish:', err)
              }
            }
          } else {
            // Reward items are in cart -> Sort cheapest first and discount 100%
            const sortedRewards = [...rewardItems].sort((a: any, b: any) => a.price - b.price)
            let remainingFree = allowedFreeCount
            let bogoSavings = 0

            for (const item of sortedRewards) {
              const freeQty = Math.min(item.quantity, remainingFree)
              bogoSavings += freeQty * item.price
              remainingFree -= freeQty
              if (remainingFree <= 0) break
            }

            discountAmount = bogoSavings
            if (coupon.maxDiscount) {
              discountAmount = Math.min(discountAmount, coupon.maxDiscount)
            }
          }
        } 
        else if (coupon.bogoType === 'CHEAPEST_FREE') {
          const totalQty = restaurantItems.reduce((acc: number, it: any) => acc + (it.quantity || 1), 0)
          if (totalQty < 2) {
            return NextResponse.json({
              error: `Add at least 2 dishes from ${restaurant?.name || 'this restaurant'} to get the cheapest one FREE!`,
            }, { status: 400 })
          }

          // Flatten into unit items to find the single cheapest item
          const unitPrices: number[] = []
          restaurantItems.forEach((it: any) => {
            const qty = it.quantity || 1
            for (let i = 0; i < qty; i++) {
              unitPrices.push(it.price)
            }
          })
          unitPrices.sort((a, b) => a - b)
          discountAmount = unitPrices[0] || 0
          if (coupon.maxDiscount) {
            discountAmount = Math.min(discountAmount, coupon.maxDiscount)
          }
        } 
        else {
          // SAME_ITEM BOGO (Default)
          let eligibleItems = restaurantItems
          if (coupon.bogoDishId) {
            eligibleItems = restaurantItems.filter((it: any) => {
              const pid = it.productId || it.id
              return pid === coupon.bogoDishId
            })
          }

          let totalBogoDiscount = 0
          let totalFreeUnlocked = 0

          for (const it of eligibleItems) {
            const pairs = Math.floor((it.quantity || 1) / 2)
            const freeCount = Math.min(pairs, maxFreeCap - totalFreeUnlocked)
            if (freeCount > 0) {
              totalBogoDiscount += freeCount * it.price
              totalFreeUnlocked += freeCount
            }
          }

          if (totalBogoDiscount === 0) {
            const singleItems = eligibleItems.filter((it: any) => (it.quantity || 1) === 1)
            if (singleItems.length > 0) {
              nudgeMessage = `Add 1 more ${singleItems[0].name || 'item'} to get 1 FREE! 🎁`
            }
            return NextResponse.json({
              error: nudgeMessage || `Add 2 of the same eligible item to unlock Buy 1 Get 1 Free!`,
              nudgeMessage,
            }, { status: 400 })
          }

          discountAmount = totalBogoDiscount
          if (coupon.maxDiscount) {
            discountAmount = Math.min(discountAmount, coupon.maxDiscount)
          }
        }
      }
      // ── FREE DELIVERY CALCULATION ──
      else if (coupon.discountType === 'FREE_DELIVERY') {
        discountAmount = 25.0 // Standard restaurant delivery fee waived
      }
    } 
    // 3. Global coupon
    else {
      if (subtotal < coupon.minOrder) {
        return NextResponse.json(
          { error: `Minimum order of ₹${coupon.minOrder} required for this coupon` },
          { status: 400 }
        )
      }
    }

    // Standard PERCENT & FLAT discount calculations (if not BOGO or FREE_DELIVERY)
    if (coupon.discountType === 'FLAT') {
      discountAmount = Math.min(coupon.value, eligibleSubtotal)
    } else if (coupon.discountType === 'PERCENT') {
      discountAmount = (eligibleSubtotal * coupon.value) / 100
      if (coupon.maxDiscount) {
        discountAmount = Math.min(discountAmount, coupon.maxDiscount)
      }
    }

    return NextResponse.json({
      message: 'Coupon applied successfully!',
      coupon: {
        id: coupon.id,
        code: coupon.code,
        discountType: coupon.discountType,
        bogoType: coupon.bogoType,
        triggerVariant: coupon.triggerVariant,
        rewardVariant: coupon.rewardVariant,
        badgeText: coupon.badgeText || (coupon.discountType === 'BOGO' ? 'BUY 1 GET 1 FREE' : undefined),
        value: coupon.value,
        discountAmount: Math.round(discountAmount * 100) / 100,
        nudgeMessage,
        freeGiftDetails,
      },
    })
  } catch (error: any) {
    console.error('Coupon validation error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
