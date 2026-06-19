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
    const user = await prisma.user.findFirst()
    if (!user) {
      console.log('No user found in DB!')
      return
    }

    console.log(`Using user: ${user.name} (${user.id})`)

    const address = await prisma.address.create({
      data: {
        userId: user.id,
        label: 'Homee',
        houseNo: 'Behind chauhan complex',
        street: 'Bhitar gaon road',
        area: 'Kushmanda devi',
        city: 'Ghatampur',
        pincode: '209206',
        phone: '6392884183',
        isDefault: false,
        lat: null,
        lng: null,
      }
    })

    console.log('ADDRESS CREATED SUCCESSFULLY:', JSON.stringify(address, null, 2))

    // Let's delete it so we don't pollute the db
    await prisma.address.delete({
      where: { id: address.id }
    })
    console.log('Deleted temporary test address.')

  } catch (err) {
    console.error('Error occurred during address creation:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
