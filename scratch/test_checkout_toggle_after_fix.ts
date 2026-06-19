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

  // 1. Fetch addresses via API GET to confirm STORE_PICKUP is NOT returned
  console.log('Fetching addresses from API /api/addresses...')
  const addressesRes = await fetch('http://localhost:3000/api/addresses', {
    headers: {
      'x-user-id': user.id,
      'x-user-email': user.email,
      'x-user-name': user.name || 'Rahul Sharma',
      'x-user-role': user.role
    }
  })
  const addresses = await addressesRes.json()
  console.log('Addresses returned by API:', addresses.map((a: any) => ({ id: a.id, label: a.label })))

  const hasStorePickup = addresses.some((a: any) => a.label === 'STORE_PICKUP')
  if (hasStorePickup) {
    console.error('FAIL: STORE_PICKUP address was returned by the addresses API!')
    process.exit(1)
  } else {
    console.log('SUCCESS: STORE_PICKUP address was successfully hidden from addresses API list.')
  }

  // Find a product to order
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

  // 2. Test PICKUP order creation
  console.log('Placing a pickup order...')
  const pickupRes = await fetch('http://localhost:3000/api/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': user.id,
      'x-user-email': user.email,
      'x-user-name': user.name || 'Rahul Sharma',
      'x-user-role': user.role
    },
    body: JSON.stringify({
      addressId: 'STORE_PICKUP',
      paymentMethod: 'COD',
      items,
      deliveryMethod: 'PICKUP',
      isB2B: false,
      scheduledSlot: 'INSTANT'
    })
  })
  console.log('PICKUP status:', pickupRes.status)

  // 3. Test DELIVERY order creation using user's real address (e.g. MG Road)
  // Find a real non-pickup address for the user
  const realAddr = await prisma.address.findFirst({
    where: { userId: user.id, label: { not: 'STORE_PICKUP' } }
  })

  if (realAddr) {
    console.log(`Placing a delivery order to address ID: ${realAddr.id} (${realAddr.label})...`)
    const deliveryRes = await fetch('http://localhost:3000/api/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-user-id': user.id,
        'x-user-email': user.email,
        'x-user-name': user.name || 'Rahul Sharma',
        'x-user-role': user.role
      },
      body: JSON.stringify({
        addressId: realAddr.id,
        paymentMethod: 'COD',
        items,
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        scheduledSlot: 'INSTANT'
      })
    })
    console.log('DELIVERY status:', deliveryRes.status)
  } else {
    console.log('No real addresses found to test delivery order')
  }
}

runTest()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
