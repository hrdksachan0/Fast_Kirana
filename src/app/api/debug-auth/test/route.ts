import { NextResponse } from 'next/server'
import { PrismaAdapter } from '@auth/prisma-adapter'
import { prisma } from '@/lib/prisma'

// This endpoint tests if PrismaAdapter can perform the same operations
// that NextAuth would during a Google OAuth callback
export async function GET() {
  const adapter = PrismaAdapter(prisma)
  const results: Record<string, any> = {
    timestamp: new Date().toISOString(),
    tests: {},
  }

  // Test 1: getUserByEmail
  try {
    const user = await adapter.getUserByEmail!('test-oauth-debug@gmail.com')
    results.tests.getUserByEmail = {
      status: 'OK',
      found: !!user,
    }
  } catch (err: any) {
    results.tests.getUserByEmail = {
      status: 'FAILED',
      error: err.message,
    }
  }

  // Test 2: createUser (then clean up)
  const testEmail = `test-oauth-${Date.now()}@test.com`
  try {
    const user = await adapter.createUser!({
      email: testEmail,
      name: 'Test OAuth User',
      image: null,
      emailVerified: new Date(),
      id: 'test-id',
    })
    results.tests.createUser = {
      status: 'OK',
      userId: user.id,
      email: user.email,
    }

    // Test 3: linkAccount (simulate Google account linking)
    try {
      await adapter.linkAccount!({
        userId: user.id,
        type: 'oidc',
        provider: 'google',
        providerAccountId: `test-${Date.now()}`,
        access_token: 'test-access-token',
        refresh_token: null,
        id_token: 'test-id-token-value',
        expires_at: Math.floor(Date.now() / 1000) + 3600,
        token_type: 'bearer',
        scope: 'openid email profile',
        session_state: null,
      } as any)
      results.tests.linkAccount = { status: 'OK' }
    } catch (err: any) {
      results.tests.linkAccount = {
        status: 'FAILED',
        error: err.message,
        // Include the full error for debugging
        stack: err.stack?.split('\n').slice(0, 5),
      }
    }

    // Clean up: delete the test user and account
    try {
      await prisma.account.deleteMany({ where: { userId: user.id } })
      await prisma.user.delete({ where: { id: user.id } })
      results.tests.cleanup = { status: 'OK' }
    } catch (err: any) {
      results.tests.cleanup = { status: 'FAILED', error: err.message }
    }
  } catch (err: any) {
    results.tests.createUser = {
      status: 'FAILED',
      error: err.message,
      stack: err.stack?.split('\n').slice(0, 5),
    }
  }

  // Test 4: getUserByAccount
  try {
    const user = await adapter.getUserByAccount!({
      provider: 'google',
      providerAccountId: 'nonexistent',
    })
    results.tests.getUserByAccount = {
      status: 'OK',
      found: !!user,
    }
  } catch (err: any) {
    results.tests.getUserByAccount = {
      status: 'FAILED',
      error: err.message,
    }
  }

  return NextResponse.json(results, {
    headers: { 'Cache-Control': 'no-store' },
  })
}
