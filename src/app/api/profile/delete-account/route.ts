import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { sendOtpEmail } from '@/lib/mail'

export const dynamic = 'force-dynamic'

export async function DELETE(request: NextRequest) {
  try {
    const session = await auth()
    if (!session?.user) {
      return NextResponse.json({ error: 'Unauthorized. Please sign in.' }, { status: 401 })
    }

    const sessionId = session.user.id
    const sessionEmail = session.user.email?.trim().toLowerCase()

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          ...(sessionId ? [{ id: sessionId }] : []),
          ...(sessionEmail ? [{ email: { equals: sessionEmail, mode: 'insensitive' as const } }] : []),
        ],
      },
    })

    if (!user) {
      return NextResponse.json({ error: 'User account not found' }, { status: 404 })
    }

    const userId = user.id
    const originalEmail = user.email

    // 1. Send confirmation email before clearing identity records
    if (originalEmail && !originalEmail.includes('@anonymized.local')) {
      try {
        const { Resend } = await import('resend')
        const apiKey = process.env.RESEND_API_KEY?.trim()
        if (apiKey) {
          const resend = new Resend(apiKey)
          const fromEmail = process.env.EMAIL_FROM || 'FastMinute <help@fastminute.in>'
          const resendFrom = fromEmail.includes('@gmail.com') || fromEmail.includes('@yahoo.com')
            ? 'onboarding@resend.dev'
            : fromEmail

          await resend.emails.send({
            from: resendFrom,
            to: originalEmail,
            subject: 'Account Deletion Confirmation - FastMinute',
            html: `
              <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 24px; border: 1px solid #eee; border-radius: 12px;">
                <h2 style="color: #e20a22; margin-top: 0;">Account Deleted Successfully</h2>
                <p style="color: #444; font-size: 14px; line-height: 1.6;">
                  Hello ${user.name || 'FastMinute User'},
                </p>
                <p style="color: #555; font-size: 14px; line-height: 1.6;">
                  As per your request under the Digital Personal Data Protection (DPDP) Act, your FastMinute account and associated personal data (saved addresses, contact numbers, push notification subscriptions) have been permanently anonymized and purged from our active systems.
                </p>
                <p style="color: #777; font-size: 12px; margin-top: 24px; line-height: 1.5;">
                  Note: Past order transaction records are retained strictly in an anonymized format for statutory tax and financial auditing requirements under Indian law.
                </p>
                <div style="margin-top: 24px; padding-top: 16px; border-top: 1px solid #eee; font-size: 11px; color: #999;">
                  FastMinute Quick-Commerce · NH34, Ghatampur, Kanpur Nagar, UP - 209206
                </div>
              </div>
            `,
          })
        }
      } catch (emailErr) {
        console.warn('[DeleteAccount] Confirmation email notice:', emailErr)
      }
    }

    // 2. Cascade deletion of personal data & devices in a single transaction
    await prisma.$transaction([
      prisma.session.deleteMany({ where: { userId } }),
      prisma.account.deleteMany({ where: { userId } }),
      prisma.address.deleteMany({ where: { userId } }),
      prisma.fcmToken.deleteMany({ where: { userId } }),
      prisma.pushSubscription.deleteMany({ where: { userId } }),
      prisma.cart.deleteMany({ where: { userId } }),
      prisma.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted User',
          email: `deleted-${userId.slice(0, 8)}@anonymized.local`,
          phone: null,
          image: null,
          passwordHash: null,
          isBlocked: true,
          blockReason: 'User requested account deletion (DPDP / Right to Erasure)',
          blockedAt: new Date(),
          deletedAt: new Date(),
        },
      }),
    ])

    return NextResponse.json({
      success: true,
      message: 'Your account and personal data have been permanently deleted and anonymized.',
    })
  } catch (error: any) {
    console.error('[DeleteAccount] Failed to process account deletion:', error)
    return NextResponse.json(
      { error: 'An unexpected error occurred while deleting your account. Please try again or contact support.' },
      { status: 500 }
    )
  }
}
