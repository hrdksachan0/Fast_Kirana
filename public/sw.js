self.addEventListener('install', (event) => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})

self.addEventListener('fetch', (event) => {
  // Pass-through to network, satisfies PWA requirements
})

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
      // If user already has the tracking page (or any page for this order) open, just focus it
      for (let i = 0; i < windowClients.length; i++) {
        const client = windowClients[i];
        if (orderId && client.url.includes(`/order/${orderId}`) && 'focus' in client) {
          return client.focus();
        }
      }
      // If user has any FastKirana tab open, navigate that tab instead of opening new window
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
