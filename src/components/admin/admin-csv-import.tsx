'use client'

import { useState, useRef, useCallback } from 'react'
import { toast } from 'sonner'
import {
  FileSpreadsheet,
  Download,
  Upload,
  X,
  Check,
  AlertCircle,
  Loader2,
  Trash,
  ChevronDown,
  ChevronUp,
  ShoppingBasket,
  Coffee,
} from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface ParsedProduct {
  name: string
  category: string
  unit: string
  mrp: string
  price: string
  stock: string
  tags: string
  description: string
  imageUrl: string
  costPrice: string
  minStock: string
  location: string
}

interface ValidationError {
  row: number
  field: string
  message: string
}

interface ImportResult {
  created: number
  skipped: number
  errors: string[]
}

interface AdminCsvImportProps {
  categories: Array<{ id: string; name: string; slug: string }>
  onImportComplete: (products: any[]) => void
  onClose: () => void
}

function parseCSV(text: string): string[][] {
  const rows: string[][] = []
  let current = ''
  let inQuotes = false
  let row: string[] = []

  for (let i = 0; i < text.length; i++) {
    const ch = text[i]
    const next = text[i + 1]

    if (inQuotes) {
      if (ch === '"' && next === '"') {
        current += '"'
        i++
      } else if (ch === '"') {
        inQuotes = false
      } else {
        current += ch
      }
    } else {
      if (ch === '"') {
        inQuotes = true
      } else if (ch === ',') {
        row.push(current.trim())
        current = ''
      } else if (ch === '\n' || (ch === '\r' && next === '\n')) {
        row.push(current.trim())
        if (row.some(cell => cell.length > 0)) rows.push(row)
        row = []
        current = ''
        if (ch === '\r') i++
      } else {
        current += ch
      }
    }
  }
  // last row
  row.push(current.trim())
  if (row.some(cell => cell.length > 0)) rows.push(row)

  return rows
}

const GROCERY_TEMPLATE_HEADERS = [
  'Name', 'Category', 'Unit', 'MRP', 'Price', 'Stock', 'Tags', 'Description', 'Image URL', 'Cost Price', 'Min Stock', 'Location'
]

const GROCERY_TEMPLATE_ROWS = [
  ['Amul Butter', 'Dairy & Breakfast', '500g', '280', '260', '50', 'dairy, butter, popular', 'Fresh Amul salted butter', '', '220', '10', 'Aisle 2-B'],
  ['Maggi Noodles', 'Snacks & Munchies', '1 pc', '14', '12', '100', 'instant, snacks, popular', 'Classic 2-min Maggi noodles', '', '10', '20', 'Aisle 4-A'],
  ['Tata Salt', 'Atta, Rice & Dal', '1 kg', '28', '25', '80', 'salt, essential, cooking', 'Iodised Tata salt', '', '18', '15', 'Aisle 1-C'],
]

const CAFE_TEMPLATE_HEADERS = [
  'Name', 'Category', 'Unit', 'MRP', 'Price', 'Stock', 'Tags', 'Description', 'Image URL', 'Cost Price', 'Min Stock', 'Location'
]

const CAFE_TEMPLATE_ROWS = [
  ['Veg Grilled Sandwich', 'FastKirana Cafe', '1 plate', '120', '99', '30', 'sandwich, fastfood, cafe', 'Toasted sandwich with fresh veggies and cheese', '', '60', '5', 'Kitchen Grid A'],
  ['Special Masala Chai', 'FastKirana Cafe', '1 cup', '30', '20', '100', 'tea, beverage, hot', 'Authentic Indian spiced tea', '', '8', '10', 'Chai Station'],
  ['Paneer Burger', 'FastKirana Cafe', '1 pc', '150', '129', '25', 'burger, paneer, popular', 'Crispy paneer patty with gourmet sauces', '', '80', '5', 'Kitchen Grid B'],
  ['Penne Arrabbiata (Red Sauce Pasta)', 'FastKirana Cafe', '1 bowl', '180', '149', '15', 'pasta, Italian, redsauce', 'Spicy tomato sauce pasta with Italian herbs', '', '90', '3', 'Pasta Station'],
]


