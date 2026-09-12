'use client'

import { AdminVendorConsole } from '@/components/admin/admin-vendor-console'

interface VendorConsoleTabProps {
  storeId?: string
}

export function VendorConsoleTab({ storeId }: VendorConsoleTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminVendorConsole storeId={storeId} />
    </div>
  )
}
