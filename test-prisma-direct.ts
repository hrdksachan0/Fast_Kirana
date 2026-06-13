import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

let connectionString = process.env.DATABASE_URL || ''
console.log('DATABASE_URL is:', connectionString)

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
console.log('Final connectionString:', connectionString)

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
    console.log('Testing pool.connect directly first...')
    const client = await pool.connect()
    console.log('Direct pool.connect succeeded!')
    client.release()

    console.log('Now testing prisma.product.count()...')
    const count = await prisma.product.count()
    console.log('Prisma count succeeded! Count:', count)
  } catch (err) {
    console.error('Error occurred:', err)
  } finally {
    await prisma.$disconnect()
  }
}

main()
