import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  transpilePackages: ['@supabase/supabase-js'],
  experimental: {
    staleTimes: {
      dynamic: 30,
      static: 180,
    },
  },
  images: {
    minimumCacheTTL: 2592000,
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'res.cloudinary.com',
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
    const apiDest = process.env.NEXT_PUBLIC_API_URL || 'https://fast-kirana-0ezx.onrender.com';
    return [
      {
        source: '/api/python/:path*',
        destination: `${apiDest}/:path*`,
      },
      {
        source: '/api/categories',
        destination: `${apiDest}/api/categories`,
      },
      {
        source: '/api/categories/:id',
        destination: `${apiDest}/api/categories/:id`,
      },
      {
        source: '/api/profile/:path*',
        destination: `${apiDest}/api/profile/:path*`,
      },
      {
        source: '/api/banners',
        destination: `${apiDest}/api/banners`,
      },
      {
        source: '/api/settings',
        destination: `${apiDest}/api/settings`,
      },
      {
        source: '/api/products/:path*',
        destination: `${apiDest}/api/products/:path*`,
      },
      {
        source: '/api/restaurants/:path*',
        destination: `${apiDest}/api/restaurants/:path*`,
      },
      {
        source: '/api/cart/:path*',
        destination: `${apiDest}/api/cart/:path*`,
      },
      {
        source: '/api/addresses/:path*',
        destination: `${apiDest}/api/addresses/:path*`,
      },
      {
        source: '/api/coupons/:path*',
        destination: `${apiDest}/api/coupons/:path*`,
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
        source: '/api/admin/:path*',
        destination: `${apiDest}/api/admin/:path*`,
      },
      {
        source: '/api/forecast/:path*',
        destination: `${apiDest}/api/forecast/:path*`,
      },
    ];
  },
  async headers() {
    const allowedOrigin = process.env.NEXT_PUBLIC_APP_URL || 'https://fast-kirana-gtm.vercel.app';
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains" },
          { key: "X-XSS-Protection", value: "1; mode=block" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
        ]
      },
      {
        source: "/api/:path*",
        headers: [
          { key: "Access-Control-Allow-Credentials", value: "true" },
          { key: "Access-Control-Allow-Origin", value: allowedOrigin },
          { key: "Access-Control-Allow-Methods", value: "GET,DELETE,PATCH,POST,PUT,OPTIONS" },
          { key: "Access-Control-Allow-Headers", value: "X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization" },
        ]
      }
    ];
  }
};

export default nextConfig;

