import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'
import bcrypt from 'bcryptjs'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
  console.log('🌱 Seeding database...')

  // Clear existing data
  await prisma.review.deleteMany()
  await prisma.orderItem.deleteMany()
  await prisma.order.deleteMany()
  await prisma.cartItem.deleteMany()
  await prisma.cart.deleteMany()
  await prisma.productImage.deleteMany()
  await prisma.product.deleteMany()
  await prisma.category.deleteMany()
  await prisma.address.deleteMany()
  await prisma.session.deleteMany()
  await prisma.account.deleteMany()
  await prisma.verificationToken.deleteMany()
  await prisma.coupon.deleteMany()
  await prisma.user.deleteMany()

  // Create users
  const adminHash = await bcrypt.hash('admin123', 12)
  const userHash = await bcrypt.hash('user123', 12)
  const deliveryHash = await bcrypt.hash('delivery123', 12)
  const chefHash = await bcrypt.hash('chef123', 12)
  const pickerHash = await bcrypt.hash('picker123', 12)

  const admin = await prisma.user.create({
    data: {
      name: 'Admin',
      email: 'admin@fastkirana.com',
      passwordHash: adminHash,
      role: 'ADMIN',
      phone: '+919876543210',
    },
  })

  const chef = await prisma.user.create({
    data: {
      name: 'Chef Kitchener',
      email: 'chef@fastkirana.com',
      passwordHash: chefHash,
      role: 'CHEF',
      phone: '+919900112233',
    },
  })

  const picker = await prisma.user.create({
    data: {
      name: 'Suresh Picker',
      email: 'picker@fastkirana.com',
      passwordHash: pickerHash,
      role: 'PICKER',
      phone: '+919800001122',
    },
  })

  const delivery = await prisma.user.create({
    data: {
      name: 'Ramesh Rider',
      email: 'delivery@fastkirana.com',
      passwordHash: deliveryHash,
      role: 'DELIVERY',
      phone: '+919988776655',
    },
  })

  const user = await prisma.user.create({
    data: {
      name: 'Rahul Sharma',
      email: 'user@fastkirana.com',
      passwordHash: userHash,
      role: 'USER',
      phone: '+919123456789',
      addresses: {
        create: {
          label: 'Home',
          houseNo: '42-B',
          street: 'MG Road',
          area: 'Koramangala',
          city: 'Bangalore',
          pincode: '560034',
          phone: '+919123456789',
          isDefault: true,
        },
      },
    },
  })

  // Create categories
  const categories = await Promise.all([
    prisma.category.create({ data: { name: 'Fruits & Vegetables', slug: 'fruits-vegetables', imageUrl: '🥬', sortOrder: 1 } }),
    prisma.category.create({ data: { name: 'Dairy & Breakfast', slug: 'dairy-breakfast', imageUrl: '🥛', sortOrder: 2 } }),
    prisma.category.create({ data: { name: 'Snacks & Munchies', slug: 'snacks-munchies', imageUrl: '🍿', sortOrder: 3 } }),
    prisma.category.create({ data: { name: 'Beverages', slug: 'beverages', imageUrl: '🥤', sortOrder: 4 } }),
    prisma.category.create({ data: { name: 'Personal Care', slug: 'personal-care', imageUrl: '🧴', sortOrder: 5 } }),
    prisma.category.create({ data: { name: 'Household', slug: 'household', imageUrl: '🏠', sortOrder: 6 } }),
    prisma.category.create({ data: { name: 'Bakery & Biscuits', slug: 'bakery-biscuits', imageUrl: '🍞', sortOrder: 7 } }),
    prisma.category.create({ data: { name: 'Atta, Rice & Dal', slug: 'atta-rice-dal', imageUrl: '🌾', sortOrder: 8 } }),
  ])

  const [fruits, dairy, snacks, beverages, personalCare, household, bakery, staples] = categories

  // Products - Fruits & Vegetables (10)
  const fruitsProducts = [
    { name: 'Banana - Robusta', slug: 'banana-robusta', unit: '1 dozen', mrp: 49, price: 39, discount: 20, stock: 200, tags: ['fresh', 'popular'], description: 'Fresh yellow bananas, perfect for daily consumption. Rich in potassium and natural energy.' },
    { name: 'Apple - Shimla', slug: 'apple-shimla', unit: '1 kg', mrp: 199, price: 169, discount: 15, stock: 80, tags: ['fresh', 'premium'], description: 'Crisp and juicy Shimla apples. Handpicked from Himachal Pradesh orchards.' },
    { name: 'Onion', slug: 'onion', unit: '1 kg', mrp: 40, price: 35, discount: 12, stock: 300, tags: ['essential', 'cooking'], description: 'Fresh red onions, essential for Indian cooking. Farm fresh quality.' },
    { name: 'Tomato - Local', slug: 'tomato-local', unit: '1 kg', mrp: 45, price: 38, discount: 15, stock: 250, tags: ['fresh', 'cooking'], description: 'Ripe red tomatoes, locally sourced. Perfect for curries and salads.' },
    { name: 'Potato', slug: 'potato', unit: '1 kg', mrp: 35, price: 30, discount: 14, stock: 400, tags: ['essential', 'staple'], description: 'Fresh potatoes, versatile for all Indian dishes.' },
    { name: 'Green Chilli', slug: 'green-chilli', unit: '100 g', mrp: 15, price: 12, discount: 20, stock: 150, tags: ['spicy', 'cooking'], description: 'Fresh green chillies for that perfect kick in your food.' },
    { name: 'Coriander Leaves', slug: 'coriander-leaves', unit: '1 bunch', mrp: 15, price: 10, discount: 33, stock: 120, tags: ['fresh', 'garnish'], description: 'Fresh coriander leaves for garnishing and chutney.' },
    { name: 'Cucumber', slug: 'cucumber', unit: '500 g', mrp: 30, price: 25, discount: 16, stock: 180, tags: ['fresh', 'salad'], description: 'Cool and crisp cucumbers, perfect for salads and raita.' },
    { name: 'Mango - Alphonso', slug: 'mango-alphonso', unit: '1 kg', mrp: 499, price: 399, discount: 20, stock: 50, tags: ['seasonal', 'premium'], description: 'King of fruits! Premium Alphonso mangoes from Ratnagiri.' },
    { name: 'Lemon', slug: 'lemon', unit: '4 pcs', mrp: 20, price: 16, discount: 20, stock: 200, tags: ['fresh', 'essential'], description: 'Fresh lemons, perfect for nimbu pani and cooking.' },
  ]

  // Products - Dairy & Breakfast (10)
  const dairyProducts = [
    { name: 'Amul Toned Milk', slug: 'amul-toned-milk', unit: '1 L', mrp: 56, price: 54, discount: 3, stock: 200, tags: ['dairy', 'daily'], description: 'Amul toned milk, pasteurized and fresh. Perfect for tea and daily use.' },
    { name: 'Amul Butter', slug: 'amul-butter', unit: '500 g', mrp: 270, price: 255, discount: 5, stock: 100, tags: ['dairy', 'popular'], description: 'Utterly butterly delicious! India\'s favorite butter.' },
    { name: 'Amul Cheese Slices', slug: 'amul-cheese-slices', unit: '200 g', mrp: 120, price: 110, discount: 8, stock: 90, tags: ['dairy', 'snack'], description: 'Processed cheese slices, perfect for sandwiches and burgers.' },
    { name: 'Mother Dairy Curd', slug: 'mother-dairy-curd', unit: '400 g', mrp: 40, price: 38, discount: 5, stock: 150, tags: ['dairy', 'daily'], description: 'Thick and creamy curd, freshly set. Great for raita.' },
    { name: 'Eggs - Farm Fresh', slug: 'eggs-farm-fresh', unit: '12 pcs', mrp: 84, price: 72, discount: 14, stock: 120, tags: ['protein', 'breakfast'], description: 'Farm fresh eggs, rich in protein. Brown and white mixed.' },
    { name: 'Paneer - Fresh', slug: 'paneer-fresh', unit: '200 g', mrp: 90, price: 80, discount: 11, stock: 80, tags: ['dairy', 'protein'], description: 'Soft and fresh cottage cheese, made from pure milk.' },
    { name: 'Amul Taaza Milk', slug: 'amul-taaza-milk', unit: '500 ml', mrp: 27, price: 27, discount: 0, stock: 300, tags: ['dairy', 'daily'], description: 'Homogenized toned milk, UHT processed for longer freshness.' },
    { name: 'Bread - White', slug: 'bread-white', unit: '400 g', mrp: 40, price: 35, discount: 12, stock: 100, tags: ['breakfast', 'daily'], description: 'Soft white bread, perfect for sandwiches and toast.' },
    { name: 'Kellogg\'s Corn Flakes', slug: 'kelloggs-corn-flakes', unit: '475 g', mrp: 230, price: 199, discount: 13, stock: 60, tags: ['breakfast', 'cereal'], description: 'Crunchy corn flakes, the original breakfast cereal.' },
    { name: 'Amul Ghee', slug: 'amul-ghee', unit: '1 L', mrp: 680, price: 630, discount: 7, stock: 70, tags: ['dairy', 'cooking'], description: 'Pure cow ghee, rich aroma. Essential for Indian cooking.' },
  ]

  // Products - Snacks (10)
  const snacksProducts = [
    { name: 'Lay\'s Classic Salted', slug: 'lays-classic-salted', unit: '130 g', mrp: 40, price: 38, discount: 5, stock: 200, tags: ['chips', 'popular'], description: 'India\'s favorite potato chips. Crispy, crunchy, and lightly salted.' },
    { name: 'Kurkure Masala Munch', slug: 'kurkure-masala-munch', unit: '115 g', mrp: 30, price: 28, discount: 6, stock: 180, tags: ['namkeen', 'popular'], description: 'Tedha hai par mera hai! Crunchy namkeen with masala flavor.' },
    { name: 'Haldiram\'s Aloo Bhujia', slug: 'haldirams-aloo-bhujia', unit: '400 g', mrp: 120, price: 105, discount: 12, stock: 100, tags: ['namkeen', 'traditional'], description: 'Classic aloo bhujia from Haldiram\'s. Perfect tea-time snack.' },
    { name: 'Cadbury Dairy Milk', slug: 'cadbury-dairy-milk', unit: '110 g', mrp: 99, price: 92, discount: 7, stock: 150, tags: ['chocolate', 'popular'], description: 'Kuch meetha ho jaaye! Silky smooth milk chocolate.' },
    { name: '5 Star Chocolate', slug: '5-star-chocolate', unit: '40 g', mrp: 30, price: 28, discount: 6, stock: 200, tags: ['chocolate', 'snack'], description: 'Chewy caramel nougat covered in milk chocolate.' },
    { name: 'Bikaji Bhujia', slug: 'bikaji-bhujia', unit: '200 g', mrp: 65, price: 58, discount: 10, stock: 120, tags: ['namkeen', 'traditional'], description: 'Authentic Bikaner style bhujia. Thin, crispy, and flavorful.' },
    { name: 'Maggi 2-Minute Noodles', slug: 'maggi-noodles', unit: '280 g (4-pack)', mrp: 56, price: 52, discount: 7, stock: 250, tags: ['instant', 'popular'], description: 'India\'s favorite instant noodles. Ready in 2 minutes.' },
    { name: 'Oreo Biscuits', slug: 'oreo-biscuits', unit: '120 g', mrp: 30, price: 28, discount: 6, stock: 180, tags: ['biscuit', 'chocolate'], description: 'Twist, lick, and dunk! Chocolate sandwich cookies with cream.' },
    { name: 'Pringles Original', slug: 'pringles-original', unit: '134 g', mrp: 199, price: 175, discount: 12, stock: 80, tags: ['chips', 'premium'], description: 'Once you pop, you can\'t stop! Perfectly shaped potato crisps.' },
    { name: 'Dark Fantasy Choco Fills', slug: 'dark-fantasy-choco-fills', unit: '300 g', mrp: 150, price: 135, discount: 10, stock: 90, tags: ['biscuit', 'premium'], description: 'Premium chocolate-filled cookies. Irresistibly indulgent.' },
  ]

  // Products - Beverages (10)
  const beveragesProducts = [
    { name: 'Coca-Cola', slug: 'coca-cola', unit: '750 ml', mrp: 40, price: 38, discount: 5, stock: 300, tags: ['cold-drink', 'popular'], description: 'Thanda matlab Coca-Cola! Refreshing carbonated beverage.' },
    { name: 'Tata Tea Gold', slug: 'tata-tea-gold', unit: '500 g', mrp: 270, price: 249, discount: 7, stock: 100, tags: ['tea', 'daily'], description: 'Premium blend of 15% long leaf for a perfect cup of chai.' },
    { name: 'Nescafe Classic', slug: 'nescafe-classic', unit: '200 g', mrp: 450, price: 399, discount: 11, stock: 80, tags: ['coffee', 'popular'], description: 'It all starts with a Nescafe! Instant coffee granules.' },
    { name: 'Real Fruit Juice - Mango', slug: 'real-mango-juice', unit: '1 L', mrp: 110, price: 99, discount: 10, stock: 120, tags: ['juice', 'mango'], description: 'Real mango juice made from Alphonso mangoes. No added preservatives.' },
    { name: 'Paper Boat Aam Panna', slug: 'paper-boat-aam-panna', unit: '250 ml', mrp: 30, price: 27, discount: 10, stock: 150, tags: ['desi', 'summer'], description: 'Drinks and memories! Traditional aam panna made with raw mangoes.' },
    { name: 'Sprite', slug: 'sprite', unit: '750 ml', mrp: 40, price: 38, discount: 5, stock: 250, tags: ['cold-drink', 'popular'], description: 'Clear hai! Refreshing lemon-lime flavored drink.' },
    { name: 'Bisleri Water', slug: 'bisleri-water', unit: '1 L', mrp: 20, price: 20, discount: 0, stock: 500, tags: ['water', 'essential'], description: 'India\'s trusted mineral water brand. Pure and safe drinking water.' },
    { name: 'Red Bull Energy Drink', slug: 'red-bull-energy', unit: '250 ml', mrp: 115, price: 110, discount: 4, stock: 80, tags: ['energy', 'premium'], description: 'Red Bull gives you wings! Energy drink with caffeine and taurine.' },
    { name: 'Frooti Mango Drink', slug: 'frooti-mango', unit: '600 ml', mrp: 30, price: 28, discount: 6, stock: 200, tags: ['juice', 'popular'], description: 'Mango Frooti, fresh and juicy! Everyone\'s favorite mango drink.' },
    { name: 'Thumbs Up', slug: 'thumbs-up', unit: '750 ml', mrp: 40, price: 38, discount: 5, stock: 250, tags: ['cold-drink', 'popular'], description: 'Taste the thunder! Strong cola flavor that packs a punch.' },
  ]

  // Products - Personal Care (10)
  const personalCareProducts = [
    { name: 'Dove Soap', slug: 'dove-soap', unit: '100 g', mrp: 55, price: 49, discount: 10, stock: 200, tags: ['soap', 'popular'], description: 'Dove beauty bar with 1/4 moisturizing cream. Soft, smooth skin.' },
    { name: 'Colgate MaxFresh', slug: 'colgate-maxfresh', unit: '150 g', mrp: 100, price: 89, discount: 11, stock: 150, tags: ['toothpaste', 'daily'], description: 'Cooling crystals for fresh breath all day. Cavity protection toothpaste.' },
    { name: 'Head & Shoulders Shampoo', slug: 'head-shoulders-shampoo', unit: '340 ml', mrp: 350, price: 315, discount: 10, stock: 90, tags: ['shampoo', 'popular'], description: 'Anti-dandruff shampoo for clean and healthy scalp.' },
    { name: 'Dettol Handwash', slug: 'dettol-handwash', unit: '200 ml', mrp: 99, price: 89, discount: 10, stock: 180, tags: ['hygiene', 'essential'], description: 'Trusted germ protection. Original liquid handwash.' },
    { name: 'Vaseline Body Lotion', slug: 'vaseline-body-lotion', unit: '200 ml', mrp: 199, price: 175, discount: 12, stock: 100, tags: ['skincare', 'popular'], description: 'Intensive care body lotion for deep moisturization.' },
    { name: 'Nivea Deo Roll On', slug: 'nivea-deo-roll-on', unit: '50 ml', mrp: 210, price: 189, discount: 10, stock: 120, tags: ['deo', 'personal'], description: '48-hour protection with care for underarm skin.' },
    { name: 'Gillette Guard Razor', slug: 'gillette-guard-razor', unit: '1 pc', mrp: 55, price: 49, discount: 10, stock: 100, tags: ['shaving', 'men'], description: 'Comfortable close shave with safety guard. India\'s best razor.' },
    { name: 'Whisper Ultra Clean', slug: 'whisper-ultra-clean', unit: '30 pads', mrp: 199, price: 179, discount: 10, stock: 80, tags: ['feminine', 'hygiene'], description: 'Ultra soft top sheet for comfort and dryness.' },
    { name: 'Himalaya Face Wash', slug: 'himalaya-face-wash', unit: '150 ml', mrp: 175, price: 155, discount: 11, stock: 90, tags: ['skincare', 'herbal'], description: 'Neem face wash for pimple-free, clear skin. Herbal formulation.' },
    { name: 'Parachute Coconut Oil', slug: 'parachute-coconut-oil', unit: '250 ml', mrp: 115, price: 105, discount: 8, stock: 130, tags: ['hair', 'oil'], description: '100% pure coconut oil for strong and beautiful hair.' },
  ]

  // Products - Household (10)
  const householdProducts = [
    { name: 'Vim Dishwash Bar', slug: 'vim-dishwash-bar', unit: '500 g', mrp: 42, price: 38, discount: 9, stock: 200, tags: ['cleaning', 'daily'], description: 'Tough on grease, gentle on hands. India\'s #1 dishwash bar.' },
    { name: 'Surf Excel Easy Wash', slug: 'surf-excel-easy-wash', unit: '1.5 kg', mrp: 210, price: 189, discount: 10, stock: 100, tags: ['detergent', 'popular'], description: 'Daag ache hain! Superior stain removal detergent powder.' },
    { name: 'Harpic Toilet Cleaner', slug: 'harpic-toilet-cleaner', unit: '500 ml', mrp: 95, price: 85, discount: 10, stock: 120, tags: ['cleaning', 'toilet'], description: '10x better cleaning power. Kills 99.9% germs.' },
    { name: 'Lizol Floor Cleaner', slug: 'lizol-floor-cleaner', unit: '975 ml', mrp: 199, price: 175, discount: 12, stock: 90, tags: ['cleaning', 'floor'], description: 'Citrus fresh floor cleaner for sparkling clean floors.' },
    { name: 'Good Knight Liquid', slug: 'good-knight-liquid', unit: '45 ml', mrp: 74, price: 68, discount: 8, stock: 150, tags: ['mosquito', 'essential'], description: 'Mosquito repellent liquid vaporizer. 60 nights protection.' },
    { name: 'Garbage Bags', slug: 'garbage-bags', unit: '30 pcs', mrp: 99, price: 85, discount: 14, stock: 200, tags: ['household', 'essential'], description: 'Medium-size biodegradable garbage bags. Strong and leak-proof.' },
    { name: 'Scotch-Brite Scrub Pad', slug: 'scotch-brite-scrub', unit: '3 pcs', mrp: 45, price: 40, discount: 11, stock: 180, tags: ['cleaning', 'kitchen'], description: 'Heavy duty scrub pad for tough stains. Lasts 2x longer.' },
    { name: 'Parchute Room Freshener', slug: 'room-freshener', unit: '240 ml', mrp: 160, price: 140, discount: 12, stock: 80, tags: ['freshener', 'home'], description: 'Long-lasting lavender fragrance for a fresh-smelling home.' },
    { name: 'Colin Glass Cleaner', slug: 'colin-glass-cleaner', unit: '500 ml', mrp: 120, price: 105, discount: 12, stock: 100, tags: ['cleaning', 'glass'], description: 'Streak-free shine for windows and glass surfaces.' },
    { name: 'Aluminium Foil', slug: 'aluminium-foil', unit: '9 m', mrp: 85, price: 75, discount: 11, stock: 150, tags: ['kitchen', 'wrapping'], description: 'Food-grade aluminium foil for wrapping, baking, and storing.' },
  ]

  // Products - Bakery & Biscuits (10)
  const bakeryProducts = [
    { name: 'Parle-G Biscuits', slug: 'parle-g-biscuits', unit: '800 g', mrp: 80, price: 72, discount: 10, stock: 250, tags: ['biscuit', 'popular'], description: 'India\'s most loved glucose biscuit. G for Genius!' },
    { name: 'Britannia Good Day', slug: 'britannia-good-day', unit: '250 g', mrp: 55, price: 49, discount: 10, stock: 150, tags: ['biscuit', 'cookies'], description: 'Butter cookies that make every day a good day.' },
    { name: 'Marie Gold Biscuits', slug: 'marie-gold-biscuits', unit: '250 g', mrp: 35, price: 32, discount: 8, stock: 200, tags: ['biscuit', 'light'], description: 'Light and crispy Marie biscuits. Perfect with tea.' },
    { name: 'Britannia Cake Rusk', slug: 'britannia-cake-rusk', unit: '300 g', mrp: 60, price: 55, discount: 8, stock: 100, tags: ['rusk', 'tea-time'], description: 'Toasted cake rusk, great for dipping in chai.' },
    { name: 'Pav - Fresh', slug: 'pav-fresh', unit: '6 pcs', mrp: 30, price: 25, discount: 16, stock: 80, tags: ['bread', 'fresh'], description: 'Soft and fluffy pav buns. Perfect for pav bhaji and vada pav.' },
    { name: 'Milk Bread', slug: 'milk-bread', unit: '400 g', mrp: 45, price: 40, discount: 11, stock: 90, tags: ['bread', 'daily'], description: 'Enriched milk bread, soft and nutritious for the family.' },
    { name: 'Croissant - Butter', slug: 'croissant-butter', unit: '2 pcs', mrp: 80, price: 70, discount: 12, stock: 50, tags: ['bakery', 'premium'], description: 'Flaky, buttery croissants. Freshly baked golden perfection.' },
    { name: 'Bourbon Biscuits', slug: 'bourbon-biscuits', unit: '150 g', mrp: 30, price: 27, discount: 10, stock: 180, tags: ['biscuit', 'chocolate'], description: 'Chocolate cream-filled biscuits. A classic favorite.' },
    { name: 'Jim Jam Biscuits', slug: 'jim-jam-biscuits', unit: '150 g', mrp: 30, price: 27, discount: 10, stock: 170, tags: ['biscuit', 'cream'], description: 'Treat jim jam! Cream-filled biscuits kids love.' },
    { name: 'Muffin - Chocolate', slug: 'muffin-chocolate', unit: '2 pcs', mrp: 90, price: 79, discount: 12, stock: 40, tags: ['bakery', 'premium'], description: 'Rich chocolate muffins, soft and fluffy with chocolate chips.' },
  ]

  // Products - Atta, Rice & Dal (10)
  const staplesProducts = [
    { name: 'Aashirvaad Atta', slug: 'aashirvaad-atta', unit: '5 kg', mrp: 295, price: 265, discount: 10, stock: 80, tags: ['atta', 'staple'], description: 'India\'s best whole wheat atta. Soft rotis guaranteed.' },
    { name: 'India Gate Basmati Rice', slug: 'india-gate-basmati', unit: '5 kg', mrp: 499, price: 449, discount: 10, stock: 60, tags: ['rice', 'premium'], description: 'Long grain basmati rice. Aged for extra flavor and aroma.' },
    { name: 'Toor Dal', slug: 'toor-dal', unit: '1 kg', mrp: 160, price: 142, discount: 11, stock: 120, tags: ['dal', 'staple'], description: 'Premium quality toor dal. Cooks perfectly every time.' },
    { name: 'Moong Dal', slug: 'moong-dal', unit: '1 kg', mrp: 140, price: 125, discount: 10, stock: 100, tags: ['dal', 'protein'], description: 'Yellow moong dal, high in protein. Makes delicious khichdi.' },
    { name: 'Fortune Sunflower Oil', slug: 'fortune-sunflower-oil', unit: '1 L', mrp: 145, price: 130, discount: 10, stock: 100, tags: ['oil', 'cooking'], description: 'Light and healthy sunflower cooking oil. Rich in Vitamin E.' },
    { name: 'MDH Garam Masala', slug: 'mdh-garam-masala', unit: '100 g', mrp: 72, price: 65, discount: 9, stock: 150, tags: ['spice', 'essential'], description: 'Asli masala sach sach! Blend of 13 premium spices.' },
    { name: 'Saffola Gold Oil', slug: 'saffola-gold-oil', unit: '1 L', mrp: 189, price: 169, discount: 10, stock: 80, tags: ['oil', 'healthy'], description: 'Heart-healthy blended cooking oil with oryzanol.' },
    { name: 'Sugar', slug: 'sugar', unit: '1 kg', mrp: 48, price: 42, discount: 12, stock: 200, tags: ['staple', 'essential'], description: 'Refined white sugar, sulphur-free. Essential kitchen staple.' },
    { name: 'Salt - Tata', slug: 'tata-salt', unit: '1 kg', mrp: 24, price: 22, discount: 8, stock: 300, tags: ['salt', 'essential'], description: 'Desh ka namak! Vacuum evaporated iodized salt.' },
    { name: 'Chana Dal', slug: 'chana-dal', unit: '1 kg', mrp: 120, price: 108, discount: 10, stock: 110, tags: ['dal', 'cooking'], description: 'Split chickpea lentils. Versatile dal for multiple dishes.' },
  ]

  // Helper to create products for a category
  async function createProducts(products: any[], categoryId: string) {
    for (const p of products) {
      await prisma.product.create({
        data: {
          name: p.name,
          slug: p.slug,
          description: p.description,
          imageUrl: `/products/${p.slug}.png`,
          categoryId,
          mrp: p.mrp,
          price: p.price,
          discount: p.discount,
          unit: p.unit,
          stock: p.stock,
          isAvailable: true,
          tags: p.tags,
        },
      })
    }
  }

  await createProducts(fruitsProducts, fruits.id)
  await createProducts(dairyProducts, dairy.id)
  await createProducts(snacksProducts, snacks.id)
  await createProducts(beveragesProducts, beverages.id)
  await createProducts(personalCareProducts, personalCare.id)
  await createProducts(householdProducts, household.id)
  await createProducts(bakeryProducts, bakery.id)
  await createProducts(staplesProducts, staples.id)

  // Create coupons
  await prisma.coupon.createMany({
    data: [
      { code: 'WELCOME50', discountType: 'PERCENT', value: 50, minOrder: 199, maxDiscount: 100, maxUses: 1000, isActive: true },
      { code: 'FLAT100', discountType: 'FLAT', value: 100, minOrder: 499, maxUses: 500, isActive: true },
      { code: 'SAVE20', discountType: 'PERCENT', value: 20, minOrder: 299, maxDiscount: 150, maxUses: 2000, isActive: true },
      { code: 'FIRST10', discountType: 'FLAT', value: 10, minOrder: 99, maxUses: 5000, isActive: true },
      { code: 'MEGA200', discountType: 'FLAT', value: 200, minOrder: 999, maxUses: 100, isActive: true },
    ],
  })

  console.log('✅ Seeded 8 categories, 80 products, 5 users (admin, user, delivery, chef, picker), 5 coupons')
}

main()
  .then(async () => await prisma.$disconnect())
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
