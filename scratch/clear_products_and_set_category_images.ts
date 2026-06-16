import { prisma } from '../src/lib/prisma'

const CATEGORY_IMAGES: Record<string, string> = {
  'fruits-vegetables': '/fruits_vegetables_category.png',
  'dairy-breakfast': '/dairy_breakfast_category.png',
  'snacks-munchies': '/snacks_munchies_category.png',
  'beverages': '/beverages_category.png',
  'personal-care': '/personal_care_category.png',
  'household': '/household_category.png',
  'bakery-biscuits': '/bakery_biscuits_category.png',
  'atta-rice-dal': '/atta_rice_dal_category.png',
  'ice-cream': '/ice_cream_category.png',
  'cafe': '/cafe_category.png'
}

async function main() {
  console.log('🌱 Starting category images update...')
  
  for (const [slug, imageUrl] of Object.entries(CATEGORY_IMAGES)) {
    const existing = await prisma.category.findUnique({
      where: { slug }
    })

    if (existing) {
      await prisma.category.update({
        where: { id: existing.id },
        data: { imageUrl }
      })
      console.log(`Updated category: "${existing.name}" (slug: "${slug}") -> set imageUrl = "${imageUrl}"`)
    } else {
      console.log(`Category with slug "${slug}" not found in DB, skipping.`)
    }
  }

  console.log('\n🧹 Clearing all product data from database...')
  
  // Delete all products
  const deleteResult = await prisma.product.deleteMany({})
  console.log(`Deleted ${deleteResult.count} products from database.`)
  
  console.log('\n✅ Database cleanup complete!')
}

main()
  .then(async () => {
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
