import 'dotenv/config'
import { PrismaClient, PaymentMethod, PaymentStatus, OrderStatus } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import { FREE_DELIVERY_THRESHOLD, DELIVERY_FEE, TAX_RATE } from '../src/lib/constants'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function runTest() {
  // 1. Get a user
  const user = await prisma.user.findFirst({
    where: { email: 'user@fastkirana.com' }
  })
  if (!user) throw new Error('Test user not found')
  const userId = user.id

  // 2. Get or create a address
  let address = await prisma.address.findFirst({
    where: { userId }
  })
  if (!address) {
    address = await prisma.address.create({
      data: {
        userId,
        label: 'Home',
        houseNo: '123',
        street: 'Ghatampur St',
        area: 'Ghatampur',
        city: 'Kanpur',
        pincode: '209206',
        phone: '1234567890'
      }
    })
  }

  // 3. Find the products
  const productSlugs = [
    'butter-paneer-dosa',
    'veg-sandwitch',
    'chilli-potato',
    'chili-paneer-gravy'
  ]

  const dbProducts = await prisma.product.findMany({
    where: { slug: { in: productSlugs } },
    include: { category: true }
  })

  console.log(`Found ${dbProducts.length} dbProducts for testing`)

  const items = [
    {
      product: dbProducts.find(p => p.slug === 'butter-paneer-dosa'),
      quantity: 2
    },
    {
      product: dbProducts.find(p => p.slug === 'veg-sandwitch'),
      quantity: 1
    },
    {
      product: dbProducts.find(p => p.slug === 'chilli-potato'),
      quantity: 1
    },
    {
      product: dbProducts.find(p => p.slug === 'chili-paneer-gravy'),
      quantity: 1
    }
  ].filter(i => i.product)

  if (items.length !== 4) {
    console.error('Failed to resolve all products:', items.map(i => i.product?.slug))
    return
  }

  // Map to format similar to cart items
  const cartItems = items.map(item => ({
    product: {
      id: item.product!.id,
      slug: item.product!.slug,
      name: item.product!.name,
      imageUrl: item.product!.imageUrl,
      price: item.product!.price,
      mrp: item.product!.mrp,
      stock: item.product!.stock,
      unit: item.product!.unit,
      discount: item.product!.discount
    },
    quantity: item.quantity
  }))

  console.log('Cart items payload prepared.')

  // Re-implement /api/orders route logic in test context
  const isCafeProductLocal = (p: any) => {
    if (!p) return false
    if (p.category?.slug === 'cafe') return true
    if (p.tags?.includes('cafe')) return true
    return false
  }

  const cafeItems: any[] = []
  const groceryItems: any[] = []

  for (const item of cartItems) {
    const isVariant = item.product.id.includes('_')
    const [productId, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]

    const dbProduct = dbProducts.find((p) => p.id === productId)
    if (!dbProduct || !dbProduct.isAvailable) {
      throw new Error(`Product "${item.product.name}" is no longer available`)
    }

    const itemWithDb = {
      ...item,
      dbProduct
    }

    if (isCafeProductLocal(dbProduct)) {
      cafeItems.push(itemWithDb)
    } else {
      groceryItems.push(itemWithDb)
    }
  }

  const combinedSubtotal = cartItems.reduce((sum: number, item: any) => {
    return sum + item.product.price * item.quantity
  }, 0)

  const combinedDiscount = 0
  const ordersToCreate: any[] = []

  if (groceryItems.length > 0) {
    const grocerySubtotal = groceryItems.reduce((sum, item) => sum + item.dbProduct.price * item.quantity, 0)
    const groceryDiscount = 0
    const groceryDeliveryFee = grocerySubtotal >= FREE_DELIVERY_THRESHOLD ? 0 : DELIVERY_FEE
    const groceryTaxes = (grocerySubtotal - groceryDiscount) * TAX_RATE
    const groceryTotal = grocerySubtotal - groceryDiscount + groceryDeliveryFee + groceryTaxes

    ordersToCreate.push({
      type: 'GROCERY',
      subtotal: grocerySubtotal,
      discount: groceryDiscount,
      deliveryFee: groceryDeliveryFee,
      taxes: groceryTaxes,
      total: groceryTotal,
      items: groceryItems,
    })
  }

  if (cafeItems.length > 0) {
    const cafeSubtotal = cafeItems.reduce((sum, item) => sum + item.dbProduct.price * item.quantity, 0)
    const cafeDiscount = 0
    const cafeDeliveryFee = cafeSubtotal >= 200 ? 0 : 25
    const cafeTaxes = (cafeSubtotal - cafeDiscount) * TAX_RATE
    const cafeTotal = cafeSubtotal - cafeDiscount + cafeDeliveryFee + cafeTaxes

    ordersToCreate.push({
      type: 'CAFE',
      subtotal: cafeSubtotal,
      discount: cafeDiscount,
      deliveryFee: cafeDeliveryFee,
      taxes: cafeTaxes,
      total: cafeTotal,
      items: cafeItems,
    })
  }

  const paymentStatus = PaymentStatus.PENDING

  console.log(`Starting transaction to create ${ordersToCreate.length} orders...`)

  const createdOrders = await prisma.$transaction(async (tx) => {
    const results: any[] = []
    const now = new Date()

    for (const orderInfo of ordersToCreate) {
      const orderItemsData = orderInfo.items.map((item: any) => {
        const isVariant = item.product.id.includes('_')
        const [_, variantName] = isVariant ? item.product.id.split('_') : [item.product.id, null]
        
        let itemPrice = item.dbProduct.price
        return {
          productId: item.dbProduct.id,
          name: item.product.name,
          price: itemPrice,
          quantity: item.quantity,
          imageUrl: item.dbProduct.imageUrl,
          selectedVariant: variantName,
        }
      })

      let estimatedDelivery = new Date(Date.now() + (orderInfo.type === 'CAFE' ? 30 : 10) * 60 * 1000)

      const newOrder = await tx.order.create({
        data: {
          userId: userId,
          addressId: address!.id,
          status: OrderStatus.PENDING,
          subtotal: orderInfo.subtotal,
          discount: orderInfo.discount,
          deliveryFee: orderInfo.deliveryFee,
          taxes: orderInfo.taxes,
          total: orderInfo.total,
          paymentMethod: PaymentMethod.COD,
          paymentStatus,
          estimatedDelivery,
          deliveryMethod: 'DELIVERY',
          isB2B: false,
          shopName: orderInfo.type === 'CAFE' ? 'FastKirana Cafe Kitchen' : 'FastKirana Dark Store',
          shopPhone: orderInfo.type === 'CAFE' ? '+91 70544 70303' : '+91 70544 70303',
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
        if (item.selectedVariant) {
          const dbProd = await tx.product.findUnique({
            where: { id: item.productId }
          })
          if (dbProd && dbProd.variants && Array.isArray(dbProd.variants)) {
            const updatedVariants = (dbProd.variants as any[]).map((v) => {
              if (v.name === item.selectedVariant) {
                return { ...v, stock: Math.max(0, v.stock - item.quantity) }
              }
              return v
            })
            const newTotalStock = updatedVariants.reduce((sum, v) => sum + v.stock, 0)
            
            await tx.product.update({
              where: { id: item.productId },
              data: {
                variants: updatedVariants,
                stock: newTotalStock,
              }
            })
          }
        } else {
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
      }
    }

    return results
  })

  console.log(`Success! Created ${createdOrders.length} orders:`)
  createdOrders.forEach(o => {
    console.log(`- Order ID: ${o.id}, Shop: ${o.shopName}, Total: ₹${o.total}, Items Count: ${o.items.length}`)
  })
}

runTest()
  .then(async () => {
    await prisma.$disconnect()
    process.exit(0)
  })
  .catch(async (e) => {
    console.error('Test execution failed with error:')
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
