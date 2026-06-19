import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function testToggle() {
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) {
    console.error('Test user not found')
    process.exit(1)
  }

  // Get user's addresses
  const addresses = await prisma.address.findMany({
    where: { userId: user.id }
  })
  console.log('User addresses:', addresses.map(a => ({ id: a.id, label: a.label, pincode: a.pincode, city: a.city })))

  const product = await prisma.product.findFirst({
    where: { isAvailable: true },
    include: { category: true }
  })
  if (!product) {
    console.error('No products found')
    process.exit(1)
  }
  console.log('Using product:', { id: product.id, name: product.name, price: product.price, isCafe: product.category?.slug === 'cafe' })

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

  // Test 1: Place order with PICKUP
  console.log('Testing PICKUP order...')
  const resPickup = await fetch('http://localhost:3000/api/orders', {
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

  console.log('PICKUP status:', resPickup.status)
  console.log('PICKUP body:', await resPickup.text())

  // Test 2: Place order with DELIVERY
  if (addresses.length > 0) {
    console.log('Testing DELIVERY order...')
    const resDelivery = await fetch('http://localhost:3000/api/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-user-id': user.id,
        'x-user-email': user.email,
        'x-user-name': user.name || 'Rahul Sharma',
        'x-user-role': user.role
      },
      body: JSON.stringify({
        addressId: addresses[0].id,
        paymentMethod: 'COD',
        items,
        deliveryMethod: 'DELIVERY',
        isB2B: false,
        scheduledSlot: 'INSTANT'
      })
    })

    console.log('DELIVERY status:', resDelivery.status)
    console.log('DELIVERY body:', await resDelivery.text())
  }
}

testToggle()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (err) => {
    console.error(err)
    await prisma.$disconnect()
  })
