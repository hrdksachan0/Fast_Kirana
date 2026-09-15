import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Shipping & Delivery Policy - FastKirana',
  description: 'Instant 10-20 minute delivery timelines, delivery fee tiers, and serviceable zones for FastKirana.',
}

export default function ShippingPolicyPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-card p-6 sm:p-10 rounded-2xl shadow-sm border border-border">
        <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-2">
          Shipping & Delivery Policy
        </h1>
        <p className="text-muted-foreground text-sm mb-8">
          Last Updated: September 15, 2026
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed text-sm sm:text-base">
          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">1. Delivery Coverage & Serviceable Area</h2>
            <p className="text-muted-foreground">
              FastKirana operates an instant hyperlocal dark store and restaurant delivery network serving <strong>Ghatampur, Kanpur Nagar, Uttar Pradesh (PIN: 209206)</strong> and adjacent suburban zones within a strict <strong>5.0 km delivery radius</strong>.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">2. Delivery Timelines (10–20 Minutes)</h2>
            <p className="text-muted-foreground">
              All orders placed on FastKirana are processed instantly:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-1.5 text-muted-foreground">
              <li><strong>Grocery & Dark Store Items:</strong> Delivered within <strong>10 to 15 minutes</strong>.</li>
              <li><strong>Hot Restaurant Dishes:</strong> Freshly prepared and delivered within <strong>15 to 25 minutes</strong>.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">3. Delivery Fee & Free Delivery Tiers</h2>
            <p className="text-muted-foreground">
              Our delivery charges are transparent and calculated based on your distance from our central dark store hub in Ghatampur:
            </p>
            <div className="mt-4 border border-border rounded-xl overflow-hidden">
              <table className="min-w-full divide-y divide-border text-xs sm:text-sm">
                <thead className="bg-muted/50">
                  <tr>
                    <th className="px-4 py-3 text-left font-bold text-foreground">Distance Range</th>
                    <th className="px-4 py-3 text-left font-bold text-foreground">Delivery Charge</th>
                    <th className="px-4 py-3 text-left font-bold text-foreground">FREE Delivery On Orders</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-muted-foreground">
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">0 to 2.0 km (Ghatampur City)</td>
                    <td className="px-4 py-3">₹25</td>
                    <td className="px-4 py-3 text-emerald-600 dark:text-emerald-400 font-bold">Above ₹199</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">2.0 to 3.0 km (Suburban Area)</td>
                    <td className="px-4 py-3">₹35</td>
                    <td className="px-4 py-3 text-emerald-600 dark:text-emerald-400 font-bold">Above ₹299</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">3.0 to 5.0 km (Extended Zone)</td>
                    <td className="px-4 py-3">₹50</td>
                    <td className="px-4 py-3 text-emerald-600 dark:text-emerald-400 font-bold">Above ₹399</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">4. Order Tracking & Contactless Handover</h2>
            <p className="text-muted-foreground">
              Once an order is confirmed, customers can track the delivery rider live in real-time on our GPS map with estimated arrival time. Riders follow strict hygiene protocols and support contactless doorstep delivery upon request.
            </p>
          </section>

          <section className="border-t border-border pt-6 mt-8">
            <h2 className="text-xl font-bold text-foreground mb-3">5. Delivery Queries & Support</h2>
            <p className="text-muted-foreground">
              If your delivery is delayed or you need rider assistance:
            </p>
            <div className="mt-3 text-muted-foreground space-y-1">
              <p>Helpline: <a href="tel:+917054470303" className="text-rose-600 hover:underline font-bold">+91 70544 70303</a></p>
              <p>Email: <a href="mailto:fastkiranadelivery@gmail.com" className="text-rose-600 hover:underline font-bold">fastkiranadelivery@gmail.com</a></p>
              <p>Operating Hours: <strong>6:00 AM – 12:00 Midnight</strong></p>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
