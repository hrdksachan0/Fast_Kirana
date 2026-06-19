import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function runTest() {
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) {
    console.error('User not found')
    process.exit(1)
  }

  // Find the STORE_PICKUP address for this user
  const storePickupAddr = await prisma.address.findFirst({
    where: { userId: user.id, label: 'STORE_PICKUP' }
  })

  if (!storePickupAddr) {
    console.log('No STORE_PICKUP address found in DB')
    process.exit(0)
  }

  const product = await prisma.product.findFirst({
    where: { isAvailable: true },
    include: { category: true }
  })
  if (!product) {
    console.error('No products found')
    process.exit(1)
  }

  const items = [
    {
      product: {
        id: product.id,
        slug: product.slug,
        name: product.name,
        price: product.price,
        mrp: product.mrp,
        stock: product.stock,
        unit: product.unit,
        isAvailable: product.isAvailable,
        category: { slug: product.category?.slug }
      },
      quantity: 1
    }
  ]

  console.log(`Testing DELIVERY order using STORE_PICKUP address ID: ${storePickupAddr.id}`)
  const res = await fetch('http://localhost:3000/api/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': user.id,
      'x-user-email': user.email,
      'x-user-name': user.name || 'Rahul Sharma',
      'x-user-role': user.role
    },
    body: JSON.stringify({
      addressId: storePickupAddr.id,
      paymentMethod: 'COD',
      items,
      deliveryMethod: 'DELIVERY',
      isB2B: false,
      scheduledSlot: 'INSTANT'
    })
  })

  console.log('Status:', res.status)
  console.log('Body:', await res.text())
}

runTest()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
