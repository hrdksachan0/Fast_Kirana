import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'

export async function DELETE(request: NextRequest) {
  try {
    const session = await auth()
    if (!session || !session.user || !session.user.id) {
      return NextResponse.json({ error: 'Unauthorized. Please sign in.' }, { status: 401 })
    }

    const userId = session.user.id

    // Perform data anonymization & deletion in a transaction
    await prisma.$transaction(async (tx) => {
      // 1. Delete push subscriptions
      await tx.pushSubscription.deleteMany({ where: { userId } })

      // 2. Delete user addresses
      await tx.address.deleteMany({ where: { userId } })

      // 3. Delete accounts and sessions
      await tx.account.deleteMany({ where: { userId } })
      await tx.session.deleteMany({ where: { userId } })

      // 4. Anonymize user record to preserve past transaction integrity while purging PII
      await tx.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted User',
          email: `deleted-${userId.substring(0, 8)}@anonymized.local`,
          phone: null,
          image: null,
          passwordHash: null,
          isBlocked: true,
          blockReason: 'User requested account deletion',
          blockedAt: new Date(),
        },
      })
    })

    return NextResponse.json({
      success: true,
      message: 'Account personal data anonymized and deleted successfully.',
    })
  } catch (error: any) {
    console.error('Failed to delete user account:', error)
    return NextResponse.json({ error: 'Failed to delete user account' }, { status: 500 })
  }
}
