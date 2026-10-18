import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = 'https://www.fastminute.in'

  return {
    rules: [
      {
        userAgent: '*',
        allow: ['/', '/category/', '/product/', '/food/'],
        disallow: [
          '/api/',
          '/admin/',
          '/superadmin/',
          '/delivery/',
          '/chef/',
          '/picker/',
          '/cart',
          '/checkout',
          '/order/',
          '/account/',
          '/login',
          '/register',
          '/search',
          '/*?*',
        ],
      },
      {
        userAgent: 'Googlebot',
        allow: ['/', '/category/', '/product/', '/food/'],
        disallow: [
          '/api/',
          '/admin/',
          '/superadmin/',
          '/delivery/',
          '/chef/',
          '/picker/',
          '/cart',
          '/checkout',
          '/order/',
          '/account/',
          '/login',
          '/register',
          '/search',
          '/*?*sort=',
          '/*?*filter=',
          '/*?*storeId=',
        ],
      },
      {
        userAgent: ['GPTBot', 'ClaudeBot', 'CCBot', 'Bytespider', 'AhrefsBot', 'SemrushBot'],
        disallow: ['/'],
      },
    ],
    sitemap: [
      `${baseUrl}/sitemap.xml`,
      'https://fastminute.in/sitemap.xml',
    ],
  }
}
