import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

export async function POST(request: NextRequest) {
  const session = await auth()
  if (!session || session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    const body = await request.json()
    const { products } = body

    if (!Array.isArray(products) || products.length === 0) {
      return NextResponse.json({ error: 'No products provided' }, { status: 400 })
    }

    if (products.length > 500) {
      return NextResponse.json({ error: 'Maximum 500 products per import' }, { status: 400 })
    }

    const results: { created: number; skipped: number; errors: string[] } = {
      created: 0,
      skipped: 0,
      errors: [],
    }

    // Fetch all existing slugs to check for duplicates
    const existingSlugs = new Set(
      (await prisma.product.findMany({ select: { slug: true } })).map(p => p.slug)
    )

    // Fetch all categories for lookup
    const categories = await prisma.category.findMany({
      select: { id: true, name: true, slug: true }
    })

    const categoryByName = new Map<string, string>()
    const categoryBySlug = new Map<string, string>()
    categories.forEach(c => {
      categoryByName.set(c.name.toLowerCase().trim(), c.id)
      categoryBySlug.set(c.slug.toLowerCase().trim(), c.id)
    })

    const createdProducts: any[] = []

    for (let i = 0; i < products.length; i++) {
      const item = products[i]
      const rowNum = i + 1

      try {
        // Validate required fields
        if (!item.name || !item.name.trim()) {
          results.errors.push(`Row ${rowNum}: Name is required`)
          results.skipped++
          continue
        }
        if (!item.category || !item.category.trim()) {
          results.errors.push(`Row ${rowNum} (${item.name}): Category is required`)
          results.skipped++
          continue
        }
        if (!item.unit || !item.unit.trim()) {
          results.errors.push(`Row ${rowNum} (${item.name}): Unit is required`)
          results.skipped++
          continue
        }

        const mrp = parseFloat(item.mrp)
        const price = parseFloat(item.price)

        if (isNaN(mrp) || mrp <= 0) {
          results.errors.push(`Row ${rowNum} (${item.name}): Invalid MRP`)
          results.skipped++
          continue
        }
        if (isNaN(price) || price <= 0) {
          results.errors.push(`Row ${rowNum} (${item.name}): Invalid Price`)
          results.skipped++
          continue
        }

        // Find category by name or slug
        const catKey = item.category.toLowerCase().trim()
        const categoryId = categoryByName.get(catKey) || categoryBySlug.get(catKey)

        if (!categoryId) {
          results.errors.push(`Row ${rowNum} (${item.name}): Category "${item.category}" not found`)
          results.skipped++
          continue
        }

        // Generate slug
        let slug = item.name
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-|-$)+/g, '')

        // Make slug unique
        if (existingSlugs.has(slug)) {
          slug = `${slug}-${Date.now().toString().slice(-4)}-${i}`
        }
        existingSlugs.add(slug)

        const stock = parseInt(item.stock) || 0
        const discount = mrp > price ? Math.max(0, Math.round(((mrp - price) / mrp) * 100)) : 0
        const tags = item.tags
          ? item.tags.split(',').map((t: string) => t.trim()).filter((t: string) => t.length > 0)
          : []
        const costPrice = parseFloat(item.costPrice) || 0

        const product = await prisma.product.create({
          data: {
            name: item.name.trim(),
            slug,
            description: item.description?.trim() || '',
            imageUrl: item.imageUrl?.trim() || '📦',
            categoryId,
            mrp,
            price,
            discount,
            unit: item.unit.trim(),
            stock,
            isAvailable: true,
            tags,
            costPrice,
            minStock: parseInt(item.minStock) || 10,
          },
          include: { category: true },
        })

        createdProducts.push(product)
        results.created++
      } catch (err: any) {
        results.errors.push(`Row ${rowNum} (${item.name || 'unknown'}): ${err.message}`)
        results.skipped++
      }
    }

    // Revalidate storefront
    try {
      revalidateStorefront()
    } catch (e) {
      // ignore revalidation errors
    }

    return NextResponse.json({
      ...results,
      products: createdProducts,
    })
  } catch (error: any) {
    console.error('Bulk import error:', error)
    return NextResponse.json({ error: 'Bulk import failed' }, { status: 500 })
  }
}
