import { prisma } from '../src/lib/prisma'

async function run() {
  console.log('--- Concurrency Test Started ---')
  
  // 1. Fetch a valid active customer
  const user = await prisma.user.findFirst({
    where: { role: 'USER' }
  })
  if (!user) {
    console.error('No USER found in the database to run the test.')
    return
  }
  console.log(`Using test user: ${user.name} (ID: ${user.id})`)

  // 2. Fetch a valid available product with stock > 50 (excluding cafe/restaurant to bypass timing checks)
  const product = await prisma.product.findFirst({
    where: {
      isAvailable: true,
      stock: { gt: 50 },
      category: {
        slug: { notIn: ['cafe', 'restaurant'] }
      },
      NOT: [
        { tags: { has: 'cafe' } },
        { tags: { has: 'restaurant' } }
      ]
    },
    include: { category: true }
  })
  if (!product) {
    console.error('No available product with stock > 50 found.')
    return
  }
  console.log(`Using test product: ${product.name} (ID: ${product.id}, Stock: ${product.stock})`)

  // 3. Prepare order payload
  const payload = {
    addressId: null, // Will be overridden since deliveryMethod is PICKUP
    paymentMethod: 'COD',
    items: [
      {
        product: {
          id: product.id,
          slug: product.slug,
          name: product.name,
          price: product.price,
          mrp: product.mrp,
          stock: product.stock,
          isAvailable: product.isAvailable,
          category: { slug: product.category.slug }
        },
        quantity: 5
      }
    ],
    deliveryMethod: 'PICKUP',
    isB2B: false,
    scheduledSlot: 'INSTANT'
  }

  // 4. Fire 15 concurrent requests
  console.log('Firing 15 concurrent order placements at once...')
  const startTime = Date.now()
  const requests = Array.from({ length: 15 }).map(async (_, idx) => {
    try {
      const response = await fetch('http://localhost:3000/api/orders', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': user.id,
          'x-user-email': user.email,
          'x-user-name': user.name || 'Test User',
          'x-user-role': user.role,
          'x-bypass-limiter': 'true'
        },
        body: JSON.stringify(payload)
      })

      const status = response.status
      const body = await response.json()
      return { idx: idx + 1, success: response.ok, status, error: body.error || null, orderId: body.id || null, readableId: body.readableId || null }
    } catch (err: any) {
      return { idx: idx + 1, success: false, status: 500, error: err.message, orderId: null, readableId: null }
    }
  })

  const results = await Promise.all(requests)
  const duration = Date.now() - startTime

  console.log(`\nCompleted in ${duration}ms. Results:`)
  console.table(results)

  const successCount = results.filter(r => r.success).length
  console.log(`\nTotal Success: ${successCount}/15`)
  
  if (successCount === 15) {
    console.log('✅ Success! No unique constraint collisions occurred and all orders succeeded!')
  } else {
    console.error('❌ Failed. Some orders failed to process.')
  }
}

run()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
