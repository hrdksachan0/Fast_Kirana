import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import bcrypt from 'bcryptjs'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  console.log('🌱 Running safe seed (preserves all uploaded data)...')

  // ─────────────────────────────────────────────────────────────
  // NOTE: We do NOT delete any products, categories, or orders.
  // This seed only creates users and coupons if they don't exist.
  // All admin-uploaded products and categories are fully preserved.
  // ─────────────────────────────────────────────────────────────

  // ── Users (upsert so running twice is safe) ──
  const adminHash = await bcrypt.hash('admin123', 12)
  const userHash = await bcrypt.hash('user123', 12)
  const deliveryHash = await bcrypt.hash('delivery123', 12)
  const chefHash = await bcrypt.hash('chef123', 12)
  const pickerHash = await bcrypt.hash('picker123', 12)

  await prisma.user.upsert({
    where: { email: 'admin@fastkirana.com' },
    update: {},
    create: {
      name: 'Admin',
      email: 'admin@fastkirana.com',
      passwordHash: adminHash,
      role: 'ADMIN',
      phone: '+919876543210',
    },
  })

  await prisma.user.upsert({
    where: { email: 'chef@fastkirana.com' },
    update: {},
    create: {
      name: 'Chef Kitchener',
      email: 'chef@fastkirana.com',
      passwordHash: chefHash,
      role: 'CHEF',
      phone: '+919900112233',
    },
  })

  await prisma.user.upsert({
    where: { email: 'picker@fastkirana.com' },
    update: {},
    create: {
      name: 'Suresh Picker',
      email: 'picker@fastkirana.com',
      passwordHash: pickerHash,
      role: 'PICKER',
      phone: '+919800001122',
    },
  })

  await prisma.user.upsert({
    where: { email: 'delivery@fastkirana.com' },
    update: {},
    create: {
      name: 'Ramesh Rider',
      email: 'delivery@fastkirana.com',
      passwordHash: deliveryHash,
      role: 'DELIVERY',
      phone: '+919988776655',
    },
  })

  await prisma.user.upsert({
    where: { email: 'user@fastkirana.com' },
    update: {},
    create: {
      name: 'Rahul Sharma',
      email: 'user@fastkirana.com',
      passwordHash: userHash,
      role: 'USER',
      phone: '+919123456789',
      addresses: {
        create: {
          label: 'Home',
          houseNo: '42-B',
          street: 'Patel Nagar',
          area: 'Ghatampur',
          city: 'Kanpur',
          pincode: '209206',
          phone: '+919123456789',
          isDefault: true,
        },
      },
    },
  })

  // ── Coupons (createMany with skipDuplicates) ──
  await prisma.coupon.createMany({
    skipDuplicates: true,
    data: [
      { code: 'WELCOME50', discountType: 'PERCENT', value: 50, minOrder: 199, maxDiscount: 100, maxUses: 1000, isActive: true },
      { code: 'FLAT100',   discountType: 'FLAT',    value: 100, minOrder: 499, maxUses: 500,  isActive: true },
      { code: 'SAVE20',    discountType: 'PERCENT', value: 20,  minOrder: 299, maxDiscount: 150, maxUses: 2000, isActive: true },
      { code: 'FIRST10',   discountType: 'FLAT',    value: 10,  minOrder: 99,  maxUses: 5000, isActive: true },
      { code: 'MEGA200',   discountType: 'FLAT',    value: 200, minOrder: 999, maxUses: 100,  isActive: true },
    ],
  })

  const productCount = await prisma.product.count()
  const categoryCount = await prisma.category.count()

  console.log(`✅ Safe seed complete!`)
  console.log(`   → Users & coupons created/skipped (no duplicates)`)
  console.log(`   → Your uploaded data is safe: ${categoryCount} categories, ${productCount} products preserved`)
}

main()
  .then(async () => await prisma.$disconnect())
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
