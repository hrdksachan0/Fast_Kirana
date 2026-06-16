import { prisma } from '../src/lib/prisma'

const CAFE_PRODUCTS = [
  {
    name: 'Special Masala Chai',
    slug: 'special-masala-chai',
    description: 'Hot steaming milk tea brewed with fresh ginger, cardamom, and premium tea leaves.',
    imageUrl: '☕',
    mrp: 35,
    price: 30,
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
    unit: '1 pc',
    stock: 60,
    tags: ['cafe', 'sandwiches', 'hot-bite', 'breakfast', 'snacks'],
  },
  {
    name: 'Paneer Grilled Sandwich',
    slug: 'paneer-grilled-sandwich',
    description: 'Fresh grilled bread stuffed with spiced cottage cheese cubes, capsicum, onions, and spicy green mint chutney.',
    imageUrl: '🥪',
    mrp: 119,
    price: 99,
    unit: '1 pc',
    stock: 60,
    tags: ['cafe', 'sandwiches', 'popular'],
  },
  {
    name: 'Cheese Chilli Toast Sandwich',
    slug: 'cheese-chilli-toast-sandwich',
    description: 'Golden toasted bread slices loaded with chopped green chillies, capsicum, and melted cheddar and mozzarella cheese.',
    imageUrl: '🥪',
    mrp: 109,
    price: 89,
    unit: '1 pc',
    stock: 60,
    tags: ['cafe', 'sandwiches'],
  },
  {
    name: 'Veg Frankie Roll',
    slug: 'veg-frankie-roll',
    description: 'Golden-wrapped crispy roll with vegetable patty, fresh onions, spices and green mint chutney.',
    imageUrl: '🌯',
    mrp: 66,
    price: 59,
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
    unit: '1 Roll',
    stock: 100,
    tags: ['cafe', 'frankie-rolls', 'kathi-roll'],
  },
  {
    name: 'Classic Cold Coffee',
    slug: 'classic-cold-coffee',
    description: 'Creamy and sweet chilled milk blended with rich coffee and ice cream.',
    imageUrl: '🧋',
    mrp: 89,
    price: 79,
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
    unit: '1 cup (250 ml)',
    stock: 80,
    tags: ['cafe', 'cold-coffee'],
  },
  {
    name: 'Virgin Mojito',
    slug: 'virgin-mojito',
    description: 'Refreshing carbonated cooler made with fresh mint leaves, lime juice, and simple syrup.',
    imageUrl: '🍹',
    mrp: 79,
    price: 69,
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
    unit: '1 glass (250 ml)',
    stock: 85,
    tags: ['cafe', 'mocktails'],
  },
  {
    name: 'Chocolate Oreo Shake',
    slug: 'chocolate-oreo-shake',
    description: 'Thick creamy milkshake blended with vanilla ice cream, cocoa, and Oreo biscuit crumbles.',
    imageUrl: '🥤',
    mrp: 119,
    price: 99,
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
    unit: '1 cup (300 ml)',
    stock: 75,
    tags: ['cafe', 'shakes'],
  },
  {
    name: 'Penne Arrabbiata (Red Sauce Pasta)',
    slug: 'penne-arrabbiata',
    description: 'Freshly cooked penne pasta tossed in a spicy garlic, tomato, and red chilli pepper sauce.',
    imageUrl: '🍝',
    mrp: 149,
    price: 129,
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
    unit: '1 plate',
    stock: 60,
    tags: ['cafe', 'italian-pasta'],
  },
  {
    name: 'Veg Fried Rice',
    slug: 'veg-fried-rice',
    description: 'Aromatic basmati rice stir-fried in a wok with fresh vegetables, garlic, and soy sauce.',
    imageUrl: '🍚',
    mrp: 129,
    price: 109,
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
    unit: '1 plate',
    stock: 70,
    tags: ['cafe', 'rice-dishes', 'popular'],
  },
  {
    name: 'Bombay Vada Pav (2 pcs)',
    slug: 'bombay-vada-pav',
    description: 'Classic Mumbai street food! Deep-fried potato dumpling placed inside a sliced pav bread with spicy chutneys.',
    imageUrl: '🥪',
    mrp: 59,
    price: 49,
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
    unit: '1 pc',
    stock: 100,
    tags: ['cafe', 'bombay-bites'],
  },
  {
    name: 'Veg Momos (6 pcs)',
    slug: 'veg-momos-6pcs',
    description: 'Steamed thin wrappers stuffed with minced cabbage, carrots, onion, and spices. Served with fire-hot red chilli garlic dip.',
    imageUrl: '🥟',
    mrp: 80,
    price: 69,
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
    unit: '1 plate',
    stock: 80,
    tags: ['cafe', 'chinese'],
  }
]

async function main() {
  console.log('🌱 Starting Cafe products seeding...')
  
  // Find Cafe category id
  let cafeCategory = await prisma.category.findUnique({
    where: { slug: 'cafe' }
  })

  if (!cafeCategory) {
    console.log('Cafe category not found, creating it first...')
    cafeCategory = await prisma.category.create({
      data: {
        name: 'FastKirana Café',
        slug: 'cafe',
        imageUrl: '/cafe_category.png',
        sortOrder: 10
      }
    })
  }

  let created = 0
  let skipped = 0

  for (const item of CAFE_PRODUCTS) {
    const existing = await prisma.product.findUnique({
      where: { slug: item.slug }
    })

    if (existing) {
      console.log(`Product with slug "${item.slug}" already exists. Skipping.`)
      skipped++
    } else {
      const discount = item.mrp > item.price ? Math.max(0, Math.round(((item.mrp - item.price) / item.mrp) * 100)) : 0
      const costPrice = Math.round(item.price * 0.6)
      
      await prisma.product.create({
        data: {
          name: item.name,
          slug: item.slug,
          description: item.description,
          imageUrl: item.imageUrl,
          categoryId: cafeCategory.id,
          mrp: item.mrp,
          price: item.price,
          discount,
          unit: item.unit,
          stock: item.stock,
          isAvailable: true,
          tags: item.tags,
          costPrice,
          minStock: 10
        }
      })
      console.log(`Created Cafe Product: "${item.name}" (slug: "${item.slug}")`)
      created++
    }
  }

  console.log(`\n✅ Seeding complete! Created: ${created}, Skipped: ${skipped}`)
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
