const CACHE_NAME = 'fastkirana-v4'
const STATIC_ASSETS = [
  '/',
  '/offline',
  '/manifest.json',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/brand/fastkirana_app_icon.png',
  '/sounds/order_chime.mp3'
]

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS)
    })
  )
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      )
    }).then(() => self.clients.claim())
  )
})

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)
  
  if (event.request.method !== 'GET') return

  const isMediaCDN = 
    url.origin === self.location.origin ||
    url.href.includes('cloudinary.com') ||
    url.href.includes('supabase.co') ||
    url.href.includes('images.unsplash.com')

  if (!isMediaCDN) return

  // 1. API Calls (Network-First, fallback to cached copy when offline)
  if (url.pathname.startsWith('/api/') && !url.pathname.includes('/auth/')) {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, copy)
            })
          }
          return response
        })
        .catch(() => {
          return caches.match(event.request)
        })
    )
    return
  }

  // 2. Static JS/CSS Assets, Sounds & Multi-CDN Images (Cache-First, falling back to Network)
  const isStaticOrMedia = 
    url.pathname.startsWith('/_next/static/') || 
    url.pathname.includes('/icons/') || 
    url.pathname.includes('/sounds/') || 
    url.pathname.match(/\.(png|jpg|jpeg|gif|webp|svg|ico|woff2|mp3)$/i) || 
    url.href.includes('cloudinary.com') ||
    url.href.includes('supabase.co') ||
    url.href.includes('images.unsplash.com')

  if (isStaticOrMedia) {
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) return cachedResponse
        
        return fetch(event.request).then((response) => {
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, copy)
            })
          }
          return response
        })
      })
    )
    return
  }

  // 3. Page Routes (Network-First, fallback to cached page or '/offline' if offline)
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((response) => {
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, copy)
            })
          }
          return response
        })
        .catch(async () => {
          const cachedMatch = await caches.match(event.request)
          if (cachedMatch) return cachedMatch
          const offlinePage = await caches.match('/offline')
          return offlinePage || caches.match('/')
        })
    )
  }
})

// Web Push Notification Listeners (With Live Stage Alerts & Vibration)
self.addEventListener('push', (event) => {
  if (!event.data) return;
  try {
    const payload = event.data.json();
    const title = payload.title || 'FastKirana Express ⚡';
    const isOrderUpdate = Boolean(
      payload.data?.orderId ||
      payload.data?.status ||
      payload.data?.type === 'ORDER_STATUS_UPDATE' ||
      title.includes('Order') ||
      title.includes('Rider') ||
      title.includes('Arriving')
    );

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
    };
    event.waitUntil(self.registration.showNotification(title, options));
  } catch (err) {
    console.error('Push handling error:', err);
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const orderId = event.notification.data?.orderId;
  const urlToOpen = orderId ? `/order/${orderId}/track` : '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      // If user already has the tracking page open, focus it
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (orderId && client.url.includes(`/order/${orderId}`) && 'focus' in client) {
          return client.focus();
        }
      }
      // If user has any FastKirana tab open, navigate that tab instead of opening a new window
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if ('focus' in client && 'navigate' in client) {
          return client.focus().then(() => client.navigate(urlToOpen));
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});
