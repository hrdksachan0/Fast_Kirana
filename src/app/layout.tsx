import type { Metadata, Viewport } from 'next'
import { Plus_Jakarta_Sans } from 'next/font/google'
import './globals.css'
import { QueryProvider } from '@/providers/query-provider'
import { AuthProvider } from '@/providers/auth-provider'
import { ThemeProvider } from '@/providers/theme-provider'
import { Navbar } from '@/components/layout/navbar'
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
import Script from 'next/script'
import { Suspense } from 'react'
import { TopProgressBar } from '@/components/shared/top-progress-bar'

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  weight: ['300', '400', '500', '600', '700', '800']
})

export const metadata: Metadata = {
  title: 'Fast Kirana - Fast Grocery Delivery in Ghatampur, Kanpur',
  description: 'Order groceries online and get them delivered to your doorstep in Ghatampur, Kanpur in minutes. Fresh fruits, vegetables, dairy, atta, rice, dal, snacks and more.',
  keywords: [
    'grocery delivery in Ghatampur',
    'online grocery store Kanpur',
    'Fast Kirana Ghatampur',
    'online kirana shop Ghatampur',
    'buy milk online Ghatampur',
    'fresh vegetables delivery Ghatampur',
    'fast grocery delivery',
    'kirana store near me'
  ],
  manifest: '/manifest.json',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastkirana.in'),
  openGraph: {
    title: 'Fast Kirana - Fast Grocery Delivery in Ghatampur',
    description: 'Order groceries online and get them delivered in minutes in Ghatampur, Kanpur.',
    url: 'https://www.fastkirana.in',
    siteName: 'Fast Kirana',
    images: [
      {
        url: '/fastkirana_app_icon.png',
        width: 512,
        height: 512,
        alt: 'Fast Kirana Logo',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fast Kirana - Fast Grocery Delivery in Ghatampur',
    description: 'Order groceries online and get them delivered in minutes in Ghatampur, Kanpur.',
    images: ['/fastkirana_app_icon.png'],
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
        <script
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
        <QueryProvider>
          <AuthProvider>
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
                    <main className="flex-grow pt-[96px] md:pt-[80px]">
                      {children}
                    </main>
                    <Footer />
                  </div>
                  <MobileBottomNav />
                  <CartStickyBar />
                  <CartDrawer />
                  <VariantSelectorDrawer />
                  <Toaster position="top-center" richColors closeButton visibleToasts={1} duration={2000} />
                  <PWARegistration />
                  <PushNotificationConsent />
                  <SoftPromptDialog />
                </PushNotificationProvider>
              </CartSyncProvider>
            </LiveStockProvider>
            </ThemeProvider>
          </AuthProvider>
        </QueryProvider>
      </body>
    </html>
  )
}
