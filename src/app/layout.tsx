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
import { PhoneEnforcementModal } from '@/components/auth/phone-enforcement-modal'
import { NetworkLivenessBanner } from '@/components/shared/network-liveness-banner'
import { AppDownloadSheet } from '@/components/shared/app-download-sheet'

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  weight: ['300', '400', '500', '600', '700', '800']
})

export const metadata: Metadata = {
  title: {
    default: 'FastMinute - Online Grocery & Food Delivery in Minutes | Ghatampur',
    template: '%s | FastMinute Ghatampur',
  },
  description: 'Order groceries, fresh milk, vegetables, dairy, snacks, restaurant food & daily essentials online in Ghatampur, Kanpur Nagar (209206). Superfast doorstep delivery with COD & UPI payment support.',
  keywords: [
    'FastMinute',
    'Fast Minute',
    'FastMinute Ghatampur',
    'fastminute.in',
    'grocery delivery in Ghatampur',
    'online grocery store Kanpur',
    'online kirana shop Ghatampur',
    'buy milk online Ghatampur',
    'fresh vegetables delivery Ghatampur',
    'food delivery Ghatampur',
    'restaurant delivery Ghatampur',
    'fast grocery delivery Kanpur',
    'kirana store near me Ghatampur',
    'dark store Ghatampur 209206',
    'fast delivery Ghatampur',
    '10 minute delivery Ghatampur'
  ],
  manifest: '/manifest.json?v=5',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastminute.in'),
  alternates: {
    canonical: 'https://www.fastminute.in',
    languages: {
      'en-IN': 'https://www.fastminute.in',
      'hi-IN': 'https://www.fastminute.in',
    },
  },
  appLinks: {
    android: {
      package: 'com.fastkirana.app',
      app_name: 'FastMinute: Deliver in Minutes',
      url: 'https://play.google.com/store/apps/details?id=com.fastkirana.app',
    },
    web: {
      url: 'https://www.fastminute.in/',
      should_fallback: true,
    },
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
    title: 'FastMinute - Online Grocery & Food Delivery in Minutes',
    description: 'Order groceries and food online and get them delivered in minutes in Ghatampur, Kanpur Nagar.',
    url: 'https://www.fastminute.in',
    siteName: 'FastMinute',
    images: [
      {
        url: '/brand/fastkirana_app_icon.png?v=3',
        width: 1024,
        height: 1024,
        alt: 'FastMinute Logo',
        type: 'image/png',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'FastMinute - Online Delivery in Minutes',
    description: 'Order groceries and food online and get them delivered in minutes.',
    images: ['/brand/fastkirana_app_icon.png?v=3'],
  },
}

export const viewport: Viewport = {
  themeColor: '#e20a22',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 3,
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
                {/* Subtle static gradient mesh for depth without repaint overhead */}
                <div className="hidden md:block fixed inset-0 pointer-events-none z-[-1] overflow-hidden opacity-30 dark:opacity-35 bg-[radial-gradient(ellipse_at_top_left,rgba(226,10,34,0.06),transparent_50%),radial-gradient(ellipse_at_bottom_right,rgba(0,177,64,0.05),transparent_50%)] transform-gpu" />

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
                <PhoneEnforcementModal />
                <NetworkLivenessBanner />
                <AppDownloadSheet />

                </PushNotificationProvider>
              </CartSyncProvider>
            </LiveStockProvider>
          </ThemeProvider>
        </AuthProvider>
      </body>
    </html>
  )
}
