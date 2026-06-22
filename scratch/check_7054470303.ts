import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import 'dotenv/config'

let connectionString = process.env.DATABASE_URL || ''
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim()
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1)
  }
  connectionString = connectionString.trim()
  if (!connectionString.includes('uselibpqcompat=')) {
    const separator = connectionString.includes('?') ? '&' : '?'
    connectionString = `${connectionString}${separator}uselibpqcompat=true`
  }
}

const pool = new Pool({
  connectionString,
  max: 1
})

const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function check() {
  try {
    const phone = '7054470303'
    console.log(`Checking DB for phone: ${phone}`)
    const cleaned = phone.replace(/\D/g, '')
    const normalizedPhone = `+91${cleaned}`
    console.log(`Normalized phone: ${normalizedPhone}`)
    
    const user = await prisma.user.findFirst({
      where: { phone: normalizedPhone },
      select: { id: true, email: true, name: true, phone: true }
    })
    console.log('User query result:', user)
    
    const waDigits = normalizedPhone.replace(/\D/g, '').replace(/^91/, '')
    const normalizedEmail = user ? user.email : `wa-${waDigits}@fastkirana.com`
    console.log('Normalized email:', normalizedEmail)

    // Try creating/deleting OTP token
    console.log('Testing OtpToken cleanup...')
    await prisma.otpToken.deleteMany({
      where: { email: normalizedEmail }
    })
    console.log('OtpToken cleanup OK')

    console.log('Testing OtpToken creation...')
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000)
    await prisma.otpToken.create({
      data: {
        email: normalizedEmail,
        token: '123456',
        expiresAt
      }
    })
    console.log('OtpToken creation OK')
    
  } catch (err) {
    console.error('Error during check:', err)
  } finally {
    await prisma.$disconnect()
    await pool.end()
  }
}

check()
