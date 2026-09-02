import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Shopping Cart - FastKirana',
  description: 'View your selected groceries and food items in your FastKirana cart.',
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
