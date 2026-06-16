import { prisma } from '../src/lib/prisma'

const CATEGORIES_TO_ADD = [
  { name: 'Fruits & Vegetables', slug: 'fruits-vegetables', sortOrder: 1 },
  { name: 'Dairy & Breakfast', slug: 'dairy-breakfast', sortOrder: 2 },
  { name: 'Snacks & Munchies', slug: 'snacks-munchies', sortOrder: 3 },
  { name: 'Beverages', slug: 'beverages', sortOrder: 4 },
  { name: 'Personal Care', slug: 'personal-care', sortOrder: 5 },
  { name: 'Household Needs', slug: 'household', sortOrder: 6 },
  { name: 'Bakery & Biscuits', slug: 'bakery-biscuits', sortOrder: 7 },
  { name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', sortOrder: 8 },
  { name: 'Ice Cream', slug: 'ice-cream', sortOrder: 9 },
  { name: 'FastKirana Café', slug: 'cafe', sortOrder: 10 }
]

async function main() {
  console.log('🌱 Starting category restore...')
  let created = 0
  let updated = 0

  for (const cat of CATEGORIES_TO_ADD) {
    const existing = await prisma.category.findUnique({
      where: { slug: cat.slug }
    })

    if (existing) {
      // Clear imageUrl to null (no photos) and update sortOrder
      await prisma.category.update({
        where: { id: existing.id },
        data: {
          sortOrder: cat.sortOrder,
          imageUrl: null // clear category image URL (no photos)
        }
      })
      console.log(`Updated category: "${cat.name}" (slug: "${cat.slug}") -> set imageUrl = null, sortOrder = ${cat.sortOrder}`)
      updated++
    } else {
      await prisma.category.create({
        data: {
          name: cat.name,
          slug: cat.slug,
          imageUrl: null, // no photos
          sortOrder: cat.sortOrder
        }
      })
      console.log(`Created category: "${cat.name}" (slug: "${cat.slug}") -> imageUrl = null, sortOrder = ${cat.sortOrder}`)
      created++
    }
  }

  console.log(`\n✅ Category restore complete! Created: ${created}, Updated: ${updated}`)
}

main()
  .then(async () => {
    // wait a moment for prisma adapter to cleanup
    setTimeout(async () => {
      await prisma.$disconnect()
      process.exit(0)
    }, 500)
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
