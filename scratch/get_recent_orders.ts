import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import { getDistanceKm, getDeliveryRules, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '../src/lib/distance'

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

const pool = new Pool({ connectionString })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  try {
    const storeLatSetting = await prisma.storeSetting.findUnique({ where: { key: 'store_lat' } })
    const storeLngSetting = await prisma.storeSetting.findUnique({ where: { key: 'store_lng' } })
    const storeLat = storeLatSetting?.value ? parseFloat(storeLatSetting.value) : DEFAULT_STORE_LAT
    const storeLng = storeLngSetting?.value ? parseFloat(storeLngSetting.value) : DEFAULT_STORE_LNG

    console.log(`Store coordinates: ${storeLat}, ${storeLng}`)

    // Query last 15 orders
    const orders = await prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 15,
      include: {
        address: true,
        user: true,
      }
    })

    console.log('\n--- Recent Orders ---')
    orders.forEach(order => {
      let distanceText = 'No coords'
      let lat = order.address?.lat
      let lng = order.address?.lng

      if (lat !== null && lng !== null && lat !== undefined && lng !== undefined) {
        const dist = getDistanceKm(storeLat, storeLng, lat, lng)
        distanceText = `${dist.toFixed(2)} km`
      }

      console.log(`Order ID: ${order.id}`)
      console.log(`Date: ${order.createdAt.toISOString()}`)
      console.log(`Customer: ${order.user?.name || 'Unknown'} (${order.user?.phone || 'No phone'})`)
      console.log(`Address: ${order.address?.houseNo}, ${order.address?.street}, ${order.address?.area}, ${order.address?.city} (${order.address?.pincode})`)
      console.log(`Distance: ${distanceText} (lat: ${lat}, lng: ${lng})`)
      console.log(`Status: ${order.status}`)
      console.log(`Total: ${order.total}`)
      console.log('---------------------')
    })
  } catch (err) {
    console.error('Error fetching orders:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
