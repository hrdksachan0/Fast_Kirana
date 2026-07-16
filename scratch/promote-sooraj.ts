import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

async function main() {
  const phone = '8115214721'
  const normalizedPhone = '+918115214721'

  // Update both the phone format just in case
  const user = await prisma.user.findFirst({
    where: {
      OR: [
        { phone: phone },
        { phone: normalizedPhone },
        { email: 'soorajyadavgtm@gmail.com' }
      ]
    }
  })

  if (!user) {
    console.error('User not found in database')
    return
  }

  const updatedUser = await prisma.user.update({
    where: { id: user.id },
    data: {
      role: 'ADMIN',
      phone: normalizedPhone // Ensure it has international format for WhatsApp alerts
    }
  })

  console.log('Successfully upgraded user to ADMIN:', updatedUser)
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
