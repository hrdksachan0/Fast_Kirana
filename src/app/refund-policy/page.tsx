import { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Refund & Cancellation Policy - FastKirana',
  description: 'Cancellation, Return and Refund Policy for FastKirana quick-commerce and food delivery services.',
}

export default function RefundPolicyPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-card p-6 sm:p-10 rounded-2xl shadow-sm border border-border">
        <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-2">
          Refund & Cancellation Policy
        </h1>
        <p className="text-muted-foreground text-sm mb-8">
          Last Updated: September 15, 2026
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed text-sm sm:text-base">
          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">1. Order Cancellation Policy</h2>
            <div className="space-y-2 text-muted-foreground">
              <p>
                <strong>Before Order Dispatch / Preparation:</strong> You can cancel your order free of charge within 1 minute of placing it or before the dark store picker / restaurant chef has started packing or cooking your order.
              </p>
              <p>
                <strong>After Order Dispatch:</strong> Because we deliver within 10–20 minutes and perishable food/groceries are packed immediately, cancellations are not permitted once the delivery partner is on the way with your items.
              </p>
            </div>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">2. Returns & Replacement Eligibility</h2>
            <p className="text-muted-foreground">
              We offer doorstep return / replacement or instant refunds in the following circumstances:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-1.5 text-muted-foreground">
              <li><strong>Damaged or Tampered Products:</strong> Package was opened, leaked, or physically damaged upon arrival.</li>
              <li><strong>Missing or Incorrect Items:</strong> Item received differs from what was ordered in the app.</li>
              <li><strong>Expired or Spoiled Goods:</strong> Fresh produce (dairy, vegetables, fruits) delivered past expiry date or spoiled.</li>
              <li><strong>Quality Issue with Prepared Food:</strong> Spilled container, uncooked or stale restaurant meal.</li>
            </ul>
            <p className="text-muted-foreground mt-3">
              <em>Note:</em> For perishable items (fruits, vegetables, milk, bread, hot cooked food), issues must be reported to our support team within <strong>2 hours</strong> of delivery. For packaged non-perishable goods, issues can be reported within <strong>24 hours</strong>.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">3. Refund Process & Timelines</h2>
            <p className="text-muted-foreground">
              Once an eligible return or cancellation request is verified, refunds are processed immediately through our secure payment gateway:
            </p>
            <div className="mt-4 border border-border rounded-xl overflow-hidden">
              <table className="min-w-full divide-y divide-border text-xs sm:text-sm">
                <thead className="bg-muted/50">
                  <tr>
                    <th className="px-4 py-3 text-left font-bold text-foreground">Payment Method</th>
                    <th className="px-4 py-3 text-left font-bold text-foreground">Refund Destination</th>
                    <th className="px-4 py-3 text-left font-bold text-foreground">Estimated Time</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border text-muted-foreground">
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">UPI (GPay, PhonePe, Paytm)</td>
                    <td className="px-4 py-3">Original Bank Account (UPI VPA)</td>
                    <td className="px-4 py-3 text-emerald-600 dark:text-emerald-400 font-bold">Instant to 2 Hours</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">Credit / Debit Cards</td>
                    <td className="px-4 py-3">Original Card Account</td>
                    <td className="px-4 py-3">3 to 5 Business Days</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">Net Banking</td>
                    <td className="px-4 py-3">Source Bank Account</td>
                    <td className="px-4 py-3">2 to 4 Business Days</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-3 font-semibold text-foreground">Cash on Delivery (COD)</td>
                    <td className="px-4 py-3">Customer UPI ID or FastKirana Wallet</td>
                    <td className="px-4 py-3 text-emerald-600 dark:text-emerald-400 font-bold">Instant (within 1 hour)</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">4. Non-Refundable Items</h2>
            <p className="text-muted-foreground">
              The following categories are non-returnable once safely delivered intact:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-1 text-muted-foreground">
              <li>Personal hygiene and grooming items once the seal is opened.</li>
              <li>Consumable items that have been partially used or opened after successful delivery without defect.</li>
            </ul>
          </section>

          <section className="border-t border-border pt-6 mt-8">
            <h2 className="text-xl font-bold text-foreground mb-3">5. How to Request a Refund</h2>
            <p className="text-muted-foreground">
              To request a return, replacement, or refund, simply reach out to us with your Order ID and item photos:
            </p>
            <div className="mt-3 text-muted-foreground space-y-1">
              <p>WhatsApp / Call Support: <a href="https://wa.me/917054470303" className="text-rose-600 hover:underline font-bold">+91 70544 70303</a></p>
              <p>Email: <a href="mailto:fastkiranadelivery@gmail.com" className="text-rose-600 hover:underline font-bold">fastkiranadelivery@gmail.com</a></p>
              <p>Hours: <strong>6:00 AM – 12:00 Midnight (Daily)</strong></p>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
