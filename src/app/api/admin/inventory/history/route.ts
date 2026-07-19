import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'

export async function GET(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user || (session.user as any).role !== 'ADMIN') {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const limit = parseInt(searchParams.get('limit') || '100', 10)
    const offset = parseInt(searchParams.get('offset') || '0', 10)
    const productId = searchParams.get('productId')

    const where: any = {}
    if (productId) {
      where.productId = productId
    }

    const [logs, total] = await Promise.all([
      prisma.stockLog.findMany({
        where,
        orderBy: {
          createdAt: 'desc'
        },
        take: limit,
        skip: offset,
        include: {
          product: {
            select: {
              name: true,
              readableId: true,
              barcode: true,
              unit: true
            }
          }
        }
      }),
      prisma.stockLog.count({ where })
    ])

    return NextResponse.json({
      logs,
      total,
      limit,
      offset
    })
  } catch (error: any) {
    console.error('Fetch stock history error:', error)
    return NextResponse.json({ error: 'Internal Server Error' }, { status: 500 })
  }
}
