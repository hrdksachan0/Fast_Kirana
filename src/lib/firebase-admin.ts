import admin from 'firebase-admin'

function initAdmin() {
  if (admin.apps.length) return admin.apps[0]

  const projectId = process.env.FIREBASE_PROJECT_ID
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL
  const privateKey = process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n')

  if (projectId && clientEmail && privateKey) {
    try {
      return admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      })
    } catch (e) {
      console.warn('Failed to initialize Firebase Admin:', e)
    }
  }

  const credJson = process.env.FIREBASE_CREDENTIALS
  if (credJson) {
    try {
      const parsed = JSON.parse(credJson)
      return admin.initializeApp({
        credential: admin.credential.cert(parsed),
      })
    } catch (e) {
      console.warn('Failed to initialize Firebase from JSON:', e)
    }
  }

  return null
}

initAdmin()

export const fcmMessaging = admin.apps.length > 0 ? admin.messaging() : null

