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
    const apiDest = process.env.NEXT_PUBLIC_FASTAPI_URL || process.env.NEXT_PUBLIC_API_URL || 'https://fastkirana-production-a4b8.up.railway.app';
    return {
      beforeFiles: [
        // Phase 1: Safe Read-Only Catalog & Content Routes (Zero Financial Risk)
        {
          source: '/api/banners',
          destination: `${apiDest}/api/banners`,
        },
        {
          source: '/api/banners/:path*',
          destination: `${apiDest}/api/banners/:path*`,
        },
        {
          source: '/api/categories',
          destination: `${apiDest}/api/categories`,
        },
        {
          source: '/api/categories/:path*',
          destination: `${apiDest}/api/categories/:path*`,
        },
        {
          source: '/api/restaurants',
          destination: `${apiDest}/api/restaurants`,
        },
        {
          source: '/api/restaurants/:path*',
          destination: `${apiDest}/api/restaurants/:path*`,
        },
        // Phase 2: User Addresses, Cart Sync & Coupons Proxy (Low Risk)
        {
          source: '/api/addresses',
          destination: `${apiDest}/api/addresses`,
        },
        {
          source: '/api/addresses/:path*',
          destination: `${apiDest}/api/addresses/:path*`,
        },
        {
          source: '/api/cart',
          destination: `${apiDest}/api/cart`,
        },
        {
          source: '/api/cart/:path*',
          destination: `${apiDest}/api/cart/:path*`,
        },
        {
          source: '/api/coupons',
          destination: `${apiDest}/api/coupons`,
        },
        {
          source: '/api/coupons/:path*',
          destination: `${apiDest}/api/coupons/:path*`,
        },
        // Phase 3: Core Orders & Logistics Proxy
        {
          source: '/api/orders',
          destination: `${apiDest}/api/orders`,
        },
        {
          source: '/api/orders/:path*',
          destination: `${apiDest}/api/orders/:path*`,
        },
        {
          source: '/api/delivery/:path*',
          destination: `${apiDest}/api/delivery/:path*`,
        },
        {
          source: '/api/picker/:path*',
          destination: `${apiDest}/api/picker/:path*`,
        },
        {
          source: '/api/kot-broadcast',
          destination: `${apiDest}/api/kot-broadcast`,
        },
        // Phase 4: Payments & Profile
        {
          source: '/api/payment/:path*',
          destination: `${apiDest}/api/payment/:path*`,
        },
        {
          source: '/api/payments/:path*',
          destination: `${apiDest}/api/payments/:path*`,
        },
        {
          source: '/api/profile/:path*',
          destination: `${apiDest}/api/profile/:path*`,
        },
        // Phase 5: Admin Dashboard & Operations
        {
          source: '/api/admin/:path*',
          destination: `${apiDest}/api/admin/:path*`,
        },
      ],
      afterFiles: [
        // Python AI microservices & WebSockets
        {
          source: '/api/python/:path*',
          destination: `${apiDest}/:path*`,
        },
        {
          source: '/ws/:path*',
          destination: `${apiDest}/ws/:path*`,
        },
      ],
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
