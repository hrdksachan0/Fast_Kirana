import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { updateTag } from 'next/cache'
import { revalidateStorefront } from '@/lib/revalidate'

// Helper to authenticate admin
async function checkAdmin() {
  const session = await auth()
  return session?.user && (session.user as any).role === 'ADMIN'
}

// GET: Retrieve all banners (for admin console list)
export async function GET() {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const banners = await prisma.promoBanner.findMany({
      orderBy: {
        sortOrder: 'asc'
      }
    })

    return NextResponse.json(banners)
  } catch (error: any) {
    console.error('Error fetching admin banners:', error)
    return NextResponse.json({ error: 'Failed to fetch banners' }, { status: 500 })
  }
}

// POST: Create a new promo banner
export async function POST(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { title, description, code, gradient, type, imageUrl, linkUrl, isActive, sortOrder } = body

    if (!title || !description) {
      return NextResponse.json(
        { error: 'Missing required fields: title, description' },
        { status: 400 }
      )
    }

    const banner = await prisma.promoBanner.create({
      data: {
        title,
        description,
        code: code || '',
        gradient: gradient || 'from-primary via-rose-500 to-orange-400',
        type: type || 'custom',
        imageUrl: imageUrl || null,
        linkUrl: linkUrl || null,
        isActive: isActive !== undefined ? isActive : true,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : 0,
      }
    })

    // Purge caches immediately
    updateTag('banners')
    revalidateStorefront()

    return NextResponse.json({ success: true, banner })
  } catch (error: any) {
    console.error('Error creating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to create banner' }, { status: 500 })
  }
}

// PUT: Update an existing promo banner
export async function PUT(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const body = await request.json()
    const { id, title, description, code, gradient, type, imageUrl, linkUrl, isActive, sortOrder } = body

    if (!id) {
      return NextResponse.json({ error: 'Missing banner ID' }, { status: 400 })
    }

    // Verify banner exists
    const existing = await prisma.promoBanner.findUnique({
      where: { id }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Banner not found' }, { status: 404 })
    }

    const updated = await prisma.promoBanner.update({
      where: { id },
      data: {
        title: title !== undefined ? title : existing.title,
        description: description !== undefined ? description : existing.description,
        code: code !== undefined ? code : existing.code,
        gradient: gradient !== undefined ? gradient : existing.gradient,
        type: type !== undefined ? type : existing.type,
        imageUrl: imageUrl !== undefined ? imageUrl : existing.imageUrl,
        linkUrl: linkUrl !== undefined ? linkUrl : existing.linkUrl,
        isActive: isActive !== undefined ? isActive : existing.isActive,
        sortOrder: sortOrder !== undefined ? parseInt(String(sortOrder), 10) : existing.sortOrder,
      }
    })

    // Purge caches immediately
    updateTag('banners')
    revalidateStorefront()

    return NextResponse.json({ success: true, banner: updated })
  } catch (error: any) {
    console.error('Error updating banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to update banner' }, { status: 500 })
  }
}

// DELETE: Delete a promo banner
export async function DELETE(request: NextRequest) {
  try {
    if (!(await checkAdmin())) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { searchParams } = new URL(request.url)
    const id = searchParams.get('id')

    if (!id) {
      return NextResponse.json({ error: 'Missing banner ID' }, { status: 400 })
    }

    // Verify banner exists
    const existing = await prisma.promoBanner.findUnique({
      where: { id }
    })

    if (!existing) {
      return NextResponse.json({ error: 'Banner not found' }, { status: 404 })
    }

    await prisma.promoBanner.delete({
      where: { id }
    })

    // Purge caches immediately
    updateTag('banners')
    revalidateStorefront()

    return NextResponse.json({ success: true, message: 'Banner deleted successfully' })
  } catch (error: any) {
    console.error('Error deleting banner:', error)
    return NextResponse.json({ error: error.message || 'Failed to delete banner' }, { status: 500 })
  }
}
