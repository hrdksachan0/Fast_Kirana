'use client'

import { AdminSettings } from '@/components/admin/admin-settings'

interface SettingsTabProps {
  storeId?: string
  storeHubName?: string
  onSettingsSaved: () => Promise<void>
}

export function SettingsTab({ storeId, storeHubName, onSettingsSaved }: SettingsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminSettings storeId={storeId} storeHubName={storeHubName} onSettingsSaved={onSettingsSaved} />
    </div>
  )
}
