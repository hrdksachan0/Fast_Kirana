import { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Checkout - FastMinute',
  description: 'Complete your FastMinute grocery and food order.',
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
