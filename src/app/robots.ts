import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastkirana.in'

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/',
          '/admin/',
          '/delivery/',
          '/chef/',
          '/picker/',
          '/cart',
          '/checkout',
          '/order/',
          '/account/',
          '/login',
          '/register',
        ],
      },
      {
        userAgent: 'Googlebot',
        allow: '/',
        disallow: [
          '/api/',
          '/admin/',
          '/delivery/',
          '/chef/',
          '/picker/',
          '/cart',
          '/checkout',
          '/order/',
          '/account/',
          '/login',
          '/register',
        ],
      },
      {
        userAgent: 'GPTBot',
        disallow: ['/api/', '/admin/', '/product/', '/category/', '/food/', '/search'],
      },
      {
        userAgent: 'PerplexityBot',
        disallow: ['/api/', '/admin/', '/product/', '/category/', '/food/', '/search'],
      },
      {
        userAgent: 'ClaudeBot',
        disallow: ['/api/', '/admin/', '/product/', '/category/', '/food/', '/search'],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  }
}
