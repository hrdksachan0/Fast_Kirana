export function JsonLdSchema() {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastkirana.in'

  const localBusinessSchema = {
    '@context': 'https://schema.org',
    '@type': 'GroceryStore',
    '@id': `${baseUrl}/#store`,
    name: 'FastKirana - Online Grocery Delivery Ghatampur',
    alternateName: 'Fast Kirana Ghatampur',
    url: baseUrl,
    logo: `${baseUrl}/brand/fastkirana_app_icon.png`,
    image: `${baseUrl}/brand/fastkirana_app_icon.png`,
    description:
      'FastKirana is Ghatampur’s premier online grocery dark store delivery service. Order fresh fruits, vegetables, milk, dairy, snacks, atta, rice, dal, and daily essentials with fast doorstep delivery in Ghatampur, Kanpur Nagar, Uttar Pradesh.',
    telephone: '+91-8112849854',
    priceRange: '₹',
    currenciesAccepted: 'INR',
    paymentAccepted: 'Cash, UPI, Google Pay, PhonePe, Paytm, BHIM, Credit Card, Debit Card',
    address: {
      '@type': 'PostalAddress',
      streetAddress: 'Main Market Road, Near Power House',
      addressLocality: 'Ghatampur',
      addressRegion: 'Uttar Pradesh',
      postalCode: '209206',
      addressCountry: 'IN',
    },
    geo: {
      '@type': 'GeoCoordinates',
      latitude: 26.1554,
      longitude: 80.1633,
    },
    areaServed: [
      {
        '@type': 'AdministrativeArea',
        name: 'Ghatampur',
      },
      {
        '@type': 'AdministrativeArea',
        name: 'Kanpur Nagar',
      },
      {
        '@type': 'AdministrativeArea',
        name: 'Uttar Pradesh',
      },
    ],
    openingHoursSpecification: [
      {
        '@type': 'OpeningHoursSpecification',
        dayOfWeek: [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ],
        opens: '06:00',
        closes: '23:00',
      },
    ],
    sameAs: [
      'https://www.facebook.com/fastkirana',
      'https://www.instagram.com/fastkirana',
    ],
  }

  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    '@id': `${baseUrl}/#website`,
    url: baseUrl,
    name: 'FastKirana',
    publisher: {
      '@id': `${baseUrl}/#store`,
    },
    potentialAction: {
      '@type': 'SearchAction',
      target: {
        '@type': 'EntryPoint',
        urlTemplate: `${baseUrl}/search?q={search_term_string}`,
      },
      'query-input': 'required name=search_term_string',
    },
  }

  const faqSchema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: [
      {
        '@type': 'Question',
        name: 'What is FastKirana?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastKirana is Ghatampur’s premier online grocery delivery platform. We deliver fresh milk, vegetables, fruits, packaged foods, snacks, dairy, beverage, and kirana items directly to your doorstep in Ghatampur, Kanpur Nagar.',
        },
      },
      {
        '@type': 'Question',
        name: 'How fast is grocery delivery in Ghatampur?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastKirana delivers orders fast across Ghatampur market and surrounding residential areas in Kanpur Nagar.',
        },
      },
      {
        '@type': 'Question',
        name: 'What payment options are available on FastKirana?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastKirana supports Cash on Delivery (COD), UPI payments (Google Pay, PhonePe, Paytm, BHIM), and Razorpay Debit/Credit card options.',
        },
      },
    ],
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(localBusinessSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(websiteSchema) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqSchema) }}
      />
    </>
  )
}
