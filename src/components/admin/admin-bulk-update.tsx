'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { 
  PackageOpen, 
  ChevronRight, 
  Settings, 
  HelpCircle,
  Play,
  RotateCcw,
  History,
  CheckCircle,
  AlertTriangle,
  Loader2,
  Undo
} from 'lucide-react'
import { formatPrice } from '@/lib/utils'

interface Category {
  id: string
  name: string
  slug: string
}

interface Product {
  id: string
  name: string
  price: number
  stock: number
  isAvailable: boolean
}

interface ChangePreview {
  productId: string
  name: string
  oldValue: number | boolean
  newValue: number | boolean
}

interface BatchHistory {
  batchId: string
  changeType: string
  createdAt: string
  count: number
  records: Array<{
    id: string
    productName: string
    oldPrice: number
    newPrice: number
  }>
}

interface AdminBulkUpdateProps {
  categories: Category[]
  onUpdateCompleted?: () => void
}

export function AdminBulkUpdate({ categories, onUpdateCompleted }: AdminBulkUpdateProps) {
  // Bulk update parameters form
  const [selectedCategoryId, setSelectedCategoryId] = useState<string>('ALL')
  const [updateType, setUpdateType] = useState<'PRICE' | 'STOCK' | 'AVAILABILITY'>('PRICE')
  const [mode, setMode] = useState<'FLAT_INCREASE' | 'FLAT_DECREASE' | 'PERCENT_INCREASE' | 'PERCENT_DECREASE' | 'SET_VALUE'>('FLAT_INCREASE')
  const [value, setValue] = useState<string>('')
  
  // States for previews & execution
  const [previewing, setPreviewing] = useState(false)
  const [previews, setPreviews] = useState<ChangePreview[]>([])
  const [previewBatchId, setPreviewBatchId] = useState<string | null>(null)
  
  const [applying, setApplying] = useState(false)

  // History state
  const [historyList, setHistoryList] = useState<BatchHistory[]>([])
  const [loadingHistory, setLoadingHistory] = useState(true)
  const [undoingBatchId, setUndoingBatchId] = useState<string | null>(null)

  // Load history on mount
  const fetchHistory = async () => {
    try {
      setLoadingHistory(true)
      const res = await fetch('/api/admin/bulk-update')
      if (!res.ok) throw new Error('Failed to load history')
      const data = await res.json()
      setHistoryList(data.batches || [])
    } catch (err) {
      console.error(err)
      toast.error('Could not load price update history')
    } finally {
      setLoadingHistory(false)
    }
  }

  useEffect(() => {
    fetchHistory()
  }, [])

  // Auto adjust mode if availability is selected
  useEffect(() => {
    if (updateType === 'AVAILABILITY') {
      setMode('SET_VALUE')
      setValue('1') // default to Enable (1)
    } else if (updateType === 'STOCK' && mode.includes('PERCENT')) {
      // Stock typically uses flat values
      setMode('FLAT_INCREASE')
    }
  }, [updateType])

  // Get preview of changes
  const handlePreview = async (e: React.FormEvent) => {
    e.preventDefault()
    
    const parsedVal = parseFloat(value)
    if (isNaN(parsedVal) && updateType !== 'AVAILABILITY') {
      toast.error('Please enter a valid numeric value')
      return
    }

    try {
      setPreviewing(true)
      setPreviews([])
      
      const payload = {
        categoryId: selectedCategoryId === 'ALL' ? undefined : selectedCategoryId,
        updateType,
        mode,
        value: updateType === 'AVAILABILITY' ? parseInt(value, 10) : parsedVal,
        preview: true
      }

      const res = await fetch('/api/admin/bulk-update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (!res.ok) {
        const errorData = await res.json()
        throw new Error(errorData.error || 'Preview request failed')
      }

      const data = await res.json()
      setPreviews(data.changes || [])
      setPreviewBatchId(data.batchId || null)
      toast.success(`Computed preview for ${data.updated} product(s)`)
    } catch (err: any) {
      console.error(err)
      toast.error(err.message || 'Error generating bulk preview')
    } finally {
      setPreviewing(false)
    }
  }

  // Apply bulk update changes
  const handleApply = async () => {
    if (previews.length === 0) return

    const parsedVal = parseFloat(value)
    try {
      setApplying(true)
      const payload = {
        categoryId: selectedCategoryId === 'ALL' ? undefined : selectedCategoryId,
        updateType,
        mode,
        value: updateType === 'AVAILABILITY' ? parseInt(value, 10) : parsedVal,
        preview: false
      }

      const res = await fetch('/api/admin/bulk-update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      })

      if (!res.ok) throw new Error('Bulk update failed')
      
      const data = await res.json()
      toast.success(`Successfully updated ${data.updated} product(s)`)
      
      // Reset view
      setPreviews([])
      setPreviewBatchId(null)
      setValue('')
      
      // Refresh database history table
      await fetchHistory()
      
      if (onUpdateCompleted) onUpdateCompleted()
    } catch (err) {
      console.error(err)
      toast.error('Error applying bulk update')
    } finally {
      setApplying(false)
    }
  }

  // Undo a previous price update batch
  const handleUndo = async (batchId: string) => {
    try {
      setUndoingBatchId(batchId)
      const res = await fetch('/api/admin/bulk-update', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ batchId })
      })

      if (!res.ok) throw new Error('Undo request failed')
      const data = await res.json()
      
      toast.success(`Reverted changes for ${data.reverted} products!`)
      await fetchHistory()
      if (onUpdateCompleted) onUpdateCompleted()
    } catch (err) {
      console.error(err)
      toast.error('Could not undo bulk update')
    } finally {
      setUndoingBatchId(null)
    }
  }

  // Helper description of the update action
  const getActionPhrase = () => {
    const scope = selectedCategoryId === 'ALL' ? 'all catalog products' : `products in the selected category`
    
    if (updateType === 'AVAILABILITY') {
      return `This will set availability to ${value === '1' ? 'Enabled' : 'Disabled'} for ${scope}.`
    }

    const modeLabel = {
      FLAT_INCREASE: `add flat ₹${value}`,
      FLAT_DECREASE: `subtract flat ₹${value}`,
      PERCENT_INCREASE: `increase by ${value}%`,
      PERCENT_DECREASE: `decrease by ${value}%`,
      SET_VALUE: `set to exactly ${updateType === 'PRICE' ? '₹' : ''}${value} units`
    }[mode]

    return `This will update ${updateType.toLowerCase()} to ${modeLabel} for ${scope}.`
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      
      {/* Parameter Control Panel Card */}
      <div className="lg:col-span-2 space-y-6">
        
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4">
          <div>
            <h3 className="text-base font-bold text-text-primary flex items-center gap-1.5">
              <Settings className="h-5 w-5 text-accent" />
              Configure Bulk Update Action
            </h3>
            <p className="text-xs text-text-secondary mt-0.5">
              Apply pricing adjustments, replenish stock levels, or toggle availability status for entire ranges instantly.
            </p>
          </div>

          <form onSubmit={handlePreview} className="space-y-4">
            
            {/* Category selection */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Target Category Range</label>
                <select
                  value={selectedCategoryId}
                  onChange={(e) => setSelectedCategoryId(e.target.value)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary"
                >
                  <option value="ALL">All Store Products</option>
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              {/* Action type */}
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Field to Update</label>
                <select
                  value={updateType}
                  onChange={(e) => setUpdateType(e.target.value as any)}
                  className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary"
                >
                  <option value="PRICE">Price (Cost & Selling prices)</option>
                  <option value="STOCK">Stock level (Replenishment)</option>
                  <option value="AVAILABILITY">Availability toggle</option>
                </select>
              </div>
            </div>

            {/* Mode selection and value */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              
              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Calculation Method</label>
                {updateType === 'AVAILABILITY' ? (
                  <select
                    disabled
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs opacity-60"
                  >
                    <option>Set Status</option>
                  </select>
                ) : (
                  <select
                    value={mode}
                    onChange={(e) => setMode(e.target.value as any)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary"
                  >
                    <option value="FLAT_INCREASE">Flat increase (+Value)</option>
                    <option value="FLAT_DECREASE">Flat decrease (-Value)</option>
                    {updateType === 'PRICE' && <option value="PERCENT_INCREASE">Percentage increase (+%)</option>}
                    {updateType === 'PRICE' && <option value="PERCENT_DECREASE">Percentage decrease (-%)</option>}
                    <option value="SET_VALUE">Set exact value (=Value)</option>
                  </select>
                )}
              </div>

              <div className="space-y-1">
                <label className="text-[10px] font-extrabold uppercase tracking-wider text-text-secondary">Adjustment Value</label>
                {updateType === 'AVAILABILITY' ? (
                  <select
                    value={value}
                    onChange={(e) => setValue(e.target.value)}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary"
                  >
                    <option value="1">Available (Show in Shop)</option>
                    <option value="0">Unavailable (Hide from Customers)</option>
                  </select>
                ) : (
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={value}
                    onChange={(e) => setValue(e.target.value)}
                    placeholder={updateType === 'PRICE' ? 'e.g. 10 for 10% or ₹10' : 'e.g. 50 units'}
                    className="w-full bg-muted/40 border border-border px-3 py-2 rounded-xl text-xs focus:outline-none focus:border-primary"
                  />
                )}
              </div>

            </div>

            {/* Explanatory banner */}
            {value !== '' && (
              <div className="p-3 bg-accent/5 rounded-xl border border-accent/15 flex items-start gap-2">
                <HelpCircle className="h-4.5 w-4.5 text-accent mt-0.5 shrink-0" />
                <span className="text-[11px] text-text-secondary font-semibold leading-relaxed">
                  {getActionPhrase()}
                </span>
              </div>
            )}

            {/* Run Button */}
            <div className="pt-2">
              <button
                type="submit"
                disabled={previewing || value === ''}
                className="w-full h-9 rounded-xl font-bold bg-primary hover:bg-primary-dark text-white transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 text-xs"
              >
                {previewing ? (
                  <>
                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    Computing database preview...
                  </>
                ) : (
                  <>
                    <Play className="h-3.5 w-3.5" />
                    Preview Update Changes
                  </>
                )}
              </button>
            </div>

          </form>
        </div>

        {/* Live Preview Changes Section */}
        {previews.length > 0 && (
          <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-4 animate-slide-down">
            <div className="flex items-center justify-between border-b border-border/60 pb-3">
              <div>
                <h4 className="text-sm font-bold text-text-primary flex items-center gap-1.5">
                  <CheckCircle className="h-4.5 w-4.5 text-accent" />
                  Preview: Computed Changes ({previews.length} products)
                </h4>
                <p className="text-[10px] text-text-muted mt-0.5">Please review before saving to the live database.</p>
              </div>
              <button
                onClick={() => setPreviews([])}
                className="text-[10px] text-text-secondary hover:text-red-500 font-bold"
              >
                Cancel Update
              </button>
            </div>

            <div className="max-h-60 overflow-y-auto divide-y divide-border/60 pr-1">
              {previews.map((change) => (
                <div key={change.productId} className="py-2.5 flex justify-between items-center text-xs">
                  <span className="font-semibold text-text-primary truncate max-w-[200px] md:max-w-xs">{change.name}</span>
                  <div className="flex items-center gap-2 font-mono font-bold shrink-0">
                    <span className="text-text-muted">
                      {updateType === 'PRICE' ? formatPrice(change.oldValue as number) : String(change.oldValue)}
                    </span>
                    <ChevronRight className="h-3 w-3 text-text-muted" />
                    <span className="text-accent bg-accent/5 px-2 py-0.5 rounded border border-accent/10">
                      {updateType === 'PRICE' ? formatPrice(change.newValue as number) : String(change.newValue)}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            <div className="pt-2 border-t border-border/60 flex items-center gap-3">
              <button
                onClick={handleApply}
                disabled={applying}
                className="flex-1 h-9 rounded-xl font-bold bg-accent hover:bg-accent-dark text-white transition-colors flex items-center justify-center gap-1.5 disabled:opacity-60 text-xs"
              >
                {applying ? (
                  <>
                    <Loader2 className="h-3.5 w-3.5 animate-spin" />
                    Applying database transaction...
                  </>
                ) : (
                  <>
                    <CheckCircle className="h-3.5 w-3.5" />
                    Confirm & Apply to Database
                  </>
                )}
              </button>
            </div>
          </div>
        )}

      </div>

      {/* Side: Price History Log Card */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex flex-col justify-between">
        <div className="space-y-4">
          <div className="flex items-center gap-2 border-b border-border/60 pb-3">
            <History className="h-5 w-5 text-accent animate-pulse-slow" />
            <div>
              <h4 className="text-sm font-bold text-text-primary">Recent Adjustments Log</h4>
              <p className="text-[10px] text-text-muted">Audit list of past bulk changes.</p>
            </div>
          </div>

          {loadingHistory ? (
            <div className="py-20 flex justify-center">
              <Loader2 className="h-6 w-6 animate-spin text-primary" />
            </div>
          ) : historyList.length === 0 ? (
            <div className="py-10 text-center text-xs text-text-secondary">
              No recent bulk price changes logged.
            </div>
          ) : (
            <div className="space-y-3 max-h-[360px] overflow-y-auto pr-1">
              {historyList.map((batch) => (
                <div key={batch.batchId} className="p-3 bg-muted/30 border border-border rounded-xl space-y-2">
                  <div className="flex justify-between items-start text-[10px]">
                    <span className="font-extrabold text-accent bg-accent/5 px-1.5 py-0.5 rounded border border-accent/10">
                      {batch.changeType}
                    </span>
                    <span className="text-text-muted">
                      {new Date(batch.createdAt).toLocaleDateString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                    </span>
                  </div>
                  
                  <div className="flex justify-between items-center text-xs">
                    <span className="text-text-secondary font-semibold">Updated {batch.count} product(s)</span>
                    {batch.changeType.startsWith('BULK_') && (
                      <button
                        onClick={() => handleUndo(batch.batchId)}
                        disabled={undoingBatchId === batch.batchId}
                        className="text-[10px] text-red-500 hover:text-red-600 font-bold flex items-center gap-0.5 disabled:opacity-50"
                      >
                        {undoingBatchId === batch.batchId ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <Undo className="h-3 w-3" />
                        )}
                        Undo Update
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        <div className="mt-4 pt-4 border-t border-border/60 text-[9px] text-text-muted flex items-start gap-1">
          <AlertTriangle className="h-3.5 w-3.5 text-orange-400 shrink-0 mt-0.5" />
          <span>Only Price updates can be reverted. Stock additions and availability states must be re-applied manually.</span>
        </div>
      </div>

    </div>
  )
}
