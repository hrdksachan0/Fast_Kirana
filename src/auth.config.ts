import type { NextAuthConfig } from 'next-auth'
import Google from 'next-auth/providers/google'
import { SignJWT, jwtVerify } from 'jose'

// Clean environment variables (removes quotes if copy-pasted with quotes)
const getCleanEnv = (key: string): string => {
  let val = process.env[key] || ''
  val = val.trim()
  if (val.startsWith('"') && val.endsWith('"')) {
    val = val.substring(1, val.length - 1)
  }
  if (val.startsWith("'") && val.endsWith("'")) {
    val = val.substring(1, val.length - 1)
  }
  return val.trim()
}

const googleClientId = getCleanEnv('GOOGLE_CLIENT_ID')
const googleClientSecret = getCleanEnv('GOOGLE_CLIENT_SECRET')

export const authConfig = {
  trustHost: true,
  providers: [
    Google({
      clientId: googleClientId || 'placeholder',
      clientSecret: googleClientSecret || 'placeholder',
      allowDangerousEmailAccountLinking: true,
      authorization: {
        params: {
          prompt: 'select_account',
        },
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user, trigger, session, account }) {
      if (user) {
        token.role = (user as any).role
        token.id = user.id
        token.phone = (user as any).phone
        token.assignedRestaurantId = (user as any).assignedRestaurantId
        token.assignedStoreId = (user as any).assignedStoreId
        
        // If it's a virtual email from WhatsApp login, clean it and set it as the email token field
        if (user.email && user.email.startsWith('wa-') && user.email.includes('@fastkirana.com')) {
          const phoneDigits = user.email.split('@')[0].replace('wa-', '')
          const cleanPhone = phoneDigits.length === 12 && phoneDigits.startsWith('91')
            ? phoneDigits.slice(2)
            : phoneDigits
          token.email = `+91 ${cleanPhone}`
        } else {
          token.email = user.email
        }
      }
      if (trigger === 'update' && session) {
        if (session.name) token.name = session.name
        if (session.phone) token.phone = session.phone
        if (session.email) token.email = session.email
      }

      // Ensure token always has real-time DB role, phone, and assignedStoreId
      if (token.id || user?.id || user?.email) {
        try {
          const { prisma } = require('@/lib/prisma')
          const userId = (token.id || user?.id) as string
          const userEmail = (token.email || user?.email) as string
          const dbUser = await prisma.user.findFirst({
            where: {
              OR: [
                userId ? { id: userId } : null,
                userEmail ? { email: userEmail.toLowerCase() } : null
              ].filter(Boolean)
            },
            select: { id: true, role: true, assignedRestaurantId: true, assignedStoreId: true, phone: true }
          })
          if (dbUser) {
            token.id = dbUser.id
            token.role = dbUser.role
            token.assignedRestaurantId = dbUser.assignedRestaurantId
            token.assignedStoreId = dbUser.assignedStoreId
            if (dbUser.phone && !token.phone) token.phone = dbUser.phone
          } else if (!token.role) {
            token.role = 'USER'
          }
        } catch (e) {
          if (!token.role) token.role = 'USER'
        }
      }

      return token
    },
    async session({ session, token }) {
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
  },
  session: {
    strategy: 'jwt',
  },
  pages: {
    signIn: '/login',
    error: '/login',
  },
} satisfies NextAuthConfig
