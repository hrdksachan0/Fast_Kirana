import dotenv from 'dotenv'
dotenv.config()
import { prisma } from './src/lib/prisma'

async function main() {
  console.log('Testing prisma connection...')
  
  let connectionString = (process.env.NODE_ENV !== 'production' && process.env.DIRECT_URL)
    ? process.env.DIRECT_URL
    : (process.env.DATABASE_URL || '')

  console.log('Using connection string:', connectionString ? connectionString.replace(/:[^:@]+@/, ':***@') : 'none')
  console.log('process.env.NODE_ENV:', process.env.NODE_ENV)
  
  console.time('DB Query')
  try {
    const userCount = await prisma.user.count()
    console.log(`Success! User count: ${userCount}`)
  } catch (err) {
    console.error('Prisma connection failed:', err)
  } finally {
    console.timeEnd('DB Query')
    await prisma.$disconnect()
  }
}

main()
