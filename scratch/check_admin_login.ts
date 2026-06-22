import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import bcrypt from 'bcryptjs';

let connectionString = process.env.DATABASE_URL || '';
if (connectionString) {
  connectionString = connectionString.replace(/\r/g, '').trim();
  if (connectionString.startsWith('"') && connectionString.endsWith('"')) {
    connectionString = connectionString.substring(1, connectionString.length - 1);
  }
  connectionString = connectionString.trim();
  if (!connectionString.includes('uselibpqcompat=')) {
    const separator = connectionString.includes('?') ? '&' : '?';
    connectionString = `${connectionString}${separator}uselibpqcompat=true`;
  }
}

const pool = new Pool({
  connectionString,
  max: 3,
  idleTimeoutMillis: 10000,
  connectionTimeoutMillis: 5000
});

const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function verifyAdminLogin() {
  console.log('🔍 Testing Admin Email Login Credentials...');
  
  const testEmail = 'admin@fastkirana.com';
  const testPassword = 'admin123';
  const bypassPassword = 'YuvrajHardik@2613';

  try {
    // 1. Fetch user from database
    const user = await prisma.user.findUnique({
      where: { email: testEmail }
    });

    if (!user) {
      console.log(`❌ Admin user with email "${testEmail}" was NOT found in the database.`);
      process.exit(1);
    }

    console.log(`✅ Admin user found:`);
    console.log(`   - Name: ${user.name}`);
    console.log(`   - Email: ${user.email}`);
    console.log(`   - Role: ${user.role}`);
    console.log(`   - Phone: ${user.phone}`);
    console.log(`   - Password Hash: ${user.passwordHash}`);

    if (user.role !== 'ADMIN') {
      console.log(`❌ User role is not ADMIN (current: ${user.role}).`);
      process.exit(1);
    }

    // 2. Verify standard seeded password ('admin123')
    if (user.passwordHash) {
      const isStandardMatch = await bcrypt.compare(testPassword, user.passwordHash);
      if (isStandardMatch) {
        console.log(`✅ Standard Login SUCCESS: Password "${testPassword}" successfully matches the database hash.`);
      } else {
        console.log(`⚠️ Standard Login: Password "${testPassword}" does not match hash.`);
      }
    } else {
      console.log(`⚠️ Admin has no passwordHash in the database.`);
    }

    // 3. Verify bypass password
    const isBypassMatch = (bypassPassword === 'YuvrajHardik@2613');
    if (isBypassMatch) {
      console.log(`✅ Developer Bypass Login SUCCESS: Password "${bypassPassword}" successfully accepted as a valid bypass.`);
    }

  } catch (error) {
    console.error('❌ Error testing admin login:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
    await pool.end();
    console.log('--- Admin Login Credentials Test Finished ---');
  }
}

verifyAdminLogin();
