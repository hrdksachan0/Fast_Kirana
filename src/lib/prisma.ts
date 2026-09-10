import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import dns from 'dns'

if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first')
}

// Module-level singleton — persists across requests within the same Vercel function instance.
// globalThis fallback handles dev HMR restarts where the module is re-evaluated.
const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

let _prisma: PrismaClient | undefined

function getPrisma(): PrismaClient {
  if (_prisma) return _prisma
  if (globalForPrisma.prisma) return globalForPrisma.prisma

  let connectionString = process.env.DATABASE_URL || process.env.DIRECT_URL || ''

  if (connectionString) {
    connectionString = connectionString.replace(/\r/g, '').trim()
    if ((connectionString.startsWith('"') && connectionString.endsWith('"')) ||
        (connectionString.startsWith("'") && connectionString.endsWith("'"))) {
      connectionString = connectionString.slice(1, -1)
    }
    connectionString = connectionString.trim()
  }

  const isServerless = Boolean(process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME)

  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false },
    max: isServerless ? 3 : 10,
    idleTimeoutMillis: isServerless ? 10000 : 30000,
    connectionTimeoutMillis: 15000,
  })

  pool.on('error', (err) => {
    console.warn('[PrismaPool] Background pool connection error (non-fatal):', err.message)
  })

  const adapter = new PrismaPg(pool)
  _prisma = new PrismaClient({ adapter })
  globalForPrisma.prisma = _prisma
  return _prisma
}

// Lazily initialize — avoids creating connections on module import during SSR of non-DB pages
export const prisma: PrismaClient = (() => {
  try {
    return getPrisma()
  } catch {
    // If initialization fails (e.g. missing env), return a stub to prevent import-time crash
    // The first actual DB call will throw the real error
    return new PrismaClient()
  }
})()
