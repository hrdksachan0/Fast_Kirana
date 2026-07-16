import dotenv from 'dotenv'
dotenv.config()

import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import { getDistanceKm, DEFAULT_STORE_LAT, DEFAULT_STORE_LNG } from '../src/lib/distance'

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

    // Query cancelled or all recent orders to see if any are > 4 km
    const orders = await prisma.order.findMany({
      orderBy: { createdAt: 'desc' },
      take: 40,
      include: {
        address: true,
        user: true,
      }
    })

    console.log('\n--- Checking Last 40 Orders ---')
    let foundFar = false
    orders.forEach(order => {
      let distanceText = 'No coords'
      let lat = order.address?.lat
      let lng = order.address?.lng
      let dist = 0

      if (lat !== null && lng !== null && lat !== undefined && lng !== undefined) {
        dist = getDistanceKm(storeLat, storeLng, lat, lng)
        distanceText = `${dist.toFixed(2)} km`
      }

      // We want to print any order that is > 3 km or has no coords, or is cancelled
      if (dist > 3 || lat === null || order.status === 'CANCELLED') {
        foundFar = true
        console.log(`Order ID: ${order.id}`)
        console.log(`Date: ${order.createdAt.toISOString()}`)
        console.log(`Customer: ${order.user?.name || 'Unknown'} (${order.user?.phone || 'No phone'})`)
        console.log(`Address: ${order.address?.houseNo}, ${order.address?.street}, ${order.address?.area}, ${order.address?.city} (${order.address?.pincode})`)
        console.log(`Distance: ${distanceText} (lat: ${lat}, lng: ${lng})`)
        console.log(`Status: ${order.status}`)
        console.log(`Total: ${order.total}`)
        console.log('---------------------')
      }
    })

    if (!foundFar) {
      console.log('No cancelled or far orders found in the last 40 orders.')
    }
  } catch (err) {
    console.error('Error fetching orders:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

main()
