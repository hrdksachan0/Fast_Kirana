/**
 * FastKirana Progressive Web App Service Worker (v5)
 * Featuring Offline Catalog Browsing & Instant Stale-While-Revalidate Engine
 */

const CACHE_STATIC = 'fastkirana-static-v5'
const CACHE_CATALOG = 'fastkirana-catalog-v5'
const CACHE_IMAGES = 'fastkirana-images-v5'
const CACHE_PAGES = 'fastkirana-pages-v5'

const ALL_CACHES = [CACHE_STATIC, CACHE_CATALOG, CACHE_IMAGES, CACHE_PAGES]

// Essential assets to pre-cache on install
const PRECACHE_ASSETS = [
  '/',
  '/offline',
  '/category',
  '/manifest.json',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/brand/fastkirana_app_icon.png',
  '/brand/fastkirana-logo.png',
  '/sounds/order_chime.mp3',
  '/api/categories',
  '/api/settings',
  '/api/products?limit=50',
]

// 1. Installation: Pre-cache core shell & catalog snapshot with fault-tolerance
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_STATIC).then(async (cache) => {
      // Use allSettled so transient failures in API endpoints don't abort SW installation
      const promises = PRECACHE_ASSETS.map(async (url) => {
        try {
          const res = await fetch(url, { cache: 'no-cache' })
          if (res.ok) {
            const targetCache = url.startsWith('/api/') ? await caches.open(CACHE_CATALOG) : cache
            await targetCache.put(url, res)
          }
        } catch {
          // Ignore non-fatal pre-cache failures during install
        }
      })
      await Promise.allSettled(promises)
    })
  )
  self.skipWaiting()
})

// 2. Activation: Clean up stale cache versions and claim clients
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys
          .filter((key) => !ALL_CACHES.includes(key))
          .map((key) => caches.delete(key))
      )
    }).then(() => self.clients.claim())
  )
})

// Helper: Network fetch with timeout
function fetchWithTimeout(request, timeoutMs = 2500) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('Network request timed out'))
    }, timeoutMs)

    fetch(request)
      .then((res) => {
        clearTimeout(timer)
        resolve(res)
      })
      .catch((err) => {
        clearTimeout(timer)
        reject(err)
      })
  })
}

