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
    const beveragesProducts = await prisma.product.findMany({
      where: {
        category: {
          slug: 'beverages'
        }
      },
      include: {
        category: true
      }
    })
    console.log(`Found ${beveragesProducts.length} beverages products in DB:`)
    console.log(JSON.stringify(beveragesProducts.map(p => ({
      id: p.id,
      name: p.name,
      slug: p.slug,
      isAvailable: p.isAvailable,
      isBestSeller: p.isBestSeller,
      isTopPick: p.isTopPick,
      isFlashDeal: p.isFlashDeal,
      discount: p.discount,
      categorySlug: p.category.slug
    })), null, 2))

  } catch (err) {
    console.error('Error occurred:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
