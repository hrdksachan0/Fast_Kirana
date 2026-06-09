import { prisma } from '@/lib/prisma'
import { CafeStorefront } from '@/components/cafe/cafe-storefront'

// Revalidate page every 30 seconds to keep quantities synced
export const revalidate = 30

export default async function CafePage() {
  // 1. Self-healing seeding for Cafe category & hot food products
  let cafeCategory = null
  try {
    cafeCategory = await prisma.category.findUnique({
      where: { slug: 'cafe' }
    })

    if (!cafeCategory) {
      cafeCategory = await prisma.category.create({
        data: {
          name: 'FastKirana Cafe',
          slug: 'cafe',
          imageUrl: '/cafe_category.png',
          sortOrder: 0,
        }
      })
    } else if (cafeCategory.imageUrl === '☕') {
      // Update existing cafe category with proper image
      cafeCategory = await prisma.category.update({
        where: { id: cafeCategory.id },
        data: { imageUrl: '/cafe_category.png' }
      })
    }
  } catch (e) {
    console.warn('Database connection error in cafe page: failed to fetch/seed cafe category')
  }

  // Define hot cafe items to seed if they do not exist
  const hotCafeProducts = [
    {
      name: 'Special Masala Chai',
      slug: 'special-masala-chai',
      description: 'Hot steaming milk tea brewed with fresh ginger, cardamom, and premium tea leaves.',
      imageUrl: '☕',
      mrp: 35,
      price: 30,
      discount: 14,
      unit: '1 cup (150 ml)',
      stock: 100,
      tags: ['cafe', 'hot-beverage', 'breakfast', 'tea', 'popular'],
    },
    {
      name: 'Hot Filter Coffee',
      slug: 'hot-filter-coffee',
      description: 'Traditional South Indian filter coffee brewed with fresh milk and premium chicory blend.',
      imageUrl: '☕',
      mrp: 45,
      price: 40,
      discount: 11,
      unit: '1 cup (150 ml)',
      stock: 100,
      tags: ['cafe', 'hot-beverage', 'breakfast', 'coffee', 'popular'],
    },
    {
      name: 'Fresh Samosa (2 pcs)',
      slug: 'fresh-samosa-2pcs',
      description: 'Crispy golden pastry stuffed with spiced potato and peas filling. Served hot with sweet tamarind and spicy green chutney.',
      imageUrl: '🥟',
      mrp: 35,
      price: 30,
      discount: 14,
      unit: '1 plate (2 pcs)',
      stock: 80,
      tags: ['cafe', 'hot-bite', 'snacks', 'samosa', 'popular'],
    },
    {
      name: 'Veg Grilled Sandwich',
      slug: 'veg-grilled-sandwich',
      description: 'Golden grilled bread stuffed with fresh cucumber, tomato, onion slices, and green chutney spreads.',
      imageUrl: '🥪',
      mrp: 99,
      price: 79,
      discount: 20,
      unit: '1 pc',
      stock: 60,
      tags: ['cafe', 'hot-bite', 'breakfast', 'snacks'],
    },
    // Frankie Rolls (from user's screenshot)
    {
      name: 'Veg Frankie Roll',
      slug: 'veg-frankie-roll',
      description: 'Golden-wrapped crispy roll with vegetable patty, fresh onions, spices and green mint chutney.',
      imageUrl: '🌯',
      mrp: 66,
      price: 59,
      discount: 11,
      unit: '1 Roll',
      stock: 100,
      tags: ['cafe', 'frankie-rolls', 'veg', 'popular'],
    },
    {
      name: 'Paneer Frankie Roll',
      slug: 'paneer-frankie-roll',
      description: 'Scrumptious roll stuffed with spiced paneer cubes, crisp veggies, onions and green chutney.',
      imageUrl: '🌯',
      mrp: 76,
      price: 69,
      discount: 9,
      unit: '1 Roll',
      stock: 100,
      tags: ['cafe', 'frankie-rolls', 'paneer'],
    },
    {
      name: 'Cheese Frankie Roll',
      slug: 'cheese-frankie-roll',
      description: 'Delicious hot roll loaded with melted cheese, vegetable patty, and tangy sauces.',
      imageUrl: '🌯',
      mrp: 86,
      price: 79,
      discount: 8,
      unit: '1 Roll',
      stock: 100,
      tags: ['cafe', 'frankie-rolls', 'cheese'],
    },
    {
      name: 'Paneer Cheese Frankie Roll',
      slug: 'paneer-cheese-frankie-roll',
      description: 'Perfect combination of soft paneer cubes and melted cheese, cooked with spices and wrapped in a fresh paratha.',
      imageUrl: '🌯',
      mrp: 92,
      price: 92,
      discount: 0,
      unit: '1 Roll',
      stock: 100,
      tags: ['cafe', 'frankie-rolls', 'paneer-cheese'],
    },
    {
      name: 'Paneer Kathi Roll',
      slug: 'paneer-kathi-roll',
      description: 'Classic Kolkata street-style kathi roll filled with marinated spiced paneer tandoori masala and crunchy onions.',
      imageUrl: '🌯',
      mrp: 96,
      price: 89,
      discount: 7,
      unit: '1 Roll',
      stock: 100,
      tags: ['cafe', 'frankie-rolls', 'kathi-roll'],
    },
    // Cold Coffee
    {
      name: 'Classic Cold Coffee',
      slug: 'classic-cold-coffee',
      description: 'Creamy and sweet chilled milk blended with rich coffee and ice cream.',
      imageUrl: '🧋',
      mrp: 89,
      price: 79,
      discount: 11,
      unit: '1 cup (250 ml)',
      stock: 80,
      tags: ['cafe', 'cold-coffee', 'popular'],
    },
    {
      name: 'Hazelnut Cold Coffee',
      slug: 'hazelnut-cold-coffee',
      description: 'Creamy cold coffee infused with rich aromatic hazelnut syrup.',
      imageUrl: '🧋',
      mrp: 99,
      price: 89,
      discount: 10,
      unit: '1 cup (250 ml)',
      stock: 80,
      tags: ['cafe', 'cold-coffee'],
    },
    // Mocktails
    {
      name: 'Virgin Mojito',
      slug: 'virgin-mojito',
      description: 'Refreshing carbonated cooler made with fresh mint leaves, lime juice, and simple syrup.',
      imageUrl: '🍹',
      mrp: 79,
      price: 69,
      discount: 12,
      unit: '1 glass (250 ml)',
      stock: 85,
      tags: ['cafe', 'mocktails', 'popular'],
    },
    {
      name: 'Blue Lagoon Cooler',
      slug: 'blue-lagoon-cooler',
      description: 'Vibrant blue citrus cooler blended with lemonade and carbonated club soda.',
      imageUrl: '🍹',
      mrp: 89,
      price: 79,
      discount: 11,
      unit: '1 glass (250 ml)',
      stock: 85,
      tags: ['cafe', 'mocktails'],
    },
    // Shakes
    {
      name: 'Chocolate Oreo Shake',
      slug: 'chocolate-oreo-shake',
      description: 'Thick creamy milkshake blended with vanilla ice cream, cocoa, and Oreo biscuit crumbles.',
      imageUrl: '🥤',
      mrp: 119,
      price: 99,
      discount: 16,
      unit: '1 cup (300 ml)',
      stock: 75,
      tags: ['cafe', 'shakes', 'popular'],
    },
    {
      name: 'Strawberry Shake',
      slug: 'strawberry-shake',
      description: 'Creamy thick shake blended with delicious sweet strawberries and fresh milk.',
      imageUrl: '🥤',
      mrp: 99,
      price: 89,
      discount: 10,
      unit: '1 cup (300 ml)',
      stock: 75,
      tags: ['cafe', 'shakes'],
    },
    // Pasta
    {
      name: 'Penne Arrabbiata (Red Sauce Pasta)',
      slug: 'penne-arrabbiata',
      description: 'Freshly cooked penne pasta tossed in a spicy garlic, tomato, and red chilli pepper sauce.',
      imageUrl: '🍝',
      mrp: 149,
      price: 129,
      discount: 13,
      unit: '1 plate',
      stock: 60,
      tags: ['cafe', 'italian-pasta', 'popular'],
    },
    {
      name: 'White Sauce Alfredo Pasta',
      slug: 'white-sauce-alfredo-pasta',
      description: 'Rich penne pasta tossed in a creamy, buttery white cheese sauce with herbs.',
      imageUrl: '🍝',
      mrp: 159,
      price: 139,
      discount: 12,
      unit: '1 plate',
      stock: 60,
      tags: ['cafe', 'italian-pasta'],
    },
    // Rice Dishes
    {
      name: 'Veg Fried Rice',
      slug: 'veg-fried-rice',
      description: 'Aromatic basmati rice stir-fried in a wok with fresh vegetables, garlic, and soy sauce.',
      imageUrl: '🍚',
      mrp: 129,
      price: 109,
      discount: 15,
      unit: '1 plate',
      stock: 70,
      tags: ['cafe', 'rice-dishes'],
    },
    {
      name: 'Paneer Biryani',
      slug: 'paneer-biryani',
      description: 'Slow-cooked aromatic basmati rice layered with spiced paneer cubes, caramelized onions, and saffron.',
      imageUrl: '🍚',
      mrp: 169,
      price: 149,
      discount: 11,
      unit: '1 plate',
      stock: 70,
      tags: ['cafe', 'rice-dishes', 'popular'],
    },
    // Bombay Bites
    {
      name: 'Bombay Vada Pav (2 pcs)',
      slug: 'bombay-vada-pav',
      description: 'Classic Mumbai street food! Deep-fried potato dumpling placed inside a sliced pav bread with spicy chutneys.',
      imageUrl: '🥪',
      mrp: 59,
      price: 49,
      discount: 16,
      unit: '1 plate (2 pavs)',
      stock: 120,
      tags: ['cafe', 'bombay-bites', 'popular'],
    },
    {
      name: 'Bombay Masala Toast',
      slug: 'bombay-masala-toast',
      description: 'Grilled sandwich stuffed with spiced mashed potato filling, cucumber, onions, tomatoes, and spicy coriander chutney.',
      imageUrl: '🥪',
      mrp: 69,
      price: 59,
      discount: 14,
      unit: '1 pc',
      stock: 100,
      tags: ['cafe', 'bombay-bites'],
    },
    // Chinese Cuisine
    {
      name: 'Veg Momos (6 pcs)',
      slug: 'veg-momos-6pcs',
      description: 'Steamed thin wrappers stuffed with minced cabbage, carrots, onion, and spices. Served with fire-hot red chilli garlic dip.',
      imageUrl: '🥟',
      mrp: 80,
      price: 69,
      discount: 13,
      unit: '1 plate (6 pcs)',
      stock: 90,
      tags: ['cafe', 'chinese', 'popular'],
    },
    {
      name: 'Chilli Garlic Noodles',
      slug: 'chilli-garlic-noodles',
      description: 'Stir-fried noodles cooked with lots of fresh garlic, red chillies, and assorted crunchy vegetables.',
      imageUrl: '🍜',
      mrp: 139,
      price: 119,
      discount: 14,
      unit: '1 plate',
      stock: 80,
      tags: ['cafe', 'chinese'],
    }
  ]

  // 2. Fetch all products under Cafe category or tagged with 'cafe'
  let dbCafeProducts: any[] = []
  try {
    dbCafeProducts = await prisma.product.findMany({
      where: {
        OR: [
          { categoryId: cafeCategory?.id || 'non-existent' },
          { tags: { has: 'cafe' } },
        ],
        isAvailable: true,
      },
      include: { category: true }
    })
  } catch (e) {
    console.warn('Database connection error in cafe page: failed to fetch cafe products')
  }

  // 3. Self-healing seeding: Ensure all new categories and products exist in the database individually
  if (cafeCategory) {
    let seededNewProduct = false
    for (const item of hotCafeProducts) {
      const exists = dbCafeProducts.some(p => p.slug === item.slug)
      if (!exists) {
        try {
          const existing = await prisma.product.findUnique({
            where: { slug: item.slug }
          })
          if (!existing) {
            console.info(`Seeding missing cafe product: ${item.name}`)
            await prisma.product.create({
              data: {
                name: item.name,
                slug: item.slug,
                description: item.description,
                imageUrl: item.imageUrl,
                categoryId: cafeCategory.id,
                mrp: item.mrp,
                price: item.price,
                discount: item.discount,
                unit: item.unit,
                stock: item.stock,
                isAvailable: true,
                tags: item.tags,
              }
            })
            seededNewProduct = true
          }
        } catch (err) {
          console.warn(`Database connection error in cafe page: failed to dynamically seed cafe product ${item.slug}`, err)
        }
      }
    }

    // Re-fetch after seeding if we seeded anything new
    if (seededNewProduct) {
      try {
        dbCafeProducts = await prisma.product.findMany({
          where: {
            OR: [
              { categoryId: cafeCategory.id },
              { tags: { has: 'cafe' } },
            ],
            isAvailable: true,
          },
          include: { category: true }
        })
      } catch (e) {
        console.warn('Database connection error in cafe page: failed to fetch cafe products after seeding')
      }
    }
  }

  return (
    <CafeStorefront initialProducts={dbCafeProducts} />
  )
}
