export function JsonLdSchema() {
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'https://www.fastminute.in'

  const localBusinessSchema = {
    '@context': 'https://schema.org',
    '@type': 'GroceryStore',
    '@id': `${baseUrl}/#store`,
    name: 'FastMinute - Online Grocery Delivery Ghatampur',
    alternateName: 'FastMinute Ghatampur',
    url: baseUrl,
    logo: `${baseUrl}/brand/fastkirana_app_icon.png`,
    image: `${baseUrl}/brand/fastkirana_app_icon.png`,
    description:
      'FastMinute is Ghatampur’s premier online grocery dark store delivery service. Order fresh fruits, vegetables, milk, dairy, snacks, atta, rice, dal, and daily essentials with fast doorstep delivery in Ghatampur, Kanpur Nagar, Uttar Pradesh.',
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
      'https://play.google.com/store/apps/details?id=com.fastkirana.app',
      'https://www.facebook.com/fastkirana',
      'https://www.instagram.com/fastkirana',
    ],
  }

  const mobileAppSchema = {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    '@id': `${baseUrl}/#mobileapp`,
    name: 'FastMinute: Deliver in Minutes',
    alternateName: ['FastMinute', 'Fast Minute', 'FastMinute App'],
    operatingSystem: 'Android',
    applicationCategory: 'ShoppingApplication',
    identifier: 'com.fastkirana.app',
    url: 'https://play.google.com/store/apps/details?id=com.fastkirana.app',
    downloadUrl: 'https://play.google.com/store/apps/details?id=com.fastkirana.app',
    installUrl: 'https://play.google.com/store/apps/details?id=com.fastkirana.app',
    image: `${baseUrl}/brand/fastkirana_app_icon.png`,
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'INR',
    },
    author: {
      '@type': 'Organization',
      name: 'FastMinute Services',
      url: baseUrl,
    },
    description:
      'Official FastMinute app for instant grocery, daily milk, fresh fruits & vegetables, snacks, and restaurant food delivery in Ghatampur, Kanpur Nagar.',
  }

  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    '@id': `${baseUrl}/#website`,
    url: baseUrl,
    name: 'FastMinute',
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
        name: 'What is FastMinute?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute is Ghatampur’s premier online grocery delivery platform. We deliver fresh milk, vegetables, fruits, packaged foods, snacks, dairy, beverage, and kirana items directly to your doorstep in Ghatampur, Kanpur Nagar.',
        },
      },
      {
        '@type': 'Question',
        name: 'How fast is grocery delivery in Ghatampur?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute delivers orders fast across Ghatampur market and surrounding residential areas in Kanpur Nagar.',
        },
      },
      {
        '@type': 'Question',
        name: 'What payment options are available on FastMinute?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute supports Cash on Delivery (COD), UPI payments (Google Pay, PhonePe, Paytm, BHIM), and Cashfree Debit/Credit card options.',
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
        dangerouslySetInnerHTML={{ __html: JSON.stringify(mobileAppSchema) }}
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
