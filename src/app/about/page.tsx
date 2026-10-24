import { Metadata } from 'next'
import Link from 'next/link'
import { 
  Zap, 
  ShieldCheck, 
  Clock, 
  MapPin, 
  HeartHandshake, 
  ShoppingBag, 
  Truck, 
  Smartphone,
  ArrowRight,
  Sparkles,
  Store,
  Users
} from 'lucide-react'

export const metadata: Metadata = {
  title: 'About Us - FastMinute (Fast Minute) | 10-Minute Grocery Delivery in Ghatampur',
  description: 'FastMinute (Fast Minute) is Ghatampur\'s premier 10-minute grocery and food delivery platform. Learn about our local dark store model, our mission for Kanpur Nagar (209206), and our commitment to fresh daily essentials.',
  alternates: {
    canonical: 'https://www.fastminute.in/about',
  },
  openGraph: {
    title: 'About FastMinute (Fast Minute) - 10-Minute Delivery in Ghatampur',
    description: 'FastMinute delivers groceries, fresh vegetables, milk, dairy, and restaurant food to your doorstep in minutes across Ghatampur, Uttar Pradesh.',
    url: 'https://www.fastminute.in/about',
    siteName: 'FastMinute',
    locale: 'en_IN',
    type: 'website',
  },
}

