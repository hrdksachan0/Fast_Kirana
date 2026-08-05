const { PrismaClient } = require('@prisma/client')
const p = new PrismaClient()

async function main() {
  const bevIce = await p.product.findMany({
    where: { isAvailable: true, category: { slug: { in: ['beverages', 'ice-cream'] } } },
    select: { id: true, name: true, restaurantId: true, category: { select: { slug: true } } }
  })
  console.log('Total bev+ice:', bevIce.length)
  bevIce.slice(0, 5).forEach(x => console.log(' ', x.name, x.category?.slug, x.restaurantId))

  const best = await p.product.findMany({
    where: {
      isAvailable: true,
      OR: [
        {
          restaurantId: null,
          NOT: [
            { tags: { has: 'restaurant' } },
            { category: { slug: { in: ['restaurant', 'fastkirana-restaurant', 'cafe', 'fastkirana-cafe'] } } }
          ]
        },
        { category: { slug: { in: ['beverages', 'ice-cream'] } } }
      ]
    },
    take: 400,
    select: { id: true, name: true, category: { select: { slug: true } } }
  })
  const b = best.filter(x => x.category?.slug === 'beverages')
  const i = best.filter(x => x.category?.slug === 'ice-cream')
  console.log('BestSellers total:', best.length, 'Bev:', b.length, 'Ice:', i.length)
  if (b.length > 0) console.log('  Sample bev:', b[0].name)
  if (i.length > 0) console.log('  Sample ice:', i[0].name)

  await p.$disconnect()
}

main().catch(e => { console.error(e); p.$disconnect() })
