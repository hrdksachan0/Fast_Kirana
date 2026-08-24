import { Metadata } from 'next'
import Link from 'next/link'
import { ArrowLeft, HelpCircle, Truck, Sparkles, MapPin, ShoppingBag, ShieldCheck, ChevronRight } from 'lucide-react'

export const metadata: Metadata = {
  title: 'Frequently Asked Questions (FAQ) & Delivery Policy | FastKirana',
  description: 'Learn about FastKirana delivery charges, free delivery tiers, minimum order policy, payment options, and delivery coverage across Ghatampur.',
}

export default function FAQPage() {
  const faqs = [
    {
      category: '🚚 Delivery Charges & Distance Tiers',
      items: [
        {
          q: 'What are the delivery charges and free delivery thresholds on FastKirana?',
          a: `FastKirana offers distance-based transparent delivery pricing across Ghatampur:
• 0 to 2 km (Local Ghatampur): ₹25 delivery fee — FREE Delivery on orders above ₹199!
• 2 to 3 km (Suburban Area): ₹35 delivery fee — FREE Delivery on orders above ₹299!
• 3 to 5 km (Extended Area): ₹50 delivery fee — FREE Delivery on orders above ₹399!
• Outside 5 km: Delivery is currently limited to a maximum of 5.0 km from our central hub.`,
        },
        {
          q: 'Is there any minimum order value requirement?',
          a: 'No! There is absolutely NO minimum order value requirement. You can place an order of any amount without any minimum order block.',
        },
        {
          q: 'How do I know the delivery fee for my address?',
          a: 'When you select or add your address on the checkout page, our system automatically calculates the exact GPS distance from our hub and displays your delivery fee and free delivery threshold badge right on your address card!',
        },
      ],
    },
    {
      category: '🛍️ Ordering & Combining Stores',
      items: [
        {
          q: 'Can I combine FastKirana Grocery and Restaurant items in the same order?',
          a: 'Yes! You can order fresh groceries from FastKirana Darkstore and hot food from any restaurant (like A.S. Restaurant, Wedson Restaurant, or Bal Udyan) together in one seamless combined order.',
        },
        {
          q: 'Can I order from multiple restaurants at the same time?',
          a: 'To guarantee food quality and quick delivery, food items must come from 1 restaurant kitchen per order. However, FastKirana Grocery items can be combined with any restaurant without any limitation!',
        },
        {
          q: 'What happens if I add dishes from a different restaurant to my cart?',
          a: 'A friendly prompt will ask if you want to switch restaurants. Only previous restaurant dishes will be cleared — all your grocery items will remain 100% safe in your cart!',
        },
      ],
    },
    {
      category: '💳 Payments & Safety',
      items: [
        {
          q: 'What payment methods are supported?',
          a: 'We accept Cash on Delivery (COD), UPI (Google Pay, PhonePe, Paytm, BHIM), Net Banking, and Debit/Credit cards via secure Razorpay payment gateway.',
        },
        {
          q: 'How fast is the delivery in Ghatampur?',
          a: 'Most grocery and fast-food orders are delivered to your doorstep within 15 to 30 minutes depending on your location and kitchen prep time.',
        },
      ],
    },
  ]

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-zinc-950 py-10 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto space-y-8">
        
        {/* Top Navigation */}
        <div className="flex items-center justify-between border-b border-zinc-200 dark:border-zinc-800 pb-4">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-xs font-black text-text-secondary hover:text-primary transition-colors"
          >
            <ArrowLeft size={16} /> Back to Store
          </Link>
          <span className="text-[10px] font-black uppercase tracking-wider text-accent bg-accent/10 px-2.5 py-1 rounded-full border border-accent/20">
            Help Center
          </span>
        </div>

        {/* Header Hero */}
        <div className="text-center space-y-3">
          <div className="h-14 w-14 rounded-2xl bg-primary/10 text-primary flex items-center justify-center mx-auto border border-primary/20 shadow-inner">
            <HelpCircle size={28} className="stroke-[2.5]" />
          </div>
          <h1 className="text-2xl sm:text-3xl font-black text-text-primary tracking-tight">
            Frequently Asked Questions
          </h1>
          <p className="text-xs sm:text-sm font-semibold text-text-secondary max-w-xl mx-auto leading-relaxed">
            Everything you need to know about FastKirana delivery fees, distance tiers, and ordering policies.
          </p>
        </div>

        {/* Highlighted Delivery Fee Tier Card */}
        <div className="rounded-3xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900/60 p-5 sm:p-6 shadow-xl space-y-4">
          <div className="flex items-center gap-2 text-text-primary">
            <Truck className="h-5 w-5 text-primary" />
            <h2 className="text-sm sm:text-base font-black tracking-tight">
              FastKirana Distance & Delivery Fee Tiers
            </h2>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
            {/* Tier 1 */}
            <div className="rounded-2xl border border-emerald-500/30 bg-emerald-50/40 dark:bg-emerald-950/20 p-4 space-y-1.5 text-center">
              <span className="inline-block text-[9.5px] font-black uppercase tracking-wider text-emerald-700 dark:text-emerald-300 bg-emerald-500/10 px-2 py-0.5 rounded-full border border-emerald-500/20">
                0 - 2 km (Local)
              </span>
              <div className="text-lg font-black text-text-primary">₹25 <span className="text-xs font-bold text-text-muted">Fee</span></div>
              <p className="text-[11px] font-black text-emerald-600 dark:text-emerald-400">
                FREE above ₹199
              </p>
            </div>

            {/* Tier 2 */}
            <div className="rounded-2xl border border-blue-500/30 bg-blue-50/40 dark:bg-blue-950/20 p-4 space-y-1.5 text-center">
              <span className="inline-block text-[9.5px] font-black uppercase tracking-wider text-blue-700 dark:text-blue-300 bg-blue-500/10 px-2 py-0.5 rounded-full border border-blue-500/20">
                2 - 3 km (Suburban)
              </span>
              <div className="text-lg font-black text-text-primary">₹35 <span className="text-xs font-bold text-text-muted">Fee</span></div>
              <p className="text-[11px] font-black text-blue-600 dark:text-blue-400">
                FREE above ₹299
              </p>
            </div>

            {/* Tier 3 */}
            <div className="rounded-2xl border border-amber-500/30 bg-amber-50/40 dark:bg-amber-950/20 p-4 space-y-1.5 text-center">
              <span className="inline-block text-[9.5px] font-black uppercase tracking-wider text-amber-700 dark:text-amber-300 bg-amber-500/10 px-2 py-0.5 rounded-full border border-amber-500/20">
                3 - 5 km (Extended)
              </span>
              <div className="text-lg font-black text-text-primary">₹50 <span className="text-xs font-bold text-text-muted">Fee</span></div>
              <p className="text-[11px] font-black text-amber-600 dark:text-amber-400">
                FREE above ₹399
              </p>
            </div>
          </div>

          <div className="text-center pt-1 text-[11px] font-extrabold text-text-secondary">
            ⚡ <strong>Zero Minimum Order:</strong> Order anything without minimum cart restrictions!
          </div>
        </div>

        {/* FAQs Accordions */}
        <div className="space-y-6">
          {faqs.map((cat, idx) => (
            <div key={idx} className="space-y-3">
              <h3 className="text-xs font-black uppercase tracking-wider text-text-muted px-1">
                {cat.category}
              </h3>
              <div className="space-y-2.5">
                {cat.items.map((item, i) => (
                  <div
                    key={i}
                    className="rounded-2xl border border-zinc-200 dark:border-zinc-800 bg-white dark:bg-zinc-900/40 p-4 space-y-2"
                  >
                    <h4 className="text-xs sm:text-sm font-black text-text-primary leading-snug">
                      {item.q}
                    </h4>
                    <p className="text-[11.5px] font-semibold text-text-secondary leading-relaxed whitespace-pre-line">
                      {item.a}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>

        {/* Bottom CTA Card */}
        <div className="rounded-3xl bg-gradient-to-r from-primary to-accent p-6 text-white text-center space-y-3 shadow-xl">
          <h3 className="text-base sm:text-lg font-black tracking-tight">
            Ready to place an order?
          </h3>
          <p className="text-xs text-white/90 max-w-md mx-auto font-medium">
            Explore 1000+ groceries, fresh vegetables, dairy, and restaurant dishes in Ghatampur.
          </p>
          <div className="pt-2">
            <Link
              href="/"
              className="inline-flex items-center gap-1.5 px-6 py-2.5 bg-white text-primary font-black text-xs rounded-full shadow-md hover:bg-zinc-100 transition-all cursor-pointer"
            >
              Start Shopping Now <ChevronRight size={14} />
            </Link>
          </div>
        </div>

      </div>
    </div>
  )
}
