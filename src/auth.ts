import NextAuth from 'next-auth'
import { PrismaAdapter } from '@auth/prisma-adapter'
import { prisma } from '@/lib/prisma'
import Credentials from 'next-auth/providers/credentials'
import bcrypt from 'bcryptjs'
import { authConfig } from './auth.config'

export const { handlers, auth, signIn, signOut } = NextAuth({
  ...authConfig,
  adapter: PrismaAdapter(prisma),
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

        const email = (credentials.email as string).toLowerCase().trim()
        const password = credentials.password as string

        const user = await prisma.user.findUnique({
          where: { email },
        })

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

        const email = (credentials.email as string).toLowerCase().trim()
        const otp = credentials.otp as string
        const name = credentials.name as string
        const phone = credentials.phone as string

        // 1. Verify OTP in database
        const otpRecord = await prisma.otpToken.findFirst({
          where: {
            email,
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
        let user = await prisma.user.findUnique({
          where: { email }
        })

        if (!user) {
          user = await prisma.user.create({
            data: {
              email,
              name: name || null,
              phone: phone || null,
              role: 'USER'
            }
          })
        } else if (name || phone) {
          user = await prisma.user.update({
            where: { email },
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
          image: user.image
        }
      }
    }),
  ],
})
