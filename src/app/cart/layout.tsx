import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Shopping Cart - FastKirana',
  description: 'View your selected groceries and food items in your FastKirana cart. Checkout now for instant delivery.',
  openGraph: {
    title: 'Fast Kirana - Online Grocery Delivery in Ghatampur, Kanpur',
    description: 'Order groceries online and get them delivered fast in Ghatampur, Kanpur Nagar.',
    url: 'https://www.fastkirana.in/cart',
    siteName: 'Fast Kirana',
    images: [
      {
        url: '/brand/fastkirana_app_icon.png?v=3',
        width: 1024,
        height: 1024,
        alt: 'Fast Kirana Logo',
        type: 'image/png',
      },
    ],
    locale: 'en_IN',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Fast Kirana - Online Grocery Delivery in Ghatampur',
    description: 'Order groceries online and get them delivered fast in Ghatampur, Kanpur.',
    images: ['/brand/fastkirana_app_icon.png?v=3'],
  },
  robots: {
    index: false,
    follow: false,
    googleBot: {
      index: false,
      follow: false,
    },
  },
}

export default function CartLayout({ children }: { children: React.ReactNode }) {
  return children
}
