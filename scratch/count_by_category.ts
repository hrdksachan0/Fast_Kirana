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
    const totalProducts = await prisma.product.count()
    console.log('Total Products in DB:', totalProducts)

    const categories = await prisma.category.findMany({
      include: {
        _count: {
          select: { products: true }
        }
      }
    })
    console.log('Product Count by Category:')
    console.log(categories.map(c => ({ name: c.name, slug: c.slug, count: c._count.products })))

  } catch (err) {
    console.error('Error occurred:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
