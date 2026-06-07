import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

function createPrismaClient() {
  let connectionString = process.env.DATABASE_URL || ''
  
  if (connectionString) {
    connectionString = connectionString.replace(/\r/g, '').trim()
    if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
      connectionString = connectionString.substring(1, connectionString.length - 1)
    } else if (connectionString.startsWith("'") && connectionString.endsWith("'")) {
      connectionString = connectionString.substring(1, connectionString.length - 1)
    }
    connectionString = connectionString.trim()
    
    if (!connectionString.includes('uselibpqcompat=')) {
      const separator = connectionString.includes('?') ? '&' : '?'
      connectionString = `${connectionString}${separator}uselibpqcompat=true`
    }
  }

  const pool = new Pool({ connectionString })
  const adapter = new PrismaPg(pool)
  return new PrismaClient({ adapter })
}

export const prisma = globalForPrisma.prisma ?? createPrismaClient()

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma


