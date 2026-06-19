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
    const categories = await prisma.category.findMany({
      orderBy: { sortOrder: 'asc' }
    })
    console.log('Categories in DB:')
    console.log(JSON.stringify(categories, null, 2))

    const orderItems = await prisma.orderItem.groupBy({
      by: ['productId'],
      _sum: {
        quantity: true,
      },
      orderBy: {
        _sum: {
          quantity: 'desc',
        },
      },
      take: 12,
    })
    console.log('Top orderItems (productId & quantity sum):')
    console.log(JSON.stringify(orderItems, null, 2))

    // Let's get some products
    const products = await prisma.product.findMany({
      take: 10,
      select: {
        id: true,
        name: true,
        isTopPick: true,
        isBestSeller: true,
        isFlashDeal: true,
      }
    })
    console.log('Sample Products:')
    console.log(JSON.stringify(products, null, 2))

  } catch (err) {
    console.error('Error occurred:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
