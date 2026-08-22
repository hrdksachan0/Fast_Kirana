/**
 * Single-instance cached Google Maps JS API script loader.
 * Prevents multiple dynamic script insertions across components.
 */

let mapsLoaderPromise: Promise<void> | null = null

interface WindowWithGoogle extends Window {
  google?: { maps?: unknown }
}

export function loadGoogleMapsScript(apiKey?: string): Promise<void> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Google Maps script can only be loaded in the browser.'))
  }

  // Already loaded globally
  const windowWithGoogle = window as WindowWithGoogle
  if (windowWithGoogle.google && windowWithGoogle.google.maps) {
    return Promise.resolve()
  }

  // Already loading
  if (mapsLoaderPromise) {
    return mapsLoaderPromise
  }

  const key = apiKey || process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY || ''
  if (!key) {
    return Promise.reject(new Error('NEXT_PUBLIC_GOOGLE_MAPS_API_KEY is not defined.'))
  }

  mapsLoaderPromise = new Promise((resolve, reject) => {
    const existingScript = document.getElementById('google-maps-sdk')
    if (existingScript) {
      existingScript.addEventListener('load', () => resolve())
      existingScript.addEventListener('error', (err) => reject(err))
      return
    }

    const script = document.createElement('script')
    script.id = 'google-maps-sdk'
    script.src = `https://maps.googleapis.com/maps/api/js?key=${key}&libraries=places,geometry`
    script.async = true
    script.defer = true

    script.onload = () => resolve()
    script.onerror = (err) => {
      mapsLoaderPromise = null
      reject(err)
    }

    document.head.appendChild(script)
  })

  return mapsLoaderPromise
}
