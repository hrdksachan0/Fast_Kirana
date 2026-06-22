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
    const orders = await prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 10,
      include: {
        user: true,
        address: true
      }
    })

    console.log('--- LATEST 10 ORDERS ---')
    for (const o of orders) {
      console.log(`Order ID: ${o.id}`)
      console.log(`  Shop Name: ${o.shopName}`)
      console.log(`  Status: ${o.status}`)
      console.log(`  Total: ₹${o.total}`)
      console.log(`  Created At: ${o.createdAt}`)
      console.log(`  User: ${o.user?.name} (Phone: ${o.user?.phone})`)
      console.log(`  Address Phone: ${o.address?.phone}`)
      console.log(`  Delivery Method: ${o.deliveryMethod}`)
      console.log('------------------------')
    }
  } catch (err) {
    console.error('Error querying orders:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