export function AdminCsvImport({ categories, onImportComplete, onClose }: AdminCsvImportProps) {
  const [importType, setImportType] = useState<'grocery' | 'cafe'>('grocery')
  const [parsedProducts, setParsedProducts] = useState<ParsedProduct[]>([])
  const [validationErrors, setValidationErrors] = useState<ValidationError[]>([])
  const [isImporting, setIsImporting] = useState(false)
  const [importResult, setImportResult] = useState<ImportResult | null>(null)
  const [showErrors, setShowErrors] = useState(false)
  const [fileName, setFileName] = useState('')
  const fileInputRef = useRef<HTMLInputElement>(null)

  const categoryNames = new Set(categories.map(c => c.name.toLowerCase().trim()))
  const categorySlugs = new Set(categories.map(c => c.slug.toLowerCase().trim()))

  const handleImportTypeChange = useCallback((type: 'grocery' | 'cafe') => {
    setImportType(type)
    setParsedProducts([])
    setValidationErrors([])
    setFileName('')
    setImportResult(null)
  }, [])

  const downloadTemplate = useCallback(() => {
    const headers = importType === 'grocery' ? GROCERY_TEMPLATE_HEADERS : CAFE_TEMPLATE_HEADERS
    const rowsData = importType === 'grocery' ? GROCERY_TEMPLATE_ROWS : CAFE_TEMPLATE_ROWS

    const cafeCategory = categories.find(c => c.slug === 'cafe')
    const cafeCategoryName = cafeCategory?.name || 'FastKirana Cafe'

    const rows = rowsData.map(row => {
      const parsedRow = [...row]
      if (importType === 'cafe') {
        parsedRow[1] = cafeCategoryName
      }
      return parsedRow.map(cell => cell.includes(',') ? `"${cell}"` : cell).join(',')
    })

    const csv = [headers.join(','), ...rows].join('\n')
    const blob = new Blob([csv], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = importType === 'grocery' ? 'fastkirana_grocery_template.csv' : 'fastkirana_cafe_template.csv'
    a.click()
    URL.revokeObjectURL(url)
    toast.success(`${importType === 'grocery' ? 'Grocery' : 'Cafe'} template CSV downloaded!`)
  }, [importType, categories])

  const validateProducts = useCallback((products: ParsedProduct[], type: 'grocery' | 'cafe'): ValidationError[] => {
    const errors: ValidationError[] = []

    const cafeCategory = categories.find(c => c.slug === 'cafe')
    const cafeCategoryName = cafeCategory?.name || 'FastKirana Cafe'
    const cafeCategoryNameLower = cafeCategoryName.toLowerCase().trim()

    products.forEach((p, i) => {
      const row = i + 1
      if (!p.name) errors.push({ row, field: 'Name', message: 'Name is required' })
      
      if (!p.category) {
        errors.push({ row, field: 'Category', message: 'Category is required' })
      } else {
        const catLower = p.category.toLowerCase().trim()
        const isCafeCategory = (catLower === 'cafe' || catLower === cafeCategoryNameLower)

        if (type === 'cafe') {
          if (!isCafeCategory) {
            errors.push({
              row,
              field: 'Category',
              message: `Cafe Import must have Category "${cafeCategoryName}". Found "${p.category}".`
            })
          }
        } else {
          if (isCafeCategory) {
            errors.push({
              row,
              field: 'Category',
              message: `Category "${cafeCategoryName}" is not allowed in Grocery Import. Switch to Cafe Import.`
            })
          } else if (!categoryNames.has(catLower) && !categorySlugs.has(catLower)) {
            errors.push({ row, field: 'Category', message: `Category "${p.category}" not found in database` })
          }
        }
      }

      if (!p.unit) errors.push({ row, field: 'Unit', message: 'Unit is required' })
      if (!p.mrp || isNaN(parseFloat(p.mrp)) || parseFloat(p.mrp) <= 0) errors.push({ row, field: 'MRP', message: 'Valid MRP required' })
      if (!p.price || isNaN(parseFloat(p.price)) || parseFloat(p.price) <= 0) errors.push({ row, field: 'Price', message: 'Valid Price required' })
      if (parseFloat(p.price) > parseFloat(p.mrp)) errors.push({ row, field: 'Price', message: 'Price cannot exceed MRP' })
    })
    return errors
  }, [categories, categoryNames, categorySlugs])

  const handleFileChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (!file) return

    setFileName(file.name)
    setImportResult(null)

    const reader = new FileReader()
    reader.onload = (event) => {
      try {
        const text = event.target?.result as string
        const rows = parseCSV(text)

        if (rows.length < 2) {
          toast.error('CSV file is empty or has no data rows')
          return
        }

        const headerRow = rows[0].map(h => h.toLowerCase().trim())
        const dataRows = rows.slice(1)

        const getIdx = (names: string[]) => {
          for (const n of names) {
            const idx = headerRow.indexOf(n.toLowerCase())
            if (idx !== -1) return idx
          }
          return -1
        }

        const nameIdx = getIdx(['name', 'product name', 'product'])
        const categoryIdx = getIdx(['category', 'category name'])
        const unitIdx = getIdx(['unit', 'unit specification', 'size'])
        const mrpIdx = getIdx(['mrp', 'mrp price', 'max price'])
        const priceIdx = getIdx(['price', 'selling price', 'fastkirana price'])
        const stockIdx = getIdx(['stock', 'initial stock', 'qty', 'quantity'])
        const tagsIdx = getIdx(['tags', 'tag'])
        const descIdx = getIdx(['description', 'desc', 'details'])
        const imgIdx = getIdx(['image url', 'imageurl', 'image', 'photo'])
        const costIdx = getIdx(['cost price', 'costprice', 'cost'])
        const minStockIdx = getIdx(['min stock', 'minstock', 'min stock alert'])
        const locationIdx = getIdx(['location', 'shelf', 'rack', 'aisle'])

        if (nameIdx === -1 || mrpIdx === -1 || priceIdx === -1) {
          toast.error('CSV must have at least Name, MRP, and Price columns')
          return
        }

        const products: ParsedProduct[] = dataRows
          .filter(row => row.some(cell => cell.length > 0))
          .map(row => ({
            name: row[nameIdx] || '',
            category: categoryIdx >= 0 ? (row[categoryIdx] || '') : '',
            unit: unitIdx >= 0 ? (row[unitIdx] || '') : '',
            mrp: mrpIdx >= 0 ? (row[mrpIdx] || '') : '',
            price: priceIdx >= 0 ? (row[priceIdx] || '') : '',
            stock: stockIdx >= 0 ? (row[stockIdx] || '0') : '0',
            tags: tagsIdx >= 0 ? (row[tagsIdx] || '') : '',
            description: descIdx >= 0 ? (row[descIdx] || '') : '',
            imageUrl: imgIdx >= 0 ? (row[imgIdx] || '') : '',
            costPrice: costIdx >= 0 ? (row[costIdx] || '0') : '0',
            minStock: minStockIdx >= 0 ? (row[minStockIdx] || '10') : '10',
            location: locationIdx >= 0 ? (row[locationIdx] || '') : '',
          }))


        setParsedProducts(products)
        const errs = validateProducts(products, importType)
        setValidationErrors(errs)

        if (products.length === 0) {
          toast.error('No valid product rows found in CSV')
        } else {
          toast.success(`Parsed ${products.length} products from CSV`)
        }
      } catch (err) {
        toast.error('Failed to parse CSV file')
        console.error('CSV parse error:', err)
      }
    }
    reader.readAsText(file)

    e.target.value = ''
  }, [validateProducts, importType])

  const handleImport = useCallback(async () => {
    if (parsedProducts.length === 0) return

    const criticalErrors = validationErrors.filter(
      e => ['Name', 'Category', 'MRP', 'Price'].includes(e.field)
    )
    if (criticalErrors.length > 0) {
      toast.error(`Fix ${criticalErrors.length} critical errors before importing`)
      setShowErrors(true)
      return
    }

    setIsImporting(true)
    try {
      const res = await fetch('/api/admin/products/bulk-import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ products: parsedProducts }),
      })

      const data = await res.json()

      if (res.ok) {
        setImportResult({
          created: data.created,
          skipped: data.skipped,
          errors: data.errors || [],
        })

        if (data.created > 0) {
          toast.success(`✅ ${data.created} products imported successfully!`)
          onImportComplete(data.products || [])
        }
        if (data.skipped > 0) {
          toast.warning(`⚠️ ${data.skipped} products skipped due to errors`)
        }
      } else {
        toast.error(data.error || 'Import failed')
      }
    } catch (err) {
      toast.error('Network error during import')
    } finally {
      setIsImporting(false)
    }
  }, [parsedProducts, validationErrors, onImportComplete])

  const removeProduct = useCallback((index: number) => {
    const updated = parsedProducts.filter((_, i) => i !== index)
    setParsedProducts(updated)
    setValidationErrors(validateProducts(updated, importType))
  }, [parsedProducts, validateProducts, importType])

  const errorCount = validationErrors.length
  const criticalCount = validationErrors.filter(e => ['Name', 'Category', 'MRP', 'Price'].includes(e.field)).length
  const hasErrors = errorCount > 0
  const canImport = parsedProducts.length > 0 && criticalCount === 0 && !isImporting

  const isCafe = importType === 'cafe'
  const visibleCategories = categories.filter(c => isCafe ? c.slug === 'cafe' : c.slug !== 'cafe')

  // UI styling strings mapped to theme
  const headerGradient = isCafe
    ? 'from-rose-500/5 to-amber-500/5'
    : 'from-blue-500/5 to-indigo-500/5'

  const iconContainerClass = isCafe
    ? 'bg-rose-500/10 text-rose-600 dark:text-rose-400'
    : 'bg-blue-500/10 text-blue-600 dark:text-blue-400'

  const downloadButtonClass = isCafe
    ? 'border-rose-500/30 bg-rose-500/5 hover:bg-rose-500/10 text-rose-600 dark:text-rose-400'
    : 'border-blue-500/30 bg-blue-500/5 hover:bg-blue-500/10 text-blue-600 dark:text-blue-400'

  const uploadLabelClass = isCafe
    ? 'border-amber-500/30 bg-amber-500/5 hover:bg-amber-500/10 text-amber-600 dark:text-amber-400'
    : 'border-accent/30 bg-accent/5 hover:bg-accent/10 text-accent'

  const importButtonClass = isCafe
    ? 'bg-rose-600 hover:bg-rose-700 text-white shadow-rose-600/10'
    : 'bg-accent hover:bg-accent/90 text-white shadow-accent/10'

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: 10 }}
      className="bg-card border border-border rounded-2xl shadow-sm overflow-hidden animate-slide-up"
    >
      {/* Header */}
      <div className={`flex items-center justify-between p-4 md:p-5 border-b border-border/60 bg-gradient-to-r ${headerGradient}`}>
        <div className="flex items-center gap-3">
          <div className={`flex h-10 w-10 items-center justify-center rounded-xl ${iconContainerClass}`}>
            <FileSpreadsheet className="h-5 w-5" />
          </div>
          <div>
            <h3 className="text-sm font-extrabold text-text-primary">CSV Bulk Import</h3>
            <p className="text-[10px] text-text-secondary mt-0.5">Upload a CSV file to add multiple products at once</p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="p-1.5 rounded-lg hover:bg-muted/60 text-text-secondary hover:text-text-primary transition-colors cursor-pointer"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      {/* Segmented Import Type Selection Tabs */}
      <div className="flex p-1 bg-muted/30 border-b border-border/40 gap-1">
        <button
          onClick={() => handleImportTypeChange('grocery')}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 text-xs font-extrabold rounded-lg transition-all cursor-pointer ${
            !isCafe
              ? 'bg-card text-blue-600 dark:text-blue-400 shadow-sm border border-border/40'
              : 'text-text-secondary hover:text-text-primary hover:bg-muted/40'
          }`}
        >
          <ShoppingBasket className="h-4 w-4" />
          Grocery Import
        </button>
        <button
          onClick={() => handleImportTypeChange('cafe')}
          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 text-xs font-extrabold rounded-lg transition-all cursor-pointer ${
            isCafe
              ? 'bg-card text-rose-600 dark:text-rose-400 shadow-sm border border-border/40'
              : 'text-text-secondary hover:text-text-primary hover:bg-muted/40'
          }`}
        >
          <Coffee className="h-4 w-4" />
          Cafe Import
        </button>
      </div>

      <div className="p-4 md:p-5 space-y-4">

        {/* Step 1: Download Template + Upload */}
        <div className="flex flex-col sm:flex-row gap-3">
          <button
            onClick={downloadTemplate}
            className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed text-xs font-bold rounded-xl transition-all cursor-pointer ${downloadButtonClass}`}
          >
            <Download className="h-4 w-4" />
            Download {isCafe ? 'Cafe' : 'Grocery'} Template CSV
          </button>

          <label className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 border-2 border-dashed text-xs font-bold rounded-xl transition-all cursor-pointer ${uploadLabelClass}`}>
            <Upload className="h-4 w-4" />
            {fileName ? `📄 ${fileName}` : 'Upload CSV File'}
            <input
              ref={fileInputRef}
              type="file"
              accept=".csv"
              onChange={handleFileChange}
              className="hidden"
            />
          </label>
        </div>

        {/* Available Categories Reference */}
        <div className="bg-muted/20 border border-border/40 rounded-xl p-3">
          <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider mb-1.5">
            Available {isCafe ? 'Cafe' : 'Grocery'} Categories (use exact name in CSV):
          </p>
          <div className="flex flex-wrap gap-1.5">
            {visibleCategories.map(c => (
              <span key={c.id} className="px-2 py-0.5 bg-card border border-border/50 rounded-md text-[10px] font-bold text-text-primary">
                {c.name}
              </span>
            ))}
            {visibleCategories.length === 0 && (
              <span className="text-[10px] text-text-muted italic">No categories found</span>
            )}
          </div>
        </div>

        {/* Import Result */}
        <AnimatePresence>
          {importResult && (
            <motion.div
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="rounded-xl border p-4 space-y-2"
              style={{
                borderColor: importResult.created > 0 ? 'rgba(16,185,129,0.3)' : 'rgba(239,68,68,0.3)',
                backgroundColor: importResult.created > 0 ? 'rgba(16,185,129,0.05)' : 'rgba(239,68,68,0.05)',
              }}
            >
              <div className="flex items-center gap-3">
                {importResult.created > 0 ? (
                  <Check className="h-5 w-5 text-accent" />
                ) : (
                  <AlertCircle className="h-5 w-5 text-red-500" />
                )}
                <div>
                  <p className="text-sm font-extrabold text-text-primary">
                    {importResult.created > 0 ? `✅ ${importResult.created} Products Imported!` : 'Import completed with errors'}
                  </p>
                  {importResult.skipped > 0 && (
                    <p className="text-xs text-text-secondary">{importResult.skipped} rows skipped</p>
                  )}
                </div>
              </div>
              {importResult.errors.length > 0 && (
                <div className="max-h-32 overflow-y-auto text-[10px] text-red-500 space-y-0.5 mt-2">
                  {importResult.errors.map((err, i) => (
                    <p key={i}>• {err}</p>
                  ))}
                </div>
              )}
            </motion.div>
          )}
        </AnimatePresence>

        {/* Validation Errors */}
        {hasErrors && parsedProducts.length > 0 && (
          <div className="rounded-xl border border-amber-500/30 bg-amber-500/5 p-3">
            <button
              onClick={() => setShowErrors(!showErrors)}
              className="w-full flex items-center justify-between cursor-pointer"
            >
              <div className="flex items-center gap-2">
                <AlertCircle className="h-4 w-4 text-amber-500" />
                <span className="text-xs font-bold text-amber-600 dark:text-amber-400">
                  {errorCount} validation issue{errorCount > 1 ? 's' : ''}
                  {criticalCount > 0 && ` (${criticalCount} critical — must fix before import)`}
                </span>
              </div>
              {showErrors ? <ChevronUp className="h-3.5 w-3.5 text-amber-500" /> : <ChevronDown className="h-3.5 w-3.5 text-amber-500" />}
            </button>
            {showErrors && (
              <div className="mt-2 max-h-32 overflow-y-auto space-y-0.5">
                {validationErrors.map((err, i) => (
                  <p key={i} className="text-[10px] text-amber-600 dark:text-amber-400">
                    Row {err.row}: [{err.field}] {err.message}
                  </p>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Preview Table */}
        {parsedProducts.length > 0 && (
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <p className="text-xs font-extrabold text-text-primary">
                📋 Preview: {parsedProducts.length} product{parsedProducts.length > 1 ? 's' : ''}
              </p>
              <button
                onClick={() => { setParsedProducts([]); setValidationErrors([]); setFileName(''); setImportResult(null) }}
                className="text-[10px] font-bold text-red-500 hover:text-red-600 cursor-pointer"
              >
                Clear All
              </button>
            </div>

            <div className="max-h-[300px] overflow-auto rounded-xl border border-border/60">
              <table className="w-full text-xs">
                <thead className="bg-muted/30 sticky top-0 z-10">
                  <tr>
                    <th className="py-2 px-3 text-left font-extrabold text-text-secondary">#</th>
                    <th className="py-2 px-3 text-left font-extrabold text-text-secondary">Name</th>
                    <th className="py-2 px-3 text-left font-extrabold text-text-secondary">Category</th>
                    <th className="py-2 px-3 text-left font-extrabold text-text-secondary">Unit</th>
                    <th className="py-2 px-3 text-right font-extrabold text-text-secondary">MRP</th>
                    <th className="py-2 px-3 text-right font-extrabold text-text-secondary">Price</th>
                    <th className="py-2 px-3 text-right font-extrabold text-text-secondary">Stock</th>
                    <th className="py-2 px-3 text-left font-extrabold text-text-secondary">Tags</th>
                    <th className="py-2 px-3"></th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {parsedProducts.map((p, i) => {
                    const rowErrors = validationErrors.filter(e => e.row === i + 1)
                    const hasRowError = rowErrors.length > 0
                    return (
                      <tr key={i} className={`${hasRowError ? 'bg-red-500/5' : 'hover:bg-muted/20'} transition-colors`}>
                        <td className="py-2 px-3 text-text-muted font-bold">{i + 1}</td>
                        <td className="py-2 px-3 font-bold text-text-primary max-w-[150px] truncate">
                          {p.name || <span className="text-red-500 italic">Missing</span>}
                        </td>
                        <td className="py-2 px-3 font-semibold text-text-secondary max-w-[120px] truncate">
                          {p.category || <span className="text-red-500 italic">Missing</span>}
                        </td>
                        <td className="py-2 px-3 text-text-secondary font-semibold">{p.unit || '-'}</td>
                        <td className="py-2 px-3 text-right font-bold">₹{p.mrp || '-'}</td>
                        <td className="py-2 px-3 text-right font-bold text-accent">₹{p.price || '-'}</td>
                        <td className="py-2 px-3 text-right font-semibold">{p.stock || '0'}</td>
                        <td className="py-2 px-3 text-text-muted text-[10px] max-w-[120px] truncate">{p.tags || '-'}</td>
                        <td className="py-2 px-2">
                          <button
                            onClick={() => removeProduct(i)}
                            className="p-1 text-red-400 hover:text-red-500 hover:bg-red-500/10 rounded transition-colors cursor-pointer"
                            title="Remove this row"
                          >
                            <Trash className="h-3 w-3" />
                          </button>
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>

            {/* Import Button */}
            <button
              onClick={handleImport}
              disabled={!canImport}
              className={`w-full flex items-center justify-center gap-2 px-4 py-3 text-sm font-extrabold rounded-xl shadow-md hover:shadow-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer ${importButtonClass}`}
            >
              {isImporting ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Importing {parsedProducts.length} products...
                </>
              ) : (
                <>
                  <Check className="h-4 w-4" />
                  Import {parsedProducts.length} Products
                </>
              )}
            </button>
          </div>
        )}
      </div>
    </motion.div>
  )
}
