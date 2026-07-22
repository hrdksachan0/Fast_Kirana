import { prisma } from '../src/lib/prisma'
import { execSync } from 'child_process'

async function main() {
  console.log('Adding columns to PostgreSQL database...')
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "isBlocked" BOOLEAN NOT NULL DEFAULT false;
  `)
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "blockReason" TEXT;
  `)
  await prisma.$executeRawUnsafe(`
    ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "blockedAt" TIMESTAMP(3);
  `)
  console.log('Database columns added successfully!')

  console.log('Regenerating Prisma client...')
  execSync('npx prisma generate', { stdio: 'inherit' })
  console.log('Prisma client regenerated successfully!')
}

main()
  .catch((err) => {
    console.error('Error applying schema changes:', err)
    process.exit(1)
  })
  .finally(() => {
    prisma.$disconnect()
  })
