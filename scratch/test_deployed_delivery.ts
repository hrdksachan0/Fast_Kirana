import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function runDeployedDeliveryTest() {
  // 1. Get user
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) throw new Error('User not found')

  // 2. Find or create a valid Ghatampur address
  let address = await prisma.address.findFirst({
    where: {
      userId: user.id,
      pincode: '209206',
      city: { contains: 'Ghatampur', mode: 'insensitive' }
    }
  })

  if (!address) {
    address = await prisma.address.create({
      data: {
        userId: user.id,
        label: 'Ghatampur Home',
        houseNo: 'G-10',
        street: 'Ghatampur Market Road',
        area: 'Ghatampur Market',
        city: 'Ghatampur',
        pincode: '209206',
        phone: '+919999999999'
      }
    })
    console.log('Created new Ghatampur address:', address.id)
  } else {
    console.log('Using existing Ghatampur address:', address.id)
  }

  const payload = {
    addressId: address.id,
    paymentMethod: 'COD',
    items: [
      {
        product: {
          id: 'cmqc8nzb4001c04jxrovu4cnp', // Butter Paneer Dosa
          slug: 'butter-paneer-dosa',
          name: 'Butter Paneer Dosa',
          price: 94,
          mrp: 105,
          stock: 99996,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 2
      },
      {
        product: {
          id: 'cmqc8n6gu000e04jxotc6obtg', // Veg Sandwitch
          slug: 'veg-sandwitch',
          name: 'Veg Sandwitch',
          price: 59,
          mrp: 69,
          stock: 99998,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      },
      {
        product: {
          id: 'cmqc8o63l001k04jxgo2j5d9v', // Chilli Potato
          slug: 'chilli-potato',
          name: 'Chilli Potato',
          price: 94,
          mrp: 99,
          stock: 99998,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      },
      {
        product: {
          id: 'cmqc8o3k2001h04jxa7xs28my', // Chili Paneer - Gravy
          slug: 'chili-paneer-gravy',
          name: 'Chili Paneer - Gravy',
          price: 134,
          mrp: 149,
          stock: 99997,
          isAvailable: true,
          category: { slug: 'cafe' }
        },
        quantity: 1
      }
    ],
    deliveryMethod: 'DELIVERY',
    isB2B: false,
    scheduledSlot: 'INSTANT'
  }

  const response = await fetch('https://fast-kirana-gray.vercel.app/api/orders', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-user-id': user.id,
      'x-user-email': user.email,
      'x-user-name': user.name || 'Rahul Sharma',
      'x-user-role': user.role
    },
    body: JSON.stringify(payload)
  })

  console.log('Deployed DELIVERY Response status:', response.status)
  const text = await response.text()
  console.log('Deployed DELIVERY Response body:', text)
}

runDeployedDeliveryTest()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
