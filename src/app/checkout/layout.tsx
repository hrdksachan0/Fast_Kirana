import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Checkout - FastKirana',
  description: 'Complete your FastKirana grocery and food order.',
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
