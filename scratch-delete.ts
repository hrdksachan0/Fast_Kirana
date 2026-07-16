import { prisma } from './src/lib/prisma'

async function main() {
  console.log('--- Database Deletion Utility ---')

  // 1. Delete the product 'butter-paneer-masala'
  const productSlug = 'butter-paneer-masala'
  const product = await prisma.product.findUnique({
    where: { slug: productSlug }
  })

  if (product) {
    console.log(`Found product "${product.name}". Deleting it...`)
    await prisma.product.delete({
      where: { id: product.id }
    })
    console.log('Product deleted successfully.')
  } else {
    console.log(`Product with slug "${productSlug}" was not found (already deleted).`)
  }

  // 2. Delete all CANCELLED orders
  console.log('Querying all CANCELLED orders...')
  const cancelledOrders = await prisma.order.findMany({
    where: { status: 'CANCELLED' }
  })

  console.log(`Found ${cancelledOrders.length} cancelled orders to delete.`)

  if (cancelledOrders.length > 0) {
    const deleteResult = await prisma.order.deleteMany({
      where: { status: 'CANCELLED' }
    })
    console.log(`Successfully deleted ${deleteResult.count} cancelled orders (and cascaded order items).`)
  } else {
    console.log('No cancelled orders to delete.')
  }
}

main()
  .catch(err => {
    console.error('Error during deletion process:', err)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
