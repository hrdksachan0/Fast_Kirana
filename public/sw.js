const CACHE_NAME = 'fastkirana-v2'
const STATIC_ASSETS = [
  '/',
  '/manifest.json',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/brand/fastkirana_app_icon.png'
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

  // Only cache request from the same origin or Cloudinary image assets
  if (url.origin !== self.location.origin && !url.href.includes('cloudinary.com')) return

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

  // 2. Static JS/CSS Assets & Images (Cache-First, falling back to Network)
  const isStaticAsset = 
    url.pathname.startsWith('/_next/static/') || 
    url.pathname.includes('/icons/') || 
    url.pathname.match(/\.(png|jpg|jpeg|gif|webp|svg|ico|woff2)$/i) || 
    url.href.includes('cloudinary.com')

  if (isStaticAsset) {
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

  // 3. Page Routes (Network-First, fallback to cached '/' if offline)
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
        .catch(() => {
          return caches.match('/')
        })
    )
  }
})

// Web Push Notification Listeners (Preserved)
self.addEventListener('push', (event) => {
  if (!event.data) return;
  try {
    const payload = event.data.json();
    const title = payload.title || 'FastKirana Update';
    const options = {
      body: payload.body,
      icon: payload.icon || '/icons/icon-192.png',
      badge: payload.badge || '/icons/badge.png',
      tag: payload.tag || undefined,
      renotify: payload.tag ? true : false,
      data: payload.data || {},
      vibrate: [100, 50, 100],
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
