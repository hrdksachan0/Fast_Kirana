import 'dotenv/config'
import { prisma } from '../src/lib/prisma'

const CLOUD_NAME = 'dvcsjvpbg'
const API_KEY = '923798735997129'
const API_SECRET = 'uZve5pFHquL3XxlgWx2K-i0jNig'

function normalize(str: string) {
  return str.toLowerCase().replace(/[^a-z0-9]/g, '')
}

async function main() {
  console.log('Fetching all Cloudinary images...')
  const auth = Buffer.from(API_KEY + ':' + API_SECRET).toString('base64')
  let allResources: any[] = []
  let nextCursor: string | undefined = undefined
  do {
    const url = 'https://api.cloudinary.com/v1_1/' + CLOUD_NAME + '/resources/image?max_results=500' + (nextCursor ? '&next_cursor=' + nextCursor : '')
    const res = await fetch(url, { headers: { Authorization: 'Basic ' + auth } })
    if (!res.ok) { const txt = await res.text(); throw new Error('Cloudinary error ' + res.status + ': ' + txt) }
    const data: any = await res.json()
    allResources = allResources.concat(data.resources || [])
    nextCursor = data.next_cursor
  } while (nextCursor)

  console.log('Found ' + allResources.length + ' images in Cloudinary')
  allResources.forEach((img: any) => console.log(' -', img.public_id, '|', img.secure_url))

  const products = await prisma.product.findMany({ select: { id: true, name: true, slug: true, imageUrl: true }, orderBy: { name: 'asc' } })
  console.log('\nTotal products: ' + products.length + '. Matching...')

  let updated = 0, skipped = 0, noMatch = 0
  for (const product of products) {
    if (product.imageUrl && product.imageUrl.includes('cloudinary.com')) { skipped++; continue }
    const productNorm = normalize(product.name)
    const slugNorm = normalize(product.slug)
    const match = allResources.find((img: any) => {
      const pubId = normalize(img.public_id)
      return pubId.includes(productNorm) || pubId.includes(slugNorm) || productNorm.includes(pubId) || slugNorm.includes(pubId)
    })
    if (match) {
      await prisma.product.update({ where: { id: product.id }, data: { imageUrl: match.secure_url } })
      console.log('Updated: ' + product.name + ' -> ' + match.secure_url.substring(0, 70))
      updated++
    } else {
      console.log('No match: ' + product.name)
      noMatch++
    }
  }

  console.log('\nDone! Updated: ' + updated + ', Already Cloudinary: ' + skipped + ', No match: ' + noMatch)

  await prisma.storeSetting.upsert({ where: { key: 'cloudinary_api_key' }, create: { key: 'cloudinary_api_key', value: API_KEY }, update: { value: API_KEY } })
  await prisma.storeSetting.upsert({ where: { key: 'cloudinary_api_secret' }, create: { key: 'cloudinary_api_secret', value: API_SECRET }, update: { value: API_SECRET } })
  console.log('Credentials saved to Store Settings!')
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1) })
