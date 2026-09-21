import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'
import { invalidateProductCache } from '@/lib/search-cache'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    const role = session?.user?.role || headerRole

    if (!role || (role !== 'PICKER' && role !== 'ADMIN')) {
      return NextResponse.json({ error: 'Unauthorized: Picker or Admin access required' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const search = searchParams.get('search')
    const categoryId = searchParams.get('categoryId')
    const barcode = searchParams.get('barcode')
    const limit = parseInt(searchParams.get('limit') || '50', 10)

    const where: any = {
      restaurantId: null, // Strictly grocery / dark store products
    }

    if (barcode) {
      where.barcode = barcode.trim()
    } else {
      if (categoryId && categoryId !== 'ALL') {
        where.categoryId = categoryId
      }
      if (search && search.trim().length > 0) {
        where.OR = [
          { name: { contains: search.trim(), mode: 'insensitive' } },
          { barcode: { contains: search.trim() } },
          { location: { contains: search.trim(), mode: 'insensitive' } },
        ]
      }
    }

    const products = await prisma.product.findMany({
      where,
      include: { category: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    })

    return NextResponse.json({ products })
  } catch (error: any) {
    console.error('[Picker Products GET Error]:', error)
    return NextResponse.json({ error: error?.message || 'Failed to fetch dark store products' }, { status: 500 })
  }
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    const role = session?.user?.role || headerRole

    if (!role || (role !== 'PICKER' && role !== 'ADMIN')) {
      return NextResponse.json({ error: 'Unauthorized: Picker or Admin role required to add products' }, { status: 401 })
    }

    const body = await request.json()
    const {
      name,
      categoryId,
      mrp,
      price,
      unit,
      stock,
      minStock,
      location,
      barcode,
      imageUrl,
      description,
      expiryDate,
      tags,
    } = body

    // ─── Rule 1: Mandatory Field Validation ─────────────────────────────────
    if (!name || !name.trim()) {
      return NextResponse.json({ error: 'Product name is required' }, { status: 400 })
    }
    if (mrp === undefined || mrp === null || isNaN(parseFloat(mrp))) {
      return NextResponse.json({ error: 'Valid MRP is required' }, { status: 400 })
    }
    if (price === undefined || price === null || isNaN(parseFloat(price))) {
      return NextResponse.json({ error: 'Valid selling price is required' }, { status: 400 })
    }

    const parsedMrp = parseFloat(mrp)
    const parsedPrice = parseFloat(price)
    const parsedStock = parseInt(String(stock ?? 10), 10) || 0
    const parsedMinStock = parseInt(String(minStock ?? 5), 10) || 5

    // ─── Rule 2: Pricing Logic Checks ───────────────────────────────────────
    if (parsedMrp <= 0) {
      return NextResponse.json({ error: 'MRP must be greater than 0' }, { status: 400 })
    }
    if (parsedPrice <= 0) {
      return NextResponse.json({ error: 'Selling price must be greater than 0' }, { status: 400 })
    }
    if (parsedPrice > parsedMrp) {
      return NextResponse.json({ error: 'Selling price cannot exceed MRP' }, { status: 400 })
    }

    // ─── Rule 3: Category Isolation (Grocery Only) ──────────────────────────
    let targetCategoryId = categoryId
    if (!targetCategoryId) {
      const firstGroceryCat = await prisma.category.findFirst({
        where: {
          slug: {
            notIn: ['restaurant-food', 'restaurant', 'cafe', 'fast-food-kitchen'],
          },
        },
        orderBy: { sortOrder: 'asc' },
      })
      targetCategoryId = firstGroceryCat?.id
    } else {
      const selectedCat = await prisma.category.findUnique({
        where: { id: targetCategoryId },
      })
      if (!selectedCat) {
        return NextResponse.json({ error: 'Invalid category selected' }, { status: 400 })
      }
      const catSlug = selectedCat.slug.toLowerCase()
      if (
        catSlug.includes('restaurant') ||
        catSlug.includes('cafe') ||
        catSlug === 'fast-food-kitchen'
      ) {
        return NextResponse.json(
          { error: 'Pickers cannot add products to restaurant/cafe categories' },
          { status: 400 }
        )
      }
    }

    if (!targetCategoryId) {
      return NextResponse.json({ error: 'No valid grocery category found' }, { status: 400 })
    }

    // ─── Rule 4: Barcode Uniqueness Guard ───────────────────────────────────
    const cleanBarcode = barcode && typeof barcode === 'string' ? barcode.trim() : null
    if (cleanBarcode) {
      const existingWithBarcode = await prisma.product.findFirst({
        where: { barcode: cleanBarcode },
        select: { id: true, name: true, stock: true },
      })
      if (existingWithBarcode) {
        return NextResponse.json(
          {
            error: `A product with barcode "${cleanBarcode}" already exists: "${existingWithBarcode.name}" (Stock: ${existingWithBarcode.stock})`,
            duplicateProductId: existingWithBarcode.id,
          },
          { status: 409 }
        )
      }
    }

    // ─── Rule 5: Calculate Discount & Slug ──────────────────────────────────
    const discountVal =
      parsedMrp > parsedPrice ? Math.max(0, Math.round(((parsedMrp - parsedPrice) / parsedMrp) * 100)) : 0

    const baseSlug = name
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '') || `item-${Date.now()}`
    const existingSlugCount = await prisma.product.count({ where: { slug: { startsWith: baseSlug } } })
    const finalSlug =
      existingSlugCount > 0
        ? `${baseSlug}-${existingSlugCount + 1}-${Date.now().toString().slice(-4)}`
        : baseSlug

    // Get next readableId
    const lastProduct = await prisma.product.findFirst({
      orderBy: { readableId: 'desc' },
      select: { readableId: true },
    })
    const nextReadableId = lastProduct?.readableId ? lastProduct.readableId + 1 : 200001

    // Pack tags
    const tagsList = Array.isArray(tags) ? [...tags] : []
    if (!tagsList.includes('grocery')) tagsList.push('grocery')
    if (!tagsList.includes('darkstore')) tagsList.push('darkstore')

    // Parse expiry date if provided
    let parsedExpiry: Date | null = null
    if (expiryDate) {
      try {
        parsedExpiry = new Date(expiryDate)
      } catch (_) {}
    }

    // ─── Rule 6: Strictly Enforce restaurantId: null ────────────────────────
    const product = await prisma.product.create({
      data: {
        name: name.trim(),
        slug: finalSlug,
        readableId: nextReadableId,
        categoryId: targetCategoryId,
        restaurantId: null, // STRICTLY ENFORCED GROCERY DOMAIN
        mrp: parsedMrp,
        price: parsedPrice,
        discount: discountVal,
        unit: (unit && typeof unit === 'string' && unit.trim()) ? unit.trim() : '1 pc',
        stock: parsedStock,
        minStock: parsedMinStock,
        location: (location && typeof location === 'string') ? location.trim() : null,
        barcode: cleanBarcode,
        imageUrl: imageUrl || null,
        description: description || null,
        expiryDate: parsedExpiry,
        tags: tagsList,
        isAvailable: parsedStock > 0,
      },
      include: {
        category: true,
      },
    })

    try {
      revalidateStorefront(product.category?.slug)
      await invalidateProductCache()
    } catch (e) {
      console.warn('[Picker Products] Cache invalidation warning:', e)
    }

    return NextResponse.json({ product, success: true }, { status: 201 })
  } catch (error: any) {
    console.error('[Picker Products POST Error]:', error)
    return NextResponse.json({ error: error?.message || 'Failed to add grocery product' }, { status: 500 })
  }
}

