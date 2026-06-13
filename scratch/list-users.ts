import dotenv from 'dotenv'
dotenv.config({ path: 'd:/Fastkirana/.env' })

import { prisma } from '../src/lib/prisma'

async function main() {
  try {
    const users = await prisma.user.findMany({
      include: {
        accounts: true
      }
    })
    console.log('--- USERS LIST ---')
    console.log(JSON.stringify(users, null, 2))
  } catch (err) {
    console.error('Error listing users:', err)
  } finally {
    await prisma.$disconnect()
  }
}

main()
