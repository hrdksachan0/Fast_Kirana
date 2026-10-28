import { Suspense } from 'react'
import { Metadata } from 'next'
import { AppRedirectClient } from './app-redirect-client'

export const metadata: Metadata = {
  title: 'FastMinute App - 10-Minute Grocery & Food Delivery in Ghatampur',
  description:
    'Download or open the FastMinute app for 10-25 minute delivery of fresh vegetables, daily dairy milk, grocery essentials, and hot restaurant food in Ghatampur.',
  openGraph: {
    title: '⚡ FastMinute App - 10-Minute Delivery in Ghatampur',
    description:
      'Fresh groceries, milk, vegetables & delicious restaurant meals delivered straight to your door in 10-25 mins. Tap to open or install!',
    url: 'https://www.fastminute.in/app',
    siteName: 'FastMinute Express',
    images: [
      {
        url: 'https://www.fastminute.in/brand/fastkirana_app_icon.png',
        width: 512,
        height: 512,
        alt: 'FastMinute App Icon',
      },
    ],
    type: 'website',
  },
  twitter: {
    card: 'summary',
    title: '⚡ FastMinute - 10-Minute Delivery App',
    description:
      'Ghatampur’s fastest delivery app. Order groceries & food in 10-25 minutes.',
    images: ['https://www.fastminute.in/brand/fastkirana_app_icon.png'],
  },
}

export default function AppPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-neutral-950 text-white flex flex-col items-center justify-center p-4">
          <div className="w-12 h-12 rounded-full border-4 border-emerald-500 border-t-transparent animate-spin mb-4" />
          <p className="text-neutral-400 text-sm font-medium">Opening FastMinute...</p>
        </div>
      }
    >
      <AppRedirectClient />
    </Suspense>
  )
}