export async function PATCH(request: NextRequest) {
  try {
    const session = await auth()
    const headerRole = request.headers.get('x-user-role')?.toUpperCase()
    const role = session?.user?.role || headerRole

    if (!role || (role !== 'PICKER' && role !== 'ADMIN')) {
      return NextResponse.json({ error: 'Unauthorized: Picker or Admin role required' }, { status: 401 })
    }

    const body = await request.json()
    const {
      id,
      productId,
      barcode,
      mrp,
      price,
      stock,
      unit,
      isAvailable,
      location,
      variants,
    } = body

    const targetId = id || productId
    if (!targetId && !barcode) {
      return NextResponse.json({ error: 'Product ID or Barcode is required' }, { status: 400 })
    }

    const where: any = {}
    if (targetId) {
      where.id = targetId
    } else if (barcode) {
      where.barcode = barcode.trim()
    }

    const existingProduct = await prisma.product.findFirst({
      where,
      include: { category: true },
    })

    if (!existingProduct) {
      return NextResponse.json({ error: 'Product not found' }, { status: 404 })
    }

    // STRICT GUARD: Pickers can only edit grocery products, NEVER restaurant food items
    if (existingProduct.restaurantId !== null) {
      return NextResponse.json(
        { error: 'Pickers are strictly restricted to dark store / grocery products. Restaurant items cannot be edited by pickers.' },
        { status: 403 }
      )
    }

    const updateData: any = {}

    // Variant handling
    let sortedVariants = variants
    if (variants && Array.isArray(variants) && variants.length > 0) {
      for (const v of variants) {
        if (!v.name || !v.name.toString().trim()) {
          return NextResponse.json({ error: 'All variants must have a name (e.g. 500g, 1kg)' }, { status: 400 })
        }
        const vPrice = parseFloat(v.price)
        const vMrp = parseFloat(v.mrp) || vPrice
        if (isNaN(vPrice) || vPrice <= 0) {
          return NextResponse.json({ error: `Variant "${v.name}" must have a price greater than 0` }, { status: 400 })
        }
        if (vPrice > vMrp) {
          return NextResponse.json({ error: `Variant "${v.name}" price (₹${vPrice}) cannot exceed MRP (₹${vMrp})` }, { status: 400 })
        }
      }

      sortedVariants = [...variants]
        .map((v: any) => ({
          name: v.name.toString().trim(),
          price: parseFloat(v.price),
          mrp: parseFloat(v.mrp) || parseFloat(v.price),
          stock: parseInt(String(v.stock ?? 20), 10) || 0,
          unit: v.unit ? String(v.unit).trim() : undefined,
        }))
        .sort((a, b) => a.price - b.price)

      updateData.variants = sortedVariants
    } else if (variants !== undefined) {
      updateData.variants = []
    }

    // Pricing validation
    let currentMrp = existingProduct.mrp
    let currentPrice = existingProduct.price

    if (mrp !== undefined && mrp !== null) {
      const parsedMrp = parseFloat(mrp)
      if (isNaN(parsedMrp) || parsedMrp <= 0) {
        return NextResponse.json({ error: 'MRP must be a number greater than 0' }, { status: 400 })
      }
      currentMrp = parsedMrp
      updateData.mrp = parsedMrp
    } else if (sortedVariants && Array.isArray(sortedVariants) && sortedVariants.length > 0) {
      currentMrp = sortedVariants[0].mrp
      updateData.mrp = sortedVariants[0].mrp
    }

    if (price !== undefined && price !== null) {
      const parsedPrice = parseFloat(price)
      if (isNaN(parsedPrice) || parsedPrice <= 0) {
        return NextResponse.json({ error: 'Selling price must be a number greater than 0' }, { status: 400 })
      }
      currentPrice = parsedPrice
      updateData.price = parsedPrice
    } else if (sortedVariants && Array.isArray(sortedVariants) && sortedVariants.length > 0) {
      currentPrice = sortedVariants[0].price
      updateData.price = sortedVariants[0].price
    }

    if (currentPrice > currentMrp) {
      return NextResponse.json(
        { error: `Selling price (₹${currentPrice}) cannot exceed MRP (₹${currentMrp})` },
        { status: 400 }
      )
    }

    // Auto calculate discount percentage
    updateData.discount = currentMrp > currentPrice
      ? Math.max(0, Math.round(((currentMrp - currentPrice) / currentMrp) * 100))
      : 0

    // Optional stock & availability
    if (stock !== undefined && stock !== null) {
      const parsedStock = parseInt(String(stock), 10)
      if (!isNaN(parsedStock) && parsedStock >= 0) {
        updateData.stock = parsedStock
        if (isAvailable === undefined) {
          updateData.isAvailable = parsedStock > 0
        }
      }
    }

    if (isAvailable !== undefined && isAvailable !== null) {
      updateData.isAvailable = Boolean(isAvailable)
    }

    if (unit !== undefined && typeof unit === 'string' && unit.trim()) {
      updateData.unit = unit.trim()
    }

    if (location !== undefined && typeof location === 'string') {
      updateData.location = location.trim()
    }

    const updatedProduct = await prisma.product.update({
      where: { id: existingProduct.id },
      data: updateData,
      include: { category: true },
    })

    try {
      revalidateStorefront(updatedProduct.category?.slug)
      await invalidateProductCache()
    } catch (e) {
      console.warn('[Picker Products PATCH] Cache invalidation warning:', e)
    }

    return NextResponse.json({
      success: true,
      product: updatedProduct,
      message: `Updated pricing for ${updatedProduct.name}: ₹${updatedProduct.price} (MRP: ₹${updatedProduct.mrp}, ${updatedProduct.discount}% OFF)`,
    })
  } catch (error: any) {
    console.error('[Picker Products PATCH Error]:', error)
    return NextResponse.json({ error: error?.message || 'Failed to update grocery product pricing' }, { status: 500 })
  }
}

