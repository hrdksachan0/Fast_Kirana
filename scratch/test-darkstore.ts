import { prisma } from '../src/lib/prisma'

async function test() {
  console.log('Testing DarkStore database query...')
  try {
    const stores = await prisma.darkStore.findMany()
    console.log(`✅ DarkStore query successful. Found ${stores.length} store(s):`)
    console.log(JSON.stringify(stores, null, 2))
  } catch (e: any) {
    console.error('❌ DarkStore query failed:', e.message || e)
  } finally {
    await prisma.$disconnect()
  }
}

test()
