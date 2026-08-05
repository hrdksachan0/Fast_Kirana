import { prisma } from './src/lib/prisma'

async function main() {
  console.log('Finding Restaurant category...')
  const restaurantCategory = await prisma.category.findFirst({
    where: { slug: 'restaurant' }
  })

  if (!restaurantCategory) {
    console.error('Restaurant category not found! Please make sure the database is seeded.')
    process.exit(1)
  }

  console.log(`Found category: ${restaurantCategory.name} (ID: ${restaurantCategory.id})`)

  const productName = 'Butter Paneer Masala'
  const slug = 'butter-paneer-masala'

  // Check if product already exists
  const existingProduct = await prisma.product.findUnique({
    where: { slug }
  })

  if (existingProduct) {
    console.log(`Product "${productName}" already exists. Updating it...`)
    const updated = await prisma.product.update({
      where: { id: existingProduct.id },
      data: {
        categoryId: restaurantCategory.id,
        price: 220,
        mrp: 260,
        stock: 100,
        tags: ['restaurant', 'north-indian'],
        unit: '1 Portion',
        isAvailable: true
      }
    })
    console.log('Product updated successfully:', updated)
  } else {
    console.log(`Creating product "${productName}"...`)
    const created = await prisma.product.create({
      data: {
        name: productName,
        slug,
        description: 'Creamy, rich, and delicious paneer cubes cooked in a butter gravy with traditional spices.',
        imageUrl: '🍲',
        categoryId: restaurantCategory.id,
        mrp: 260,
        price: 220,
        discount: 15,
        unit: '1 Portion',
        stock: 100,
        isAvailable: true,
        tags: ['restaurant', 'north-indian'],
        minStock: 10,
        costPrice: 150
      }
    })
    console.log('Product created successfully:', created)
  }
}

main()
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
