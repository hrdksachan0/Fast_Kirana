'use client'

import { AdminSettings } from '@/components/admin/admin-settings'

interface SettingsTabProps {
  onSettingsSaved: () => Promise<void>
}

export function SettingsTab({ onSettingsSaved }: SettingsTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminSettings onSettingsSaved={onSettingsSaved} />
    </div>
  )
}
