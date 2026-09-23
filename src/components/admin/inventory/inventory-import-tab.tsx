'use client'

import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { FileSpreadsheet, Loader2, Sparkles } from 'lucide-react'
import { toast } from 'sonner'

interface ImportItem {
  barcode: string
  name: string
  categorySlug: string
  brand: string
  mrp: number
  price: number
  stockQty: number
  unit: string
  imageUrl: string
}

interface InventoryImportTabProps {
  storeId?: string | null
  onImportSuccess?: () => void
}

export function InventoryImportTab({
  storeId,
  onImportSuccess,
}: InventoryImportTabProps) {
  const [importText, setImportText] = useState('')
  const [importPreview, setImportPreview] = useState<ImportItem[]>([])
  const [importing, setImporting] = useState(false)

  const handleParseImport = () => {
    if (!importText.trim()) return

    const rows = importText.trim().split('\n')
    const parsed: ImportItem[] = rows
      .map((row) => {
        const cols = row.split('\t') // split by tabs (standard copy-paste from Sheets)
        if (cols.length < 3) return null

        return {
          barcode: cols[0]?.trim() || '',
          name: cols[1]?.trim() || '',
          categorySlug: cols[2]?.trim().toLowerCase() || 'other-essentials',
          brand: cols[3]?.trim() || 'Generic',
          mrp: parseFloat(cols[4]) || 0,
          price: parseFloat(cols[5]) || 0,
          stockQty: parseInt(cols[6], 10) || 0,
          unit: cols[7]?.trim() || '1 pc',
          imageUrl: cols[8]?.trim() || '',
        }
      })
      .filter((item): item is ImportItem => item !== null)

    setImportPreview(parsed)
    toast.info(`Parsed ${parsed.length} rows. Please verify preview before importing.`)
  }

  const handleRunImport = async () => {
    if (importPreview.length === 0) return

    try {
      setImporting(true)
      const res = await fetch('/api/admin/inventory/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items: importPreview, storeId: storeId || undefined }),
      })

      if (!res.ok) throw new Error('Bulk import failed')
      const data = await res.json()

      toast.success(data.message || 'Import successful')
      setImportPreview([])
      setImportText('')
      onImportSuccess?.()
    } catch (err) {
      console.error(err)
      toast.error('Bulk import process failed')
    } finally {
      setImporting(false)
    }
  }

  return (
    <motion.div
      key="import-tab"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      className="space-y-6"
    >
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
        <div>
          <h3 className="text-sm font-black text-text-primary flex items-center gap-2">
            <FileSpreadsheet className="h-5 w-5 text-accent" />
            Google Sheets / Excel Bulk Import
          </h3>
          <p className="text-xs text-text-secondary mt-0.5">
            Copy columns from your grocery spreadsheet and paste them directly below to import or update inventory.
          </p>
        </div>

        {/* Import Textbox */}
        <div className="space-y-2">
          <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
            Paste Spreadsheet Rows (TAB Separated)
          </label>
          <textarea
            rows={8}
            value={importText}
            onChange={(e) => setImportText(e.target.value)}
            placeholder="Barcode&#9;Product Name&#9;Category Slug&#9;Brand&#9;MRP&#9;Selling Price&#9;Stock Quantity&#9;Unit&#9;Image URL"
            className="w-full bg-muted/40 border border-border/80 p-4 rounded-xl text-xs focus:outline-none focus:border-accent focus:bg-card font-mono leading-relaxed"
          />
          <div className="flex justify-between items-center">
            <span className="text-[9px] text-text-muted font-bold">
              Format: Barcode [Tab] Name [Tab] CategorySlug [Tab] Brand [Tab] MRP [Tab] Price [Tab] StockQty [Tab] Unit [Tab] ImageURL
            </span>
            <button
              onClick={handleParseImport}
              className="px-4 py-1.5 bg-accent hover:bg-accent-dark text-white rounded-lg text-xs font-extrabold cursor-pointer transition-colors shadow"
            >
              Preview & Validate Data
            </button>
          </div>
        </div>

        {/* Preview Grid */}
        {importPreview.length > 0 && (
          <div className="space-y-4 pt-4 border-t border-border/40">
            <div className="flex items-center justify-between">
              <span className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">
                Data Preview Grid ({importPreview.length} items parsed)
              </span>
              <button
                onClick={handleRunImport}
                disabled={importing}
                className="px-6 py-2 bg-emerald-500 hover:bg-emerald-600 text-white rounded-xl text-xs font-black tracking-wider uppercase transition-colors shadow flex items-center gap-1.5 cursor-pointer"
              >
                {importing ? (
                  <Loader2 className="h-4.5 w-4.5 animate-spin" />
                ) : (
                  <Sparkles className="h-4.5 w-4.5" />
                )}
                Apply Bulk Import & Sync
              </button>
            </div>

            <div className="overflow-x-auto border border-border rounded-xl">
              <table className="w-full text-left border-collapse text-[10px] font-semibold">
                <thead>
                  <tr className="bg-muted/50 border-b border-border text-text-secondary uppercase text-[8px] font-extrabold tracking-wider">
                    <th className="px-4 py-3">Barcode</th>
                    <th className="px-4 py-3">Product Name</th>
                    <th className="px-4 py-3">Category</th>
                    <th className="px-4 py-3">Brand</th>
                    <th className="px-4 py-3 text-right">MRP</th>
                    <th className="px-4 py-3 text-right">Sale Price</th>
                    <th className="px-4 py-3 text-center">Qty to Add</th>
                    <th className="px-4 py-3">Unit</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {importPreview.map((item, idx) => (
                    <tr key={idx} className="hover:bg-muted/10 transition-colors">
                      <td className="px-4 py-2.5 font-mono text-text-primary">
                        {item.barcode || '—'}
                      </td>
                      <td className="px-4 py-2.5 text-text-primary font-bold">{item.name}</td>
                      <td className="px-4 py-2.5 text-text-secondary">{item.categorySlug}</td>
                      <td className="px-4 py-2.5 text-text-secondary">{item.brand}</td>
                      <td className="px-4 py-2.5 text-right text-text-secondary">₹{item.mrp}</td>
                      <td className="px-4 py-2.5 text-right text-accent font-bold">₹{item.price}</td>
                      <td className="px-4 py-2.5 text-center text-text-primary font-bold">
                        +{item.stockQty}
                      </td>
                      <td className="px-4 py-2.5 text-text-secondary">{item.unit}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </motion.div>
  )
}
