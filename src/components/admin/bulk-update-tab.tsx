'use client'

import { AdminBulkUpdate } from '@/components/admin/admin-bulk-update'
import { toast } from 'sonner'

interface BulkUpdateTabProps {
  categories: any[]
  onUpdateCompleted: () => Promise<void>
}

export function BulkUpdateTab({ categories, onUpdateCompleted }: BulkUpdateTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminBulkUpdate
        categories={categories}
        onUpdateCompleted={async () => {
          try {
            const res = await fetch('/api/products?limit=1000')
            if (res.ok) {
              const data = await res.json()
              if (data.products) {
                // Products will be refreshed by parent
                onUpdateCompleted()
              }
            }
          } catch (err) {
            console.error(err)
            toast.error('Failed to refresh products')
          }
        }}
      />
    </div>
  )
}
