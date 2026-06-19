import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

let connectionString = process.env.DATABASE_URL || ''
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim()
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1)
  }
  connectionString = connectionString.trim()
  if (!connectionString.includes('uselibpqcompat=')) {
    const separator = connectionString.includes('?') ? '&' : '?'
    connectionString = `${connectionString}${separator}uselibpqcompat=true`
  }
}

const pool = new Pool({
  connectionString,
  max: 3,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000
})

const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  try {
    const users = await prisma.user.findMany({
      take: 5,
      select: {
        id: true,
        email: true,
        name: true,
      }
    })
    console.log('USERS IN DB:', JSON.stringify(users, null, 2))

    const addresses = await prisma.address.findMany({
      take: 5
    })
    console.log('ADDRESSES IN DB:', JSON.stringify(addresses, null, 2))

  } catch (err) {
    console.error('Error occurred:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
