import { prisma } from '../src/lib/prisma'

const PRODUCTS = [
  // CAFE
  { name: 'Cold Coffee', category: 'cafe', description: 'Rich cold brew coffee blended with milk and sugar — perfectly chilled.', imageUrl: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=600&q=80', mrp: 120, price: 99, unit: '300ml', stock: 50, tags: 'cafe,cold-coffee,hot-beverage', costPrice: 40 },
  { name: 'Masala Chai', category: 'cafe', description: 'Freshly brewed Indian spiced tea with ginger, cardamom, and cinnamon.', imageUrl: 'https://images.unsplash.com/photo-1567922045116-2a00fae2ed03?w=600&q=80', mrp: 60, price: 49, unit: '200ml', stock: 80, tags: 'cafe,chai,hot-beverage', costPrice: 15 },
  { name: 'Veg Club Sandwich', category: 'cafe', description: 'Triple-layered sandwich with fresh vegetables, cheese, and mayo.', imageUrl: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&q=80', mrp: 180, price: 149, unit: '1 piece', stock: 30, tags: 'cafe,sandwich,sandwiches,hot-bite', costPrice: 55 },
  { name: 'Cheese Burst Sandwich', category: 'cafe', description: 'Toasted sandwich loaded with melted cheese, capsicum, and jalapeños.', imageUrl: 'https://images.unsplash.com/photo-1554080353-a576cf803bda?w=600&q=80', mrp: 220, price: 189, unit: '1 piece', stock: 25, tags: 'cafe,sandwich,sandwiches', costPrice: 65 },
  { name: 'Paneer Frankie Roll', category: 'cafe', description: 'Soft roti rolled with spiced paneer bhurji, onion, and mint chutney.', imageUrl: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&q=80', mrp: 160, price: 129, unit: '1 roll', stock: 35, tags: 'cafe,frankie-rolls,snack', costPrice: 45 },
  { name: 'Veg Hakka Noodles', category: 'cafe', description: 'Stir-fried Hakka noodles with fresh vegetables and Indo-Chinese sauces.', imageUrl: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&q=80', mrp: 200, price: 169, unit: '1 plate', stock: 20, tags: 'cafe,chinese,hot-bite', costPrice: 60 },
  { name: 'Penne Arrabbiata', category: 'cafe', description: 'Al dente penne in a spicy tomato-garlic sauce, garnished with fresh basil.', imageUrl: 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=600&q=80', mrp: 250, price: 219, unit: '1 bowl', stock: 18, tags: 'cafe,pasta,italian-pasta', costPrice: 75 },
  { name: 'Vada Pav', category: 'cafe', description: 'Mumbai street-style crispy batata vada in a soft pav with dry garlic chutney.', imageUrl: 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80', mrp: 60, price: 49, unit: '1 piece', stock: 60, tags: 'cafe,bombay-bites,snack', costPrice: 18 },
  { name: 'Veg Pulao', category: 'cafe', description: 'Fragrant basmati rice cooked with mixed vegetables and aromatic whole spices.', imageUrl: 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=600&q=80', mrp: 180, price: 149, unit: '1 bowl', stock: 22, tags: 'cafe,rice-dishes,hot-bite', costPrice: 50 },
  { name: 'Mango Shake', category: 'cafe', description: 'Thick and creamy Alphonso mango milkshake, chilled and ready to sip.', imageUrl: 'https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&q=80', mrp: 130, price: 109, unit: '350ml', stock: 40, tags: 'cafe,shake,mango,hot-beverage', costPrice: 38 },
  { name: 'Pav Bhaji', category: 'cafe', description: 'Buttery spiced bhaji served with soft pav and dollop of butter.', imageUrl: 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=600&q=80', mrp: 150, price: 129, unit: '1 plate', stock: 28, tags: 'cafe,bombay-bites,hot-bite', costPrice: 48 },
  { name: 'Cappuccino', category: 'cafe', description: 'Classic Italian cappuccino with rich espresso, steamed milk, and foam art.', imageUrl: 'https://images.unsplash.com/photo-1572442388796-11668a67e53d?w=600&q=80', mrp: 150, price: 129, unit: '250ml', stock: 50, tags: 'cafe,coffee,hot-beverage,cappuccino', costPrice: 45 },
  // ICE CREAM
  { name: 'Chocolate Ice Cream', category: 'ice-cream', description: 'Rich Belgian chocolate ice cream with a creamy, smooth texture.', imageUrl: 'https://images.unsplash.com/photo-1563805042-7684c019e1cb?w=600&q=80', mrp: 80, price: 65, unit: '100ml', stock: 50, tags: 'ice-cream,chocolate,dessert', costPrice: 22 },
  { name: 'Mango Kulfi', category: 'ice-cream', description: 'Traditional Indian kulfi packed with real Alphonso mango pulp.', imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&q=80', mrp: 60, price: 49, unit: '80ml', stock: 70, tags: 'ice-cream,kulfi,mango,dessert', costPrice: 16 },
  { name: 'Vanilla Soft Serve', category: 'ice-cream', description: 'Classic creamy vanilla soft serve in a crispy waffle cone.', imageUrl: 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=600&q=80', mrp: 70, price: 59, unit: '1 cone', stock: 45, tags: 'ice-cream,vanilla,cone', costPrice: 18 },
  { name: 'Strawberry Ice Cream Cup', category: 'ice-cream', description: 'Fruity strawberry ice cream with real strawberry pieces.', imageUrl: 'https://images.unsplash.com/photo-1501443762994-82bd5dace89a?w=600&q=80', mrp: 75, price: 62, unit: '100ml', stock: 40, tags: 'ice-cream,strawberry,dessert', costPrice: 20 },
  { name: 'Choco Bar', category: 'ice-cream', description: 'Vanilla ice cream coated in a thick dark chocolate shell on a stick.', imageUrl: 'https://images.unsplash.com/photo-1488900128323-21503983a07e?w=600&q=80', mrp: 50, price: 40, unit: '1 bar', stock: 80, tags: 'ice-cream,bar,chocolate,dessert', costPrice: 14 },
  { name: 'Butterscotch Scoop', category: 'ice-cream', description: 'Golden butterscotch ice cream loaded with crunchy caramel brittle bits.', imageUrl: 'https://images.unsplash.com/photo-1560008581-09826d1de69e?w=600&q=80', mrp: 80, price: 69, unit: '120ml', stock: 35, tags: 'ice-cream,butterscotch,dessert', costPrice: 24 },
  { name: 'Kesar Pista Kulfi', category: 'ice-cream', description: 'Royal saffron and pistachio kulfi — a festive Indian frozen treat.', imageUrl: 'https://images.unsplash.com/photo-1587314168485-3236d6710814?w=600&q=80', mrp: 90, price: 75, unit: '100ml', stock: 30, tags: 'ice-cream,kulfi,kesar,dessert', costPrice: 28 },
  { name: 'Oreo Ice Cream Sandwich', category: 'ice-cream', description: 'Vanilla ice cream sandwiched between two real Oreo cookies.', imageUrl: 'https://images.unsplash.com/photo-1481391319762-47dff72954d9?w=600&q=80', mrp: 65, price: 55, unit: '1 piece', stock: 60, tags: 'ice-cream,oreo,sandwich,dessert', costPrice: 19 },
  // BEVERAGES
  { name: 'Coca-Cola 600ml', category: 'beverages', description: 'The classic refreshing cola — perfectly chilled and carbonated.', imageUrl: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=600&q=80', mrp: 45, price: 40, unit: '600ml', stock: 100, tags: 'beverages,cold-drinks,cola', costPrice: 25 },
  { name: 'Sprite 600ml', category: 'beverages', description: 'Crisp lemon-lime flavored carbonated soft drink.', imageUrl: 'https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=600&q=80', mrp: 45, price: 40, unit: '600ml', stock: 90, tags: 'beverages,cold-drinks,soda', costPrice: 25 },
  { name: 'Real Mango Juice 1L', category: 'beverages', description: 'Dabur Real fruit juice — no added preservatives, packed fresh.', imageUrl: 'https://images.unsplash.com/photo-1534353436294-0dbd4bdac845?w=600&q=80', mrp: 110, price: 95, unit: '1L', stock: 60, tags: 'beverages,juices,mango', costPrice: 55 },
  { name: 'Paper Boat Aam Panna', category: 'beverages', description: 'Traditional tangy-sweet raw mango drink with a hint of roasted cumin.', imageUrl: 'https://images.unsplash.com/photo-1622597467836-f3285f2131b8?w=600&q=80', mrp: 30, price: 25, unit: '250ml', stock: 80, tags: 'beverages,juices,mango', costPrice: 14 },
  { name: 'Red Bull Energy Drink', category: 'beverages', description: 'The original energy drink. Vitalizes body and mind.', imageUrl: 'https://images.unsplash.com/photo-1546171753-97d7676e4602?w=600&q=80', mrp: 130, price: 115, unit: '250ml', stock: 45, tags: 'beverages,energy-drink', costPrice: 75 },
  { name: 'Tropicana Orange Juice', category: 'beverages', description: '100% pure squeezed orange juice — no concentrate, no preservatives.', imageUrl: 'https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=600&q=80', mrp: 95, price: 82, unit: '1L', stock: 55, tags: 'beverages,juices,orange', costPrice: 50 },
  { name: 'Nescafe Classic 50g', category: 'beverages', description: 'Premium instant coffee powder — smooth, rich, and full-flavored.', imageUrl: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&q=80', mrp: 185, price: 165, unit: '50g', stock: 40, tags: 'beverages,tea-coffee,coffee', costPrice: 90 },
  { name: 'Frooti Mango Drink', category: 'beverages', description: 'Fun, sweet mango-flavored fruit drink — loved by all ages.', imageUrl: 'https://images.unsplash.com/photo-1534353436294-0dbd4bdac845?w=600&q=80', mrp: 20, price: 18, unit: '200ml', stock: 120, tags: 'beverages,juices,mango', costPrice: 10 },
  { name: 'Sweet Lassi', category: 'beverages', description: 'Chilled thick Punjabi sweet lassi made from fresh curd and sugar.', imageUrl: 'https://images.unsplash.com/photo-1553361371-9b22f78e8b1d?w=600&q=80', mrp: 80, price: 65, unit: '300ml', stock: 35, tags: 'beverages,lassi,dairy', costPrice: 25 },
  { name: 'Limca Soda 750ml', category: 'beverages', description: 'Tangy lemon-lime sparkling soft drink — great on a hot day.', imageUrl: 'https://images.unsplash.com/photo-1473657252935-de1e4f51f90f?w=600&q=80', mrp: 50, price: 42, unit: '750ml', stock: 75, tags: 'beverages,cold-drinks,soda,lemon', costPrice: 28 },
]

async function main() {
  const categories = await prisma.category.findMany({ select: { id: true, slug: true } })
  const catMap = new Map(categories.map(c => [c.slug, c.id]))
  let created = 0, skipped = 0
  for (const p of PRODUCTS) {
    const categoryId = catMap.get(p.category)
    if (!categoryId) { console.warn('No category: ' + p.category); skipped++; continue }
    const slug = p.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')
    const existing = await prisma.product.findUnique({ where: { slug } })
    if (existing) { console.log('Exists: ' + p.name); skipped++; continue }
    const discount = Math.round(((p.mrp - p.price) / p.mrp) * 100)
    await prisma.product.create({ data: { name: p.name, slug, description: p.description, imageUrl: p.imageUrl, categoryId, mrp: p.mrp, price: p.price, discount, unit: p.unit, stock: p.stock, isAvailable: true, tags: p.tags.split(',').map((t) => t.trim()), costPrice: p.costPrice, minStock: 10 } })
    console.log('Created: ' + p.name + ' (' + p.category + ')')
    created++
  }
  console.log('\nDone! Created: ' + created + ', Skipped: ' + skipped)
  await prisma.$disconnect()
}
main().catch(e => { console.error(e); prisma.$disconnect(); process.exit(1) })
