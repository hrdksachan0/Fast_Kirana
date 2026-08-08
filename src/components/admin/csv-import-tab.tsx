'use client'

import { AdminCsvImport } from '@/components/admin/admin-csv-import'
import { toast } from 'sonner'

interface CsvImportTabProps {
  categories: any[]
}

export function CsvImportTab({ categories }: CsvImportTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminCsvImport
        categories={categories}
        onImportComplete={(imported) => {
          toast.success(`${imported.length} products imported successfully!`)
        }}
        onClose={() => {
          // Parent will handle tab navigation
        }}
      />
    </div>
  )
}
