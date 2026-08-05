import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { auth } from '@/auth'
import { requireAdmin } from '@/lib/auth-guard'
import { revalidateTag } from 'next/cache'
import { revalidateStorefront } from '@/lib/revalidate'

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { id } = await params
    const body = await request.json()
    const { name, imageUrl, sortOrder } = body

    const category = await prisma.category.findUnique({
      where: { id },
    })

    if (!category) {
      return NextResponse.json({ error: 'Category not found' }, { status: 404 })
    }

    const updateData: any = {}
    if (imageUrl !== undefined) updateData.imageUrl = imageUrl
    if (sortOrder !== undefined) updateData.sortOrder = parseInt(sortOrder) || 0
    if (body.parentId !== undefined) updateData.parentId = body.parentId || null

    if (name !== undefined && name !== category.name) {
      updateData.name = name
      // Generate slug from name
      const slug = name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)+/g, '')

      const existing = await prisma.category.findFirst({
        where: {
          slug,
          id: { not: id },
        },
      })

      let finalSlug = slug
      if (existing) {
        finalSlug = `${slug}-${Date.now().toString().slice(-4)}`
      }
      updateData.slug = finalSlug
    }

    const updatedCategory = await prisma.category.update({
      where: { id },
      data: updateData,
    })

    // Revalidate category lists cache immediately
    try {
      revalidateTag('categories', 'max')
      revalidateStorefront()
    } catch (e) {
      console.error('Failed to trigger category revalidation on patch:', e)
    }

    return NextResponse.json(updatedCategory)
  } catch (error: any) {
    console.error('Failed to update category:', error)
    return NextResponse.json({ error: 'Failed to update category' }, { status: 500 })
  }
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { id } = await params

    const category = await prisma.category.findUnique({
      where: { id },
    })

    if (!category) {
      return NextResponse.json({ error: 'Category not found' }, { status: 404 })
    }

    // Check if category has associated products
    const productCount = await prisma.product.count({
      where: { categoryId: id },
    })

    if (productCount > 0) {
      return NextResponse.json(
        { error: 'Category contains active products. Please reassign or delete the products first.' },
        { status: 400 }
      )
    }

    await prisma.category.delete({
      where: { id },
    })

    // Revalidate category lists cache immediately
    try {
      revalidateTag('categories', 'max')
      revalidateStorefront()
    } catch (e) {
      console.error('Failed to trigger category revalidation on delete:', e)
    }

    return NextResponse.json({ success: true, message: 'Category deleted successfully' })
  } catch (error: any) {
    console.error('Failed to delete category:', error)
    return NextResponse.json({ error: 'Failed to delete category' }, { status: 500 })
  }
}
