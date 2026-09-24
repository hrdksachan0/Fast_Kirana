import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  compress: true,
  reactStrictMode: true,
  output: 'standalone',
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production' ? { exclude: ['error', 'warn'] } : false,
  },
  experimental: {
    optimizePackageImports: ['lucide-react', 'date-fns', 'framer-motion', '@base-ui/react', 'sonner', 'clsx', 'tailwind-merge'],
    staleTimes: {
      dynamic: 30,
      static: 300,
    },
  },
  images: {
    unoptimized: process.env.NODE_ENV === 'development',
    minimumCacheTTL: 2592000,
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'res.cloudinary.com',
      },
      {
        protocol: 'https',
        hostname: 'bberzasmxwioxjynbuaf.supabase.co',
      },
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: 'lh3.googleusercontent.com',
      },
      {
        protocol: 'https',
        hostname: 'avatars.githubusercontent.com',
      },
      {
        protocol: 'https',
        hostname: 'www.fastkirana.in',
      },
    ],
  },
  async redirects() {
    return [
      {
        source: '/:path*',
        has: [
          {
            type: 'host',
            value: 'fast-kirana-gtm.vercel.app',
          },
        ],
        destination: 'https://www.fastkirana.in/:path*',
        permanent: true,
      },
      {
        source: '/:path*',
        has: [
          {
            type: 'host',
            value: 'fastkirana.in',
          },
        ],
        destination: 'https://www.fastkirana.in/:path*',
        permanent: true,
      },
    ];
  },
  async rewrites() {
    const apiDest = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://fastkirana-production-0cdd.up.railway.app';
    return {
      beforeFiles: [
        // Python AI microservices & WebSockets
        {
          source: '/api/python/:path*',
          destination: `${apiDest}/:path*`,
        },
        {
          source: '/ws/:path*',
          destination: `${apiDest}/ws/:path*`,
        },
        // Core High-Traffic Customer & Store APIs -> Railway FastAPI
        {
          source: '/api/products/:path*',
          destination: `${apiDest}/api/products/:path*`,
        },
        {
          source: '/api/products',
          destination: `${apiDest}/api/products`,
        },
        {
          source: '/api/categories/:path*',
          destination: `${apiDest}/api/categories/:path*`,
        },
        {
          source: '/api/categories',
          destination: `${apiDest}/api/categories`,
        },
        {
          source: '/api/restaurants/:path*',
          destination: `${apiDest}/api/restaurants/:path*`,
        },
        {
          source: '/api/restaurants',
          destination: `${apiDest}/api/restaurants`,
        },
        {
          source: '/api/cafe/:path*',
          destination: `${apiDest}/api/cafe/:path*`,
        },
        {
          source: '/api/cart/:path*',
          destination: `${apiDest}/api/cart/:path*`,
        },
        {
          source: '/api/cart',
          destination: `${apiDest}/api/cart`,
        },
        {
          source: '/api/coupons/:path*',
          destination: `${apiDest}/api/coupons/:path*`,
        },
        {
          source: '/api/coupons',
          destination: `${apiDest}/api/coupons`,
        },
        // Store Hubs, Store Status & Location Geofencing -> FastAPI
        {
          source: '/api/stores/:path*',
          destination: `${apiDest}/api/stores/:path*`,
        },
        {
          source: '/api/stores',
          destination: `${apiDest}/api/stores`,
        },
        {
          source: '/api/store-status',
          destination: `${apiDest}/api/store-status`,
        },
        {
          source: '/api/delivery-check',
          destination: `${apiDest}/api/delivery-check`,
        },
        {
          source: '/api/location/:path*',
          destination: `${apiDest}/api/location/:path*`,
        },
        // Core Customer Orders, Status, Tracking & COD -> FastAPI
        {
          source: '/api/orders/:path*',
          destination: `${apiDest}/api/orders/:path*`,
        },
        {
          source: '/api/orders',
          destination: `${apiDest}/api/orders`,
        },
        {
          source: '/api/store-settings/:path*',
          destination: `${apiDest}/api/store-settings/:path*`,
        },
        {
          source: '/api/banners/:path*',
          destination: `${apiDest}/api/banners/:path*`,
        },
        {
          source: '/api/banners',
          destination: `${apiDest}/api/banners`,
        },
        {
          source: '/api/wishlist/:path*',
          destination: `${apiDest}/api/wishlist/:path*`,
        },
        {
          source: '/api/wishlist',
          destination: `${apiDest}/api/wishlist`,
        },
        {
          source: '/api/vendors/:path*',
          destination: `${apiDest}/api/vendors/:path*`,
        },
        {
          source: '/api/picker/:path*',
          destination: `${apiDest}/api/picker/:path*`,
        },
        {
          source: '/api/delivery/:path*',
          destination: `${apiDest}/api/delivery/:path*`,
        },
        {
          source: '/api/addresses/:path*',
          destination: `${apiDest}/api/addresses/:path*`,
        },
        {
          source: '/api/addresses',
          destination: `${apiDest}/api/addresses`,
        },
        {
          source: '/api/profile/:path*',
          destination: `${apiDest}/api/profile/:path*`,
        },
        {
          source: '/api/profile',
          destination: `${apiDest}/api/profile`,
        },
        {
          source: '/api/fcm/:path*',
          destination: `${apiDest}/api/fcm/:path*`,
        },
        {
          source: '/api/admin/rider-cash/:path*',
          destination: `${apiDest}/api/admin/rider-cash/:path*`,
        },
        {
          source: '/api/admin/rider-cash',
          destination: `${apiDest}/api/admin/rider-cash`,
        },
        // Admin Analytics & Reports -> 100% FastAPI Backend Cutover
        {
          source: '/api/admin/reports/:path*',
          destination: `${apiDest}/api/admin/reports/:path*`,
        },
        {
          source: '/api/admin/reports',
          destination: `${apiDest}/api/admin/reports`,
        },
        {
          source: '/api/admin/restaurant-sales/:path*',
          destination: `${apiDest}/api/admin/restaurant-sales/:path*`,
        },
        {
          source: '/api/admin/restaurant-sales',
          destination: `${apiDest}/api/admin/restaurant-sales`,
        },
        {
          source: '/api/admin/payouts/:path*',
          destination: `${apiDest}/api/admin/payouts/:path*`,
        },
        {
          source: '/api/admin/payouts',
          destination: `${apiDest}/api/admin/payouts`,
        },
        {
          source: '/api/admin/forecast/:path*',
          destination: `${apiDest}/api/admin/forecast/:path*`,
        },
        {
          source: '/api/admin/forecast',
          destination: `${apiDest}/api/admin/forecast`,
        },
        {
          source: '/api/admin/inward/:path*',
          destination: `${apiDest}/api/admin/inward/:path*`,
        },
        {
          source: '/api/admin/inward',
          destination: `${apiDest}/api/admin/inward`,
        },
        {
          source: '/api/admin/live-carts/:path*',
          destination: `${apiDest}/api/admin/live-carts/:path*`,
        },
        {
          source: '/api/admin/live-carts',
          destination: `${apiDest}/api/admin/live-carts`,
        },
        {
          source: '/api/admin/alerts/:path*',
          destination: `${apiDest}/api/admin/alerts/:path*`,
        },
        {
          source: '/api/admin/alerts',
          destination: `${apiDest}/api/admin/alerts`,
        },
        {
          source: '/api/admin/reviews/:path*',
          destination: `${apiDest}/api/admin/reviews/:path*`,
        },
        {
          source: '/api/admin/reviews',
          destination: `${apiDest}/api/admin/reviews`,
        },
        // Admin Stores Hub Management -> FastAPI
        {
          source: '/api/admin/stores/:path*',
          destination: `${apiDest}/api/admin/stores/:path*`,
        },
        {
          source: '/api/admin/stores',
          destination: `${apiDest}/api/admin/stores`,
        },
        // Admin Products & Catalog Management -> FastAPI
        {
          source: '/api/admin/products/:path*',
          destination: `${apiDest}/api/admin/products/:path*`,
        },
        {
          source: '/api/admin/products',
          destination: `${apiDest}/api/admin/products`,
        },
        // Admin Users & Staff Management -> FastAPI
        {
          source: '/api/admin/users/:path*',
          destination: `${apiDest}/api/admin/users/:path*`,
        },
        {
          source: '/api/admin/users',
          destination: `${apiDest}/api/admin/users`,
        },
        // Admin Order Management & Actions -> FastAPI
        {
          source: '/api/admin/orders/:path*',
          destination: `${apiDest}/api/admin/orders/:path*`,
        },
        {
          source: '/api/admin/orders',
          destination: `${apiDest}/api/admin/orders`,
        },
        // Online Payment Gateway (Cashfree) -> FastAPI
        {
          source: '/api/payment/cashfree/:path*',
          destination: `${apiDest}/api/payment/cashfree/:path*`,
        },
        {
          source: '/api/payments/cashfree/:path*',
          destination: `${apiDest}/api/payments/cashfree/:path*`,
        },
      ],
      afterFiles: [],
      fallback: [],
    };
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains" },
          { key: "X-XSS-Protection", value: "1; mode=block" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Content-Security-Policy", value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: blob: https:; font-src 'self' data: https:; connect-src 'self' https: wss:; frame-src 'self' https:;" },
        ]
      },
      {
        source: "/api/:path*",
        headers: [
          { key: "Access-Control-Allow-Credentials", value: "true" },
          { key: "Access-Control-Allow-Origin", value: "*" },
          { key: "Access-Control-Allow-Methods", value: "GET,DELETE,PATCH,POST,PUT,OPTIONS" },
          { key: "Access-Control-Allow-Headers", value: "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization" },
        ]
      },
      {
        source: "/(images|icons|fonts)/:path*",
        headers: [
          { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
        ]
      },
      {
        source: "/favicon.ico",
        headers: [
          { key: "Cache-Control", value: "public, max-age=86400, stale-while-revalidate=604800" },
        ]
      }
    ];
  }
};

export default nextConfig;
