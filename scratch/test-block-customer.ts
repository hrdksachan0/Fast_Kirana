import { prisma } from '../src/lib/prisma'

async function runTest() {
  console.log('--- Testing Block Customer Feature End-to-End ---')

  // 1. Get or create a test customer user
  let user = await prisma.user.findFirst({
    where: { role: 'USER', email: { startsWith: 'test-block-' } }
  })

  if (!user) {
    user = await prisma.user.create({
      data: {
        name: 'Block Test Customer',
        email: `test-block-${Date.now()}@fastkirana.com`,
        phone: '+919876543210',
        role: 'USER',
        isBlocked: false,
      }
    })
  }

  console.log(`Using test customer: ${user.name} (${user.email}, ID: ${user.id})`)

  // 2. Block the customer directly via database / logic
  console.log('\n[Step 1] Blocking customer account with reason: "Repeated Fake COD Orders"')
  await prisma.user.update({
    where: { id: user.id },
    data: {
      isBlocked: true,
      blockReason: 'Repeated Fake COD Orders',
      blockedAt: new Date(),
    }
  })
  console.log('Customer status updated to isBlocked = true')

  // 3. Test OTP Send endpoint for blocked user
  console.log('\n[Step 2] Testing OTP send for blocked user...')
  const otpRes = await fetch('http://localhost:3000/api/auth/otp/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: user.email })
  })
  const otpData = await otpRes.json()
  console.log(`OTP Send Status: ${otpRes.status}, Body:`, otpData)
  if (otpRes.status === 403) {
    console.log('✅ OTP Send correctly blocked!')
  } else {
    console.error('❌ OTP Send check failed.')
  }

  // 4. Test Order Placement for blocked user
  console.log('\n[Step 3] Testing order placement for blocked user...')
  const product = await prisma.product.findFirst({ where: { isAvailable: true, stock: { gt: 10 } }, include: { category: true } })
  if (product) {
    const orderRes = await fetch('http://localhost:3000/api/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-user-id': user.id,
        'x-user-email': user.email,
        'x-user-name': user.name || 'Test User',
        'x-user-role': user.role,
        'x-bypass-limiter': 'true'
      },
      body: JSON.stringify({
        addressId: null,
        paymentMethod: 'COD',
        items: [{
          product: {
            id: product.id,
            slug: product.slug,
            name: product.name,
            price: product.price,
            mrp: product.mrp,
            stock: product.stock,
            isAvailable: true,
            category: { slug: product.category.slug }
          },
          quantity: 5
        }],
        deliveryMethod: 'PICKUP',
        isB2B: false,
        scheduledSlot: 'INSTANT'
      })
    })
    const orderData = await orderRes.json()
    console.log(`Order Placement Status: ${orderRes.status}, Body:`, orderData)
    if (orderRes.status === 403) {
      console.log('✅ Order Placement correctly blocked!')
    } else {
      console.error('❌ Order Placement check failed.')
    }
  }

  // 5. Unblock the customer
  console.log('\n[Step 4] Unblocking customer account...')
  await prisma.user.update({
    where: { id: user.id },
    data: {
      isBlocked: false,
      blockReason: null,
      blockedAt: null,
    }
  })
  console.log('Customer unblocked successfully!')

  console.log('\n--- All Block Customer Tests Completed ---')
}

runTest()
  .catch(console.error)
  .finally(() => prisma.$disconnect())
