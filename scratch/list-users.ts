import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const users = await prisma.user.findMany({
    select: {
      id: true,
      name: true,
      email: true,
      phone: true,
      role: true,
    }
  })
  console.log('--- Current Users in Database ---')
  console.log(JSON.stringify(users, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
