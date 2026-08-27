import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import bcrypt from 'bcryptjs'
import { authLimiter } from '@/lib/rate-limit'
import { signupSchema, validateBody } from '@/lib/validation'

export async function POST(request: NextRequest) {
  const limited = await authLimiter.check(request)
  if (limited) return limited

  const validation = await validateBody(request, signupSchema)
  if (!validation.success) return validation.error

  const { name, email, password, phone } = validation.data

  try {
    const existingUser = await prisma.user.findUnique({
      where: { email },
    })

    if (existingUser) {
      return NextResponse.json({ error: 'Email already registered' }, { status: 400 })
    }

    const passwordHash = await bcrypt.hash(password, 12)

    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash,
        phone: phone || null,
        role: 'USER',
      },
    })

    return NextResponse.json({
      message: 'User registered successfully',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
      },
    })
  } catch (error: any) {
    console.error('Signup Error:', error)
    return NextResponse.json({ error: 'Internal server error' }, { status: 500 })
  }
}
