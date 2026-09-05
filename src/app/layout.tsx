import type { Metadata, Viewport } from 'next'
import { Plus_Jakarta_Sans } from 'next/font/google'
import './globals.css'
import { AuthProvider } from '@/providers/auth-provider'
import { ThemeProvider } from '@/providers/theme-provider'
import { Navbar } from '@/components/layout/navbar'
import { MainWrapper } from '@/components/layout/main-wrapper'
import { Footer } from '@/components/layout/footer'
import { MobileBottomNav } from '@/components/layout/mobile-bottom-nav'
import { CartStickyBar } from '@/components/cart/cart-sticky-bar'
import { CartDrawer } from '@/components/cart/cart-drawer'
import { VariantSelectorDrawer } from '@/components/product/variant-selector-drawer'
import { Toaster } from 'sonner'
import { cn } from "@/lib/utils";
import { PWARegistration } from '@/components/shared/pwa-registration'
import { PushNotificationConsent } from '@/components/shared/push-notification-consent'
import { LiveStockProvider } from '@/components/providers/live-stock-provider'
import { CartSyncProvider } from '@/components/providers/cart-sync-provider'
import { PushNotificationProvider } from '@/providers/push-notification-provider'
import { SoftPromptDialog } from '@/components/shared/soft-prompt-dialog'
import { CartConflictDialog } from '@/components/cart/cart-conflict-dialog'
import Script from 'next/script'
import { Suspense } from 'react'
import { TopProgressBar } from '@/components/shared/top-progress-bar'
import { SwipeToBack } from '@/components/shared/swipe-to-back'
import { SupabaseAuthBridge } from '@/components/auth/auth-bridge'


import { JsonLdSchema } from '@/components/seo/json-ld'
import { UnserviceableLocationBanner } from '@/components/layout/unserviceable-banner'

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  weight: ['300', '400', '500', '600', '700', '800']
})

export const metadata: Metadata = {
  title: 'Fast Kirana - Online Grocery Delivery in Ghatampur, Kanpur',
  description: 'Order groceries, fresh milk, vegetables, dairy, snacks, food & daily essentials online in Ghatampur, Kanpur Nagar. Fast doorstep delivery with COD & UPI support.',
  keywords: [
    'grocery delivery in Ghatampur',
    'online grocery store Kanpur',
    'Fast Kirana Ghatampur',
    'online kirana shop Ghatampur',
    'buy milk online Ghatampur',
    'fresh vegetables delivery Ghatampur',
    'fast grocery delivery Kanpur',
    'kirana store near me Ghatampur',
    'dark store Ghatampur 209206',
    'fast delivery Ghatampur'
  ],
  manifest: '/manifest.json?v=2',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastkirana.in'),
  alternates: {
    canonical: 'https://www.fastkirana.in',
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  openGraph: {
    title: 'Fast Kirana - Online Grocery Delivery in Ghatampur, Kanpur',
    description: 'Order groceries online and get them delivered fast in Ghatampur, Kanpur Nagar.',
    url: 'https://www.fastkirana.in',
    siteName: 'Fast Kirana',
    images: [
      {
        url: '/brand/fastkirana_app_icon.png',
        width: 512,
        height: 512,
        alt: 'Fast Kirana Ghatampur Logo',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fast Kirana - Online Grocery Delivery in Ghatampur',
    description: 'Order groceries online and get them delivered fast in Ghatampur, Kanpur.',
    images: ['/brand/fastkirana_app_icon.png'],
  },
}

export const viewport: Viewport = {
  themeColor: '#e20a22',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className={cn("font-sans", jakarta.variable)} suppressHydrationWarning>
      <head>
        <meta name="geo.region" content="IN-UP" />
        <meta name="geo.placename" content="Ghatampur, Kanpur Nagar, Uttar Pradesh" />
        <meta name="geo.position" content="26.1554;80.1633" />
        <meta name="ICBM" content="26.1554, 80.1633" />
        <JsonLdSchema />
        <script
          id="theme-init"
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var saved = localStorage.getItem('theme');
                  document.documentElement.classList.add(saved || 'light');
                } catch (e) {}
              })();
            `,
          }}
        />
      </head>
      <body className={`${jakarta.className} bg-background text-text-primary antialiased`}>
        <AuthProvider>
          <SupabaseAuthBridge />
          <ThemeProvider>
            <LiveStockProvider>
              <CartSyncProvider>
                <PushNotificationProvider>
                <Suspense fallback={null}>
                  <TopProgressBar />
                </Suspense>
                {/* Elegant glowing background gradient mesh blobs for a modern Web3/SaaS look */}
                <div className="hidden md:block fixed inset-0 pointer-events-none z-[-1] overflow-hidden opacity-40 dark:opacity-45">
                  <div className="absolute top-[-10%] left-[-10%] w-[600px] h-[600px] rounded-full bg-primary/8 blur-[130px] animate-float-slow" />
                  <div className="absolute bottom-[20%] right-[-10%] w-[500px] h-[500px] rounded-full bg-accent/8 blur-[120px] animate-float-reverse" />
                  <div className="absolute top-[40%] right-[10%] w-[300px] h-[300px] rounded-full bg-rose-400/5 blur-[100px] animate-float" />
                </div>

                <div className="flex flex-col min-h-screen">
                  <Navbar />
                  <UnserviceableLocationBanner />
                  <MainWrapper>
                    {children}
                  </MainWrapper>
                  <Footer />
                </div>
                <MobileBottomNav />
                <CartStickyBar />
                <PWARegistration />
                <CartDrawer />
                <VariantSelectorDrawer />
                <Toaster position="top-center" richColors closeButton visibleToasts={1} duration={2000} />

                <PushNotificationConsent />
                <SoftPromptDialog />
                <CartConflictDialog />
                <SwipeToBack />

                </PushNotificationProvider>
              </CartSyncProvider>
            </LiveStockProvider>
          </ThemeProvider>
        </AuthProvider>
      </body>
    </html>
  )
}
