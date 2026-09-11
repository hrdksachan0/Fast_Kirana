import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'
import bcrypt from 'bcryptjs'
import { getStoreUserFilter } from '@/lib/store-resolver'

export async function GET(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const { searchParams } = new URL(request.url)
  const page = parseInt(searchParams.get('page') || '1')
  const limit = parseInt(searchParams.get('limit') || '20')
  const search = searchParams.get('search')
  const role = searchParams.get('role')
  const status = searchParams.get('status')
  const storeId = searchParams.get('storeId') || (session?.user as any)?.assignedStoreId || null
  
  const skip = (page - 1) * limit

  try {
    const where: any = {
      NOT: {
        email: { startsWith: 'guest-' }
      }
    }
    const andClauses: any[] = []

    if (role && role !== 'ALL') {
      andClauses.push({ role })
    }

    if (status === 'BLOCKED') {
      andClauses.push({ isBlocked: true })
    } else if (status === 'ACTIVE') {
      andClauses.push({ isBlocked: false })
    }

    if (search) {
      andClauses.push({
        OR: [
          { name: { contains: search, mode: 'insensitive' } },
          { email: { contains: search, mode: 'insensitive' } },
          { phone: { contains: search, mode: 'insensitive' } },
          { blockReason: { contains: search, mode: 'insensitive' } },
        ]
      })
    }

    if (storeId && storeId !== 'all') {
      if (role === 'DELIVERY' || role === 'PICKER') {
        andClauses.push({ assignedStoreId: storeId })
      } else {
        const userStoreFilter = await getStoreUserFilter(storeId)
        if (Object.keys(userStoreFilter).length > 0) {
          andClauses.push(userStoreFilter)
        }
      }
    }

    if (andClauses.length > 0) {
      where.AND = andClauses
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          role: true,
          assignedStoreId: true,
          assignedStore: {
            select: { id: true, name: true }
          },
          isBlocked: true,
          blockReason: true,
          blockedAt: true,
          createdAt: true,
          _count: {
            select: { orders: true },
          },
        },
        skip,
        take: limit,
      }),
      prisma.user.count({ where }),
    ])

    return NextResponse.json({ users, total, page, limit })
  } catch (error: any) {
    console.error('Failed to fetch users:', error)
    return NextResponse.json({ error: 'Failed to fetch users' }, { status: 500 })
  }
}

export async function PATCH(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { userId, role, name, phone, assignedStoreId } = await request.json()

    if (!userId) {
      return NextResponse.json({ error: 'Missing required userId' }, { status: 400 })
    }

    const updateData: any = {}
    if (name) updateData.name = name.trim()
    if (phone) updateData.phone = phone.trim()
    if (assignedStoreId !== undefined) {
      updateData.assignedStoreId = assignedStoreId ? assignedStoreId : null
    }

    if (Object.keys(updateData).length > 0) {
      await prisma.user.update({
        where: { id: userId },
        data: updateData,
      })
    }

    if (role) {
      if (role !== 'USER' && role !== 'DELIVERY' && role !== 'ADMIN' && role !== 'PICKER' && role !== 'CHEF') {
        return NextResponse.json({ error: 'Invalid role' }, { status: 400 })
      }

      // Safeguard: Do not allow downgrading master admin or assigned store managers
      const targetUser = await prisma.user.findUnique({
        where: { id: userId },
        select: { email: true, phone: true, role: true, assignedStoreId: true }
      })
      const isRootAdmin = targetUser?.email === 'admin@fastkirana.com' || targetUser?.email === 'superadmin@fastkirana.com' || targetUser?.phone?.includes('7054470303') || targetUser?.phone?.includes('9170942500')
      if (isRootAdmin && role !== 'ADMIN') {
        return NextResponse.json({ error: 'Root Admin accounts cannot be downgraded' }, { status: 403 })
      }

      // Update using raw SQL to bypass PrismaPg enum casting issue
      await prisma.$executeRaw`
        UPDATE users SET role = ${role}::"Role", "updatedAt" = NOW() WHERE id = ${userId}
      `
    }

    return NextResponse.json({ success: true, message: 'User details updated successfully' })
  } catch (error: any) {
    console.error('Failed to update user details:', error)
    return NextResponse.json({ error: 'Failed to update user details' }, { status: 500 })
  }
}

export async function POST(request: Request) {
  const adminResult = await requireAdmin()
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  try {
    const { userId, password } = await request.json()

    if (!userId || !password) {
      return NextResponse.json({ error: 'Missing required fields' }, { status: 400 })
    }

    if (password.length < 6) {
      return NextResponse.json({ error: 'Password must be at least 6 characters' }, { status: 400 })
    }

    const passwordHash = await bcrypt.hash(password, 12)

    const targetUser = await prisma.user.findUnique({
      where: { id: userId },
      select: { phone: true, email: true }
    })

    if (targetUser?.phone) {
      const digits = getLast10Digits(targetUser.phone)
      await prisma.user.updateMany({
        where: {
          OR: [
            { id: userId },
            { phone: targetUser.phone },
            { phone: digits },
            { phone: `+91${digits}` },
            { email: `wa-${digits}@fastkirana.com` }
          ]
        },
        data: { passwordHash },
      })
    } else {
      await prisma.user.update({
        where: { id: userId },
        data: { passwordHash },
      })
    }

    return NextResponse.json({ success: true, message: 'Password updated successfully' })
  } catch (error: any) {
    console.error('Failed to set worker password:', error)
    return NextResponse.json({ error: 'Failed to set password' }, { status: 500 })
  }
}
