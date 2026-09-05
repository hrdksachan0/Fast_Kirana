import NextAuth from 'next-auth'
import { PrismaAdapter } from '@auth/prisma-adapter'
import { prisma } from '@/lib/prisma'
import Credentials from 'next-auth/providers/credentials'
import bcrypt from 'bcryptjs'
import { authConfig } from './auth.config'
import { normalizePhone, getLast10Digits, isValidIndianPhone } from '@/lib/phone'

const { handlers, auth: nextAuthAuth, signIn, signOut } = NextAuth({
  ...authConfig,
  trustHost: true,
  secret: process.env.AUTH_SECRET || process.env.NEXTAUTH_SECRET,
  adapter: PrismaAdapter(prisma),
  debug: process.env.NODE_ENV !== 'production',
  logger: {
    error: (error: any) => {
      if (process.env.NODE_ENV === 'production') return
      console.error('--- NEXTAUTH ERROR ---')
      console.error(JSON.stringify(error, Object.getOwnPropertyNames(error), 2))
    },
    warn: (code) => {
      if (process.env.NODE_ENV === 'production') return
      console.warn('--- NEXTAUTH WARN ---')
      console.warn('Code:', code)
    },
    debug: (code, metadata) => {
      if (process.env.NODE_ENV === 'production') return
    }
  },
  callbacks: {
    ...authConfig.callbacks,
    async session({ session, token }) {
      if (token?.id) {
        try {
          const dbUser = await prisma.user.findUnique({
            where: { id: token.id as string },
            select: { role: true, assignedRestaurantId: true, assignedStoreId: true, phone: true }
          })
          if (dbUser) {
            token.role = dbUser.role
            token.assignedRestaurantId = dbUser.assignedRestaurantId
            token.assignedStoreId = dbUser.assignedStoreId
            if (dbUser.phone) token.phone = dbUser.phone
          }
        } catch (e) {
          console.error('Session DB sync error:', e)
        }
      }

      if (token) {
        session.user.id = token.id as string
        session.user.role = token.role as any
        session.user.phone = token.phone as string
        session.user.assignedRestaurantId = token.assignedRestaurantId as string
        session.user.assignedStoreId = token.assignedStoreId as string
        if (token.email) {
          session.user.email = token.email as string
        }
      }
      return session
    },
    async signIn({ user, account, profile }) {
      if (user?.email) {
        const dbUser = await prisma.user.findUnique({
          where: { email: user.email },
          select: { id: true, isBlocked: true, blockReason: true }
        })

        if (dbUser?.isBlocked) {
          return false
        }

        // Auto-link Google OAuth account if user previously registered via OTP/Email
        if (account && account.provider && dbUser) {
          try {
            const existingAccount = await prisma.account.findFirst({
              where: {
                provider: account.provider,
                providerAccountId: account.providerAccountId
              }
            })

            if (!existingAccount) {
              await prisma.account.create({
                data: {
                  userId: dbUser.id,
                  type: account.type || 'oauth',
                  provider: account.provider,
                  providerAccountId: account.providerAccountId,
                  access_token: account.access_token,
                  refresh_token: account.refresh_token,
                  expires_at: account.expires_at,
                  token_type: account.token_type,
                  scope: account.scope,
                  id_token: account.id_token,
                }
              })
            }
          } catch (linkErr) {
            console.error('Auto account linking notice:', linkErr)
          }
        }
      }
      return true // allow sign-in
    },
  },
  events: {
    async linkAccount({ user, account }) {
    },
    async createUser({ user }) {
    },
    async signIn({ user }) {
    },
  },
  providers: [
    ...authConfig.providers,
    Credentials({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) return null

        const input = (credentials.email as string).trim()
        const password = credentials.password as string

        const isDev = process.env.NODE_ENV !== 'production'
        const bypassEnabled = isDev && process.env.ENABLE_DEV_BYPASS === '1'
        const bypassPassword = process.env.DEV_BYPASS_PASSWORD
        const isBypass = bypassEnabled && !!bypassPassword && password === bypassPassword

        // Check if input is a phone number or email
        const normPhone = normalizePhone(input)
        const isPhone = isValidIndianPhone(input)
        const cleanPhoneDigits = getLast10Digits(input)

        let user = null
        if (isPhone) {
          const rawDigits = cleanPhoneDigits
          const matchingUsers = await prisma.user.findMany({
            where: {
              OR: [
                { phone: normPhone },
                { phone: rawDigits },
                { phone: `+91${rawDigits}` },
                { email: input.toLowerCase() }
              ]
            }
          })
          // Prioritize canonical staff & restaurant accounts:
          // 9170942500 -> superadmin@fastkirana.com (Super Admin HQ)
          // 7054470303 -> admin@fastkirana.com (Store Operations Manager)
          // 8112849854 -> asrestaurant3@gmail.com (A.S. Restaurant Owner REST-101)
          // 9250138656 -> restaurant@fastkirana.com (Wedson Restaurant Owner REST-102)
          // 7991488783 -> baludyanhotelrestaurant@gmail.com (Bal Udyan Restaurant Owner REST-103)
          const canonicalUser = matchingUsers.find(u => 
            (cleanPhoneDigits === '9170942500' && u.email === 'superadmin@fastkirana.com') ||
            (cleanPhoneDigits === '7054470303' && u.email === 'admin@fastkirana.com') ||
            (cleanPhoneDigits === '8112849854' && (u.email === 'asrestaurant3@gmail.com' || u.assignedRestaurantId === 'REST-101')) ||
            (cleanPhoneDigits === '9250138656' && (u.email === 'restaurant@fastkirana.com' || u.assignedRestaurantId === 'REST-102')) ||
            (cleanPhoneDigits === '7991488783' && (u.email === 'baludyanhotelrestaurant@gmail.com' || u.assignedRestaurantId === 'REST-103'))
          )
          user = canonicalUser || matchingUsers.find(u => u.role !== 'USER' || !!u.passwordHash) || matchingUsers[0]
        } else {
          user = await prisma.user.findUnique({
            where: { email: input.toLowerCase() },
          })
        }

        if (user && user.isBlocked) {
          throw new Error(`Your account has been blocked. ${user.blockReason ? `Reason: ${user.blockReason}` : 'Please contact customer support.'}`)
        }

        if (isBypass) {
          if (!user) {
            // Auto-detect role based on email prefix for developer convenience
            let role: 'USER' | 'ADMIN' | 'CHEF' | 'RESTAURANT_OWNER' | 'PICKER' | 'DELIVERY' = 'USER'
            if (input.startsWith('admin') || input.startsWith('superadmin')) role = 'ADMIN'
            else if (input.startsWith('chef')) role = 'CHEF'
            else if (input.startsWith('restaurant') || input.startsWith('owner')) role = 'RESTAURANT_OWNER'
            else if (input.startsWith('picker')) role = 'PICKER'
            else if (input.startsWith('delivery')) role = 'DELIVERY'

            // Extract name from email prefix
            const baseName = input.split('@')[0]
            const name = baseName.charAt(0).toUpperCase() + baseName.slice(1)

            // Auto-create password hash for consistency
            const passwordHash = await bcrypt.hash(bypassPassword!, 12)

            user = await prisma.user.create({
              data: {
                email: isPhone ? `user-${cleanPhoneDigits}@fastkirana.com` : input.toLowerCase(),
                name,
                role,
                passwordHash,
                phone: isPhone ? normPhone : '+919999999999',
              }
            })
          }

          return {
            id: user.id,
            name: user.name,
            email: user.email,
            role: user.role,
            phone: user.phone,
            image: user.image,
            assignedRestaurantId: user.assignedRestaurantId,
            assignedStoreId: user.assignedStoreId,
          }
        }

        if (!user || !user.passwordHash) return null

        const isValid = await bcrypt.compare(password, user.passwordHash)

        if (!isValid) return null

        return {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          phone: user.phone,
          image: user.image,
          assignedRestaurantId: user.assignedRestaurantId,
          assignedStoreId: user.assignedStoreId,
        }
      },
    }),
    Credentials({
      id: 'otp',
      name: 'OTP',
      credentials: {
        email: { label: 'Email', type: 'email' },
        otp: { label: 'OTP', type: 'text' },
        name: { label: 'Name', type: 'text' },
        phone: { label: 'Phone', type: 'text' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.otp) return null

        let email = (credentials.email as string).toLowerCase().trim()
        const otp = credentials.otp as string
        const name = credentials.name as string
        let phone = credentials.phone as string

        const isPhoneInput = isValidIndianPhone(email) || (phone && isValidIndianPhone(phone))
        const rawPhoneInput = isPhoneInput ? (isValidIndianPhone(email) ? email : phone) : ''
        const cleanDigits = rawPhoneInput ? getLast10Digits(rawPhoneInput) : ''
        const normalizedPhone = cleanDigits ? `+91${cleanDigits}` : ''

        if (isPhoneInput) {
          const existingUser = await prisma.user.findFirst({
            where: {
              OR: [
                { phone: normalizedPhone },
                { phone: cleanDigits },
                { phone: `91${cleanDigits}` },
                { email: `wa-${cleanDigits}@fastkirana.com` },
                { email: email }
              ]
            },
            select: { email: true, phone: true }
          })
          if (existingUser) {
            email = existingUser.email
            if (!phone && existingUser.phone) phone = existingUser.phone
          } else {
            email = `wa-${cleanDigits}@fastkirana.com`
          }
          if (!phone) {
            phone = normalizedPhone
          }
        }

        // 1. Verify OTP in database across all candidate identifier formats
        const candidateEmails = [email, email.toLowerCase()]
        if (cleanDigits) {
          candidateEmails.push(
            `wa-${cleanDigits}@fastkirana.com`,
            cleanDigits,
            normalizedPhone,
            `91${cleanDigits}`
          )
        }

        const otpRecord = await prisma.otpToken.findFirst({
          where: {
            email: { in: candidateEmails },
            token: otp,
            expiresAt: { gt: new Date() }
          }
        })

        if (!otpRecord) return null

        // 2. Delete used OTP token
        await prisma.otpToken.delete({
          where: { id: otpRecord.id }
        })

        // 3. Find or create user
        let user = await prisma.user.findFirst({
          where: {
            OR: [
              { email },
              ...(cleanDigits ? [
                { phone: normalizedPhone },
                { phone: cleanDigits },
                { phone: `91${cleanDigits}` },
                { email: `wa-${cleanDigits}@fastkirana.com` }
              ] : [])
            ]
          }
        })

        if (user && user.isBlocked) {
          throw new Error(`Your account has been blocked. ${user.blockReason ? `Reason: ${user.blockReason}` : 'Please contact customer support.'}`)
        }

        if (!user) {
          let userPhone = phone || (cleanDigits ? normalizedPhone : null)
          user = await prisma.user.create({
            data: {
              email,
              name: name || null,
              phone: userPhone,
              role: 'USER'
            }
          })
        } else if (name || phone) {
          user = await prisma.user.update({
            where: { id: user.id },
            data: {
              name: name || user.name,
              phone: phone || user.phone
            }
          })
        }

        return {
          id: user.id,
          name: user.name,
          email: user.email,
          role: user.role,
          phone: user.phone,
          image: user.image,
          assignedStoreId: user.assignedStoreId,
          assignedRestaurantId: user.assignedRestaurantId,
        }
      }
    }),
  ],
})

