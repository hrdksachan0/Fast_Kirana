import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { revalidateStorefront } from '@/lib/revalidate'

// Helper to create a unique URL-friendly slug
function slugify(text: string) {
  return text
    .toString()
    .toLowerCase()
    .replace(/\s+/g, '-') // Replace spaces with -
    .replace(/[^\w\-]+/g, '') // Remove all non-word chars
    .replace(/\-\-+/g, '-') // Replace multiple - with single -
    .replace(/^-+/, '') // Trim - from start
    .replace(/-+$/, '') // Trim - from end
}

export async function POST(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { items } = body as {
      items: Array<{
        barcode?: string
        readableId?: string | number
        name: string
        brand?: string
        categorySlug?: string
        mrp: string | number
        price: string | number
        stockQty: string | number
        unit?: string
        imageUrl?: string
      }>
    }

    if (!items || !Array.isArray(items) || items.length === 0) {
      return NextResponse.json({ error: 'Items array is required' }, { status: 400 })
    }

    // Load all categories for faster lookup
    const allCategories = await prisma.category.findMany()
    const categoryMap = new Map(allCategories.map(c => [c.slug, c]))

    // Get default category in case slug is missing or doesn't match
    const defaultCategory = allCategories[0] || await prisma.category.create({
      data: { name: 'Other Essentials', slug: 'other-essentials', sortOrder: 999 }
    })

    const results = {
      created: 0,
      updated: 0,
      errors: 0,
      errorDetails: [] as string[]
    }

    // Process all items sequentially in a transaction block to maintain database integrity
    await prisma.$transaction(async (tx) => {
      // Find the highest readableId to compute increments
      const lastProduct = await tx.product.findFirst({
        orderBy: { readableId: 'desc' }
      })
      let currentMaxReadableId = lastProduct?.readableId || 0

      for (let idx = 0; idx < items.length; idx++) {
        const item = items[idx]
        try {
          const name = item.name?.trim()
          if (!name) {
            throw new Error(`Row ${idx + 1}: Product name is required`)
          }

          const barcode = item.barcode?.trim() || null
          const parsedReadableId = item.readableId ? parseInt(String(item.readableId), 10) : null
          const mrp = parseFloat(String(item.mrp || 0))
          const price = parseFloat(String(item.price || 0))
          const stockQty = parseInt(String(item.stockQty || 0), 10)
          const unit = item.unit?.trim() || '1 pc'
          const brand = item.brand?.trim() || 'Generic'
          const imageUrl = item.imageUrl?.trim() || null
          const slugKey = item.categorySlug?.trim().toLowerCase() || 'other-essentials'

          // Find category
          const category = categoryMap.get(slugKey) || defaultCategory

          // Try to find existing product
          let existingProduct = null
          if (barcode) {
            existingProduct = await tx.product.findUnique({
              where: { barcode }
            })
          }

          if (!existingProduct && parsedReadableId && !isNaN(parsedReadableId)) {
            existingProduct = await tx.product.findUnique({
              where: { readableId: parsedReadableId }
            })
          }

          if (existingProduct) {
            // Product exists: Update price/MRP and increment stock
            const prevStock = existingProduct.stock
            const newStock = prevStock + Math.max(0, stockQty)

            await tx.product.update({
              where: { id: existingProduct.id },
              data: {
                mrp: mrp > 0 ? mrp : existingProduct.mrp,
                price: price > 0 ? price : existingProduct.price,
                stock: newStock,
                imageUrl: imageUrl || existingProduct.imageUrl,
                unit: unit || existingProduct.unit
              }
            })

            // Create stock log if stock is added
            if (stockQty > 0) {
              await tx.stockLog.create({
                data: {
                  productId: existingProduct.id,
                  quantity: stockQty,
                  type: 'BULK_IMPORT',
                  prevStock,
                  newStock
                }
              })
            }

            results.updated++
          } else {
            // Product does not exist: Create product
            currentMaxReadableId++
            const productSlug = `${slugify(name)}-${Math.random().toString(36).slice(2, 6)}`

            const newProduct = await tx.product.create({
              data: {
                name,
                slug: productSlug,
                readableId: currentMaxReadableId,
                barcode: barcode || null,
                mrp,
                price,
                stock: Math.max(0, stockQty),
                unit,
                imageUrl,
                categoryId: category.id,
                costPrice: mrp * 0.75, // smart fallback
                tags: [brand, slugKey].filter(Boolean)
              }
            })

            // Create stock log if initial stock is > 0
            if (stockQty > 0) {
              await tx.stockLog.create({
                data: {
                  productId: newProduct.id,
                  quantity: stockQty,
                  type: 'BULK_IMPORT',
                  prevStock: 0,
                  newStock: stockQty
                }
              })
            }

            results.created++
          }
        } catch (itemErr: any) {
          results.errors++
          results.errorDetails.push(itemErr.message || `Error processing row ${idx + 1}`)
        }
      }
    }, {
      timeout: 30000 // Give bulk transactions up to 30 seconds
    })

    // Trigger on-demand cache revalidation of the categories
    try {
      revalidateStorefront()
    } catch (e) {
      console.error('Storefront cache revalidation failed after bulk import:', e)
    }

    return NextResponse.json({
      success: true,
      message: `Bulk import completed: ${results.created} products created, ${results.updated} updated, ${results.errors} skipped due to errors.`,
      created: results.created,
      updated: results.updated,
      errors: results.errors,
      errorDetails: results.errorDetails
    })
  } catch (error: any) {
    console.error('Bulk import transaction error:', error)
    return NextResponse.json({ error: error.message || 'Internal Server Error' }, { status: 500 })
  }
}
