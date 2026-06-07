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
import { CartFlyAnimation } from '@/components/shared/cart-fly-animation'
import { Toaster } from 'sonner'
import { cn } from "@/lib/utils";
import { PWARegistration } from '@/components/shared/pwa-registration'
import Script from 'next/script'

const jakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  weight: ['300', '400', '500', '600', '700', '800']
})

export const metadata: Metadata = {
  title: 'FastKirana - Fast Grocery Delivery',
  description: 'Order groceries online and get them delivered to your doorstep with our fast delivery service. Fresh fruits, vegetables, dairy, snacks and more.',
  keywords: ['grocery delivery', 'online grocery', 'fast delivery', 'FastKirana', 'kirana store'],
  manifest: '/manifest.json',
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
    <html lang="en" className={cn("font-sans", jakarta.variable)} suppressHydrationWarning data-scroll-behavior="smooth">
      <head>
        <Script
          id="theme-init"
          strategy="beforeInteractive"
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                try {
                  var saved = localStorage.getItem('theme');
                  var system = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
                  document.documentElement.classList.add(saved || system);
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
              {/* Elegant glowing background gradient mesh blobs for a modern Web3/SaaS look */}
              <div className="fixed inset-0 pointer-events-none z-[-1] overflow-hidden opacity-40 dark:opacity-45">
                <div className="absolute top-[-10%] left-[-10%] w-[600px] h-[600px] rounded-full bg-primary/8 blur-[130px] animate-float-slow" />
                <div className="absolute bottom-[20%] right-[-10%] w-[500px] h-[500px] rounded-full bg-accent/8 blur-[120px] animate-float-reverse" />
                <div className="absolute top-[40%] right-[10%] w-[300px] h-[300px] rounded-full bg-rose-400/5 blur-[100px] animate-float" />
              </div>

              <Navbar />
              <main className="min-h-screen pt-[96px] md:pt-[80px] pb-16 md:pb-0">
                {children}
              </main>
              <Footer />
              <MobileBottomNav />
              <CartStickyBar />
              <CartDrawer />
              <CartFlyAnimation />
              <Toaster position="bottom-center" richColors closeButton />
              <PWARegistration />
            </ThemeProvider>
          </AuthProvider>
        </QueryProvider>
      </body>
    </html>
  )
}
