'use client'

import { AdminPushNotifications } from '@/components/admin/admin-push-notifications'

interface PushNotificationsTabProps {}

export function PushNotificationsTab({}: PushNotificationsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminPushNotifications />
    </div>
  )
}
