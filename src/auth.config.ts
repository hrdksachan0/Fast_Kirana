import type { NextAuthConfig } from 'next-auth'
import Google from 'next-auth/providers/google'

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
    }),
  ],
  callbacks: {
    async jwt({ token, user, trigger, session }) {
      if (user) {
        token.role = (user as any).role
        token.id = user.id
        token.phone = (user as any).phone
      }
      if (trigger === 'update' && session) {
        if (session.name) token.name = session.name
        if (session.phone) token.phone = session.phone
      }
      return token
    },
    async session({ session, token }) {
      if (token) {
        session.user.id = token.id as string
        session.user.role = token.role as any
        session.user.phone = token.phone as string
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