// 3. Fetch Event Routing
self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)

  // Only handle GET requests
  if (request.method !== 'GET') return

  // Strictly skip all auth, checkout, order mutations, admin consoles & payment webhooks
  if (
    url.pathname.startsWith('/api/auth/') ||
    url.pathname.startsWith('/api/orders') ||
    url.pathname.startsWith('/api/payment') ||
    url.pathname.startsWith('/api/payments') ||
    url.pathname.startsWith('/order') ||
    url.pathname.startsWith('/checkout') ||
    url.pathname.startsWith('/admin') ||
    url.pathname.startsWith('/account')
  ) {
    return
  }

  // A. Product & Brand Images (Cache-First with Background Network Populate)
  const isImageOrMedia =
    url.pathname.match(/\.(png|jpg|jpeg|gif|webp|svg|ico|mp3)$/i) ||
    url.href.includes('cloudinary.com') ||
    url.href.includes('supabase.co') ||
    url.href.includes('images.unsplash.com') ||
    url.pathname.includes('/brand/') ||
    url.pathname.includes('/icons/') ||
    url.pathname.includes('/sounds/')

  if (isImageOrMedia) {
    event.respondWith(
      caches.open(CACHE_IMAGES).then(async (cache) => {
        const cached = await cache.match(request)
        if (cached) return cached

        try {
          const networkRes = await fetch(request)
          if (networkRes && networkRes.ok) {
            cache.put(request, networkRes.clone())
          }
          return networkRes
        } catch {
          // If offline and image not found, try fallback app icon or return empty
          const fallback = await cache.match('/brand/fastkirana_app_icon.png')
          return fallback || new Response('', { status: 408, statusText: 'Offline Image Unavailable' })
        }
      })
    )
    return
  }

  // B. Next.js Static Chunks & Fonts (Cache-First)
  if (url.pathname.startsWith('/_next/static/') || url.pathname.match(/\.(woff|woff2|ttf|eot)$/i)) {
    event.respondWith(
      caches.open(CACHE_STATIC).then(async (cache) => {
        const cached = await cache.match(request)
        if (cached) return cached

        const networkRes = await fetch(request)
        if (networkRes.ok) {
          cache.put(request, networkRes.clone())
        }
        return networkRes
      })
    )
    return
  }

  // C. Catalog & Storefront APIs (Stale-While-Revalidate Engine)
  const isCatalogApi =
    url.pathname.startsWith('/api/products') ||
    url.pathname.startsWith('/api/categories') ||
    url.pathname.startsWith('/api/restaurants') ||
    url.pathname.startsWith('/api/banners') ||
    url.pathname.startsWith('/api/settings')

  if (isCatalogApi) {
    event.respondWith(
      caches.open(CACHE_CATALOG).then(async (cache) => {
        const cachedRes = await cache.match(request)

        // Asynchronously update cache in the background
        const networkUpdatePromise = fetch(request)
          .then((networkRes) => {
            if (networkRes && networkRes.ok) {
              cache.put(request, networkRes.clone())
            }
            return networkRes
          })
          .catch(() => null)

        // If cached catalog exists, return immediately for instant 0ms offline experience!
        if (cachedRes) {
          event.waitUntil(networkUpdatePromise)
          return cachedRes
        }

        // If not cached, wait for network or return graceful empty payload if completely offline
        try {
          const freshRes = await networkUpdatePromise
          if (freshRes) return freshRes
        } catch {}

        return new Response(JSON.stringify({ products: [], categories: [], offline: true }), {
          headers: { 'Content-Type': 'application/json', 'X-FastKirana-Offline': 'true' }
        })
      })
    )
    return
  }

  // D. Page Navigation & Next.js RSC Prefetches (Fast Network Race with Cache Fallback)
  const isPageNavigation = request.mode === 'navigate' || request.headers.get('RSC') === '1'
  if (isPageNavigation) {
    event.respondWith(
      caches.open(CACHE_PAGES).then(async (cache) => {
        try {
          // Race network with 2.2-second timeout (prevents hanging on slow 2G)
          const networkRes = await fetchWithTimeout(request, 2200)
          if (networkRes && networkRes.ok) {
            cache.put(request, networkRes.clone())
            return networkRes
          }
        } catch {
          // Network failed or timed out — check cache
        }

        const cachedPage = await cache.match(request)
        if (cachedPage) return cachedPage

        // If specific sub-page isn't cached, try fallback to cached root or dedicated offline page
        const offlinePage = await caches.match('/offline')
        return offlinePage || caches.match('/') || new Response('Offline', { status: 503 })
      })
    )
    return
  }
})

// 4. Web Push Notifications
self.addEventListener('push', (event) => {
  if (!event.data) return
  try {
    const payload = event.data.json()
    const title = payload.title || 'FastKirana Express ⚡'
    const isOrderUpdate = Boolean(
      payload.data?.orderId ||
      payload.data?.status ||
      payload.data?.type === 'ORDER_STATUS_UPDATE' ||
      title.includes('Order') ||
      title.includes('Rider') ||
      title.includes('Arriving')
    )

    const options = {
      body: payload.body,
      icon: payload.icon || '/icons/icon-192.png',
      badge: payload.badge || '/icons/badge.png',
      tag: payload.tag || (payload.data?.orderId ? `order_${payload.data.orderId}` : undefined),
      renotify: true,
      data: payload.data || {},
      vibrate: isOrderUpdate ? [200, 100, 200, 100, 300] : [100, 50, 100],
      sound: '/sounds/order_chime.mp3',
      actions: isOrderUpdate ? [
        { action: 'track', title: '📍 Track Live' },
        { action: 'close', title: 'Dismiss' }
      ] : []
    }
    event.waitUntil(self.registration.showNotification(title, options))
  } catch (err) {
    console.error('Push handling error:', err)
  }
})

// 5. Push Notification Click Handling
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const orderId = event.notification.data?.orderId
  const urlToOpen = orderId ? `/order/${orderId}/track` : '/'

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i]
        if (orderId && client.url.includes(`/order/${orderId}`) && 'focus' in client) {
          return client.focus()
        }
      }
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i]
        if ('focus' in client && 'navigate' in client) {
          return client.focus().then(() => client.navigate(urlToOpen))
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen)
      }
    })
  )
})
