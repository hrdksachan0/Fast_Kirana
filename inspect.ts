import { prisma } from './src/lib/prisma'

async function run() {
  const maxOrder = await prisma.order.findFirst({
    orderBy: { readableId: 'desc' },
    select: { readableId: true }
  })
  console.log('Highest Order readableId:', maxOrder?.readableId)
  
  const productCount = await prisma.product.count()
  console.log('Total Products:', productCount)
  
  const maxProduct = await prisma.product.findFirst({
    orderBy: { readableId: 'desc' },
    select: { readableId: true }
  })
  console.log('Highest Product readableId:', maxProduct?.readableId)
}

run()

