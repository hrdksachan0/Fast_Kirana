import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function testOrder() {
  // Let's find a user, an address, and some products to place an order
  const user = await prisma.user.findFirst({
    where: { role: 'USER' }
  })
  
  if (!user) {
    console.error('No customer found')
    return
  }

  const address = await prisma.address.findFirst({
    where: { userId: user.id }
  })

  if (!address) {
    console.error('No address found for user', user.id)
    return
  }

  const productNames = [
    'Butter Paneer Dosa',
    'Veg Sandwitch',
    'Chilli Potato',
    'Chili Paneer - Gravy'
  ]
  
  const dbProducts = await prisma.product.findMany({
    where: {
      name: { in: productNames }
    }
  })

  if (dbProducts.length === 0) {
    console.error('No matching products found in database')
    return
  }

  console.log(`Testing with user: ${user.email}, address: ${address.id}, products: ${dbProducts.map(p => p.name).join(', ')}`)

  const products = dbProducts // Alias to match below variables

  // Let's simulate the Prisma transaction that is performed during checkout
  try {
    const createdOrders = await prisma.$transaction(async (tx) => {
      const results: any[] = []
      
      const orderItemsData = products.map((p) => {
        const qty = p.name === 'Butter Paneer Dosa' ? 2 : 1
        return {
          productId: p.id,
          name: p.name,
          price: p.price,
          quantity: qty,
          imageUrl: p.imageUrl,
          selectedVariant: null,
        }
      })

      // Try creating a test order
      const newOrder = await tx.order.create({
        data: {
          userId: user.id,
          addressId: address.id,
          status: 'PENDING',
          subtotal: products.reduce((sum, p) => sum + p.price, 0),
          discount: 0,
          deliveryFee: 0,
          taxes: 0,
          total: products.reduce((sum, p) => sum + p.price, 0),
          paymentMethod: 'COD',
          paymentStatus: 'PENDING',
          estimatedDelivery: new Date(),
          deliveryMethod: 'DELIVERY',
          isB2B: false,
          shopName: 'FastKirana Cafe Kitchen',
          items: {
            create: orderItemsData.map((item: any) => ({
              productId: item.productId,
              name: item.name,
              price: item.price,
              quantity: item.quantity,
              imageUrl: item.imageUrl,
              selectedVariant: item.selectedVariant,
            })),
          },
        },
        include: {
          items: true,
          address: true,
        },
      })

      results.push(newOrder)

      // Deduct stock
      for (const item of orderItemsData) {
        const batches = await tx.productBatch.findMany({
          where: {
            productId: item.productId,
            quantity: { gt: 0 }
          },
          orderBy: {
            expiryDate: 'asc'
          }
        })

        let remainingToDeduct = item.quantity

        if (batches.length > 0) {
          for (const batch of batches) {
            if (remainingToDeduct <= 0) break
            const deductFromThisBatch = Math.min(batch.quantity, remainingToDeduct)
            await tx.productBatch.update({
              where: { id: batch.id },
              data: { quantity: { decrement: deductFromThisBatch } }
            })
            remainingToDeduct -= deductFromThisBatch
          }
        }

        const activeBatches = await tx.productBatch.findMany({
          where: {
            productId: item.productId,
            quantity: { gt: 0 }
          },
          orderBy: { expiryDate: 'asc' }
        })

        const newTotalStock = activeBatches.reduce((sum, b) => sum + b.quantity, 0)
        const newEarliestExpiry = activeBatches.length > 0 ? activeBatches[0].expiryDate : null

        if (activeBatches.length > 0 || batches.length > 0) {
          await tx.product.update({
            where: { id: item.productId },
            data: {
              stock: newTotalStock,
              expiryDate: newEarliestExpiry
            }
          })
        } else {
          await tx.product.update({
            where: { id: item.productId },
            data: { stock: { decrement: item.quantity } }
          })
        }
      }

      return results
    })

    console.log('Order creation simulation succeeded! Created order IDs:', createdOrders.map(o => o.id))
  } catch (err) {
    console.error('Order creation simulation failed with error:', err)
  }
}

testOrder()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
