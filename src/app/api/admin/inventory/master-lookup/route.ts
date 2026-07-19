import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { MASTER_CATALOG } from '@/lib/master-catalog'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const barcode = searchParams.get('barcode')

    if (!barcode) {
      return NextResponse.json({ error: 'Barcode parameter is required' }, { status: 400 })
    }

    // 1. Query the database first
    const dbProduct = await prisma.product.findUnique({
      where: { barcode },
      include: {
        category: true
      }
    })

    if (dbProduct) {
      return NextResponse.json({
        exists: true,
        foundInMaster: false,
        product: {
          id: dbProduct.id,
          readableId: dbProduct.readableId,
          name: dbProduct.name,
          mrp: dbProduct.mrp,
          price: dbProduct.price,
          stock: dbProduct.stock,
          unit: dbProduct.unit,
          imageUrl: dbProduct.imageUrl,
          categoryName: dbProduct.category?.name || '',
          categorySlug: dbProduct.category?.slug || '',
          costPrice: dbProduct.costPrice
        }
      })
    }

    // 2. Query the local master catalog list
    const masterProduct = MASTER_CATALOG.find(p => p.barcode === barcode)
    if (masterProduct) {
      // Find category ID matching categorySlug
      const dbCategory = await prisma.category.findUnique({
        where: { slug: masterProduct.categorySlug }
      })

      return NextResponse.json({
        exists: false,
        foundInMaster: true,
        product: {
          barcode: masterProduct.barcode,
          name: masterProduct.name,
          brand: masterProduct.brand,
          categoryName: masterProduct.categoryName,
          categorySlug: masterProduct.categorySlug,
          categoryId: dbCategory?.id || '',
          mrp: masterProduct.mrp,
          price: masterProduct.price,
          unit: masterProduct.unit,
          imageUrl: masterProduct.imageUrl
        }
      })
    }

    // 3. Not found anywhere
    return NextResponse.json({
      exists: false,
      foundInMaster: false
    })
  } catch (error: any) {
    console.error('Master catalog lookup error:', error)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
