import { Suspense } from 'react'
import { Metadata } from 'next'
import { AppRedirectClient } from './app-redirect-client'

export const metadata: Metadata = {
  title: 'FastMinute on Google Play Store',
  description:
    'Download FastMinute (Fast Minute) from Google Play Store for 10-Minute Grocery & Food Delivery in Ghatampur.',
  openGraph: {
    title: 'FastMinute - 10-Minute Delivery App',
    description:
      'Download FastMinute from Google Play Store for fresh groceries, milk, vegetables & delicious restaurant meals in Ghatampur.',
    url: 'https://play.google.com/store/apps/details?id=com.fastkirana.app',
    siteName: 'Google Play Store',
    images: [
      {
        url: 'https://www.fastminute.in/brand/fastkirana_app_icon.png',
        width: 512,
        height: 512,
        alt: 'FastMinute on Google Play',
      },
    ],
  },
  twitter: {
    card: 'summary',
    title: 'FastMinute - 10-Minute Delivery App on Google Play',
    description:
      'Download FastMinute on Google Play Store for 10-minute grocery delivery in Ghatampur.',
    images: ['https://www.fastminute.in/brand/fastkirana_app_icon.png'],
  },
}

export default function AppPage() {
  return (
    <>
      <head>
        <meta
          httpEquiv="refresh"
          content="0; url=https://play.google.com/store/apps/details?id=com.fastkirana.app"
        />
      </head>
      <Suspense
        fallback={
          <div className="min-h-screen bg-neutral-950 text-white flex flex-col items-center justify-center p-4">
            <div className="w-10 h-10 rounded-full border-3 border-emerald-500 border-t-transparent animate-spin mb-4" />
            <p className="text-neutral-400 text-sm font-medium">Opening Google Play Store...</p>
          </div>
        }
      >
        <AppRedirectClient />
      </Suspense>
    </>
  )
}
