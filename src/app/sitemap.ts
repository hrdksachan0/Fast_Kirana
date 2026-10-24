import { MetadataRoute } from 'next'
import { prisma } from '@/lib/prisma'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  // Strictly enforce fastminute.in so Google Search Console does not reject sitemap URLs
  const baseUrl = 'https://www.fastminute.in'

  // Static routes
  const staticRoutes: MetadataRoute.Sitemap = [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1.0,
    },
    {
      url: `${baseUrl}/category`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/food`,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.9,
    },
    {
      url: `${baseUrl}/about`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: `${baseUrl}/contact`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.5,
    },
    {
      url: `${baseUrl}/faq`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.5,
    },
    {
      url: `${baseUrl}/privacy-policy`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${baseUrl}/terms`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${baseUrl}/refund-policy`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
    {
      url: `${baseUrl}/shipping-policy`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.3,
    },
  ]

  try {
    // Dynamic Product Routes
    const products = await prisma.product.findMany({
      where: { isAvailable: true },
      select: { id: true, slug: true, updatedAt: true },
      take: 2000,
    })

    const productRoutes: MetadataRoute.Sitemap = products.map((prod) => ({
      url: `${baseUrl}/product/${prod.slug || prod.id}`,
      lastModified: prod.updatedAt || new Date(),
      changeFrequency: 'daily',
      priority: 0.85,
    }))

    // Dynamic Category Routes
    const categories = await prisma.category.findMany({
      select: { id: true, slug: true },
      take: 200,
    })

    const categoryRoutes: MetadataRoute.Sitemap = categories.map((cat) => ({
      url: `${baseUrl}/category/${cat.slug || cat.id}`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.8,
    }))

    // Dynamic Restaurant & Kitchen Routes
    const restaurants = await prisma.restaurant.findMany({
      where: { isActive: true },
      select: { id: true, slug: true, updatedAt: true },
      take: 100,
    })

    const restaurantRoutes: MetadataRoute.Sitemap = restaurants.map((rest) => ({
      url: `${baseUrl}/food/${rest.slug || rest.id}`,
      lastModified: rest.updatedAt || new Date(),
      changeFrequency: 'daily',
      priority: 0.85,
    }))

    return [...staticRoutes, ...restaurantRoutes, ...categoryRoutes, ...productRoutes]
  } catch (error) {
    console.error('Error generating sitemap:', error)
    return staticRoutes
  }
}
