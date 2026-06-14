'use client'

import { usePushNotificationContext } from '@/providers/push-notification-provider'

export function usePushNotification() {
  return usePushNotificationContext()
}