export default function AboutPage() {
  const jsonLd = {
    '@context': 'https://schema.org',
    '@type': 'AboutPage',
    name: 'About FastMinute',
    url: 'https://www.fastminute.in/about',
    description: 'Information about FastMinute (Fast Minute), a 10-minute grocery and food delivery service operating in Ghatampur, Kanpur Nagar, Uttar Pradesh (209206).',
    mainEntity: {
      '@type': 'Organization',
      name: 'FastMinute',
      alternateName: ['Fast Minute', 'FastMinute Grocery', 'FastMinute Ghatampur'],
      url: 'https://www.fastminute.in',
      logo: 'https://www.fastminute.in/brand/fastkirana_app_icon.png',
      foundingLocation: {
        '@type': 'Place',
        name: 'Ghatampur, Kanpur Nagar, Uttar Pradesh',
        address: {
          '@type': 'PostalAddress',
          addressLocality: 'Ghatampur',
          addressRegion: 'Uttar Pradesh',
          postalCode: '209206',
          addressCountry: 'IN',
        },
      },
      areaServed: 'Ghatampur, Kanpur Nagar (209206)',
      knowsAbout: [
        'Quick Commerce',
        '10-Minute Grocery Delivery',
        'Online Kirana',
        'Fresh Dairy Milk Delivery',
        'Local Food Ordering',
      ],
    },
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <div className="bg-background min-h-screen py-10 px-4 sm:px-6 lg:px-8">
        <div className="max-w-5xl mx-auto space-y-12">
          
          {/* Hero Section */}
          <section className="text-center space-y-4 pt-4">
            <div className="inline-flex items-center gap-2 bg-rose-500/10 border border-rose-500/20 text-rose-600 dark:text-rose-400 text-xs sm:text-sm font-bold px-3.5 py-1.5 rounded-full select-none">
              <Sparkles className="h-4 w-4" />
              Ghatampur&apos;s Own 10-Minute Delivery Platform
            </div>
            <h1 className="text-3xl sm:text-5xl font-black text-foreground tracking-tight max-w-3xl mx-auto leading-tight">
              About <span className="text-rose-600">FastMinute</span> (Fast Minute)
            </h1>
            <p className="text-muted-foreground text-sm sm:text-lg max-w-2xl mx-auto leading-relaxed">
              We are on a mission to bring instant quick-commerce to Ghatampur and surrounding regions in Kanpur Nagar (209206) — delivering groceries, fresh dairy, produce, and cooked meals right to your doorstep in 10 to 15 minutes.
            </p>
          </section>

          {/* Quick Metrics */}
          <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div className="bg-card border border-border rounded-2xl p-5 text-center shadow-xs">
              <div className="text-2xl sm:text-3xl font-black text-rose-600">10-15 Min</div>
              <div className="text-xs text-muted-foreground font-semibold mt-1">Average Delivery Time</div>
            </div>
            <div className="bg-card border border-border rounded-2xl p-5 text-center shadow-xs">
              <div className="text-2xl sm:text-3xl font-black text-foreground">5,000+</div>
              <div className="text-xs text-muted-foreground font-semibold mt-1">Happy Families in Town</div>
            </div>
            <div className="bg-card border border-border rounded-2xl p-5 text-center shadow-xs">
              <div className="text-2xl sm:text-3xl font-black text-emerald-600">1,500+</div>
              <div className="text-xs text-muted-foreground font-semibold mt-1">Products &amp; Essentials</div>
            </div>
            <div className="bg-card border border-border rounded-2xl p-5 text-center shadow-xs">
              <div className="text-2xl sm:text-3xl font-black text-amber-500">6 AM - 12 AM</div>
              <div className="text-xs text-muted-foreground font-semibold mt-1">Open 365 Days a Year</div>
            </div>
          </section>

          {/* Our Story & Mission */}
          <section className="bg-card border border-border rounded-3xl p-6 sm:p-10 space-y-6 shadow-xs">
            <div className="space-y-2">
              <h2 className="text-xl sm:text-2xl font-black text-foreground">
                Our Story: Why We Built FastMinute
              </h2>
              <p className="text-muted-foreground text-sm sm:text-base leading-relaxed">
                For years, Tier-2 and Tier-3 towns like Ghatampur were left out of the modern quick-commerce revolution. Big national players only operated in metro cities like Delhi, Mumbai, or Bengaluru, while families in Ghatampur had to step out in harsh weather or traffic just to buy milk, bread, cooking oil, or medicine.
              </p>
              <p className="text-muted-foreground text-sm sm:text-base leading-relaxed">
                FastMinute (also known as <strong className="text-foreground">Fast Minute</strong>) was founded to bridge this gap. We established a hyper-local dark store network right in the heart of Ghatampur on NH34. By combining smart local inventory management, trained delivery riders, and an easy-to-use mobile web &amp; Android app, we made 10-minute grocery delivery a reality for every household in Ghatampur.
              </p>
            </div>
          </section>

          {/* How FastMinute Works */}
          <section className="space-y-6">
            <div className="text-center space-y-2">
              <h2 className="text-2xl sm:text-3xl font-black text-foreground">
                How FastMinute Works in 3 Steps
              </h2>
              <p className="text-muted-foreground text-xs sm:text-sm">
                Optimized from tap to doorbell delivery
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-card border border-border rounded-2xl p-6 space-y-3 shadow-xs">
                <div className="h-11 w-11 rounded-xl bg-rose-500/10 text-rose-600 flex items-center justify-center font-black">
                  <Smartphone className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-foreground text-base">1. Order in Seconds</h3>
                <p className="text-xs sm:text-sm text-muted-foreground leading-relaxed">
                  Browse over 1,500 daily essentials, fresh milk, vegetables, snacks, and local restaurant dishes on the FastMinute app or website.
                </p>
              </div>

              <div className="bg-card border border-border rounded-2xl p-6 space-y-3 shadow-xs">
                <div className="h-11 w-11 rounded-xl bg-amber-500/10 text-amber-600 flex items-center justify-center font-black">
                  <Store className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-foreground text-base">2. Picked from Local Dark Store</h3>
                <p className="text-xs sm:text-sm text-muted-foreground leading-relaxed">
                  Our dedicated pickers pack your items in under 2 minutes with strict quality checks, ensuring chilled items stay cold and fresh produce stays crisp.
                </p>
              </div>

              <div className="bg-card border border-border rounded-2xl p-6 space-y-3 shadow-xs">
                <div className="h-11 w-11 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center font-black">
                  <Truck className="h-5 w-5" />
                </div>
                <h3 className="font-bold text-foreground text-base">3. 10-Minute Doorstep Drop</h3>
                <p className="text-xs sm:text-sm text-muted-foreground leading-relaxed">
                  Our professional delivery fleet brings the bag right to your door with live tracking and flexible payment options: UPI, Cash on Delivery, or Cards.
                </p>
              </div>
            </div>
          </section>

          {/* What Makes Us Different */}
          <section className="bg-muted/40 border border-border rounded-3xl p-6 sm:p-10 space-y-6">
            <h2 className="text-xl sm:text-2xl font-black text-foreground">
              What You Get with FastMinute
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div className="flex gap-4">
                <div className="h-10 w-10 shrink-0 rounded-xl bg-rose-500/10 text-rose-600 flex items-center justify-center">
                  <Zap className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-bold text-foreground text-sm sm:text-base">Guaranteed Quick Delivery</h4>
                  <p className="text-xs sm:text-sm text-muted-foreground mt-1 leading-relaxed">
                    No waiting for hours or days. When you need cooking oil in the middle of dinner or milk for morning tea, we arrive in minutes.
                  </p>
                </div>
              </div>

              <div className="flex gap-4">
                <div className="h-10 w-10 shrink-0 rounded-xl bg-emerald-500/10 text-emerald-600 flex items-center justify-center">
                  <ShieldCheck className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-bold text-foreground text-sm sm:text-base">100% Genuine &amp; Fresh</h4>
                  <p className="text-xs sm:text-sm text-muted-foreground mt-1 leading-relaxed">
                    Sourced directly from verified brands and trusted local suppliers. No expired products or compromised quality.
                  </p>
                </div>
              </div>

              <div className="flex gap-4">
                <div className="h-10 w-10 shrink-0 rounded-xl bg-blue-500/10 text-blue-600 flex items-center justify-center">
                  <HeartHandshake className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-bold text-foreground text-sm sm:text-base">Support for Local Economy</h4>
                  <p className="text-xs sm:text-sm text-muted-foreground mt-1 leading-relaxed">
                    We create local employment for delivery riders, warehouse pickers, and partner with local dairy farms and restaurants.
                  </p>
                </div>
              </div>

              <div className="flex gap-4">
                <div className="h-10 w-10 shrink-0 rounded-xl bg-purple-500/10 text-purple-600 flex items-center justify-center">
                  <Clock className="h-5 w-5" />
                </div>
                <div>
                  <h4 className="font-bold text-foreground text-sm sm:text-base">Reliable 6 AM to 12 Midnight</h4>
                  <p className="text-xs sm:text-sm text-muted-foreground mt-1 leading-relaxed">
                    Early morning puja items and fresh milk to midnight snack cravings — our dark stores operate 18 hours every day.
                  </p>
                </div>
              </div>
            </div>
          </section>

          {/* Operational Hub & Service Areas */}
          <section className="bg-card border border-border rounded-3xl p-6 sm:p-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6 shadow-xs">
            <div className="space-y-3 max-w-xl">
              <div className="inline-flex items-center gap-1.5 text-rose-600 text-xs font-bold uppercase tracking-wider bg-rose-500/10 px-2.5 py-1 rounded-md">
                <MapPin className="h-3.5 w-3.5" />
                Serving All of Ghatampur
              </div>
              <h3 className="text-xl sm:text-2xl font-black text-foreground">
                Delivering Across Pincode 209206
              </h3>
              <p className="text-xs sm:text-sm text-muted-foreground leading-relaxed">
                Our main dark store is located on NH34, Ghatampur Market, Kanpur Nagar. We deliver across all localities including Station Road, Power House Colony, Main Bazar, Jahangirabad, Kushmanda Nagar, and surrounding neighbourhoods.
              </p>
            </div>
            <div className="flex flex-col sm:flex-row gap-3 shrink-0 w-full md:w-auto">
              <Link
                href="/category"
                className="inline-flex items-center justify-center gap-2 bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs sm:text-sm px-5 py-3 rounded-xl transition-all shadow-xs"
              >
                <ShoppingBag className="h-4 w-4" />
                Start Shopping
              </Link>
              <Link
                href="/contact"
                className="inline-flex items-center justify-center gap-2 bg-muted hover:bg-muted/80 text-foreground font-bold text-xs sm:text-sm px-5 py-3 rounded-xl border border-border transition-all"
              >
                Contact Support
                <ArrowRight className="h-4 w-4" />
              </Link>
            </div>
          </section>

          {/* App Download Banner */}
          <section className="bg-gradient-to-br from-zinc-900 to-black text-white rounded-3xl p-6 sm:p-10 relative overflow-hidden border border-zinc-800">
            <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
              <div className="space-y-2 max-w-xl">
                <span className="text-xs uppercase font-bold text-rose-400 tracking-wider">FastMinute Mobile App</span>
                <h3 className="text-2xl sm:text-3xl font-black leading-tight">
                  Download the FastMinute App for Android
                </h3>
                <p className="text-xs sm:text-sm text-zinc-400 leading-relaxed">
                  Enjoy real-time order tracking, app-exclusive flash sales, and 1-tap reordering directly on your phone.
                </p>
              </div>
              <a
                href="https://play.google.com/store/apps/details?id=com.fastkirana.app"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-3 bg-white text-black hover:bg-zinc-100 font-bold px-6 py-3.5 rounded-2xl transition-all shadow-lg shrink-0"
              >
                <Smartphone className="h-5 w-5 text-rose-600" />
                <div className="text-left">
                  <div className="text-[10px] uppercase font-semibold text-zinc-600 leading-none">Get it on</div>
                  <div className="text-sm font-black leading-tight">Google Play Store</div>
                </div>
              </a>
            </div>
          </section>

        </div>
      </div>
    </>
  )
}
