import admin from 'firebase-admin'

if (!admin.apps.length) {
  const projectId = process.env.FIREBASE_PROJECT_ID
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')

  if (!projectId || !clientEmail || !privateKey) {
    console.warn('Firebase Admin credentials not found in environment variables. FCM push will be disabled.')
  } else {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey,
      }),
    })
    console.log('Firebase Admin initialized for project:', projectId)
  }
}

export const fcmMessaging = admin.messaging()
