import { prisma } from '@/lib/prisma'

export async function runGuestCleanup(days: number = 2) {
  const cutoff = new Date(Date.now() - days * 24 * 60 * 60 * 1000)

  try {
    const guestUsers = await prisma.user.findMany({
      where: {
        createdAt: { lt: cutoff },
        role: 'USER',
        OR: [
          { phone: null },
          { phone: '' }
        ],
        AND: [
          {
            OR: [
              { email: { startsWith: 'anon-fcm-' } },
              { email: { startsWith: 'guest-' } },
              { name: { startsWith: 'Guest' } }
            ]
          },
          {
            orders: { none: {} }
          }
        ]
      },
      select: { id: true },
      take: 2000
    })

    const targetIds = guestUsers.map((u) => u.id)
    if (targetIds.length === 0) {
      return { deletedUsers: 0, deletedCarts: 0, deletedTokens: 0, deletedAddresses: 0 }
    }

    const [deletedTokens, deletedCarts, deletedAddresses, deletedUsers] = await prisma.$transaction([
      prisma.fcmToken.deleteMany({ where: { userId: { in: targetIds } } }),
      prisma.cart.deleteMany({ where: { userId: { in: targetIds } } }),
      prisma.address.deleteMany({ where: { userId: { in: targetIds } } }),
      prisma.user.deleteMany({ where: { id: { in: targetIds } } })
    ])

    return {
      deletedUsers: deletedUsers.count,
      deletedCarts: deletedCarts.count,
      deletedTokens: deletedTokens.count,
      deletedAddresses: deletedAddresses.count
    }
  } catch (error) {
    console.error('[GuestCleanupService] Error during guest cleanup:', error)
    return { error: String(error), deletedUsers: 0 }
  }
}