export async function auth(...args: any[]) {
  // 1. Try NextAuth standard cookie session first
  const session = await (nextAuthAuth as any)(...args)
  if (session) return session

  // 2. Native Mobile Header-based authentication fallback
  try {
    const { headers } = require('next/headers')
    const result = headers()
    const headersList = result instanceof Promise ? await result : result
    const userId = headersList.get('x-user-id')
    const userEmail = headersList.get('x-user-email')
    const userName = headersList.get('x-user-name')
    const userRole = headersList.get('x-user-role')
    const userPhone = headersList.get('x-user-phone')

    if (!userId) return null;

      let resolvedUserId = userId;
      if (userId.startsWith('mock-id-') || !userId.includes('-')) {
        try {
          const email = userEmail || 'admin@fastkirana.com';
          let dbUser = await prisma.user.findUnique({
            where: { email }
          });
          if (dbUser && dbUser.isBlocked) {
            return null;
          }
          if (dbUser) {
            resolvedUserId = dbUser.id;
          } else {
            dbUser = await prisma.user.create({
              data: {
                email,
                name: userName || 'Mock User',
                role: userRole as any,
                phone: userPhone || '+919999900000',
              }
            });
            resolvedUserId = dbUser.id;
          }
        } catch (dbErr) {
          console.error('Failed to resolve mock user in db:', dbErr);
        }
      }

      let assignedStoreId: string | null = headersList.get('x-user-store-id') || null
      let assignedRestaurantId: string | null = null

      if (resolvedUserId) {
        try {
          const dbUser = await prisma.user.findUnique({
            where: { id: resolvedUserId },
            select: { assignedStoreId: true, assignedRestaurantId: true, role: true }
          })
          if (dbUser) {
            if (dbUser.assignedStoreId) assignedStoreId = dbUser.assignedStoreId
            if (dbUser.assignedRestaurantId) assignedRestaurantId = dbUser.assignedRestaurantId
          }
        } catch (e) {}
      }

      return {
        user: {
          id: resolvedUserId,
          role: userRole as any,
          email: userEmail,
          name: userName,
          phone: userPhone,
          assignedStoreId,
          assignedRestaurantId,
        },
        expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      };
  } catch (err) {
    // Suppress errors (not inside request context)
  }
  return null
}

export { handlers, signIn, signOut }
