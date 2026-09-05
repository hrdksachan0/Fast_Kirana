import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { revalidateStorefront } from '@/lib/revalidate'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const restaurant = await prisma.restaurant.findFirst({
      where: {
        OR: [{ id }, { slug: id }]
      },
      select: {
        id: true,
        name: true,
        slug: true,
        menuSections: true,
      }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    let sections: any[] = []
    if (restaurant.menuSections) {
      try {
        sections = typeof restaurant.menuSections === 'string'
          ? JSON.parse(restaurant.menuSections)
          : restaurant.menuSections
      } catch (e) {
        sections = []
      }
    }

    const normalized = (Array.isArray(sections) ? sections : []).map((s: any, idx: number) => ({
      id: s.id || `sec_${s.slug || s.tag || idx}`,
      name: s.name || s.title || 'Section',
      title: s.title || s.name || 'Section',
      emoji: s.emoji || '🍽️',
      description: s.description || '',
      imageUrl: s.imageUrl || s.image || null,
      sortOrder: s.sortOrder !== undefined ? s.sortOrder : idx + 1,
      disabled: Boolean(s.disabled),
    }))

    return NextResponse.json({ sections: normalized, restaurant })
  } catch (error: any) {
    console.error('Restaurant sections GET error:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params
    const body = await request.json()
    const { name, title, emoji, description, imageUrl, sortOrder } = body

    const sectionTitle = (title || name || '').trim()
    if (!sectionTitle) {
      return NextResponse.json({ error: 'Section title is required' }, { status: 400 })
    }

    const restaurant = await prisma.restaurant.findFirst({
      where: { OR: [{ id }, { slug: id }] }
    })

    if (!restaurant) {
      return NextResponse.json({ error: 'Restaurant not found' }, { status: 404 })
    }

    let currentSections: any[] = []
    if (restaurant.menuSections) {
      try {
        currentSections = typeof restaurant.menuSections === 'string'
          ? JSON.parse(restaurant.menuSections)
          : restaurant.menuSections
      } catch (e) {
        currentSections = []
      }
    }
    if (!Array.isArray(currentSections)) currentSections = []

    const cleanSlug = sectionTitle.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
    const uniqueId = `sec_${cleanSlug}_${Date.now().toString(36)}`

    const newSection = {
      id: uniqueId,
      name: sectionTitle,
      title: sectionTitle,
      slug: cleanSlug,
      tag: cleanSlug,
      emoji: emoji?.trim() || '🍽️',
      description: (description || '').trim(),
      imageUrl: imageUrl || null,
      sortOrder: sortOrder !== undefined ? Number(sortOrder) : currentSections.length + 1,
      disabled: false,
      matchTags: [cleanSlug]
    }

    const updatedSections = [...currentSections, newSection]

    await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: { menuSections: updatedSections }
    })

    await revalidateStorefront()

    return NextResponse.json({
      success: true,
      section: newSection,
      sections: updatedSections,
      message: `Category "${sectionTitle}" created with ID: ${uniqueId}`
    })
  } catch (error: any) {
    console.error('Restaurant sections POST error:', error)
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 })
  }
}