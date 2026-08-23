'use client'

import { AdminCsvImport } from '@/components/admin/admin-csv-import'
import { toast } from 'sonner'

interface CsvImportTabProps {
  categories: any[]
  onImportSuccess?: () => void
}

export function CsvImportTab({ categories, onImportSuccess }: CsvImportTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminCsvImport
        categories={categories}
        onImportComplete={(imported) => {
          toast.success(`${imported.length} products imported successfully!`)
          onImportSuccess?.()
        }}
        onClose={() => {
          // Parent will handle tab navigation
        }}
      />
    </div>
  )
}
