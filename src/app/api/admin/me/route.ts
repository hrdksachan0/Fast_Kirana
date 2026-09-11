import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireAdmin } from '@/lib/auth-guard'

export async function GET(request: Request) {
  const adminResult = await requireAdmin(request)
  if (adminResult.error) return adminResult.error
  const session = adminResult.session

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      role: true,
      assignedStoreId: true,
      assignedStore: {
        select: { id: true, name: true }
      }
    }
  })

  return NextResponse.json({
    user,
    assignedStoreId: user?.assignedStoreId || null,
    storeName: user?.assignedStore?.name || null
  })
}
