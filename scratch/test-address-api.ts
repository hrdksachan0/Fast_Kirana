import { prisma } from '../src/lib/prisma'

async function test() {
  console.log('Starting backend address creation test using main prisma instance...')
  try {
    // Check if the user exists
    const testUser = await prisma.user.findFirst()
    if (!testUser) {
      console.log('❌ No user found in database to link address to.')
      return;
    }
    
    console.log(`Creating address for test user ID: ${testUser.id} (${testUser.name})`)
    const newAddress = await prisma.address.create({
      data: {
        userId: testUser.id,
        label: 'Test Home 🏠',
        houseNo: 'Flat 101',
        street: 'Main Road',
        area: 'Vikas Nagar',
        city: 'Ghatampur',
        pincode: '209206',
        phone: '9999999999',
        isDefault: false,
        lat: 26.1534185,
        lng: 80.1714024
      }
    })
    console.log('✅ Address created successfully in database:', newAddress)
    
    // Clean up
    await prisma.address.delete({
      where: { id: newAddress.id }
    })
    console.log('✅ Test Address cleaned up successfully.')
  } catch (e: any) {
    console.error('❌ Failed to create address in database:', e.message || e)
  } finally {
    await prisma.$disconnect()
  }
}

test()
