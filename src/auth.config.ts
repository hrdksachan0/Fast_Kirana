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
      // For Google OAuth users, the adapter creates the user but doesn't set
      // role/phone on the JWT. Mark them so the middleware can handle it.
      if (account?.provider === 'google' && !token.role) {
        token.role = 'USER'
      }
      if (trigger === 'update' && session) {
        if (session.name) token.name = session.name
        if (session.phone) token.phone = session.phone
        if (session.email) token.email = session.email
      }

      // Only query DB if token.role is missing or during explicit session update trigger
      if (token.id && (!token.role || trigger === 'update')) {
        try {
          const { prisma } = require('@/lib/prisma')
          const dbUser = await prisma.user.findUnique({
            where: { id: token.id as string },
            select: { role: true, assignedRestaurantId: true }
          })
          if (dbUser) {
            token.role = dbUser.role
            token.assignedRestaurantId = dbUser.assignedRestaurantId
          }
        } catch (e) {
          // Suppress error outside DB context
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
  jwt: {
    async encode({ token }) {
      if (!token) return ''
      const secretStr = getCleanEnv('AUTH_SECRET') || getCleanEnv('NEXTAUTH_SECRET') || 'fastkirana-secret-key-change-me'
      const secretKey = new TextEncoder().encode(secretStr)
      return await new SignJWT(token as any)
        .setProtectedHeader({ alg: 'HS256' })
        .setIssuedAt()
        .setExpirationTime('30d')
        .sign(secretKey)
    },
    async decode({ token }) {
      if (!token) return null
      try {
        const secretStr = getCleanEnv('AUTH_SECRET') || getCleanEnv('NEXTAUTH_SECRET') || 'fastkirana-secret-key-change-me'
        const secretKey = new TextEncoder().encode(secretStr)
        const { payload } = await jwtVerify(token, secretKey, { algorithms: ['HS256'] })
        return payload as any
      } catch (e) {
        return null
      }
    },
  },
  pages: {
    signIn: '/login',
    error: '/login',
  },
} satisfies NextAuthConfig
