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
  console.log('--- DELETING CANCELLED ORDERS IN DB ---')
  try {
    const countBefore = await prisma.order.count({
      where: {
        status: 'CANCELLED'
      }
    })
    console.log(`Found ${countBefore} CANCELLED orders in DB.`)

    if (countBefore === 0) {
      console.log('No cancelled orders to delete.')
      return
    }

    const deleteResult = await prisma.order.deleteMany({
      where: {
        status: 'CANCELLED'
      }
    })

    console.log(`Successfully deleted ${deleteResult.count} CANCELLED orders.`)
  } catch (err) {
    console.error('Error during deletion:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
