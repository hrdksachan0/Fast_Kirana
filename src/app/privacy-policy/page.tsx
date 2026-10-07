import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Privacy Policy - Fast Kirana',
  description: 'Privacy Policy and Data Protection guidelines for Fast Kirana app and website users.',
}

export default function PrivacyPolicyPage() {
  return (
    <div className="bg-background min-h-screen py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-3xl mx-auto bg-card p-8 rounded-2xl shadow-sm border border-border">
        <h1 className="text-3xl font-extrabold text-foreground tracking-tight mb-6">
          Privacy Policy — FastKirana
        </h1>
        <p className="text-muted-foreground text-sm mb-8">
          Last Updated: October 7, 2026 | Applicable to: FastKirana Android App (com.fastkirana.app) and fastkirana.in
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed">
          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">1. Introduction</h2>
            <p className="text-muted-foreground">
              FastKirana ("we", "us", or "our") operates the FastKirana mobile application (Package ID: <strong>com.fastkirana.app</strong>) and the official website (<a href="https://www.fastkirana.in" className="text-primary hover:underline">www.fastkirana.in</a>). This page informs you of our policies regarding the collection, use, and disclosure of personal data when you use our Service.
            </p>
            <p className="text-muted-foreground mt-2">
              By using FastKirana, you agree to the collection and use of information in accordance with this policy. We do not sell your personal data to any third party.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">2. Information Collection and Use</h2>
            <p className="text-muted-foreground">
              For a better experience while using our Service, we may require you to provide us with certain personally identifiable information, including but not limited to:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-1 text-muted-foreground">
              <li><strong>Name:</strong> To address you and personalize your account.</li>
              <li><strong>Email Address:</strong> For login authentication, transaction invoices, and customer support.</li>
              <li><strong>Phone Number:</strong> For secure OTP authentication and coordination of delivery.</li>
              <li><strong>Location Data (Foreground and Background):</strong> FastKirana collects location data to determine service availability in your area (e.g. Ghatampur), calculate delivery fees, navigate delivery personnel to your selected drop-off address, and provide live delivery tracking while an order is active.</li>
              <li><strong>Purchase & Payment Information:</strong> To track order status, process refunds via authorized payment gateways (e.g. Cashfree), and show previous checkout histories. We do not store sensitive payment card or bank PIN credentials.</li>
              <li><strong>Device & Push Notification Tokens:</strong> Firebase Cloud Messaging (FCM) tokens to deliver transactional order updates and delivery alerts.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">3. Account and Data Deletion</h2>
            <p className="text-muted-foreground font-semibold">
              You have the right to request the deletion of your account and all associated personal data at any time.
            </p>
            <p className="text-muted-foreground mt-2">
              Users can delete their account directly inside the FastKirana App via <strong>Settings &gt; Delete Account</strong>, or submit a data deletion request by emailing us at <a href="mailto:fastkiranadelivery@gmail.com" className="text-primary hover:underline font-medium">fastkiranadelivery@gmail.com</a>. Upon receipt, all personal identity records, saved addresses, and profile data will be permanently purged from our active databases within 7 business days.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">4. Security</h2>
            <p className="text-muted-foreground">
              We value your trust in providing us your personal information, thus we are striving to use commercially acceptable means of protecting it. All data is transmitted securely using HTTPS (encryption in transit) and stored securely behind verified authentication firewalls.
            </p>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">5. Third-Party Service Providers</h2>
            <p className="text-muted-foreground">
              We may employ third-party companies and individuals due to the following reasons:
            </p>
            <ul className="list-disc pl-5 mt-2 space-y-1 text-muted-foreground">
              <li><strong>Google Maps Platform:</strong> For geocoding delivery addresses, calculating distance, and optimizing delivery routes.</li>
              <li><strong>Firebase (Google LLC):</strong> For Cloud Messaging push notifications (FCM) and delivery status alerts.</li>
              <li><strong>Cashfree Payments India:</strong> To process digital payments, UPI, and refunds securely complying with RBI security protocols.</li>
              <li><strong>Supabase / Cloud Infrastructure:</strong> For encrypted database hosting and authentication services.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">6. Changes to This Privacy Policy</h2>
            <p className="text-muted-foreground">
              We may update our Privacy Policy from time to time. Thus, you are advised to review this page periodically for any changes. We will notify you of any changes by posting the new Privacy Policy on this page.
            </p>
          </section>

          <section className="border-t border-border pt-6 mt-8">
            <h2 className="text-xl font-bold text-foreground mb-3">7. Contact Us</h2>
            <p className="text-muted-foreground">
              If you have any questions, feedback, or data deletion requests regarding this Privacy Policy, please contact us:
            </p>
            <p className="text-foreground font-semibold mt-2">
              Email: <a href="mailto:fastkiranadelivery@gmail.com" className="text-rose-600 hover:underline font-medium">fastkiranadelivery@gmail.com</a>
            </p>
          </section>
        </div>
      </div>
    </div>
  )
}
