import { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Terms of Service - FastKirana',
  description: 'Terms of Service and User Agreement for FastKirana quick-commerce and food delivery services.',
}

export default function TermsPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-card p-6 sm:p-10 rounded-2xl shadow-sm border border-border">
        <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-2">
          Terms of Service
        </h1>
        <p className="text-muted-foreground text-sm mb-8">
          Last Updated: September 15, 2026
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed text-sm sm:text-base">
          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">1. Agreement to Terms</h2>
            <p className="text-muted-foreground">
              By accessing or using FastKirana website (<a href="https://www.fastkirana.in" className="text-rose-600 hover:underline">www.fastkirana.in</a>) or mobile applications, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our services.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">2. Service Description</h2>
            <p className="text-muted-foreground">
              FastKirana is a hyperlocal quick-commerce platform providing 10–20 minute delivery of daily groceries, fresh dairy, packaged snacks, beverages, household essentials, and prepared food from local partner restaurants across Ghatampur, Kanpur Nagar, Uttar Pradesh.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">3. User Accounts and Verification</h2>
            <p className="text-muted-foreground">
              To place orders, you must provide a valid mobile phone number and verify it via One-Time Password (OTP). You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">4. Pricing, Payments & Billing</h2>
            <ul className="list-disc pl-5 space-y-2 text-muted-foreground">
              <li>All prices listed on FastKirana are in Indian Rupees (INR ₹) inclusive of applicable taxes unless stated otherwise.</li>
              <li>We accept payments via UPI (Google Pay, PhonePe, Paytm, BHIM), Credit/Debit Cards, Net Banking, Digital Wallets, and Cash on Delivery (COD).</li>
              <li>Payments made online are processed securely through RBI-compliant, PCI-DSS certified payment gateway partners (such as Cashfree).</li>
              <li>Delivery charges are calculated dynamically based on distance from our dark store/restaurants as per our <Link href="/shipping-policy" className="text-rose-600 hover:underline font-medium">Shipping Policy</Link>.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">5. Order Acceptance & Fulfillment</h2>
            <p className="text-muted-foreground">
              While we strive to ensure 100% item availability, occasionally products or prepared food items may go out of stock. In such cases, we will inform you promptly and issue an instant refund for prepaid items as per our <Link href="/refund-policy" className="text-rose-600 hover:underline font-medium">Refund Policy</Link>.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">6. User Conduct & Prohibited Uses</h2>
            <p className="text-muted-foreground">
              Users agree not to misuse the platform, provide fraudulent delivery addresses, abuse promotional coupon codes, or harass delivery personnel. We reserve the right to suspend or terminate accounts engaging in abusive behavior.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">7. Limitation of Liability & Governing Law</h2>
            <p className="text-muted-foreground">
              These terms are governed by the laws of India. Any disputes arising out of or related to our services shall be subject to the exclusive jurisdiction of the competent courts in Kanpur Nagar, Uttar Pradesh.
            </p>
          </section>

          <section className="border-t border-border pt-6 mt-8">
            <h2 className="text-xl font-bold text-foreground mb-3">8. Grievance Redressal & Contact</h2>
            <p className="text-muted-foreground">
              For any questions, grievances, or clarifications regarding these Terms of Service:
            </p>
            <div className="mt-3 text-muted-foreground space-y-1">
              <p><strong>FastKirana Support Desk</strong></p>
              <p>NH34, Ghatampur Market, Kanpur Nagar, UP - 209206</p>
              <p>Email: <a href="mailto:fastkiranadelivery@gmail.com" className="text-rose-600 hover:underline font-medium">fastkiranadelivery@gmail.com</a></p>
              <p>Phone / WhatsApp: <a href="tel:+917054470303" className="text-rose-600 hover:underline font-medium">+91 70544 70303</a></p>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
