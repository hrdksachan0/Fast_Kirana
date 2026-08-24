import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import dns from 'dns'

if (typeof dns.setDefaultResultOrder === 'function') {
  dns.setDefaultResultOrder('ipv4first')
}

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

function createPrismaClient() {
  let connectionString = process.env.DATABASE_URL || process.env.DIRECT_URL || ''
  
  if (connectionString) {
    connectionString = connectionString.replace(/\r/g, '').trim()
    if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
      connectionString = connectionString.substring(1, connectionString.length - 1)
    } else if (connectionString.startsWith("'") && connectionString.endsWith("'")) {
      connectionString = connectionString.substring(1, connectionString.length - 1)
    }
    connectionString = connectionString.trim()
  }

  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false },
    max: 15,                     // Supabase Pro supports 100+ connections — 15 is safe for serverless
    idleTimeoutMillis: 30000,    // Release idle connections after 30s
    connectionTimeoutMillis: 30000, // 30s timeout for reliable connection establishment
  })

  // Silently handle pool errors to prevent unhandled rejections crashing the process
  pool.on('error', (err) => {
    console.warn('[PrismaPool] Background pool connection error (non-fatal):', err.message)
  })
  
  const adapter = new PrismaPg(pool)
  return new PrismaClient({ adapter })
}

export const prisma = globalForPrisma.prisma ?? createPrismaClient()

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
