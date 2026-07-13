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
          Privacy Policy
        </h1>
        <p className="text-muted-foreground text-sm mb-8">
          Last Updated: July 14, 2026
        </p>

        <div className="space-y-8 text-foreground/90 leading-relaxed">
          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">1. Introduction</h2>
            <p className="text-muted-foreground">
              Fast Kirana ("we", "us", or "our") built the Fast Kirana app and website as a commercial service. This service is provided at no cost for app downloads and is intended for use "as is".
            </p>
            <p className="text-muted-foreground mt-2">
              If you choose to use our Service, then you agree to the collection and use of information in relation to this policy. The personal information that we collect is used for providing and improving the Service. We will not use or share your information with anyone except as described in this Privacy Policy.
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
              <li><strong>Location Data:</strong> To check service availability in your area (e.g. Ghatampur) and navigate delivery partners to your exact address.</li>
              <li><strong>Purchase & Payment History:</strong> To track order status, process refunds, and show previous checkout histories.</li>
            </ul>
          </section>

          <section>
            <h2 className="text-xl font-bold text-foreground mb-3">3. Account and Data Deletion</h2>
            <p className="text-muted-foreground font-semibold">
              You have the right to request the deletion of your account and all associated personal data at any time.
            </p>
            <p className="text-muted-foreground mt-2">
              To request account and data deletion, please contact our support team directly at: <a href="mailto:iamuv2609@gmail.com" className="text-rose-600 hover:underline font-medium">iamuv2609@gmail.com</a>. We will process your request and securely purge all your personal identity records from our production databases within 7 business days.
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
              <li>To facilitate our Service (e.g. database services, image hosting).</li>
              <li>To process transactions securely (e.g. Razorpay payment integration).</li>
              <li>To send transactional SMS notifications (OTP) and push notifications.</li>
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
              Email: <a href="mailto:iamuv2609@gmail.com" className="text-rose-600 hover:underline font-medium">iamuv2609@gmail.com</a>
            </p>
          </section>
        </div>
      </div>
    </div>
  )
}
