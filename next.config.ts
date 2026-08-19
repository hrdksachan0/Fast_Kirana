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
      // Generic Python API passthrough
      {
        source: '/api/python/:path*',
        destination: `${apiDest}/:path*`,
      },

      // ── Products ──
      {
        source: '/api/products', // READ
        destination: `${apiDest}/api/products`,
      },

      // ── Categories ──
      {
        source: '/api/categories', // READ
        destination: `${apiDest}/api/categories`,
      },

      // ── Restaurants ──
      {
        source: '/api/restaurants', // READ
        destination: `${apiDest}/api/restaurants`,
      },
      {
        source: '/api/restaurants/:id', // READ
        destination: `${apiDest}/api/restaurants/:id`,
      },

      // ── Cart ──
      {
        source: '/api/cart/:path*',
        destination: `${apiDest}/api/cart/:path*`,
      },

      // ── Orders ──
      {
        source: '/api/orders/:path*',
        destination: `${apiDest}/api/orders/:path*`,
      },

      // ── Addresses ──
      {
        source: '/api/addresses/:path*',
        destination: `${apiDest}/api/addresses/:path*`,
      },

      // ── Coupons ──
      {
        source: '/api/coupons/:path*',
        destination: `${apiDest}/api/coupons/:path*`,
      },

      // ── Delivery & Rider ──
      {
        source: '/api/delivery/:path*',
        destination: `${apiDest}/api/delivery/:path*`,
      },
      {
        source: '/api/delivery-check',
        destination: `${apiDest}/api/delivery-check`,
      },
      {
        source: '/api/picker/:path*',
        destination: `${apiDest}/api/picker/:path*`,
      },

      // ── Admin (all sub-routes) ──
      {
        source: '/api/admin/:path*',
        destination: `${apiDest}/api/admin/:path*`,
      },

      // ── Profile ──
      {
        source: '/api/profile/:path*',
        destination: `${apiDest}/api/profile/:path*`,
      },

      // ── Banners ──
      {
        source: '/api/banners',
        destination: `${apiDest}/api/banners`,
      },

      // ── Settings ──
      {
        source: '/api/settings',
        destination: `${apiDest}/api/settings`,
      },

      // ── Forecast / AI ──
      {
        source: '/api/forecast/:path*',
        destination: `${apiDest}/api/forecast/:path*`,
      },

      // ── Payments (Paytm) ──
      {
        source: '/api/payment/:path*',
        destination: `${apiDest}/api/payment/:path*`,
      },

      // ── Push Notifications (FCM) ──
      {
        source: '/api/push/:path*',
        destination: `${apiDest}/api/push/:path*`,
      },

      // ── Restaurant Dashboard (Owner/Chef panel) ──
      {
        source: '/api/restaurant-dashboard/:path*',
        destination: `${apiDest}/api/restaurant-dashboard/:path*`,
      },
      {
        source: '/api/restaurant/:path*',
        destination: `${apiDest}/api/restaurant/:path*`,
      },

      // ── Cafe Reports ──
      {
        source: '/api/cafe/:path*',
        destination: `${apiDest}/api/cafe/:path*`,
      },

      // ── Location / Geocode / Store Check ──
      {
        source: '/api/geocode/:path*',
        destination: `${apiDest}/api/geocode/:path*`,
      },
      {
        source: '/api/location/:path*',
        destination: `${apiDest}/api/location/:path*`,
      },

      // ── Upload ──
      {
        source: '/api/upload',
        destination: `${apiDest}/api/upload`,
      },

      // ── Wishlist ──
      {
        source: '/api/wishlist',
        destination: `${apiDest}/api/wishlist`,
      },

      // ── Health ──
      {
        source: '/api/health',
        destination: `${apiDest}/api/health`,
      },

      // ── Diagnostics ──
      {
        source: '/api/diagnostics',
        destination: `${apiDest}/api/diagnostics`,
      },

      // ── Revalidate Bridge (webhook for cache busting) ──
      {
        source: '/api/revalidate-bridge',
        destination: `${apiDest}/api/revalidate-bridge`,
      },

      // ── Cron Keep-Alive ──
      {
        source: '/api/cron/:path*',
        destination: `${apiDest}/api/cron/:path*`,
      },
    ];
    // NOTE: /api/auth/[...nextauth] handles NextAuth session creation natively
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
          { key: "Content-Security-Policy", value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: blob: https:; font-src 'self' data: https:; connect-src 'self' https: wss:; frame-src 'self' https:;" },
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

