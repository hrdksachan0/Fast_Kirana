import { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Privacy Policy - FastMinute',
  description: 'Privacy Policy, Data Protection Guidelines, and User Rights under India\'s DPDP Act 2023 for FastMinute app and website.',
}

export default function PrivacyPolicyPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-card p-6 sm:p-10 rounded-2xl shadow-sm border border-border">
        <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-2">
          Privacy Policy — FastMinute
        </h1>
        <p className="text-muted-foreground text-xs sm:text-sm mb-8">
          Last Updated: November 12, 2026 | Applicable to: FastMinute Android App (com.fastkirana.app) and fastminute.in
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed text-sm sm:text-base">
          {/* Section 1 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">1. Introduction &amp; Commitment</h2>
            <p className="text-muted-foreground">
              FastMinute (&ldquo;we&rdquo;, &ldquo;us&rdquo;, or &ldquo;our&rdquo;) operates the FastMinute hyperlocal delivery mobile application (Package ID: <strong>com.fastkirana.app</strong>) and the official website (<a href="https://www.fastminute.in" className="text-primary hover:underline font-semibold">www.fastminute.in</a>).
            </p>
            <p className="text-muted-foreground mt-2">
              We are deeply committed to protecting your privacy and personal data in strict compliance with India&apos;s <strong>Digital Personal Data Protection Act, 2023 (DPDP Act)</strong> and the Information Technology (Reasonable Security Practices and Procedures and Sensitive Personal Data or Information) Rules, 2011. We collect only what is strictly required to deliver your groceries and food orders, and we never sell your personal information.
            </p>
          </section>

          {/* Section 2 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">2. Personal Data We Collect</h2>
            <p className="text-muted-foreground">
              Depending on how you interact with FastMinute, we may collect the following categories of information:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-2 text-muted-foreground">
              <li>
                <strong>Identity &amp; Contact Data:</strong> Mobile phone number (for secure One-Time Password [OTP] login and rider coordination), full name, and email address (for transactional tax invoices and customer receipts).
              </li>
              <li>
                <strong>Delivery &amp; Location Data:</strong> Precise drop-off coordinates, house/flat number, street name, and pincode (e.g. Ghatampur 209206) collected on-demand to confirm serviceability, calculate delivery fees, navigate our riders, and provide live doorstep tracking while an order is active.
              </li>
              <li>
                <strong>Order &amp; Transaction History:</strong> Items ordered, quantities, timestamps, transaction amounts, payment method selected (COD, UPI, Card, or Wallet), and payment gateway reference tokens. <em>We never store debit/credit card numbers, CVVs, or banking PINs.</em>
              </li>
              <li>
                <strong>Device &amp; Notification Data:</strong> Device operating system, IP address, and Firebase Cloud Messaging (FCM) tokens to deliver transactional alerts when your order is packed and out for delivery.
              </li>
              <li>
                <strong>Product Search Queries:</strong> Search text typed into our store search bar (e.g. &ldquo;fresh milk&rdquo; or &ldquo;tea biscuits&rdquo;) to locate matching inventory. Search queries are stripped of personal identifiers.
              </li>
            </ul>
          </section>

          {/* Section 3 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">3. Purpose of Processing (Why We Collect Data)</h2>
            <p className="text-muted-foreground">We process your personal information strictly for legitimate commercial and fulfillment purposes:</p>
            <ul className="list-disc pl-5 mt-2 space-y-1.5 text-muted-foreground">
              <li>To fulfill, pack, dispatch, and deliver grocery and food orders to your doorstep within 10–20 minutes.</li>
              <li>To authenticate your identity securely via SMS or WhatsApp OTP without requiring vulnerable passwords.</li>
              <li>To facilitate seamless online payments and issue instant refunds through authorized banking partners.</li>
              <li>To provide customer support for missing, damaged, or substituted items.</li>
              <li>To fulfill statutory tax, accounting, and invoicing obligations under Indian law (GST &amp; Consumer Protection Act).</li>
            </ul>
          </section>

          {/* Section 4 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">4. Third-Party Service Providers</h2>
            <p className="text-muted-foreground">
              We never sell or commercialize your personal data to advertising brokers. We only share essential data with verified infrastructure and delivery partners:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-2 text-muted-foreground">
              <li>
                <strong>Delivery Personnel (Riders):</strong> Your drop-off address, name, and contact number are provided to the designated delivery rider solely to complete the active delivery.
              </li>
              <li>
                <strong>Payment Aggregators (Cashfree Payments India):</strong> Digital transactions are processed via RBI-authorized, PCI-DSS Level 1 certified Cashfree payment gateway. Card data is tokenized securely on their certified servers.
              </li>
              <li>
                <strong>Mapping &amp; Navigation (Google Maps Platform):</strong> Addresses are geocoded to compute distances and guide riders efficiently. Maps scripts load strictly on-demand.
              </li>
              <li>
                <strong>Push Notifications (Firebase / Google LLC):</strong> Encrypted device tokens deliver live order updates.
              </li>
              <li>
                <strong>Transactional Email (Resend):</strong> Used exclusively to deliver authentication OTPs and official order invoices.
              </li>
              <li>
                <strong>AI Search Understanding (Google Gemini API):</strong> Used to interpret natural-language product search intents. Zero customer PII (no names, phones, or addresses) is transmitted to AI models.
              </li>
              <li>
                <strong>Error Diagnostics (Sentry):</strong> Used to identify crashes and technical bugs. Session diagnostics are gated behind user consent, and all form inputs and text remain strictly masked.
              </li>
            </ul>
          </section>

          {/* Section 5 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">5. Data Retention &amp; Lifecycle</h2>
            <ul className="list-disc pl-5 mt-2 space-y-2 text-muted-foreground">
              <li>
                <strong>Active Accounts:</strong> Maintained while your account remains active.
              </li>
              <li>
                <strong>Guest Sessions &amp; Abandoned Carts:</strong> Automatically purged by automated background lifecycle routines after 2 to 7 days.
              </li>
              <li>
                <strong>Statutory Financial Records:</strong> Order invoices and transaction logs are retained in anonymized format for statutory periods required under Indian Goods and Services Tax (GST) rules, after which they are permanently expunged.
              </li>
            </ul>
          </section>

          {/* Section 6 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">6. Your Rights Under the DPDP Act 2023</h2>
            <p className="text-muted-foreground">You maintain full sovereignty over your personal data:</p>
            <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs sm:text-sm">
              <div className="p-3.5 rounded-xl bg-muted/40 border border-border">
                <h4 className="font-bold text-foreground mb-1">Right to Access &amp; Portability</h4>
                <p className="text-muted-foreground text-xs leading-relaxed">
                  Download an instant, offline machine-readable copy of your personal data, addresses, and order history from <strong>My Account &gt; Download My Data (JSON)</strong>.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-muted/40 border border-border">
                <h4 className="font-bold text-foreground mb-1">Right to Erasure (Delete Account)</h4>
                <p className="text-muted-foreground text-xs leading-relaxed">
                  Permanently purge and anonymize your account, addresses, and device subscriptions at any time directly in <strong>My Account &gt; Delete Account</strong>.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-muted/40 border border-border">
                <h4 className="font-bold text-foreground mb-1">Right to Rectification</h4>
                <p className="text-muted-foreground text-xs leading-relaxed">
                  Update or correct your profile details, mobile number, or delivery addresses at any time in your profile dashboard.
                </p>
              </div>

              <div className="p-3.5 rounded-xl bg-muted/40 border border-border">
                <h4 className="font-bold text-foreground mb-1">Right to Withdraw Consent</h4>
                <p className="text-muted-foreground text-xs leading-relaxed">
                  Manage or revoke optional cookie and diagnostic preferences at any time via the <strong>Cookie Choices</strong> button in our website footer.
                </p>
              </div>
            </div>
          </section>

          {/* Section 7 */}
          <section>
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">7. Protection of Children</h2>
            <p className="text-muted-foreground">
              FastMinute is intended for users aged 18 and above. In accordance with Section 9 of the DPDP Act 2023, we do not undertake behavioral tracking or targeted advertising directed at children. If you believe a minor has registered without parental authorization, please notify us to purge their records immediately.
            </p>
          </section>

          {/* Section 8 */}
          <section className="border-t border-border pt-6 mt-8">
            <h2 className="text-lg sm:text-xl font-bold text-foreground mb-3">8. Grievance Officer &amp; Redressal</h2>
            <p className="text-muted-foreground">
              In accordance with the Information Technology Act, 2000 and the Digital Personal Data Protection Act, 2023, the details of our designated Grievance Officer are:
            </p>
            <div className="mt-3 p-4 rounded-xl bg-muted/30 border border-border space-y-1 text-xs sm:text-sm text-muted-foreground">
              <p><strong className="text-foreground">Grievance Redressal Officer:</strong> FastMinute Support Desk</p>
              <p><strong className="text-foreground">Operations Address:</strong> NH34, Ghatampur Market, Kanpur Nagar, Uttar Pradesh - 209206, India</p>
              <p><strong className="text-foreground">Email:</strong> <a href="mailto:fastminutedelivery@gmail.com" className="text-primary hover:underline font-semibold">fastminutedelivery@gmail.com</a> / <a href="mailto:help@fastminute.in" className="text-primary hover:underline font-semibold">help@fastminute.in</a></p>
              <p><strong className="text-foreground">Helpline / WhatsApp:</strong> +91 70544 70303</p>
            </div>
          </section>
        </div>
      </div>
    </div>
  )
}
