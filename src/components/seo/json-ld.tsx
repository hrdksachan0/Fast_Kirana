export function JsonLdSchema() {
  const baseUrl = 'https://www.fastminute.in'

  const localBusinessSchema = {
    '@context': 'https://schema.org',
    '@type': ['GroceryStore', 'DeliveryService'],
    '@id': `${baseUrl}/#store`,
    name: 'FastMinute - 10-Minute Grocery & Food Delivery',
    alternateName: ['Fast Minute', 'FastMinute Ghatampur', 'Fast Minute Delivery', 'FastKirana', 'FastMinute App'],
    url: baseUrl,
    logo: `${baseUrl}/brand/fastkirana_app_icon.png`,
    image: `${baseUrl}/brand/fastkirana_app_icon.png`,
    description:
      'FastMinute (Fast Minute) is Ghatampur’s premier 10-minute online grocery dark store delivery service. Order fresh fruits, vegetables, milk, dairy, snacks, atta, rice, dal, and restaurant meals with fast doorstep delivery in Ghatampur, Kanpur Nagar, Uttar Pradesh (209206).',
    disambiguatingDescription:
      'FastMinute (Fast Minute) is an Indian quick-commerce company and delivery service in Ghatampur, Kanpur Nagar, Uttar Pradesh, India. It is a local grocery and food delivery service, not a music track or general timer.',
    telephone: '+91-7054470303',
    priceRange: '₹',
    currenciesAccepted: 'INR',
    paymentAccepted: 'Cash on Delivery, UPI, Google Pay, PhonePe, Paytm, BHIM, Credit Card, Debit Card',
    address: {
      '@type': 'PostalAddress',
      streetAddress: 'Main Market Road, Near Power House, NH34',
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
        closes: '23:59',
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
    alternateName: ['FastMinute', 'Fast Minute', 'FastMinute App', 'Fast Minute Grocery'],
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
      'Official FastMinute (Fast Minute) app for instant 10-minute grocery, daily milk, fresh fruits & vegetables, snacks, and restaurant food delivery in Ghatampur, Kanpur Nagar.',
  }

  const websiteSchema = {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    '@id': `${baseUrl}/#website`,
    url: baseUrl,
    name: 'FastMinute',
    alternateName: ['Fast Minute', 'FastMinute Grocery', 'FastMinute India', 'FastMinute Ghatampur'],
    description:
      'FastMinute (Fast Minute) - Official website for 10-minute online grocery, dairy, fresh vegetables & food delivery in Ghatampur, Kanpur Nagar.',
    publisher: {
      '@id': `${baseUrl}/#organization`,
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
        name: 'What is FastMinute (Fast Minute)?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute (also written as Fast Minute) is Ghatampur’s premier 10-minute online grocery and food delivery platform. We deliver fresh milk, vegetables, fruits, packaged foods, snacks, dairy, cold drinks, and hot restaurant food directly to your doorstep in Ghatampur, Kanpur Nagar (209206).',
        },
      },
      {
        '@type': 'Question',
        name: 'How fast is grocery delivery in Ghatampur?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute delivers orders in 10-15 minutes across Ghatampur market and surrounding residential areas in Kanpur Nagar.',
        },
      },
      {
        '@type': 'Question',
        name: 'What payment options are available on FastMinute?',
        acceptedAnswer: {
          '@type': 'Answer',
          text: 'FastMinute supports Cash on Delivery (COD), UPI payments (Google Pay, PhonePe, Paytm, BHIM), and Debit/Credit card options.',
        },
      },
    ],
  }

  const organizationSchema = {
    '@context': 'https://schema.org',
    '@type': ['Organization', 'OnlineBusiness'],
    '@id': `${baseUrl}/#organization`,
    name: 'FastMinute',
    alternateName: ['Fast Minute', 'FastMinute Services', 'FastMinute Grocery', 'FastMinute App', 'FastKirana', 'Fast Minute Delivery'],
    legalName: 'FastMinute Services',
    url: baseUrl,
    logo: `${baseUrl}/brand/fastkirana_app_icon.png`,
    image: `${baseUrl}/brand/fastkirana_app_icon.png`,
    email: 'help@fastminute.in',
    telephone: '+91-7054470303',
    description:
      'FastMinute (Fast Minute) is an Indian quick-commerce company providing 10-minute doorstep grocery, daily essentials, and restaurant food delivery in Ghatampur, Kanpur Nagar, Uttar Pradesh.',
    disambiguatingDescription:
      'FastMinute is a quick-commerce grocery delivery company in Uttar Pradesh, India. Not affiliated with any musical recording or audio track.',
    address: {
      '@type': 'PostalAddress',
      streetAddress: 'Main Market Road, Near Power House, NH34',
      addressLocality: 'Ghatampur',
      addressRegion: 'Uttar Pradesh',
      postalCode: '209206',
      addressCountry: 'IN',
    },
    contactPoint: [
      {
        '@type': 'ContactPoint',
        telephone: '+91-7054470303',
        contactType: 'customer service',
        areaServed: 'IN',
        availableLanguage: ['en', 'hi'],
      },
    ],
    sameAs: [
      'https://play.google.com/store/apps/details?id=com.fastkirana.app',
      'https://www.facebook.com/fastkirana',
      'https://www.instagram.com/fastkirana',
    ],
  }

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationSchema) }}
      />
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
