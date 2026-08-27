import admin from 'firebase-admin'

const FALLBACK_CREDENTIALS = {
  projectId: 'fastkirana-98a68',
  clientEmail: 'firebase-adminsdk-fbsvc@fastkirana-98a68.iam.gserviceaccount.com',
  privateKey: `-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDmnNIVpENGO4on\nLOR0O/yzwFfXMOtYZ9o2oGZBF66p7GnHczP07vaNGhn1cCjlIMgo829HvN8jB1kI\n5tSxwhZsr9tL/i78PQh7vI5iDNYGuPw6awSClu1TwfDCWS1KqH198EP0raMxhFe4\nS1iOe4NkOxFlxifHZRMik74Zhkhmtd8byEeTltGccYwcCA2iJQZ/xjcFonxgElK6\nig2/Io/9NyiMaSODObLvsq9xNKWzKDAd/8utnT8sBar0Py9i+9vnHSkNcyatgQ7M\nsYgH+k8aru587J+ikkToT8JTNELI2pZVIRqeKvlrv6dQsMXODqjNFCQ+7joQGcMu\nF++WYb7jAgMBAAECggEAOV2QOvbyDzH3Y1hc+fcEHPi/QRX3rTWkSAttdEq+VaGs\nDIPBTG/3H9F63J2KZrjZYapwp5E5ln6Y7Mhy50cHCgFS1VwE9xT9m74jUwurX9+7\nSpLde9isb7XiPI4vYI96LA5M8TwSSNqJcZw4irT50cCJyt3YflbLxEGpO7M2Jmol\nhL8YqRj7rp0qy9W6VxfmT/DoS6P19k238vayELVozUdMMavUNeUwz6OmGjzyAHOz\nU0P3PdRX8LvivAOnA/A7GzpsbP9JWRbOIlU1J/kCnP+Kcg/G6pZZ/p6qMPv1d2ib\nPyX2DOSm2G0GEWkfR4aXX+BoUu8RzNLS4fO+euHtvQKBgQD6xaX0IMoJYo5bunMj\nUn67rjbDxPJRpdfAag3FwSRxR7giT/l6oTgg35qM+XuGJL5tRmwSoLfsXf4mCKB5\n2NzNif1t4gRx6uMx5ygDzmPOYIHpmmYNjDTSGGQ4fHxYSOzlCBWmuTERV8eNn772\nu9uW5iDXQu2h5dYjzfKNtn7c5QKBgQDra5UuFHALAotQ1ug5s3ZwQd+YXcIpO0Qr\nhtzy+h1IWcXSgK55WJL0X/gCl5WBPTeNzCoGbD5nKaThb9WHOskKpo8gaKvXOwKQ\nPV3+2QTc64tFIe5sbPKidrdOFAVhV8xMJzh0aDY37VdvHf3puYyyb4IR/YLxOBi9\n8fiTFgw4JwKBgQCoHxQIXGc27YUlSBXi626dosmCbCpMxNOlYzSCjN9CtuNi1Z0b\nMrSvjVlPA/9lSoMEPb88qdVEuSsnEoeLyPEXN1jZbzqtqNzSWve/vYG6HYdbNrEO\nih3rcIDYQdUXVyTC0624TdXwm5nkf+GGByHLw9Lmni80aCMtc+gWS/A3ZQKBgHpD\nYTKRQq81Hw1YzzpITdZ3H5yN9Oxc70Z7v/wgkVyl4us0EWjL62YnATK3btmz5Uor\nIhg71xzUr+C0p/yXNxnk7qgyNCyPZQFsHYjhRHlHiwjYWm7NFiXx6bkPBMxNQLi8\nFcG+7YmWJbZ7qQbdaoixCKg3NO356D+djy80YBw5AoGASYDtpXNW0ZPl8wD9GRuI\nqyk/xC7Fuvc75rVMHKv/AwWUWlot1I5eJiJoIqQKF0R9xDnprlxGqpk9vlY7WHBD\nj1yxowoSr851qAsjOHEL8GAU8RS1RzcUq6ZguNnA3yPALna4nSTh4t/1wtSS7Vif\nvr2uSqJghFgjT1YH8irHRkQ=\n-----END PRIVATE KEY-----\n`
}

function initAdmin() {
  if (admin.apps.length) return admin.apps[0]

  const projectId = process.env.FIREBASE_PROJECT_ID || FALLBACK_CREDENTIALS.projectId
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL || FALLBACK_CREDENTIALS.clientEmail
  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || FALLBACK_CREDENTIALS.privateKey)?.replace(/\\n/g, '\n')

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

  return null
}

initAdmin()

export const fcmMessaging = admin.apps.length > 0 ? admin.messaging() : null


