import { prisma } from '../src/lib/prisma'

async function main() {
  const admins = await prisma.user.findMany({
    where: {
      role: 'ADMIN'
    },
    select: {
      id: true,
      name: true,
      email: true,
      phone: true
    }
  })
  console.log('Admins in DB:', JSON.stringify(admins, null, 2))
}

main()
