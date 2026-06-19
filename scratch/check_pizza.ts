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
    const products = await prisma.product.findMany({
      where: {
        name: {
          contains: 'Pizza',
          mode: 'insensitive'
        }
      },
      include: {
        category: true
      }
    })
    console.log('All Pizza Products:')
    console.log(JSON.stringify(products, null, 2))
  } catch (err) {
    console.error('Error:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
