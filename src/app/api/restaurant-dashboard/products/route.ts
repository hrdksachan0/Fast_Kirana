import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { getSessionRestaurantId } from '@/lib/restaurant-ids'
import { logger } from '@/lib/logger'
import { restaurantCatalogService } from '@/services/restaurant-catalog.service'
import { createDishSchema } from '@/lib/validations/restaurant-schemas'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    let session = null
    try {
      session = await auth()
    } catch (e) {
      logger.warn('auth', 'Auth check failed in restaurant products GET', e)
    }

    const storeIdParam = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId
    const paramRestId = searchParams.get('restaurantId')
    const effectiveRestId = getSessionRestaurantId(session, request, paramRestId)

    const data = await restaurantCatalogService.getDashboardCatalog(effectiveRestId, storeIdParam)
    return NextResponse.json(data)
  } catch (error: unknown) {
    logger.error('restaurant-products', 'Restaurant dashboard products GET error', error)
    const message = error instanceof Error ? error.message : 'Internal server error'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    let session = null
    try {
      session = await auth()
    } catch (e) {
      logger.warn('auth', 'Auth check failed in restaurant products POST', e)
    }

    const rawBody = await request.json()

    // Runtime Schema Validation with Zod
    const validationResult = createDishSchema.safeParse(rawBody)
    if (!validationResult.success) {
      const errorMsg = validationResult.error.issues[0]?.message || 'Invalid input data'
      return NextResponse.json({ error: errorMsg, details: validationResult.error.format() }, { status: 400 })
    }

    const validatedData = validationResult.data

    // Determine target restaurant ID cleanly
    const finalRestaurantId = getSessionRestaurantId(session, request, validatedData.restaurantId)
    if (!finalRestaurantId || finalRestaurantId === 'ALL') {
      return NextResponse.json({ error: 'Valid target restaurant ID is required to create a dish' }, { status: 400 })
    }

    const product = await restaurantCatalogService.createDish({
      ...validatedData,
      restaurantId: finalRestaurantId,
    })

    return NextResponse.json({ product, success: true }, { status: 201 })
  } catch (error: unknown) {
    logger.error('restaurant-products', 'Restaurant dashboard products POST error', error)
    const message = error instanceof Error ? error.message : 'Failed to create menu item'
    return NextResponse.json({ error: message }, { status: 500 })
  }
}
