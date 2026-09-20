'use client'

import React from 'react'
import { SettingsTab } from '@/components/admin/settings-tab'

export interface AdminDarkStoresTabProps {
  storeId?: string
  storeHubName?: string
  onSettingsSaved: () => Promise<void>
}

export function AdminDarkStoresTab({
  storeId,
  storeHubName,
  onSettingsSaved,
}: AdminDarkStoresTabProps) {
  return (
    <div className="w-full">
      <SettingsTab
        storeId={storeId}
        storeHubName={storeHubName}
        onSettingsSaved={onSettingsSaved}
      />
    </div>
  )
}
