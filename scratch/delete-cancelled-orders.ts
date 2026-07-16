import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  // Count how many orders are cancelled
  const cancelledCount = await prisma.order.count({
    where: { status: 'CANCELLED' }
  })

  console.log(`Found ${cancelledCount} cancelled orders in the database.`)

  if (cancelledCount === 0) {
    console.log('No cancelled orders to delete.')
    return
  }

  // Delete all cancelled orders (cascade will handle OrderItems automatically)
  const deleteResult = await prisma.order.deleteMany({
    where: { status: 'CANCELLED' }
  })

  console.log(`Successfully deleted ${deleteResult.count} cancelled orders from the database.`)
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error deleting cancelled orders:', err)
    process.exit(1)
  })
